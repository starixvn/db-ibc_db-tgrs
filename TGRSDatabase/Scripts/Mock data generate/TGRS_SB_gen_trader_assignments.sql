SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE [dbo].[TGRS_SB_gen_trader_assignments]
    @TargetDate DATETIME,
    @MatchIdToUse INT,
    @BalanceUpDay SMALLDATETIME
AS
BEGIN
    SET NOCOUNT ON;
    
    BEGIN TRY
        -- Determine target assignment table
        DECLARE @TargetAssignmentTableIsArchive BIT = 0;
        DECLARE @ErrorMessage NVARCHAR(MAX) = NULL;

        IF @TargetDate < @BalanceUpDay
        BEGIN
            SET @TargetAssignmentTableIsArchive = 1;
        END

        PRINT 'Creating trader assignments for MatchID: ' + CAST(@MatchIdToUse AS VARCHAR) + '...';
        
        -- Declare and populate a list of traders to assign
        DECLARE @TraderList TABLE (
            RowID INT IDENTITY PRIMARY KEY,
            TraderID INT
        );

        INSERT INTO @TraderList (TraderID)
        SELECT TOP 5 CustId
        FROM dbo.Trader
        ORDER BY NEWID();

        DECLARE @TraderCount INT;

        SELECT @TraderCount = COUNT(*)
        FROM @TraderList;

        IF @TraderCount = 0
        BEGIN
            PRINT 'Warning: No traders found to assign. Performance data might use default trader.';
            RETURN;
        END

        IF @MatchIdToUse IS NULL
        BEGIN
            SET @ErrorMessage = 'MatchIdToUse is NULL. Cannot create assignments.';
            THROW 51000, @ErrorMessage, 1;
            RETURN;
        END

        DECLARE @NextAssignmentBkID INT;

        IF @TargetAssignmentTableIsArchive = 1
        BEGIN
            SELECT @NextAssignmentBkID = ISNULL(MAX(ID), 0) + 1
            FROM bodb_archive.dbo.Dot_Admin_Assignment_Trader_bk WITH (NOLOCK);

            PRINT 'Next starting ID for Dot_Admin_Assignment_Trader_bk: ' + CAST(@NextAssignmentBkID AS VARCHAR);
        END

        -- Create distinct bet types table
        DECLARE @DistinctBetTypes TABLE (BetType INT PRIMARY KEY);

        INSERT INTO @DistinctBetTypes (BetType)
        SELECT DISTINCT
            CASE n % 55
                WHEN 0 THEN 1
                WHEN 1 THEN 2
                WHEN 2 THEN 3
                WHEN 3 THEN 4
                WHEN 4 THEN 5
                WHEN 5 THEN 6
                WHEN 6 THEN 7
                WHEN 7 THEN 8
                WHEN 8 THEN 9
                WHEN 9 THEN 10
                WHEN 10 THEN 12
                WHEN 11 THEN 13
                WHEN 12 THEN 14
                WHEN 13 THEN 15
                WHEN 14 THEN 16
                WHEN 15 THEN 17
                WHEN 16 THEN 18
                WHEN 17 THEN 22
                WHEN 18 THEN 24
                WHEN 19 THEN 25
                WHEN 20 THEN 26
                WHEN 21 THEN 27
                WHEN 22 THEN 28
                WHEN 23 THEN 29
                WHEN 24 THEN 30
                WHEN 25 THEN 38
                WHEN 26 THEN 121
                WHEN 27 THEN 122
                WHEN 28 THEN 123
                WHEN 29 THEN 124
                WHEN 30 THEN 125
                WHEN 31 THEN 126
                WHEN 32 THEN 127
                WHEN 33 THEN 128
                WHEN 34 THEN 129
                WHEN 35 THEN 130
                WHEN 36 THEN 131
                WHEN 37 THEN 132
                WHEN 38 THEN 133
                WHEN 39 THEN 134
                WHEN 40 THEN 135
                WHEN 41 THEN 136
                WHEN 42 THEN 137
                WHEN 43 THEN 138
                WHEN 44 THEN 139
                WHEN 45 THEN 140
                WHEN 46 THEN 141
                WHEN 47 THEN 142
                WHEN 48 THEN 143
                WHEN 49 THEN 144
                WHEN 50 THEN 145
                WHEN 51 THEN 146
                WHEN 52 THEN 147
                WHEN 53 THEN 148
                WHEN 54 THEN 149
                ELSE 150
            END
        FROM (
            SELECT TOP 100
                ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS n
            FROM sys.objects a
            CROSS JOIN sys.objects b
            ) nums;

        DECLARE @AssignmentsInserted INT = 0;

        IF @TargetAssignmentTableIsArchive = 1
        BEGIN
            WITH
                DistinctBetTypesWithRN
                AS
                (
                    SELECT
                        BetType,
                        ROW_NUMBER() OVER (ORDER BY BetType) AS rn
                    FROM @DistinctBetTypes
                )
            INSERT INTO bodb_archive.dbo.Dot_Admin_Assignment_Trader_bk (
                ID,
                MatchId,
                BetType,
                TraderID,
                UpdatedTime,
                UpdatedUser,
                liveindicator,
                Detail_X,
                Detail_Y,
                Detail_Z,
                Type
                )
            SELECT
                @NextAssignmentBkID + dbrn.rn - 1,
                @MatchIdToUse,
                dbrn.BetType,
                tl.TraderID,
                @TargetDate,
                tl.TraderID,
                0,
                0,
                0,
                0,
                0
            FROM DistinctBetTypesWithRN dbrn
            JOIN @TraderList tl
                ON tl.RowID = ((dbrn.rn - 1) % @TraderCount) + 1
            WHERE NOT EXISTS (
                SELECT 1
                FROM bodb_archive.dbo.Dot_Admin_Assignment_Trader_bk existing
                WHERE existing.MatchId = @MatchIdToUse
                    AND existing.BetType = dbrn.BetType
                    AND existing.liveindicator = 0
                    AND existing.Detail_X = 0
                    AND existing.Detail_Y = 0
                    AND existing.Detail_Z = 0
                    AND existing.Type = 0
                );

            SET @AssignmentsInserted = @@ROWCOUNT;
            PRINT CAST(@AssignmentsInserted AS VARCHAR) + ' assignments inserted into bodb_archive.dbo.Dot_Admin_Assignment_Trader_bk.';
        END
        ELSE
        BEGIN
            WITH
                DistinctBetTypesWithRN
                AS
                (
                    SELECT
                        BetType,
                        ROW_NUMBER() OVER (ORDER BY BetType) AS rn
                    FROM @DistinctBetTypes
                )
            INSERT INTO bodb02.dbo.Dot_Admin_Assignment_Trader (
                MatchId,
                BetType,
                TraderID,
                UpdatedTime,
                UpdatedUser,
                liveindicator,
                Detail_X,
                Detail_Y,
                Detail_Z,
                Type
                )
            SELECT
                @MatchIdToUse,
                dbrn.BetType,
                tl.TraderID,
                @TargetDate,
                tl.TraderID,
                0,
                0,
                0,
                0,
                0
            FROM DistinctBetTypesWithRN dbrn
            JOIN @TraderList tl
                ON tl.RowID = ((dbrn.rn - 1) % @TraderCount) + 1
            WHERE NOT EXISTS (
                SELECT 1
                FROM bodb02.dbo.Dot_Admin_Assignment_Trader existing
                WHERE existing.MatchId = @MatchIdToUse
                    AND existing.BetType = dbrn.BetType
                    AND existing.liveindicator = 0
                    AND existing.Detail_X = 0
                    AND existing.Detail_Y = 0
                    AND existing.Detail_Z = 0
                    AND existing.Type = 0
                );

            SET @AssignmentsInserted = @@ROWCOUNT;
            PRINT CAST(@AssignmentsInserted AS VARCHAR) + ' assignments inserted into bodb02.dbo.Dot_Admin_Assignment_Trader.';
        END
        
        PRINT 'Finished processing mock trader assignments for MatchID: ' + CAST(@MatchIdToUse AS VARCHAR);
    END TRY
    BEGIN CATCH
        SET @ErrorMessage = 'Error in TGRS_SB_gen_trader_assignments: ' + ERROR_MESSAGE();
        PRINT @ErrorMessage;
        THROW;
    END CATCH
END
GO 