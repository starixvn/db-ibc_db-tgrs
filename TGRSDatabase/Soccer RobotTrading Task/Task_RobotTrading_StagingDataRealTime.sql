ALTER PROCEDURE  [dbo].[Task_RobotTrading_StagingDataRealTime]
		@Debug					BIT = 0
	,   @Bettypes				VARCHAR(2000) =  '1,3,7,8'
AS
/*
	Created:	20191217@Long.Luu
	Task :		Staging Data on TGRS DB
	DB:			DBTGRS.bodb_TGRS
	Original:
  
	Revisions:
		- 20191217@Long.Luu:	Created [Redmine ID: 118959]
   		
	Param's Explanation:

	Exam:
	 
*/
BEGIN
	SET NOCOUNT ON;

	/*
	-- INITIALIZE --
	*/
	-- Common variables
	DECLARE	@Begin					DATETIME = GETDATE()
		,	@RowCount				INT
		,	@Duration				INT
		,	@Msg					NVARCHAR(MAX)
		,	@Date					NVARCHAR(250);

	DECLARE @Today					SMALLDATETIME;

	DECLARE	@WinlostDate			DATE;
	DECLARE @CurrentDate			DATE = CONVERT(DATE, GETDATE());
	DECLARE @CurrentDateBefore1Hour DATE =  CONVERT(DATE, DATEADD(HOUR, -1, GETDATE()));
	
	IF	OBJECT_ID('tempdb..#tmpFilteredBettypes') IS NOT NULL
		DROP TABLE	#tmpFilteredBettypes;

	CREATE TABLE	#tmpFilteredBettypes (
			BetType					SMALLINT PRIMARY KEY
	);

	INSERT INTO #tmpFilteredBettypes(BetType)
	SELECT val FROM dbo.strSplit_Key(@Bettypes,',')
	
	IF	OBJECT_ID('tempdb..#tmpScanningMatches') IS NOT NULL
	BEGIN
		DROP TABLE #tmpScanningMatches;
	END;

	CREATE TABLE	#tmpScanningMatches (
			MatchId			INT NOT NULL
		,	EventDate		DATETIME
		,	KickOffTime		DATETIME
		,	WorkShift		TINYINT
		,	MatchCode		NVARCHAR(50)			
		,	LeagueId		INT		
		,	LeagueGroupId	SMALLINT	
		,	SportType		INT
		,	HomeId			INT
		,	AwayId			INT
		,	LeagueName		NVARCHAR(100)
		,	HomeName		NVARCHAR(100)
		,	SpecialType		INT				
	);
	
	CREATE CLUSTERED INDEX	#CIX_tmpDLScannedMatches_MatchId ON #tmpScanningMatches (
			MatchId			ASC
	);
	
	CREATE NONCLUSTERED INDEX #NIX_tmpDLScannedMatches_EventDate ON #tmpScanningMatches (
			EventDate		ASC
	);

	IF	OBJECT_ID('tempdb..#tmpTraders') IS NOT NULL
	BEGIN
		DROP TABLE #tmpTraders;
	END;

	CREATE TABLE	#tmpTraders (
			TraderId		INT
		,	LeagueId		INT
		,	MatchId			INT
		,	EventDate		DATETIME
		,	MainDBBetType	INT
		,	TeamId			INT
		,	Grade			TINYINT
	);

	CREATE CLUSTERED INDEX	#CIX_tmpDLTraderIdx ON #tmpTraders (
			TraderId		ASC
		,	EventDate		ASC
		,	MatchId			ASC
		,	MainDBBetType	ASC
	);

	IF	OBJECT_ID('tempdb..#tmp8RMMembers') IS NOT NULL
	BEGIN
		DROP TABLE #tmp8RMMembers;
	END;

	CREATE TABLE	#tmp8RMMembers (
			CustId			INT PRIMARY KEY
	);

	IF	OBJECT_ID('tempdb..#tmpWinlossDates') IS NOT NULL
	BEGIN
		DROP TABLE	#tmpWinlossDates;
	END;

	CREATE TABLE	#tmpWinlossDates (
			WinlostDate		DATE
	);

	IF	OBJECT_ID('tempdb..#ExtraPTSportbooks') IS NOT NULL
	BEGIN
		DROP TABLE	#ExtraPTSportbooks;
	END;

	CREATE TABLE #ExtraPTSportbooks
	(
			SuperId			INT
		,	ExtraPT			MONEY
		,	FromDate		DATETIME
		,	ToDate			DATETIME
	);

	IF	OBJECT_ID('tempdb..#tmpFilteredBettransByBatch') IS NOT NULL
	BEGIN
		DROP TABLE	#tmpFilteredBettransByBatch;
	END;

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
		,	Srecommend			INT
		,	Scomm				MONEY
		,	ExtraPT				DECIMAL(12, 8)
		,	Stake				MONEY
		,	WinLost				MONEY
		,	SMAWinLost			MONEY
		,	MatchCode			VARCHAR(100)
		,	EventDate			DATETIME
		,	SportType			INT
		,	LeagueId			INT
		,	LeagueGroupId		SMALLINT	
		,	HomeId				INT
		,	AwayId				INT
		,	LiveIndicator		BIT
		,   BetChoice			NVARCHAR(10) 
		,	Is8RM				BIT
	);
		
	CREATE CLUSTERED INDEX	#CIX_tmpFilteredBettransByBatch_CustId ON #tmpFilteredBettransByBatch (
			CustId				ASC
	);
	
	IF	OBJECT_ID('tempdb..#tmpFilteredBettransByBatch_Distinct') IS NOT NULL
	BEGIN
		DROP TABLE	#tmpFilteredBettransByBatch_Distinct;
	END;

	CREATE TABLE	#tmpFilteredBettransByBatch_Distinct (
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
		,	Srecommend			INT
		,	Scomm				MONEY
		,	ExtraPT				DECIMAL(12, 8)
		,	Stake				MONEY
		,	WinLost				MONEY
		,	SMAWinLost			MONEY
		,	MatchCode			VARCHAR(100)
		,	EventDate			DATETIME
		,	SportType			INT
		,	LeagueId			INT
		,	LeagueGroupId		SMALLINT	
		,	HomeId				INT
		,	AwayId				INT
		,	LiveIndicator		BIT
		,   BetChoice			NVARCHAR(10) 
		,	Is8RM				BIT
	);

	CREATE CLUSTERED INDEX	#CIX_tmpDLFilteredBettransByBatch_DistinctIdx ON #tmpFilteredBettransByBatch_Distinct (
			WinlostDate			ASC
		,	MatchId				ASC
		,	BetType				ASC
	);

	CREATE NONCLUSTERED INDEX	#NCIX_tmpDLFilteredBettransByBatch_DistinctIdx ON #tmpFilteredBettransByBatch_Distinct (
			CustId				ASC
	);

	IF	OBJECT_ID('tempdb..#tmpStagingTraderPerformance') IS NOT NULL
	BEGIN
		DROP TABLE	#tmpStagingTraderPerformance;
	END;

	CREATE TABLE	#tmpStagingTraderPerformance (
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
		,	ExtraPT				DECIMAL(12, 8)
		,	TPositionTaking		SMALLMONEY
		,	VirtualRate			FLOAT
		,	ActualRate			FLOAT
		,	LiveIndicator		BIT
		,   BetChoice			NVARCHAR(10) 
		,	Is8RM				BIT
		,	LeagueGroupId		SMALLINT
	);
	
	CREATE CLUSTERED INDEX #CIX_tmpDLStagingTraderPerformanceIdx ON #tmpStagingTraderPerformance (
			TraderId			ASC
		,	EventDate			ASC
	); 

	CREATE NONCLUSTERED INDEX	#NCIX_tmpDLStagingTraderPerformanceIdx ON #tmpStagingTraderPerformance (
			CustId				ASC
	);

	/*
	-- START GENERATING DATA --
	*/
	INSERT INTO #tmp8RMMembers(CustId)
	SELECT c.custid
	FROM bodb02.dbo.custInfo AS c WITH(NOLOCK)
	WHERE c.recommend = 52466;

	INSERT INTO #tmpWinlossDates (winlostdate)
	SELECT DISTINCT winlostdate
	FROM (VALUES (@CurrentDate), (@CurrentDateBefore1Hour)) d(winlostdate);

	WHILE EXISTS (SELECT 1 FROM #tmpWinlossDates)
	BEGIN
		SELECT	TOP(1)
				@WinLostDate = d.winlostdate
		FROM	#tmpWinlossDates AS d
		ORDER BY winlostdate ASC;

		-- STAGING DATA
		-- GET Scanned Match List: Completed Soccer Match
		INSERT INTO #tmpScanningMatches(MatchId, EventDate, KickOffTime, WorkShift, MatchCode, LeagueId, LeagueGroupId, SportType, HomeId, AwayId, LeagueName, HomeName, SpecialType)
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
		WHERE	m.EventDate = @WinLostDate
				AND	m.SportType = 1
				AND m.EventStatus = 'completed'
				AND	m.MatchCode NOT LIKE '%hedge%';
		
		-- REMOVE Scanned Match List: if existing any Ticket has not been settled (ruben <> 1)
		DELETE	sm
		FROM	#tmpScanningMatches AS sm WITH (ROWLOCK)
		WHERE	sm.MatchId  IN (	SELECT	TOP(1) b.MatchId
									FROM	bodb02.dbo.bettrans AS b WITH(NOLOCK) 
									WHERE	b.matchid = sm.matchid
											AND b.Currency NOT IN (20, 27, 28)
											AND b.ruben <> 1);		
		
		INSERT INTO	#tmpTraders (TraderId, LeagueId, MatchId, EventDate, MainDBBetType, TeamId, Grade)
		SELECT	DISTINCT
				[TraderId]		= a.TraderID
			,	[LeagueId]		= m.LeagueId
			,	[MatchId]		= m.MatchId
			,	[EventDate]		= m.EventDate
			,	[MainDBBetType] = a.bettype
			,	[TeamId]		= td_T.TeamId
			,	[Grade]			= td_G.Grade
		FROM	bodb02.dbo.Dot_Admin_Assignment_Trader AS a WITH (NOLOCK)
				INNER JOIN #tmpScanningMatches AS m WITH (NOLOCK) ON m.MatchId = a.Matchid
				LEFT JOIN dbo.TraderGrade_History AS td_G WITH (NOLOCK) ON	td_G.CustID = a.TraderID
					AND	m.EventDate BETWEEN td_G.BeginDate AND ISNULL(td_G.EndDate, @Today + 10)
				LEFT JOIN dbo.TraderTeam_History AS td_T WITH (NOLOCK) ON	td_T.CustID = a.TraderID
					AND	m.EventDate BETWEEN td_T.BeginDate AND ISNULL(td_T.EndDate, @Today + 10)
		WHERE	m.EventDate = @WinLostDate;
		
		SELECT	@RowCount	= @@ROWCOUNT
			,	@Duration	= DATEDIFF(millisecond, @Begin, GETDATE());
		
		IF	@Debug = 1
		BEGIN
			RAISERROR('From Origin - Insert #tmpTraders - Date: "%s" - %d rows - %d ms', 0, 0, @Date, @RowCount, @Duration) WITH NOWAIT;
		END;

		-- ExtraPT
		INSERT INTO #ExtraPTSportbooks
		SELECT t.SuperId, SUM(t.ExtraPT) AS ExtraPT, t.FromDate, t.ToDate
		FROM
			(
				SELECT SuperId, ExtraPT, FromDate, ToDate
				FROM bodb02.dbo.Acc_GroupExtraPTSetting WITH (NOLOCK)
				WHERE @WinlostDate BETWEEN FromDate AND ToDate
					AND ProductId = 1 AND Sporttype = 0 AND SubProduct = ''
			) AS t
		GROUP BY t.SuperId, t.FromDate, t.ToDate;

		SELECT @Date = CONVERT(NVARCHAR, @WinlostDate, 120);

		TRUNCATE TABLE	#tmpFilteredBettransByBatch;
		INSERT INTO	#tmpFilteredBettransByBatch (TransId, CustId, MatchId, WorkShift, SpecialType, WinlostDate, Bettype, Modds, 
				VirtualRate, ActualRate, Tpositiontaking, Srecommend, Scomm, ExtraPT, Stake, WinLost, SMAWinLost, MatchCode,
				EventDate, SportType, LeagueId, LeagueGroupId, HomeId, AwayId, LiveIndicator, BetChoice, Is8RM)
		SELECT	[TransId]			= b.transid
			,	[CustId]			= b.custid
			,	[MatchId]			= b.matchId
			,	[WorkShift]			= m.WorkShift
			,	[SpecialType]		= m.SpecialType
			,	[WinlostDate]		= b.winlostdate
			,	[Bettype]			= CASE	WHEN b.bettype = 1308
												THEN 153
											WHEN b.bettype = 1311
												THEN 154
											WHEN b.bettype = 1316
												THEN 155
											WHEN b.bettype = 465
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
			,	[VirtualRate]		= b.virtualrate
			,	[ActualRate]		= b.actualrate
			,	[Tpositiontaking]	= b.tpositiontaking
			,	[Srecommend]		= b.srecommend
			,	[Scomm]				= b.scomm
			,	[ExtraPT]			= CASE WHEN m.eventdate < '20170221' THEN 0 ELSE es.ExtraPT END
			,	[Stake]				= CASE WHEN b.modds = 0.25 OR b.modds = - 0.25 THEN ABS(b.stake) / 2 ELSE ABS(b.stake) END
			,	[WinLost]			= winlost - actual_stake
			,	[SMAWinLost]		= awinlost + mwinlost + swinlost
			,	[MatchCode]			= m.matchCode
			,	[EventDate]			= m.EventDate
			,	[SportType]			= m.SportType
			,	[LeagueId]			= m.LeagueId
			,	[LeagueGroupId]		= m.LeagueGroupId
			,	[HomeId]			= m.HomeId
			,	[AwayId]			= m.AwayId
			,	[LiveIndicator]		= b.liveindicator
			,	[BetChoice]			= b.betteam
			,	[Is8RM]				= CASE WHEN t8.CustId IS NULL THEN 0 ELSE 1 END
		FROM	bodb02.dbo.bettrans AS b WITH (NOLOCK)
				INNER JOIN #tmpScanningMatches AS m WITH (NOLOCK) ON b.matchid = m.matchid
				INNER JOIN #tmpFilteredBettypes AS bt WITH(NOLOCK) ON b.bettype = bt.BetType
				LEFT JOIN #ExtraPTSportbooks AS es WITH (NOLOCK) ON es.SuperId = b.srecommend
					AND	b.winlostdate BETWEEN es.FromDate AND es.ToDate
				LEFT JOIN bodb02.dbo.MatchMaxbet AS mm WITH (NOLOCK) ON mm.MatchId = b.matchid
					AND	mm.BetType = b.bettype
				LEFT JOIN #tmp8RMMembers AS t8 WITH(NOLOCK) ON b.CustId = t8.CustId
		WHERE	b.winlostdate = @WinlostDate
				AND	b.statusID IN (112, 113)
				AND	b.Currency NOT IN (20, 27, 28)
				AND b.liveindicator = 1;
			
		SELECT	@RowCount	= @@ROWCOUNT
			,	@Duration	= DATEDIFF(millisecond, @Begin, GETDATE());

		IF	@Debug = 1
		BEGIN
			RAISERROR('From Origin - Insert #tmpFilteredBettransByBatch - Date: "%s" - %d rows - %d ms', 0, 0, @Date, @RowCount, @Duration) WITH NOWAIT;
		END;

		-- "DISTINCT" Prevent Page Splits
		TRUNCATE TABLE	#tmpFilteredBettransByBatch_Distinct;
		INSERT INTO	#tmpFilteredBettransByBatch_Distinct (TransId, CustId, MatchId, WorkShift, SpecialType, WinlostDate, Bettype, Modds, 
				VirtualRate, ActualRate, Tpositiontaking, Srecommend, Scomm, ExtraPT, Stake, WinLost, SMAWinLost, MatchCode, 
				EventDate, SportType, LeagueId, LeagueGroupId, HomeId, AwayId, LiveIndicator, BetChoice, Is8RM)
		SELECT	DISTINCT b.TransId, b.CustId, b.MatchId, b.WorkShift, b.SpecialType, b.WinlostDate, b.Bettype, b.Modds, 
				b.VirtualRate, b.ActualRate, b.Tpositiontaking, b.Srecommend, b.Scomm, b.ExtraPT, b.Stake, b.WinLost, b.SMAWinLost, b.MatchCode, 
				b.EventDate, b.SportType, b.LeagueId, b.LeagueGroupId, b.HomeId, b.AwayId, b.LiveIndicator, b.BetChoice, b.Is8RM
		FROM	#tmpFilteredBettransByBatch AS b WITH(NOLOCK);
			
		INSERT INTO	#tmpStagingTraderPerformance (TraderId, CustId, WorkShift, MatchId, MatchCode, EventDate, SportType, LeagueId, LeagueGroupId, HomeId, AwayId, TeamId, 
			Grade, BetType, Stake, WinLost, SMAWinLost, Comm, BetCount, ExtraPT, TPositionTaking, VirtualRate, ActualRate, LiveIndicator, BetChoice, Is8RM)
		SELECT	[TraderId]			= t.TraderId
			,	[CustId]			= b.CustId
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
			,	[WinLost]			= b.WinLost
			,	[SMAWinLost]		= b.SMAWinLost
			,	[Comm]				= b.scomm --Commission
			,	[BetCount]			= 1 --Live BetCount
			,	[ExtraPT]			= ISNULL(b.ExtraPT, 0)
			,	[TPositionTaking]	= b.tpositiontaking
			,	[VirtualRate]		= b.virtualrate
			,	[ActualRate]		= b.actualrate
			,	[LiveIndicator]		= b.LiveIndicator
			,	[BetChoice]			= b.BetChoice 
			,	[Is8RM]				= b.Is8RM
		FROM	#tmpFilteredBettransByBatch_Distinct AS b WITH (NOLOCK)
				LEFT JOIN #tmpTraders AS t WITH (NOLOCK) ON	b.winlostdate = t.EventDate
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
												WHEN b.BetType = 3 AND b.SpecialType = 2
													THEN - 7 --Corners 15mins O/U
												WHEN b.BetType = 3 AND b.SpecialType = 7
													THEN - 8 --Total Bookings
												WHEN b.BetType = 1 AND b.SpecialType = 1
													THEN - 37 --Total Bookings 15mins HDP
												WHEN b.BetType = 3 AND b.SpecialType = 1
													THEN - 10 --Total Bookings 15mins O/U
												WHEN b.BetType = 3 AND b.SpecialType = 6
													THEN - 13 --No. of Corner
												WHEN b.BetType = 8 AND b.SpecialType = 6
													THEN - 12 --1st No. of Corner
												WHEN b.BetType = 8 AND b.SpecialType = 7
													THEN - 9 --1st TotalBookings
												WHEN (b.BetType = 3 OR b.BetType = 8) AND b.SpecialType = 3
													THEN - 11 --Single Team O/U
												ELSE b.BetType
											END
					) AS ca
		WHERE	b.winlostdate = @WinlostDate
		GROUP BY	t.TraderId
				,	b.custid
				,	ISNULL(b.WorkShift, 1)
				,	b.MatchId
				,	b.MatchCode
				,	b.EventDate
				,	b.SportType
				,	b.LeagueId
				,	b.LeagueGroupId
				,	b.HomeId
				,	b.AwayId
				,	t.TeamId
				,	t.Grade
				,	ca.BetType
				,	b.Stake
				,	b.WinLost
				,	b.SMAWinLost
				,	b.scomm
				,	ISNULL(b.ExtraPT, 0)
				,	b.tpositiontaking
				,	b.virtualrate
				,	b.actualrate
				,	b.BetChoice
				,	b.LiveIndicator
				,	b.Is8RM
				,	b.transid -- should not be removed since there is a case that extraPT is changed in the range of time --> duplicate row
				;

		SELECT	@RowCount	= @@ROWCOUNT
			,	@Duration	= DATEDIFF(millisecond, @Begin, GETDATE());

		IF	@Debug = 1
		BEGIN
			RAISERROR('From Origin - Insert #tmpStagingTraderPerformance - Date: "%s" - %d rows - %d ms', 0, 0, @Date, @RowCount, @Duration) WITH NOWAIT;
		END;

		DELETE dbo.RobotTrading WHERE EventDate = @WinlostDate AND Bettype IN (SELECT BetType FROM #tmpFilteredBettypes WITH (NOLOCK));

		INSERT INTO	dbo.RobotTrading (TraderId, WorkShift, MatchId, MatchCode, EventDate, SportType, LeagueId, HomeId, AwayId, TeamId, Grade, BetType,  
			Is8RM, LeagueGroupId, Stake_VR, WinLoss_VR, Comm_VR, Stake_AR, WinLoss_AR, Comm_AR, BetCount)
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
			,	[BetCount]			= SUM(CASE WHEN tc.custid IS NULL THEN t.BetCount ELSE 0 END)
		FROM	#tmpStagingTraderPerformance AS t WITH(NOLOCK) 
				LEFT JOIN bodb02.dbo.TradeCust tc WITH (NOLOCK) ON t.CustId = tc.custid AND tc.VendorID = 14
		WHERE	t.EventDate = @WinlostDate
		GROUP BY t.TraderId, t.WorkShift, t.MatchId, t.MatchCode, t.EventDate, t.SportType, t.LeagueId, t.HomeId, t.AwayId, t.TeamId, t.Grade, t.BetType, t.LiveIndicator, t.Is8RM, t.LeagueGroupId;
				
		SELECT	@RowCount	= @@ROWCOUNT
			,	@Duration	= DATEDIFF(millisecond, @Begin, GETDATE());

		IF	@Debug = 1
		BEGIN
			RAISERROR('From Origin - Insert TraderPerformance - Date: "%s" - %d rows - %d ms', 0, 0, @Date, @RowCount, @Duration) WITH NOWAIT;
		END;

		-- SUM DAILY
		DELETE [dbo].[RobotTrading_BetTypeDaily] WITH(ROWLOCK)
		WHERE EventDate = @WinlostDate;

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
		)
		SELECT	[EventDate]		= @Date 
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
		FROM [dbo].[RobotTrading] AS t WITH(NOLOCK)
		WHERE t.EventDate = @WinlostDate
		GROUP BY t.[BetType]
			,	t.[LeagueId]
			,	t.[LeagueGroupId]
			,	t.[Is8RM];

		-- SUM MONTHLY
		DECLARE @StartDate		DATE
			,	@EndDate		DATE;

		SELECT @StartDate = DATEADD(DD, -DAY(@WinlostDate) + 1, @WinlostDate);
		SELECT @EndDate = DATEADD(DD, -1 ,DATEADD(MM, 1, @StartDate));
 
		DELETE [dbo].[RobotTrading_BetTypeMonthly] WITH(ROWLOCK)
		WHERE EventDate = @StartDate;

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
		)
		SELECT	[EventDate]		= @StartDate 
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
		 FROM [dbo].[RobotTrading] AS t WITH(NOLOCK)
		 WHERE t.EventDate BETWEEN @StartDate AND @EndDate
		 GROUP BY t.[BetType]
			,	t.[LeagueId]
			,	t.[LeagueGroupId]
			,	t.[Is8RM];

		DELETE	d WITH(ROWLOCK)
		FROM	#tmpWinlossDates AS d
		WHERE	d.winlostdate = @winlostdate;
	END;
END;

GO
/*<info serverAlias="DBTGRS-bodb_TGRS" executers="bodbTGRSNet" isFunction="0" isNested="0"></info>*/