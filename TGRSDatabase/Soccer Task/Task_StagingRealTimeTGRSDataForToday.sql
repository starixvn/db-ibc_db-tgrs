ALTER PROCEDURE	[dbo].[Task_StagingRealTimeTGRSDataForToday]
	@Debug				BIT = 0
AS
/*
	Created:	20171017@Long.Luu
	Task :		Staging Data for Today on TGRS DB
	DB:			DB06.bodb_TGRS_UAT & DB061.bodb_TGRS
	Original:
  
	Revisions:
   		- 20171017@Long.Luu: Create new		
		- 20171129@Long.Luu: Support Live Status
		- 20180117@Long.Luu: Support BetChoice for RealTime job [Redmine ID: 87861]
		- 20180119@John.Ngo: Update Logic generating data [Redmine: #87861]
		- 20180416@John.Ngo: Update formular for calculating extra PT
		- 20180419@Long.Luu: Add 2 more bettypes for Asian 1x2 HDP [Redmine: #93890]
		- 20180504@John.Ngo: Update formular to get @WinLostDate
		- 20180516@Long:	Filter unsupported bettypes
		- 20180618@John.Ngo: Missing data of FT bettype #97059
		- 20180822@John.Ngo: Missing data of 124, 125 bettype #100251
		- 20180823@Long.Luu: Manage for case changing the status of match before bettrans [Redmine ID: 97987]
		- 20180824@Casey.Huynh: Fix Issue get Bettype. Add SpecialBettype for FillterBettrans Instead of Trader [Redmine ID:89493]
		- 20180911@Long:	Support excluding Leagues from report [Redmine ID: #100322]
   		- 20180924@Long:	Fix bug for updating juice value only for Live data
		- 20180924Casey.Huynh: Update condition get data to table "TraceScannedMatchesInfo"
		- 20190108@John:	Exclude Cashout tickets from Betcount figures in TGR reports [Redmine ID: 107602]
		- 20190128@John:	Fix Null value for Grade & Team [Redmine ID: 107809]
		- 20190304@Long:	Calc Actual-rate values for Soccer [Redmine ID: 108920]
		- 20190513@John.Ngo: Update the logic on checking match to prepare data for trading performance [Redmine ID: 113321]
		- 20190704@John.Ngo: Implement change request to the job sum and enhance logic on Extra PT WL calculation [Redmine ID: 116379]
		- 20190822@Long.Luu: Grade brokendown for details performance [Redmine ID: 117030]
		- 20190822@Long.Luu: Suppport Non-Live Data [Redmine ID: 118959]
		- 20200331@John.Ngo: Update new table [Dot_Admin_Assignment_Trader] [Redmine ID: 120634]
		- 20200416@John.Ngo: [TGR] Extend league data type [Redmine ID: 132630]
		- 20200504@John.Ngo: [TGR] Get ExtraPT from epositiontaking column in bettrans table [Redmine ID: 133409]
		- 20200721@John.Ngo: New Negative Bettype No Of Corner HDP [Redmine ID: 138095]
		- 20201017@John.Ngo: TGR - Integrate Adjustmnet Odds Spread of Licensee [Redmine ID: 142421]
		- 20201112@John.Ngo: TGR - Enhance formula of calculating adjusted odds by Licensee [Redmine ID: 145246]
		- 20210811@Adam.Tran: TGR - Sports - Performance Real Figures [Redmine: #158981]
	Param's Explanation:
		
	Exam:
	 
*/
BEGIN
	SET NOCOUNT ON;

	DECLARE	@IdForLiveUnassignedTrader		INT = 0
		,	@IdForNonLiveUnassignedTrader	INT = -1;

	DECLARE	@Begin		DATETIME = GETDATE()
		,	@RowCount	INT
		,	@Duration	INT
		,	@Today		SMALLDATETIME = GETDATE();

	IF	OBJECT_ID('tempdb..#tmpRTScannedMatches') IS NOT NULL
	BEGIN
		DROP TABLE #tmpRTScannedMatches;
	END;

	CREATE TABLE	#tmpRTScannedMatches (
			  MatchId		INT NOT NULL
			, EventDate		DATETIME
			, KickOffTime	DATETIME
			, WorkShift		TINYINT
			, MatchCode		NVARCHAR(50)			
			, LeagueId		INT			
			, SportType		INT
			, HomeId		INT
			, AwayId		INT
			, LeagueName	NVARCHAR(512)
			, HomeName		NVARCHAR(100)
			, SpecialType	INT				
	);
	
	CREATE CLUSTERED INDEX	#CIX_tmpRTScannedMatches_MatchId ON #tmpRTScannedMatches (
		MatchId		ASC
	);
		
	IF	OBJECT_ID('tempdb..#tmpRTSupportedBettypes') IS NOT NULL
	BEGIN
		DROP TABLE	#tmpRTSupportedBettypes
	END;

	CREATE TABLE	#tmpRTSupportedBettypes (
			BetType					SMALLINT PRIMARY KEY
	);
	
	INSERT INTO #tmpRTSupportedBettypes(BetType)
	SELECT b.BetType
	FROM dbo.BetType b WITH(NOLOCK)
	WHERE b.BetType > 0;

	-- STEP #1: STAGING DATA
	IF	OBJECT_ID('tempdb..#tmpRTSpread1x2') IS NOT NULL
	BEGIN
		DROP TABLE	#tmpRTSpread1x2;
	END;

	CREATE TABLE	#tmpRTSpread1x2 (
						Margin	MONEY
					,	Spread	MONEY
					);
						
	INSERT INTO	#tmpRTSpread1x2
			(Margin, Spread)
	VALUES	(1.05  , 0.2   )
		,	(1.08  , 0.3   )
		,	(1.10  , 0.36  )
		,	(1.12  , 0.44  )
		,	(1.15  , 0.52  );
		
	IF	OBJECT_ID('tempdb..#tmp8RMMembers') IS NOT NULL
		BEGIN
			DROP TABLE #tmp8RMMembers;
		END;

	CREATE TABLE	#tmp8RMMembers (
			CustId			INT PRIMARY KEY CLUSTERED
	);

	IF	OBJECT_ID('tempdb..#tmpRTTrader') IS NOT NULL
	BEGIN
		DROP TABLE #tmpRTTrader;
	END;

	CREATE TABLE	#tmpRTTrader (
			TraderId			INT
		,	LeagueId			INT
		,	MatchId				INT
		,	EventDate			DATETIME
		,	Bettype				INT
		,	TeamId				INT
		,	Grade				TINYINT
	);

	CREATE CLUSTERED INDEX	#CIX_tmpRTTraderIdx ON #tmpRTTrader (
			EventDate			ASC
		,	MatchId				ASC
		,	BetType				ASC
	);
	
	IF	OBJECT_ID('tempdb..#ExtraPTSportbook') IS NOT NULL
	BEGIN
		DROP TABLE	#ExtraPTSportbook;
	END;

	CREATE TABLE #ExtraPTSportbook
	(
		SuperId		INT,
		ExtraPT		MONEY,
		FromDate	DATETIME,
		ToDate		DATETIME
	);
							
	IF	OBJECT_ID('tempdb..#tmpRTFilteredBettransByBatch') IS NOT NULL
	BEGIN
		DROP TABLE	#tmpRTFilteredBettransByBatch;
	END;

	CREATE TABLE	#tmpRTFilteredBettransByBatch (
			TransId				BIGINT
		,	CustId				INT
		,	MatchId				INT
		,	WorkShift			INT
		,	Winlostdate			SMALLDATETIME
		,	Bettype				SMALLINT
		,	SpecialType			INT
		,	Modds				SMALLMONEY
		,	Virtualrate			FLOAT
		,	Actualrate			FLOAT
		,	Tpositiontaking		SMALLMONEY
		,	spositiontaking		SMALLMONEY
		,	mpositiontaking		SMALLMONEY
		,	apositiontaking		SMALLMONEY
		,	Srecommend			INT
		,	Scomm				MONEY
		,	ExtraPT				DECIMAL(12, 8)
		,	Spread				MONEY
		,	Stake				MONEY
		,	actual_stake		MONEY
		,	winlost				MONEY
		,	awinlost			MONEY
		,	mwinlost			MONEY
		,	swinlost			MONEY
		,	MatchCode			VARCHAR(100)
		,	EventDate			DATETIME
		,	SportType			INT
		,	LeagueId			INT
		,	HomeId				INT
		,	AwayId				INT
		,	LiveIndicator		BIT
		,	Is8RM				BIT
		,   BetChoice			NVARCHAR(10)
		,	AdjOdds				SMALLMONEY
		,	OriOdds				SMALLMONEY
		,	statuswinlost		TINYINT
		,	oddstype			TINYINT
		,	isDecOddsOnly		BIT
	);
	
	IF	OBJECT_ID('tempdb..#tmpRTStagingTraderPerformance') IS NOT NULL
	BEGIN
		DROP TABLE	#tmpRTStagingTraderPerformance;
	END;

	CREATE TABLE	#tmpRTStagingTraderPerformance (
			TraderId			INT
		,	CustId				INT
		,	WorkShift			TINYINT
		,	MatchId				INT
		,	MatchCode			VARCHAR(100)
		,	EventDate			DATETIME
		,	SportType			INT
		,	LeagueId			INT
		,	HomeId				INT
		,	AwayId				INT
		,	TeamId				INT
		,	Grade				TINYINT
		,	BetType				SMALLINT
		,	Stake				MONEY
		,	WinLost				MONEY
		,	SMAWinLost			MONEY
		,	Comm				MONEY
		,	BetCount			INT
		,	Spread				MONEY
		,	ExtraPT				DECIMAL(12, 8)
		,	TPositionTaking		SMALLMONEY
		,	VirtualRate			FLOAT
		,	ActualRate			FLOAT
		,	LiveIndicator		BIT
		,	Is8RM				BIT
		,   BetChoice			NVARCHAR(10) 
	);
	
	CREATE CLUSTERED INDEX #CIX_tmpRTStagingTraderPerformanceIdx ON #tmpRTStagingTraderPerformance (
			TraderId			ASC
		,	EventDate			ASC
	); 
	
	CREATE NONCLUSTERED INDEX	#NCIX_tmpRTStagingTraderPerformanceIdx ON #tmpRTStagingTraderPerformance (
			CustId		ASC
	);

	IF	OBJECT_ID('tempdb..#tmpRTWinlostdate') IS NOT NULL
		BEGIN
			DROP TABLE	#tmpRTWinlostdate;
		END;

		CREATE TABLE	#tmpRTWinlostdate (
			Winlostdate				DATE
		);

	DECLARE @WinLostDate DATE;
	DECLARE @CurrentDate DATE = CONVERT(DATE, GETDATE());
	DECLARE @CurrentDateBefore1Hour DATE =  CONVERT(DATE, DATEADD(HOUR, -1, GETDATE()));

	DECLARE @Odds		FLOAT
		,	@winlost	MONEY
		,	@UpdateById TINYINT = 1; -- 1: by odds, 2: by winlost

	INSERT INTO #tmpRTWinlostdate (winlostdate)
	SELECT DISTINCT winlostdate
	FROM (VALUES (@CurrentDate), (@CurrentDateBefore1Hour)) d(winlostdate);

	INSERT INTO #tmp8RMMembers(CustId)
	SELECT c.custid
	FROM bodb02.dbo.custInfo AS c WITH(NOLOCK)
	WHERE c.recommend = 52466;

	-- START TO CALC
	WHILE EXISTS (SELECT 1 FROM #tmpRTWinlostdate)
	BEGIN
		TRUNCATE TABLE #tmpRTTrader;
		TRUNCATE TABLE #tmpRTScannedMatches;
		TRUNCATE TABLE #ExtraPTSportbook;

		SELECT	TOP(1)
				@WinLostDate = d.winlostdate
		FROM	#tmpRTWinlostdate AS d
		ORDER BY winlostdate ASC;
		
		-- GET Scanned Match List: Completed Soccer Match
		INSERT INTO #tmpRTScannedMatches(MatchId, EventDate, KickOffTime,WorkShift, MatchCode, LeagueId, SportType, HomeId, AwayId, LeagueName, HomeName, SpecialType)
		SELECT	m.matchid
				, m.eventdate
				, m.kickofftime
	 			, CASE	WHEN CAST(m.kickofftime AS TIME) >= '00:00:00' AND CAST(m.kickofftime AS TIME) < '06:00:00'
								THEN 1 --  Afternoon: 12:00:00 ~ 17:59:59 (GMT + 8)
							WHEN CAST(m.kickofftime AS TIME) >= '06:00:00' AND CAST(m.kickofftime AS TIME) < '16:00:00'
								THEN 2 -- Night: 18:00:00 ~ 3:59:59 (GMT + 8)				
							--WHEN CAST(m.kickofftime AS TIME) >= '16:00:00' AND CAST(m.kickofftime AS TIME) <'24:00:00'THEN 3 --  Midnight: 4:00:00 ~ 11:59:59 (GMT + 8)
							ELSE 3
				  END AS WorkShift
				, m.matchcode
				, m.leagueid
				, m.SportType
				, m.homeid
				, m.awayId
				, l.leaguename
				, t.teamname AS HomeName
				, CASE	WHEN l.LeagueName LIKE '%SPECIFIC 15 MINS TOTAL BOOKINGS%'
							THEN 1
						WHEN l.LeagueName LIKE '%SPECIFIC 15 MINS%' AND t.teamname LIKE '%No.of Corners%'
							THEN 2
						WHEN l.LeagueName LIKE '%SPECIALS' AND (t.teamname LIKE '%Over' OR t.teamname LIKE '%Under')
							THEN 3
						WHEN l.LeagueName LIKE '%SPECIFIC 15 MINS%'
							THEN 4
						WHEN l.LeagueName LIKE '%SPECIFIC 10 MINS%'
							THEN 5
						WHEN t.teamname LIKE '%No.of Corners%'
							THEN 6
						WHEN t.teamname LIKE '%Total Bookings'
							THEN 7
						WHEN t.teamname LIKE '%Corner%'
							THEN 8
						WHEN t.teamname LIKE '%Booking'
							THEN 9
						ELSE 0
					END AS SpecialType
		FROM	bodb02.dbo.Match AS m WITH (NOLOCK)
				INNER JOIN bodb02.dbo.league AS l WITH (NOLOCK) ON l.leagueid = m.leagueid
				LEFT JOIN bodb02.dbo.team AS t WITH (NOLOCK) ON t.teamid = HomeId
				LEFT JOIN dbo.TraderPerformance AS tp WITH(NOLOCK) ON tp.MatchId = m.matchid
		WHERE	m.EventDate = @WinlostDate
				AND	m.SportType = 1
				AND m.EventStatus = 'completed'
				AND	m.MatchCode NOT LIKE '%hedge%'
				AND tp.MatchId IS NULL;
										
		SELECT	@RowCount	= @@ROWCOUNT
			,	@Duration	= DATEDIFF(millisecond, @Begin, GETDATE());

		IF	@Debug = 1
		BEGIN
			-- Force the output to appear immediately --
			RAISERROR('Insert #tmpRTScannedMatches - %d rows - %d ms', 0, 0, @RowCount, @Duration) WITH NOWAIT;
		END;		
		
		-- REMOVE Scanned Match List: if existing any Ticket has not been settled (ruben <> 1)
		DELETE	sm
		FROM	#tmpRTScannedMatches AS sm WITH (ROWLOCK)
		WHERE	sm.MatchId  IN (	SELECT	TOP(1) b.MatchId
									FROM	bodb02.dbo.bettrans AS b WITH(NOLOCK) 
									WHERE	b.matchid = sm.matchid
											AND b.Currency NOT IN (20, 27, 28) 
											AND b.ruben <> 1);		

		INSERT INTO	#tmpRTTrader (TraderId, LeagueId, MatchId, EventDate, BetType, TeamId, Grade)
		SELECT	DISTINCT
				[TraderId]		= a.TraderId
			,	[LeagueId]		= m.LeagueId
			,	[MatchId]		= m.MatchId
			,	[EventDate]		= m.EventDate
			,	[BetType]		= a.bettype
			,	[TeamId]		= td_T.TeamId
			,	[Grade]			= td_G.Grade
		FROM	bodb02.dbo.Dot_Admin_Assignment_Trader AS a WITH (NOLOCK)
		INNER JOIN	#tmpRTScannedMatches AS m WITH (NOLOCK) ON m.MatchId = a.Matchid
		LEFT JOIN	#tmpRTSupportedBettypes AS b WITH(NOLOCK) ON b.BetType = a.bettype
		LEFT JOIN	dbo.TraderGrade_History AS td_G WITH (NOLOCK) ON td_G.CustID = a.TraderId
				AND	m.EventDate BETWEEN td_G.BeginDate AND ISNULL(td_G.EndDate, @Today + 10)
		LEFT JOIN	dbo.TraderTeam_History AS td_T WITH (NOLOCK) ON	td_T.CustID = a.TraderId
				AND	m.EventDate BETWEEN td_T.BeginDate AND ISNULL(td_T.EndDate, @Today + 10)
		CROSS APPLY (
					SELECT dt.TraderID, dt.MatchId, dt.Bettype,
						ROW_NUMBER() OVER(PARTITION BY dt.MatchId, dt.Bettype ORDER BY dt.UpdatedTime DESC, dt.ID DESC) AS Row_Num
					FROM bodb02.dbo.Dot_Admin_Assignment_Trader AS dt WITH (NOLOCK)
					WHERE   a.matchid = dt.matchid
						AND a.bettype = dt.bettype		
						AND a.TraderId <> 0
					) dat
		WHERE	m.EventDate = @WinlostDate
				AND a.TraderId <> 0
				AND a.TraderID = dat.TraderID
				AND a.MatchId = dat.MatchId
				AND a.Bettype = dat.Bettype
				AND dat.Row_Num = 1;
		
		SELECT	@RowCount	= @@ROWCOUNT
			,	@Duration	= DATEDIFF(millisecond, @Begin, GETDATE());

		IF	@Debug = 1
		BEGIN
			-- Force the output to appear immediately --
			RAISERROR('Insert #tmpRTTrader - %d rows - %d ms', 0, 0, @RowCount, @Duration) WITH NOWAIT;
		END;	

		TRUNCATE TABLE	#tmpRTFilteredBettransByBatch;
		INSERT INTO	#tmpRTFilteredBettransByBatch (TransId, CustId, MatchId, WorkShift, SpecialType, Winlostdate, Bettype, Modds, Virtualrate, Actualrate, Tpositiontaking,
						spositiontaking, mpositiontaking, apositiontaking, Srecommend, Scomm, ExtraPT, Spread, Stake, actual_stake, winlost, awinlost, mwinlost, swinlost, 
						MatchCode, EventDate, SportType, LeagueId, HomeId, AwayId, LiveIndicator, Is8RM, BetChoice, AdjOdds, OriOdds ,statuswinlost, oddstype, isDecOddsOnly)
			SELECT	[TransId]			= b.transid
				,	[CustId]			= b.custid
				,	[MatchId]			= b.matchId
				,	[WorkShift]			= m.WorkShift
				,	[SpecialType]		= m.SpecialType
				,	[Winlostdate]		= b.winlostdate
				,	[Bettype]			= CASE	WHEN b.bettype = 465
													THEN 458
												WHEN b.bettype = 466
													THEN 459
												WHEN b.bettype = 124
													THEN 5
												WHEN b.bettype = 125
													THEN 15
												ELSE b.bettype
											END
				,	[Modds]				= b.modds
				,	[Virtualrate]		= b.virtualrate
				,	[Actualrate]		= b.actualrate
				,	[Tpositiontaking]	= b.tpositiontaking
				,	[spositiontaking]	= b.spositiontaking
				,	[mpositiontaking]	= b.mpositiontaking
				,	[apositiontaking]	= b.apositiontaking
				,	[Srecommend]		= b.srecommend
				,	[Scomm]				= b.scomm
				,	[ExtraPT]			= ISNULL(b.epositiontaking, 0)
				,	[Spread]			= CASE WHEN mm.BetType IN (5, 15) THEN ISNULL(s.Spread, - (4 / mm.Spread - 4)) ELSE mm.Spread END
				,	[Stake]				= CASE WHEN b.modds = 0.25 OR b.modds = - 0.25 THEN ABS(b.stake) / 2 ELSE ABS(b.stake) END
				,	[actual_stake]		= b.actual_stake
				,	[winlost]			= b.winlost
				,	[awinlost]			= b.awinlost
				,	[mwinlost]			= b.mwinlost
				,	[swinlost]			= b.swinlost
				,	[MatchCode]			= m.MatchCode
				,	[EventDate]			= m.EventDate
				,	[SportType]			= m.SportType
				,	[LeagueId]			= m.LeagueId
				,	[HomeId]			= m.HomeId
				,	[AwayId]			= m.AwayId
				,	[LiveIndicator]		= b.liveindicator
				,	[Is8RM]				= CASE WHEN t8.CustId IS NULL THEN 0 ELSE 1 END
				,	[BetChoice]			= b.betteam
				,	[AdjOdds]			= CASE WHEN fdec.OddsType IS NOT NULL THEN b.odds - 1 ELSE b.odds END
				,	[OriOdds]			= CASE WHEN fdec.OddsType IS NOT NULL THEN bi.OriginalOdds - 1 ELSE bi.OriginalOdds END
				,	[statuswinlost]		= b.statuswinlost
				,	[oddstype]			= b.oddstype
				,	[isDecOddsOnly]		= CASE WHEN fdec.OddsType IS NOT NULL THEN 1 ELSE 0 END
		FROM		bodb02.dbo.bettrans AS b WITH (NOLOCK)
			INNER JOIN	#tmpRTScannedMatches AS m WITH (NOLOCK)	ON b.matchid = m.matchid
			LEFT JOIN	bodb02.dbo.MatchMaxbet AS mm WITH (NOLOCK) ON mm.MatchId = b.MatchId AND mm.BetType = b.bettype
			LEFT JOIN	#tmpRTSpread1x2 AS s ON	mm.Spread = s.Margin AND mm.BetType IN (5, 15)
			LEFT JOIN bodb02.dbo.BettransInfo bi WITH (NOLOCK) ON b.transid = bi.transid
			LEFT JOIN #tmp8RMMembers AS t8 WITH(NOLOCK) ON b.CustId = t8.CustId
			LEFT JOIN bodb02.dbo.f_Set_OddsTypeBettypes() fdec  ON b.bettype = fdec.BetType
		WHERE	b.winlostdate = @winlostdate
			AND	b.statusID IN (112, 113)
			AND	b.Currency NOT IN (20, 27, 28)
		OPTION (RECOMPILE);
		
		SELECT	@RowCount	= @@ROWCOUNT
			,	@Duration	= DATEDIFF(millisecond, @Begin, GETDATE())
			;

		IF	@Debug = 1
		BEGIN
			-- Force the output to appear immediately --
			RAISERROR('From Origin - Insert #tmpRTFilteredBettransByBatch - %d rows - %d ms', 0, 0, @RowCount, @Duration) WITH NOWAIT;
		END;
		
		-- "DISTINCT" Prevent Page Splits
		DELETE b WITH(ROWLOCK)
		FROM	(	
					SELECT ROW_NUMBER() OVER (PARTITION BY TransId ORDER BY TransId) AS rn
					FROM #tmpRTFilteredBettransByBatch
				) AS b
		WHERE b.rn > 1;

		-- Odds Spread Setting - ReCalculate Original Winlost
		UPDATE b WITH(ROWLOCK, UPDLOCK)
		SET   @UpdateById = CASE WHEN b.isDecOddsOnly = 1 OR b.OriOdds * b.AdjOdds > 0 THEN 1
							ELSE 2 END
			, @Odds = CASE WHEN
							(
								((b.isDecOddsOnly = 1 OR (b.OriOdds > 0 AND b.AdjOdds > 0)) AND b.statuswinlost IN (1, 2))
								OR (b.isDecOddsOnly <> 1 AND b.OriOdds < 0 AND b.AdjOdds < 0 AND b.statuswinlost IN (3, 4))
							) THEN CAST(b.OriOdds AS FLOAT) / b.AdjOdds
						ELSE 1 END
			, @winlost = CASE WHEN (b.OriOdds < 0 AND b.AdjOdds > 0) THEN
										CASE WHEN b.statuswinlost = 2 THEN (b.winlost / b.AdjOdds) -- won  
											 WHEN b.statuswinlost = 1 THEN (b.winlost / b.AdjOdds) -- half won  
											 WHEN b.statuswinlost = 4 THEN (-1) * (b.winlost * b.OriOdds) -- lose  
											 WHEN b.statuswinlost = 3 THEN (-1) * (b.winlost * b.OriOdds) -- half lose
										END  
										WHEN (b.OriOdds > 0 AND b.AdjOdds < 0) THEN  
										CASE WHEN b.statuswinlost = 2 THEN (-1) * (b.actual_stake * b.OriOdds / b.AdjOdds) -- won  
											 WHEN b.statuswinlost = 1 THEN (-1) * (b.actual_stake * b.OriOdds / b.AdjOdds) * 0.5 -- half won  
											 WHEN b.statuswinlost = 4 THEN (b.actual_stake / b.AdjOdds) -- lose  
											 WHEN b.statuswinlost = 3 THEN (b.actual_stake / b.AdjOdds) * 0.5 -- half lose
										END
									END
			, b.winlost  = CASE @UpdateById
								WHEN 1 THEN b.winlost * @Odds
								WHEN 2 THEN @winlost END
			, b.swinlost = CASE @UpdateById
								WHEN 1 THEN b.swinlost * @Odds
								WHEN 2 THEN b.spositiontaking * @winlost END
			, b.mwinlost = CASE @UpdateById
								WHEN 1 THEN b.mwinlost * @Odds
								WHEN 2 THEN b.mpositiontaking * @winlost END
			, b.awinlost = CASE @UpdateById
								WHEN 1 THEN b.awinlost * @Odds
								WHEN 2 THEN b.apositiontaking * @winlost END
		FROM #tmpRTFilteredBettransByBatch AS b
		WHERE b.winlostdate = @winlostdate
			AND b.OriOdds IS NOT NULL
			AND b.OriOdds <> 0
			AND b.AdjOdds <> 0;

		SELECT	@RowCount	= @@ROWCOUNT
			,	@Duration	= DATEDIFF(millisecond, @Begin, GETDATE())
			;

		IF	@Debug = 1
		BEGIN
			-- Force the output to appear immediately
			RAISERROR('From Origin - ReCalculate Original Winlost #tmpRTFilteredBettransByBatch - %d rows - %d ms', 0, 0, @RowCount, @Duration) WITH NOWAIT;
		END;
			
		INSERT INTO	#tmpRTStagingTraderPerformance (TraderId, CustId, WorkShift, MatchId, MatchCode, EventDate, SportType, LeagueId, HomeId, AwayId, 
			TeamId, Grade, BetType, Stake, WinLost, SMAWinLost, Comm, BetCount, Spread, ExtraPT, TPositionTaking, VirtualRate, ActualRate, LiveIndicator, Is8RM, BetChoice)
		SELECT		[TraderId]			= CASE WHEN b.LiveIndicator = 0 THEN @IdForNonLiveUnassignedTrader ELSE ISNULL(t.TraderId, @IdForLiveUnassignedTrader) END
				,	[CustId]			= b.custid
				,	[WorkShift]			= ISNULL(b.WorkShift, 1)
				,	[MatchId]			= b.MatchId
				,	[MatchCode]			= b.MatchCode
				,	[EventDate]			= b.EventDate
				,	[SportType]			= b.SportType
				,	[LeagueId]			= b.LeagueId
				,	[HomeId]			= b.HomeId
				,	[AwayId]			= b.AwayId
				,	[TeamId]			= t.TeamId
				,	[Grade]				= t.Grade
				,	[BetType]			= ca.BetType
				,	[Stake]				= b.Stake --Turnover
				,	[WinLost]			= b.winlost - b.actual_stake
				,	[SMAWinLost]		= b.awinlost + b.mwinlost + b.swinlost
				,	[Comm]				= b.scomm --Commission
				,	[BetCount]			= 1 --Live BetCount
				,	[Spread]			= b.Spread
				,	[ExtraPT]			= ISNULL(b.ExtraPT, 0)
				,	[TPositionTaking]	= b.tpositiontaking
				,	[VirtualRate]		= b.virtualrate
				,	[ActualRate]		= b.actualrate
				,	[LiveIndicator]		= b.LiveIndicator
				,	[Is8RM]				= b.Is8RM
				,	[BetChoice]			= b.BetChoice 
		FROM	#tmpRTFilteredBettransByBatch AS b WITH (NOLOCK)
			INNER JOIN #tmpRTSupportedBettypes AS bt WITH(NOLOCK) ON b.BetType = bt.BetType
			LEFT JOIN	#tmpRTTrader AS t WITH (NOLOCK)
					ON	b.winlostdate = t.EventDate
					AND	b.matchid = t.matchid
					AND	(b.BetType = t.BetType OR (b.bettype = 23 AND t.BetType = 1)
						)
			CROSS APPLY	(
				SELECT	[BetType]	= CASE	WHEN b.BetType = 1 AND b.SpecialType = 0
													THEN 1 --HDP
												WHEN b.BetType = 3 AND b.SpecialType = 0
													THEN 3 --O/U		
												WHEN b.BetType = 8 AND b.SpecialType = 0
													THEN 8 --1st O/U
												WHEN b.BetType IN (5, 124) AND b.SpecialType = 0
													THEN 5 --1x2		
												WHEN b.BetType IN (5, 124) AND b.SpecialType = 5
													THEN - 14 --10mins 1x2
												WHEN b.BetType IN (15, 125) AND b.SpecialType = 0
													THEN 15 --1st 1x2
												WHEN b.BetType = 1 AND b.SpecialType = 4
													THEN - 1 --15mins HDP
												WHEN (b.bettype = 23 AND t.BetType = 1) OR (b.BetType = 1 AND b.SpecialType = 8)
													THEN - 2 --Next Corner
												WHEN b.BetType = 1 AND b.SpecialType = 5
													THEN - 15 --10mins HDP
												WHEN b.BetType = 1 AND b.SpecialType = 9
													THEN - 3 --Next Booking
												WHEN b.BetType IN (5, 124) AND b.SpecialType = 4
													THEN - 4 --15mins 1X2
												WHEN b.BetType = 3 AND b.SpecialType = 4
													THEN - 5 --15mins O/U
												WHEN b.BetType = 3 AND b.SpecialType = 5
													THEN - 6 --10mins O/U
												WHEN b.BetType = 1 AND b.SpecialType = 2  
													THEN - 39 --No. of Corners 15mins HPD
												WHEN b.BetType = 3 AND b.SpecialType = 2  
													THEN - 7 --No. of Corner 15mins O/U
												WHEN b.BetType = 3 AND b.SpecialType = 7
													THEN - 8 --Total Bookings
												WHEN b.BetType = 1 AND b.SpecialType = 1
													THEN - 37 --Total Bookings 15mins HDP
												WHEN b.BetType = 3 AND b.SpecialType = 1
													THEN - 10 --Total Bookings 15mins O/U
												WHEN b.BetType = 1 AND b.SpecialType = 6  
													THEN - 41  --No. of Corners HPD
												WHEN b.BetType = 3 AND b.SpecialType = 6  
													THEN - 13 --No. of Corners O/U
												WHEN b.BetType = 7 AND b.SpecialType = 6  
													THEN - 40 --1st No. of Corners HDP
												WHEN b.BetType = 8 AND b.SpecialType = 6  
													THEN - 12 --1st No. of Corners O/U												
												WHEN b.BetType = 8 AND b.SpecialType = 7
													THEN - 9 --1st TotalBookings
												WHEN (b.BetType = 3 OR b.BetType = 8) AND b.SpecialType = 3
													THEN - 11 --Single Team O/U
												WHEN b.BetType IN (5, 124)
													THEN 5 --1x2	
												WHEN b.BetType IN (15, 125)
													THEN 15 --1st 1x2
												ELSE b.BetType
											END
				) AS ca
		WHERE	b.winlostdate = @winlostdate;

		SELECT	@RowCount	= @@ROWCOUNT
			,	@Duration	= DATEDIFF(millisecond, @Begin, GETDATE())
			;

		IF	@Debug = 1
		BEGIN
			-- Force the output to appear immediately --
			RAISERROR('From Origin - Insert #tmpRTStagingTraderPerformance - %d rows - %d ms', 0, 0, @RowCount, @Duration) WITH NOWAIT;
		END;

		UPDATE stp WITH(ROWLOCK, UPDLOCK)
		SET stp.TeamId = t.TeamId
			,	stp.Grade = t.Grade
		FROM #tmpRTStagingTraderPerformance AS stp
		INNER JOIN dbo.Trader t WITH (NOLOCK) ON t.CustId IN (@IdForLiveUnassignedTrader, @IdForNonLiveUnassignedTrader) AND stp.TraderId = t.CustId;

		INSERT INTO	dbo.TraderPerformance (CustId, WorkShift, MatchId, MatchCode, EventDate, SportType, LeagueId, HomeId, AwayId, TeamId, Grade, BetType, 
			IsLive, Stake, WinLost, Comm, Stake_AR, WinLost_AR, Comm_AR, Is8RM, Stake_Real, WinLost_Real, Stake_VAR, WinLost_VAR, BetCount, Spread)
		SELECT	[CustId]			= t.TraderId
			,	[WorkShift]			= t.WorkShift
			,	[MatchId]			= t.MatchId
			,	[MatchCode]			= t.MatchCode
			,	[EventDate]			= t.EventDate
			,	[SportType]			= t.SportType
			,	[LeagueId]			= t.LeagueId
			,	[HomeId]			= t.HomeId
			,	[AwayId]			= t.AwayId
			,	[TeamId]			= t.TeamId
			,	[Grade]				= t.Grade
			,	[BetType]			= t.BetType
			,	[IsLive]			= t.LiveIndicator
			,	[Stake]				= SUM(t.Stake * (1 - t.TPositionTaking - t.ExtraPT) * t.VirtualRate)
			,	[WinLost]			= SUM(((-(t.WinLost + t.SMAWinLost)) + t.WinLost * t.ExtraPT) * t.VirtualRate)
			,	[Comm]				= SUM((t.Comm - (CASE WHEN t.TPositionTaking = 1 THEN 0 ELSE (t.Comm * t.ExtraPT/(1 - t.TPositionTaking)) END)) * (CASE WHEN t.VirtualRate > t.ActualRate THEN t.ActualRate ELSE t.VirtualRate END))
			,	[Stake_AR]			= SUM(t.Stake * (1 - t.TPositionTaking - t.ExtraPT) * (CASE WHEN t.VirtualRate > t.ActualRate THEN t.VirtualRate ELSE t.ActualRate END))
			,	[WinLost_AR]		= SUM(((-(t.WinLost + t.SMAWinLost)) + t.WinLost * t.ExtraPT) * t.ActualRate)
			,	[Comm_AR]			= SUM((t.Comm - (CASE WHEN t.TPositionTaking = 1 THEN 0 ELSE (t.Comm * t.ExtraPT/(1 - t.TPositionTaking)) END)) * t.ActualRate)
			,	[Is8RM]				= t.Is8RM
			,	[Stake_Real]		= SUM((CASE WHEN t.TPositionTaking = 1 THEN 0 ELSE (1 - t.TPositionTaking - t.ExtraPT) END * ABS(t.Stake) * t.ActualRate) * (CASE WHEN t.VirtualRate > t.ActualRate THEN t.VirtualRate/t.ActualRate ELSE 1 END))
			,	[WinLost_Real]		= SUM(-((t.WinLost + t.SMAWinLost) + t.Comm) * t.ActualRate + (CASE WHEN t.TPositionTaking = 1 THEN 0 ELSE t.WinLost + t.Comm/(1 - t.TPositionTaking) END ) * t.ExtraPT * t.ActualRate)
			,	[Stake_VAR]			= SUM(CASE WHEN t.TPositionTaking = 1 THEN 0 ELSE (1 - t.TPositionTaking - t.ExtraPT) END  * ABS(t.Stake) * t.ActualRate * (CASE WHEN t.VirtualRate > t.ActualRate THEN (t.VirtualRate/t.ActualRate -1) ELSE -(t.VirtualRate/t.ActualRate - 1) END))
			,	[WinLost_VAR]		= SUM((t.WinLost + t.SMAWinLost - (CASE WHEN t.TPositionTaking = 1 THEN 0 ELSE t.WinLost * t.ExtraPT END) + (CASE WHEN t.VirtualRate < t.ActualRate THEN (t.Comm - CASE WHEN t.TPositionTaking=1 THEN 0 ELSE t.Comm * t.ExtraPT/(1-t.TPositionTaking) END) ELSE 0 END)) * (t.VirtualRate/t.ActualRate - 1)*t.ActualRate)
			,	[BetCount]			= SUM(CASE WHEN tc.custid IS NULL THEN t.BetCount ELSE 0 END)
			,	[Spread]			= MAX(t.Spread)
		FROM	#tmpRTStagingTraderPerformance AS t 
				LEFT JOIN bodb02.dbo.TradeCust tc WITH (NOLOCK) ON t.CustId = tc.custid AND tc.VendorID = 14
		WHERE	t.EventDate = @winlostdate
		GROUP BY t.TraderId, t.WorkShift, t.MatchId, t.MatchCode, t.EventDate, t.SportType, t.LeagueId, t.HomeId, t.AwayId, t.TeamId, t.Grade, t.BetType, t.LiveIndicator, t.Is8RM;
				
		SELECT	@RowCount	= @@ROWCOUNT
			,	@Duration	= DATEDIFF(millisecond, @Begin, GETDATE());

		IF	@Debug = 1
		BEGIN
			-- Force the output to appear immediately --
			RAISERROR('	Insert TraderPerformance - %d rows - %d ms', 0, 0, @RowCount, @Duration) WITH NOWAIT;
		END;

		INSERT INTO	[dbo].[TraderPerformance_BetChoice](CustId, MatchId, EventDate, SportType, LeagueId, BetType, BetChoice, IsLive, Stake, WinLost, Comm, Stake_AR, WinLost_AR, Comm_AR, Is8RM, Stake_Real, WinLost_Real, Stake_VAR, WinLost_VAR, BetCount)
		SELECT		[CustId]			= t.TraderId
				,	[MatchId]			= t.MatchId
				,	[EventDate]			= t.EventDate
				,	[SportType]			= t.SportType
				,	[LeagueId]			= t.LeagueId
				,	[BetType]			= t.BetType
				,	[BetChoice]			= t.BetChoice
				,	[IsLive]			= t.LiveIndicator
				,	[Stake]				= SUM(t.Stake * (1 - t.TPositionTaking - t.ExtraPT) * t.VirtualRate)
				,	[WinLost]			= SUM(((-(t.WinLost + t.SMAWinLost)) + t.WinLost * t.ExtraPT) * t.VirtualRate)
				,	[Comm]				= SUM((t.Comm - (CASE WHEN t.TPositionTaking = 1 THEN 0 ELSE (t.Comm * t.ExtraPT/(1 - t.TPositionTaking)) END)) * (CASE WHEN t.VirtualRate > t.ActualRate THEN t.ActualRate ELSE t.VirtualRate END))
				,	[Stake_AR]			= SUM(t.Stake * (1 - t.TPositionTaking - t.ExtraPT) * (CASE WHEN t.VirtualRate > t.ActualRate THEN t.VirtualRate ELSE t.ActualRate END))
				,	[WinLost_AR]		= SUM(((-(t.WinLost + t.SMAWinLost)) + t.WinLost * t.ExtraPT) * t.ActualRate)
				,	[Comm_AR]			= SUM((t.Comm - (CASE WHEN t.TPositionTaking = 1 THEN 0 ELSE (t.Comm * t.ExtraPT/(1 - t.TPositionTaking)) END)) * t.ActualRate)
				,	[Is8RM]				= t.Is8RM
				,	[Stake_Real]		= SUM((CASE WHEN t.TPositionTaking = 1 THEN 0 ELSE (1 - t.TPositionTaking - t.ExtraPT) END * ABS(t.Stake) * t.ActualRate) * (CASE WHEN t.VirtualRate > t.ActualRate THEN t.VirtualRate/t.ActualRate ELSE 1 END))
				,	[WinLost_Real]		= SUM(-((t.WinLost + t.SMAWinLost) + t.Comm) * t.ActualRate + (CASE WHEN t.TPositionTaking = 1 THEN 0 ELSE t.WinLost + t.Comm/(1 - t.TPositionTaking) END ) * t.ExtraPT * t.ActualRate)
				,	[Stake_VAR]			= SUM(CASE WHEN t.TPositionTaking = 1 THEN 0 ELSE (1 - t.TPositionTaking - t.ExtraPT) END  * ABS(t.Stake) * t.ActualRate * (CASE WHEN t.VirtualRate > t.ActualRate THEN (t.VirtualRate/t.ActualRate -1) ELSE -(t.VirtualRate/t.ActualRate - 1) END))
				,	[WinLost_VAR]		= SUM((t.WinLost + t.SMAWinLost - (CASE WHEN t.TPositionTaking = 1 THEN 0 ELSE t.WinLost * t.ExtraPT END) + (CASE WHEN t.VirtualRate < t.ActualRate THEN (t.Comm - CASE WHEN t.TPositionTaking=1 THEN 0 ELSE t.Comm * t.ExtraPT/(1-t.TPositionTaking) END) ELSE 0 END)) * (t.VirtualRate/t.ActualRate - 1)*t.ActualRate)
				,	[BetCount]			= SUM(CASE WHEN tc.custid IS NULL THEN t.BetCount ELSE 0 END)
		FROM #tmpRTStagingTraderPerformance AS t
				LEFT JOIN bodb02.dbo.TradeCust tc WITH (NOLOCK) ON t.CustId = tc.custid AND tc.VendorID = 14
		WHERE t.EventDate = @winlostdate AND t.BetChoice IS NOT NULL
		GROUP BY t.TraderId, t.MatchId, t.EventDate, t.SportType, t.LeagueId, t.BetType, t.BetChoice, t.LiveIndicator, t.Is8RM;
				
		SELECT	@RowCount	= @@ROWCOUNT
			,	@Duration	= DATEDIFF(millisecond, @Begin, GETDATE())
			;

		IF	@Debug = 1
		BEGIN
			-- Force the output to appear immediately --
			RAISERROR('From - Insert [TraderPerformance_BetChoice] - %d rows - %d ms', 0, 0, @RowCount, @Duration) WITH NOWAIT;
		END;
		
		TRUNCATE TABLE #tmpRTStagingTraderPerformance;
		TRUNCATE TABLE #tmpRTFilteredBettransByBatch;
	
		-- STEP #2: SUM DAILY
		DELETE FROM [dbo].[SummaryByBetType_Daily] WHERE EventDate = @WinlostDate;

		INSERT INTO [dbo].[SummaryByBetType_Daily]
		(
				[EventDate]
			,	[LeagueId]
			,	[BetType]
			,	[WorkShift]
			,	[IsLive]
			,	[Stake]
			,	[WinLost]
			,	[Comm]
			,	[Stake_AR]
			,	[WinLost_AR]
			,	[Comm_AR]
			,	[Is8RM]
			,	[Stake_Real]
			,	[WinLost_Real]
			,	[Stake_VAR]
			,	[WinLost_VAR]			
			,	[BetCount]
			,	[MatchCount]
		)
		SELECT	[EventDate]		= @WinlostDate 
			,	[LeagueId]		= t.[LeagueId]
			,	[BetType]		= t.[BetType]
			,	[WorkShift]		= t.[WorkShift]
			,	[IsLive]		= t.[IsLive]
			,	[Stake]			= SUM(t.[Stake]) 
			,	[WinLost]		= SUM(t.[WinLost]) 
			,	[Comm]			= SUM(t.[Comm]) 
			,	[Stake_AR]		= SUM(t.[Stake_AR]) 
			,	[WinLost_AR]	= SUM(t.[WinLost_AR]) 
			,	[Comm_AR]		= SUM(t.[Comm_AR]) 
			,	[Is8RM]			= t.[Is8RM]
			,	[Stake_Real]	= SUM(t.[Stake_Real])
			,	[WinLost_Real]	= SUM(t.[WinLost_Real])
			,	[Stake_VAR]		= SUM(t.[Stake_VAR])
			,	[WinLost_VAR]	= SUM(t.[WinLost_VAR])			
			,	[BetCount]		= SUM(t.[BetCount]) 
			,	[MatchCount]	= COUNT(DISTINCT [MatchId])
		FROM dbo.TraderPerformance AS t WITH(NOLOCK)
		WHERE t.EventDate = @WinlostDate
		GROUP BY t.[LeagueId]
			,	t.[BetType]
			,	t.[WorkShift]
			,	t.[IsLive]
			,	t.[Is8RM];

		IF	OBJECT_ID('tempdb..#tmpRTBettypeGroup') IS NOT NULL
		BEGIN
			DROP TABLE #tmpRTBettypeGroup;
		END;

		CREATE TABLE	#tmpRTBettypeGroup (
				BetType			SMALLINT PRIMARY KEY
			,	BettypeGroup	TINYINT
		);

		INSERT INTO #tmpRTBettypeGroup(BetType,	BettypeGroup)
		SELECT DISTINCT b.BetType
			,	b.BettypeGroup
		FROM dbo.BetType b WITH(NOLOCK);
	
		DELETE FROM [dbo].[SummaryByLeague_Daily] WHERE EventDate = @WinlostDate;

		INSERT INTO [dbo].[SummaryByLeague_Daily]
		(
				[EventDate]
			,	[LeagueId]
			,	[WorkShift]
			,	[BettypeGroup]
			,	[IsLive]
			,	[Stake]
			,	[WinLost]
			,	[Comm]
			,	[Stake_AR]
			,	[WinLost_AR]
			,	[Comm_AR]
			,	[Is8RM]
			,	[Stake_Real]
			,	[WinLost_Real]
			,	[Stake_VAR]
			,	[WinLost_VAR]			
			,	[BetCount]
			,	[MatchCount]
		)
		SELECT	[EventDate]		= @WinlostDate 
			,	[LeagueId]		= s.[LeagueId]
			,	[WorkShift]		= s.[WorkShift]
			,	[BettypeGroup]	= g.[BettypeGroup]
			,	[IsLive]		= s.[IsLive]
			,	[Stake]			= SUM(s.[Stake])
			,	[WinLost]		= SUM(s.[WinLost]) 
			,	[Comm]			= SUM(s.[Comm]) 
			,	[Stake_AR]		= SUM(s.[Stake_AR]) 
			,	[WinLost_AR]	= SUM(s.[WinLost_AR]) 
			,	[Comm_AR]		= SUM(s.[Comm_AR]) 
			,	[Is8RM]			= s.[Is8RM]
			,	[Stake_Real]	= SUM(s.[Stake_Real])
			,	[WinLost_Real]	= SUM(s.[WinLost_Real])
			,	[Stake_VAR]		= SUM(s.[Stake_VAR])
			,	[WinLost_VAR]	= SUM(s.[WinLost_VAR])			
			,	[BetCount]		= SUM(s.[BetCount]) 
			,	[MatchCount]	= COUNT(DISTINCT s.[MatchId])
		FROM dbo.TraderPerformance s WITH(NOLOCK)
			INNER JOIN #tmpRTBettypeGroup g WITH(NOLOCK) ON s.BetType = g.BetType
		WHERE s.EventDate = @WinlostDate
		GROUP BY s.[LeagueId]
			,	s.[WorkShift]
			,	g.[BettypeGroup]
			,	s.[IsLive]
			,	s.[Is8RM];		   
		   
		DELETE FROM [dbo].[SummaryByTeam_Daily] WHERE EventDate = @WinlostDate;

		INSERT INTO [dbo].[SummaryByTeam_Daily]
		(
				[EventDate]
			,	[TeamId]
			,	[LeagueId]
			,	[WorkShift]
			,	[BettypeGroup]
			,	[IsLive]
			,	[Stake]
			,	[WinLost]
			,	[Comm]
			,	[Stake_AR]
			,	[WinLost_AR]
			,	[Comm_AR]
			,	[Is8RM]
			,	[Stake_Real]
			,	[WinLost_Real]
			,	[Stake_VAR]
			,	[WinLost_VAR]			
			,	[BetCount]
			,	[MatchCount]
		)
		SELECT	[EventDate]		= @WinlostDate 
			,	[TeamId]		= s.[TeamId]
			,	[LeagueId]		= s.[LeagueId]
			,	[WorkShift]		= s.[WorkShift]
			,	[BettypeGroup]	= g.[BettypeGroup]
			,	[IsLive]		= s.[IsLive]
			,	[Stake]			= SUM(s.[Stake]) 
			,	[WinLost]		= SUM(s.[WinLost])
			,	[Comm]			= SUM(s.[Comm]) 
			,	[Stake_AR]		= SUM(s.[Stake_AR]) 
			,	[WinLost_AR]	= SUM(s.[WinLost_AR]) 
			,	[Comm_AR]		= SUM(s.[Comm_AR]) 
			,	[Is8RM]			= s.[Is8RM]
			,	[Stake_Real]	= SUM(s.[Stake_Real])
			,	[WinLost_Real]	= SUM(s.[WinLost_Real])
			,	[Stake_VAR]		= SUM(s.[Stake_VAR])
			,	[WinLost_VAR]	= SUM(s.[WinLost_VAR])			
			,	[BetCount]		= SUM(s.[BetCount]) 
			,	[MatchCount]	= COUNT(DISTINCT s.[MatchId])
		FROM dbo.TraderPerformance s WITH(NOLOCK)
			INNER JOIN #tmpRTBettypeGroup g WITH(NOLOCK) ON s.BetType = g.BetType
		WHERE	s.EventDate = @WinlostDate
		GROUP BY s.[TeamId]
			,	s.[LeagueId]				
			,	s.[WorkShift]
			,	g.[BettypeGroup]
			,	s.[IsLive]
			,	s.[Is8RM];

		-- STEP 3: SUM MONTHLY
		DECLARE @StartDate DATE;
		SELECT @StartDate = DATEADD(MONTH, DATEDIFF(MONTH, 0, @WinlostDate), 0);

		DELETE [dbo].[SummaryByTrader_Monthly] WHERE EventDate = @StartDate;

		INSERT INTO [dbo].[SummaryByTrader_Monthly]
		(
				[Eventdate]
			,	[CustId]
			,	[LeagueId]
			,	[WorkShift]
			,	[BettypeGroup]
			,	[IsLive]
			,	[Stake]
			,	[WinLost]
			,	[Comm]
			,	[Stake_AR]
			,	[WinLost_AR]
			,	[Comm_AR]
			,	[Is8RM]
			,	[Stake_Real]
			,	[WinLost_Real]
			,	[Stake_VAR]
			,	[WinLost_VAR]			
			,	[BetCount]
			,	[MatchCount]
		)
		SELECT	[Eventdate]		= @StartDate 
			,	[CustId]		= s.[CustId]
			,	[LeagueId]		= s.[LeagueId]
			,	[WorkShift]		= s.[WorkShift]
			,	[BettypeGroup]	= g.[BettypeGroup]
			,	[IsLive]		= s.[IsLive]
			,	[Stake]			= SUM(s.[Stake])
			,	[WinLost]		= SUM(s.[WinLost]) 
			,	[Comm]			= SUM(s.[Comm])
			,	[Stake_AR]		= SUM(s.[Stake_AR]) 
			,	[WinLost_AR]	= SUM(s.[WinLost_AR]) 
			,	[Comm_AR]		= SUM(s.[Comm_AR]) 
			,	[Is8RM]			= s.[Is8RM]
			,	[Stake_Real]	= SUM(s.[Stake_Real])
			,	[WinLost_Real]	= SUM(s.[WinLost_Real])
			,	[Stake_VAR]		= SUM(s.[Stake_VAR])
			,	[WinLost_VAR]	= SUM(s.[WinLost_VAR])			
			,	[BetCount]		= SUM(s.[BetCount]) 
			,	[MatchCount]	= COUNT(DISTINCT s.[MatchId])
		FROM [dbo].[TraderPerformance] s WITH(NOLOCK)
			INNER JOIN #tmpRTBettypeGroup g WITH(NOLOCK) ON s.BetType = g.BetType
		WHERE s.EventDate BETWEEN @StartDate AND @WinlostDate
		GROUP BY s.[CustId]
			,	s.[LeagueId]
			,	s.[WorkShift]
			,	g.[BettypeGroup]
			,	s.[IsLive]
			,	s.[Is8RM];

		DELETE [dbo].[SummaryByBetType_Monthly]	WHERE EventDate = @StartDate;

		INSERT INTO [dbo].[SummaryByBetType_Monthly]
		(
				[EventDate]
			,	[LeagueId]
			,	[BetType]
			,	[WorkShift]
			,	[IsLive]
			,	[Stake]
			,	[WinLost]
			,	[Comm]
			,	[Stake_AR]
			,	[WinLost_AR]
			,	[Comm_AR]
			,	[Is8RM]
			,	[Stake_Real]
			,	[WinLost_Real]
			,	[Stake_VAR]
			,	[WinLost_VAR]		
			,	[BetCount]
			,	[MatchCount]
		)
		SELECT	[EventDate]		= @StartDate 
			,	[LeagueId]		= s.[LeagueId]
			,	[BetType]		= s.[BetType]
			,	[WorkShift]		= s.[WorkShift]
			,	[IsLive]		= s.[IsLive]
			,	[Stake]			= SUM(s.[Stake])
			,	[WinLost]		= SUM(s.[WinLost]) 
			,	[Comm]			= SUM(s.[Comm])
			,	[Stake_AR]		= SUM(s.[Stake_AR]) 
			,	[WinLost_AR]	= SUM(s.[WinLost_AR]) 
			,	[Comm_AR]		= SUM(s.[Comm_AR]) 
			,	[Is8RM]			= s.[Is8RM]
			,	[Stake_Real]	= SUM(s.[Stake_Real])
			,	[WinLost_Real]	= SUM(s.[WinLost_Real])
			,	[Stake_VAR]		= SUM(s.[Stake_VAR])
			,	[WinLost_VAR]	= SUM(s.[WinLost_VAR])			
			,	[BetCount]		= SUM(s.[BetCount]) 
			,	[MatchCount]	= COUNT(DISTINCT s.[MatchId])
		FROM [dbo].[TraderPerformance] AS s WITH(NOLOCK)
		WHERE s.EventDate BETWEEN @StartDate AND @WinlostDate
		GROUP BY s.[LeagueId]
			,	s.[BetType]
			,	s.[WorkShift]
			,	s.[IsLive]
			,	s.[Is8RM];

		DELETE [dbo].SummaryByLeague_Monthly WHERE EventDate = @StartDate;

		INSERT INTO [dbo].SummaryByLeague_Monthly
		(
				[EventDate]
			,	[LeagueId]
			,	[WorkShift]
			,	[BettypeGroup]
			,	[IsLive]
			,	[Stake]
			,	[WinLost]
			,	[Comm]
			,	[Stake_AR]
			,	[WinLost_AR]
			,	[Comm_AR]
			,	[Is8RM]
			,	[Stake_Real]
			,	[WinLost_Real]
			,	[Stake_VAR]
			,	[WinLost_VAR]			
			,	[BetCount]
			,	[MatchCount]
		)
		SELECT	[EventDate]		= @StartDate 
			,	[LeagueId]		= s.[LeagueId]
			,	[WorkShift]		= s.[WorkShift]
			,	[BettypeGroup]	= g.[BettypeGroup]
			,	[IsLive]		= s.[IsLive]
			,	[Stake]			= SUM(s.[Stake])
			,	[WinLost]		= SUM(s.[WinLost]) 
			,	[Comm]			= SUM(s.[Comm])
			,	[Stake_AR]		= SUM(s.[Stake_AR]) 
			,	[WinLost_AR]	= SUM(s.[WinLost_AR]) 
			,	[Comm_AR]		= SUM(s.[Comm_AR]) 
			,	[Is8RM]			= s.[Is8RM]
			,	[Stake_Real]	= SUM(s.[Stake_Real])
			,	[WinLost_Real]	= SUM(s.[WinLost_Real])
			,	[Stake_VAR]		= SUM(s.[Stake_VAR])
			,	[WinLost_VAR]	= SUM(s.[WinLost_VAR])			
			,	[BetCount]		= SUM(s.[BetCount]) 
			,	[MatchCount]	= COUNT(DISTINCT s.[MatchId])
		FROM [dbo].[TraderPerformance] s WITH(NOLOCK)
			INNER JOIN #tmpRTBettypeGroup g WITH(NOLOCK) ON s.BetType = g.BetType
		WHERE s.EventDate BETWEEN @StartDate AND @WinlostDate
		GROUP BY s.[LeagueId]
			,	s.[WorkShift]
			,	g.[BettypeGroup]
			,	s.[IsLive]
			,	s.[Is8RM];

		DELETE [dbo].SummaryByTeam_Monthly	WHERE EventDate = @StartDate;

		INSERT INTO [dbo].SummaryByTeam_Monthly
		(
				[EventDate]
			,	[TeamId]
			,	[LeagueId]
			,	[WorkShift]
			,	[BettypeGroup]
			,	[IsLive]
			,	[Stake]
			,	[WinLost]
			,	[Comm]
			,	[Stake_AR]
			,	[WinLost_AR]
			,	[Comm_AR]
			,	[Is8RM]
			,	[Stake_Real]
			,	[WinLost_Real]
			,	[Stake_VAR]
			,	[WinLost_VAR]			
			,	[BetCount]
			,	[MatchCount]
		)
		SELECT	[EventDate]		= @StartDate 
			,	[TeamId]		= s.[TeamId]
			,	[LeagueId]		= s.[LeagueId]
			,	[WorkShift]		= s.[WorkShift]
			,	[BettypeGroup]	= g.[BettypeGroup]
			,	[IsLive]		= s.[IsLive]
			,	[Stake]			= SUM(s.[Stake])
			,	[WinLost]		= SUM(s.[WinLost]) 
			,	[Comm]			= SUM(s.[Comm])
			,	[Stake_AR]		= SUM(s.[Stake_AR]) 
			,	[WinLost_AR]	= SUM(s.[WinLost_AR]) 
			,	[Comm_AR]		= SUM(s.[Comm_AR]) 
			,	[Is8RM]			= s.[Is8RM]
			,	[Stake_Real]	= SUM(s.[Stake_Real])
			,	[WinLost_Real]	= SUM(s.[WinLost_Real])
			,	[Stake_VAR]		= SUM(s.[Stake_VAR])
			,	[WinLost_VAR]	= SUM(s.[WinLost_VAR])			
			,	[BetCount]		= SUM(s.[BetCount]) 
			,	[MatchCount]	= COUNT(DISTINCT s.[MatchId])
		FROM [dbo].[TraderPerformance] s WITH(NOLOCK)
			INNER JOIN #tmpRTBettypeGroup g WITH(NOLOCK) ON s.BetType = g.BetType
		WHERE s.EventDate BETWEEN @StartDate AND @WinlostDate
		GROUP BY s.[TeamId]
			,	s.[LeagueId]
			,	s.[WorkShift]
			,	g.[BettypeGroup]
			,	s.[IsLive]
			,	s.[Is8RM];

		-- STEP 4: STAGING JUICE
		IF	OBJECT_ID('tempdb..#tmpRTDataGroup') IS NOT NULL
		BEGIN
			DROP TABLE	#tmpRTDataGroup;
		END;

		CREATE TABLE	#tmpRTDataGroup (
				TraderId			INT
			,	EventDate			DATE
			,	MatchId				INT
			,	BetType				SMALLINT
			,	BetTeam				VARCHAR(10)
			,	ScoreHDP			SMALLMONEY
			,	AVGOdds				FLOAT
			,	StakeMYBeforeComm	MONEY
			,	StakeMY				MONEY
			,	Stake				MONEY
			,	MOdds				SMALLMONEY
			,	StatusID			TINYINT
			,	AVGOdds_AR			FLOAT
			,	StakeMYBeforeComm_AR MONEY
			,	StakeMY_AR			MONEY
			,	Stake_AR			MONEY
		);
			
		IF	OBJECT_ID('tempdb..#tmpRTFilteredBettransForJuice') IS NOT NULL
		BEGIN
			DROP TABLE	#tmpRTFilteredBettransForJuice;
		END;

		CREATE TABLE	#tmpRTFilteredBettransForJuice (
				TransId				BIGINT
			,	MatchId				INT
			,	Winlostdate			SMALLDATETIME
			,	Bettype				SMALLINT
			,	Modds				SMALLMONEY
			,	Virtualrate			FLOAT
			,	Actualrate			FLOAT
			,	Tpositiontaking		SMALLMONEY
			,	Scomm				MONEY
			,	Betteam				VARCHAR(10)
			,	Odds				SMALLMONEY
			,	StatusID			TINYINT
			,	ExtraPT				DECIMAL(12, 8)
			,	ScoreHDP			SMALLMONEY
			,	StakeMY				MONEY
			,	Stake				MONEY
		);

		CREATE CLUSTERED INDEX	#CIX_tmpRTFilteredBettransForJuiceIdx2 ON #tmpRTFilteredBettransForJuice (
				Winlostdate			ASC
			,	MatchId				ASC
			,	BetType				ASC
		);
							
		IF	OBJECT_ID('tempdb..#tmpRTStagingTraderPerformance2') IS NOT NULL
		BEGIN
			DROP TABLE	#tmpRTStagingTraderPerformance2;
		END;

		CREATE TABLE	#tmpRTStagingTraderPerformance2 (
				TraderId			INT
			,	EventDate			DATE
			,	MatchId				INT
			,	BetType				SMALLINT
			,	BetTeam				VARCHAR(10)
			,	ScoreHDP			SMALLMONEY
			,	Odds				FLOAT
			,	StakeMY				MONEY
			,	Stake				MONEY
			,	ExtraPT				DECIMAL(12, 8)
			,	TPositionTaking		SMALLMONEY
			,	VirtualRate			FLOAT
			,	ActualRate			FLOAT
			,	Scomm				MONEY
			,	MOdds				SMALLMONEY
			,	StatusID			TINYINT
		);
		
		CREATE CLUSTERED INDEX #CIX_#tmpRTStagingTraderPerformance2Idx ON #tmpRTStagingTraderPerformance2 (
				TraderId			ASC
			,	EventDate			ASC
		);
							
		IF	OBJECT_ID('tempdb..#tmpRTTrader2') IS NOT NULL
		BEGIN
			DROP TABLE	#tmpRTTrader2;
		END;

		CREATE TABLE	#tmpRTTrader2 (
				TraderId			INT
			,	MatchId				INT
			,	EventDate			DATETIME
			,	BetType				SMALLINT
			,	SpecialType			TINYINT
		);

		CREATE INDEX	#IDX_tmpRTTrader2 ON #tmpRTTrader2 (
				EventDate			ASC
			,	MatchId				ASC
			,	BetType				ASC
		);
	
		INSERT INTO	#tmpRTTrader2 (TraderId, MatchId, EventDate, BetType, SpecialType)
		SELECT	DISTINCT
				[TraderId]		= a.TraderId
			,	[MatchId]		= m.MatchId
			,	[EventDate]		= m.EventDate
			,	[BetType]		= a.BetType
			,	[SpecialType]	= CASE	WHEN LeagueName LIKE '%SPECIFIC 15 MINS TOTAL BOOKINGS%'
											THEN 1
										WHEN LeagueName LIKE '%SPECIFIC 15 MINS%' AND t.TeamName LIKE '%No.of Corners%'
											THEN 2
										WHEN LeagueName LIKE '%SPECIALS' AND (t.TeamName LIKE '%Over' OR t.TeamName LIKE '%Under')
											THEN 3
										WHEN LeagueName LIKE '%SPECIFIC 15 MINS%'
											THEN 4
										WHEN LeagueName LIKE '%SPECIFIC 10 MINS%'
											THEN 5
										WHEN t.TeamName LIKE '%No.of Corners%'
											THEN 6
										WHEN t.TeamName LIKE '%Total Bookings'
											THEN 7
										WHEN t.TeamName LIKE '%Corner%'
											THEN 8
										WHEN t.TeamName LIKE '%Booking'
											THEN 9
										ELSE 0
									END
		FROM		bodb02.dbo.Dot_Admin_Assignment_Trader AS a WITH (NOLOCK)
			INNER JOIN	bodb02.dbo.Match AS m WITH (NOLOCK) ON a.matchid = m.matchid
			LEFT JOIN	bodb02.dbo.Team AS t WITH (NOLOCK) ON m.homeid = t.teamid
			LEFT JOIN	bodb02.dbo.League AS l WITH (NOLOCK) ON	m.leagueid = l.LeagueId
			CROSS APPLY (
						SELECT dt.TraderID, dt.MatchId, dt.Bettype,
							ROW_NUMBER() OVER(PARTITION BY dt.MatchId, dt.Bettype ORDER BY dt.UpdatedTime DESC, dt.ID DESC) AS Row_Num
						FROM bodb02.dbo.Dot_Admin_Assignment_Trader AS dt WITH (NOLOCK)
						WHERE   a.matchid = dt.matchid
							AND a.bettype = dt.bettype		
							AND a.TraderId <> 0
						) dat
		WHERE		m.EventDate = @WinlostDate
				AND	m.EventStatus = 'completed'
				AND	m.SportType = 1
				AND	m.MatchCode NOT LIKE '%hedge%'	
				AND a.TraderId <> 0
				AND a.TraderID = dat.TraderID
				AND a.MatchId = dat.MatchId
				AND a.Bettype = dat.Bettype
				AND dat.Row_Num = 1;

		SELECT	@RowCount	= @@ROWCOUNT
			,	@Duration	= DATEDIFF(millisecond, @Begin, GETDATE());

		IF	@Debug = 1
		BEGIN
			-- Force the output to appear immediately --
			RAISERROR('Insert #tmpRTTrader2 - %d rows - %d ms', 0, 0, @RowCount, @Duration) WITH NOWAIT;
		END;

		INSERT INTO #tmpRTFilteredBettransForJuice (TransId, MatchId, Winlostdate, Bettype, Modds, Virtualrate, Actualrate, 
			Tpositiontaking, Scomm, Betteam, Odds, StatusID, ExtraPT, ScoreHDP, StakeMY, Stake)
		SELECT	[TransId]			= b.transid
			,	[MatchId]			= b.matchid
			,	[Winlostdate]		= b.winlostdate
			,	[Bettype]			= b.bettype
			,	[Modds]				= b.modds
			,	[Virtualrate]		= b.virtualrate
			,	[Actualrate]		= b.actualrate
			,	[Tpositiontaking]	= b.tpositiontaking
			,	[Scomm]				= b.scomm
			,	[Betteam]			= b.betteam
			,	[Odds]				= b.odds
			,	[StatusID]			= b.statusID
			,	[ExtraPT]			= ISNULL(b.epositiontaking, 0)
			,	[ScoreHDP]			= CASE	WHEN b.bettype IN (1, 7) THEN (b.hdp1 + b.livehomescore) - (b.hdp2 + b.liveawayscore)
											ELSE b.hdp1
										END
			,	[StakeMY]			= CASE WHEN ABS(b.odds) <= 1 THEN 1 ELSE ABS(b.odds) END
									* CASE WHEN ABS(b.modds) = 0.25 THEN 0.5 ELSE 1 END
									* ABS(b.stake)
			,	[Stake]				= CASE WHEN ABS(b.modds) = 0.25 THEN 0.5 ELSE 1 END
									* ABS(b.stake)
		FROM		bodb02.dbo.bettrans AS b WITH (NOLOCK)
			INNER JOIN	bodb02.dbo.Match AS m WITH (NOLOCK)	ON	b.matchid = m.matchid
		WHERE	b.winlostdate = @winlostdate
			AND	b.bettype IN (1, 3, 7, 8)
			AND	b.statusID IN (112, 113)
			AND	b.Currency NOT IN (20, 27, 28)
			AND	b.LiveIndicator = 1
			AND	m.SportType = 1
			AND	m.MatchCode NOT LIKE '%hedge%';
			
		SELECT	@RowCount	= @@ROWCOUNT
			,	@Duration	= DATEDIFF(millisecond, @Begin, GETDATE());

		IF	@Debug = 1
		BEGIN
			-- Force the output to appear immediately --
			RAISERROR('	Insert #tmpRTFilteredBettransForJuice - %d rows - %d ms', 0, 0, @RowCount, @Duration) WITH NOWAIT;
		END;

		-- Staging Performance 
		INSERT INTO #tmpRTStagingTraderPerformance2 (TraderId, EventDate, MatchId, BetType, BetTeam, ScoreHDP, Odds, StakeMY, Stake, ExtraPT, 
			TPositionTaking, VirtualRate, ActualRate, Scomm, MOdds, StatusID)
		SELECT	[TraderId]			= ISNULL(t.TraderId, @IdForLiveUnassignedTrader)
			,	[EventDate]			= b.winlostdate
			,	[MatchId]			= b.matchid
			,	[BetType]			= ca.BetType
			,	[BetTeam]			= b.betteam
			,	[ScoreHDP]			= b.ScoreHDP
			,	[Odds]				= b.odds
			,	[StakeMY]			= b.StakeMY
			,	[Stake]				= b.Stake
			,	[ExtraPT]			= ISNULL(b.ExtraPT, 0)
			,	[TPositionTaking]	= b.tpositiontaking
			,	[VirtualRate]		= b.virtualrate
			,	[ActualRate]		= b.actualrate
			,	[Scomm]				= b.scomm
			,	[MOdds]				= b.modds
			,	[StatusID]			= b.statusID
		FROM		#tmpRTFilteredBettransForJuice AS b
		LEFT JOIN	#tmpRTTrader2 AS t WITH (NOLOCK)
				ON	b.winlostdate = t.EventDate
				AND	b.matchid = t.matchid
				AND	b.BetType = t.BetType
		CROSS APPLY	(
			SELECT	[BetType]		= CASE	WHEN b.BetType = 1 AND SpecialType = 0
												THEN 1 --HDP
											WHEN b.BetType = 3 AND SpecialType = 0
												THEN 3 --O/U		
											WHEN b.BetType = 8 AND SpecialType = 0
												THEN 8 --1st O/U
											WHEN b.BetType = 1 AND SpecialType = 4
												THEN -1 --15mins HDP
											WHEN b.BetType = 1 AND SpecialType = 8
												THEN -2 --Next Corner
											WHEN b.BetType = 1 AND SpecialType = 5
												THEN -15 --10mins HDP
											WHEN b.BetType = 1 AND SpecialType = 9
												THEN -3 --Next Booking
											WHEN b.BetType = 3 AND SpecialType = 4
												THEN -5 --15mins O/U
											WHEN b.BetType = 3 AND SpecialType = 5
												THEN -6 --10mins O/U
											WHEN b.BetType = 1 AND SpecialType = 2  
												THEN -39 --No. of Corners 15mins HPD
											WHEN b.BetType = 3 AND SpecialType = 2  
												THEN -7 --No. of Corner 15mins O/U
											WHEN b.BetType = 3 AND SpecialType = 7
												THEN -8 --Total Bookings
											WHEN b.BetType = 1 AND SpecialType = 1
												THEN -37 --Total Bookings 15mins HDP
											WHEN b.BetType = 3 AND SpecialType = 1 
												THEN -10 --Total Bookings 15mins O/U
											WHEN b.BetType = 1 AND SpecialType = 6  
												THEN -41  --No. of Corners HPD
											WHEN b.BetType = 3 AND SpecialType = 6  
												THEN -13 --No. of Corners O/U
											WHEN b.BetType = 7 AND SpecialType = 6  
												THEN -40 --1st No. of Corners HDP
											WHEN b.BetType = 8 AND SpecialType = 6  
												THEN -12 --1st No. of Corners O/U											
											WHEN b.BetType = 8 AND SpecialType = 7
												THEN -9 --1st TotalBookings
											WHEN (b.BetType = 3 OR b.BetType = 8) AND SpecialType = 3
												THEN -11 --Single Team O/U
											ELSE b.BetType
										END
		) AS ca
		WHERE	b.winlostdate = @WinLostDate;
		
		SELECT	@RowCount	= @@ROWCOUNT
			,	@Duration	= DATEDIFF(millisecond, @Begin, GETDATE());

		IF	@Debug = 1
		BEGIN
			-- Force the output to appear immediately --
			RAISERROR('	Insert #tmpRTStagingTraderPerformance2 - %d rows - %d ms', 0, 0, @RowCount, @Duration) WITH NOWAIT;
		END;

		INSERT INTO #tmpRTDataGroup (TraderId, EventDate, MatchId, BetType, BetTeam, ScoreHDP, MOdds, StatusID, AVGOdds, StakeMYBeforeComm, StakeMY, Stake, 
			AVGOdds_AR, StakeMYBeforeComm_AR, StakeMY_AR, Stake_AR)
		SELECT	[TraderId]			= t.TraderId
			,	[EventDate]			= t.EventDate
			,	[MatchId]			= t.MatchId
			,	[BetType]			= t.BetType
			,	[BetTeam]			= t.BetTeam
			,	[ScoreHDP]			= t.ScoreHDP
			,	[MOdds]				= t.MOdds
			,	[StatusID]			= t.StatusID
			,	[AVGOdds]			= SUM((CASE WHEN t.Odds < 0 THEN 1 ELSE t.Odds END) * ABS(t.Stake) * (1 - t.TPositionTaking - t.ExtraPT) * t.VirtualRate)
									/ SUM((CASE WHEN t.Odds < 0 THEN -t.Odds ELSE 1 END) * ABS(t.Stake) * (1 - t.TPositionTaking - t.ExtraPT) * t.VirtualRate)
									--TotalWin/TotalLose
			,	[StakeMYBeforeComm]	= SUM(t.StakeMY * (1 - t.TPositionTaking - t.ExtraPT) * t.VirtualRate)
			,	[StakeMY]			= SUM(t.StakeMY * (1 - t.TPositionTaking - t.ExtraPT) * t.VirtualRate - (t.Scomm - CASE WHEN t.TPositionTaking = 1 THEN 0 ELSE t.Scomm * t.ExtraPT / (1 - t.TPositionTaking) END) * (CASE WHEN t.VirtualRate > t.ActualRate THEN t.ActualRate ELSE t.VirtualRate END))
			,	[Stake]				= SUM(CASE WHEN t.Odds < 0 THEN -t.Odds ELSE 1 END * ABS(t.Stake) * (1 - t.TPositionTaking - t.ExtraPT) * t.VirtualRate - (t.Scomm - CASE WHEN t.TPositionTaking = 1 THEN 0 ELSE t.Scomm * t.ExtraPT / (1 - t.TPositionTaking) END) * (CASE WHEN t.VirtualRate > t.ActualRate THEN t.ActualRate ELSE t.VirtualRate END))
				
			,	[AVGOdds_AR]		= SUM((CASE WHEN t.Odds < 0 THEN 1 ELSE t.Odds END) * ABS(t.Stake) * (1 - t.TPositionTaking - t.ExtraPT) * (CASE WHEN t.VirtualRate > t.ActualRate THEN t.VirtualRate ELSE t.ActualRate END))
									/ SUM((CASE WHEN t.Odds < 0 THEN -t.Odds ELSE 1 END) * ABS(t.Stake) * (1 - t.TPositionTaking - t.ExtraPT) * (CASE WHEN t.VirtualRate > t.ActualRate THEN t.VirtualRate ELSE t.ActualRate END))
									--TotalWin/TotalLose
			,	[StakeMYBeforeComm_AR]	= SUM(t.StakeMY * (1 - t.TPositionTaking - t.ExtraPT) * (CASE WHEN t.VirtualRate > t.ActualRate THEN t.VirtualRate ELSE t.ActualRate END))
			,	[StakeMY_AR]		= SUM(t.StakeMY * (1 - t.TPositionTaking - t.ExtraPT) * (CASE WHEN t.VirtualRate > t.ActualRate THEN t.VirtualRate ELSE t.ActualRate END) - (t.Scomm - CASE WHEN t.TPositionTaking = 1 THEN 0 ELSE t.Scomm * t.ExtraPT / (1 - t.TPositionTaking) END) * t.ActualRate)
			,	[Stake_AR]			= SUM(CASE WHEN t.Odds < 0 THEN -t.Odds ELSE 1 END * ABS(t.Stake) * (1 - t.TPositionTaking - t.ExtraPT) * (CASE WHEN t.VirtualRate > t.ActualRate THEN t.VirtualRate ELSE t.ActualRate END) - (t.Scomm - CASE WHEN t.TPositionTaking = 1 THEN 0 ELSE t.Scomm * t.ExtraPT / (1 - t.TPositionTaking) END) * t.ActualRate)
		FROM	#tmpRTStagingTraderPerformance2 AS t WITH(NOLOCK)
		GROUP BY t.TraderId, t.EventDate, t.MatchId, t.BetType, t.BetTeam, t.ScoreHDP, t.MOdds, t.StatusID;
		
		SELECT	@RowCount	= @@ROWCOUNT
			,	@Duration	= DATEDIFF(millisecond, @Begin, GETDATE());

		IF	@Debug = 1
		BEGIN
			-- Force the output to appear immediately --
			RAISERROR('	Insert #tmpRTDataGroup - %d rows - %d ms', 0, 0, @RowCount, @Duration) WITH NOWAIT;
		END;

		TRUNCATE TABLE	#tmpRTTrader2;
		TRUNCATE TABLE	#tmpRTStagingTraderPerformance2;
		TRUNCATE TABLE	#tmpRTFilteredBettransForJuice;

		-- Start calculating juice and update to TraderPerformance table
		IF	@Debug = 1
		BEGIN
			PRINT('Start calculating juice and update to TraderPerformance table');
		END;

		IF	OBJECT_ID('tempdb..#tmpRTJuice') IS NOT NULL
		BEGIN
			DROP TABLE	#tmpRTJuice;
		END;

		CREATE TABLE	#tmpRTJuice (
				EventDate			DATE
			,	MatchId				INT
			,	BetType				SMALLINT
			,	StakeMYBeforeComm	MONEY
			,	StakeMY				MONEY
			,	Juice				MONEY
			,	StakeMYRJuice		MONEY
			,	StakeMYRTotal		MONEY
			,	ScoreHDP			SMALLMONEY
			,	StakeMYBeforeComm_AR	MONEY
			,	StakeMY_AR			MONEY
			,	Juice_AR			MONEY
			,	StakeMYRJuice_AR	MONEY
			,	StakeMYRTotal_AR	MONEY
		);

		CREATE INDEX #IDX_tmpRTJuiceEventDate ON #tmpRTJuice (
				EventDate			ASC
			,	MatchId				ASC
			,	BetType				ASC
		);

		IF	OBJECT_ID('tempdb..#tmpRTSumTotal') IS NOT NULL
		BEGIN
			DROP TABLE	#tmpRTSumTotal;
		END;

		CREATE TABLE	#tmpRTSumTotal (
				EventDate			DATE
			,	MatchId				INT
			,	BetType				SMALLINT
			,	StakeMYBeforeComm	MONEY
			,	Juice				MONEY
			,	StakeMYRJuice		MONEY
			,	StakeMYBeforeComm_AR	MONEY
			,	Juice_AR			MONEY
			,	StakeMYRJuice_AR	MONEY
		);
		
		CREATE INDEX #IDX_tmpRTSumTotalEventDate ON #tmpRTSumTotal (
			EventDate			ASC
		);

		IF	OBJECT_ID('tempdb..#tmpRTResults') IS NOT NULL
		BEGIN
			DROP TABLE	#tmpRTResults;
		END;

		CREATE TABLE	#tmpRTResults (
				EventDate			DATE
			,	MatchId				INT
			,	BetType				SMALLINT
			,	StakeMYBeforeComm	MONEY
			,	Juice				MONEY
			,	StakeMYRJuice		MONEY
			,	StakeMYBeforeComm_AR	MONEY
			,	Juice_AR			MONEY
			,	StakeMYRJuice_AR	MONEY
		);

		CREATE INDEX #IDX_tmpRTResultsEventDate ON #tmpRTResults (
			EventDate			ASC
		);

		INSERT INTO #tmpRTJuice (EventDate, MatchId, BetType, ScoreHDP, StakeMYBeforeComm, StakeMY, Juice, StakeMYRJuice, StakeMYRTotal, 
			StakeMYBeforeComm_AR, StakeMY_AR, Juice_AR, StakeMYRJuice_AR, StakeMYRTotal_AR)
		SELECT	[EventDate]			= temp1.EventDate
			,	[MatchId]			= temp1.MatchId
			,	[BetType]			= temp1.BetType
			,	[ScoreHDP]			= temp1.ScoreHDP
			,	[StakeMYBeforeComm]	= SUM(temp1.StakeMYBeforeComm)
			,	[StakeMY]			= SUM(temp1.StakeMY)
			,	[Juice]				= SUM(ISNULL( CASE	WHEN temp1.BetTeam IN ('h')
															THEN  CASE WHEN temp2.Stake * (1 + ABS(temp2.AVGOdds)) / (1 + ABS(temp1.AVGOdds)) > temp1.Stake THEN temp1.Stake ELSE temp2.Stake * (1 + ABS(temp2.AVGOdds)) / (1 + ABS(temp1.AVGOdds)) END * CASE WHEN temp1.AVGOdds > 0 THEN 1 ELSE -temp1.AVGOdds END
																- CASE WHEN temp1.Stake * (1 + ABS(temp1.AVGOdds)) / (1 + ABS(temp2.AVGOdds)) > temp2.Stake THEN temp2.Stake ELSE temp1.Stake * (1 + ABS(temp1.AVGOdds)) / (1 + ABS(temp2.AVGOdds)) END * CASE WHEN temp2.AVGOdds > 0 THEN temp2.AVGOdds ELSE 1 END 
														ELSE 0 
												  END
												, 0
										  )
									  )
			,	[StakeMYRJuice]		= SUM(ISNULL( CASE	WHEN temp1.BetTeam IN ('h')
															THEN  CASE WHEN temp2.Stake * (1 + ABS(temp2.AVGOdds)) / (1 + ABS(temp1.AVGOdds)) > temp1.Stake THEN temp1.Stake ELSE temp2.Stake * (1 + ABS(temp2.AVGOdds)) / (1 + ABS(temp1.AVGOdds)) END * CASE WHEN ABS(temp1.AVGOdds) > 1 THEN ABS(temp1.AVGOdds) ELSE 1 END
																+ CASE WHEN temp1.Stake * (1 + ABS(temp1.AVGOdds)) / (1 + ABS(temp2.AVGOdds)) > temp2.Stake THEN temp2.Stake ELSE temp1.Stake * (1 + ABS(temp1.AVGOdds)) / (1 + ABS(temp2.AVGOdds)) END * CASE WHEN ABS(temp2.AVGOdds) > 1 THEN ABS(temp2.AVGOdds) ELSE 1 END
														ELSE 0
												  END
												, 0
										  )
									  )
			,	[StakeMYRTotal]		= SUM(ISNULL( CASE	WHEN temp1.BetTeam IN ('h')
															THEN  temp1.Stake * CASE WHEN ABS(temp1.AVGOdds) > 1 THEN ABS(temp1.AVGOdds) ELSE 1 END
																+ temp2.Stake * CASE WHEN ABS(temp2.AVGOdds) > 1 THEN ABS(temp2.AVGOdds) ELSE 1 END
														ELSE 0
												  END
												, 0
										  )
									  )
			,	[StakeMYBeforeComm_AR]	= SUM(temp1.StakeMYBeforeComm_AR)
			,	[StakeMY_AR]			= SUM(temp1.StakeMY_AR)
			,	[Juice_AR]				= SUM(ISNULL( CASE	WHEN temp1.BetTeam IN ('h')
															THEN  CASE WHEN temp2.Stake_AR * (1 + ABS(temp2.AVGOdds_AR)) / (1 + ABS(temp1.AVGOdds_AR)) > temp1.Stake_AR THEN temp1.Stake_AR ELSE temp2.Stake_AR * (1 + ABS(temp2.AVGOdds_AR)) / (1 + ABS(temp1.AVGOdds_AR)) END * CASE WHEN temp1.AVGOdds_AR > 0 THEN 1 ELSE -temp1.AVGOdds_AR END
																- CASE WHEN temp1.Stake_AR * (1 + ABS(temp1.AVGOdds_AR)) / (1 + ABS(temp2.AVGOdds_AR)) > temp2.Stake_AR THEN temp2.Stake_AR ELSE temp1.Stake_AR * (1 + ABS(temp1.AVGOdds_AR)) / (1 + ABS(temp2.AVGOdds_AR)) END * CASE WHEN temp2.AVGOdds_AR > 0 THEN temp2.AVGOdds_AR ELSE 1 END 
														ELSE 0 
												  END
												, 0
										  )
									  )
			,	[StakeMYRJuice_AR]		= SUM(ISNULL( CASE	WHEN temp1.BetTeam IN ('h')
															THEN  CASE WHEN temp2.Stake_AR * (1 + ABS(temp2.AVGOdds_AR)) / (1 + ABS(temp1.AVGOdds_AR)) > temp1.Stake_AR THEN temp1.Stake_AR ELSE temp2.Stake_AR * (1 + ABS(temp2.AVGOdds_AR)) / (1 + ABS(temp1.AVGOdds_AR)) END * CASE WHEN ABS(temp1.AVGOdds_AR) > 1 THEN ABS(temp1.AVGOdds_AR) ELSE 1 END
																+ CASE WHEN temp1.Stake_AR * (1 + ABS(temp1.AVGOdds_AR)) / (1 + ABS(temp2.AVGOdds_AR)) > temp2.Stake_AR THEN temp2.Stake_AR ELSE temp1.Stake_AR * (1 + ABS(temp1.AVGOdds_AR)) / (1 + ABS(temp2.AVGOdds_AR)) END * CASE WHEN ABS(temp2.AVGOdds_AR) > 1 THEN ABS(temp2.AVGOdds_AR) ELSE 1 END
														ELSE 0
												  END
												, 0
										  )
									  )
			,	[StakeMYRTotal_AR]		= SUM(ISNULL( CASE	WHEN temp1.BetTeam IN ('h')
															THEN  temp1.Stake_AR * CASE WHEN ABS(temp1.AVGOdds_AR) > 1 THEN ABS(temp1.AVGOdds_AR) ELSE 1 END
																+ temp2.Stake_AR * CASE WHEN ABS(temp2.AVGOdds_AR) > 1 THEN ABS(temp2.AVGOdds_AR) ELSE 1 END
														ELSE 0
												  END
												, 0
										  )
									  )
		FROM		#tmpRTDataGroup AS temp1 WITH (NOLOCK)
		LEFT JOIN	#tmpRTDataGroup AS temp2 WITH (NOLOCK)
				ON	temp1.MatchId = temp2.MatchId
				AND	temp1.BetType = temp2.BetType
				AND	temp1.ScoreHDP = temp2.ScoreHDP
				AND	temp1.BetTeam <> temp2.BetTeam
		GROUP BY temp1.EventDate, temp1.MatchId, temp1.BetType, temp1.ScoreHDP;

		INSERT INTO	#tmpRTSumTotal (EventDate, MatchId, BetType, StakeMYBeforeComm, Juice, StakeMYRJuice, StakeMYBeforeComm_AR, Juice_AR, StakeMYRJuice_AR)
		SELECT	[EventDate]			= t.EventDate
			,	[MatchId]			= t.MatchId
			,	[BetType]			= t.BetType
			,	[StakeMYBeforeComm]	= SUM(t.StakeMYBeforeComm)
			,	[Juice]				= SUM(t.Juice)
			,	[StakeMYRJuice]		= SUM(CASE WHEN t.StakeMYRTotal = 0 THEN 0 ELSE CAST(t.StakeMYBeforeComm AS DECIMAL(38,18)) * t.StakeMYRJuice / t.StakeMYRTotal END) -- Before comm		
			,	[StakeMYBeforeComm_AR]	= SUM(t.StakeMYBeforeComm_AR)
			,	[Juice_AR]			= SUM(t.Juice_AR)
			,	[StakeMYRJuice_AR]	= SUM(CASE WHEN t.StakeMYRTotal_AR = 0 THEN 0 ELSE CAST(t.StakeMYBeforeComm_AR AS DECIMAL(38,18)) * t.StakeMYRJuice_AR / t.StakeMYRTotal_AR END) -- Before comm
		FROM	#tmpRTJuice t
		GROUP BY t.EventDate, t.MatchId, t.BetType, t.ScoreHDP;

		INSERT INTO #tmpRTResults (EventDate, MatchId, BetType, StakeMYBeforeComm, Juice, StakeMYRJuice, StakeMYBeforeComm_AR, Juice_AR, StakeMYRJuice_AR)
		SELECT	[EventDate]			= t.EventDate
			,	[MatchId]			= t.MatchId
			,	[BetType]			= t.BetType
			,	[StakeMYBeforeComm]	= SUM(t.StakeMYBeforeComm)
			,	[Juice]				= SUM(t.Juice)
			,	[StakeMYRJuice]		= SUM(t.StakeMYRJuice)		
			,	[StakeMYBeforeComm_AR]	= SUM(t.StakeMYBeforeComm_AR)
			,	[Juice_AR]			= SUM(t.Juice_AR)
			,	[StakeMYRJuice_AR]	= SUM(t.StakeMYRJuice_AR)
		FROM	#tmpRTSumTotal t
		GROUP BY t.EventDate, t.MatchId, t.BetType;
	
		UPDATE	tp
		SET		tp.Juice = t.Juice
			,	tp.StakeMYR = t.StakeMYBeforeComm
			,	tp.StakeMYRJuice = t.StakeMYRJuice
			,	tp.Juice_AR = t.Juice_AR
			,	tp.StakeMYR_AR = t.StakeMYBeforeComm_AR
			,	tp.StakeMYRJuice_AR = t.StakeMYRJuice_AR
		FROM		dbo.TraderPerformance AS tp WITH (ROWLOCK, UPDLOCK)
		INNER JOIN	#tmpRTResults AS t WITH (NOLOCK) ON	t.MatchId = tp.matchid
				AND	t.BetType = tp.bettype
		WHERE	tp.EventDate = t.EventDate
				AND tp.IsLive = 1; -- Temporarily update Juice for live tickets only
	
		SELECT	@RowCount	= @@ROWCOUNT
			,	@Duration	= DATEDIFF(millisecond, @Begin, GETDATE())
			;

		IF	@Debug = 1
		BEGIN
			-- Force the output to appear immediately --
			RAISERROR('UPDATE Juice into TraderPerformance - %d rows - %d ms', 0, 0, @RowCount, @Duration) WITH NOWAIT;
		END;
		
		DELETE	d
		FROM	#tmpRTWinlostdate AS d
		WHERE	d.winlostdate = @winlostdate;

	END;

END;

GO
/*<info serverAlias="DBTGRS-bodb_TGRS" executers="bodbTGRSNet" isFunction="0" isNested="0"></info>*/