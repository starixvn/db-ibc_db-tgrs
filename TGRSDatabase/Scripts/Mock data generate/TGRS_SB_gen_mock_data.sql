SET XACT_ABORT ON;
SET NOCOUNT ON;
BEGIN TRANSACTION;

DECLARE @TargetDate DATETIME = '2025-07-13';
DECLARE @NumberOfTransactions INT = 50; -- Configurable number of mock transactions

DECLARE @SportTypeToGenerate INT = 1;
DECLARE @BetTypeToGenerate INT = NULL; -- Specific BetType to generate, if NULL, use random bet type from SBM
---
DECLARE @MatchIdToUse INT = NULL; -- The ID of the match to use, null to use random existing match on TargetDate, if no existing match then create new
DECLARE @ForceCreateNewMatch BIT = 1; -- If 1, then create new match even if existing match is found
---
DECLARE @LeagueIdToUse INT = 147230; -- The ID of the league to use (if matchIdToUse is NULL), null to use random league
DECLARE @HomeIdToUse INT = NULL; -- The ID of the home team to use (if matchIdToUse is NULL), null to use random home team
DECLARE @AwayIdToUse INT = NULL; -- The ID of the away team to use (if matchIdToUse is NULL), null to use random away team
---

BEGIN --calculate target table choice 
    DECLARE @BalanceUpDay SMALLDATETIME, @MoveBetsDay SMALLDATETIME;
    DECLARE @TargetTableChoice INT; -- 1 for _bk, 2 for _14, 3 for live/current

    DECLARE @tmpBUMBData TABLE (
        BUDay SMALLDATETIME,
        MBDay SMALLDATETIME
    );

    INSERT INTO @tmpBUMBData
    EXECUTE bodb02.dbo.Age_SelBalanceUpDay;

    SELECT TOP 1
        @BalanceUpDay = BUDay,
        @MoveBetsDay = MBDay
    FROM @tmpBUMBData;

    IF @TargetDate < @BalanceUpDay
    BEGIN
        SET @TargetTableChoice = 1;
        PRINT 'Date range targets _bk tables.';
    END
    ELSE IF @TargetDate >= @BalanceUpDay
        AND @TargetDate <= @MoveBetsDay
    BEGIN
        SET @TargetTableChoice = 2;
        PRINT 'Date range targets _14 tables.';
    END
    ELSE -- @TargetDate > @MoveBetsDay
    BEGIN
        SET @TargetTableChoice = 3;
        PRINT 'Date range targets live tables.';
    END;
END

-- Check for existing suitable match
PRINT 'Checking for existing completed soccer match on ' + CONVERT(VARCHAR, @TargetDate, 23) + '...';

IF @TargetTableChoice = 1
BEGIN
    SELECT TOP 1
        @MatchIdToUse = matchid
    FROM bodb_Archive.dbo.match_bk WITH (NOLOCK)
    WHERE eventdate = @TargetDate
        AND sporttype = 1
        AND eventstatus = 'completed'
        AND matchcode NOT LIKE '%hedge%'
        AND leagueid = @LeagueIdToUse
    ORDER BY NEWID();
END
ELSE IF @TargetTableChoice = 2
BEGIN
    SELECT TOP 1
        @MatchIdToUse = matchid
    FROM bodb02.dbo.match14 WITH (NOLOCK)
    WHERE eventdate = @TargetDate
        AND sporttype = 1
        AND eventstatus = 'completed'
        AND matchcode NOT LIKE '%hedge%'
        AND leagueid = @LeagueIdToUse
    ORDER BY NEWID();
END
ELSE -- @TargetTableChoice = 3
BEGIN
    SELECT TOP 1
        @MatchIdToUse = matchid
    FROM bodb02.dbo.match WITH (NOLOCK)
    WHERE eventdate = @TargetDate
        AND sporttype = 1
        AND eventstatus = 'completed'
        AND matchcode NOT LIKE '%hedge%'
        AND leagueid = @LeagueIdToUse
    ORDER BY NEWID();
END

-- Handle Match Creation or Use Existing
IF @MatchIdToUse IS NOT NULL AND @ForceCreateNewMatch = 0
BEGIN
    PRINT 'Found existing match with ID: ' + CAST(@MatchIdToUse AS VARCHAR) + '. Using this match.';
END
ELSE
BEGIN
    IF @ForceCreateNewMatch = 1
    BEGIN
        PRINT 'ForceCreateNewMatch is 1. Creating new match...';
    END
    ELSE
    BEGIN
        PRINT 'No suitable existing match found. Creating new match...';
    END

    IF @LeagueIdToUse IS NULL
    BEGIN
        SELECT TOP 1
            @LeagueIdToUse = leagueid
        FROM bodb02.dbo.league
        WHERE sporttype = 1
            AND leagueid > 0
        ORDER BY NEWID();
    END
    ELSE
    BEGIN
        -- Check if league exists
        IF NOT EXISTS (
            SELECT 1
            FROM bodb02.dbo.league
            WHERE leagueid = @LeagueIdToUse
        )
        BEGIN
            RAISERROR('League @LeagueIdToUse not found.', 16, 1);
            RETURN;
        END
    END

    IF @LeagueIdToUse IS NULL
    BEGIN
        RAISERROR('No active League found', 16, 1);
        RETURN;
    END

    DECLARE @LeagueNameToUse NVARCHAR(255);
    SELECT @LeagueNameToUse = leaguename
    FROM bodb02.dbo.league
    WHERE leagueid = @LeagueIdToUse;

    DECLARE @IsGeneratingPenaltyMatch BIT = 0;
    IF @LeagueNameToUse LIKE '%PENALTY%'
    BEGIN
        SET @IsGeneratingPenaltyMatch = 1;
        PRINT 'Generating penalty match for league: ' + @LeagueNameToUse;
    END

    -- Create match data using the centralized stored procedure
    EXEC bodb_tgrs.dbo.TGRS_SB_create_match_data 
        @TargetTableChoice = @TargetTableChoice,
        @SportType = @SportTypeToGenerate,
        @LeagueIdToUse = @LeagueIdToUse,
        @HomeIdToUse = @HomeIdToUse,
        @AwayIdToUse = @AwayIdToUse,
        @TargetDate = @TargetDate,
        @IsGeneratingPenaltyMatch = @IsGeneratingPenaltyMatch,
        @MatchIdToUse = @MatchIdToUse OUTPUT;
END;
-- End of match handling

-- Determine target assignment table
DECLARE @TargetAssignmentTableIsArchive BIT = 0;

IF @TargetDate < @BalanceUpDay
BEGIN
    SET @TargetAssignmentTableIsArchive = 1;
END

-- Check for existing assignments
DECLARE @AssignmentsExist BIT = 0;

PRINT 'Checking for existing assignments for MatchID: ' + CAST(@MatchIdToUse AS VARCHAR) + '...';

IF @TargetAssignmentTableIsArchive = 1
BEGIN
    IF EXISTS (
        SELECT 1
        FROM bodb_archive.dbo.Dot_Admin_Assignment_Trader_bk
        WHERE MatchId = @MatchIdToUse
        )
        SET @AssignmentsExist = 1;
END
ELSE
BEGIN
    IF EXISTS (
        SELECT 1
        FROM bodb02.dbo.Dot_Admin_Assignment_Trader
        WHERE MatchId = @MatchIdToUse
        )
        SET @AssignmentsExist = 1;
END

-- Handle Assignments
IF @AssignmentsExist = 1
BEGIN
    PRINT 'Found existing assignments for MatchID: ' + CAST(@MatchIdToUse AS VARCHAR) + '. Skipping assignment creation.';
END
ELSE
BEGIN
    PRINT 'No existing assignments found for MatchID: ' + CAST(@MatchIdToUse AS VARCHAR) + '. Creating new assignments...';
    -- Generate Trader Assignments using stored procedure
    EXEC bodb_tgrs.dbo.TGRS_SB_gen_trader_assignments
        @TargetDate = @TargetDate,
        @MatchIdToUse = @MatchIdToUse,
        @BalanceUpDay = @BalanceUpDay;
END;
-- End of assignment handling

-- Generate Bet Transactions using stored procedure
EXEC bodb_tgrs.dbo.TGRS_SB_gen_bet_transactions
    @TargetTableChoice = @TargetTableChoice,
    @TargetDate = @TargetDate,
    @MatchIdToUse = @MatchIdToUse,
    @NumberOfTransactions = @NumberOfTransactions,
    @BetTypeToGenerate = @BetTypeToGenerate;

COMMIT TRANSACTION;

-- Execute the stored procedure for SOCCER to populate the TGRS data
EXEC bodb_tgrs.dbo.Task_StagingDataTGRS @Debug = 1,
    @GenerateFromDate = @TargetDate,
    @GenerateToDate = @TargetDate;

PRINT 'Executed Task_StagingDataTGRS for the target date.';
PRINT 'Script finished.';
