USE bodb_tgrs
GO

CREATE OR ALTER PROCEDURE [dbo].[TGRS_SB_create_match_data]
    @TargetTableChoice INT, -- 1 for _bk, 2 for _14, 3 for live
    @SportType INT,
    @LeagueIdToUse INT,
    @HomeIdToUse INT,
    @AwayIdToUse INT,
    @TargetDate DATETIME,
    @IsGeneratingPenaltyMatch BIT,
    @MatchIdToUse INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    
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
            liveawayscore
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
            FLOOR(RAND() * 3), -- hthomescore
            FLOOR(RAND() * 3), -- htawayscore
            FLOOR(RAND() * 5), -- finalhomescore
            FLOOR(RAND() * 5), -- finalawayscore
            FLOOR(RAND() * 2), -- livehomescore
            FLOOR(RAND() * 2) -- liveawayscore
        );
    '

    -- Create new match record conditionally based on @TargetTableChoice
    IF @TargetTableChoice = 1 -- Target _bk
    BEGIN
        SET @NextAvailableMatchId = ISNULL((SELECT MAX(matchid) FROM bodb_Archive.dbo.match_bk), 0) + 1;
        SET @InsertMatchSQL = REPLACE(@InsertMatchSQLTemplate, '[[table_name_here]]', 'bodb_Archive.dbo.match_bk');
        EXEC sp_executesql @InsertMatchSQL
        , N'@NextAvailableMatchId INT, @LeagueIdToUse INT, @HomeIdToUse INT, @AwayIdToUse INT, @TargetDate DATETIME, @ParentID INT'
        , @NextAvailableMatchId, @LeagueIdToUse, @HomeIdToUse, @AwayIdToUse, @TargetDate, NULL;

        SET @MatchIdToUse = @NextAvailableMatchId;
        PRINT 'Created parent Match in bodb_Archive.dbo.match_bk with ID: ' + CAST(@MatchIdToUse AS VARCHAR);

        -- 2 penalty matches are child of parent match
        IF @IsGeneratingPenaltyMatch = 1
        BEGIN
            SET @ParentMatchId = @MatchIdToUse;
            DELETE FROM @InsertedMatchIdTable;
            SET @MatchIdToUse = NULL;

            BEGIN TRY
                SET @NextAvailableMatchId = @NextAvailableMatchId + 1;
                INSERT INTO @InsertedMatchIdTable
                EXEC sp_executesql @InsertMatchSQL
                , N'@NextAvailableMatchId INT, @LeagueIdToUse INT, @SportType INT, @HomeIdToUse INT, @AwayIdToUse INT, @TargetDate DATETIME, @ParentID INT'
                , @NextAvailableMatchId, @LeagueIdToUse, @SportType, @HomeIdToUse, @AwayIdToUse, @TargetDate, @ParentMatchId;
                SET @MatchIdToUse = @NextAvailableMatchId;

                SET @NextAvailableMatchId = @NextAvailableMatchId + 1;
                INSERT INTO @InsertedMatchIdTable
                EXEC sp_executesql @InsertMatchSQL
                , N'@NextAvailableMatchId INT, @LeagueIdToUse INT, @SportType INT, @HomeIdToUse INT, @AwayIdToUse INT, @TargetDate DATETIME, @ParentID INT'
                , @NextAvailableMatchId, @LeagueIdToUse, @SportType, @HomeIdToUse, @AwayIdToUse, @TargetDate, @ParentMatchId;
                SET @MatchIdToUse = @NextAvailableMatchId;

                PRINT 'Created penalty Match in bodb_Archive.dbo.match_bk with ID: ' + CAST(@MatchIdToUse AS VARCHAR);
                
                -- Generate penalty shootout data
                EXEC bodb_tgrs.dbo.TGRS_SB_gen_penalty_shootout_data @MatchIdToUse, @TargetTableChoice;
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
        , N'@NextAvailableMatchId INT, @LeagueIdToUse INT, @SportType INT, @HomeIdToUse INT, @AwayIdToUse INT, @TargetDate DATETIME, @ParentID INT'
        , @NextAvailableMatchId, @LeagueIdToUse, @SportType, @HomeIdToUse, @AwayIdToUse, @TargetDate, NULL;

        SET @MatchIdToUse = @NextAvailableMatchId;
        PRINT 'Created parent Match in bodb02.dbo.match14 with ID: ' + CAST(@MatchIdToUse AS VARCHAR);

        -- 2 penalty matches are child of parent match
        IF @IsGeneratingPenaltyMatch = 1
        BEGIN
            SET @ParentMatchId = @MatchIdToUse;
            DELETE FROM @InsertedMatchIdTable;
            SET @MatchIdToUse = NULL;

            BEGIN TRY
                SET @NextAvailableMatchId = @NextAvailableMatchId + 1;
                INSERT INTO @InsertedMatchIdTable
                EXEC sp_executesql @InsertMatchSQL
                , N'@NextAvailableMatchId INT, @LeagueIdToUse INT, @SportType INT, @HomeIdToUse INT, @AwayIdToUse INT, @TargetDate DATETIME, @ParentID INT'
                , @NextAvailableMatchId, @LeagueIdToUse, @SportType, @HomeIdToUse, @AwayIdToUse, @TargetDate, @ParentMatchId;
                SET @MatchIdToUse = @NextAvailableMatchId;

                SET @NextAvailableMatchId = @NextAvailableMatchId + 1;
                INSERT INTO @InsertedMatchIdTable
                EXEC sp_executesql @InsertMatchSQL
                , N'@NextAvailableMatchId INT, @LeagueIdToUse INT, @SportType INT, @HomeIdToUse INT, @AwayIdToUse INT, @TargetDate DATETIME, @ParentID INT'
                , @NextAvailableMatchId, @LeagueIdToUse, @SportType, @HomeIdToUse, @AwayIdToUse, @TargetDate, @ParentMatchId;
                SET @MatchIdToUse = @NextAvailableMatchId;

                PRINT 'Created penalty Match in bodb02.dbo.match14 with ID: ' + CAST(@MatchIdToUse AS VARCHAR);
                
                -- Generate penalty shootout data
                EXEC bodb_tgrs.dbo.TGRS_SB_gen_penalty_shootout_data @MatchIdToUse, @TargetTableChoice;
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
        , N'@LeagueIdToUse INT, @SportType INT, @HomeIdToUse INT, @AwayIdToUse INT, @TargetDate DATETIME, @ParentID INT'
        , @LeagueIdToUse, @SportType, @HomeIdToUse, @AwayIdToUse, @TargetDate, NULL;

        SET @MatchIdToUse = (SELECT TOP 1 matchid FROM @InsertedMatchIdTable);
        PRINT 'Created parent Match in bodb02.dbo.match with ID: ' + CAST(@MatchIdToUse AS VARCHAR);

        -- 2 penalty matches are child of parent match
        IF @IsGeneratingPenaltyMatch = 1
        BEGIN
            SET @ParentMatchId = @MatchIdToUse;
            DELETE FROM @InsertedMatchIdTable;
            SET @MatchIdToUse = NULL;

            BEGIN TRY
                INSERT INTO @InsertedMatchIdTable
                EXEC sp_executesql @InsertMatchSQL
                , N'@LeagueIdToUse INT, @SportType INT, @HomeIdToUse INT, @AwayIdToUse INT, @TargetDate DATETIME, @ParentID INT'
                , @LeagueIdToUse, @SportType, @HomeIdToUse, @AwayIdToUse, @TargetDate, @ParentMatchId;

                INSERT INTO @InsertedMatchIdTable
                EXEC sp_executesql @InsertMatchSQL
                , N'@LeagueIdToUse INT, @SportType INT, @HomeIdToUse INT, @AwayIdToUse INT, @TargetDate DATETIME, @ParentID INT'
                , @LeagueIdToUse, @SportType, @HomeIdToUse, @AwayIdToUse, @TargetDate, @ParentMatchId;

                SET @MatchIdToUse = (SELECT TOP 1 matchid FROM @InsertedMatchIdTable);
                PRINT 'Using penalty match in bodb02.dbo.match with ID: ' + CAST(@MatchIdToUse AS VARCHAR);

                -- Generate penalty shootout data
                EXEC bodb_tgrs.dbo.TGRS_SB_gen_penalty_shootout_data @MatchIdToUse, @TargetTableChoice;
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