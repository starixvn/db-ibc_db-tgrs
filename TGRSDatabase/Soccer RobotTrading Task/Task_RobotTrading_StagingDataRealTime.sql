/*<info serverAlias="DBTGRS-bodb_TGRS" executers="wsv_tgrs" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE  [dbo].[Task_RobotTrading_StagingDataRealTime]
		@LookBackTime			DATETIME = NULL
	,   @Bettypes				VARCHAR(2000) =  '1,3,7,8'
AS
/*
	Created:	20191217@Long.Luu
	Task :		Staging Data on TGRS DB
	DB:			DBTGRS.bodb_TGRS
	Original:
  
	Revisions:
		- 20191217@Long.Luu: Created [Redmine ID: 118959]
		- 20200120@John.Ngo: [TGR Soccer] RT3 Performance - Model Comparision Report [Redmine ID: 127208]
   		- 20200210@John.Ngo: [TGR Soccer] RT3 - Adding TA model into Robot Trading by Bettype and Month [Redmine ID: 128184]
		- 20200409@John.Ngo: Update logic for #Trader [Redmine ID: 120634]
		- 20200416@John.Ngo: [TGR] Extend league data type [Redmine ID: 132630]
		- 20200504@John.Ngo: [TGR] Get ExtraPT from epositiontaking column in bettrans table [Redmine ID: 133409]
		- 20200721@John.Ngo: New Negative Bettype No Of Corner HDP [Redmine ID: 138095]
		- 20201017@John.Ngo: TGR - Integrate Adjustmnet Odds Spread of Licensee [Redmine ID: 142421]
		- 20201112@John.Ngo: TGR - Enhance formula of calculating adjusted odds by Licensee [Redmine ID: 145246]
		- 20230103@John.Ngo: Fix Odds Spread Setting - ReCalculate Original Winlost [Redmine ID: 182351]
		- 20240217@Jaden.Tang: Remove TradeCust table (#206895)
		- 20250917@Jaden.Tang: Improve performance and increase job interval [Redmine ID: #240746]
		
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

	DECLARE @Today					SMALLDATETIME = GETDATE();



	CREATE TABLE	#tmpFilteredBettypes (
			BetType					SMALLINT PRIMARY KEY CLUSTERED
	);

	INSERT INTO #tmpFilteredBettypes(BetType)
	SELECT val FROM dbo.strSplit_Key(@Bettypes,',')
	
	-- Filter Site
	CREATE TABLE	#tmpFilteredSite (
			SiteId	INT PRIMARY KEY CLUSTERED
		,	[Site]		VARCHAR(20)
		,	TypeSiteId	TINYINT
	);
	
	INSERT INTO #tmpFilteredSite(SiteId, [Site], TypeSiteId)
	SELECT  si.siteid, 
			si.[site], 
		CASE WHEN si.[site] = 'CN88' THEN 1 -- 'CN88'
			 WHEN si.isDeposit = 1 THEN 2 -- 'Cash' 
			 ELSE 3 --'Nova'
		END AS TypeSiteId
	FROM [bodb02].[dbo].[Site] si (NOLOCK);
	
	-- Customer Site
	CREATE TABLE	#tmpCustomerSite (
			CustId		INT PRIMARY KEY CLUSTERED
		,	[Site]		VARCHAR(20)
		,	TypeSiteId	TINYINT
	);

	CREATE TABLE	#tmpScanningMatches (
			MatchId			INT NOT NULL PRIMARY KEY CLUSTERED
		,	EventDate		DATETIME
		,	KickOffTime		DATETIME
		,	WorkShift		TINYINT
		,	MatchCode		NVARCHAR(50)			
		,	LeagueId		INT		
		,	LeagueGroupId	SMALLINT	
		,	SportType		INT
		,	HomeId			INT
		,	AwayId			INT
		,	LeagueName		NVARCHAR(512)
		,	HomeName		NVARCHAR(100)
		,	SpecialType		INT				
	);

	CREATE TABLE	#tmpTraders (
			TraderId		INT
		,	LeagueId		INT
		,	MatchId			INT
		,	EventDate		DATETIME
		,	MainDBBetType	INT
		,	TeamId			INT
		,	Grade			TINYINT
		,	[Type]			TINYINT
	);

	CREATE TABLE	#tmp8RMMembers (
			CustId			INT PRIMARY KEY CLUSTERED
	);


	CREATE TABLE	#tmpFilteredBettransByBatch (
			TransId				BIGINT
		,	CustId				INT
		,	MatchId				INT
		,	WorkShift			INT
		,	WinlostDate			SMALLDATETIME
		,	Bettype				SMALLINT
		,	SpecialType			INT
		,	Modds				SMALLMONEY
		,	VirtualRate			FLOAT
		,	ActualRate			FLOAT
		,	Tpositiontaking		SMALLMONEY
		,	spositiontaking		SMALLMONEY
		,	mpositiontaking		SMALLMONEY
		,	apositiontaking		SMALLMONEY
		,	Srecommend			INT
		,	Scomm				MONEY
		,	ExtraPT				DECIMAL(12, 8)
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
		,	LeagueGroupId		SMALLINT	
		,	HomeId				INT
		,	AwayId				INT
		,	LiveIndicator		BIT
		,	Is8RM				BIT
		,	AdjOdds				SMALLMONEY
		,	OriOdds				SMALLMONEY
		,	statuswinlost		TINYINT
		,	oddstype			TINYINT
		,	isDecOddsOnly		BIT
	);

	CREATE TABLE	#tmpRobotTradingPerformance (
			TraderId			INT
		,	CustId				INT
		,	Srecommend			INT
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
		,	ExtraPT				DECIMAL(12, 8)
		,	TPositionTaking		SMALLMONEY
		,	VirtualRate			FLOAT
		,	ActualRate			FLOAT
		,	LiveIndicator		BIT
		,	Is8RM				BIT
		,	LeagueGroupId		SMALLINT
		,	[Type]				TINYINT
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
		INSERT INTO #tmpScanningMatches WITH (TABLOCK)
			(MatchId, EventDate, KickOffTime, WorkShift, MatchCode, LeagueId, LeagueGroupId, SportType, HomeId, AwayId, LeagueName, HomeName, SpecialType)
		SELECT	m.matchid
			,	m.eventdate
			,	m.kickofftime
	 		,	CASE	WHEN CAST(m.kickofftime AS TIME) >= '00:00:00' AND CAST(m.kickofftime AS TIME) < '06:00:00'
							THEN 1 --  Afternoon: 12:00:00 ~ 17:59:59 (GMT + 8)
						WHEN CAST(m.kickofftime AS TIME) >= '06:00:00' AND CAST(m.kickofftime AS TIME) < '16:00:00'
							THEN 2 -- Night: 18:00:00 ~ 3:59:59 (GMT + 8)				
						--WHEN CAST(m.kickofftime AS TIME) >= '16:00:00' AND CAST(m.kickofftime AS TIME) <'24:00:00'THEN 3 --  Midnight: 4:00:00 ~ 11:59:59 (GMT + 8)
						ELSE 3
				END AS WorkShift
			,	m.matchcode
			,	m.leagueid
			,	l.LeagueGroupID
			,	m.SportType
			,	m.homeid
			,	m.awayId
			,	l.leaguename
			,	t.teamname AS HomeName
			,	CASE WHEN l.LeagueName LIKE '%SPECIFIC 15 MINS TOTAL BOOKINGS%'
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
				LEFT JOIN bodb02.dbo.team AS t WITH (NOLOCK) ON t.teamid = homeid
		WHERE	m.SportType = 1
				AND m.EventStatus = 'completed'
				AND	m.MatchCode NOT LIKE '%hedge%'
                AND EXISTS (
					SELECT 1 FROM bodb02.dbo.bettrans b WITH (NOLOCK) 
					WHERE m.matchid = b.matchid AND b.Settlementtime >= @LookbackTime
					AND b.Currency NOT IN (20, 27, 28)
					AND b.statusID IN (111, 112, 113)
					AND b.ruben = 1
                )
        OPTION (RECOMPILE);
		
		INSERT INTO	#tmpTraders (TraderId, LeagueId, MatchId, EventDate, MainDBBetType, TeamId, Grade, [Type])
		SELECT	DISTINCT
				[TraderId]		= a.TraderID
			,	[LeagueId]		= m.LeagueId
			,	[MatchId]		= m.MatchId
			,	[EventDate]		= m.EventDate
			,	[MainDBBetType] = a.bettype
			,	[TeamId]		= td_T.TeamId
			,	[Grade]			= td_G.Grade
			,	[Type]			= a.[Type]
		FROM	bodb02.dbo.Dot_Admin_Assignment_Trader AS a WITH (NOLOCK)
				INNER JOIN #tmpScanningMatches AS m WITH (NOLOCK) ON m.MatchId = a.Matchid
				INNER JOIN #tmpFilteredBettypes AS b WITH (NOLOCK) ON b.BetType = a.bettype
				LEFT JOIN dbo.TraderGrade_History AS td_G WITH (NOLOCK) ON	td_G.CustID = a.TraderID
					AND	m.EventDate BETWEEN td_G.BeginDate AND ISNULL(td_G.EndDate, @Today + 10)
				LEFT JOIN dbo.TraderTeam_History AS td_T WITH (NOLOCK) ON	td_T.CustID = a.TraderID
					AND	m.EventDate BETWEEN td_T.BeginDate AND ISNULL(td_T.EndDate, @Today + 10)
		WHERE	a.TraderId <> 0
			AND a.MatchID IN (SELECT MatchID FROM #tmpScanningMatches)
		OPTION (RECOMPILE);
		
		-- keep only the latest records by matchid/bettype
		WITH LatestTraderAssignments AS (
			SELECT 
				t.TraderId, 
				t.MatchId, 
				t.MainDBBetType,
				t.[Type],
				ROW_NUMBER() OVER(PARTITION BY t.MatchId, t.MainDBBetType, t.[Type] ORDER BY a.UpdatedTime DESC, a.ID DESC) AS Row_Num
			FROM #tmpTraders t
			INNER JOIN bodb02.dbo.Dot_Admin_Assignment_Trader AS a WITH (NOLOCK) 
				ON t.MatchId = a.matchid 
				AND t.MainDBBetType = a.bettype 
				AND t.TraderId = a.TraderId
				AND t.[Type] = a.[Type]
		)
		DELETE t
		FROM #tmpTraders t
		INNER JOIN LatestTraderAssignments lta ON 
			t.MatchId = lta.MatchId AND 
			t.MainDBBetType = lta.MainDBBetType AND
			t.[Type] = lta.[Type] AND
			lta.Row_Num > 1;

		-- REMOVE Scanned Match List: if not existing any Trader
		DELETE	sm
		FROM	#tmpScanningMatches AS sm WITH (ROWLOCK)
				LEFT JOIN #tmpTraders AS td WITH (NOLOCK) ON sm.MatchId = td.MatchId
		WHERE	td.MatchId IS NULL;
		-- Fix Odds Spread Setting - ReCalculate Original Winlost (b.winlost - b.actual_stake)
		INSERT INTO	#tmpFilteredBettransByBatch WITH (TABLOCK)
			(TransId, CustId, MatchId, WorkShift, SpecialType, WinlostDate, Bettype, Modds,	VirtualRate, ActualRate, Tpositiontaking,
				spositiontaking, mpositiontaking, apositiontaking, Srecommend, Scomm, ExtraPT, Stake, actual_stake, winlost, awinlost, mwinlost, swinlost,
				MatchCode, EventDate, SportType, LeagueId, LeagueGroupId, HomeId, AwayId, LiveIndicator, Is8RM, AdjOdds, OriOdds ,statuswinlost, oddstype, isDecOddsOnly)
		SELECT	[TransId]			= b.transid
			,	[CustId]			= b.custid
			,	[MatchId]			= b.matchId
			,	[WorkShift]			= m.WorkShift
			,	[SpecialType]		= m.SpecialType
			,	[WinlostDate]		= b.winlostdate
			,	[Bettype]			= b.bettype
			,	[Modds]				= b.modds
			,	[VirtualRate]		= b.virtualrate
			,	[ActualRate]		= b.actualrate
			,	[Tpositiontaking]	= b.tpositiontaking
			,	[spositiontaking]	= b.spositiontaking
			,	[mpositiontaking]	= b.mpositiontaking
			,	[apositiontaking]	= b.apositiontaking
			,	[Srecommend]		= b.srecommend
			,	[Scomm]				= b.scomm
			,	[ExtraPT]			= ISNULL(b.epositiontaking, 0)
			,	[Stake]				= CASE WHEN b.modds = 0.25 OR b.modds = - 0.25 THEN ABS(b.stake) / 2 ELSE ABS(b.stake) END
			,	[actual_stake]		= b.actual_stake
			,	[winlost]			= (b.winlost - b.actual_stake)
			,	[awinlost]			= b.awinlost
			,	[mwinlost]			= b.mwinlost
			,	[swinlost]			= b.swinlost
			,	[MatchCode]			= m.matchCode
			,	[EventDate]			= m.EventDate
			,	[SportType]			= m.SportType
			,	[LeagueId]			= m.LeagueId
			,	[LeagueGroupId]		= m.LeagueGroupId
			,	[HomeId]			= m.HomeId
			,	[AwayId]			= m.AwayId
			,	[LiveIndicator]		= b.liveindicator
			,	[Is8RM]				= CASE WHEN t8.CustId IS NULL THEN 0 ELSE 1 END
			,	[AdjOdds]			= CASE WHEN fdec.OddsType IS NOT NULL THEN b.odds - 1 ELSE b.odds END
			,	[OriOdds]			= NULL -- Will be populated in the UPDATE statement
			,	[statuswinlost]		= b.statuswinlost
			,	[oddstype]			= b.oddstype
			,	[isDecOddsOnly]		= CASE WHEN fdec.OddsType IS NOT NULL THEN 1 ELSE 0 END
		FROM	bodb02.dbo.bettrans AS b WITH (NOLOCK)
				INNER JOIN #tmpScanningMatches AS m WITH (NOLOCK) ON b.matchid = m.matchid
				INNER JOIN #tmpFilteredBettypes AS bt WITH(NOLOCK) ON b.bettype = bt.BetType
				LEFT JOIN bodb02.dbo.MatchMaxbet AS mm WITH (NOLOCK) ON mm.MatchId = b.matchid
					AND	mm.BetType = b.bettype
				LEFT JOIN #tmp8RMMembers AS t8 WITH(NOLOCK) ON b.CustId = t8.CustId
				LEFT JOIN bodb02.dbo.f_Set_OddsTypeBettypes() fdec  ON b.bettype = fdec.BetType
		WHERE	b.statusID IN (112, 113)
				AND	b.Currency NOT IN (20, 27, 28)
				AND b.liveindicator = 1
		OPTION (RECOMPILE);
			
		-- "DISTINCT" Prevent Page Splits
		DELETE b WITH(ROWLOCK)
		FROM	(	
					SELECT ROW_NUMBER() OVER (PARTITION BY TransId ORDER BY TransId ASC) AS rn
					FROM #tmpFilteredBettransByBatch
				) AS b
		WHERE b.rn > 1;

		-- Update to populate OriOdds from BettransInfo
		UPDATE b WITH(ROWLOCK, UPDLOCK)
		SET b.OriOdds = CASE WHEN fdec.OddsType IS NOT NULL THEN bi.OriginalOdds - 1 ELSE bi.OriginalOdds END
		FROM #tmpFilteredBettransByBatch AS b
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
			FROM #tmpFilteredBettransByBatch AS b
			WHERE b.OriOdds IS NOT NULL
				AND b.OriOdds <> 0
				AND b.AdjOdds <> 0;

			
		INSERT INTO	#tmpRobotTradingPerformance WITH (TABLOCK)
			(TraderId, CustId, Srecommend, WorkShift, MatchId, MatchCode, EventDate, SportType, LeagueId, LeagueGroupId, HomeId, AwayId, TeamId, 
			Grade, BetType, Stake, WinLost, SMAWinLost, Comm, BetCount, ExtraPT, TPositionTaking, VirtualRate, ActualRate, LiveIndicator, Is8RM, [Type])
		SELECT	[TraderId]			= t.TraderId
			,	[CustId]			= b.CustId
			,	[Srecommend]		= b.Srecommend
			,	[WorkShift]			= ISNULL(b.WorkShift, 1)
			,	[MatchId]			= b.MatchId
			,	[MatchCode]			= b.MatchCode
			,	[EventDate]			= b.EventDate
			,	[SportType]			= b.SportType
			,	[LeagueId]			= b.LeagueId
			,	[LeagueGroupId]		= b.LeagueGroupId
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
			,	[ExtraPT]			= ISNULL(b.ExtraPT, 0)
			,	[TPositionTaking]	= b.tpositiontaking
			,	[VirtualRate]		= b.virtualrate
			,	[ActualRate]		= b.actualrate
			,	[LiveIndicator]		= b.LiveIndicator
			,	[Is8RM]				= b.Is8RM
			,	[Type]				= t.[Type]
		FROM	#tmpFilteredBettransByBatch AS b WITH (NOLOCK)
				INNER JOIN #tmpTraders AS t WITH (NOLOCK) ON	b.winlostdate = t.EventDate
					AND	b.matchid = t.matchid
					AND	b.BetType = t.MainDBBetType
				CROSS APPLY	(
					SELECT	[BetType]	= CASE	WHEN b.BetType = 1 AND b.SpecialType = 0
														THEN 1 --HDP
													WHEN b.BetType = 3 AND b.SpecialType = 0
														THEN 3 --O/U		
													WHEN b.BetType = 8 AND b.SpecialType = 0
														THEN 8 --1st O/U
													WHEN b.BetType = 1 AND b.SpecialType = 4
														THEN - 1 --15mins HDP
													WHEN (b.BetType = 1 AND b.SpecialType = 8)
														THEN - 2 --Next Corner
													WHEN b.BetType = 1 AND b.SpecialType = 5
														THEN - 15 --10mins HDP
													WHEN b.BetType = 1 AND b.SpecialType = 9
														THEN - 3 --Next Booking
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
													ELSE b.BetType
												END
					) AS ca;

		-- Customer Site
		INSERT INTO #tmpCustomerSite (CustId, [Site])
		SELECT DISTINCT rt.CustId, c.[site]
		FROM #tmpRobotTradingPerformance rt WITH (NOLOCK)
			INNER JOIN bodb02.dbo.Customer c WITH (NOLOCK) ON rt.Srecommend = c.custid
		WHERE c.custid > 0;
			
		UPDATE ct
		SET ct.TypeSiteId = fs.TypeSiteId
		FROM #tmpCustomerSite ct WITH (NOLOCK)
			INNER JOIN #tmpFilteredSite fs WITH (NOLOCK) ON ct.[Site] = fs.[Site]
		WHERE fs.SiteId > 0;
	END;

	BEGIN TRANSACTION
		-- Delete existing data for the processed matches
		DELETE r WITH(ROWLOCK) 
		FROM dbo.RobotTrading AS r
		WHERE EXISTS (
			SELECT 1 FROM #tmpRobotTradingPerformance rt
			WHERE r.MatchId = rt.MatchId
			AND r.EventDate = rt.EventDate
			AND r.BetType = rt.BetType
		);

		-- Insert RobotTrading
		INSERT INTO	dbo.RobotTrading (TraderId, WorkShift, MatchId, MatchCode, EventDate, SportType, LeagueId, HomeId, AwayId, TeamId, Grade, BetType,  
			Is8RM, LeagueGroupId, Stake_VR, WinLoss_VR, Comm_VR, Stake_AR, WinLoss_AR, Comm_AR, BetCount, [Type], TypeSiteId)
		SELECT	[TraderId]			= t.TraderId
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
			,	[Is8RM]				= t.Is8RM
			,	[LeagueGroupId]		= t.LeagueGroupId
			,	[Stake_VR]			= SUM(t.Stake * (1 - t.TPositionTaking - t.ExtraPT) * t.VirtualRate)
			,	[WinLoss_VR]		= SUM(((-(t.WinLost + t.SMAWinLost)) + t.WinLost * t.ExtraPT) * t.VirtualRate)
			,	[Comm_VR]			= SUM((t.Comm - (CASE WHEN t.TPositionTaking = 1 THEN 0 ELSE (t.Comm * t.ExtraPT/(1 - t.TPositionTaking)) END)) * (CASE WHEN t.VirtualRate > t.ActualRate THEN t.ActualRate ELSE t.VirtualRate END))
			,	[Stake_AR]			= SUM(t.Stake * (1 - t.TPositionTaking - t.ExtraPT) * (CASE WHEN t.VirtualRate > t.ActualRate THEN t.VirtualRate ELSE t.ActualRate END))
			,	[WinLoss_AR]		= SUM(((-(t.WinLost + t.SMAWinLost)) + t.WinLost * t.ExtraPT) * t.ActualRate)
			,	[Comm_AR]			= SUM((t.Comm - (CASE WHEN t.TPositionTaking = 1 THEN 0 ELSE (t.Comm * t.ExtraPT/(1 - t.TPositionTaking)) END)) * t.ActualRate)
			,	[BetCount]			= SUM(t.BetCount)
			,	[Type]				= t.[Type]
			,	[TypeSiteId]		= c.TypeSiteId
		FROM	#tmpRobotTradingPerformance AS t WITH(NOLOCK)
				INNER JOIN #tmpCustomerSite AS c WITH(NOLOCK) ON t.CustId = c.CustId
		GROUP BY t.TraderId, t.WorkShift, t.MatchId, t.MatchCode, t.EventDate, t.SportType, t.LeagueId, t.HomeId, t.AwayId, t.TeamId, t.Grade, t.BetType, t.LiveIndicator, t.Is8RM, t.LeagueGroupId, t.[Type], c.TypeSiteId;

		-- SUM DAILY
		DELETE [dbo].[RobotTrading_BetTypeDaily] WITH(ROWLOCK)
		WHERE EventDate IN (SELECT DISTINCT EventDate FROM #tmpRobotTradingPerformance);

		INSERT INTO [dbo].[RobotTrading_BetTypeDaily]
		(
				[EventDate]
			,	[BetType]
			,	[LeagueId]
			,	[LeagueGroupId]
			,	[Is8RM]
			,	[Stake_VR]
			,	[WinLoss_VR]
			,	[Comm_VR]
			,	[Stake_AR]
			,	[WinLoss_AR]
			,	[Comm_AR]			
			,	[BetCount]	
			,	[MatchCount]
			,   [Type]
			,	[TypeSiteId]
		)
		SELECT	[EventDate]		= t.[EventDate]
			,	[BetType]		= t.[BetType]
			,	[LeagueId]		= t.[LeagueId]
			,	[LeagueGroupId] = t.[LeagueGroupId]
			,	[Is8RM]			= t.[Is8RM]
			,	[Stake_VR]		= SUM(t.[Stake_VR]) 
			,	[WinLoss_VR]	= SUM(t.[WinLoss_VR]) 
			,	[Comm_VR]		= SUM(t.[Comm_VR]) 
			,	[Stake_AR]		= SUM(t.[Stake_AR]) 
			,	[WinLoss_AR]	= SUM(t.[WinLoss_AR]) 
			,	[Comm_AR]		= SUM(t.[Comm_AR]) 
			,	[BetCount]		= SUM(t.[BetCount]) 
			,	[MatchCount]	= COUNT(DISTINCT [MatchId])
			,	[Type]			= t.[Type]
			,	[TypeSiteId]	= t.[TypeSiteId]
		FROM [dbo].[RobotTrading] AS t WITH(NOLOCK)
		WHERE t.EventDate IN (SELECT DISTINCT EventDate FROM #tmpRobotTradingPerformance)
		GROUP BY t.[EventDate]
			,	t.[BetType]
			,	t.[LeagueId]
			,	t.[LeagueGroupId]
			,	t.[Is8RM]
			,	t.[Type]
			,	t.[TypeSiteId];

		-- SUM MONTHLY
		DELETE [dbo].[RobotTrading_BetTypeMonthly] WITH(ROWLOCK)
		WHERE EventDate IN (
			SELECT DATEADD(MONTH, DATEDIFF(MONTH, 0, EventDate), 0) AS FirstDayOfMonth
			FROM #tmpRobotTradingPerformance
		);

		INSERT INTO [dbo].[RobotTrading_BetTypeMonthly]
		(
				[EventDate]
			,	[BetType]
			,	[LeagueId]
			,	[LeagueGroupId]
			,	[Is8RM]
			,	[Stake_VR]
			,	[WinLoss_VR]
			,	[Comm_VR]
			,	[Stake_AR]
			,	[WinLoss_AR]
			,	[Comm_AR]			
			,	[BetCount]	
			,	[MatchCount]
			,	[Type]
			,	[TypeSiteId]
		)
		SELECT	[EventDate]		= DATEADD(MONTH, DATEDIFF(MONTH, 0, t.EventDate), 0)
			,	[BetType]		= t.[BetType]
			,	[LeagueId]		= t.[LeagueId]
			,	[LeagueGroupId] = t.[LeagueGroupId]
			,	[Is8RM]			= t.[Is8RM]
			,	[Stake_VR]		= SUM(t.[Stake_VR]) 
			,	[WinLoss_VR]	= SUM(t.[WinLoss_VR]) 
			,	[Comm_VR]		= SUM(t.[Comm_VR]) 
			,	[Stake_AR]		= SUM(t.[Stake_AR]) 
			,	[WinLoss_AR]	= SUM(t.[WinLoss_AR]) 
			,	[Comm_AR]		= SUM(t.[Comm_AR]) 
			,	[BetCount]		= SUM(t.[BetCount]) 
			,	[MatchCount]	= COUNT(DISTINCT t.[MatchId])
			,	[Type]			= t.[Type]
			,	[TypeSiteId]	= t.[TypeSiteId]
		 FROM [dbo].[RobotTrading] AS t WITH(NOLOCK)
		 WHERE t.EventDate IN (
			SELECT DATEADD(MONTH, DATEDIFF(MONTH, 0, EventDate), 0) AS FirstDayOfMonth
			FROM #tmpRobotTradingPerformance
		 )
		 GROUP BY DATEADD(MONTH, DATEDIFF(MONTH, 0, t.EventDate), 0)
			,	t.[BetType]
			,	t.[LeagueId]
			,	t.[LeagueGroupId]
			,	t.[Is8RM]
			,	t.[Type]
			,	t.[TypeSiteId];

		DELETE [dbo].[RobotTrading_Monthly] WITH(ROWLOCK)
		WHERE EventDate IN (
			SELECT DATEADD(MONTH, DATEDIFF(MONTH, 0, EventDate), 0) AS FirstDayOfMonth
			FROM #tmpRobotTradingPerformance
		);

		INSERT INTO [dbo].[RobotTrading_Monthly]
		(
				[TraderId]
			,	[EventDate]
			,	[LeagueId]
			,	[LeagueGroupId]
			,	[Is8RM]
			,	[Stake_VR]
			,	[WinLoss_VR]
			,	[Comm_VR]
			,	[Stake_AR]
			,	[WinLoss_AR]
			,	[Comm_AR]			
			,	[BetCount]	
			,	[MatchCount]
			,	[Type]
			,	[TypeSiteId]
		)
		SELECT	[TraderId]		= t.TraderId
			,	[EventDate]		= DATEADD(MONTH, DATEDIFF(MONTH, 0, t.EventDate), 0)
			,	[LeagueId]		= t.[LeagueId]
			,	[LeagueGroupId] = t.[LeagueGroupId]
			,	[Is8RM]			= t.[Is8RM]
			,	[Stake_VR]		= SUM(t.[Stake_VR]) 
			,	[WinLoss_VR]	= SUM(t.[WinLoss_VR]) 
			,	[Comm_VR]		= SUM(t.[Comm_VR]) 
			,	[Stake_AR]		= SUM(t.[Stake_AR]) 
			,	[WinLoss_AR]	= SUM(t.[WinLoss_AR]) 
			,	[Comm_AR]		= SUM(t.[Comm_AR]) 
			,	[BetCount]		= SUM(t.[BetCount]) 
			,	[MatchCount]	= COUNT(DISTINCT t.[MatchId])
			,	[Type]			= t.[Type]
			,	[TypeSiteId]	= t.[TypeSiteId]
		 FROM [dbo].[RobotTrading] AS t WITH(NOLOCK)
		 WHERE t.EventDate IN (
			SELECT DATEADD(MONTH, DATEDIFF(MONTH, 0, EventDate), 0) AS FirstDayOfMonth
			FROM #tmpRobotTradingPerformance
		 )
		 GROUP BY DATEADD(MONTH, DATEDIFF(MONTH, 0, t.EventDate), 0)
			,	t.TraderId
			,	t.[LeagueId]
			,	t.[LeagueGroupId]
			,	t.[Is8RM]
			,	t.[Type]
			,	t.[TypeSiteId];

	COMMIT;

	-- Cleanup temp tables
	DROP TABLE #tmpRobotTradingPerformance;
	DROP TABLE #tmpFilteredBettransByBatch;
	DROP TABLE #tmpTraders;
	DROP TABLE #tmpScanningMatches;
	DROP TABLE #tmpCustomerSite;
	DROP TABLE #tmpFilteredSite;
	DROP TABLE #tmpFilteredBettypes;
	DROP TABLE #tmp8RMMembers;
END;

GO