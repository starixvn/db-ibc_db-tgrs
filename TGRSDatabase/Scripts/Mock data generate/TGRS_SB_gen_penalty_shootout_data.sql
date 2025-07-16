USE bodb_tgrs
GO

CREATE OR ALTER PROCEDURE [dbo].[TGRS_SB_gen_penalty_shootout_data]
    @MatchId INT,
    @TargetTableChoice INT, -- 1 for _bk, 2 for _14, 3 for live
    @HomePenaltyScore INT OUTPUT,
    @AwayPenaltyScore INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @PenaltyMatchDetailSQL NVARCHAR(MAX) = NULL;
    DECLARE @PenaltyMatchDetailSQLTemplate NVARCHAR(MAX) = '
        INSERT INTO [[table_name_here]] (
            matchid,
            resourceid,
            homevalue
        )
        VALUES (
            @MatchId,
            @ResourceId,
            @HomeValue
        );
    ';
    
    -- Set target table based on choice
    IF @TargetTableChoice = 1
    BEGIN
        SET @PenaltyMatchDetailSQL = REPLACE(@PenaltyMatchDetailSQLTemplate, '[[table_name_here]]', 'bodb_Archive.dbo.ResultDetail_BK');
    END
    ELSE IF @TargetTableChoice = 2
    BEGIN
        SET @PenaltyMatchDetailSQL = REPLACE(@PenaltyMatchDetailSQLTemplate, '[[table_name_here]]', 'bodb02.dbo.ResultDetail14');
    END
    ELSE -- @TargetTableChoice = 3
    BEGIN
        SET @PenaltyMatchDetailSQL = REPLACE(@PenaltyMatchDetailSQLTemplate, '[[table_name_here]]', 'bodb02.dbo.ResultDetail');
    END
    
    -- Generate randomized penalty shootout data
    DECLARE @PenaltyRounds TABLE (
        RoundNumber INT,
        HomeResourceID NVARCHAR(10),
        AwayResourceID NVARCHAR(10),
        HomeResult NVARCHAR(10),
        AwayResult NVARCHAR(10)
    );
    
    -- Generate random penalty shootout (realistic football scenario)
    DECLARE @Round INT = 1;
    DECLARE @HomeScore INT = 0;
    DECLARE @AwayScore INT = 0;
    DECLARE @MatchDecided BIT = 0;
    DECLARE @MaxRounds INT = 5; -- Minimum 5 rounds
    DECLARE @HomeResult NVARCHAR(10);
    DECLARE @AwayResult NVARCHAR(10);
    DECLARE @HomeResourceID NVARCHAR(10);
    DECLARE @AwayResourceID NVARCHAR(10);
    
    -- 20% chance to force a sudden death scenario (tied after 5 rounds)
    DECLARE @ForceSuddenDeath BIT = 0;
    IF (ABS(CHECKSUM(NEWID())) % 100) < 20
    BEGIN
        SET @ForceSuddenDeath = 1;
        PRINT 'Forcing sudden death scenario...';
    END
    
    -- Generate penalty results round by round
    WHILE @Round <= @MaxRounds OR (@Round <= 10 AND @MatchDecided = 0)
    BEGIN
        -- Fixed resource ID prefixes: '381' for Away, '382' for Home
        SET @HomeResourceID = '382' + RIGHT('00' + CAST(@Round AS VARCHAR), 2);
        SET @AwayResourceID = '381' + RIGHT('00' + CAST(@Round AS VARCHAR), 2);
        
        -- Realistic penalty success rate: ~75% for home, ~70% for away
        -- Adjust rates for sudden death scenarios
        DECLARE @HomeSuccessRate INT = 75;
        DECLARE @AwaySuccessRate INT = 70;
        
        -- In sudden death scenarios, equalize success rates to increase ties
        IF @ForceSuddenDeath = 1 AND @Round <= 5
        BEGIN
            SET @HomeSuccessRate = 72;
            SET @AwaySuccessRate = 72;
        END
        
        -- Special logic for round 5 in forced sudden death
        IF @ForceSuddenDeath = 1 AND @Round = 5
        BEGIN
            -- Adjust final round to ensure tie
            DECLARE @ScoreDiff INT = @HomeScore - @AwayScore;
            IF @ScoreDiff > 0
            BEGIN
                -- Home is ahead, make home miss and away score
                SET @HomeSuccessRate = 10;
                SET @AwaySuccessRate = 90;
            END
            ELSE IF @ScoreDiff < 0
            BEGIN
                -- Away is ahead, make away miss and home score
                SET @HomeSuccessRate = 90;
                SET @AwaySuccessRate = 10;
            END
            -- If tied, use normal rates
        END
        
        IF @MatchDecided = 0
        BEGIN
            -- Home team penalty
            IF (ABS(CHECKSUM(NEWID())) % 100) < @HomeSuccessRate
            BEGIN
                SET @HomeResult = 'S';
                SET @HomeScore = @HomeScore + 1;
            END
            ELSE
            BEGIN
                SET @HomeResult = 'M';
            END
            
            -- Check if match is decided after home penalty
            IF @Round >= 5
            BEGIN
                IF @Round = 5
                BEGIN
                    -- In round 5, calculate if away team can still catch up
                    DECLARE @RemainingRounds INT = @MaxRounds - @Round;
                    DECLARE @AwayMaxPossible INT = @AwayScore + @RemainingRounds;
                    
                    -- Match decided if away team can't catch up
                    IF @HomeScore > @AwayMaxPossible
                    BEGIN
                        SET @MatchDecided = 1;
                        SET @AwayResult = 'NT'; -- Away doesn't take penalty
                    END
                END
            END
            
            -- Away team penalty (only if match not decided)
            IF @MatchDecided = 0
            BEGIN
                IF (ABS(CHECKSUM(NEWID())) % 100) < @AwaySuccessRate
                BEGIN
                    SET @AwayResult = 'S';
                    SET @AwayScore = @AwayScore + 1;
                END
                ELSE
                BEGIN
                    SET @AwayResult = 'M';
                END
                
                -- Check if match is decided after away penalty
                IF @Round >= 5
                BEGIN
                    IF @Round = 5
                    BEGIN
                        -- After 5 rounds, check for sudden death
                        IF @HomeScore = @AwayScore
                        BEGIN
                            SET @MaxRounds = 10; -- Extend to potential sudden death
                            PRINT 'Scores tied after 5 rounds (' + CAST(@HomeScore AS VARCHAR) + '-' + CAST(@AwayScore AS VARCHAR) + '), entering sudden death...';
                        END
                        ELSE
                        BEGIN
                            -- Match decided in regular 5 rounds
                            SET @MatchDecided = 1;
                        END
                    END
                    ELSE IF @Round > 5
                    BEGIN
                        -- Sudden death: first team to have advantage wins
                        IF @HomeScore <> @AwayScore
                        BEGIN
                            SET @MatchDecided = 1;
                            PRINT 'Sudden death decided in round ' + CAST(@Round AS VARCHAR) + ': ' + CAST(@HomeScore AS VARCHAR) + '-' + CAST(@AwayScore AS VARCHAR);
                        END
                    END
                END
            END
        END
        
        -- Insert this round's results
        INSERT INTO @PenaltyRounds VALUES 
            (@Round, @HomeResourceID, @AwayResourceID, @HomeResult, @AwayResult);
        
        -- Break immediately if match is decided
        IF @MatchDecided = 1 BREAK;
        
        SET @Round = @Round + 1;
        
        -- Safety break for sudden death
        IF @Round > 10 BREAK;
    END
    
    -- Set OUTPUT parameters
    SET @HomePenaltyScore = @HomeScore;
    SET @AwayPenaltyScore = @AwayScore;
    
    DECLARE @SuddenDeathText NVARCHAR(50) = '';
    IF @Round - 1 > 5
    BEGIN
        SET @SuddenDeathText = ' - SUDDEN DEATH';
    END
    
    -- Insert Home team penalty results
    DECLARE @CurrentRound INT;
    DECLARE home_cursor CURSOR FOR 
        SELECT RoundNumber, HomeResourceID, HomeResult FROM @PenaltyRounds;
    
    OPEN home_cursor;
    FETCH NEXT FROM home_cursor INTO @CurrentRound, @HomeResourceID, @HomeResult;
    
    WHILE @@FETCH_STATUS = 0
    BEGIN
        EXEC sp_executesql @PenaltyMatchDetailSQL
        , N'@MatchId INT, @ResourceId NVARCHAR(10), @HomeValue NVARCHAR(10)'
        , @MatchId, @HomeResourceID, @HomeResult;
        
        FETCH NEXT FROM home_cursor INTO @CurrentRound, @HomeResourceID, @HomeResult;
    END;
    
    CLOSE home_cursor;
    DEALLOCATE home_cursor;
    
    -- Insert Away team penalty results
    DECLARE away_cursor CURSOR FOR 
        SELECT RoundNumber, AwayResourceID, AwayResult FROM @PenaltyRounds;
    
    OPEN away_cursor;
    FETCH NEXT FROM away_cursor INTO @CurrentRound, @AwayResourceID, @AwayResult;
    
    WHILE @@FETCH_STATUS = 0
    BEGIN
        EXEC sp_executesql @PenaltyMatchDetailSQL
        , N'@MatchId INT, @ResourceId NVARCHAR(10), @HomeValue NVARCHAR(10)'
        , @MatchId, @AwayResourceID, @AwayResult;
        
        FETCH NEXT FROM away_cursor INTO @CurrentRound, @AwayResourceID, @AwayResult;
    END;
    
    CLOSE away_cursor;
    DEALLOCATE away_cursor;
    
    PRINT 'Generated penalty shootout data for match: ' + CAST(@MatchId AS VARCHAR) + ' (Home ' + CAST(@HomeScore AS VARCHAR) + ' - ' + CAST(@AwayScore AS VARCHAR) + ' Away)' + @SuddenDeathText;
END
GO 