ALTER PROCEDURE	[dbo].[Task_StagingRealTimeTGRSDataForToday]
	@LookBackTime				DATETIME = NULL
AS
/*
	Created:	20171017@Long.Luu
	Task :		Staging Data for Today on TGRS DB
	DB:			DB06.bodb_TGRS_UAT & DB061.bodb_TGRS
	Original:   Task_StagingRealTimeTGRSDataForToday
  
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
		- 20210916@John.Ngo: Add Fast Market Bettype [Redmine: #157999]
		- 20220117@John.Ngo: Support view down for Total Goal, Time Machine and Corner bettype [Redmine: #166679]
		- 20221025@John.Ngo: [TGR] Enhance for the case of TPositionTaking = 1 [Redmine ID: 179546]
		- 20230103@John.Ngo: Fix Odds Spread Setting - ReCalculate Original Winlost [Redmine ID: 182351]
		- 20230421@John.Ngo: Update formula of Juice and Leftover (Separate 8RM data) [Redmine ID: 187082]
		- 20240217@Jaden.Tang: Remove TradeCust table (#206895)
		- 20250409@Jaden.Tang: Add VarianceVR for TGRS Staging Data [Redmine ID: #213765]
		- 20250707@Jaden.Tang: Add SiteID for TGRS Staging Data [Redmine ID: #213812]
		- 20250917@Jaden.Tang: Separate Juice calculation and increase job interval [Redmine ID: #237899]
		
	Param's Explanation:
		
	Exam:
*/
BEGIN
	SET NOCOUNT ON;

	-- Slightly more than the job interval
    DECLARE @LookbackMinutes INT = 15;
    DECLARE @Now DATETIME = GETDATE();

    IF @LookbackTime IS NULL
        SET @LookbackTime = DATEADD(MINUTE, -@LookbackMinutes, @Now);

	DECLARE	@IdForLiveUnassignedTrader		INT = 0
		,	@IdForNonLiveUnassignedTrader	INT = -1;

	DECLARE	@Today		SMALLDATETIME = GETDATE();

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

	CREATE TABLE	#tmpRTSupportedBettypes (
			BetType					SMALLINT PRIMARY KEY
		,	IsBetChoiceDetail		BIT DEFAULT ((0))
	);
	
	INSERT INTO #tmpRTSupportedBettypes(BetType, IsBetChoiceDetail)
	SELECT	DISTINCT b.bettype, b.IsBetChoiceDetail
	FROM	dbo.BetType AS b WITH (NOLOCK)
	WHERE	b.BetType > 0;

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

	CREATE TABLE	#tmp8RMMembers (
			CustId			INT PRIMARY KEY CLUSTERED
	);

	CREATE TABLE	#tmpRTTrader (
			TraderId			INT
		,	LeagueId			INT
		,	MatchId				INT
		,	EventDate			DATETIME
		,	Bettype				INT
		,	TeamId				INT
		,	Grade				TINYINT
	);

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
		,	hdp1				SMALLMONEY
		,	hdp2				SMALLMONEY
		,	oddsspread			MONEY
		,	Is8RM				BIT
		,   BetChoice			NVARCHAR(10)
		,	AdjOdds				SMALLMONEY
		,	OriOdds				SMALLMONEY
		,	statuswinlost		TINYINT
		,	oddstype			TINYINT
		,	isDecOddsOnly		BIT
		,	VarianceVR			DECIMAL(9,6) NULL -- Added VarianceVR
	);

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
		,	hdp1				SMALLMONEY
		,	hdp2				SMALLMONEY
		,	oddsspread			MONEY
		,	Is8RM				BIT
		,   BetChoice			NVARCHAR(10)
		,	IsBetChoiceDetail	BIT
		,	VarianceVR			DECIMAL(9,6) NULL -- Added VarianceVR
		,	SiteID				INT NULL
	);

	DECLARE @Odds		FLOAT
		,	@winlost	MONEY
		,	@UpdateById TINYINT = 1; -- 1: by odds, 2: by winlost

	INSERT INTO #tmp8RMMembers(CustId)
	SELECT c.custid
	FROM bodb02.dbo.custInfo AS c WITH(NOLOCK)
	WHERE c.recommend = 52466;

	-- Staging data
	BEGIN		
		-- GET Scanned Match List: Completed Soccer Match
		INSERT INTO #tmpRTScannedMatches WITH (TABLOCK) 
			(MatchId, EventDate, KickOffTime,WorkShift, MatchCode, LeagueId, SportType, HomeId, AwayId, LeagueName, HomeName, SpecialType)
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
		WHERE	m.SportType = 1
				AND m.EventStatus = 'completed'
                AND EXISTS (
					SELECT 1 FROM bodb02.dbo.bettrans b WITH (NOLOCK) 
					WHERE m.matchid = b.matchid AND b.Settlementtime >= @LookbackTime
					AND b.Currency NOT IN (20, 27, 28)
					AND b.statusID IN (111, 112, 113)
					AND b.ruben = 1
                )
        OPTION (RECOMPILE);	

		CREATE CLUSTERED INDEX	#CIX_tmpRTScannedMatches_MatchId ON #tmpRTScannedMatches (
			MatchId		ASC
		);

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
		LEFT JOIN	dbo.TraderGrade_History AS td_G WITH (NOLOCK) ON td_G.CustID = a.TraderId
				AND	m.EventDate BETWEEN td_G.BeginDate AND ISNULL(td_G.EndDate, @Today + 10)
		LEFT JOIN	dbo.TraderTeam_History AS td_T WITH (NOLOCK) ON	td_T.CustID = a.TraderId
				AND	m.EventDate BETWEEN td_T.BeginDate AND ISNULL(td_T.EndDate, @Today + 10)
		WHERE	a.TraderId <> 0
			AND a.MatchID IN (SELECT MatchID FROM #tmpRTScannedMatches)
		OPTION (RECOMPILE);
		
		-- keep only the latest records by matchid/bettype
		WITH LatestTraderAssignments AS (
			SELECT 
				t.TraderId, 
				t.MatchId, 
				t.BetType,
				ROW_NUMBER() OVER(PARTITION BY t.MatchId, t.BetType ORDER BY a.UpdatedTime DESC, a.ID DESC) AS Row_Num
			FROM #tmpRTTrader t
			INNER JOIN bodb02.dbo.Dot_Admin_Assignment_Trader AS a WITH (NOLOCK) 
				ON t.MatchId = a.matchid 
				AND t.BetType = a.bettype 
				AND t.TraderId = a.TraderId
		)
		DELETE t
		FROM #tmpRTTrader t
		INNER JOIN LatestTraderAssignments lta ON 
			t.MatchId = lta.MatchId AND 
			t.BetType = lta.BetType AND
			lta.Row_Num > 1;

		CREATE CLUSTERED INDEX	#CIX_tmpRTTraderIdx ON #tmpRTTrader (
				EventDate			ASC
			,	MatchId				ASC
			,	BetType				ASC
		);

		-- Fix Odds Spread Setting - ReCalculate Original Winlost (b.winlost - b.actual_stake)
		INSERT INTO	#tmpRTFilteredBettransByBatch WITH (TABLOCK)
			(TransId, CustId, MatchId, WorkShift, SpecialType, Winlostdate, Bettype, Modds, Virtualrate, Actualrate, Tpositiontaking,
				spositiontaking, mpositiontaking, apositiontaking, Srecommend, Scomm, ExtraPT, Spread, Stake, actual_stake, winlost, awinlost, mwinlost, swinlost, 
				MatchCode, EventDate, SportType, LeagueId, HomeId, AwayId, LiveIndicator, hdp1, hdp2, oddsspread, Is8RM, BetChoice, AdjOdds, OriOdds ,statuswinlost, oddstype, isDecOddsOnly
				, VarianceVR -- Added VarianceVR
				)
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
				,	[winlost]			= (b.winlost - b.actual_stake)
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
				,	[hdp1]				= b.hdp1
				,	[hdp2]				= b.hdp2
				,	[oddsspread]		= b.oddsspread
				,	[Is8RM]				= CASE WHEN t8.CustId IS NULL THEN 0 ELSE 1 END
				,	[BetChoice]			= b.betteam
				,	[AdjOdds]			= CASE WHEN fdec.OddsType IS NOT NULL THEN b.odds - 1 ELSE b.odds END
				,	[OriOdds]			= NULL -- Will be populated in the UPDATE statement
				,	[statuswinlost]		= b.statuswinlost
				,	[oddstype]			= b.oddstype
				,	[isDecOddsOnly]		= CASE WHEN fdec.OddsType IS NOT NULL THEN 1 ELSE 0 END
				,	[VarianceVR]		= CASE WHEN b.actualrate <> 0 THEN CAST((b.virtualrate / b.actualrate - 1) AS DECIMAL(9,6)) ELSE NULL END -- Calculate VarianceVR
		FROM		bodb02.dbo.bettrans AS b WITH (NOLOCK)
			INNER JOIN	#tmpRTScannedMatches AS m WITH (NOLOCK)	ON b.matchid = m.matchid
			LEFT JOIN	bodb02.dbo.MatchMaxbet AS mm WITH (NOLOCK) ON mm.MatchId = b.MatchId AND mm.BetType = b.bettype
			LEFT JOIN	#tmpRTSpread1x2 AS s ON	mm.Spread = s.Margin AND mm.BetType IN (5, 15)
			LEFT JOIN #tmp8RMMembers AS t8 WITH(NOLOCK) ON b.CustId = t8.CustId
			LEFT JOIN bodb02.dbo.f_Set_OddsTypeBettypes() fdec  ON b.bettype = fdec.BetType
		WHERE	b.statusID IN (112, 113)
			AND	b.Currency NOT IN (20, 27, 28)
		OPTION (RECOMPILE);
		
		-- "DISTINCT" Prevent Page Splits
		DELETE b WITH(ROWLOCK)
		FROM	(	
					SELECT ROW_NUMBER() OVER (PARTITION BY TransId ORDER BY TransId) AS rn
					FROM #tmpRTFilteredBettransByBatch
				) AS b
		WHERE b.rn > 1;

		-- Update to populate OriOdds from BettransInfo
		UPDATE b WITH(ROWLOCK, UPDLOCK)
		SET b.OriOdds = CASE WHEN fdec.OddsType IS NOT NULL THEN bi.OriginalOdds - 1 ELSE bi.OriginalOdds END
		FROM #tmpRTFilteredBettransByBatch AS b
		INNER LOOP JOIN bodb02.dbo.BettransInfo bi WITH (NOLOCK) ON b.transid = bi.transid
		LEFT JOIN bodb02.dbo.f_Set_OddsTypeBettypes() fdec ON b.bettype = fdec.BetType;
		
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
		WHERE b.OriOdds IS NOT NULL
			AND b.OriOdds <> 0
			AND b.AdjOdds <> 0;
			
		INSERT INTO	#tmpRTStagingTraderPerformance WITH (TABLOCK) 
			(TraderId, CustId, WorkShift, MatchId, MatchCode, EventDate, SportType, LeagueId, HomeId, AwayId, 
			TeamId, Grade, BetType, Stake, WinLost, SMAWinLost, Comm, BetCount, Spread, ExtraPT, TPositionTaking, VirtualRate, ActualRate, LiveIndicator, hdp1, hdp2, oddsspread, Is8RM, BetChoice, IsBetChoiceDetail
			, VarianceVR, SiteID
			)
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
				,	[WinLost]			= b.winlost
				,	[SMAWinLost]		= b.awinlost + b.mwinlost + b.swinlost
				,	[Comm]				= b.scomm --Commission
				,	[BetCount]			= 1 --Live BetCount
				,	[Spread]			= b.Spread
				,	[ExtraPT]			= ISNULL(b.ExtraPT, 0)
				,	[TPositionTaking]	= b.tpositiontaking
				,	[VirtualRate]		= b.virtualrate
				,	[ActualRate]		= b.actualrate
				,	[LiveIndicator]		= b.LiveIndicator
				,	[hdp1]				= b.hdp1
				,	[hdp2]				= b.hdp2
				,	[oddsspread]		= b.oddsspread
				,	[Is8RM]				= b.Is8RM
				,	[BetChoice]			= b.BetChoice
				,	[IsBetChoiceDetail]	= bt.IsBetChoiceDetail
				,	[VarianceVR]		= b.VarianceVR
				,	[SiteID]			= s.SiteID
		FROM	#tmpRTFilteredBettransByBatch AS b WITH (NOLOCK)
			INNER JOIN #tmpRTSupportedBettypes AS bt WITH(NOLOCK) ON b.BetType = bt.BetType
			INNER JOIN bodb02.dbo.vw_customer AS c WITH(NOLOCK) ON b.custid = c.CustId
			INNER JOIN bodb02.dbo.site AS s WITH(NOLOCK) ON c.site = s.site
			LEFT JOIN	#tmpRTTrader AS t WITH (NOLOCK)
					ON	b.winlostdate = t.EventDate
					AND	b.matchid = t.matchid
					AND	(b.BetType = t.BetType OR (b.bettype = 23 AND t.BetType = 1))
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
				) AS ca;

		CREATE CLUSTERED INDEX #CIX_tmpRTStagingTraderPerformanceIdx ON #tmpRTStagingTraderPerformance (
				EventDate			ASC
		); 

		UPDATE stp WITH(ROWLOCK, UPDLOCK)
		SET stp.TeamId = t.TeamId
			,	stp.Grade = t.Grade
		FROM #tmpRTStagingTraderPerformance AS stp
		INNER JOIN dbo.Trader t WITH (NOLOCK) ON t.CustId IN (@IdForLiveUnassignedTrader, @IdForNonLiveUnassignedTrader) AND stp.TraderId = t.CustId;
	END;

	BEGIN TRANSACTION
		DELETE FROM dbo.TraderPerformance 
		WHERE EXISTS (
			SELECT 1 FROM #tmpRTStagingTraderPerformance AS t 
			WHERE t.TraderId = TraderPerformance.CustId
			AND t.WorkShift = TraderPerformance.WorkShift
			AND t.MatchId = TraderPerformance.MatchId
			AND t.EventDate = TraderPerformance.EventDate
			AND t.SportType = TraderPerformance.SportType
			AND t.LeagueId = TraderPerformance.LeagueId
			AND t.HomeId = TraderPerformance.HomeId
			AND t.AwayId = TraderPerformance.AwayId
			AND t.TeamId = TraderPerformance.TeamId
			AND t.Grade = TraderPerformance.Grade
			AND t.BetType = TraderPerformance.BetType
			AND t.LiveIndicator = TraderPerformance.IsLive
			AND t.Is8RM = TraderPerformance.Is8RM
			AND t.VarianceVR = TraderPerformance.VarianceVR
			AND t.SiteID = TraderPerformance.SiteID
		)

		INSERT INTO	dbo.TraderPerformance (CustId, WorkShift, MatchId, MatchCode, EventDate, SportType, LeagueId, HomeId, AwayId, TeamId, Grade, BetType, 
			IsLive, Stake, WinLost, Comm, Stake_AR, WinLost_AR, Comm_AR, Is8RM, Stake_Real, WinLost_Real, Stake_VAR, WinLost_VAR, BetCount, Spread
			, VarianceVR, SiteID
			)
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
			,	[BetCount]			= SUM(t.BetCount)
			,	[Spread]			= MAX(t.Spread)
			,	[VarianceVR]		= t.VarianceVR
			,	[SiteID]			= t.SiteID
		FROM	#tmpRTStagingTraderPerformance AS t
		GROUP BY t.TraderId, t.WorkShift, t.MatchId, t.MatchCode, t.EventDate, t.SportType, t.LeagueId, t.HomeId, t.AwayId, t.TeamId, t.Grade, t.BetType, t.LiveIndicator, t.Is8RM
		, t.VarianceVR, t.SiteID;

		INSERT INTO	[dbo].[TraderPerformance_BetChoice](CustId, MatchId, EventDate, SportType, LeagueId, BetType, BetChoice, IsLive, Stake, WinLost, Comm, Stake_AR, WinLost_AR, Comm_AR, Is8RM, Stake_Real, WinLost_Real, Stake_VAR, WinLost_VAR, BetCount
			, VarianceVR, SiteID
			)
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
				,	[BetCount]			= SUM(t.BetCount)
				,	[VarianceVR]		= t.VarianceVR
				,	[SiteID]			= t.SiteID
		FROM #tmpRTStagingTraderPerformance AS t
		WHERE t.BetChoice IS NOT NULL
		GROUP BY t.TraderId, t.MatchId, t.EventDate, t.SportType, t.LeagueId, t.BetType, t.BetChoice, t.LiveIndicator, t.Is8RM
		, t.VarianceVR, t.SiteID;

		DELETE FROM dbo.TraderPerformance_BetChoice_Detail 
		WHERE EXISTS (
			SELECT 1 FROM #tmpRTStagingTraderPerformance AS t 
			WHERE t.TraderId = TraderPerformance_BetChoice_Detail.CustId
			AND t.MatchId = TraderPerformance_BetChoice_Detail.MatchId
			AND t.EventDate = TraderPerformance_BetChoice_Detail.EventDate
			AND t.SportType = TraderPerformance_BetChoice_Detail.SportType
			AND t.LeagueId = TraderPerformance_BetChoice_Detail.LeagueId
			AND t.BetType = TraderPerformance_BetChoice_Detail.BetType
			AND t.LiveIndicator = TraderPerformance_BetChoice_Detail.IsLive
			AND t.Is8RM = TraderPerformance_BetChoice_Detail.Is8RM
			AND t.hdp1 = TraderPerformance_BetChoice_Detail.hdp1
			AND t.hdp2 = TraderPerformance_BetChoice_Detail.hdp2
			AND t.oddsspread = TraderPerformance_BetChoice_Detail.oddsspread
			AND t.BetChoice = TraderPerformance_BetChoice_Detail.betteam
			AND t.VarianceVR = TraderPerformance_BetChoice_Detail.VarianceVR
			AND t.SiteID = TraderPerformance_BetChoice_Detail.SiteID
		)

		INSERT INTO	[dbo].[TraderPerformance_BetChoice_Detail](CustId, MatchId, EventDate, SportType, LeagueId, BetType, betteam, IsLive, hdp1, hdp2, oddsspread, Stake, WinLost, Comm, Stake_AR, WinLost_AR, Comm_AR, Is8RM, Stake_Real, WinLost_Real, Stake_VAR, WinLost_VAR, BetCount
			, VarianceVR, SiteID
			)
		SELECT		[CustId]			= t.TraderId
				,	[MatchId]			= t.MatchId
				,	[EventDate]			= t.EventDate
				,	[SportType]			= t.SportType
				,	[LeagueId]			= t.LeagueId
				,	[BetType]			= t.BetType
				,	[betteam]			= t.BetChoice
				,	[IsLive]			= t.LiveIndicator
				,	[hdp1]				= t.hdp1
				,	[hdp2]				= t.hdp2
				,	[oddsspread]		= t.oddsspread
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
				,	[BetCount]			= SUM(t.BetCount)
				,	[VarianceVR]		= t.VarianceVR
				,	[SiteID]			= t.SiteID
		FROM #tmpRTStagingTraderPerformance AS t
		WHERE t.BetChoice IS NOT NULL
			AND t.IsBetChoiceDetail = 1
		GROUP BY t.TraderId, t.MatchId, t.EventDate, t.SportType, t.LeagueId, t.BetType, t.BetChoice, t.LiveIndicator, t.hdp1, t.hdp2, t.oddsspread, t.Is8RM
		, t.VarianceVR, t.SiteID;
	
		-- STEP #2: SUM DAILY
		DELETE FROM [dbo].[SummaryByBetType_Daily] 
		WHERE EventDate IN (SELECT EventDate FROM #tmpRTStagingTraderPerformance);

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
		SELECT	[EventDate]		= t.[EventDate]
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
		WHERE t.EventDate IN (SELECT EventDate FROM #tmpRTStagingTraderPerformance)
		GROUP BY 
			t.[EventDate]
			,	t.[LeagueId]
			,	t.[BetType]
			,	t.[WorkShift]
			,	t.[IsLive]
			,	t.[Is8RM];

		CREATE TABLE	#tmpRTBettypeGroup (
				BetType			SMALLINT PRIMARY KEY
			,	BettypeGroup	TINYINT
		);

		INSERT INTO #tmpRTBettypeGroup(BetType,	BettypeGroup)
		SELECT DISTINCT b.BetType
			,	b.BettypeGroup
		FROM dbo.BetType b WITH(NOLOCK);
	
		DELETE FROM [dbo].[SummaryByLeague_Daily] 
		WHERE EventDate IN (SELECT EventDate FROM #tmpRTStagingTraderPerformance);

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
		SELECT	[EventDate]		= s.[EventDate]
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
		WHERE s.EventDate IN (SELECT EventDate FROM #tmpRTStagingTraderPerformance)
		GROUP BY 
			s.[EventDate]
			,	s.[LeagueId]
			,	s.[WorkShift]
			,	g.[BettypeGroup]
			,	s.[IsLive]
			,	s.[Is8RM];		   
		   
		DELETE FROM [dbo].[SummaryByTeam_Daily] 
		WHERE EventDate IN (SELECT EventDate FROM #tmpRTStagingTraderPerformance);

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
		SELECT	[EventDate]		= s.[EventDate]
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
		WHERE s.EventDate IN (SELECT EventDate FROM #tmpRTStagingTraderPerformance)
		GROUP BY s.[TeamId]
			,	s.[EventDate]
			,	s.[LeagueId]				
			,	s.[WorkShift]
			,	g.[BettypeGroup]
			,	s.[IsLive]
			,	s.[Is8RM];

		-- STEP 3: SUM MONTHLY
		DELETE [dbo].[SummaryByTrader_Monthly] 
		WHERE EventDate IN (
			SELECT DATEADD(MONTH, DATEDIFF(MONTH, 0, EventDate), 0) AS FirstDayOfMonth
			FROM #tmpRTStagingTraderPerformance
		);

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
		SELECT	[Eventdate]		= DATEADD(MONTH, DATEDIFF(MONTH, 0, s.EventDate), 0)
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
		WHERE s.EventDate IN (
			SELECT DATEADD(MONTH, DATEDIFF(MONTH, 0, EventDate), 0) AS FirstDayOfMonth
			FROM #tmpRTStagingTraderPerformance
		)
		GROUP BY 
			DATEADD(MONTH, DATEDIFF(MONTH, 0, s.EventDate), 0)
			,	s.[CustId]
			,	s.[LeagueId]
			,	s.[WorkShift]
			,	g.[BettypeGroup]
			,	s.[IsLive]
			,	s.[Is8RM];

		DELETE [dbo].[SummaryByBetType_Monthly]	
		WHERE EventDate IN (
			SELECT DATEADD(MONTH, DATEDIFF(MONTH, 0, EventDate), 0) AS FirstDayOfMonth
			FROM #tmpRTStagingTraderPerformance
		);

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
		SELECT	[EventDate]		= DATEADD(MONTH, DATEDIFF(MONTH, 0, s.EventDate), 0)
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
		WHERE s.EventDate IN (
			SELECT DATEADD(MONTH, DATEDIFF(MONTH, 0, EventDate), 0) AS FirstDayOfMonth
			FROM #tmpRTStagingTraderPerformance
		)
		GROUP BY 
			DATEADD(MONTH, DATEDIFF(MONTH, 0, s.EventDate), 0)
			,	s.[LeagueId]
			,	s.[BetType]
			,	s.[WorkShift]
			,	s.[IsLive]
			,	s.[Is8RM];

		DELETE [dbo].SummaryByLeague_Monthly 
		WHERE EventDate IN (
			SELECT DATEADD(MONTH, DATEDIFF(MONTH, 0, EventDate), 0) AS FirstDayOfMonth
			FROM #tmpRTStagingTraderPerformance
		);

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
		SELECT	[EventDate]		= DATEADD(MONTH, DATEDIFF(MONTH, 0, s.EventDate), 0)
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
		WHERE s.EventDate IN (
			SELECT DATEADD(MONTH, DATEDIFF(MONTH, 0, EventDate), 0) AS FirstDayOfMonth
			FROM #tmpRTStagingTraderPerformance
		)
		GROUP BY 
			DATEADD(MONTH, DATEDIFF(MONTH, 0, s.EventDate), 0)
			,	s.[LeagueId]
			,	s.[WorkShift]
			,	g.[BettypeGroup]
			,	s.[IsLive]
			,	s.[Is8RM];

		DELETE [dbo].SummaryByTeam_Monthly	
		WHERE EventDate IN (
			SELECT DATEADD(MONTH, DATEDIFF(MONTH, 0, EventDate), 0) AS FirstDayOfMonth
			FROM #tmpRTStagingTraderPerformance
		);

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
		SELECT	[EventDate]		= DATEADD(MONTH, DATEDIFF(MONTH, 0, s.EventDate), 0)
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
		WHERE s.EventDate IN (
			SELECT DATEADD(MONTH, DATEDIFF(MONTH, 0, EventDate), 0) AS FirstDayOfMonth
			FROM #tmpRTStagingTraderPerformance
		)
		GROUP BY 
			DATEADD(MONTH, DATEDIFF(MONTH, 0, s.EventDate), 0)
			,	s.[TeamId]
			,	s.[LeagueId]
			,	s.[WorkShift]
			,	g.[BettypeGroup]
			,	s.[IsLive]
			,	s.[Is8RM];
	COMMIT;

	DROP TABLE #tmpRTBettypeGroup;
	DROP TABLE #tmpRTStagingTraderPerformance;
	DROP TABLE #tmpRTFilteredBettransByBatch;
	DROP TABLE #tmpRTTrader;
	DROP TABLE #tmp8RMMembers;
	DROP TABLE #tmpRTSpread1x2;
	DROP TABLE #tmpRTSupportedBettypes;
	DROP TABLE #tmpRTScannedMatches;

END;
GO

/*<info serverAlias="DBTGRS-bodb_TGRS" executers="wsv_tgrs" isFunction="0" isNested="0"></info>*/