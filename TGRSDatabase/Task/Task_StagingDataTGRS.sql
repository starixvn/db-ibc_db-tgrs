USE [bodb_TGRS]
GO
/****** Object:  StoredProcedure [dbo].[Task_StagingDataTGRS]    Script Date: 3/8/2018 9:12:16 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE	[dbo].[Task_StagingDataTGRS]
		@Debug					BIT = 0
	,	@BeforeMoveBetsDay		BIT = 1	
	,	@GenerateFromDate		SMALLDATETIME = NULL
	,	@GenerateToDate			SMALLDATETIME = NULL
AS
/*
	Created:	20140603@Tom.Vo
	Task :		Staging Data on TGRS DB
	DB:			DBTGRS.bodb_TGRS
	Original:
  
	Revisions:
		- 20141203@Tom.Vo:	Staging data with new requirement
		- 20160307@Billy:	Add new field Spread for staging data - [Redmine: #53240]
		- 20160318@Aaron:	Bug fixes on generating (1 st) 1x2 data from bettrans 
		- 20160329@Sophia: 	Change datatype of Spread Column [Redmine: #54943]
		- 20160517@Percy:	Recalculate Spread for group bettype 1x2 [RedmineID: #56999]    
		- 20170209@Long:	Apply ExtraPT
		- 20170315@Long:	devide batch by date (not by 200k records as it is)		
		- 20170517@Long:	Add more bettypes from Dot_Assginment
		- 20170830@Long:	Add more bettypes from Dot_Assginment
		- 20170816@Percy:	Change data type of Sporttype [RedmineID: #73545]
		- 20170914@Billy:	Format code and tune performance for Task Staging - [Redmine: #81465]
		- 20170918@Billy:	Remove hedge match from bettrans data - [Redmine: #83470]
		- 20170922@Long:	Support more bettypes for Soccer PH AiO - [Redmine: #83621]
		- 20171129@Long:	Support Non-Live tickets - [Redmine: #86289]
		- 20180102@Long:	Change the way to get BU & MB days
		- 20180109@Long:	Support code for generating historical data
		- 20180116@Long:	Group-by for BetChoice on each bettype [Redmine: #87861]
		- 20180119@John.Ngo: Update Logic generating data [Redmine: #87861]
		- 20180228@Long:	Track changes on matches [Redmine: #87962]
   		
	Param's Explanation:
		
	Exam:
	 
*/
BEGIN;
	SET NOCOUNT ON;

	-- Common variables
	DECLARE	@IdForUnassignedTrader	INT = 0
		;

	DECLARE	@Begin					DATETIME = GETDATE()
		,	@RowCount				INT
		,	@Duration				INT
		,	@Msg					NVARCHAR(MAX)
		;

	DECLARE @BalanceUpDay			SMALLDATETIME
		,	@MoveBetsDay			SMALLDATETIME
		,	@Yesterday				SMALLDATETIME
		;

	DECLARE	@winlostdate			DATETIME
		;
	
	IF	OBJECT_ID('tempdb..#Spread1x2') IS NOT NULL
	BEGIN;
		DROP TABLE	#Spread1x2
	END;

	CREATE TABLE	#Spread1x2 (
			Margin					MONEY
		,	Spread					MONEY
	);
						
	INSERT INTO	#Spread1x2
			(Margin, Spread)
	VALUES	(1.05  , 0.2   )
		,	(1.08  , 0.3   )
		,	(1.10  , 0.36  )
		,	(1.12  , 0.44  )
		,	(1.15  , 0.52  )
		;
				
	IF	OBJECT_ID('tempdb..#BUMBData') IS NOT NULL
	BEGIN;
		DROP TABLE	#BUMBData
	END;

	CREATE TABLE	#BUMBData (
			BUDay	SMALLDATETIME
		,	MBDay	SMALLDATETIME
	);

	INSERT INTO #BUMBData(BUDay,MBDay)
	EXECUTE bodb02.dbo.Age_SelBalanceUpDay;

	SELECT	TOP(1)
			@BalanceUpDay	= BUDay
		,	@MoveBetsDay	= MBDay
	FROM #BUMBData;

	SELECT	@Yesterday		= CONVERT(DATE, GETDATE() - 1);

	IF	@Debug = 1
	BEGIN;
		SELECT	@Msg = '
			@BalanceUpDay = ' + CONVERT(NVARCHAR, @BalanceUpDay, 120) + N'
			@MoveBetsDay  = ' + CONVERT(NVARCHAR, @MoveBetsDay, 120) + N'
			@Yesterday    = ' + CONVERT(NVARCHAR, @Yesterday, 120);

		-- Force the output to appear immediately --
		RAISERROR(@Msg, 0, 0) WITH NOWAIT;
	END;

	IF	OBJECT_ID('tempdb..#tmpTrader') IS NOT NULL
	BEGIN;
		DROP TABLE #tmpTrader;
	END;

	CREATE TABLE	#tmpTrader (
			CustId				INT
		,	LeagueId			INT
		,	MatchId				INT
		,	WorkShift			TINYINT
		,	MatchCode			VARCHAR(100)
		,	SportType			INT
		,	EventDate			DATETIME
		,	HomeId				INT
		,	AwayId				INT
		,	BetType				SMALLINT
		,	SpecialType			TINYINT
		,	TeamId				INT
		,	Grade				TINYINT
	);

	CREATE CLUSTERED INDEX	#CIX_tmpTraderIdx ON #tmpTrader (
			CustId				ASC
		,	EventDate			ASC
		,	MatchId				ASC
		,	BetType				ASC
	);

	IF	OBJECT_ID('tempdb..#winlostdate') IS NOT NULL
	BEGIN;
		DROP TABLE	#winlostdate;
	END;

	CREATE TABLE	#winlostdate (
		winlostdate				DATE
	);

	IF	OBJECT_ID('tempdb..#tmpFilteredBettransByBatch') IS NOT NULL
	BEGIN;
		DROP TABLE	#tmpFilteredBettransByBatch;
	END;

	CREATE TABLE	#tmpFilteredBettransByBatch (
			transid				BIGINT
		,	matchid				INT
		,	winlostdate			SMALLDATETIME
		,	bettype				SMALLINT
		,	modds				SMALLMONEY
		,	virtualrate			FLOAT
		,	tpositiontaking		SMALLMONEY
		,	srecommend			INT
		,	scomm				MONEY
		,	ExtraPT				DECIMAL(9, 8)
		,	Spread				MONEY
		,	Stake				MONEY
		,	WinLost				MONEY
		,	SMAWinLost			MONEY
		,	MatchCode			VARCHAR(100)
		,	EventDate			DATETIME
		,	SportType			INT
		,	LeagueId			INT
		,	HomeId				INT
		,	AwayId				INT
		,	LiveIndicator		BIT
		,   BetChoice			NVARCHAR(10) 
	);

	CREATE CLUSTERED INDEX	#CIX_tmpFilteredBettransByBatchIdx ON #tmpFilteredBettransByBatch (
			winlostdate			ASC
		,	MatchId				ASC
		,	BetType				ASC
	);

	IF	OBJECT_ID('tempdb..#tmpStagingTraderPerformance') IS NOT NULL
	BEGIN;
		DROP TABLE	#tmpStagingTraderPerformance;
	END;

	CREATE TABLE	#tmpStagingTraderPerformance (
			CustId				INT
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
		,	ExtraPT				DECIMAL(9, 8)
		,	TPositionTaking		SMALLMONEY
		,	VirtualRate			FLOAT
		,	LiveIndicator		BIT
		,   BetChoice			NVARCHAR(10) 
	);
	
	CREATE CLUSTERED INDEX #CIX_tmpStagingTraderPerformanceIdx ON #tmpStagingTraderPerformance (
			CustId				ASC
		,	EventDate			ASC
	); 

	-- Track changes on matches
	IF	OBJECT_ID('tempdb..#tmpDateToTraceChangesOnMatch') IS NOT NULL
	BEGIN;
		DROP TABLE	#tmpDateToTraceChangesOnMatch;
	END;

	CREATE TABLE	#tmpDateToTraceChangesOnMatch (
			EventDate			DATE
	);

	INSERT INTO #tmpDateToTraceChangesOnMatch (EventDate)
	VALUES(@MoveBetsDay);

	INSERT INTO #tmpDateToTraceChangesOnMatch (EventDate)
	VALUES(DATEADD(DAY, 1, @MoveBetsDay));

	INSERT INTO dbo.ChangedMatches(MatchId, EventDate, CustId, SportType, BetType, PreviousTurnover, PreviousWinloss, PreviousBetCount, CapturedDate)
	SELECT	[MatchId]		= tp.MatchId
		,	[EventDate]		= tp.EventDate
		,	[CustId]		= tp.CustId
		,	[SportType]		= tp.SportType
		,	[BetType]		= tp.BetType
		,	[Turnover]		= SUM(tp.Stake)
		,	[WinLoss]		= SUM(tp.WinLost)
		,	[BetCount]		= SUM(tp.BetCount)
		,	[CapturedDate]	= '1999-01-01'
	FROM dbo.TraderPerformance tp WITH(NOLOCK)
		INNER JOIN #tmpDateToTraceChangesOnMatch d ON tp.EventDate = d.EventDate
	GROUP BY tp.MatchId
		,	tp.EventDate
		,	tp.CustId
		,	tp.SportType
		,	tp.BetType;

	SELECT	@RowCount	= @@ROWCOUNT
		,	@Duration	= DATEDIFF(millisecond, @Begin, GETDATE())
		;

	IF	@Debug = 1
	BEGIN
		-- Force the output to appear immediately --
		RAISERROR('From TraderPerformance - Insert #ChangedMatches - %d rows - %d ms', 0, 0, @RowCount, @Duration) WITH NOWAIT;
	END;

	-- Initialize date range
	DECLARE @IsGetDataFromOrigin	BIT = 0
		,	@IsGetDataFrom14		BIT = 0
		,	@IsGetDataFromBK		BIT = 0;

	DECLARE @FromDateOrigin			SMALLDATETIME = NULL
		,	@ToDateOrigin			SMALLDATETIME = NULL
		,	@FromDate14				SMALLDATETIME = NULL
		,	@ToDate14				SMALLDATETIME = NULL
		,	@FromDateBK				SMALLDATETIME = NULL
		,	@ToDateBK				SMALLDATETIME = NULL;
	
	-- No input date range: Default job run
	IF (@GenerateFromDate IS NULL OR @GenerateToDate IS NULL)
	BEGIN
		TRUNCATE TABLE dbo.Staging_EventDate;

		SELECT @GenerateToDate = @Yesterday;

		IF @BeforeMoveBetsDay = 1
		BEGIN
			SELECT @GenerateFromDate = @BalanceUpDay;
		END
		ELSE
		BEGIN
			SELECT @GenerateFromDate = @MoveBetsDay + 1;
		END
	END;

	-- Return immediately if wrong date range
	IF @GenerateToDate < @GenerateFromDate
	BEGIN
		IF @Debug = 1
		BEGIN;
			SELECT	@Msg = 'GenerateToDate < GenerateFromDate: Unacceptable!';

			-- Force the output to appear immediately --
			RAISERROR(@Msg, 0, 0) WITH NOWAIT;
		END;

		RETURN;
	END;

	IF @GenerateFromDate < @BalanceUpDay
	BEGIN
		SELECT @IsGetDataFromBK = 1
	END
	ELSE IF @GenerateFromDate <= @MoveBetsDay
	BEGIN
		SELECT @IsGetDataFrom14 = 1
	END
	ELSE IF @GenerateFromDate > @MoveBetsDay
	BEGIN
		SELECT @IsGetDataFromOrigin = 1
	END;

	IF @GenerateToDate < @BalanceUpDay
	BEGIN
		SELECT @IsGetDataFromBK = 1
	END
	ELSE IF @GenerateToDate <= @MoveBetsDay
	BEGIN
		SELECT @IsGetDataFrom14 = 1
	END
	ELSE IF @GenerateToDate > @MoveBetsDay
	BEGIN
		SELECT @IsGetDataFromOrigin = 1
	END;

	IF @IsGetDataFromBK = 1 AND @IsGetDataFromOrigin = 1
	BEGIN
		SELECT	@FromDateOrigin = @MoveBetsDay + 1
				,	@ToDateOrigin = @GenerateToDate
				,	@FromDate14 = @BalanceUpDay
				,	@ToDate14 = @MoveBetsDay
				,	@FromDateBK = @GenerateFromDate 
				,	@ToDateBK = @BalanceUpDay - 1;
	END;

	IF @IsGetDataFromBK = 1 AND @IsGetDataFrom14 = 1 AND @IsGetDataFromOrigin = 0
	BEGIN
		SELECT	@FromDate14 = @BalanceUpDay
				,	@ToDate14 = @GenerateToDate
				,	@FromDateBK = @GenerateFromDate 
				,	@ToDateBK = @BalanceUpDay - 1;
	END;

	IF @IsGetDataFromBK = 0 AND @IsGetDataFrom14 = 1 AND @IsGetDataFromOrigin = 1
	BEGIN
		SELECT	@FromDateOrigin = @MoveBetsDay + 1
				,	@ToDateOrigin = @GenerateToDate
				,	@FromDate14 = @GenerateFromDate
				,	@ToDate14 = @MoveBetsDay
	END;

	IF @IsGetDataFromBK = 1 AND @IsGetDataFrom14 = 0 AND @IsGetDataFromOrigin = 0
	BEGIN
		SELECT	@FromDateBK = @GenerateFromDate 
				,	@ToDateBK = @GenerateToDate;
	END;

	IF @IsGetDataFromBK = 0 AND @IsGetDataFrom14 = 1 AND @IsGetDataFromOrigin = 0
	BEGIN
		SELECT	@FromDate14 = @GenerateFromDate
				,	@ToDate14 = @GenerateToDate
	END;

	IF @IsGetDataFromBK = 0 AND @IsGetDataFrom14 = 0 AND @IsGetDataFromOrigin = 1
	BEGIN
		SELECT	@FromDateOrigin = @GenerateFromDate
				,	@ToDateOrigin = @GenerateToDate
	END;

	IF @IsGetDataFromBK = 1
	BEGIN	
		TRUNCATE TABLE #tmpTrader;

		INSERT INTO	#tmpTrader (CustId, LeagueId, WorkShift, MatchId, SportType, EventDate, HomeId, AwayId, BetType, SpecialType, Matchcode, TeamId, Grade)
		SELECT	DISTINCT
				[CustId]		= a.OperatorID
			,	[LeagueId]		= m.LeagueId
			,	[WorkShift]		= CASE	WHEN CAST(m.kickofftime AS TIME) >= '00:00:00' AND CAST(m.kickofftime AS TIME) < '06:00:00'
											THEN 1 --  Afternoon: 12:00:00 ~ 17:59:59 (GMT + 8)
										WHEN CAST(m.kickofftime AS TIME) >= '06:00:00' AND CAST(m.kickofftime AS TIME) < '16:00:00'
											THEN 2 -- Night: 18:00:00 ~ 3:59:59 (GMT + 8)				
										--WHEN CAST(m.kickofftime AS TIME) >= '16:00:00' AND CAST(m.kickofftime AS TIME) <'24:00:00'THEN 3 --  Midnight: 4:00:00 ~ 11:59:59 (GMT + 8)
										ELSE 3
								  END
			,	[MatchId]		= m.MatchId
			,	[SportType]		= m.sporttype
			,	[EventDate]		= m.EventDate
			,	[HomeId]		= m.HomeId
			,	[AwayId]		= m.AwayId
			,	[BetType]		= CASE	WHEN a.bettype = 5 AND a.operatortype = 1
											THEN 1
										ELSE ISNULL(b.MainDBBetType, 0) 
								  END
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
			,	[Matchcode]		= m.Matchcode
			,	[TeamId]		= td_T.TeamId
			,	[Grade]			= td_G.Grade
		FROM		DBARC.bodb_archive.dbo.Dot_Admin_Assignment_Operator_bk AS a WITH (NOLOCK)
		INNER JOIN	DBARC.bodb_Archive.dbo.Match_bk AS m WITH (NOLOCK)
				ON	a.matchid = m.matchid
		LEFT JOIN	bodb02.dbo.Team AS t WITH (NOLOCK)
				ON	m.homeid = t.teamid
		LEFT JOIN	bodb02.dbo.League AS l WITH (NOLOCK)
				ON	m.leagueid = l.leagueid
		LEFT JOIN	dbo.BetType AS b WITH (NOLOCK)
				ON	a.bettype = b.AssignmentBetType
				AND	a.OperatorType = b.OperatorType
		LEFT JOIN	dbo.TraderGrade_History AS td_G WITH (NOLOCK)
				ON	td_G.CustID = a.OperatorID
				AND	m.EventDate BETWEEN td_G.BeginDate AND ISNULL(td_G.EndDate, GETDATE() + 10)
		LEFT JOIN	dbo.TraderTeam_History AS td_T WITH (NOLOCK)
				ON	td_T.CustID = a.OperatorID
				AND	m.EventDate BETWEEN td_T.BeginDate AND ISNULL(td_T.EndDate, GETDATE() + 10)
		WHERE	m.EventDate BETWEEN @FromDateBK AND @ToDateBK
			--AND	m.EventStatus='completed'
			AND	m.SportType = 1
			AND	a.OperatorType < 3
			AND	m.MatchCode NOT LIKE '%hedge%';
			
		SELECT	@RowCount	= @@ROWCOUNT
			,	@Duration	= DATEDIFF(millisecond, @Begin, GETDATE())
			;
			
		IF	@Debug = 1
		BEGIN;
			-- Force the output to appear immediately --
			RAISERROR('From BK - Insert #tmpTrader - %d rows - %d ms', 0, 0, @RowCount, @Duration) WITH NOWAIT;
		END;
		
		INSERT INTO	#winlostdate (winlostdate)
		SELECT	tally.winlostdate
		FROM	(
			SELECT	[NoDays] = DATEDIFF(DAY, @FromDateBK, @ToDateBK) + 1
		) cnt
		CROSS APPLY	(
			SELECT	TOP(cnt.NoDays)
					[winlostdate] = DATEADD(DAY, ROW_NUMBER() OVER(ORDER BY (SELECT NULL)) - 1, @FromDateBK)
			FROM		(VALUES (0), (0), (0), (0), (0), (0), (0), (0), (0), (0)) x10(n)
			CROSS APPLY	(VALUES (0), (0), (0), (0), (0), (0), (0), (0), (0), (0)) x100(n)
			CROSS APPLY	(VALUES (0), (0), (0), (0), (0), (0), (0), (0), (0), (0)) x1000(n)
		) tally;

		SELECT	@RowCount	= @@ROWCOUNT
			,	@Duration	= DATEDIFF(millisecond, @Begin, GETDATE())
			;
			
		IF	@Debug = 1
		BEGIN;
			-- Force the output to appear immediately --
			RAISERROR('From BK - Insert #winlostdate - %d rows - %d ms', 0, 0, @RowCount, @Duration) WITH NOWAIT;
		END;

		-- No input date range: Default job run
		IF (@GenerateFromDate IS NULL OR @GenerateToDate IS NULL)
		BEGIN;
			INSERT INTO dbo.Staging_EventDate (EventDate)
			SELECT winlostdate FROM #winlostdate

			SELECT	@RowCount	= @@ROWCOUNT
				,	@Duration	= DATEDIFF(millisecond, @Begin, GETDATE())
				;

			IF	@Debug = 1
			BEGIN;
				-- Force the output to appear immediately --
				RAISERROR('From BK - Insert Staging_EventDate - %d rows - %d ms', 0, 0, @RowCount, @Duration) WITH NOWAIT;
			END;
		END;

		------------
		WHILE	EXISTS (SELECT 1 FROM #winlostdate)
		BEGIN;
			SELECT	TOP(1)
					@WinLostDate = d.winlostdate
			FROM	#winlostdate AS d;
			
			INSERT INTO	#tmpFilteredBettransByBatch (transid, matchid, winlostdate, bettype, modds, virtualrate, tpositiontaking, srecommend, scomm, ExtraPT, Spread, Stake, WinLost, SMAWinLost, MatchCode, EventDate, SportType, LeagueId, HomeId, AwayId, LiveIndicator, BetChoice)
			SELECT	[transid]			= b.transid
				,	[matchid]			= b.matchid
				,	[winlostdate]		= b.winlostdate
				,	[bettype]			= CASE	WHEN b.bettype = 1308
													THEN 153
												WHEN b.bettype = 1311
													THEN 154
												WHEN b.bettype = 1316
													THEN 155
												ELSE b.bettype
											END
				,	[modds]				= b.modds
				,	[virtualrate]		= b.virtualrate
				,	[tpositiontaking]	= b.tpositiontaking
				,	[srecommend]		= b.srecommend
				,	[scomm]				= b.scomm
				,	[ExtraPT]			= CASE WHEN m.eventdate < '20170221' THEN 0 ELSE es.ExtraPT END
				,	[Spread]			= CASE WHEN mm.BetType IN (5, 15) THEN ISNULL(s.Spread, - (4 / mm.Spread - 4)) ELSE mm.Spread END
				,	[Stake]				= ((CASE WHEN b.modds = 0.25 OR b.modds = - 0.25 THEN ABS(b.stake) / 2 ELSE ABS(b.stake) END) * b.virtualrate)
				,	[WinLost]			= winlost - actual_stake
				,	[SMAWinLost]		= awinlost + mwinlost + swinlost
				,	[MatchCode]			= m.MatchCode
				,	[EventDate]			= m.EventDate
				,	[SportType]			= m.SportType
				,	[LeagueId]			= m.LeagueId
				,	[HomeId]			= m.HomeId
				,	[AwayId]			= m.AwayId
				,	[LiveIndicator]		= b.liveindicator
				,	[BetChoice]			= b.betteam 
			FROM		DBARC.bodb_Archive.dbo.bettrans_bk AS b WITH (NOLOCK)
			INNER JOIN	DBARC.bodb_Archive.dbo.match_bk AS m WITH (NOLOCK)
					ON	b.matchid = m.matchid
			LEFT JOIN	bodb_ACC.dbo.Acc_GroupExtraPTSetting AS es WITH (NOLOCK)
					ON	es.SuperId = b.srecommend
					AND	es.ProductId = 1
					AND	es.Sporttype = 0
					AND	es.SubProduct = ''
					AND	b.winlostdate BETWEEN es.FromDate AND es.ToDate
			LEFT JOIN	DBARC.bodb_Archive.dbo.MatchMaxbet_bk AS mm WITH (NOLOCK)
					ON	mm.MatchId = b.matchid
					AND	(	mm.BetType = b.bettype
						OR	(b.bettype = 124 AND mm.BetType = 5)
						OR	(b.bettype = 125 AND mm.BetType = 15)
						)
			LEFT JOIN	#Spread1x2 AS s
					ON	mm.Spread = s.Margin
					AND	mm.BetType IN (5, 15)
			WHERE	b.winlostdate = @winlostdate
				AND	b.statusID IN (112, 113)
				AND	b.Currency NOT IN (20, 27, 28)
				AND	m.sporttype = 1
				AND	m.MatchCode NOT LIKE '%hedge%';
					
			SELECT	@RowCount	= @@ROWCOUNT
				,	@Duration	= DATEDIFF(millisecond, @Begin, GETDATE())
				;
			
			IF	@Debug = 1
			BEGIN;
				-- Force the output to appear immediately --
				RAISERROR('From BK - Insert #tmpFilteredBettransByBatch - %d rows - %d ms', 0, 0, @RowCount, @Duration) WITH NOWAIT;
			END;
			
			INSERT INTO	#tmpStagingTraderPerformance (CustId, WorkShift, MatchId, MatchCode, EventDate, SportType, LeagueId, HomeId, AwayId, TeamId, Grade, BetType, Stake, WinLost, SMAWinLost, Comm, BetCount, Spread, ExtraPT, TPositionTaking, VirtualRate, LiveIndicator, BetChoice)
			SELECT	[CustId]			= ISNULL(t.Custid, @IdForUnassignedTrader)
				,	[WorkShift]			= ISNULL(t.WorkShift, 1)
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
				,	[Stake]				= b.Stake --turn over
				,	[WinLost]			= b.WinLost
				,	[SMAWinLost]		= b.SMAWinLost
				,	[Comm]				= scomm --Commission
				,	[BetCount]			= 1 --Live BetCount
				,	[Spread]			= b.Spread
				,	[ExtraPT]			= SUM(ISNULL(b.ExtraPT, 0))
				,	[TPositionTaking]	= b.tpositiontaking
				,	[VirtualRate]		= b.virtualrate
				,	[LiveIndicator]		= b.LiveIndicator
				,	[BetChoice]			= b.BetChoice
			FROM		#tmpFilteredBettransByBatch AS b WITH (NOLOCK)
			LEFT JOIN	#tmpTrader AS t WITH (NOLOCK)
					ON	b.winlostdate = t.EventDate
					AND	b.matchid = t.matchid
					AND	(	b.BetType = t.BetType
						OR	(b.bettype = 124 AND t.BetType = 5)
						OR	(b.bettype = 125 AND t.BetType = 15)
						OR	(b.bettype = 23 AND t.BetType = 1)
						)
			CROSS APPLY	(
				SELECT	[BetType]	= CASE	WHEN b.BetType = 1 AND SpecialType = 0
												THEN 1 --HDP
											WHEN b.BetType = 7
												THEN 7 --1st HDP
											WHEN b.BetType = 3 AND SpecialType = 0
												THEN 3 --O/U		
											WHEN b.BetType = 8 AND SpecialType = 0
												THEN 8 --1st O/U
											WHEN b.BetType = 2
												THEN 2 --O/E
											WHEN b.BetType = 12
												THEN 12 --1x2
											WHEN b.BetType IN (5, 124) AND SpecialType = 0
												THEN 5 --1x2		
											WHEN b.BetType IN (5, 124) AND SpecialType = 5
												THEN - 14 --10mins 1x2
											WHEN b.BetType IN (15, 125) AND SpecialType = 0
												THEN 15 --1st 1x2
											WHEN b.BetType = 1 AND SpecialType = 4
												THEN - 1 --15mins HDP
											WHEN (b.bettype = 23 AND t.BetType = 1) OR (b.BetType = 1 AND SpecialType = 8)
												THEN - 2 --Next Corner
											WHEN b.BetType = 1 AND SpecialType = 5
												THEN - 15 --10mins HDP
											WHEN b.BetType = 1 AND SpecialType = 9
												THEN - 3 --Next Booking
											WHEN b.BetType IN (5, 124) AND SpecialType = 4
												THEN - 4 --15mins 1X2
											WHEN b.BetType = 3 AND SpecialType = 4
												THEN - 5 --15mins O/U
											WHEN b.BetType = 3 AND SpecialType = 5
												THEN - 6 --10mins O/U
											WHEN b.BetType = 3 AND SpecialType = 2
												THEN - 7 --Corners 15mins O/U
											WHEN b.BetType = 3 AND SpecialType = 7
												THEN - 8 --Total Bookings
											WHEN b.BetType = 3 AND SpecialType = 1
												THEN - 10 --Total Bookings 15mins O/U
											WHEN b.BetType = 3 AND SpecialType = 6
												THEN - 13 --No. of Corner
											WHEN b.BetType = 8 AND SpecialType = 6
												THEN - 12 --1st No. of Corner
											WHEN b.BetType = 8 AND SpecialType = 7
												THEN - 9 --1st TotalBookings
											WHEN (b.BetType = 3 OR b.BetType = 8) AND SpecialType = 3
												THEN - 11 --Single Team O/U
											WHEN b.BetType IN (5, 124)
												THEN 5 --1x2	
											WHEN b.BetType IN (15, 125)
												THEN 15 --1st 1x2
											ELSE b.BetType
									  END
			) AS ca
			WHERE	b.winlostdate = @winlostdate
			GROUP BY	ISNULL(t.Custid, @IdForUnassignedTrader)
					,	ISNULL(t.WorkShift, 1)
					,	b.MatchId
					,	b.MatchCode
					,	b.EventDate
					,	b.SportType
					,	b.LeagueId
					,	b.HomeId
					,	b.AwayId
					,	t.TeamId
					,	t.Grade
					,	ca.BetType
					,	b.Stake
					,	b.WinLost
					,	b.SMAWinLost
					,	scomm
					,	b.Spread
					,	b.tpositiontaking
					,	b.virtualrate
					,	b.transid
					,	b.LiveIndicator
					,	b.BetChoice
					;
					
			SELECT	@RowCount	= @@ROWCOUNT
				,	@Duration	= DATEDIFF(millisecond, @Begin, GETDATE())
				;

			IF	@Debug = 1
			BEGIN;
				-- Force the output to appear immediately --
				RAISERROR('From BK - Insert #tmpStagingTraderPerformance - %d rows - %d ms', 0, 0, @RowCount, @Duration) WITH NOWAIT;
			END;
	
			DELETE [dbo].[TraderPerformance] WHERE EventDate = @winlostdate

			INSERT INTO	dbo.TraderPerformance (CustId, WorkShift, MatchId, MatchCode, EventDate, SportType, LeagueId, HomeId, AwayId, TeamId, Grade, BetType, IsLive, Stake, WinLost, Comm, BetCount, Spread)
			SELECT	[CustId]			= t.CustId
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
				,	[Stake]				= SUM(t.Stake * (1 - t.TPositionTaking - t.ExtraPT))
				,	[WinLost]			= SUM(((-(t.WinLost + t.SMAWinLost)) + t.WinLost * t.ExtraPT) * t.virtualrate)
				,	[Comm]				= SUM((Comm - (CASE WHEN t.TPositionTaking = 1 THEN 0 ELSE (Comm * t.ExtraPT/(1 - t.TPositionTaking)) END)) * t.virtualrate)
				,	[BetCount]			= SUM(t.BetCount)
				,	[Spread]			= MAX(t.Spread)
			FROM	#tmpStagingTraderPerformance AS t WHERE	t.EventDate = @winlostdate
			GROUP BY t.CustId, t.WorkShift, t.MatchId, t.MatchCode, t.EventDate, t.SportType, t.LeagueId, t.HomeId, t.AwayId, t.TeamId, t.Grade, t.BetType, t.LiveIndicator;
				
			SELECT	@RowCount	= @@ROWCOUNT
				,	@Duration	= DATEDIFF(millisecond, @Begin, GETDATE())
				;

			IF	@Debug = 1
			BEGIN;
				-- Force the output to appear immediately --
				RAISERROR('From BK - Insert TraderPerformance - %d rows - %d ms', 0, 0, @RowCount, @Duration) WITH NOWAIT;
			END;
			
			DELETE [dbo].[TraderPerformance_BetChoice]	WHERE EventDate = @winlostdate

			INSERT INTO	dbo.[TraderPerformance_BetChoice] (CustId, MatchId, EventDate, SportType, LeagueId, BetType, BetChoice, IsLive, Stake, WinLost, Comm, BetCount)
			SELECT	[CustId]			= t.CustId
				,	[MatchId]			= t.MatchId
				,	[EventDate]			= t.EventDate
				,	[SportType]			= t.SportType
				,	[LeagueId]			= t.LeagueId
				,	[BetType]			= t.BetType
				,	[BetChoice]			= t.BetChoice
				,	[IsLive]			= t.LiveIndicator
				,	[Stake]				= SUM(t.Stake * (1 - t.TPositionTaking - t.ExtraPT))
				,	[WinLost]			= SUM(((-(t.WinLost + t.SMAWinLost)) + t.WinLost * t.ExtraPT) * t.virtualrate)
				,	[Comm]				= SUM((Comm - (CASE WHEN t.TPositionTaking = 1 THEN 0 ELSE (Comm * t.ExtraPT/(1 - t.TPositionTaking)) END)) * t.virtualrate)
				,	[BetCount]			= SUM(t.BetCount)
			FROM	#tmpStagingTraderPerformance AS t WHERE t.EventDate = @winlostdate and t.BetChoice IS NOT NULL
			GROUP BY t.CustId, t.MatchId, t.EventDate, t.SportType, t.LeagueId, t.BetType, t.BetChoice, t.LiveIndicator;
				
			SELECT	@RowCount	= @@ROWCOUNT
				,	@Duration	= DATEDIFF(millisecond, @Begin, GETDATE())
				;

			IF	@Debug = 1
			BEGIN;
				-- Force the output to appear immediately --
				RAISERROR('From BK - Insert TraderPerformance_BetChoice - %d rows - %d ms', 0, 0, @RowCount, @Duration) WITH NOWAIT;
			END;

			DELETE	d
			FROM	#winlostdate AS d
			WHERE	d.winlostdate = @winlostdate;
				
			SELECT	@RowCount	= @@ROWCOUNT
				,	@Duration	= DATEDIFF(millisecond, @Begin, GETDATE())
				;
			
			IF	@Debug = 1
			BEGIN;
				-- Force the output to appear immediately --
				PRINT	@WinLostDate
				RAISERROR('From BK - DELETE #winlostdate - %d rows - %d ms', 0, 0, @RowCount, @Duration) WITH NOWAIT;
			END;

			TRUNCATE TABLE #tmpStagingTraderPerformance;
			TRUNCATE TABLE #tmpFilteredBettransByBatch;
		END;
	END;

	IF	@IsGetDataFrom14 = 1
	BEGIN
		TRUNCATE TABLE #tmpTrader;

		INSERT INTO	#tmpTrader (CustId, LeagueId, WorkShift, MatchId, SportType, EventDate, HomeId, AwayId, BetType, SpecialType, Matchcode, TeamId, Grade)
		SELECT	DISTINCT
				[CustId]		= a.OperatorID
			,	[LeagueId]		= m.LeagueId
			,	[WorkShift]		= CASE	WHEN CAST(m.kickofftime AS TIME) >= '00:00:00' AND CAST(m.kickofftime AS TIME) < '06:00:00'
											THEN 1 --  Afternoon: 12:00:00 ~ 17:59:59 (GMT + 8)
										WHEN CAST(m.kickofftime AS TIME) >= '06:00:00' AND CAST(m.kickofftime AS TIME) < '16:00:00'
											THEN 2 -- Night: 18:00:00 ~ 3:59:59 (GMT + 8)				
										--WHEN CAST(m.kickofftime AS TIME) >= '16:00:00' AND CAST(m.kickofftime AS TIME) <'24:00:00'THEN 3 --  Midnight: 4:00:00 ~ 11:59:59 (GMT + 8)
										ELSE 3
								  END
			,	[MatchId]		= m.MatchId
			,	[SportType]		= m.sporttype
			,	[EventDate]		= m.EventDate
			,	[HomeId]		= m.HomeId
			,	[AwayId]		= m.AwayId
			,	[BetType]		= CASE	WHEN a.bettype = 5 AND a.operatortype = 1
											THEN 1
										ELSE ISNULL(b.MainDBBetType, 0) 
								  END
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
			,	[Matchcode]		= m.Matchcode
			,	[TeamId]		= td_T.TeamId
			,	[Grade]			= td_G.Grade
		FROM		DBARC.bodb_archive.dbo.Dot_Admin_Assignment_Operator_bk AS a WITH (NOLOCK)
		INNER JOIN	bodb02.dbo.Match14 AS m WITH (NOLOCK)
				ON	a.matchid = m.matchid
		LEFT JOIN	bodb02.dbo.Team AS t WITH (NOLOCK)
				ON	m.homeid = t.teamid
		LEFT JOIN	bodb02.dbo.League AS l WITH (NOLOCK)
				ON	m.leagueid = l.leagueid
		LEFT JOIN	dbo.BetType AS b WITH (NOLOCK)
				ON	a.bettype = b.AssignmentBetType
				AND	a.OperatorType = b.OperatorType
		LEFT JOIN	dbo.TraderGrade_History AS td_G WITH (NOLOCK)
				ON	td_G.CustID = a.OperatorID
				AND	m.EventDate BETWEEN td_G.BeginDate AND ISNULL(td_G.EndDate, GETDATE() + 10)
		LEFT JOIN	dbo.TraderTeam_History AS td_T WITH (NOLOCK)
				ON	td_T.CustID = a.OperatorID
				AND	m.EventDate BETWEEN td_T.BeginDate AND ISNULL(td_T.EndDate, GETDATE() + 10)
		WHERE	m.EventDate BETWEEN @FromDate14 AND @ToDate14
			--AND	m.EventStatus='completed'
			AND	m.SportType = 1
			AND	a.OperatorType < 3
			AND	m.MatchCode NOT LIKE '%hedge%';
			
		SELECT	@RowCount	= @@ROWCOUNT
			,	@Duration	= DATEDIFF(millisecond, @Begin, GETDATE())
			;
			
		IF	@Debug = 1
		BEGIN;
			-- Force the output to appear immediately --
			RAISERROR('From 14 - Insert #tmpTrader - %d rows - %d ms', 0, 0, @RowCount, @Duration) WITH NOWAIT;
		END;
		
		INSERT INTO	#winlostdate (winlostdate)
		SELECT	tally.winlostdate
		FROM	(
			SELECT	[NoDays] = DATEDIFF(DAY, @FromDate14, @ToDate14) + 1
		) cnt
		CROSS APPLY	(
			SELECT	TOP(cnt.NoDays)
					[winlostdate] = DATEADD(DAY, ROW_NUMBER() OVER(ORDER BY (SELECT NULL)) - 1, @FromDate14)
			FROM		(VALUES (0), (0), (0), (0), (0), (0), (0), (0), (0), (0)) x10(n)
			CROSS APPLY	(VALUES (0), (0), (0), (0), (0), (0), (0), (0), (0), (0)) x100(n)
			CROSS APPLY	(VALUES (0), (0), (0), (0), (0), (0), (0), (0), (0), (0)) x1000(n)
		) tally;

		SELECT	@RowCount	= @@ROWCOUNT
			,	@Duration	= DATEDIFF(millisecond, @Begin, GETDATE())
			;
			
		IF	@Debug = 1
		BEGIN;
			-- Force the output to appear immediately --
			RAISERROR('From 14 - Insert #winlostdate - %d rows - %d ms', 0, 0, @RowCount, @Duration) WITH NOWAIT;
		END;

		-- No input date range: Default job run
		IF (@GenerateFromDate IS NULL OR @GenerateToDate IS NULL)
		BEGIN;
			INSERT INTO dbo.Staging_EventDate (EventDate)
			SELECT winlostdate FROM #winlostdate

			SELECT	@RowCount	= @@ROWCOUNT
				,	@Duration	= DATEDIFF(millisecond, @Begin, GETDATE())
				;

			IF	@Debug = 1
			BEGIN;
				-- Force the output to appear immediately --
				RAISERROR('From 14 - Insert Staging_EventDate - %d rows - %d ms', 0, 0, @RowCount, @Duration) WITH NOWAIT;
			END;
		END;

		------------
		WHILE	EXISTS (SELECT 1 FROM #winlostdate)
		BEGIN;
			SELECT	TOP(1)
					@WinLostDate = d.winlostdate
			FROM	#winlostdate AS d;
			
			INSERT INTO	#tmpFilteredBettransByBatch (transid, matchid, winlostdate, bettype, modds, virtualrate, tpositiontaking, srecommend, scomm, ExtraPT, Spread, Stake, WinLost, SMAWinLost, MatchCode, EventDate, SportType, LeagueId, HomeId, AwayId, LiveIndicator, BetChoice)
			SELECT	[transid]			= b.transid
				,	[matchid]			= b.matchid
				,	[winlostdate]		= b.winlostdate
				,	[bettype]			= CASE	WHEN b.bettype = 1308
													THEN 153
												WHEN b.bettype = 1311
													THEN 154
												WHEN b.bettype = 1316
													THEN 155
												ELSE b.bettype
											END
				,	[modds]				= b.modds
				,	[virtualrate]		= b.virtualrate
				,	[tpositiontaking]	= b.tpositiontaking
				,	[srecommend]		= b.srecommend
				,	[scomm]				= b.scomm
				,	[ExtraPT]			= es.ExtraPT
				,	[Spread]			= CASE WHEN mm.BetType IN (5, 15) THEN ISNULL(s.Spread, - (4 / mm.Spread - 4)) ELSE mm.Spread END
				,	[Stake]				= ((CASE WHEN b.modds = 0.25 OR b.modds = - 0.25 THEN ABS(b.stake) / 2 ELSE ABS(b.stake) END) * b.virtualrate)
				,	[WinLost]			= winlost - actual_stake
				,	[SMAWinLost]		= awinlost + mwinlost + swinlost
				,	[MatchCode]			= m.MatchCode
				,	[EventDate]			= m.EventDate
				,	[SportType]			= m.SportType
				,	[LeagueId]			= m.LeagueId
				,	[HomeId]			= m.HomeId
				,	[AwayId]			= m.AwayId
				,	[LiveIndicator]		= b.liveindicator
				,	[BetChoice]			= b.betteam
			FROM		bodb02.dbo.bettrans14 AS b WITH (NOLOCK)
			INNER JOIN	bodb02.dbo.match14 AS m WITH (NOLOCK)
					ON	b.matchid = m.matchid
			LEFT JOIN	bodb_ACC.dbo.Acc_GroupExtraPTSetting AS es WITH (NOLOCK)
					ON	es.SuperId = b.srecommend
					AND	es.ProductId = 1
					AND	es.Sporttype = 0
					AND	es.SubProduct = ''
					AND	b.winlostdate BETWEEN es.FromDate AND es.ToDate
			LEFT JOIN	bodb02.dbo.MatchMaxbet14 AS mm WITH (NOLOCK)
					ON	mm.MatchId = b.matchid
					AND	(	mm.BetType = b.bettype
						OR	(b.bettype = 124 AND mm.BetType = 5)
						OR	(b.bettype = 125 AND mm.BetType = 15)
						)
			LEFT JOIN	#Spread1x2 AS s
					ON	mm.Spread = s.Margin
					AND	mm.BetType IN (5, 15)
			WHERE	b.winlostdate = @winlostdate
				AND	b.statusID IN (112, 113)
				AND	b.Currency NOT IN (20, 27, 28)
				AND	m.sporttype = 1
				AND	m.MatchCode NOT LIKE '%hedge%';
					
			SELECT	@RowCount	= @@ROWCOUNT
				,	@Duration	= DATEDIFF(millisecond, @Begin, GETDATE())
				;
			
			IF	@Debug = 1
			BEGIN;
				-- Force the output to appear immediately --
				RAISERROR('From 14 - Insert #tmpFilteredBettransByBatch - %d rows - %d ms', 0, 0, @RowCount, @Duration) WITH NOWAIT;
			END;
			
			INSERT INTO	#tmpStagingTraderPerformance (CustId, WorkShift, MatchId, MatchCode, EventDate, SportType, LeagueId, HomeId, AwayId, TeamId, Grade, BetType, Stake, WinLost, SMAWinLost, Comm, BetCount, Spread, ExtraPT, TPositionTaking, VirtualRate, LiveIndicator, BetChoice)
			SELECT	[CustId]			= ISNULL(t.Custid, @IdForUnassignedTrader)
				,	[WorkShift]			= ISNULL(t.WorkShift, 1)
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
				,	[Stake]				= b.Stake --turn over
				,	[WinLost]			= b.WinLost
				,	[SMAWinLost]		= b.SMAWinLost
				,	[Comm]				= scomm --Commission
				,	[BetCount]			= 1 --Live BetCount
				,	[Spread]			= b.Spread
				,	[ExtraPT]			= SUM(ISNULL(b.ExtraPT, 0))
				,	[TPositionTaking]	= b.tpositiontaking
				,	[VirtualRate]		= b.virtualrate
				,	[LiveIndicator]		= b.LiveIndicator
				,	[BetChoice]			= b.BetChoice
			FROM		#tmpFilteredBettransByBatch AS b WITH (NOLOCK)
			LEFT JOIN	#tmpTrader AS t WITH (NOLOCK)
					ON	b.winlostdate = t.EventDate
					AND	b.matchid = t.matchid
					AND	(	b.BetType = t.BetType
						OR	(b.bettype = 124 AND t.BetType = 5)
						OR	(b.bettype = 125 AND t.BetType = 15)
						OR	(b.bettype = 23 AND t.BetType = 1)
						)
			CROSS APPLY	(
				SELECT	[BetType]	= CASE	WHEN b.BetType = 1 AND SpecialType = 0
												THEN 1 --HDP
											WHEN b.BetType = 7
												THEN 7 --1st HDP
											WHEN b.BetType = 3 AND SpecialType = 0
												THEN 3 --O/U		
											WHEN b.BetType = 8 AND SpecialType = 0
												THEN 8 --1st O/U
											WHEN b.BetType = 2
												THEN 2 --O/E
											WHEN b.BetType = 12
												THEN 12 --1x2
											WHEN b.BetType IN (5, 124) AND SpecialType = 0
												THEN 5 --1x2		
											WHEN b.BetType IN (5, 124) AND SpecialType = 5
												THEN - 14 --10mins 1x2
											WHEN b.BetType IN (15, 125) AND SpecialType = 0
												THEN 15 --1st 1x2
											WHEN b.BetType = 1 AND SpecialType = 4
												THEN - 1 --15mins HDP
											WHEN (b.bettype = 23 AND t.BetType = 1) OR (b.BetType = 1 AND SpecialType = 8)
												THEN - 2 --Next Corner
											WHEN b.BetType = 1 AND SpecialType = 5
												THEN - 15 --10mins HDP
											WHEN b.BetType = 1 AND SpecialType = 9
												THEN - 3 --Next Booking
											WHEN b.BetType IN (5, 124) AND SpecialType = 4
												THEN - 4 --15mins 1X2
											WHEN b.BetType = 3 AND SpecialType = 4
												THEN - 5 --15mins O/U
											WHEN b.BetType = 3 AND SpecialType = 5
												THEN - 6 --10mins O/U
											WHEN b.BetType = 3 AND SpecialType = 2
												THEN - 7 --Corners 15mins O/U
											WHEN b.BetType = 3 AND SpecialType = 7
												THEN - 8 --Total Bookings
											WHEN b.BetType = 3 AND SpecialType = 1
												THEN - 10 --Total Bookings 15mins O/U
											WHEN b.BetType = 3 AND SpecialType = 6
												THEN - 13 --No. of Corner
											WHEN b.BetType = 8 AND SpecialType = 6
												THEN - 12 --1st No. of Corner
											WHEN b.BetType = 8 AND SpecialType = 7
												THEN - 9 --1st TotalBookings
											WHEN (b.BetType = 3 OR b.BetType = 8) AND SpecialType = 3
												THEN - 11 --Single Team O/U
											WHEN b.BetType IN (5, 124)
												THEN 5 --1x2	
											WHEN b.BetType IN (15, 125)
												THEN 15 --1st 1x2
											ELSE b.BetType
									  END
			) AS ca
			WHERE	b.winlostdate = @winlostdate
			GROUP BY	ISNULL(t.Custid, @IdForUnassignedTrader)
					,	ISNULL(t.WorkShift, 1)
					,	b.MatchId
					,	b.MatchCode
					,	b.EventDate
					,	b.SportType
					,	b.LeagueId
					,	b.HomeId
					,	b.AwayId
					,	t.TeamId
					,	t.Grade
					,	ca.BetType
					,	b.Stake
					,	b.WinLost
					,	b.SMAWinLost
					,	scomm
					,	b.Spread
					,	b.tpositiontaking
					,	b.virtualrate
					,	b.transid
					,	b.LiveIndicator
					,	b.BetChoice
					;
					
			SELECT	@RowCount	= @@ROWCOUNT
				,	@Duration	= DATEDIFF(millisecond, @Begin, GETDATE())
				;

			IF	@Debug = 1
			BEGIN;
				-- Force the output to appear immediately --
				RAISERROR('From 14 - Insert #tmpStagingTraderPerformance - %d rows - %d ms', 0, 0, @RowCount, @Duration) WITH NOWAIT;
			END;

			DELETE [dbo].[TraderPerformance] WHERE EventDate = @winlostdate

			INSERT INTO	dbo.TraderPerformance (CustId, WorkShift, MatchId, MatchCode, EventDate, SportType, LeagueId, HomeId, AwayId, TeamId, Grade, BetType, IsLive, Stake, WinLost, Comm, BetCount, Spread)
			SELECT	[CustId]			= t.CustId
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
				,	[Stake]				= SUM(t.Stake * (1 - t.TPositionTaking - t.ExtraPT))
				,	[WinLost]			= SUM(((-(t.WinLost + t.SMAWinLost)) + t.WinLost * t.ExtraPT) * t.virtualrate)
				,	[Comm]				= SUM((Comm - (CASE WHEN t.TPositionTaking = 1 THEN 0 ELSE (Comm * t.ExtraPT/(1 - t.TPositionTaking)) END)) * t.virtualrate)
				,	[BetCount]			= SUM(t.BetCount)
				,	[Spread]			= MAX(t.Spread)
			FROM	#tmpStagingTraderPerformance AS t WHERE	t.EventDate = @winlostdate
			GROUP BY t.CustId, t.WorkShift, t.MatchId, t.MatchCode, t.EventDate, t.SportType, t.LeagueId, t.HomeId, t.AwayId, t.TeamId, t.Grade, t.BetType, t.LiveIndicator;
				
			SELECT	@RowCount	= @@ROWCOUNT
				,	@Duration	= DATEDIFF(millisecond, @Begin, GETDATE())
				;

			IF	@Debug = 1
			BEGIN;
				-- Force the output to appear immediately --
				RAISERROR('From 14 - Insert TraderPerformance - %d rows - %d ms', 0, 0, @RowCount, @Duration) WITH NOWAIT;
			END;
			
			DELETE [dbo].[TraderPerformance_BetChoice]	WHERE EventDate = @winlostdate

			INSERT INTO	dbo.[TraderPerformance_BetChoice] (CustId, MatchId, EventDate, SportType, LeagueId, BetType, BetChoice, IsLive, Stake, WinLost, Comm, BetCount)
			SELECT	[CustId]			= t.CustId
				,	[MatchId]			= t.MatchId
				,	[EventDate]			= t.EventDate
				,	[SportType]			= t.SportType
				,	[LeagueId]			= t.LeagueId
				,	[BetType]			= t.BetType
				,	[BetChoice]			= t.BetChoice
				,	[IsLive]			= t.LiveIndicator
				,	[Stake]				= SUM(t.Stake * (1 - t.TPositionTaking - t.ExtraPT))
				,	[WinLost]			= SUM(((-(t.WinLost + t.SMAWinLost)) + t.WinLost * t.ExtraPT) * t.virtualrate)
				,	[Comm]				= SUM((Comm - (CASE WHEN t.TPositionTaking = 1 THEN 0 ELSE (Comm * t.ExtraPT/(1 - t.TPositionTaking)) END)) * t.virtualrate)
				,	[BetCount]			= SUM(t.BetCount)
			FROM	#tmpStagingTraderPerformance AS t WHERE t.EventDate = @winlostdate and t.BetChoice IS NOT NULL
			GROUP BY t.CustId, t.MatchId, t.EventDate, t.SportType, t.LeagueId, t.BetType, t.BetChoice, t.LiveIndicator;
				
			SELECT	@RowCount	= @@ROWCOUNT
				,	@Duration	= DATEDIFF(millisecond, @Begin, GETDATE())
				;

			IF	@Debug = 1
			BEGIN;
				-- Force the output to appear immediately --
				RAISERROR('From 14 - Insert TraderPerformance_BetChoice - %d rows - %d ms', 0, 0, @RowCount, @Duration) WITH NOWAIT;
			END;

			DELETE	d
			FROM	#winlostdate AS d
			WHERE	d.winlostdate = @winlostdate;
				
			SELECT	@RowCount	= @@ROWCOUNT
				,	@Duration	= DATEDIFF(millisecond, @Begin, GETDATE())
				;
			
			IF	@Debug = 1
			BEGIN;
				-- Force the output to appear immediately --
				PRINT	@WinLostDate
				RAISERROR('From 14 - DELETE #winlostdate - %d rows - %d ms', 0, 0, @RowCount, @Duration) WITH NOWAIT;
			END;

			TRUNCATE TABLE #tmpStagingTraderPerformance;
			TRUNCATE TABLE #tmpFilteredBettransByBatch;
		END
	END
	
	IF	@IsGetDataFromOrigin = 1
	BEGIN
		TRUNCATE TABLE #tmpTrader;

		INSERT INTO	#tmpTrader (CustId, LeagueId, WorkShift, MatchId, SportType, EventDate, HomeId, AwayId, BetType, SpecialType, Matchcode, TeamId, Grade)
		SELECT	DISTINCT
				[CustId]		= a.OperatorID
			,	[LeagueId]		= m.LeagueId
			,	[WorkShift]		= CASE	WHEN CAST(m.kickofftime AS TIME) >= '00:00:00' AND CAST(m.kickofftime AS TIME) < '06:00:00'
											THEN 1 --  Afternoon: 12:00:00 ~ 17:59:59 (GMT + 8)
										WHEN CAST(m.kickofftime AS TIME) >= '06:00:00' AND CAST(m.kickofftime AS TIME) < '16:00:00'
											THEN 2 -- Night: 18:00:00 ~ 3:59:59 (GMT + 8)				
										--WHEN CAST(m.kickofftime AS TIME) >= '16:00:00' AND CAST(m.kickofftime AS TIME) <'24:00:00'THEN 3 --  Midnight: 4:00:00 ~ 11:59:59 (GMT + 8)
										ELSE 3
									END
			,	[MatchId]		= m.MatchId
			,	[SportType]		= m.sporttype
			,	[EventDate]		= m.EventDate
			,	[HomeId]		= m.HomeId
			,	[AwayId]		= m.AwayId
			,	[BetType]		= CASE	WHEN a.bettype = 5 AND a.operatortype = 1
											THEN 1
										ELSE ISNULL(b.MainDBBetType, 0) 
									END
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
			,	[Matchcode]		= m.Matchcode
			,	[TeamId]		= td_T.TeamId
			,	[Grade]			= td_G.Grade
		FROM		bodb02.dbo.Dot_admin_Assignment_Operator AS a WITH (NOLOCK)
		INNER JOIN	bodb02.dbo.Match AS m WITH (NOLOCK)
				ON	a.matchid = m.matchid
		LEFT JOIN	bodb02.dbo.Team AS t WITH (NOLOCK)
				ON	m.homeid = t.teamid
		LEFT JOIN	bodb02.dbo.League AS l WITH (NOLOCK)
				ON	m.leagueid = l.leagueid
		LEFT JOIN	dbo.BetType AS b WITH(NOLOCK)
				ON	a.bettype = b.AssignmentBetType
				AND	a.OperatorType = b.OperatorType
		LEFT JOIN	dbo.TraderGrade_History AS td_G WITH (NOLOCK)
				ON	td_G.CustID = a.OperatorID
				AND	m.EventDate BETWEEN td_G.BeginDate AND ISNULL(td_G.EndDate, GETDATE() + 10)
		LEFT JOIN	dbo.TraderTeam_History AS td_T WITH (NOLOCK)
				ON	td_T.CustID = a.OperatorID
				AND	m.EventDate BETWEEN td_T.BeginDate AND ISNULL(td_T.EndDate, GETDATE() + 10)
		WHERE	m.EventDate BETWEEN @FromDateOrigin AND @ToDateOrigin
			AND	m.EventStatus = 'completed'
			AND	m.SportType = 1
			AND	a.OperatorType < 3
			AND	m.MatchCode NOT LIKE '%hedge%';
		
		SELECT	@RowCount	= @@ROWCOUNT
			,	@Duration	= DATEDIFF(millisecond, @Begin, GETDATE())
			;

		IF	@Debug = 1
		BEGIN;
			-- Force the output to appear immediately --
			RAISERROR('From Origin - Insert #tmpTrader - %d rows - %d ms', 0, 0, @RowCount, @Duration) WITH NOWAIT;
		END;
	
		INSERT INTO	#winlostdate (winlostdate)
		SELECT	tally.winlostdate
		FROM	(
			SELECT	[NoDays] = DATEDIFF(DAY, @FromDateOrigin, @ToDateOrigin) + 1
		) cnt
		CROSS APPLY	(
			SELECT	TOP(cnt.NoDays)
					[winlostdate] = DATEADD(DAY, ROW_NUMBER() OVER(ORDER BY (SELECT NULL)) - 1, @FromDateOrigin)
			FROM		(VALUES (0), (0), (0), (0), (0), (0), (0), (0), (0), (0)) x10(n)
			CROSS APPLY	(VALUES (0), (0), (0), (0), (0), (0), (0), (0), (0), (0)) x100(n)
			CROSS APPLY	(VALUES (0), (0), (0), (0), (0), (0), (0), (0), (0), (0)) x1000(n)
		) tally;

		SELECT	@RowCount	= @@ROWCOUNT
			,	@Duration	= DATEDIFF(millisecond, @Begin, GETDATE())
			;

		IF	@Debug = 1
		BEGIN;
			-- Force the output to appear immediately --
			RAISERROR('From Origin - Insert #winlostdate - %d rows - %d ms', 0, 0, @RowCount, @Duration) WITH NOWAIT;
		END;

		-- No input date range: Default job run
		IF (@GenerateFromDate IS NULL OR @GenerateToDate IS NULL)
		BEGIN;
			INSERT INTO dbo.Staging_EventDate (EventDate)
			SELECT winlostdate FROM #winlostdate

			SELECT	@RowCount	= @@ROWCOUNT
				,	@Duration	= DATEDIFF(millisecond, @Begin, GETDATE())
				;

			IF	@Debug = 1
			BEGIN;
				-- Force the output to appear immediately --
				RAISERROR('From Origin - Insert Staging_EventDate - %d rows - %d ms', 0, 0, @RowCount, @Duration) WITH NOWAIT;
			END;
		END;

		WHILE	EXISTS (SELECT 1 FROM #winlostdate)
		BEGIN;
			SELECT	TOP(1)
					@WinLostDate = d.winlostdate
			FROM	#winlostdate AS d;
			
			TRUNCATE TABLE	#tmpFilteredBettransByBatch;
			INSERT INTO	#tmpFilteredBettransByBatch (transid, matchid, winlostdate, bettype, modds, virtualrate, tpositiontaking, srecommend, scomm, ExtraPT, Spread, Stake, WinLost, SMAWinLost, MatchCode, EventDate, SportType, LeagueId, HomeId, AwayId, LiveIndicator, BetChoice)
			SELECT	[transid]			= b.transid
				,	[matchid]			= b.matchid
				,	[winlostdate]		= b.winlostdate
				,	[bettype]			= CASE	WHEN b.bettype = 1308
													THEN 153
												WHEN b.bettype = 1311
													THEN 154
												WHEN b.bettype = 1316
													THEN 155
												ELSE b.bettype
											END
				,	[modds]				= b.modds
				,	[virtualrate]		= b.virtualrate
				,	[tpositiontaking]	= b.tpositiontaking
				,	[srecommend]		= b.srecommend
				,	[scomm]				= b.scomm
				,	[ExtraPT]			= es.ExtraPT
				,	[Spread]			= CASE WHEN mm.BetType IN (5, 15) THEN ISNULL(s.Spread, - (4 / mm.Spread - 4)) ELSE mm.Spread END
				,	[Stake]				= ((CASE WHEN b.modds = 0.25 OR b.modds = - 0.25 THEN ABS(b.stake) / 2 ELSE ABS(b.stake) END) * b.virtualrate)
				,	[WinLost]			= winlost - actual_stake
				,	[SMAWinLost]		= awinlost + mwinlost + swinlost
				,	[MatchCode]			= m.MatchCode
				,	[EventDate]			= m.EventDate
				,	[SportType]			= m.SportType
				,	[LeagueId]			= m.LeagueId
				,	[HomeId]			= m.HomeId
				,	[AwayId]			= m.AwayId
				,	[LiveIndicator]		= b.liveindicator
				,	[BetChoice]			= b.betteam
			FROM		bodb02.dbo.bettrans AS b WITH (NOLOCK)
			INNER JOIN	bodb02.dbo.match AS m WITH (NOLOCK)
					ON	b.matchid = m.matchid
			LEFT JOIN	bodb_ACC.dbo.Acc_GroupExtraPTSetting AS es WITH (NOLOCK)
					ON	es.SuperId = b.srecommend
					AND	es.ProductId = 1
					AND	es.Sporttype = 0
					AND	es.SubProduct = ''
					AND	b.winlostdate BETWEEN es.FromDate AND es.ToDate
			LEFT JOIN	bodb02.dbo.MatchMaxbet AS mm WITH (NOLOCK)
					ON	mm.MatchId = b.matchid
					AND	(	mm.BetType = b.bettype
						OR	(b.bettype = 124 AND mm.BetType = 5)
						OR	(b.bettype = 125 AND mm.BetType = 15)
						)
			LEFT JOIN	#Spread1x2 AS s
					ON	mm.Spread = s.Margin
					AND	mm.BetType IN (5, 15)
			WHERE	b.winlostdate = @winlostdate
				AND	b.statusID IN (112, 113)
				AND	b.Currency NOT IN (20, 27, 28)
				AND	m.sporttype = 1
				AND	m.MatchCode NOT LIKE '%hedge%';
			
			SELECT	@RowCount	= @@ROWCOUNT
				,	@Duration	= DATEDIFF(millisecond, @Begin, GETDATE())
				;

			IF	@Debug = 1
			BEGIN;
				-- Force the output to appear immediately --
				RAISERROR('From Origin - Insert #tmpFilteredBettransByBatch - %d rows - %d ms', 0, 0, @RowCount, @Duration) WITH NOWAIT;
			END;
			
			INSERT INTO	#tmpStagingTraderPerformance (CustId, WorkShift, MatchId, MatchCode, EventDate, SportType, LeagueId, HomeId, AwayId, TeamId, Grade, BetType, Stake, WinLost, SMAWinLost, Comm, BetCount, Spread, ExtraPT, TPositionTaking, VirtualRate, LiveIndicator, BetChoice)
			SELECT	[CustId]			= ISNULL(t.Custid, @IdForUnassignedTrader)
				,	[WorkShift]			= ISNULL(t.WorkShift, 1)
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
				,	[Stake]				= b.Stake --turn over
				,	[WinLost]			= b.WinLost
				,	[SMAWinLost]		= b.SMAWinLost
				,	[Comm]				= scomm --Commission
				,	[BetCount]			= 1 --Live BetCount
				,	[Spread]			= b.Spread
				,	[ExtraPT]			= SUM(ISNULL(b.ExtraPT, 0))
				,	[TPositionTaking]	= b.tpositiontaking
				,	[VirtualRate]		= b.virtualrate
				,	[LiveIndicator]		= b.LiveIndicator
				,	[BetChoice]			= b.BetChoice 
			FROM		#tmpFilteredBettransByBatch AS b WITH (NOLOCK)
			LEFT JOIN	#tmpTrader AS t WITH (NOLOCK)
					ON	b.winlostdate = t.EventDate
					AND	b.matchid = t.matchid
					AND	(	b.BetType = t.BetType
						OR	(b.bettype = 124 AND t.BetType = 5)
						OR	(b.bettype = 125 AND t.BetType = 15)
						OR	(b.bettype = 23 AND t.BetType = 1)
						)
			CROSS APPLY	(
				SELECT	[BetType]	= CASE	WHEN b.BetType = 1 AND SpecialType = 0
												THEN 1 --HDP
											WHEN b.BetType = 7
												THEN 7 --1st HDP
											WHEN b.BetType = 3 AND SpecialType = 0
												THEN 3 --O/U		
											WHEN b.BetType = 8 AND SpecialType = 0
												THEN 8 --1st O/U
											WHEN b.BetType = 2
												THEN 2 --O/E
											WHEN b.BetType = 12
												THEN 12 --1x2
											WHEN b.BetType IN (5, 124) AND SpecialType = 0
												THEN 5 --1x2		
											WHEN b.BetType IN (5, 124) AND SpecialType = 5
												THEN - 14 --10mins 1x2
											WHEN b.BetType IN (15, 125) AND SpecialType = 0
												THEN 15 --1st 1x2
											WHEN b.BetType = 1 AND SpecialType = 4
												THEN - 1 --15mins HDP
											WHEN (b.bettype = 23 AND t.BetType = 1) OR (b.BetType = 1 AND SpecialType = 8)
												THEN - 2 --Next Corner
											WHEN b.BetType = 1 AND SpecialType = 5
												THEN - 15 --10mins HDP
											WHEN b.BetType = 1 AND SpecialType = 9
												THEN - 3 --Next Booking
											WHEN b.BetType IN (5, 124) AND SpecialType = 4
												THEN - 4 --15mins 1X2
											WHEN b.BetType = 3 AND SpecialType = 4
												THEN - 5 --15mins O/U
											WHEN b.BetType = 3 AND SpecialType = 5
												THEN - 6 --10mins O/U
											WHEN b.BetType = 3 AND SpecialType = 2
												THEN - 7 --Corners 15mins O/U
											WHEN b.BetType = 3 AND SpecialType = 7
												THEN - 8 --Total Bookings
											WHEN b.BetType = 3 AND SpecialType = 1
												THEN - 10 --Total Bookings 15mins O/U
											WHEN b.BetType = 3 AND SpecialType = 6
												THEN - 13 --No. of Corner
											WHEN b.BetType = 8 AND SpecialType = 6
												THEN - 12 --1st No. of Corner
											WHEN b.BetType = 8 AND SpecialType = 7
												THEN - 9 --1st TotalBookings
											WHEN (b.BetType = 3 OR b.BetType = 8) AND SpecialType = 3
												THEN - 11 --Single Team O/U
											WHEN b.BetType IN (5, 124)
												THEN 5 --1x2	
											WHEN b.BetType IN (15, 125)
												THEN 15 --1st 1x2
											ELSE b.BetType
										END
				) AS ca
			WHERE	b.winlostdate = @winlostdate
			GROUP BY	ISNULL(t.Custid, @IdForUnassignedTrader)
					,	ISNULL(t.WorkShift, 1)
					,	b.MatchId
					,	b.MatchCode
					,	b.EventDate
					,	b.SportType
					,	b.LeagueId
					,	b.HomeId
					,	b.AwayId
					,	t.TeamId
					,	t.Grade
					,	ca.BetType
					,	b.Stake
					,	b.WinLost
					,	b.SMAWinLost
					,	scomm
					,	b.Spread
					,	b.tpositiontaking
					,	b.virtualrate
					,	b.transid
					,	b.LiveIndicator
					,	b.BetChoice
					;

			SELECT	@RowCount	= @@ROWCOUNT
				,	@Duration	= DATEDIFF(millisecond, @Begin, GETDATE())
				;

			IF	@Debug = 1
			BEGIN;
				-- Force the output to appear immediately --
				RAISERROR('From Origin - Insert #tmpStagingTraderPerformance - %d rows - %d ms', 0, 0, @RowCount, @Duration) WITH NOWAIT;
			END;
			
			DELETE [dbo].[TraderPerformance] WHERE EventDate = @winlostdate

			INSERT INTO	dbo.TraderPerformance (CustId, WorkShift, MatchId, MatchCode, EventDate, SportType, LeagueId, HomeId, AwayId, TeamId, Grade, BetType, IsLive, Stake, WinLost, Comm, BetCount, Spread)
			SELECT	[CustId]			= t.CustId
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
				,	[Stake]				= SUM(t.Stake * (1 - t.TPositionTaking - t.ExtraPT))
				,	[WinLost]			= SUM(((-(t.WinLost + t.SMAWinLost)) + t.WinLost * t.ExtraPT) * t.virtualrate)
				,	[Comm]				= SUM((Comm - (CASE WHEN t.TPositionTaking = 1 THEN 0 ELSE (Comm * t.ExtraPT/(1 - t.TPositionTaking)) END)) * t.virtualrate)
				,	[BetCount]			= SUM(t.BetCount)
				,	[Spread]			= MAX(t.Spread)
			FROM	#tmpStagingTraderPerformance AS t WHERE	t.EventDate = @winlostdate
			GROUP BY t.CustId, t.WorkShift, t.MatchId, t.MatchCode, t.EventDate, t.SportType, t.LeagueId, t.HomeId, t.AwayId, t.TeamId, t.Grade, t.BetType, t.LiveIndicator;
				
			SELECT	@RowCount	= @@ROWCOUNT
				,	@Duration	= DATEDIFF(millisecond, @Begin, GETDATE())
				;

			IF	@Debug = 1
			BEGIN;
				-- Force the output to appear immediately --
				RAISERROR('From Origin - Insert TraderPerformance - %d rows - %d ms', 0, 0, @RowCount, @Duration) WITH NOWAIT;
			END;
		
			DELETE [dbo].[TraderPerformance_BetChoice]	WHERE EventDate = @winlostdate

			INSERT INTO	dbo.[TraderPerformance_BetChoice] (CustId, MatchId, EventDate, SportType, LeagueId, BetType, BetChoice, IsLive, Stake, WinLost, Comm, BetCount)
			SELECT		[CustId]			= t.CustId
					,	[MatchId]			= t.MatchId
					,	[EventDate]			= t.EventDate
					,	[SportType]			= t.SportType
					,	[LeagueId]			= t.LeagueId
					,	[BetType]			= t.BetType
					,	[BetChoice]			= t.BetChoice
					,	[IsLive]			= t.LiveIndicator
					,	[Stake]				= SUM(t.Stake * (1 - t.TPositionTaking - t.ExtraPT))
					,	[WinLost]			= SUM(((-(t.WinLost + t.SMAWinLost)) + t.WinLost * t.ExtraPT) * t.virtualrate)
					,	[Comm]				= SUM((Comm - (CASE WHEN t.TPositionTaking = 1 THEN 0 ELSE (Comm * t.ExtraPT/(1 - t.TPositionTaking)) END)) * t.virtualrate)
					,	[BetCount]			= SUM(t.BetCount)
			FROM	#tmpStagingTraderPerformance AS t WHERE t.EventDate = @winlostdate and t.BetChoice IS NOT NULL
			GROUP BY t.CustId, t.MatchId, t.EventDate, t.SportType, t.LeagueId, t.BetType, t.BetChoice, t.LiveIndicator;
				
			SELECT	@RowCount	= @@ROWCOUNT
				,	@Duration	= DATEDIFF(millisecond, @Begin, GETDATE())
				;

			IF	@Debug = 1
			BEGIN
				-- Force the output to appear immediately --
				RAISERROR('From Origin - Insert TraderPerformance_BetChoice - %d rows - %d ms', 0, 0, @RowCount, @Duration) WITH NOWAIT;
			END;

			DELETE	d
			FROM	#winlostdate AS d
			WHERE	d.winlostdate = @winlostdate;
				
			SELECT	@RowCount	= @@ROWCOUNT
				,	@Duration	= DATEDIFF(millisecond, @Begin, GETDATE())
				;

			IF	@Debug = 1
			BEGIN;
				-- Force the output to appear immediately --
				PRINT	@winlostdate;
				RAISERROR('From Origin - DELETE #winlostdate - %d rows - %d ms', 0, 0, @RowCount, @Duration) WITH NOWAIT;
			END;

			TRUNCATE TABLE #tmpStagingTraderPerformance;
			TRUNCATE TABLE #tmpFilteredBettransByBatch;
		END;
	END;
END;
