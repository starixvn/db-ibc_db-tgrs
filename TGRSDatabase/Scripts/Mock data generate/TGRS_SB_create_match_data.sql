USE bodb_tgrs
GO

CREATE OR ALTER PROCEDURE [dbo].[TGRS_SB_create_match_data]
    @TargetTableChoice INT, -- 1 for _bk, 2 for _14, 3 for live
    @LeagueIdToUse INT,
    @HomeIdToUse INT = NULL,
    @AwayIdToUse INT = NULL,
    @TargetDate DATETIME,
    @IsGeneratingPenaltyMatch BIT,
    @MatchIdToUse INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @ErrorMessage NVARCHAR(MAX) = NULL;

    DECLARE @SportType INT;
    SELECT @SportType = SportType
    FROM bodb02.dbo.league
    WHERE leagueid = @LeagueIdToUse;

    IF @SportType IS NULL
    BEGIN
        SET @ErrorMessage = 'SportType not found for LeagueID: ' + CAST(@LeagueIdToUse AS VARCHAR);
        THROW 51000, @ErrorMessage, 1;
        RETURN;
    END
    
    -- Generate teams if not provided
    IF @HomeIdToUse IS NULL AND @AwayIdToUse IS NULL 
    BEGIN
        IF @IsGeneratingPenaltyMatch = 0
        BEGIN
            SELECT TOP 2
                @HomeIdToUse = CASE WHEN T.RowNum = 1 THEN T.teamid ELSE @HomeIdToUse END,
                @AwayIdToUse = CASE WHEN T.RowNum = 2 THEN T.teamid ELSE @AwayIdToUse END
            FROM (
                SELECT
                    teamid,
                    ROW_NUMBER() OVER (ORDER BY NEWID()) AS RowNum
                FROM bodb02.dbo.team
                WHERE SportType = @SportType
                    AND teamid > 0
                    AND teamname NOT LIKE '%(PEN) '
                ) AS T
            WHERE T.RowNum <= 2;
        END
        ELSE
        BEGIN
            SELECT TOP 2
                @HomeIdToUse = CASE WHEN T.RowNum = 1 THEN T.teamid ELSE @HomeIdToUse END,
                @AwayIdToUse = CASE WHEN T.RowNum = 2 THEN T.teamid ELSE @AwayIdToUse END
            FROM (
                SELECT
                    teamid,
                    ROW_NUMBER() OVER (ORDER BY NEWID()) AS RowNum
                FROM bodb02.dbo.team
                WHERE SportType = @SportType
                    AND teamid > 0
                    AND teamname LIKE '%(PEN) '
                ) AS T
            WHERE T.RowNum <= 2;
        END
    END
    ELSE
    BEGIN
        -- Check valid home and away team
        IF @HomeIdToUse IS NOT NULL AND NOT EXISTS (
            SELECT 1
            FROM bodb02.dbo.team
            WHERE teamid = @HomeIdToUse
                AND SportType = @SportType
        )
        BEGIN
            SET @ErrorMessage = 'Home team ' + CAST(@HomeIdToUse AS VARCHAR) + ' not valid.';
            THROW 51000, @ErrorMessage, 1;
            RETURN;
        END
        
        IF @AwayIdToUse IS NOT NULL AND NOT EXISTS (
            SELECT 1
            FROM bodb02.dbo.team
            WHERE teamid = @AwayIdToUse
                AND SportType = @SportType
        )
        BEGIN
            SET @ErrorMessage = 'Away team ' + CAST(@AwayIdToUse AS VARCHAR) + ' not valid.';
            THROW 51000, @ErrorMessage, 1;
            RETURN;
        END
    END

    IF @HomeIdToUse IS NULL
        OR @AwayIdToUse IS NULL
        OR @HomeIdToUse = @AwayIdToUse
    BEGIN
        SET @ErrorMessage = 'Could not find two distinct active teams for the specified league and sport type';
        THROW 51000, @ErrorMessage, 1;
        RETURN;
    END
    
    -- Generate realistic scores for parent match (main match + extra time, no penalties)
    DECLARE @HTHomeScore INT = FLOOR(RAND() * 4); -- 0-3 goals at half-time
    DECLARE @HTAwayScore INT = FLOOR(RAND() * 4); -- 0-3 goals at half-time
    
    -- Final scores: half-time + additional goals (0-2 more each)
    DECLARE @FinalHomeScore INT = @HTHomeScore + FLOOR(RAND() * 3); -- 0-2 more goals
    DECLARE @FinalAwayScore INT = @HTAwayScore + FLOOR(RAND() * 3); -- 0-2 more goals
    
    -- For penalty matches, ensure main match ends in draw (before penalties)
    IF @IsGeneratingPenaltyMatch = 1
    BEGIN
        -- Force a draw in parent match final scores
        SET @FinalAwayScore = @FinalHomeScore;
    END
    
    DECLARE @ParentMatchId INT = NULL;
    DECLARE @NextAvailableMatchId INT = NULL;
    DECLARE @InsertedMatchIdTable TABLE(matchid INT);
    DECLARE @InsertMatchSQL NVARCHAR(MAX) = NULL;
    DECLARE @InsertMatchSQLTemplate NVARCHAR(MAX) = '
        INSERT INTO [[table_name_here]] (
            matchid,
            leagueid,
            homeid,
            awayid,
            eventdate,
            eventstatus,
            betstatus,
            creator,
            matchcode,
            sporttype,
            homeid2,
            awayid2,
            DisplayMode,
            LeaguePatternID,
            HomeDisplayPatternID,
            AwayDisplayPatternID,
            IsNeutral,
            ParentID,
            hthomescore,
            htawayscore,
            finalhomescore,
            finalawayscore,
            livehomescore,
            liveawayscore,
            kickofftime
        )
        OUTPUT INSERTED.matchid
        VALUES (
            @NextAvailableMatchId,
            @LeagueIdToUse,
            @HomeIdToUse,
            @AwayIdToUse,
            @TargetDate,
            ''completed'',
            ''1-0,2-1'',
            2929, -- creator
            ''TGRS_SB_create_match_data_'' + CONVERT(VARCHAR, @TargetDate, 112), -- matchcode
            @SportType,
            0, -- homeid2
            0, -- awayid2
            0, -- DisplayMode
            0, -- LeaguePatternID
            0, -- HomeDisplayPatternID
            0, -- AwayDisplayPatternID
            0, -- IsNeutral
            @ParentID,
            @HTHomeScoreParam, -- hthomescore (parameter)
            @HTAwayScoreParam, -- htawayscore (parameter)
            @FinalHomeScore, -- finalhomescore
            @FinalAwayScore, -- finalawayscore
            @FinalHomeScore, -- livehomescore (same as final for completed match)
            @FinalAwayScore, -- liveawayscore (same as final for completed match)
            DATEADD(MINUTE, FLOOR(RAND() * 480), @TargetDate) -- kickofftime
        );
    '
    DECLARE @HomePenaltyScore INT, @AwayPenaltyScore INT;

    -- Create new match record conditionally based on @TargetTableChoice
    IF @TargetTableChoice = 1 -- Target _bk
    BEGIN
        SET @NextAvailableMatchId = ISNULL((SELECT MAX(matchid) FROM bodb_Archive.dbo.match_bk), 0) + 1;
        SET @InsertMatchSQL = REPLACE(@InsertMatchSQLTemplate, '[[table_name_here]]', 'bodb_Archive.dbo.match_bk');
        EXEC sp_executesql @InsertMatchSQL
        , N'@NextAvailableMatchId INT, @LeagueIdToUse INT, @HomeIdToUse INT, @AwayIdToUse INT, @TargetDate DATETIME, @ParentID INT, @HTHomeScoreParam INT, @HTAwayScoreParam INT, @FinalHomeScore INT, @FinalAwayScore INT, @SportType INT'
        , @NextAvailableMatchId, @LeagueIdToUse, @HomeIdToUse, @AwayIdToUse, @TargetDate, NULL, @HTHomeScore, @HTAwayScore, @FinalHomeScore, @FinalAwayScore, @SportType;

        SET @MatchIdToUse = @NextAvailableMatchId;
        PRINT 'Created parent Match in bodb_Archive.dbo.match_bk with ID: ' + CAST(@MatchIdToUse AS VARCHAR);

        -- 2 penalty matches are child of parent match
        IF @IsGeneratingPenaltyMatch = 1
        BEGIN
            SET @ParentMatchId = @MatchIdToUse;
            DELETE FROM @InsertedMatchIdTable;
            SET @MatchIdToUse = NULL;

            BEGIN TRY
                -- Create child matches using same template with half-time scores = 0
                SET @NextAvailableMatchId = @NextAvailableMatchId + 1;
                INSERT INTO @InsertedMatchIdTable
                EXEC sp_executesql @InsertMatchSQL
                , N'@NextAvailableMatchId INT, @LeagueIdToUse INT, @HomeIdToUse INT, @AwayIdToUse INT, @TargetDate DATETIME, @ParentID INT, @HTHomeScoreParam INT, @HTAwayScoreParam INT, @FinalHomeScore INT, @FinalAwayScore INT, @SportType INT'
                , @NextAvailableMatchId, @LeagueIdToUse, @HomeIdToUse, @AwayIdToUse, @TargetDate, @ParentMatchId, 0, 0, @FinalHomeScore, @FinalAwayScore, @SportType;
                SET @MatchIdToUse = @NextAvailableMatchId;

                SET @NextAvailableMatchId = @NextAvailableMatchId + 1;
                INSERT INTO @InsertedMatchIdTable
                EXEC sp_executesql @InsertMatchSQL
                , N'@NextAvailableMatchId INT, @LeagueIdToUse INT, @HomeIdToUse INT, @AwayIdToUse INT, @TargetDate DATETIME, @ParentID INT, @HTHomeScoreParam INT, @HTAwayScoreParam INT, @FinalHomeScore INT, @FinalAwayScore INT, @SportType INT'
                , @NextAvailableMatchId, @LeagueIdToUse, @HomeIdToUse, @AwayIdToUse, @TargetDate, @ParentMatchId, 0, 0, @FinalHomeScore, @FinalAwayScore, @SportType;
                SET @MatchIdToUse = @NextAvailableMatchId;

                PRINT 'Created penalty Match in bodb_Archive.dbo.match_bk with ID: ' + CAST(@MatchIdToUse AS VARCHAR);
                
                -- Generate penalty shootout data and get final scores
                EXEC bodb_tgrs.dbo.TGRS_SB_gen_penalty_shootout_data @MatchIdToUse, @TargetTableChoice, @HomePenaltyScore OUTPUT, @AwayPenaltyScore OUTPUT;
                
                -- Update child match with penalty final scores
                UPDATE bodb_Archive.dbo.match_bk 
                SET finalhomescore = @HomePenaltyScore,
                    finalawayscore = @AwayPenaltyScore,
                    livehomescore = @HomePenaltyScore,
                    liveawayscore = @AwayPenaltyScore
                WHERE matchid = @MatchIdToUse;
            END TRY
            BEGIN CATCH
                PRINT 'Something wrong with dynamic SQL execution. Please check the error message.';
                THROW;
            END CATCH
        END
    END
    ELSE IF @TargetTableChoice = 2 -- Target _14
    BEGIN
        SET @NextAvailableMatchId = ISNULL((SELECT MAX(matchid) FROM bodb02.dbo.match14), 0) + 1;
        SET @InsertMatchSQL = REPLACE(@InsertMatchSQLTemplate, '[[table_name_here]]', 'bodb02.dbo.match14');
        EXEC sp_executesql @InsertMatchSQL
        , N'@NextAvailableMatchId INT, @LeagueIdToUse INT, @HomeIdToUse INT, @AwayIdToUse INT, @TargetDate DATETIME, @ParentID INT, @HTHomeScoreParam INT, @HTAwayScoreParam INT, @FinalHomeScore INT, @FinalAwayScore INT, @SportType INT'
        , @NextAvailableMatchId, @LeagueIdToUse, @HomeIdToUse, @AwayIdToUse, @TargetDate, NULL, @HTHomeScore, @HTAwayScore, @FinalHomeScore, @FinalAwayScore, @SportType;

        SET @MatchIdToUse = @NextAvailableMatchId;
        PRINT 'Created parent Match in bodb02.dbo.match14 with ID: ' + CAST(@MatchIdToUse AS VARCHAR);

        -- 2 penalty matches are child of parent match
        IF @IsGeneratingPenaltyMatch = 1
        BEGIN
            SET @ParentMatchId = @MatchIdToUse;
            DELETE FROM @InsertedMatchIdTable;
            SET @MatchIdToUse = NULL;

            BEGIN TRY
                -- Create child matches using same template with half-time scores = 0
                SET @NextAvailableMatchId = @NextAvailableMatchId + 1;
                INSERT INTO @InsertedMatchIdTable
                EXEC sp_executesql @InsertMatchSQL
                , N'@NextAvailableMatchId INT, @LeagueIdToUse INT, @HomeIdToUse INT, @AwayIdToUse INT, @TargetDate DATETIME, @ParentID INT, @HTHomeScoreParam INT, @HTAwayScoreParam INT, @FinalHomeScore INT, @FinalAwayScore INT, @SportType INT'
                , @NextAvailableMatchId, @LeagueIdToUse, @HomeIdToUse, @AwayIdToUse, @TargetDate, @ParentMatchId, 0, 0, @FinalHomeScore, @FinalAwayScore, @SportType;
                SET @MatchIdToUse = @NextAvailableMatchId;

                SET @NextAvailableMatchId = @NextAvailableMatchId + 1;
                INSERT INTO @InsertedMatchIdTable
                EXEC sp_executesql @InsertMatchSQL
                , N'@NextAvailableMatchId INT, @LeagueIdToUse INT, @HomeIdToUse INT, @AwayIdToUse INT, @TargetDate DATETIME, @ParentID INT, @HTHomeScoreParam INT, @HTAwayScoreParam INT, @FinalHomeScore INT, @FinalAwayScore INT, @SportType INT'
                , @NextAvailableMatchId, @LeagueIdToUse, @HomeIdToUse, @AwayIdToUse, @TargetDate, @ParentMatchId, 0, 0, @FinalHomeScore, @FinalAwayScore, @SportType;
                SET @MatchIdToUse = @NextAvailableMatchId;

                PRINT 'Created penalty Match in bodb02.dbo.match14 with ID: ' + CAST(@MatchIdToUse AS VARCHAR);
                
                -- Generate penalty shootout data and get final scores
                EXEC bodb_tgrs.dbo.TGRS_SB_gen_penalty_shootout_data @MatchIdToUse, @TargetTableChoice, @HomePenaltyScore OUTPUT, @AwayPenaltyScore OUTPUT;
                
                -- Update child match with penalty final scores
                UPDATE bodb02.dbo.match14 
                SET finalhomescore = @HomePenaltyScore,
                    finalawayscore = @AwayPenaltyScore,
                    livehomescore = @HomePenaltyScore,
                    liveawayscore = @AwayPenaltyScore
                WHERE matchid = @MatchIdToUse;
            END TRY
            BEGIN CATCH
                PRINT 'Something wrong with dynamic SQL execution. Please check the error message.';
                THROW;
            END CATCH
        END
    END
    ELSE -- TargetTableChoice = 3 (live)
    BEGIN
        --Remove "@NextAvailableMatchId," and "matchid," from the INSERT INTO statement. match table is auto-incremented.
        SET @InsertMatchSQL = REPLACE(@InsertMatchSQLTemplate, '[[table_name_here]]', 'bodb02.dbo.match');
        SET @InsertMatchSQL = REPLACE(@InsertMatchSQL, '@NextAvailableMatchId,', '');
        SET @InsertMatchSQL = REPLACE(@InsertMatchSQL, 'matchid,', '');

        INSERT INTO @InsertedMatchIdTable
        EXEC sp_executesql @InsertMatchSQL
        , N'@LeagueIdToUse INT, @HomeIdToUse INT, @AwayIdToUse INT, @TargetDate DATETIME, @ParentID INT, @HTHomeScoreParam INT, @HTAwayScoreParam INT, @FinalHomeScore INT, @FinalAwayScore INT, @SportType INT'
        , @LeagueIdToUse, @HomeIdToUse, @AwayIdToUse, @TargetDate, NULL, @HTHomeScore, @HTAwayScore, @FinalHomeScore, @FinalAwayScore, @SportType;

        SET @MatchIdToUse = (SELECT TOP 1 matchid FROM @InsertedMatchIdTable);
        PRINT 'Created parent Match in bodb02.dbo.match with ID: ' + CAST(@MatchIdToUse AS VARCHAR);

        -- 2 penalty matches are child of parent match
        IF @IsGeneratingPenaltyMatch = 1
        BEGIN
            SET @ParentMatchId = @MatchIdToUse;
            DELETE FROM @InsertedMatchIdTable;
            SET @MatchIdToUse = NULL;

            BEGIN TRY
                -- Create child matches using same template with half-time scores = 0
                INSERT INTO @InsertedMatchIdTable
                EXEC sp_executesql @InsertMatchSQL
                , N'@LeagueIdToUse INT, @HomeIdToUse INT, @AwayIdToUse INT, @TargetDate DATETIME, @ParentID INT, @HTHomeScoreParam INT, @HTAwayScoreParam INT, @FinalHomeScore INT, @FinalAwayScore INT, @SportType INT'
                , @LeagueIdToUse, @HomeIdToUse, @AwayIdToUse, @TargetDate, @ParentMatchId, 0, 0, @FinalHomeScore, @FinalAwayScore, @SportType;

                INSERT INTO @InsertedMatchIdTable
                EXEC sp_executesql @InsertMatchSQL
                , N'@LeagueIdToUse INT, @HomeIdToUse INT, @AwayIdToUse INT, @TargetDate DATETIME, @ParentID INT, @HTHomeScoreParam INT, @HTAwayScoreParam INT, @FinalHomeScore INT, @FinalAwayScore INT, @SportType INT'
                , @LeagueIdToUse, @HomeIdToUse, @AwayIdToUse, @TargetDate, @ParentMatchId, 0, 0, @FinalHomeScore, @FinalAwayScore, @SportType;

                SET @MatchIdToUse = (SELECT TOP 1 matchid FROM @InsertedMatchIdTable);
                PRINT 'Using penalty match in bodb02.dbo.match with ID: ' + CAST(@MatchIdToUse AS VARCHAR);

                -- Generate penalty shootout data and get final scores
                EXEC bodb_tgrs.dbo.TGRS_SB_gen_penalty_shootout_data @MatchIdToUse, @TargetTableChoice, @HomePenaltyScore OUTPUT, @AwayPenaltyScore OUTPUT;
                
                -- Update child match with penalty final scores
                UPDATE bodb02.dbo.match 
                SET finalhomescore = @HomePenaltyScore,
                    finalawayscore = @AwayPenaltyScore,
                    livehomescore = @HomePenaltyScore,
                    liveawayscore = @AwayPenaltyScore
                WHERE matchid = @MatchIdToUse;
            END TRY
            BEGIN CATCH
                PRINT 'Something wrong with dynamic SQL execution. Please check the error message.';
                THROW;
            END CATCH
        END
    END;
    
    PRINT 'Match creation completed. Final MatchID: ' + CAST(@MatchIdToUse AS VARCHAR);
END
GO 