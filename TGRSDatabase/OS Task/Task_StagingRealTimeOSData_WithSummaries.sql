ALTER PROCEDURE dbo.Task_StagingRealTimeOSData_WithSummaries
    @Debug BIT = 0,
    @LookbackTime DATETIME = NULL
AS
/*
    Created: Jaden@20250507
    Task :   Staging Real-Time Data for Other Sports (OS),
             including daily and monthly summary updates.
             Designed for frequent execution (e.g., every 5 minutes).
    DB:      bodb_TGRS

    Revisions:
        - 20250507@Jaden: Initial creation. Execution frequency: every 5 minutes.

    Parameters:
        @Debug: 0 = No debug messages, 1 = Show debug messages
        @LookbackTime: Look up for matches with bets settled after this time. If NULL, use current time minus 10 minutes.
                       This parameter is designed for testing purpose only.

    Remarks:
        This SP identify "recent data" by matchID, not by using winlostdate
*/
BEGIN
    SET NOCOUNT ON;
    SET ANSI_WARNINGS OFF;

    DECLARE @LookbackMinutes INT = 10; -- Look back slightly more than the job interval

    DECLARE @IdForUnassignedTrader INT = 0; -- Assuming 0 is the ID for unassigned OS traders
    -- If on TESTDB061, then id for unassigned trader is 8 ('sa' user) for easy testing
    IF SERVERPROPERTY('ServerName') = 'TESTDB061'
        SET @IdForUnassignedTrader = 8;

    DECLARE @Begin DATETIME = GETDATE(),
            @Now DATETIME = GETDATE(),
            @RowCount INT,
            @Duration INT,
            @Msg NVARCHAR(MAX);
    
    DECLARE @StartOfMonth DATE;

    IF @LookbackTime IS NULL
        SET @LookbackTime = DATEADD(MINUTE, -@LookbackMinutes, @Now);
    
    SET @StartOfMonth = DATEADD(MONTH, DATEDIFF(MONTH, 0, @Now), 0);

    -- Temp table to store MatchIDs that need processing (recently completed or had recent bets)
    IF OBJECT_ID('tempdb..#tmpOSMatchesToProcess') IS NOT NULL
        DROP TABLE #tmpOSMatchesToProcess;
    CREATE TABLE #tmpOSMatchesToProcess (MatchId INT PRIMARY KEY, EventDate DATETIME, MatchCode VARCHAR(100), LeagueId INT, SportType INT);

    -- Temp table for staging OS trader assignments for relevant matches
    IF OBJECT_ID('tempdb..#tmpRealTimeOSTrader') IS NOT NULL
        DROP TABLE #tmpRealTimeOSTrader;
    CREATE TABLE #tmpRealTimeOSTrader (
        TraderId INT,
        MatchId INT,
        BetType SMALLINT,
        betid BIGINT,
        PRIMARY KEY (MatchId, BetType, betid)
    );

    -- Temp table to filter bets for the identified matches
    IF OBJECT_ID('tempdb..#tmpRealTimeOSFilteredBets') IS NOT NULL
        DROP TABLE #tmpRealTimeOSFilteredBets;
    CREATE TABLE #tmpRealTimeOSFilteredBets (
        TransId BIGINT PRIMARY KEY,
        CustId INT,
        MatchId INT,
        MatchCode VARCHAR(100),
        Winlostdate SMALLDATETIME NOT NULL,
        SportType INT,
        LeagueId INT,
        Bettype SMALLINT,
        Modds SMALLMONEY,
        Stake MONEY,
        Actual_stake MONEY,
        Virtualrate FLOAT,
        Actualrate FLOAT,
        Winlost MONEY,
        Awinlost MONEY,
        Mwinlost MONEY,
        Swinlost MONEY,
        Tpositiontaking SMALLMONEY,
        spositiontaking SMALLMONEY,
        mpositiontaking SMALLMONEY,
        apositiontaking SMALLMONEY,
        Srecommend INT,
        Scomm MONEY,
        Epositiontaking SMALLMONEY,
        LiveIndicator BIT,
        BetChoice NVARCHAR(10),
        betid BIGINT,
        AdjOdds SMALLMONEY,
        OriOdds SMALLMONEY,
        statuswinlost TINYINT,
        oddstype TINYINT,
        isDecOddsOnly BIT,
        hdp SMALLMONEY
    );


    -- Temp table to calculate performance metrics before inserting/merging
    IF OBJECT_ID('tempdb..#tmpRealTimeOSStagingPerformance') IS NOT NULL
        DROP TABLE #tmpRealTimeOSStagingPerformance;
    CREATE TABLE #tmpRealTimeOSStagingPerformance (
        TraderId INT,
        CustId INT,
        EventDate DATE NOT NULL,
        SportType INT,
        LeagueId INT,
        MatchId INT,
        MatchCode VARCHAR(100),
        BetType SMALLINT,
        Stake MONEY,
        WinLost MONEY,
        SMAWinLost MONEY,
        Comm MONEY,
        ExtraPT DECIMAL(9, 8),
        TPositionTaking SMALLMONEY,
        VirtualRate FLOAT,
        ActualRate FLOAT,
        LiveIndicator BIT,
        BetChoice NVARCHAR(10),
        betid BIGINT,
        hdp SMALLMONEY,
        [Target] DECIMAL(18, 2)
    );


    BEGIN TRY

        -- =========================================================================
        -- Step 1: Identify OS Matches to Process
        -- =========================================================================
        -- Find OS matches had bets settled recently

        INSERT INTO #tmpOSMatchesToProcess (MatchId, EventDate, MatchCode, LeagueId, SportType)
        SELECT m.MatchId, m.EventDate, m.matchcode, m.leagueid, m.sporttype
          FROM bodb02.dbo.Match AS m WITH (NOLOCK) 
         WHERE eventstatus = 'completed' 
           AND matchcode NOT LIKE '%hedge%' 
           AND SportType <> 1 -- Other Sports
           AND m.matchid IN (
               SELECT matchid 
                 FROM bodb02.dbo.bettrans AS b WITH (NOLOCK) 
                WHERE b.SettlementTime >= @LookbackTime -- Check when the bet was processed/settled
                  AND b.Currency NOT IN (20, 27, 28)
                  AND b.statusID IN (111, 112, 113)
           )
        OPTION (RECOMPILE)

        SELECT @RowCount = @@ROWCOUNT, @Duration = DATEDIFF(MILLISECOND, @Begin, GETDATE());
        IF @Debug = 1 RAISERROR('Step 1: Identified %d OS matches to process - %d ms', 0, 1, @RowCount, @Duration) WITH NOWAIT;
        SET @Begin = GETDATE(); -- Reset timer for next step

        IF @RowCount = 0
        BEGIN
            IF @Debug = 1 RAISERROR('No new OS matches or settled bets found to process. Exiting.', 0, 1) WITH NOWAIT;
            RETURN; -- Nothing to do
        END

        -- =========================================================================
        -- Step 2: Get Trader Assignments for these Matches
        -- =========================================================================
        -- Fetch latest trader assignment for the identified matches/bettypes
        -- Similar logic as in Task_StagingOSDataTGRS but filtered by #tmpOSMatchesToProcess
        -- This uses Dot_Admin_Assignment_Trader for OS

        -- For special bet types like "Map X Kill markets", the Detail_X, Detail_Y, and Detail_Z fields identify specific sub-bets.
        -- These sub-bets are represented in the bettrans table's betid column.
        -- The betid is calculated using a formula that combines the bettype with Detail_X/Y/Z values. For instance:
        -- - betid 801 represents a bet on Map 1
        -- - betid 802 represents a bet on Map 2 (formula `800 + Detail_X` are common, don't know why the number 800, maybe for good luck?)
        -- But note, not all sports use the same formula (see: https://nexdev.net/projects/sportsbook/wiki/Bet_Types_n_Bet_Options#bBAIO2)

        -- Our system has a limitation: multiple traders can be assigned to the same matchid/bettype/betid combination,
        -- but we have no way to track which trader is actually responsible for each individual bet ticket. As a workaround,
        -- we simply use the most recently assigned trader when joining with bettrans. This means live data views will
        -- show different traders on each refresh - not ideal, but it's the best we can do with our current architecture.
        
        -- See Redmine https://nexdev.net/projects/tgrs-trader-grading-reward-system/wiki/Trader_Performance_change_record_of_data
        -- and commit `65caa8cf80bac8909c1c4ffdd17784028d4c18a3` for more details.

        ;WITH CalculatedBetId AS (
            SELECT
                a.TraderID,
                a.MatchId,
                a.Bettype,
                CASE
                    WHEN a.Detail_Z <> -1 THEN 0
                    WHEN a.Detail_Y <> -1 THEN 
                        CASE
                            WHEN m.SportType IN (27, 50) THEN (800000 + a.Detail_X * 1000 + a.Detail_Y) -- cricket too (8XXXYY)
                            ELSE (80000 + a.Detail_X * 100 + a.Detail_Y)
                        END
                    WHEN a.Detail_X <> -1 THEN
                        CASE
                            WHEN m.SportType IN (27, 50) THEN (8000 + a.Detail_X) -- cricket (8XXX)
                            ELSE (800 + a.Detail_X)
                        END
                    ELSE 0
                END AS betid_calculated,
                UpdatedTime,
                ID
            FROM bodb02.dbo.Dot_Admin_Assignment_Trader AS a WITH (NOLOCK, INDEX(IX_MatchID))
            INNER JOIN #tmpOSMatchesToProcess m WITH (NOLOCK) ON a.MatchId = m.MatchId
            WHERE a.TraderId <> 0
        ),
        RankedAssignments AS (
            SELECT
                TraderId,
                MatchId,
                Bettype,
                betid_calculated,
                ROW_NUMBER() OVER (
                    PARTITION BY MatchId, Bettype, betid_calculated
                    ORDER BY UpdatedTime DESC, ID DESC
                ) AS rn
            FROM CalculatedBetId
        )
        INSERT INTO #tmpRealTimeOSTrader (TraderId, MatchId, BetType, betid)
        SELECT
            ra.TraderID,
            ra.MatchId,
            ra.Bettype,
            ra.betid_calculated
        FROM RankedAssignments ra
        WHERE ra.rn = 1
        OPTION (RECOMPILE);


        SELECT @RowCount = @@ROWCOUNT, @Duration = DATEDIFF(MILLISECOND, @Begin, GETDATE());
        IF @Debug = 1 RAISERROR('Step 2: Fetched %d OS trader assignments - %d ms', 0, 1, @RowCount, @Duration) WITH NOWAIT;
        SET @Begin = GETDATE();

        -- =========================================================================
        -- Step 3: Fetch Filtered Bets for the identified matches
        -- =========================================================================

        -- f_Set_OddsTypeBettypes() can have dupplicated bettypes due to human error
        SELECT DISTINCT BetType
        INTO #tmpDecimalBetTypes
        FROM bodb02.dbo.f_Set_OddsTypeBettypes()

        -- Fetching from BetTrans
        INSERT INTO #tmpRealTimeOSFilteredBets (
            TransId, CustId, MatchId, MatchCode, Winlostdate, SportType, LeagueId, Bettype, Modds, Stake, Actual_stake,
            Virtualrate, Actualrate, Winlost, Awinlost, Mwinlost, Swinlost, Tpositiontaking, spositiontaking,
            mpositiontaking, apositiontaking, Srecommend, Scomm, Epositiontaking, LiveIndicator, BetChoice, betid,
            AdjOdds, OriOdds, statuswinlost, oddstype, isDecOddsOnly, hdp
        )
        SELECT
            b.transid, b.custid, b.matchid, m.matchcode, b.winlostdate, m.sporttype, m.leagueid, b.bettype, b.modds, b.stake, b.actual_stake,
            b.virtualrate, b.actualrate, (b.winlost - b.actual_stake), b.awinlost, b.mwinlost, b.swinlost, b.tpositiontaking, b.spositiontaking,
            b.mpositiontaking, b.apositiontaking, b.srecommend, b.Scomm, b.epositiontaking, b.liveindicator, b.betteam, b.betid,
            [AdjOdds]       = CASE WHEN fdec.BetType IS NOT NULL THEN b.odds - 1 ELSE b.odds END,
            [OriOdds]       = CASE WHEN fdec.BetType IS NOT NULL THEN bi.OriginalOdds - 1 ELSE bi.OriginalOdds END, -- Fetch from BettransInfo
            [statuswinlost] = b.statuswinlost,
            [oddstype]      = b.oddstype,
            [isDecOddsOnly] = CASE WHEN fdec.BetType IS NOT NULL THEN 1 ELSE 0 END,
            b.hdp1
         FROM bodb02.dbo.bettrans AS b WITH (NOLOCK, INDEX(CIX_matchid_bettype))
        INNER JOIN #tmpOSMatchesToProcess m WITH (NOLOCK) ON b.MatchId = m.MatchId -- filter
         LEFT JOIN bodb02.dbo.BettransInfo bi WITH (NOLOCK) ON b.transid = bi.transid
         LEFT JOIN #tmpDecimalBetTypes fdec ON b.bettype = fdec.BetType
        WHERE b.statusID IN (111, 112, 113) 
          AND b.Currency NOT IN (20, 27, 28)
          AND EXISTS (
                SELECT 1
                FROM bodb02.dbo.SportBettypeMatrix sbm WITH (NOLOCK)    
                WHERE sbm.ProductID = 1
                  AND sbm.Sporttype = m.Sporttype
                  AND sbm.Bettype = b.Bettype
            )
          AND b.winlostdate IS NOT NULL -- filter out invalid data (only on Local database)
        OPTION (RECOMPILE);


        SELECT @RowCount = @@ROWCOUNT, @Duration = DATEDIFF(MILLISECOND, @Begin, GETDATE());
        IF @Debug = 1 RAISERROR('Step 3: Fetched %d OS bettrans rows - %d ms', 0, 1, @RowCount, @Duration) WITH NOWAIT;
        SET @Begin = GETDATE();

        -- Recalculate Winlost based on AdjOdds/OriOdds if needed (logic from Task_StagingOSDataTGRS)
        DECLARE @UpdateById_OSRT TINYINT, @Odds_OSRT FLOAT, @winlost_OSRT MONEY;

        UPDATE b
        SET   @UpdateById_OSRT = CASE WHEN b.isDecOddsOnly = 1 OR b.OriOdds * b.AdjOdds > 0 THEN 1 ELSE 2 END
            , @Odds_OSRT = CASE WHEN
                            (
                                ((b.isDecOddsOnly = 1 OR (b.OriOdds > 0 AND b.AdjOdds > 0)) AND b.statuswinlost IN (1, 2)) -- WIN, HALF WIN
                                OR (b.isDecOddsOnly <> 1 AND b.OriOdds < 0 AND b.AdjOdds < 0 AND b.statuswinlost IN (3, 4)) -- LOSE, HALF LOSE (for negative odds types)
                            ) THEN CAST(b.OriOdds AS FLOAT) / b.AdjOdds
                        ELSE 1 END
            , @winlost_OSRT = CASE 
                            WHEN (b.OriOdds < 0 AND b.AdjOdds > 0) THEN
                                CASE 
                                    WHEN b.statuswinlost = 2 THEN (b.winlost / b.AdjOdds) -- won  
                                    WHEN b.statuswinlost = 1 THEN (b.winlost / b.AdjOdds) -- half won  
                                    WHEN b.statuswinlost = 4 THEN (-1) * (b.winlost * b.OriOdds) -- lose  
                                    WHEN b.statuswinlost = 3 THEN (-1) * (b.winlost * b.OriOdds) -- half lose
                                END  
                            WHEN (b.OriOdds > 0 AND b.AdjOdds < 0) THEN  
                                CASE 
                                    WHEN b.statuswinlost = 2 THEN (-1) * (b.Actual_stake * b.OriOdds / b.AdjOdds) -- won  
                                    WHEN b.statuswinlost = 1 THEN (-1) * (b.Actual_stake * b.OriOdds / b.AdjOdds) * 0.5 -- half won  
                                    WHEN b.statuswinlost = 4 THEN (b.Actual_stake / b.AdjOdds) -- lose  
                                    WHEN b.statuswinlost = 3 THEN (b.Actual_stake / b.AdjOdds) * 0.5 -- half lose
                                END
                         END
            , b.winlost  = ISNULL(CASE @UpdateById_OSRT WHEN 1 THEN b.winlost * @Odds_OSRT WHEN 2 THEN @winlost_OSRT END, b.winlost)
            , b.swinlost = ISNULL(CASE @UpdateById_OSRT WHEN 1 THEN b.swinlost * @Odds_OSRT WHEN 2 THEN b.spositiontaking * @winlost_OSRT END, b.swinlost)
            , b.mwinlost = ISNULL(CASE @UpdateById_OSRT WHEN 1 THEN b.mwinlost * @Odds_OSRT WHEN 2 THEN b.mpositiontaking * @winlost_OSRT END, b.mwinlost)
            , b.awinlost = ISNULL(CASE @UpdateById_OSRT WHEN 1 THEN b.awinlost * @Odds_OSRT WHEN 2 THEN b.apositiontaking * @winlost_OSRT END, b.awinlost)
         FROM #tmpRealTimeOSFilteredBets AS b
        WHERE b.OriOdds IS NOT NULL
          AND b.OriOdds <> 0
          AND b.AdjOdds <> 0
          AND b.isDecOddsOnly IS NOT NULL;

        SELECT @RowCount = @@ROWCOUNT, @Duration = DATEDIFF(MILLISECOND, @Begin, GETDATE());
        IF @Debug = 1 RAISERROR('Step 3a: Recalculated winlost for %d rows in #tmpRealTimeOSFilteredBets - %d ms', 0, 1, @RowCount, @Duration) WITH NOWAIT;
        SET @Begin = GETDATE();

        -- =========================================================================
        -- Step 4: Calculate Staging Performance Data
        -- =========================================================================
        INSERT INTO #tmpRealTimeOSStagingPerformance (
            TraderId, CustId, EventDate, SportType, LeagueId, MatchId, MatchCode, BetType,
            Stake, WinLost, SMAWinLost, Comm, ExtraPT, TPositionTaking, VirtualRate,
            ActualRate, LiveIndicator, BetChoice, betid, hdp, [Target]
        )
        SELECT
            [TraderId]       = ISNULL(t.TraderId, @IdForUnassignedTrader),
            [CustId]         = b.custid,
            [EventDate]      = b.winlostdate,
            [SportType]      = b.SportType,
            [LeagueId]       = b.LeagueId,
            [MatchId]        = b.matchid,
            [MatchCode]      = b.MatchCode,
            [BetType]        = b.bettype,
            [Stake]          = ((CASE WHEN b.modds = 0.25 OR b.modds = -0.25 THEN ABS(b.stake) / 2 ELSE ABS(b.stake) END)),
            [WinLost]        = b.winlost, -- Use potentially recalculated winlost
            [SMAWinLost]     = (b.awinlost + b.mwinlost + b.swinlost), -- Use potentially recalculated SMA winlost
            [Comm]           = b.scomm,
            [ExtraPT]        = ISNULL(b.epositiontaking, 0), -- Assumes ExtraPT is directly in epositiontaking for OS post 20200213
            [TPositionTaking]= b.tpositiontaking,
            [VirtualRate]    = b.virtualrate,
            [ActualRate]     = b.actualrate,
            [LiveIndicator]  = b.LiveIndicator,
            [BetChoice]      = b.BetChoice,
            [betid]          = b.betid,
            [hdp]            = b.hdp,
            [Target]         = dbo.f_GetOSTargetBySportLeagueBettype(b.SportType, b.LeagueId, b.BetType, b.winlostdate)
         FROM #tmpRealTimeOSFilteredBets AS b
         LEFT JOIN #tmpRealTimeOSTrader AS t WITH (NOLOCK)
           ON b.matchid = t.matchid
          AND b.bettype = t.BetType
          AND b.betid = (CASE WHEN t.betid <> 0 THEN t.betid ELSE b.betid END) -- Mapping logic for 80X/80X0Y types
        OPTION (MAXDOP 2);


        SELECT @RowCount = @@ROWCOUNT, @Duration = DATEDIFF(MILLISECOND, @Begin, GETDATE());
        IF @Debug = 1 RAISERROR('Step 4: Calculated %d staging performance rows - %d ms', 0, 1, @RowCount, @Duration) WITH NOWAIT;
        SET @Begin = GETDATE();

        -- =========================================================================
        -- Step 5: Update Target Tables within a Transaction
        -- =========================================================================
        BEGIN TRANSACTION;

        -- Delete existing data
        DELETE TGT
          FROM dbo.OSDataTGRS AS TGT
         WHERE EXISTS (
               SELECT 1
                 FROM #tmpRealTimeOSStagingPerformance AS SRC
                WHERE TGT.MatchId = SRC.MatchId 
                  AND TGT.MatchCode = SRC.MatchCode
                  AND TGT.EventDate = SRC.EventDate
                  AND TGT.TraderId = SRC.TraderId
                  AND TGT.BettypeId = SRC.BetType
                  AND TGT.LeagueId = SRC.LeagueId
                  AND TGT.SportId = SRC.SportType
                  AND TGT.[Target] = SRC.[Target]
                  AND TGT.IsLive = SRC.LiveIndicator
        );

        SELECT @RowCount = @@ROWCOUNT;
        IF @Debug = 1 RAISERROR('Step 5a: Deleted %d existing rows from OSDataTGRS for processed matches', 0, 1, @RowCount) WITH NOWAIT;

        DELETE TGT
          FROM dbo.OSDataTGRS_BetChoice AS TGT
         WHERE EXISTS (
               SELECT 1
                 FROM #tmpRealTimeOSStagingPerformance AS SRC
                WHERE TGT.MatchId = SRC.MatchId
                  AND TGT.EventDate = SRC.EventDate
                  AND TGT.TraderId = SRC.TraderId
                  AND TGT.BettypeId = SRC.BetType
                  AND TGT.BetChoice = SRC.BetChoice
                  AND TGT.LeagueId = SRC.LeagueId
                  AND TGT.SportId = SRC.SportType
                  AND TGT.IsLive = SRC.LiveIndicator
                  AND TGT.hdp = SRC.hdp
                  AND TGT.betid = SRC.betid
        );

        SELECT @RowCount = @@ROWCOUNT;
        IF @Debug = 1 RAISERROR('Step 5b: Deleted %d existing rows from OSDataTGRS_BetChoice for processed matches', 0, 1, @RowCount) WITH NOWAIT;


        -- Insert the newly calculated aggregated data for these matches
        INSERT INTO dbo.OSDataTGRS (
            TraderId, MatchId, MatchCode, EventDate, SportId, LeagueId, BettypeId,
            Turnover, WinLoss, Comm, Turnover_AR, WinLoss_AR, Comm_AR, BetCount, [Target], IsLive
        )
        SELECT
            [TraderId]    = b.TraderId,
            [MatchId]     = b.MatchId,
            [MatchCode]   = b.MatchCode,
            [EventDate]   = b.EventDate,
            [SportId]     = b.SportType,
            [LeagueId]    = b.LeagueId,
            [BettypeId]   = b.BetType,
            [Turnover]    = SUM(b.Stake * (1 - b.TPositionTaking - b.ExtraPT) * b.VirtualRate),
            [WinLoss]     = SUM(((-(b.WinLost + b.SMAWinLost)) + b.WinLost * b.ExtraPT) * b.VirtualRate),
            [Comm]        = SUM((b.Comm - (CASE WHEN b.TPositionTaking = 1 THEN 0 ELSE (b.Comm * b.ExtraPT / (ISNULL(NULLIF(1 - b.TPositionTaking,0),1))) END)) * (CASE WHEN b.VirtualRate > b.ActualRate THEN b.ActualRate ELSE b.VirtualRate END)),
            [Turnover_AR] = SUM(b.Stake * (1 - b.TPositionTaking - b.ExtraPT) * (CASE WHEN b.VirtualRate > b.ActualRate THEN b.VirtualRate ELSE b.ActualRate END)),
            [WinLoss_AR]  = SUM(((-(b.WinLost + b.SMAWinLost)) + b.WinLost * b.ExtraPT) * b.ActualRate),
            [Comm_AR]     = SUM((b.Comm - (CASE WHEN b.TPositionTaking = 1 THEN 0 ELSE (b.Comm * b.ExtraPT / (ISNULL(NULLIF(1 - b.TPositionTaking,0),1))) END)) * b.ActualRate),
            [BetCount]    = COUNT(b.CustId), -- Counting CustId to represent bets
            [Target]      = dbo.f_GetOSTargetBySportLeagueBettype(b.SportType, b.LeagueId, b.BetType, b.EventDate),
            [IsLive]      = b.LiveIndicator
        FROM #tmpRealTimeOSStagingPerformance AS b WITH (NOLOCK)
        GROUP BY b.TraderId, b.MatchId, b.MatchCode, b.EventDate, b.SportType, b.LeagueId, b.BetType, b.LiveIndicator;

        SELECT @RowCount = @@ROWCOUNT;
        IF @Debug = 1 RAISERROR('Step 5c: Inserted %d rows into OSDataTGRS', 0, 1, @RowCount) WITH NOWAIT;


        INSERT INTO dbo.OSDataTGRS_BetChoice (
            TraderId, SportId, LeagueId, MatchId, EventDate, BettypeId, BetChoice, betid,
            Turnover, WinLoss, Comm, Turnover_AR, WinLoss_AR, Comm_AR, BetCount, IsLive, hdp
        )
        SELECT
            [TraderId]   = b.TraderId,
            [SportId]    = b.SportType,
            [LeagueId]   = b.LeagueId,
            [MatchId]    = b.MatchId,
            [EventDate]  = b.EventDate,
            [BettypeId]  = b.BetType,
            [BetChoice]  = b.BetChoice,
            [betid]      = b.betid,
            [Turnover]   = SUM(b.Stake * (1 - b.TPositionTaking - b.ExtraPT) * b.VirtualRate),
            [WinLoss]    = SUM(((-(b.WinLost + b.SMAWinLost)) + b.WinLost * b.ExtraPT) * b.VirtualRate),
            [Comm]       = SUM((b.Comm - (CASE WHEN b.TPositionTaking = 1 THEN 0 ELSE (b.Comm * b.ExtraPT / (ISNULL(NULLIF(1 - b.TPositionTaking,0),1))) END)) * (CASE WHEN b.VirtualRate > b.ActualRate THEN b.ActualRate ELSE b.VirtualRate END)),
            [Turnover_AR]= SUM(b.Stake * (1 - b.TPositionTaking - b.ExtraPT) * (CASE WHEN b.VirtualRate > b.ActualRate THEN b.VirtualRate ELSE b.ActualRate END)),
            [WinLoss_AR] = SUM(((-(b.WinLost + b.SMAWinLost)) + b.WinLost * b.ExtraPT) * b.ActualRate),
            [Comm_AR]    = SUM((b.Comm - (CASE WHEN b.TPositionTaking = 1 THEN 0 ELSE (b.Comm * b.ExtraPT / (ISNULL(NULLIF(1 - b.TPositionTaking,0),1))) END)) * b.ActualRate),
            [BetCount]   = COUNT(b.CustId), -- Counting CustId to represent bets
            [IsLive]     = b.LiveIndicator,
            [hdp]        = b.hdp
        FROM #tmpRealTimeOSStagingPerformance AS b WITH (NOLOCK)
        GROUP BY b.TraderId, b.SportType, b.LeagueId, b.MatchId, b.EventDate, b.BetType, b.BetChoice, b.betid, b.LiveIndicator, b.hdp;

        SELECT @RowCount = @@ROWCOUNT;
        IF @Debug = 1 RAISERROR('Step 5d: Inserted %d rows into OSDataTGRS_BetChoice', 0, 1, @RowCount) WITH NOWAIT;


        COMMIT TRANSACTION;

        SELECT @Duration = DATEDIFF(MILLISECOND, @Begin, GETDATE());
        IF @Debug = 1 RAISERROR('Step 5: Updated/Inserted data into target tables - %d ms', 0, 1, @Duration) WITH NOWAIT;
        SET @Begin = GETDATE();

        -- =========================================================================
        -- Step 6: Update Daily Summaries
        -- =========================================================================
        DECLARE @CurrentEventDate DATE;
        DECLARE EventDateCursor CURSOR FOR 
            SELECT DISTINCT EventDate 
            FROM #tmpOSMatchesToProcess 
            ORDER BY EventDate;

        OPEN EventDateCursor;
        FETCH NEXT FROM EventDateCursor INTO @CurrentEventDate;

        WHILE @@FETCH_STATUS = 0
        BEGIN
            IF @Debug = 1 
            BEGIN
                SET @Msg = FORMATMESSAGE('Step 6a: Calling Task_StagingOSTraderPerformanceByDate for %s', CONVERT(VARCHAR, @CurrentEventDate));
                RAISERROR(@Msg, 0, 1) WITH NOWAIT;
            END

            EXEC dbo.Task_StagingOSTraderPerformanceByDate @Date = @CurrentEventDate;

            FETCH NEXT FROM EventDateCursor INTO @CurrentEventDate;
        END

        CLOSE EventDateCursor;
        DEALLOCATE EventDateCursor;

        SELECT @Duration = DATEDIFF(MILLISECOND, @Begin, GETDATE());
        IF @Debug = 1 RAISERROR('Step 6: Daily summary update completed - %d ms', 0, 1, @Duration) WITH NOWAIT;
        SET @Begin = GETDATE();

        -- =========================================================================
        -- Step 7: Update Monthly Summaries
        -- =========================================================================
        IF @Debug = 1
        BEGIN
            SET @Msg = FORMATMESSAGE('Step 7a: Calling Task_StagingOSTraderPerformanceMonthly for %s', CONVERT(VARCHAR, @StartOfMonth));
            RAISERROR(@Msg, 0, 1) WITH NOWAIT;
        END
        EXEC dbo.Task_StagingOSTraderPerformanceMonthly @Month = @StartOfMonth;

        SELECT @Duration = DATEDIFF(MILLISECOND, @Begin, GETDATE());
        IF @Debug = 1 
        BEGIN
            SET @Msg = FORMATMESSAGE('Step 7: Monthly summary update completed - %d ms', @Duration);
            RAISERROR(@Msg, 0, 1) WITH NOWAIT;
        END

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        DECLARE @ErrorMessage NVARCHAR(MAX), @ErrorSeverity INT, @ErrorState INT;
        SELECT @ErrorMessage = ERROR_MESSAGE(), @ErrorSeverity = ERROR_SEVERITY(), @ErrorState = ERROR_STATE();

        RAISERROR (@ErrorMessage, @ErrorSeverity, @ErrorState);

        RETURN;
    END CATCH;

    -- Cleanup temp tables
    IF OBJECT_ID('tempdb..#tmpOSMatchesToProcess') IS NOT NULL DROP TABLE #tmpOSMatchesToProcess;
    IF OBJECT_ID('tempdb..#tmpRealTimeOSTrader') IS NOT NULL DROP TABLE #tmpRealTimeOSTrader;
    IF OBJECT_ID('tempdb..#tmpRealTimeOSFilteredBets') IS NOT NULL DROP TABLE #tmpRealTimeOSFilteredBets;
    IF OBJECT_ID('tempdb..#tmpRealTimeOSStagingPerformance') IS NOT NULL DROP TABLE #tmpRealTimeOSStagingPerformance;

    IF @Debug = 1 RAISERROR('Procedure Task_StagingRealTimeOSData_WithSummaries finished successfully.', 0, 1) WITH NOWAIT;

END;
GO
/*<info serverAlias="DBTGRS-bodb_TGRS" executers="wsv_tgrs" isFunction="0" isNested="0"></info>*/