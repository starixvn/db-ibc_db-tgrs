SET XACT_ABORT ON; -- Ensure script fails on first error
-- Script to create a dummy soccer match and generate transactions with correct BetChoice mapping
DECLARE @TargetDate DATETIME = '2025-05-05';

DECLARE @BaseRefNo BIGINT = 2025041400001;
DECLARE @BaseTransId BIGINT; -- To be set dynamically based on target table
DECLARE @MatchIdToUse INT = NULL; -- The ID of the match to use (existing or new)

DECLARE @BalanceUpDay SMALLDATETIME, @MoveBetsDay SMALLDATETIME;
DECLARE @TargetTableChoice INT; -- 1 for _bk, 2 for _14, 3 for live/current

DECLARE @tmpBUMBData TABLE (BUDay SMALLDATETIME, MBDay SMALLDATETIME);
INSERT INTO @tmpBUMBData EXECUTE bodb02.dbo.Age_SelBalanceUpDay;
SELECT TOP 1 @BalanceUpDay = BUDay, @MoveBetsDay = MBDay FROM @tmpBUMBData;

IF @TargetDate < @BalanceUpDay
BEGIN
    SET @TargetTableChoice = 1;
    PRINT 'Date range targets _bk tables.';
END
ELSE IF @TargetDate >= @BalanceUpDay AND @TargetDate <= @MoveBetsDay
BEGIN
    SET @TargetTableChoice = 2;
    PRINT 'Date range targets _14 tables.';
END
ELSE -- @TargetDate > @MoveBetsDay
BEGIN
    SET @TargetTableChoice = 3;
    PRINT 'Date range targets live tables.';
END;

-- Check for existing suitable match
PRINT 'Checking for existing completed soccer match on ' + CONVERT(VARCHAR, @TargetDate, 23) + '...';
IF @TargetTableChoice = 1
BEGIN
    SELECT TOP 1 @MatchIdToUse = matchid FROM bodb_Archive.dbo.match_bk WITH (NOLOCK)
    WHERE eventdate = @TargetDate AND sporttype = 1 AND eventstatus = 'completed';
END
ELSE IF @TargetTableChoice = 2
BEGIN
    SELECT TOP 1 @MatchIdToUse = matchid FROM bodb02.dbo.match14 WITH (NOLOCK)
    WHERE eventdate = @TargetDate AND sporttype = 1 AND eventstatus = 'completed';
END
ELSE -- @TargetTableChoice = 3
BEGIN
    SELECT TOP 1 @MatchIdToUse = matchid FROM bodb02.dbo.match WITH (NOLOCK)
    WHERE eventdate = @TargetDate AND sporttype = 1 AND eventstatus = 'completed';
END

-- Handle Match Creation or Use Existing
IF @MatchIdToUse IS NOT NULL
BEGIN
    PRINT 'Found existing match with ID: ' + CAST(@MatchIdToUse AS VARCHAR) + '. Using this match.';
END
ELSE
BEGIN
    PRINT 'No suitable existing match found. Creating new match...';
    DECLARE @RandomLeagueId INT;
    DECLARE @RandomHomeId INT;
    DECLARE @RandomAwayId INT;

    SELECT TOP 1 @RandomLeagueId = leagueid FROM bodb02.dbo.league WHERE sporttype = 1 AND leagueid > 0 ORDER BY NEWID();
    IF @RandomLeagueId IS NULL
    BEGIN
        PRINT 'No active soccer leagues found'; RETURN;
    END

    SELECT TOP 2 @RandomHomeId = CASE WHEN T.RowNum = 1 THEN T.teamid ELSE @RandomHomeId END, @RandomAwayId = CASE WHEN T.RowNum = 2 THEN T.teamid ELSE @RandomAwayId END
    FROM (SELECT teamid, ROW_NUMBER() OVER (ORDER BY NEWID()) AS RowNum FROM bodb02.dbo.team WHERE SportType IN (SELECT SportType FROM bodb02.dbo.league WHERE leagueid = @RandomLeagueId)) AS T WHERE T.RowNum <= 2;
    IF @RandomHomeId IS NULL OR @RandomAwayId IS NULL OR @RandomHomeId = @RandomAwayId
    BEGIN
        PRINT 'Could not find two distinct active soccer teams'; RETURN;
    END

    -- Create new match record conditionally based on @TargetTableChoice
    IF @TargetTableChoice = 1 -- Target _bk
    BEGIN
        DECLARE @NextAvailableMatchId INT = ISNULL((SELECT MAX(matchid) FROM bodb_Archive.dbo.match_bk WITH (NOLOCK)), 0) + 1;
        PRINT 'Next MatchID for match_bk will be: ' + CAST(@NextAvailableMatchId AS VARCHAR);
        INSERT INTO bodb_Archive.dbo.match_bk (matchid, leagueid, homeid, awayid, eventdate, eventstatus, betstatus, creator, matchcode, sporttype, homeid2, awayid2, DisplayMode, LeaguePatternID, HomeDisplayPatternID, AwayDisplayPatternID, IsNeutral)
        VALUES (@NextAvailableMatchId, @RandomLeagueId, @RandomHomeId, @RandomAwayId, @TargetDate, 'completed', '1-0,2-1', 2929, 'SOCCER_' + CONVERT(VARCHAR, @TargetDate, 112), 1, 0, 0, 0, 0, 0, 0, 0);
        SET @MatchIdToUse = @NextAvailableMatchId;
        PRINT 'Created Soccer Match in bodb_Archive.dbo.match_bk with ID: ' + CAST(@MatchIdToUse AS VARCHAR);
    END
    ELSE IF @TargetTableChoice = 2 -- Target _14
    BEGIN
        DECLARE @NextAvailableMatchId14 INT = ISNULL((SELECT MAX(matchid) FROM bodb02.dbo.match14 WITH (NOLOCK)), 0) + 1;
        PRINT 'Next MatchID for match14 will be: ' + CAST(@NextAvailableMatchId14 AS VARCHAR);
        INSERT INTO bodb02.dbo.match14 (matchid, leagueid, homeid, awayid, eventdate, eventstatus, betstatus, creator, matchcode, sporttype, homeid2, awayid2, DisplayMode, LeaguePatternID, HomeDisplayPatternID, AwayDisplayPatternID, IsNeutral)
        VALUES (@NextAvailableMatchId14, @RandomLeagueId, @RandomHomeId, @RandomAwayId, @TargetDate, 'completed', '1-0,2-1', 2929, 'SOCCER_' + CONVERT(VARCHAR, @TargetDate, 112), 1, 0, 0, 0, 0, 0, 0, 0);
        SET @MatchIdToUse = @NextAvailableMatchId14;
        PRINT 'Created Soccer Match in bodb02.dbo.match14 with ID: ' + CAST(@MatchIdToUse AS VARCHAR);
    END
    ELSE -- TargetTableChoice = 3 (live)
    BEGIN
        INSERT INTO bodb02.dbo.match (leagueid, homeid, awayid, eventdate, eventstatus, betstatus, creator, matchcode, sporttype, homeid2, awayid2, DisplayMode, LeaguePatternID, HomeDisplayPatternID, AwayDisplayPatternID, IsNeutral)
        VALUES (@RandomLeagueId, @RandomHomeId, @RandomAwayId, @TargetDate, 'completed', '1-0,2-1', 2929, 'SOCCER_' + CONVERT(VARCHAR, @TargetDate, 112), 1, 0, 0, 0, 0, 0, 0, 0);
        SET @MatchIdToUse = SCOPE_IDENTITY();
        PRINT 'Created Soccer Match in bodb02.dbo.match with ID: ' + CAST(@MatchIdToUse AS VARCHAR);
    END;
END; -- End of match handling

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
    IF EXISTS (SELECT 1 FROM bodb_archive.dbo.Dot_Admin_Assignment_Trader_bk WHERE MatchId = @MatchIdToUse)
        SET @AssignmentsExist = 1;
END
ELSE
BEGIN
    IF EXISTS (SELECT 1 FROM bodb02.dbo.Dot_Admin_Assignment_Trader WHERE MatchId = @MatchIdToUse)
        SET @AssignmentsExist = 1;
END

-- Handle Assignments
IF @AssignmentsExist = 1
BEGIN
    PRINT 'Found existing assignments for MatchID: ' + CAST(@MatchIdToUse AS VARCHAR) + '. Skipping assignment creation.';
END
ELSE
BEGIN
    PRINT 'No existing assignments found for MatchID: ' + CAST(@MatchIdToUse AS VARCHAR) + '. Inserting new assignments...';
    -- Declare and populate a list of traders to assign
    DECLARE @TraderList TABLE (RowID INT IDENTITY PRIMARY KEY, TraderID INT);
    INSERT INTO @TraderList (TraderID) 
    SELECT TOP 5 CustId FROM dbo.Trader ORDER BY NEWID(); -- Removed WHERE clause for now to avoid unknown column errors

    DECLARE @TraderCount INT;
    SELECT @TraderCount = COUNT(*) FROM @TraderList;

    IF @TraderCount = 0
    BEGIN
        PRINT 'Warning: No traders found to assign. Performance data might use default trader.';
    END
    ELSE IF @MatchIdToUse IS NOT NULL -- Check MatchIdToUse here
    BEGIN
        DECLARE @NextAssignmentBkID INT;
        IF @TargetAssignmentTableIsArchive = 1
        BEGIN
            SELECT @NextAssignmentBkID = ISNULL(MAX(ID),0) + 1 FROM bodb_archive.dbo.Dot_Admin_Assignment_Trader_bk WITH (NOLOCK);
            PRINT 'Next starting ID for Dot_Admin_Assignment_Trader_bk: ' + CAST(@NextAssignmentBkID AS VARCHAR);
        END

        DECLARE @DistinctBetTypes TABLE (BetType INT PRIMARY KEY);
        INSERT INTO @DistinctBetTypes (BetType)
        SELECT DISTINCT CASE n % 55 WHEN 0 THEN 1 WHEN 1 THEN 2 WHEN 2 THEN 3 WHEN 3 THEN 4 WHEN 4 THEN 5 WHEN 5 THEN 6 WHEN 6 THEN 7 WHEN 7 THEN 8 WHEN 8 THEN 9 WHEN 9 THEN 10 WHEN 10 THEN 12 WHEN 11 THEN 13 WHEN 12 THEN 14 WHEN 13 THEN 15 WHEN 14 THEN 16 WHEN 15 THEN 17 WHEN 16 THEN 18 WHEN 17 THEN 22 WHEN 18 THEN 24 WHEN 19 THEN 25 WHEN 20 THEN 26 WHEN 21 THEN 27 WHEN 22 THEN 28 WHEN 23 THEN 29 WHEN 24 THEN 30 WHEN 25 THEN 38 WHEN 26 THEN 121 WHEN 27 THEN 122 WHEN 28 THEN 123 WHEN 29 THEN 124 WHEN 30 THEN 125 WHEN 31 THEN 126 WHEN 32 THEN 127 WHEN 33 THEN 128 WHEN 34 THEN 129 WHEN 35 THEN 130 WHEN 36 THEN 131 WHEN 37 THEN 132 WHEN 38 THEN 133 WHEN 39 THEN 134 WHEN 40 THEN 135 WHEN 41 THEN 136 WHEN 42 THEN 137 WHEN 43 THEN 138 WHEN 44 THEN 139 WHEN 45 THEN 140 WHEN 46 THEN 141 WHEN 47 THEN 142 WHEN 48 THEN 143 WHEN 49 THEN 144 WHEN 50 THEN 145 WHEN 51 THEN 146 WHEN 52 THEN 147 WHEN 53 THEN 148 WHEN 54 THEN 149 ELSE 150 END
        FROM (SELECT TOP 100 ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS n FROM sys.objects a CROSS JOIN sys.objects b) nums;

        DECLARE @AssignmentsInserted INT = 0;

        IF @TargetAssignmentTableIsArchive = 1
        BEGIN
            WITH DistinctBetTypesWithRN AS ( SELECT BetType, ROW_NUMBER() OVER (ORDER BY BetType) as rn FROM @DistinctBetTypes )
            INSERT INTO bodb_archive.dbo.Dot_Admin_Assignment_Trader_bk (ID, MatchId, BetType, TraderID, UpdatedTime, UpdatedUser, liveindicator, Detail_X, Detail_Y, Detail_Z, Type)
            SELECT @NextAssignmentBkID + dbrn.rn - 1, @MatchIdToUse, dbrn.BetType, tl.TraderID, @TargetDate, tl.TraderID, 0, 0, 0, 0, 0
            FROM DistinctBetTypesWithRN dbrn
            JOIN @TraderList tl ON tl.RowID = ( (dbrn.rn - 1) % @TraderCount ) + 1
            WHERE NOT EXISTS ( SELECT 1 FROM bodb_archive.dbo.Dot_Admin_Assignment_Trader_bk existing WHERE existing.MatchId = @MatchIdToUse AND existing.BetType = dbrn.BetType AND existing.liveindicator = 0 AND existing.Detail_X = 0 AND existing.Detail_Y = 0 AND existing.Detail_Z = 0 AND existing.Type = 0 );
            SET @AssignmentsInserted = @@ROWCOUNT;
            PRINT CAST(@AssignmentsInserted AS VARCHAR) + ' assignments inserted into bodb_archive.dbo.Dot_Admin_Assignment_Trader_bk.';
        END
        ELSE
        BEGIN
            WITH DistinctBetTypesWithRN AS ( SELECT BetType, ROW_NUMBER() OVER (ORDER BY BetType) as rn FROM @DistinctBetTypes )
            INSERT INTO bodb02.dbo.Dot_Admin_Assignment_Trader (MatchId, BetType, TraderID, UpdatedTime, UpdatedUser, liveindicator, Detail_X, Detail_Y, Detail_Z, Type)
            SELECT @MatchIdToUse, dbrn.BetType, tl.TraderID, @TargetDate, tl.TraderID, 0, 0, 0, 0, 0
            FROM DistinctBetTypesWithRN dbrn
            JOIN @TraderList tl ON tl.RowID = ( (dbrn.rn - 1) % @TraderCount ) + 1
            WHERE NOT EXISTS ( SELECT 1 FROM bodb02.dbo.Dot_Admin_Assignment_Trader existing WHERE existing.MatchId = @MatchIdToUse AND existing.BetType = dbrn.BetType AND existing.liveindicator = 0 AND existing.Detail_X = 0 AND existing.Detail_Y = 0 AND existing.Detail_Z = 0 AND existing.Type = 0 );
            SET @AssignmentsInserted = @@ROWCOUNT;
            PRINT CAST(@AssignmentsInserted AS VARCHAR) + ' assignments inserted into bodb02.dbo.Dot_Admin_Assignment_Trader.';
        END
        PRINT 'Finished processing mock trader assignments.';
    END -- End check if @TraderCount > 0 AND @MatchIdToUse IS NOT NULL
END; -- End of assignment handling

-- Generate Bet Transactions -- 
PRINT 'Proceeding to generate bet transactions for MatchID: ' + CAST(@MatchIdToUse AS VARCHAR) + '...';

-- Determine BaseTransId based on target bettrans table
IF @TargetTableChoice = 1
BEGIN
    SELECT @BaseTransId = ISNULL(MAX(TransId), 0) FROM bodb_Archive.dbo.bettrans_bk WITH (NOLOCK);
    PRINT 'Targeting bodb_Archive.dbo.bettrans_bk for transactions. Max TransId found: ' + ISNULL(CAST(@BaseTransId AS VARCHAR), 'NULL') + '. New TransIds will start from ' + CAST(@BaseTransId + 1 AS VARCHAR) + '.';
END
ELSE IF @TargetTableChoice = 2
BEGIN
    SELECT @BaseTransId = ISNULL(MAX(TransId), 0) FROM bodb02.dbo.bettrans14 WITH (NOLOCK);
    PRINT 'Targeting bodb02.dbo.bettrans14 for transactions. Max TransId found: ' + ISNULL(CAST(@BaseTransId AS VARCHAR), 'NULL') + '. New TransIds will start from ' + CAST(@BaseTransId + 1 AS VARCHAR) + '.';
END
ELSE -- @TargetTableChoice = 3
BEGIN
    SELECT @BaseTransId = ISNULL(MAX(TransId), 0) FROM bodb02.dbo.bettrans WITH (NOLOCK);
    PRINT 'Targeting bodb02.dbo.bettrans for transactions. Max TransId found: ' + ISNULL(CAST(@BaseTransId AS VARCHAR), 'NULL') + '. New TransIds will start from ' + CAST(@BaseTransId + 1 AS VARCHAR) + '.';
END;

-- Declare a table variable to store customer IDs
DECLARE @CustomerListSB TABLE ( RowID INT IDENTITY(1,1) PRIMARY KEY, CustId INT );
INSERT INTO @CustomerListSB (CustId) SELECT TOP 100 custid FROM bodb02.dbo.vw_customer ORDER BY NEWID();
DECLARE @CustomerCountSB INT; SELECT @CustomerCountSB = COUNT(*) FROM @CustomerListSB;
IF @CustomerCountSB = 0
BEGIN
    PRINT 'No customers found in bodb02.dbo.vw_customer for Soccer script. Cannot generate transactions.'; RETURN;
END;

-- Prepare temporary table for bet transactions
IF OBJECT_ID('tempdb..#MockBetTransData') IS NOT NULL DROP TABLE #MockBetTransData;
CREATE TABLE #MockBetTransData ( TransId BIGINT, custid INT, transdate DATETIME, oddsid BIGINT, hdp1 DECIMAL(18,2), hdp2 DECIMAL(18,2), odds DECIMAL(18,2), stake DECIMAL(18,2), status VARCHAR(10), winlost DECIMAL(18,2), awinlost DECIMAL(18,2), mwinlost DECIMAL(18,2), playercomm DECIMAL(18,2), comm DECIMAL(18,2), acomm DECIMAL(18,2), apositiontaking DECIMAL(18,2), mpositiontaking DECIMAL(18,2), tpositiontaking DECIMAL(18,2), playerdiscount DECIMAL(18,2), discount DECIMAL(18,2), adiscount DECIMAL(18,2), livehomescore INT, liveawayscore INT, liveindicator INT, creator INT, refno BIGINT, comstatus INT, winlostdate DATETIME, betfrom VARCHAR(1), betcheck INT, checktime DATETIME, oddsspread DECIMAL(18,2), actualrate DECIMAL(18,2), matchid INT, recommend BIGINT, mrecommend BIGINT, ruben INT, betid BIGINT, statuswinlost INT, modds DECIMAL(18,2), bettype INT, betdaqid INT, actual_stake DECIMAL(18,2), currency INT, transdesc VARCHAR(MAX), sdiscount DECIMAL(18,2), scomm DECIMAL(18,2), spositiontaking DECIMAL(18,2), swinlost DECIMAL(18,2), srecommend BIGINT, virtualrate DECIMAL(18,2), oddstype INT, statusID INT, currency2 INT, balance DECIMAL(18,2), SecAcceptFlag VARCHAR(1), transid2 BIGINT, ExtraInfo VARCHAR(MAX), WalletType INT, BonusID BIGINT, RefCode VARCHAR(50), SettlementTime DATETIME, epositiontaking DECIMAL(18,2), ReasonID INT, sort INT, betteam VARCHAR(10) );

-- Generate 100 transaction tickets
;WITH BetTypeData AS ( SELECT n, CASE n % 55 WHEN 0 THEN 1 WHEN 1 THEN 2 WHEN 2 THEN 3 WHEN 3 THEN 4 WHEN 4 THEN 5 WHEN 5 THEN 6 WHEN 6 THEN 7 WHEN 7 THEN 8 WHEN 8 THEN 9 WHEN 9 THEN 10 WHEN 10 THEN 12 WHEN 11 THEN 13 WHEN 12 THEN 14 WHEN 13 THEN 15 WHEN 14 THEN 16 WHEN 15 THEN 17 WHEN 16 THEN 18 WHEN 17 THEN 22 WHEN 18 THEN 24 WHEN 19 THEN 25 WHEN 20 THEN 26 WHEN 21 THEN 27 WHEN 22 THEN 28 WHEN 23 THEN 29 WHEN 24 THEN 30 WHEN 25 THEN 38 WHEN 26 THEN 121 WHEN 27 THEN 122 WHEN 28 THEN 123 WHEN 29 THEN 124 WHEN 30 THEN 125 WHEN 31 THEN 126 WHEN 32 THEN 127 WHEN 33 THEN 128 WHEN 34 THEN 129 WHEN 35 THEN 130 WHEN 36 THEN 131 WHEN 37 THEN 132 WHEN 38 THEN 133 WHEN 39 THEN 134 WHEN 40 THEN 135 WHEN 41 THEN 136 WHEN 42 THEN 137 WHEN 43 THEN 138 WHEN 44 THEN 139 WHEN 45 THEN 140 WHEN 46 THEN 141 WHEN 47 THEN 142 WHEN 48 THEN 143 WHEN 49 THEN 144 WHEN 50 THEN 145 WHEN 51 THEN 146 WHEN 52 THEN 147 WHEN 53 THEN 148 WHEN 54 THEN 149 ELSE 150 END AS bettype FROM (SELECT TOP 100 ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS n FROM sys.objects a CROSS JOIN sys.objects b) nums ), BetTransDataCTE AS ( SELECT btd.n AS original_n_for_betteam, btd.bettype, raw.* FROM BetTypeData btd CROSS APPLY ( SELECT @BaseTransId + btd.n AS TransId, (SELECT CL.CustId FROM @CustomerListSB CL WHERE CL.RowID = (btd.n - 1) % @CustomerCountSB + 1) AS custid, @TargetDate AS transdate, 700000000 + btd.n AS oddsid, CASE ((btd.n + ABS(CHECKSUM(NEWID()))) % 8) WHEN 0 THEN 0.0 WHEN 1 THEN 0.25 WHEN 2 THEN 0.5 WHEN 3 THEN 0.75 WHEN 4 THEN 1.0 WHEN 5 THEN -0.25 WHEN 6 THEN -0.5 ELSE -0.75 END AS hdp1, 0 AS hdp2, CASE WHEN btd.n % 2 = 0 THEN -1.10 ELSE 0.95 END AS odds, 100 + (btd.n * 50) % 500 AS stake, CASE WHEN btd.n % 3 = 0 THEN 'WON' WHEN btd.n % 3 = 1 THEN 'LOSE' ELSE 'HALF-WON' END AS status, CASE WHEN btd.n % 3 = 0 THEN (100 + (btd.n * 50) % 500) * ABS(CASE WHEN btd.n % 2 = 0 THEN -1.10 ELSE 0.95 END) WHEN btd.n % 3 = 1 THEN 0 ELSE (100 + (btd.n * 50) % 500) * ABS(CASE WHEN btd.n % 2 = 0 THEN -1.10 ELSE 0.95 END) * 0.5 END AS winlost, CASE WHEN btd.n % 3 = 0 THEN (100 + (btd.n * 50) % 500) * -0.4 ELSE (100 + (btd.n * 50) % 500) * 0.364 END AS awinlost, CASE WHEN btd.n % 3 = 0 THEN (100 + (btd.n * 50) % 500) * -0.3 ELSE (100 + (btd.n * 50) % 500) * 0.273 END AS mwinlost, 10 AS playercomm, 8 AS comm, 5 AS acomm, 0.4 AS apositiontaking, 0.3 AS mpositiontaking, 0.9 AS tpositiontaking, 0.01 AS playerdiscount, 0.015 AS discount, 0.02 AS adiscount, CASE WHEN btd.n % 5 = 0 THEN 1 ELSE 0 END AS livehomescore, CASE WHEN btd.n % 6 = 0 THEN 1 ELSE 0 END AS liveawayscore, CASE WHEN btd.n % 5 = 0 OR btd.n % 6 = 0 THEN 1 ELSE 0 END AS liveindicator, 8 AS creator, @BaseRefNo + btd.n AS refno, 0 AS comstatus, @TargetDate AS winlostdate, 'w' AS betfrom, 0 AS betcheck, NULL AS checktime, 0 AS oddsspread, 0.2 AS actualrate, @MatchIdToUse AS matchid, 10063439 AS recommend, 10063438 AS mrecommend, 1 AS ruben, 0 AS betid, CASE WHEN btd.n % 3 = 0 THEN 2 WHEN btd.n % 3 = 1 THEN 4 ELSE 1 END AS statuswinlost, CASE WHEN btd.n % 2 = 0 THEN -1.10 ELSE 0.95 END AS modds, btd.bettype AS BetType_from_btd, -1 AS betdaqid, (100 + (btd.n * 50) % 500) AS actual_stake, 3 AS currency, NULL AS transdesc, 0.02 AS sdiscount, 2.0 AS scomm, 0.2 AS spositiontaking, CASE WHEN btd.n % 3 = 0 THEN -80 WHEN btd.n % 3 = 1 THEN 95 ELSE -40 END AS swinlost, 10063437 AS srecommend, 1 AS virtualrate, 4 AS oddstype, CASE WHEN btd.n % 3 = 0 THEN 112 WHEN btd.n % 3 = 1 THEN 113 ELSE 111 END AS statusID, NULL AS currency2, NULL AS balance, NULL AS SecAcceptFlag, NULL AS transid2, NULL AS ExtraInfo, NULL AS WalletType, NULL AS BonusID, NULL AS RefCode, CASE WHEN btd.n % 3 = 0 THEN DATEADD(MINUTE, -( (ABS(CHECKSUM(NEWID())) % 60) + 1 ), GETDATE()) ELSE DATEADD(HOUR, -( (ABS(CHECKSUM(NEWID())) % 3) + 1 ), @TargetDate) END AS SettlementTime, 0 AS epositiontaking, NULL AS ReasonID, NULL AS sort ) raw ) INSERT INTO #MockBetTransData ( TransId, custid, transdate, oddsid, hdp1, hdp2, odds, stake, status, winlost, awinlost, mwinlost, playercomm, comm, acomm, apositiontaking, mpositiontaking, tpositiontaking, playerdiscount, discount, adiscount, livehomescore, liveawayscore, liveindicator, creator, refno, comstatus, winlostdate, betfrom, betcheck, checktime, oddsspread, actualrate, matchid, recommend, mrecommend, ruben, betid, statuswinlost, modds, bettype, betdaqid, actual_stake, currency, transdesc, sdiscount, scomm, spositiontaking, swinlost, srecommend, virtualrate, oddstype, statusID, currency2, balance, SecAcceptFlag, transid2, ExtraInfo, WalletType, BonusID, RefCode, SettlementTime, epositiontaking, ReasonID, sort, betteam ) SELECT cte.TransId, cte.custid, cte.transdate, cte.oddsid, cte.hdp1, cte.hdp2, cte.odds, cte.stake, cte.status, cte.winlost, cte.awinlost, cte.mwinlost, cte.playercomm, cte.comm, cte.acomm, cte.apositiontaking, cte.mpositiontaking, cte.tpositiontaking, cte.playerdiscount, cte.discount, cte.adiscount, cte.livehomescore, cte.liveawayscore, cte.liveindicator, cte.creator, cte.refno, cte.comstatus, cte.winlostdate, cte.betfrom, cte.betcheck, cte.checktime, cte.oddsspread, cte.actualrate, cte.matchid, cte.recommend, cte.mrecommend, cte.ruben, cte.betid, cte.statuswinlost, cte.modds, cte.bettype, cte.betdaqid, cte.actual_stake, cte.currency, cte.transdesc, cte.sdiscount, cte.scomm, cte.spositiontaking, cte.swinlost, cte.srecommend, cte.virtualrate, cte.oddstype, cte.statusID, cte.currency2, cte.balance, cte.SecAcceptFlag, cte.transid2, cte.ExtraInfo, cte.WalletType, cte.BonusID, cte.RefCode, cte.SettlementTime, cte.epositiontaking, cte.ReasonID, cte.sort, CASE WHEN cte.bettype IN (1, 2, 7, 8, 12, 17, 25, 27, 123) THEN CASE (cte.original_n_for_betteam + ABS(CHECKSUM(NEWID()))) % 2 WHEN 0 THEN 'h' ELSE 'a' END WHEN cte.bettype IN (3, 5, 15, 22, 28, 121, 122) THEN CASE (cte.original_n_for_betteam + ABS(CHECKSUM(NEWID()))) % 3 WHEN 0 THEN 'h' WHEN 1 THEN 'a' ELSE 'x' END WHEN cte.bettype = 4 THEN CASE (cte.original_n_for_betteam + ABS(CHECKSUM(NEWID()))) % 31 WHEN 0 THEN '0:0' WHEN 1 THEN '0:1' WHEN 2 THEN '0:2' WHEN 3 THEN '0:3' WHEN 4 THEN '0:4' WHEN 5 THEN '0:5' WHEN 6 THEN '1:0' WHEN 7 THEN '1:1' WHEN 8 THEN '1:2' WHEN 9 THEN '1:3' WHEN 10 THEN '1:4' WHEN 11 THEN '2:0' WHEN 12 THEN '2:1' WHEN 13 THEN '2:2' WHEN 14 THEN '2:3' WHEN 15 THEN '2:4' WHEN 16 THEN '3:0' WHEN 17 THEN '3:1' WHEN 18 THEN '3:2' WHEN 19 THEN '3:3' WHEN 20 THEN '3:4' WHEN 21 THEN '4:0' WHEN 22 THEN '4:1' WHEN 23 THEN '4:2' WHEN 24 THEN '4:3' WHEN 25 THEN '4:4' WHEN 26 THEN '5:0' ELSE 'AOS' END WHEN cte.bettype = 6 THEN CASE (cte.original_n_for_betteam + ABS(CHECKSUM(NEWID()))) % 4 WHEN 0 THEN '0-1' WHEN 1 THEN '2-3' WHEN 2 THEN '4-6' ELSE '7-Over' END WHEN cte.bettype = 13 THEN CASE (cte.original_n_for_betteam + ABS(CHECKSUM(NEWID()))) % 4 WHEN 0 THEN 'an' WHEN 1 THEN 'ay' WHEN 2 THEN 'hn' ELSE 'hy' END WHEN cte.bettype = 14 THEN CASE (cte.original_n_for_betteam + ABS(CHECKSUM(NEWID()))) % 5 WHEN 0 THEN '0:0' WHEN 1 THEN '1:1' WHEN 2 THEN '1:2' WHEN 3 THEN '2:1' ELSE '2:2' END WHEN cte.bettype = 16 THEN CASE (cte.original_n_for_betteam + ABS(CHECKSUM(NEWID()))) % 9 WHEN 0 THEN '0:0' WHEN 1 THEN '0:1' WHEN 2 THEN '0:2' WHEN 3 THEN '1:0' WHEN 4 THEN '1:1' WHEN 5 THEN '1:2' WHEN 6 THEN '2:0' WHEN 7 THEN '2:1' ELSE '2:2' END WHEN cte.bettype = 18 THEN CASE (cte.original_n_for_betteam + ABS(CHECKSUM(NEWID()))) % 2 WHEN 0 THEN 'o' ELSE 'u' END WHEN cte.bettype IN (143, 144) THEN CASE (cte.original_n_for_betteam + ABS(CHECKSUM(NEWID()))) % 6 WHEN 0 THEN 'ao' WHEN 1 THEN 'au' WHEN 2 THEN 'do' WHEN 3 THEN 'du' WHEN 4 THEN 'ho' ELSE 'hu' END WHEN cte.bettype = 24 THEN CASE (cte.original_n_for_betteam + ABS(CHECKSUM(NEWID()))) % 3 WHEN 0 THEN '12' WHEN 1 THEN '1x' ELSE '2x' END WHEN cte.bettype = 26 THEN CASE (cte.original_n_for_betteam + ABS(CHECKSUM(NEWID()))) % 3 WHEN 0 THEN 'b' WHEN 1 THEN 'n' ELSE 'o' END WHEN cte.bettype = 30 THEN CASE (cte.original_n_for_betteam + ABS(CHECKSUM(NEWID()))) % 18 WHEN 0 THEN '0:0' WHEN 1 THEN '0:1' WHEN 2 THEN '0:2' WHEN 3 THEN '0:3' WHEN 4 THEN '0:4' WHEN 5 THEN '1:0' WHEN 6 THEN '1:1' WHEN 7 THEN '1:2' WHEN 8 THEN '1:3' WHEN 9 THEN '2:0' WHEN 10 THEN '2:1' WHEN 11 THEN '2:2' WHEN 12 THEN '2:3' WHEN 13 THEN '3:0' WHEN 14 THEN '3:1' WHEN 15 THEN '3:2' WHEN 16 THEN '3:3' ELSE '4:0' END WHEN cte.bettype = 126 THEN CASE (cte.original_n_for_betteam + ABS(CHECKSUM(NEWID()))) % 4 WHEN 0 THEN '0-1' WHEN 1 THEN '2-3' WHEN 2 THEN '4&Over' ELSE '4-Over' END WHEN cte.bettype = 127 THEN CASE (cte.original_n_for_betteam + ABS(CHECKSUM(NEWID()))) % 5 WHEN 0 THEN '0:0' WHEN 1 THEN '1:1' WHEN 2 THEN '1:2' WHEN 3 THEN '2:1' ELSE '2:2' END WHEN cte.bettype = 128 THEN CASE (cte.original_n_for_betteam + ABS(CHECKSUM(NEWID()))) % 4 WHEN 0 THEN 'ee' WHEN 1 THEN 'eo' WHEN 2 THEN 'oe' ELSE 'oo' END WHEN cte.bettype = 129 THEN CASE (cte.original_n_for_betteam + ABS(CHECKSUM(NEWID()))) % 6 WHEN 0 THEN '0' WHEN 1 THEN '1' WHEN 2 THEN '2' WHEN 3 THEN '3' WHEN 4 THEN '4' ELSE '5&Over' END WHEN cte.bettype = 130 THEN CASE (cte.original_n_for_betteam + ABS(CHECKSUM(NEWID()))) % 8 WHEN 0 THEN '0' WHEN 1 THEN '1' WHEN 2 THEN '2' WHEN 3 THEN '3' WHEN 4 THEN '4' WHEN 5 THEN '5' WHEN 6 THEN '6' ELSE '7&Over' END WHEN cte.bettype IN (131, 132) THEN CASE (cte.original_n_for_betteam + ABS(CHECKSUM(NEWID()))) % 3 WHEN 0 THEN '0-1' WHEN 1 THEN '2-3' ELSE '4&Over' END WHEN cte.bettype IN (136, 137, 138, 139) THEN CASE (cte.original_n_for_betteam + ABS(CHECKSUM(NEWID()))) % 2 WHEN 0 THEN 'e' ELSE 'o' END ELSE CASE (cte.original_n_for_betteam + ABS(CHECKSUM(NEWID()))) % 2 WHEN 0 THEN 'h' ELSE 'a' END END AS betteam FROM BetTransDataCTE cte;

-- Conditionally insert from #MockBetTransData to the target bettrans table
IF @TargetTableChoice = 1
BEGIN
    INSERT INTO bodb_Archive.dbo.bettrans_bk ( TransId, custid, transdate, oddsid, hdp1, hdp2, odds, stake, status, winlost, awinlost, mwinlost, playercomm, comm, acomm, apositiontaking, mpositiontaking, tpositiontaking, playerdiscount, discount, adiscount, livehomescore, liveawayscore, liveindicator, creator, refno, comstatus, winlostdate, betfrom, betcheck, checktime, oddsspread, actualrate, matchid, recommend, mrecommend, ruben, betid, statuswinlost, modds, bettype, betdaqid, actual_stake, currency, transdesc, sdiscount, scomm, spositiontaking, swinlost, srecommend, virtualrate, oddstype, statusID, currency2, balance, SecAcceptFlag, transid2, ExtraInfo, WalletType, BonusID, RefCode, SettlementTime, epositiontaking, ReasonID, sort, betteam ) SELECT TransId, custid, transdate, oddsid, hdp1, hdp2, odds, stake, status, winlost, awinlost, mwinlost, playercomm, comm, acomm, apositiontaking, mpositiontaking, tpositiontaking, playerdiscount, discount, adiscount, livehomescore, liveawayscore, liveindicator, creator, refno, comstatus, winlostdate, betfrom, betcheck, checktime, oddsspread, actualrate, matchid, recommend, mrecommend, ruben, betid, statuswinlost, modds, bettype, betdaqid, actual_stake, currency, transdesc, sdiscount, scomm, spositiontaking, swinlost, srecommend, virtualrate, oddstype, statusID, currency2, balance, SecAcceptFlag, transid2, ExtraInfo, WalletType, BonusID, RefCode, SettlementTime, epositiontaking, ReasonID, sort, betteam FROM #MockBetTransData;
    PRINT 'Inserted 100 dummy Soccer transactions into bodb_Archive.dbo.bettrans_bk.';
END
ELSE IF @TargetTableChoice = 2
BEGIN
    INSERT INTO bodb02.dbo.bettrans14 ( TransId, custid, transdate, oddsid, hdp1, hdp2, odds, stake, status, winlost, awinlost, mwinlost, playercomm, comm, acomm, apositiontaking, mpositiontaking, tpositiontaking, playerdiscount, discount, adiscount, livehomescore, liveawayscore, liveindicator, creator, refno, comstatus, winlostdate, betfrom, betcheck, checktime, oddsspread, actualrate, matchid, recommend, mrecommend, ruben, betid, statuswinlost, modds, bettype, betdaqid, actual_stake, currency, transdesc, sdiscount, scomm, spositiontaking, swinlost, srecommend, virtualrate, oddstype, statusID, currency2, balance, SecAcceptFlag, transid2, ExtraInfo, WalletType, BonusID, RefCode, SettlementTime, epositiontaking, ReasonID, sort, betteam ) SELECT TransId, custid, transdate, oddsid, hdp1, hdp2, odds, stake, status, winlost, awinlost, mwinlost, playercomm, comm, acomm, apositiontaking, mpositiontaking, tpositiontaking, playerdiscount, discount, adiscount, livehomescore, liveawayscore, liveindicator, creator, refno, comstatus, winlostdate, betfrom, betcheck, checktime, oddsspread, actualrate, matchid, recommend, mrecommend, ruben, betid, statuswinlost, modds, bettype, betdaqid, actual_stake, currency, transdesc, sdiscount, scomm, spositiontaking, swinlost, srecommend, virtualrate, oddstype, statusID, currency2, balance, SecAcceptFlag, transid2, ExtraInfo, WalletType, BonusID, RefCode, SettlementTime, epositiontaking, ReasonID, sort, betteam FROM #MockBetTransData;
    PRINT 'Inserted 100 dummy Soccer transactions into bodb02.dbo.bettrans14.';
END
ELSE IF @TargetTableChoice = 3
BEGIN
    INSERT INTO bodb02.dbo.bettrans ( TransId, custid, transdate, oddsid, hdp1, hdp2, odds, stake, status, winlost, awinlost, mwinlost, playercomm, comm, acomm, apositiontaking, mpositiontaking, tpositiontaking, playerdiscount, discount, adiscount, livehomescore, liveawayscore, liveindicator, creator, refno, comstatus, winlostdate, betfrom, betcheck, checktime, oddsspread, actualrate, matchid, recommend, mrecommend, ruben, betid, statuswinlost, modds, bettype, betdaqid, actual_stake, currency, transdesc, sdiscount, scomm, spositiontaking, swinlost, srecommend, virtualrate, oddstype, statusID, currency2, balance, SecAcceptFlag, transid2, ExtraInfo, WalletType, BonusID, RefCode, SettlementTime, epositiontaking, ReasonID, sort, betteam ) SELECT TransId, custid, transdate, oddsid, hdp1, hdp2, odds, stake, status, winlost, awinlost, mwinlost, playercomm, comm, acomm, apositiontaking, mpositiontaking, tpositiontaking, playerdiscount, discount, adiscount, livehomescore, liveawayscore, liveindicator, creator, refno, comstatus, winlostdate, betfrom, betcheck, checktime, oddsspread, actualrate, matchid, recommend, mrecommend, ruben, betid, statuswinlost, modds, bettype, betdaqid, actual_stake, currency, transdesc, sdiscount, scomm, spositiontaking, swinlost, srecommend, virtualrate, oddstype, statusID, currency2, balance, SecAcceptFlag, transid2, ExtraInfo, WalletType, BonusID, RefCode, SettlementTime, epositiontaking, ReasonID, sort, betteam FROM #MockBetTransData;
    PRINT 'Inserted 100 dummy Soccer transactions into bodb02.dbo.bettrans.';
END;

IF OBJECT_ID('tempdb..#MockBetTransData') IS NOT NULL DROP TABLE #MockBetTransData;

-- Execute the stored procedure for SOCCER to populate the TGRS data
EXEC bodb_tgrs.dbo.Task_StagingDataTGRS
    @Debug = 1,
    @GenerateFromDate = @TargetDate,
    @GenerateToDate = @TargetDate;
PRINT 'Executed Task_StagingDataTGRS for the target date.';

PRINT 'Script finished.';