ALTER PROCEDURE  [dbo].[Task_StagingDataTGRS]
		@Debug					BIT = 0
	,	@BeforeMoveBetsDay		BIT = 1	
	,	@GenerateFromDate		SMALLDATETIME = NULL
	,	@GenerateToDate			SMALLDATETIME = NULL
	,   @Bettypes				VARCHAR(2000) =  '0'
AS
/*
	Created:	20140603@Tom.Vo
	Task :		Staging Data on TGRS DB
	DB:			DBTGRS.bodb_TGRS
	Original:
  
	Revisions:
		- 20141203@Tom.Vo:	Staging data with new requirement
		- 20160307@Billy:	Add new field Spread for staging data - [Redmine: #tmpDL53240]
		- 20160318@Aaron:	Bug fixes on generating (1 st) 1x2 data from bettrans 
		- 20160329@Sophia: 	Change datatype of Spread Column [Redmine: #tmpDL54943]
		- 20160517@Percy:	Recalculate Spread for group bettype 1x2 [RedmineID: #tmpDL56999]    
		- 20170209@Long:	Apply ExtraPT
		- 20170315@Long:	devide batch by date (not by 200k records as it is)		
		- 20170517@Long:	Add more bettypes from Dot_Assginment
		- 20170830@Long:	Add more bettypes from Dot_Assginment
		- 20170816@Percy:	Change data type of Sporttype [RedmineID: #tmpDL73545]
		- 20170914@Billy:	Format code and tune performance for Task Staging - [Redmine: #tmpDL81465]
		- 20170918@Billy:	Remove hedge match from bettrans data - [Redmine: #tmpDL83470]
		- 20170922@Long:	Support more bettypes for Soccer PH AiO - [Redmine: #tmpDL83621]
		- 20171129@Long:	Support Non-Live tickets - [Redmine: #tmpDL86289]
		- 20180102@Long:	Change the way to get BU & MB days
		- 20180109@Long:	Support code for generating historical data
		- 20180116@Long:	Group-by for BetChoice on each bettype [Redmine: #tmpDL87861]
		- 20180119@John.Ngo: Update Logic generating data [Redmine: #tmpDL87861]
		- 20180228@Long:	Track changes on matches [Redmine: #tmpDL89493]
		- 20180419@Long:	Add 2 more bettypes for Asian 1x2 HDP [Redmine: #tmpDL93890]
		- 20180516@Long:	Filter unsupported bettypes
		- 20180618@John.Ngo: Missing data of FT bettype #tmpDL97059
		- 20180822@John.Ngo: Missing data of 124, 125 bettype #tmpDL100251
		- 20180713@Long.Luu: Manage for case changing the status of match before bettrans [Redmine ID: 97987]
		- 20180817@Casey.Huynh: Fix Issue get Bettype. Add SpecialBettype for FillterBettrans Instead of Trader [Redmine ID:89493]
		- 20180924@Long:	Remove code to check for ruben value in _bk & 14 table
		- 20180924Casey.Huynh: Update condition get data to table "TraceScannedMatchesInfo"
		- 20180924@Long:	Compare to pick the max value of (MoveBetDate -3) vs BalanceUpDate
		- 20190108@John:	Exclude Cashout tickets from Betcount figures in TGR reports [Redmine ID: 107602]
		- 20190304@Long:	Calc Actual-rate values for Soccer [Redmine ID: 108920]
		- 20190513@John.Ngo: Update the logic on checking match to prepare data for trading performance [Redmine ID: 113321]
		- 20190704@John.Ngo: Implement change request to the job sum and enhance logic on Extra PT WL calculation [Redmine ID: 116379]
		- 20190822@Long.Luu:	Grade brokendown for details performance [Redmine ID: 117030]
   		
	Param's Explanation:
		- @Bettype = 0: All bettype
	Exam:
	 
*/
BEGIN
	SET NOCOUNT ON;

	-- Common variables
	DECLARE	@IdForUnassignedTrader	INT = 0
		,	@IDForUnknownTeam		INT = 200
		,	@IDForUnknownGrade		INT = 200;

	DECLARE	@Begin					DATETIME = GETDATE()
		,	@RowCount				INT
		,	@Duration				INT
		,	@Msg					NVARCHAR(MAX)
		,	@Date					NVARCHAR(250)
		;

	DECLARE @BalanceUpDay			SMALLDATETIME
		,	@MoveBetsDay			SMALLDATETIME
		,	@Yesterday				SMALLDATETIME
		,	@Today					SMALLDATETIME
		,	@FromSP					BIT = 1
		,	@CapturedDate			DATETIME = GETDATE()
		;

	DECLARE	@winlostdate			DATETIME
		;
	
	-- Check running job
	DECLARE @IsRunningJob				BIT;
	
	IF (@GenerateFromDate IS NULL OR @GenerateToDate IS NULL)
	BEGIN
		SELECT @IsRunningJob = 1
	END
	--

	IF	OBJECT_ID('tempdb..#tmpDLSupportedBettypes') IS NOT NULL
		DROP TABLE	#tmpDLSupportedBettypes;

	CREATE TABLE	#tmpDLSupportedBettypes (
			BetType					SMALLINT PRIMARY KEY
	);
	
	IF	OBJECT_ID('tempdb..#tmpDLFilteredBettypes') IS NOT NULL
		DROP TABLE	#tmpDLFilteredBettypes;

	CREATE TABLE	#tmpDLFilteredBettypes (
			BetType					SMALLINT PRIMARY KEY
	);

	IF @Bettypes <> '0'
		BEGIN	
			INSERT INTO #tmpDLFilteredBettypes(BetType)
			SELECT val FROM dbo.strSplit_Key(@Bettypes,',')
		END
	ELSE
		BEGIN
			INSERT INTO #tmpDLFilteredBettypes(BetType)
			SELECT	DISTINCT m.bettype
			FROM	bodb02.dbo.SportBettypeMatrix AS m WITH(NOLOCK)
			WHERE	m.sporttype = 1
				AND	m.bettype IS NOT NULL
			UNION
			SELECT	DISTINCT b.bettype
			FROM	dbo.BetType AS b WITH (NOLOCK)
			WHERE	b.BetType < 0;
		END;

	INSERT INTO #tmpDLSupportedBettypes(BetType)
	SELECT	DISTINCT b.bettype
	FROM	dbo.BetType AS b WITH (NOLOCK)
	WHERE	b.BetType > 0;

	IF	OBJECT_ID('tempdb..#tmpDLSpread1x2') IS NOT NULL
	BEGIN
		DROP TABLE	#tmpDLSpread1x2
	END;

	CREATE TABLE	#tmpDLSpread1x2 (
			Margin					MONEY
		,	Spread					MONEY
	);
						
	INSERT INTO	#tmpDLSpread1x2
			(Margin, Spread)
	VALUES	(1.05  , 0.2   )
		,	(1.08  , 0.3   )
		,	(1.10  , 0.36  )
		,	(1.12  , 0.44  )
		,	(1.15  , 0.52  )
		;
				
	IF	OBJECT_ID('tempdb..#tmpDLBUMBData') IS NOT NULL
	BEGIN
		DROP TABLE	#tmpDLBUMBData
	END;

	CREATE TABLE	#tmpDLBUMBData (
			BUDay	SMALLDATETIME
		,	MBDay	SMALLDATETIME
	);

	INSERT INTO #tmpDLBUMBData(BUDay,MBDay)
	EXECUTE bodb02.dbo.Age_SelBalanceUpDay;

	SELECT	TOP(1)
			@BalanceUpDay	= BUDay
		,	@MoveBetsDay	= MBDay
	FROM #tmpDLBUMBData;

	SELECT	@Today			= CONVERT(DATE, @Begin);
	SELECT	@Yesterday		= DATEADD(DAY, -1, @Today);

	IF	@Debug = 1
	BEGIN
		SELECT	@Msg = '
			@BalanceUpDay = ' + CONVERT(NVARCHAR, @BalanceUpDay, 120) + N'
			@MoveBetsDay  = ' + CONVERT(NVARCHAR, @MoveBetsDay, 120) + N'
			@Yesterday    = ' + CONVERT(NVARCHAR, @Yesterday, 120);

		-- Force the output to appear immediately --
		RAISERROR(@Msg, 0, 0) WITH NOWAIT;
	END;
	
	IF	OBJECT_ID('tempdb..#tmpDLScannedMatches') IS NOT NULL
	BEGIN
		DROP TABLE #tmpDLScannedMatches;
	END;

	CREATE TABLE	#tmpDLScannedMatches (
			  MatchId		INT NOT NULL
			, EventDate		DATETIME
			, KickOffTime	DATETIME
			, WorkShift		TINYINT
			, MatchCode		NVARCHAR(50)			
			, LeagueId		INT			
			, SportType		INT
			, HomeId		INT
			, AwayId		INT
			, LeagueName	NVARCHAR(100)
			, HomeName		NVARCHAR(100)
			, SpecialType	INT				
	);
	
	CREATE CLUSTERED INDEX	#CIX_tmpDLScannedMatches_MatchId ON #tmpDLScannedMatches (
		MatchId		ASC
	);
	
	CREATE NONCLUSTERED INDEX #NIX_tmpDLScannedMatches_EventDate ON #tmpDLScannedMatches (
		EventDate	ASC
	);

	IF	OBJECT_ID('tempdb..#tmpDLTrader') IS NOT NULL
	BEGIN
		DROP TABLE #tmpDLTrader;
	END;

	CREATE TABLE	#tmpDLTrader (
			CustId				INT
		,	LeagueId			INT
		,	MatchId				INT
		,	EventDate			DATETIME
		,	Bettype				INT
		,	TraderBettype		INT
		,	OperatorType		INT
		,	MainDBBetType		INT
		,	TeamId				INT
		,	Grade				TINYINT
	);

	CREATE CLUSTERED INDEX	#CIX_tmpDLTraderIdx ON #tmpDLTrader (
			CustId				ASC
		,	EventDate			ASC
		,	MatchId				ASC
		,	BetType				ASC
	);

	IF	OBJECT_ID('tempdb..#tmpDLwinlostdate') IS NOT NULL
	BEGIN
		DROP TABLE	#tmpDLwinlostdate;
	END;

	CREATE TABLE	#tmpDLwinlostdate (
		winlostdate				DATE
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

	IF	OBJECT_ID('tempdb..#tmpDLFilteredBettransByBatch') IS NOT NULL
	BEGIN
		DROP TABLE	#tmpDLFilteredBettransByBatch;
	END;

	CREATE TABLE	#tmpDLFilteredBettransByBatch (
			transid				BIGINT
		,	custid				INT
		,	matchid				INT
		,	WorkShift			INT
		,	winlostdate			SMALLDATETIME
		,	bettype				SMALLINT
		,	SpecialType			INT
		,	modds				SMALLMONEY
		,	virtualrate			FLOAT
		,	actualrate			FLOAT
		,	tpositiontaking		SMALLMONEY
		,	srecommend			INT
		,	scomm				MONEY
		,	ExtraPT				DECIMAL(12, 8)
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
	
	IF	OBJECT_ID('tempdb..#tmpDLFilteredBettransByBatch_Distinct') IS NOT NULL
	BEGIN
		DROP TABLE	#tmpDLFilteredBettransByBatch_Distinct;
	END;

	CREATE TABLE	#tmpDLFilteredBettransByBatch_Distinct (
			transid				BIGINT
		,	custid				INT
		,	matchid				INT
		,	WorkShift			INT
		,	winlostdate			SMALLDATETIME
		,	bettype				SMALLINT
		,	SpecialType			INT
		,	modds				SMALLMONEY
		,	virtualrate			FLOAT
		,	actualrate			FLOAT
		,	tpositiontaking		SMALLMONEY
		,	srecommend			INT
		,	scomm				MONEY
		,	ExtraPT				DECIMAL(12, 8)
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

	CREATE CLUSTERED INDEX	#CIX_tmpDLFilteredBettransByBatch_DistinctIdx ON #tmpDLFilteredBettransByBatch_Distinct (
			winlostdate			ASC
		,	MatchId				ASC
		,	BetType				ASC
	);

	CREATE NONCLUSTERED INDEX	#NCIX_tmpDLFilteredBettransByBatch_DistinctIdx ON #tmpDLFilteredBettransByBatch_Distinct (
			custid				ASC
	);

	IF	OBJECT_ID('tempdb..#tmpDLStagingTraderPerformance') IS NOT NULL
	BEGIN
		DROP TABLE	#tmpDLStagingTraderPerformance;
	END;

	CREATE TABLE	#tmpDLStagingTraderPerformance (
			CustId				INT
		,	MemberCustId		INT
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
		,   BetChoice			NVARCHAR(10) 
	);
	
	CREATE CLUSTERED INDEX #CIX_tmpDLStagingTraderPerformanceIdx ON #tmpDLStagingTraderPerformance (
			CustId				ASC
		,	EventDate			ASC
	); 

	CREATE NONCLUSTERED INDEX	#NCIX_tmpDLStagingTraderPerformanceIdx ON #tmpDLStagingTraderPerformance (
			MemberCustId		ASC
	);

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
	IF (@IsRunningJob = 1)
	BEGIN
		TRUNCATE TABLE dbo.Staging_EventDate;

		SELECT @GenerateToDate = @Yesterday;

		IF @BeforeMoveBetsDay = 1
		BEGIN
			SELECT @GenerateFromDate =	CASE WHEN (@MoveBetsDay - 3) > @BalanceUpDay 
											THEN (@MoveBetsDay - 3) 
										ELSE @BalanceUpDay END;
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
		BEGIN
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

	IF @GenerateFromDate < @BalanceUpDay AND @GenerateToDate > @MoveBetsDay
	BEGIN
		SELECT @IsGetDataFromBK = 1
		SELECT @IsGetDataFrom14 = 1
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

	IF @IsGetDataFromBK = 1 AND @IsGetDataFrom14 = 1 AND @IsGetDataFromOrigin = 1
	BEGIN
		SELECT	@FromDateOrigin = @MoveBetsDay + 1
				,	@ToDateOrigin = @GenerateToDate
				,	@FromDate14 = @BalanceUpDay
				,	@ToDate14 = @MoveBetsDay
				,	@FromDateBK = @GenerateFromDate 
				,	@ToDateBK = @BalanceUpDay - 1;
	END;
	
	-- Track changes on matches
	IF (@IsRunningJob = 1)
	BEGIN

		IF	OBJECT_ID('tempdb..#tmpDLDateToTraceChangesOnMatch') IS NOT NULL
		BEGIN
			DROP TABLE	#tmpDLDateToTraceChangesOnMatch;
		END;

		CREATE TABLE	#tmpDLDateToTraceChangesOnMatch (
				EventDate			DATE
		);

		INSERT INTO	#tmpDLDateToTraceChangesOnMatch (EventDate)
		SELECT	tally.EventDate
		FROM	(
			SELECT	[NoDays] = DATEDIFF(DAY, @GenerateFromDate, @GenerateToDate) + 1
		) cnt
		CROSS APPLY	(
			SELECT	TOP(cnt.NoDays)
					[EventDate] = DATEADD(DAY, ROW_NUMBER() OVER(ORDER BY (SELECT NULL)) - 1, @GenerateFromDate)
			FROM		(VALUES (0), (0), (0), (0), (0), (0), (0), (0), (0), (0)) x10(n)
			CROSS APPLY	(VALUES (0), (0), (0), (0), (0), (0), (0), (0), (0), (0)) x100(n)
			CROSS APPLY	(VALUES (0), (0), (0), (0), (0), (0), (0), (0), (0), (0)) x1000(n)
		) tally;

		SELECT	@RowCount	= @@ROWCOUNT
			,	@Duration	= DATEDIFF(millisecond, @Begin, GETDATE())
			;

		IF	@Debug = 1
		BEGIN
			-- Force the output to appear immediately
			SELECT @Date = '@GenerateFromDate = ' + CONVERT(NVARCHAR, @GenerateFromDate, 120) + ', @GenerateToDate = ' + CONVERT(NVARCHAR, @GenerateToDate, 120);
			RAISERROR('Track Changes on Matches - Insert #tmpDLDateToTraceChangesOnMatch - Date: "%s" - %d rows - %d ms', 0, 0, @Date, @RowCount, @Duration) WITH NOWAIT;
		END;

		--=======BACKUP TraderPerformance DATA  TO TrackChangesOnMatches_Queue table
		DELETE FROM dbo.TrackChangesOnMatches_Queue;
		DECLARE @OldCapturedDate DATETIME = GETDATE();
		INSERT INTO dbo.TrackChangesOnMatches_Queue(MatchId, EventDate, SportType, BetType, OldCapturedDate, OldTraderID
					, OldTurnOver, OldWinlost, OldBetCount)
		SELECT	MatchId			= tp.MatchId
			,	EventDate		= tp.EventDate			
			,	SportType		= tp.SportType
			,	BetType			= tp.BetType
			,	OldCapturedDate	= @OldCapturedDate
			,	OldTraderID		= MAX(tp.CustId)
			,	OldTurnOver		= SUM(tp.Stake)
			,	OldWinLost		= SUM(tp.WinLost)
			,	OldBetCount		= SUM(tp.BetCount)
		FROM dbo.TraderPerformance tp WITH(NOLOCK)
			INNER JOIN #tmpDLDateToTraceChangesOnMatch d ON tp.EventDate = d.EventDate
		GROUP BY tp.MatchId
			,	tp.EventDate
			,	tp.SportType
			,	tp.BetType;

		SELECT	@RowCount	= @@ROWCOUNT
			,	@Duration	= DATEDIFF(millisecond, @Begin, GETDATE())
			;
		
		IF	@Debug = 1
		BEGIN
			-- Force the output to appear immediately
			SELECT @Date = '@GenerateFromDate = ' + CONVERT(NVARCHAR, @GenerateFromDate, 120) + ', @GenerateToDate = ' + CONVERT(NVARCHAR, @GenerateToDate, 120);
			RAISERROR('BACKUP TraderPerformance DATA - Insert TrackChangesOnMatches_Queue - Date: "%s" - %d rows - %d ms', 0, 0, @Date, @RowCount, @Duration) WITH NOWAIT;
		END;

	END;

	IF	@IsGetDataFromBK = 1
	BEGIN
		TRUNCATE TABLE #tmpDLTrader;
		
		SELECT @Date = '@FromDateBK = ' + CONVERT(NVARCHAR, @FromDateBK, 120) + ', @ToDateBK = ' + CONVERT(NVARCHAR, @ToDateBK, 120);

		-- GET Scanned Match List: Completed Soccer Match
		TRUNCATE TABLE #tmpDLScannedMatches;
		INSERT INTO #tmpDLScannedMatches(MatchId, EventDate, KickOffTime,WorkShift, MatchCode, LeagueId, SportType, HomeId, AwayId, LeagueName, HomeName, SpecialType)
		SELECT	m.matchId
				, m.eventdate
				, m.kickofftime
	 			, CASE	WHEN CAST(m.kickofftime AS TIME) >= '00:00:00' AND CAST(m.kickofftime AS TIME) < '06:00:00'
								THEN 1 --  Afternoon: 12:00:00 ~ 17:59:59 (GMT + 8)
							WHEN CAST(m.kickofftime AS TIME) >= '06:00:00' AND CAST(m.kickofftime AS TIME) < '16:00:00'
								THEN 2 -- Night: 18:00:00 ~ 3:59:59 (GMT + 8)				
							--WHEN CAST(m.kickofftime AS TIME) >= '16:00:00' AND CAST(m.kickofftime AS TIME) <'24:00:00'THEN 3 --  Midnight: 4:00:00 ~ 11:59:59 (GMT + 8)
							ELSE 3
				  END AS WorkShift
				, m.matchCode
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
		FROM	bodb_Archive.dbo.Match_bk AS m WITH (NOLOCK)
				INNER JOIN bodb02.dbo.league AS l WITH (NOLOCK) ON l.leagueid = m.leagueid
				LEFT JOIN bodb02.dbo.team AS t WITH (NOLOCK) ON t.teamid = homeid
		WHERE	m.EventDate BETWEEN @FromDateBK AND @ToDateBK
				AND	m.SportType = 1
				AND m.EventStatus = 'completed'
				AND	m.matchCode NOT LIKE '%hedge%';
		
		INSERT INTO	#tmpDLTrader (CustId, LeagueId, MatchId, EventDate, BetType, TraderBettype, OperatorType, MainDBBetType, TeamId, Grade)
		SELECT	DISTINCT
				[CustId]		= a.OperatorID
			,	[LeagueId]		= m.LeagueId
			,	[MatchId]		= m.matchId
			,	[EventDate]		= m.EventDate
			,	[BetType]		= CASE	WHEN a.bettype = 5 AND a.operatortype = 1
											THEN 1
										ELSE ISNULL(b.MainDBBetType, 0) 
									END
			,	[TraderBettype] = a.bettype
			,	[OperatorType]	= a.operatortype
			,	[MainDBBetType] = b.MainDBBetType
			,	[TeamId]		= td_T.TeamId
			,	[Grade]			= td_G.Grade
		FROM		bodb_archive.dbo.Dot_Admin_Assignment_Operator_bk AS a WITH (NOLOCK)
		INNER JOIN	#tmpDLScannedMatches AS m WITH (NOLOCK) ON m.matchId = a.matchId
		LEFT JOIN	dbo.BetType AS b WITH(NOLOCK)
				ON	a.bettype = b.AssignmentBetType
				AND	a.OperatorType = b.OperatorType
		LEFT JOIN	dbo.TraderGrade_History AS td_G WITH (NOLOCK)
				ON	td_G.CustID = a.OperatorID
				AND	m.EventDate BETWEEN td_G.BeginDate AND ISNULL(td_G.EndDate, @Today + 10)
		LEFT JOIN	dbo.TraderTeam_History AS td_T WITH (NOLOCK)
				ON	td_T.CustID = a.OperatorID
				AND	m.EventDate BETWEEN td_T.BeginDate AND ISNULL(td_T.EndDate, @Today + 10)
		WHERE	m.EventDate BETWEEN @FromDateBK AND @ToDateBK
			AND	a.OperatorType < 3
		
		SELECT	@RowCount	= @@ROWCOUNT
			,	@Duration	= DATEDIFF(millisecond, @Begin, GETDATE())
			;

		IF	@Debug = 1
		BEGIN
			-- Force the output to appear immediately
			RAISERROR('From BK - Insert #tmpDLTrader - Date: "%s" - %d rows - %d ms', 0, 0, @Date, @RowCount, @Duration) WITH NOWAIT;
		END;
	
		INSERT INTO	#tmpDLwinlostdate (winlostdate)
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
		BEGIN
			-- Force the output to appear immediately
			RAISERROR('From BK - Insert #tmpDLwinlostdate - Date: "%s" - %d rows - %d ms', 0, 0, @Date, @RowCount, @Duration) WITH NOWAIT;
		END;

		-- No input date range: Default job run
		IF (@IsRunningJob = 1)
		BEGIN
			INSERT INTO dbo.Staging_EventDate (EventDate)
			SELECT winlostdate FROM #tmpDLwinlostdate WITH(NOLOCK)

			SELECT	@RowCount	= @@ROWCOUNT
				,	@Duration	= DATEDIFF(millisecond, @Begin, GETDATE())
				;

			IF	@Debug = 1
			BEGIN
				-- Force the output to appear immediately --
				RAISERROR('From BK - Insert Staging_EventDate - %d rows - %d ms', 0, 0, @RowCount, @Duration) WITH NOWAIT;
			END;
		END;
		
		-- SUM(ExtraPT)
		TRUNCATE TABLE	#ExtraPTSportbook;
		INSERT INTO #ExtraPTSportbook
		SELECT SuperId, SUM(ExtraPT) AS ExtraPT, FromDate, ToDate
		FROM
		(
			SELECT SuperId, ExtraPT, FromDate, ToDate
			FROM bodb02.dbo.Acc_GroupExtraPTSetting WITH (NOLOCK)
			WHERE
				(
					@FromDateBK BETWEEN FromDate AND ToDate
					OR @ToDateBK BETWEEN FromDate AND ToDate
				)
				AND ProductId = 1 AND Sporttype = 0 AND SubProduct = ''
		) A
		GROUP BY SuperId, FromDate, ToDate;

		WHILE	EXISTS (SELECT 1 FROM #tmpDLwinlostdate)
		BEGIN
			SELECT	TOP(1)
					@WinLostDate = d.winlostdate
			FROM	#tmpDLwinlostdate AS d WITH(NOLOCK);
			
			SELECT @Date = CONVERT(NVARCHAR, @winlostdate, 120);

			TRUNCATE TABLE	#tmpDLFilteredBettransByBatch;
			INSERT INTO	#tmpDLFilteredBettransByBatch (transid, custid, matchid, workshift, specialType, winlostdate, bettype, modds, 
						virtualrate, actualrate, tpositiontaking, srecommend, scomm, ExtraPT, Spread, Stake, WinLost, SMAWinLost, MatchCode
						, EventDate, SportType, LeagueId, HomeId, AwayId, LiveIndicator, BetChoice)
			SELECT	[transid]			= b.transid
				,	[custid]			= b.custid
				,	[matchid]			= b.matchId
				,	[workshift]			= m.WorkShift
				,	[specialType]		= m.SpecialType
				,	[winlostdate]		= b.winlostdate
				,	[bettype]			= CASE	WHEN b.bettype = 1308
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
				,	[modds]				= b.modds
				,	[virtualrate]		= b.virtualrate
				,	[actualrate]		= b.actualrate
				,	[tpositiontaking]	= b.tpositiontaking
				,	[srecommend]		= b.srecommend
				,	[scomm]				= b.scomm
				,	[ExtraPT]			= CASE WHEN m.eventdate < '20170221' THEN 0 ELSE es.ExtraPT END
				,	[Spread]			= CASE WHEN mm.BetType IN (5, 15) THEN ISNULL(s.Spread, - (4 / mm.Spread - 4)) ELSE mm.Spread END
				,	[Stake]				= CASE WHEN b.modds = 0.25 OR b.modds = - 0.25 THEN ABS(b.stake) / 2 ELSE ABS(b.stake) END
				,	[WinLost]			= winlost - actual_stake
				,	[SMAWinLost]		= awinlost + mwinlost + swinlost
				,	[MatchCode]			= m.matchCode
				,	[EventDate]			= m.EventDate
				,	[SportType]			= m.SportType
				,	[LeagueId]			= m.LeagueId
				,	[HomeId]			= m.HomeId
				,	[AwayId]			= m.AwayId
				,	[LiveIndicator]		= b.liveindicator
				,	[BetChoice]			= b.betteam
			FROM		bodb_Archive.dbo.bettrans_bk AS b WITH (NOLOCK)
			INNER JOIN	#tmpDLScannedMatches AS m WITH (NOLOCK)
					ON	b.matchId = m.matchId
			LEFT JOIN	#ExtraPTSportbook AS es WITH (NOLOCK)
					ON	es.SuperId = b.srecommend
					AND	b.winlostdate BETWEEN es.FromDate AND es.ToDate
			LEFT JOIN	bodb_Archive.dbo.MatchMaxbet_bk AS mm WITH (NOLOCK)
					ON	mm.matchId = b.matchId
					AND	mm.BetType = b.bettype
			LEFT JOIN	#tmpDLSpread1x2 AS s
					ON	mm.Spread = s.Margin
					AND	mm.BetType IN (5, 15)
			WHERE	b.winlostdate = @winlostdate
				AND	b.statusID IN (112, 113)
				AND	b.Currency NOT IN (20, 27, 28)
				AND b.bettype IN (SELECT BetType FROM #tmpDLFilteredBettypes WITH (NOLOCK));
			
			SELECT	@RowCount	= @@ROWCOUNT
				,	@Duration	= DATEDIFF(millisecond, @Begin, GETDATE())
				;
			
			IF	@Debug = 1
			BEGIN
				-- Force the output to appear immediately
				RAISERROR('From BK - Insert #tmpDLFilteredBettransByBatch - Date: "%s" - %d rows - %d ms', 0, 0, @Date, @RowCount, @Duration) WITH NOWAIT;
			END;

				-- "DISTINCT" Prevent Page Splits
			TRUNCATE TABLE	#tmpDLFilteredBettransByBatch_Distinct;
			INSERT INTO	#tmpDLFilteredBettransByBatch_Distinct (transid, custid, matchid, workshift, specialType, winlostdate, bettype, modds, 
						virtualrate, actualrate, tpositiontaking, srecommend, scomm, ExtraPT, Spread, Stake, WinLost, SMAWinLost, MatchCode, 
						EventDate, SportType, LeagueId, HomeId, AwayId, LiveIndicator, BetChoice)
			SELECT	DISTINCT transid, custid, matchid, workshift, specialType, winlostdate, bettype, modds, 
						virtualrate, actualrate, tpositiontaking, srecommend, scomm, ExtraPT, Spread, Stake, WinLost, SMAWinLost, MatchCode, 
						EventDate, SportType, LeagueId, HomeId, AwayId, LiveIndicator, BetChoice
			FROM	#tmpDLFilteredBettransByBatch WITH(NOLOCK);
			
			INSERT INTO	#tmpDLStagingTraderPerformance (CustId, MemberCustId, WorkShift, MatchId, MatchCode, EventDate, SportType, LeagueId, HomeId, AwayId, 
			TeamId, Grade, BetType, Stake, WinLost, SMAWinLost, Comm, BetCount, Spread, ExtraPT, TPositionTaking, VirtualRate, ActualRate, LiveIndicator, BetChoice)
			SELECT	[CustId]			= ISNULL(t.Custid, @IdForUnassignedTrader)
				,	[MemberCustId]		= b.custid
				,	[WorkShift]			= ISNULL(b.WorkShift, 1)
				,	[MatchId]			= b.matchId
				,	[MatchCode]			= b.matchCode
				,	[EventDate]			= b.EventDate
				,	[SportType]			= b.SportType
				,	[LeagueId]			= b.LeagueId
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
				,	[Spread]			= b.Spread
				,	[ExtraPT]			= ISNULL(b.ExtraPT, 0)
				,	[TPositionTaking]	= b.tpositiontaking
				,	[VirtualRate]		= b.virtualrate
				,	[ActualRate]		= b.actualrate
				,	[LiveIndicator]		= b.LiveIndicator
				,	[BetChoice]			= b.BetChoice 
			FROM		#tmpDLFilteredBettransByBatch_Distinct AS b WITH (NOLOCK)
			INNER JOIN #tmpDLSupportedBettypes AS bt WITH(NOLOCK) ON b.BetType = bt.BetType
			LEFT JOIN	#tmpDLTrader AS t WITH (NOLOCK)
					ON	b.winlostdate = t.EventDate
					AND	b.matchId = t.matchId
					AND	(	b.BetType = t.BetType
						OR	(b.bettype = 23 AND t.BetType = 1)
						)
			CROSS APPLY	(
				SELECT	[BetType]	= CASE	WHEN b.BetType = 1 AND b.SpecialType = 0
												THEN 1 --HDP
											WHEN b.BetType = 7
												THEN 7 --1st HDP
											WHEN b.BetType = 3 AND b.SpecialType = 0
												THEN 3 --O/U		
											WHEN b.BetType = 8 AND b.SpecialType = 0
												THEN 8 --1st O/U
											WHEN b.BetType = 2
												THEN 2 --O/E
											WHEN b.BetType = 12
												THEN 12 --1x2
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
											WHEN b.BetType IN (5, 124)
												THEN 5 --1x2	
											WHEN b.BetType IN (15, 125)
												THEN 15 --1st 1x2
											ELSE b.BetType
										END
				) AS ca
			WHERE	b.winlostdate = @winlostdate
			GROUP BY	ISNULL(t.Custid, @IdForUnassignedTrader)
					,	b.custid
					,	ISNULL(b.WorkShift, 1)
					,	b.matchId
					,	b.matchCode
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
					,	b.scomm
					,	b.Spread
					,	ISNULL(b.ExtraPT, 0)
					,	b.tpositiontaking
					,	b.virtualrate
					,	b.actualrate
					,	b.LiveIndicator
					,	b.BetChoice
					,	b.transid -- should not be removed since there is a case that extraPT is changed in the range of time --> duplicate row
					;

			SELECT	@RowCount	= @@ROWCOUNT
				,	@Duration	= DATEDIFF(millisecond, @Begin, GETDATE())
				;
			
			IF	@Debug = 1
			BEGIN
				-- Force the output to appear immediately
				RAISERROR('From BK - Insert #tmpDLStagingTraderPerformance - Date: "%s" - %d rows - %d ms', 0, 0, @Date, @RowCount, @Duration) WITH NOWAIT;
			END;

			UPDATE t
			SET t.TeamId = @IDForUnknownTeam
				,	t.Grade = @IDForUnknownGrade
			FROM #tmpDLStagingTraderPerformance AS t WITH(ROWLOCK, UPDLOCK)
			WHERE t.CustId = 0;
			
			DELETE dbo.TraderPerformance WHERE EventDate = @winlostdate AND Bettype IN (SELECT BetType FROM #tmpDLFilteredBettypes WITH (NOLOCK));

			INSERT INTO	dbo.TraderPerformance (CustId, WorkShift, MatchId, MatchCode, EventDate, SportType, LeagueId, HomeId, AwayId, TeamId, Grade, BetType, IsLive, 
			Stake, WinLost, Comm, Stake_AR, WinLost_AR, Comm_AR, BetCount, Spread)
			SELECT	[CustId]			= t.CustId
				,	[WorkShift]			= t.WorkShift
				,	[MatchId]			= t.matchId
				,	[MatchCode]			= t.matchCode
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
				,	[BetCount]			= SUM(CASE WHEN tc.custid IS NULL THEN t.BetCount ELSE 0 END)
				,	[Spread]			= MAX(t.Spread)
			FROM	#tmpDLStagingTraderPerformance AS t WITH(NOLOCK)
			LEFT JOIN bodb02.dbo.TradeCust tc WITH (NOLOCK) ON t.MemberCustId = tc.custid AND tc.VendorID = 14
			WHERE	t.EventDate = @winlostdate
			GROUP BY t.CustId, t.WorkShift, t.matchId, t.matchCode, t.EventDate, t.SportType, t.LeagueId, t.HomeId, t.AwayId, t.TeamId, t.Grade, t.BetType, t.LiveIndicator;

			SELECT	@RowCount	= @@ROWCOUNT
				,	@Duration	= DATEDIFF(millisecond, @Begin, GETDATE())
				;

			IF	@Debug = 1
			BEGIN
				-- Force the output to appear immediately
				RAISERROR('From BK - Insert TraderPerformance - Date: "%s" - %d rows - %d ms', 0, 0, @Date, @RowCount, @Duration) WITH NOWAIT;
			END;
		
			DELETE dbo.TraderPerformance_BetChoice	WHERE EventDate = @winlostdate AND Bettype IN (SELECT BetType FROM #tmpDLFilteredBettypes WITH (NOLOCK));

			INSERT INTO	dbo.TraderPerformance_BetChoice (CustId, MatchId, EventDate, SportType, LeagueId, BetType, BetChoice, IsLive, Stake, WinLost, Comm, Stake_AR, WinLost_AR, Comm_AR, BetCount)
			SELECT		[CustId]			= t.CustId
					,	[MatchId]			= t.matchId
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
					,	[BetCount]			= SUM(CASE WHEN tc.custid IS NULL THEN t.BetCount ELSE 0 END)
			FROM	#tmpDLStagingTraderPerformance AS t WITH(NOLOCK)
			LEFT JOIN bodb02.dbo.TradeCust tc WITH (NOLOCK) ON t.MemberCustId = tc.custid AND tc.VendorID = 14
			WHERE t.EventDate = @winlostdate AND t.BetChoice IS NOT NULL
			GROUP BY t.CustId, t.matchId, t.EventDate, t.SportType, t.LeagueId, t.BetType, t.BetChoice, t.LiveIndicator;
				
			SELECT	@RowCount	= @@ROWCOUNT
				,	@Duration	= DATEDIFF(millisecond, @Begin, GETDATE())
				;
			
			IF	@Debug = 1
			BEGIN
				-- Force the output to appear immediately
				RAISERROR('From BK - Insert TraderPerformance_BetChoice - Date: "%s" - %d rows - %d ms', 0, 0, @Date, @RowCount, @Duration) WITH NOWAIT;
			END;

			DELETE	d
			FROM	#tmpDLwinlostdate AS d
			WHERE	d.winlostdate = @winlostdate;
				
			SELECT	@RowCount	= @@ROWCOUNT
				,	@Duration	= DATEDIFF(millisecond, @Begin, GETDATE())
				;
			
			IF	@Debug = 1
			BEGIN
				-- Force the output to appear immediately
				RAISERROR('From BK - DELETE #tmpDLwinlostdate - Date: "%s" - %d rows - %d ms', 0, 0, @Date, @RowCount, @Duration) WITH NOWAIT;
			END;

			TRUNCATE TABLE #tmpDLStagingTraderPerformance;
			TRUNCATE TABLE #tmpDLFilteredBettransByBatch;
			TRUNCATE TABLE #tmpDLFilteredBettransByBatch_Distinct;
		END;
	END;

	IF	@IsGetDataFrom14 = 1
	BEGIN
		TRUNCATE TABLE #tmpDLTrader;
		
		SELECT @Date = '@FromDate14 = ' + CONVERT(NVARCHAR, @FromDate14, 120) + ', @ToDate14 = ' + CONVERT(NVARCHAR, @ToDate14, 120);

		-- GET Scanned Match List: Completed Soccer Match
		TRUNCATE TABLE #tmpDLScannedMatches;
		INSERT INTO #tmpDLScannedMatches(MatchId, EventDate, KickOffTime,WorkShift, MatchCode, LeagueId, SportType, HomeId, AwayId, LeagueName, HomeName, SpecialType)
		SELECT	m.matchId
				, m.eventdate
				, m.kickofftime
	 			, CASE	WHEN CAST(m.kickofftime AS TIME) >= '00:00:00' AND CAST(m.kickofftime AS TIME) < '06:00:00'
								THEN 1 --  Afternoon: 12:00:00 ~ 17:59:59 (GMT + 8)
							WHEN CAST(m.kickofftime AS TIME) >= '06:00:00' AND CAST(m.kickofftime AS TIME) < '16:00:00'
								THEN 2 -- Night: 18:00:00 ~ 3:59:59 (GMT + 8)				
							--WHEN CAST(m.kickofftime AS TIME) >= '16:00:00' AND CAST(m.kickofftime AS TIME) <'24:00:00'THEN 3 --  Midnight: 4:00:00 ~ 11:59:59 (GMT + 8)
							ELSE 3
				  END AS WorkShift
				, m.matchCode
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
		FROM	bodb02.dbo.match14 AS m WITH (NOLOCK)
				INNER JOIN bodb02.dbo.league AS l WITH (NOLOCK) ON l.leagueid = m.leagueid
				LEFT JOIN bodb02.dbo.team AS t WITH (NOLOCK) ON t.teamid = homeid
		WHERE	m.EventDate BETWEEN @FromDate14 AND @ToDate14
				AND	m.SportType = 1
				AND m.EventStatus = 'completed'
				AND	m.matchCode NOT LIKE '%hedge%';
		
		INSERT INTO dbo.TracePerformanceScannedMatches(MatchId, EventDate, KickOffTime,WorkShift, MatchCode, LeagueId, SportType, HomeId, AwayId, LeagueName, HomeName, SpecialType, fromSP, CapturedDate )
		SELECT	MatchId
				, EventDate
				, KickOffTime
				, WorkShift
				, MatchCode
				, LeagueId
				, SportType
				, HomeId
				, AwayId
				, LeagueName
				, HomeName
				, SpecialType
				, @FromSP
				, @CapturedDate
		FROM	#tmpDLScannedMatches WITH (NOLOCK);		
		
		INSERT INTO dbo.TraceScannedMatchesInfo(MatchId, EventDate, Bettype, LiveIndicator, BetCount, SumActualStake, SumComm, SumModds, SumStake, SumVirtualRate, SumWinlost, fromSP, CapturedDate)
		SELECT m.MatchId
				, m.EventDate
				, b.Bettype
				, b.LiveIndicator
				 , BetCount = COUNT(1)
				 , SumActualStake = SUM(b.actual_stake)
				 , SumComm = SUM(b.Comm)
				 , SumModds = SUM(b.Modds)
				 , SumStake = SUM(b.Stake)
				 , SumVirtualRate = SUM(b.VirtualRate)
				 , SumWinlost = SUM(b.winlost)
				 , @FromSP
				 , @CapturedDate
		FROM	#tmpDLScannedMatches m WITH (NOLOCK)
				INNER JOIN bodb02.dbo.bettrans14 b WITH (NOLOCK) ON b.matchid = m.matchid
		WHERE b.winlostdate BETWEEN @FromDate14 AND @ToDate14
		GROUP BY  m.MatchId,  m.EventDate,  b.Bettype, b.LiveIndicator
		
		INSERT INTO	#tmpDLTrader (CustId, LeagueId, MatchId, EventDate, BetType, TraderBettype, OperatorType, MainDBBetType, TeamId, Grade)
		SELECT	DISTINCT
				[CustId]		= a.OperatorID
			,	[LeagueId]		= m.LeagueId
			,	[MatchId]		= m.matchId
			,	[EventDate]		= m.EventDate
			,	[BetType]		= CASE	WHEN a.bettype = 5 AND a.operatortype = 1
											THEN 1
										ELSE ISNULL(b.MainDBBetType, 0) 
									END
			,	[TraderBettype] = a.bettype
			,	[OperatorType]	= a.operatortype
			,	[MainDBBetType] = b.MainDBBetType
			,	[TeamId]		= td_T.TeamId
			,	[Grade]			= td_G.Grade
		FROM		bodb_archive.dbo.Dot_Admin_Assignment_Operator_bk AS a WITH (NOLOCK)
		INNER JOIN	#tmpDLScannedMatches AS m WITH (NOLOCK) ON m.matchId = a.matchId
		LEFT JOIN	dbo.BetType AS b WITH(NOLOCK)
				ON	a.bettype = b.AssignmentBetType
				AND	a.OperatorType = b.OperatorType
		LEFT JOIN	dbo.TraderGrade_History AS td_G WITH (NOLOCK)
				ON	td_G.CustID = a.OperatorID
				AND	m.EventDate BETWEEN td_G.BeginDate AND ISNULL(td_G.EndDate, @Today + 10)
		LEFT JOIN	dbo.TraderTeam_History AS td_T WITH (NOLOCK)
				ON	td_T.CustID = a.OperatorID
				AND	m.EventDate BETWEEN td_T.BeginDate AND ISNULL(td_T.EndDate, @Today + 10)
		WHERE	m.EventDate BETWEEN @FromDate14 AND @ToDate14
			AND	a.OperatorType < 3
		
		SELECT	@RowCount	= @@ROWCOUNT
			,	@Duration	= DATEDIFF(millisecond, @Begin, GETDATE())
			;

		IF	@Debug = 1
		BEGIN
			-- Force the output to appear immediately
			RAISERROR('From 14 - Insert #tmpDLTrader - Date: "%s" - %d rows - %d ms', 0, 0, @Date, @RowCount, @Duration) WITH NOWAIT;
		END;
		
		INSERT INTO dbo.TracePerformanceTrader(CustId, LeagueId, MatchId, EventDate, BetType, TraderBettype, OperatorType, MainDBBetType, TeamId, Grade, fromSP, CapturedDate)
		SELECT CustId, LeagueId, MatchId, EventDate, BetType, TraderBettype, OperatorType, MainDBBetType, TeamId, Grade, @fromSP, @CapturedDate
		FROM	#tmpDLTrader WITH (NOLOCK);
		
		INSERT INTO	#tmpDLwinlostdate (winlostdate)
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
		BEGIN
			-- Force the output to appear immediately
			RAISERROR('From 14 - Insert #tmpDLwinlostdate - Date: "%s" - %d rows - %d ms', 0, 0, @Date, @RowCount, @Duration) WITH NOWAIT;
		END;

		-- No input date range: Default job run
		IF (@IsRunningJob = 1)
		BEGIN
			INSERT INTO dbo.Staging_EventDate (EventDate)
			SELECT winlostdate FROM #tmpDLwinlostdate WITH(NOLOCK);

			SELECT	@RowCount	= @@ROWCOUNT
				,	@Duration	= DATEDIFF(millisecond, @Begin, GETDATE())
				;

			IF	@Debug = 1
			BEGIN
				-- Force the output to appear immediately --
				RAISERROR('From 14 - Insert Staging_EventDate - %d rows - %d ms', 0, 0, @RowCount, @Duration) WITH NOWAIT;
			END;
		END;

		-- SUM(ExtraPT)
		TRUNCATE TABLE	#ExtraPTSportbook;
		INSERT INTO #ExtraPTSportbook
		SELECT SuperId, SUM(ExtraPT) AS ExtraPT, FromDate, ToDate
		FROM
		(
			SELECT SuperId, ExtraPT, FromDate, ToDate
			FROM bodb02.dbo.Acc_GroupExtraPTSetting WITH (NOLOCK)
			WHERE
				(
					@FromDate14 BETWEEN FromDate AND ToDate
					OR @ToDate14 BETWEEN FromDate AND ToDate
				)
				AND ProductId = 1 AND Sporttype = 0 AND SubProduct = ''
		) A
		GROUP BY SuperId, FromDate, ToDate;

		WHILE	EXISTS (SELECT 1 FROM #tmpDLwinlostdate WITH(NOLOCK))
		BEGIN
			SELECT	TOP(1)
					@WinLostDate = d.winlostdate
			FROM	#tmpDLwinlostdate AS d WITH(NOLOCK);

			SELECT @Date = CONVERT(NVARCHAR, @winlostdate, 120);
			
			TRUNCATE TABLE	#tmpDLFilteredBettransByBatch;
			INSERT INTO	#tmpDLFilteredBettransByBatch (transid, custid, matchid, workshift, specialType, winlostdate, bettype, modds, 
						virtualrate, actualrate, tpositiontaking, srecommend, scomm, ExtraPT, Spread, Stake, WinLost, SMAWinLost, 
						MatchCode, EventDate, SportType, LeagueId, HomeId, AwayId, LiveIndicator, BetChoice)
			SELECT	[transid]			= b.transid
				,	[custid]			= b.custid
				,	[matchid]			= b.matchId
				,	[workshift]			= m.WorkShift
				,	[specialType]		= m.SpecialType
				,	[winlostdate]		= b.winlostdate
				,	[bettype]			= CASE	WHEN b.bettype = 1308
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
				,	[modds]				= b.modds
				,	[virtualrate]		= b.virtualrate
				,	[actualrate]		= b.actualrate
				,	[tpositiontaking]	= b.tpositiontaking
				,	[srecommend]		= b.srecommend
				,	[scomm]				= b.scomm
				,	[ExtraPT]			= es.ExtraPT
				,	[Spread]			= CASE WHEN mm.BetType IN (5, 15) THEN ISNULL(s.Spread, - (4 / mm.Spread - 4)) ELSE mm.Spread END
				,	[Stake]				= CASE WHEN b.modds = 0.25 OR b.modds = - 0.25 THEN ABS(b.stake) / 2 ELSE ABS(b.stake) END
				,	[WinLost]			= winlost - actual_stake
				,	[SMAWinLost]		= awinlost + mwinlost + swinlost
				,	[MatchCode]			= m.matchCode
				,	[EventDate]			= m.EventDate
				,	[SportType]			= m.SportType
				,	[LeagueId]			= m.LeagueId
				,	[HomeId]			= m.HomeId
				,	[AwayId]			= m.AwayId
				,	[LiveIndicator]		= b.liveindicator
				,	[BetChoice]			= b.betteam
			FROM		bodb02.dbo.bettrans14 AS b WITH (NOLOCK)
			INNER JOIN	#tmpDLScannedMatches AS m WITH (NOLOCK)
					ON	b.matchId = m.matchId
			LEFT JOIN	#ExtraPTSportbook AS es WITH (NOLOCK)
					ON	es.SuperId = b.srecommend
					AND	b.winlostdate BETWEEN es.FromDate AND es.ToDate
			LEFT JOIN	bodb02.dbo.MatchMaxbet14 AS mm WITH (NOLOCK)
					ON	mm.matchId = b.matchId
					AND	mm.BetType = b.bettype
			LEFT JOIN	#tmpDLSpread1x2 AS s
					ON	mm.Spread = s.Margin
					AND	mm.BetType IN (5, 15)
			WHERE	b.winlostdate = @winlostdate
				AND	b.statusID IN (112, 113)
				AND	b.Currency NOT IN (20, 27, 28)
				AND b.bettype IN (SELECT BetType FROM #tmpDLFilteredBettypes WITH (NOLOCK));
			
			SELECT	@RowCount	= @@ROWCOUNT
				,	@Duration	= DATEDIFF(millisecond, @Begin, GETDATE())
				;

			IF	@Debug = 1
			BEGIN
				-- Force the output to appear immediately
				RAISERROR('From 14 - Insert #tmpDLFilteredBettransByBatch - Date: "%s" - %d rows - %d ms', 0, 0, @Date, @RowCount, @Duration) WITH NOWAIT;
			END;

				-- "DISTINCT" Prevent Page Splits
			TRUNCATE TABLE	#tmpDLFilteredBettransByBatch_Distinct;
			INSERT INTO	#tmpDLFilteredBettransByBatch_Distinct (transid, custid, matchid, workshift, specialType, winlostdate, bettype, modds, 
						virtualrate, actualrate, tpositiontaking, srecommend, scomm, ExtraPT, Spread, Stake, WinLost, SMAWinLost, MatchCode, 
						EventDate, SportType, LeagueId, HomeId, AwayId, LiveIndicator, BetChoice)
			SELECT	DISTINCT transid, custid, matchid, workshift, specialType, winlostdate, bettype, modds, 
						virtualrate, actualrate, tpositiontaking, srecommend, scomm, ExtraPT, Spread, Stake, WinLost, SMAWinLost, MatchCode, 
						EventDate, SportType, LeagueId, HomeId, AwayId, LiveIndicator, BetChoice
			FROM	#tmpDLFilteredBettransByBatch WITH(NOLOCK);
			
			INSERT INTO	#tmpDLStagingTraderPerformance (CustId, MemberCustId, WorkShift, MatchId, MatchCode, EventDate, SportType, LeagueId, HomeId, AwayId, 
			TeamId, Grade, BetType, Stake, WinLost, SMAWinLost, Comm, BetCount, Spread, ExtraPT, TPositionTaking, VirtualRate, ActualRate, LiveIndicator, BetChoice)
			SELECT	[CustId]			= ISNULL(t.Custid, @IdForUnassignedTrader)
				,	[MemberCustId]		= b.custid
				,	[WorkShift]			= ISNULL(b.WorkShift, 1)
				,	[MatchId]			= b.matchId
				,	[MatchCode]			= b.matchCode
				,	[EventDate]			= b.EventDate
				,	[SportType]			= b.SportType
				,	[LeagueId]			= b.LeagueId
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
				,	[Spread]			= b.Spread
				,	[ExtraPT]			= ISNULL(b.ExtraPT, 0)
				,	[TPositionTaking]	= b.tpositiontaking
				,	[VirtualRate]		= b.virtualrate
				,	[ActualRate]		= b.actualrate
				,	[LiveIndicator]		= b.LiveIndicator
				,	[BetChoice]			= b.BetChoice 
			FROM		#tmpDLFilteredBettransByBatch_Distinct AS b WITH (NOLOCK)
			INNER JOIN #tmpDLSupportedBettypes AS bt WITH(NOLOCK) ON b.BetType = bt.BetType
			LEFT JOIN	#tmpDLTrader AS t WITH (NOLOCK)
					ON	b.winlostdate = t.EventDate
					AND	b.matchId = t.matchId
					AND	(	b.BetType = t.BetType
						OR	(b.bettype = 23 AND t.BetType = 1)
						)
			CROSS APPLY	(
				SELECT	[BetType]	= CASE	WHEN b.BetType = 1 AND b.SpecialType = 0
												THEN 1 --HDP
											WHEN b.BetType = 7
												THEN 7 --1st HDP
											WHEN b.BetType = 3 AND b.SpecialType = 0
												THEN 3 --O/U		
											WHEN b.BetType = 8 AND b.SpecialType = 0
												THEN 8 --1st O/U
											WHEN b.BetType = 2
												THEN 2 --O/E
											WHEN b.BetType = 12
												THEN 12 --1x2
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
											WHEN b.BetType IN (5, 124)
												THEN 5 --1x2	
											WHEN b.BetType IN (15, 125)
												THEN 15 --1st 1x2
											ELSE b.BetType
										END
				) AS ca
			WHERE	b.winlostdate = @winlostdate
			GROUP BY	ISNULL(t.Custid, @IdForUnassignedTrader)
					,	b.custid
					,	ISNULL(b.WorkShift, 1)
					,	b.matchId
					,	b.matchCode
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
					,	b.scomm
					,	b.Spread
					,	ISNULL(b.ExtraPT, 0)
					,	b.tpositiontaking
					,	b.virtualrate
					,	b.actualrate
					,	b.LiveIndicator
					,	b.BetChoice
					,	b.transid -- should not be removed since there is a case that extraPT is changed in the range of time --> duplicate row
					;

			SELECT	@RowCount	= @@ROWCOUNT
				,	@Duration	= DATEDIFF(millisecond, @Begin, GETDATE())
				;

			IF	@Debug = 1
			BEGIN
				-- Force the output to appear immediately
				RAISERROR('From 14 - Insert #tmpDLStagingTraderPerformance - Date: "%s" - %d rows - %d ms', 0, 0, @Date, @RowCount, @Duration) WITH NOWAIT;
			END;

			UPDATE t
			SET t.TeamId = @IDForUnknownTeam
				,	t.Grade = @IDForUnknownGrade
			FROM #tmpDLStagingTraderPerformance AS t WITH(ROWLOCK, UPDLOCK)
			WHERE t.CustId = 0;

			DELETE dbo.TraderPerformance WHERE EventDate = @winlostdate AND Bettype IN (SELECT BetType FROM #tmpDLFilteredBettypes WITH (NOLOCK));

			INSERT INTO	dbo.TraderPerformance (CustId, WorkShift, MatchId, MatchCode, EventDate, SportType, LeagueId, HomeId, AwayId, TeamId, Grade, BetType, IsLive, 
			Stake, WinLost, Comm, Stake_AR, WinLost_AR, Comm_AR, BetCount, Spread)
			SELECT	[CustId]			= t.CustId
				,	[WorkShift]			= t.WorkShift
				,	[MatchId]			= t.matchId
				,	[MatchCode]			= t.matchCode
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
				,	[BetCount]			= SUM(CASE WHEN tc.custid IS NULL THEN t.BetCount ELSE 0 END)
				,	[Spread]			= MAX(t.Spread)
			FROM	#tmpDLStagingTraderPerformance AS t WITH(NOLOCK)
					LEFT JOIN bodb02.dbo.TradeCust tc WITH (NOLOCK) ON t.MemberCustId = tc.custid AND tc.VendorID = 14
			WHERE	t.EventDate = @winlostdate
			GROUP BY t.CustId, t.WorkShift, t.matchId, t.matchCode, t.EventDate, t.SportType, t.LeagueId, t.HomeId, t.AwayId, t.TeamId, t.Grade, t.BetType, t.LiveIndicator;
				
			SELECT	@RowCount	= @@ROWCOUNT
				,	@Duration	= DATEDIFF(millisecond, @Begin, GETDATE())
				;

			IF	@Debug = 1
			BEGIN
				-- Force the output to appear immediately
				RAISERROR('From 14 - Insert TraderPerformance - Date: "%s" - %d rows - %d ms', 0, 0, @Date, @RowCount, @Duration) WITH NOWAIT;
			END;
		
			DELETE dbo.TraderPerformance_BetChoice	WHERE EventDate = @winlostdate AND Bettype IN (SELECT BetType FROM #tmpDLFilteredBettypes WITH (NOLOCK));

			INSERT INTO	dbo.TraderPerformance_BetChoice (CustId, MatchId, EventDate, SportType, LeagueId, BetType, BetChoice, IsLive, Stake, WinLost, Comm, Stake_AR, WinLost_AR, Comm_AR, BetCount)
			SELECT		[CustId]			= t.CustId
					,	[MatchId]			= t.matchId
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
					,	[BetCount]			= SUM(CASE WHEN tc.custid IS NULL THEN t.BetCount ELSE 0 END)
			FROM	#tmpDLStagingTraderPerformance AS t WITH(NOLOCK)
					LEFT JOIN bodb02.dbo.TradeCust tc WITH (NOLOCK) ON t.MemberCustId = tc.custid AND tc.VendorID = 14
			WHERE t.EventDate = @winlostdate AND t.BetChoice IS NOT NULL
			GROUP BY t.CustId, t.matchId, t.EventDate, t.SportType, t.LeagueId, t.BetType, t.BetChoice, t.LiveIndicator;
				
			SELECT	@RowCount	= @@ROWCOUNT
				,	@Duration	= DATEDIFF(millisecond, @Begin, GETDATE())
				;

			IF	@Debug = 1
			BEGIN
				-- Force the output to appear immediately
				RAISERROR('From 14 - Insert TraderPerformance_BetChoice - Date: "%s" - %d rows - %d ms', 0, 0, @Date, @RowCount, @Duration) WITH NOWAIT;
			END;

			DELETE	d
			FROM	#tmpDLwinlostdate AS d
			WHERE	d.winlostdate = @winlostdate;
				
			SELECT	@RowCount	= @@ROWCOUNT
				,	@Duration	= DATEDIFF(millisecond, @Begin, GETDATE())
				;

			IF	@Debug = 1
			BEGIN
				-- Force the output to appear immediately
				RAISERROR('From 14 - DELETE #tmpDLwinlostdate - Date: "%s" - %d rows - %d ms', 0, 0, @Date, @RowCount, @Duration) WITH NOWAIT;
			END;

			TRUNCATE TABLE #tmpDLStagingTraderPerformance;
			TRUNCATE TABLE #tmpDLFilteredBettransByBatch;
			TRUNCATE TABLE #tmpDLFilteredBettransByBatch_Distinct;
		END;
	END;
	
	IF	@IsGetDataFromOrigin = 1
	BEGIN
		TRUNCATE TABLE #tmpDLTrader;
		
		SELECT @Date = '@FromDateOrigin = ' + CONVERT(NVARCHAR, @FromDateOrigin, 120) + ', @ToDateOrigin = ' + CONVERT(NVARCHAR, @ToDateOrigin, 120);

		-- GET Scanned Match List: Completed Soccer Match
		TRUNCATE TABLE #tmpDLScannedMatches;
		INSERT INTO #tmpDLScannedMatches(MatchId, EventDate, KickOffTime,WorkShift, MatchCode, LeagueId, SportType, HomeId, AwayId, LeagueName, HomeName, SpecialType)
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
				LEFT JOIN bodb02.dbo.team AS t WITH (NOLOCK) ON t.teamid = homeid
		WHERE	m.EventDate BETWEEN @FromDateOrigin AND @ToDateOrigin
				AND	m.SportType = 1
				AND m.EventStatus = 'completed'
				AND	m.MatchCode NOT LIKE '%hedge%';
		
		-- REMOVE Scanned Match List: if existing any Ticket has not been settled (ruben <> 1)
		DELETE	sm
		FROM	#tmpDLScannedMatches AS sm WITH (ROWLOCK)
		WHERE	sm.MatchId  IN (	SELECT	TOP(1) b.MatchId
									FROM	bodb02.dbo.bettrans AS b WITH(NOLOCK) 
									WHERE	b.matchid = sm.matchid
											AND b.Currency NOT IN (20, 27, 28)
											AND b.ruben <> 1);		
		
		----Captured Data for Tunning
		INSERT INTO dbo.TracePerformanceScannedMatches(MatchId, EventDate, KickOffTime,WorkShift, MatchCode, LeagueId, SportType, HomeId, AwayId, LeagueName, HomeName, SpecialType, fromSP, CapturedDate)
		SELECT	MatchId
				, EventDate
				, KickOffTime
				, WorkShift
				, MatchCode
				, LeagueId
				, SportType
				, HomeId
				, AwayId
				, LeagueName
				, HomeName
				, SpecialType
				, @FromSP
				, @CapturedDate
		FROM	#tmpDLScannedMatches WITH (NOLOCK);		
		
		----Captured Data for Tunning
		INSERT INTO dbo.TraceScannedMatchesInfo(MatchId, EventDate, Bettype, LiveIndicator, BetCount, SumActualStake, SumComm, SumModds, SumStake, SumVirtualRate, SumWinlost, fromSP, CapturedDate)
		SELECT m.MatchId
				, m.EventDate
				, b.Bettype
				, b.LiveIndicator
				 , BetCount = COUNT(1)
				 , SumActualStake = SUM(b.actual_stake)
				 , SumComm = SUM(b.Comm)
				 , SumModds = SUM(b.Modds)
				 , SumStake = SUM(b.Stake)
				 , SumVirtualRate = SUM(b.VirtualRate)
				 , SumWinlost = SUM(b.winlost)
				 , @FromSP
				 , @CapturedDate
		FROM	#tmpDLScannedMatches m WITH (NOLOCK)
				INNER JOIN bodb02.dbo.bettrans b WITH (NOLOCK) ON b.matchid = m.matchid
		WHERE	b.winlostdate BETWEEN @FromDateOrigin AND @ToDateOrigin
		GROUP BY  m.MatchId,  m.EventDate,  b.Bettype, b.LiveIndicator
		
		INSERT INTO	#tmpDLTrader (CustId, LeagueId, MatchId, EventDate, BetType, TraderBettype, OperatorType, MainDBBetType, TeamId, Grade)
		SELECT	DISTINCT
				[CustId]		= a.OperatorID
			,	[LeagueId]		= m.LeagueId
			,	[MatchId]		= m.MatchId
			,	[EventDate]		= m.EventDate
			,	[BetType]		= CASE	WHEN a.bettype = 5 AND a.operatortype = 1
											THEN 1
										ELSE ISNULL(b.MainDBBetType, 0) 
									END
			,	[TraderBettype] = a.bettype
			,	[OperatorType]	= a.operatortype
			,	[MainDBBetType] = b.MainDBBetType
			,	[TeamId]		= td_T.TeamId
			,	[Grade]			= td_G.Grade
		FROM		bodb02.dbo.Dot_admin_Assignment_Operator AS a WITH (NOLOCK)
		INNER JOIN	#tmpDLScannedMatches AS m WITH (NOLOCK) ON m.MatchId = a.Matchid
		LEFT JOIN	dbo.BetType AS b WITH(NOLOCK)
				ON	a.bettype = b.AssignmentBetType
				AND	a.OperatorType = b.OperatorType
		LEFT JOIN	dbo.TraderGrade_History AS td_G WITH (NOLOCK)
				ON	td_G.CustID = a.OperatorID
				AND	m.EventDate BETWEEN td_G.BeginDate AND ISNULL(td_G.EndDate, @Today + 10)
		LEFT JOIN	dbo.TraderTeam_History AS td_T WITH (NOLOCK)
				ON	td_T.CustID = a.OperatorID
				AND	m.EventDate BETWEEN td_T.BeginDate AND ISNULL(td_T.EndDate, @Today + 10)
		WHERE	m.EventDate BETWEEN @FromDateOrigin AND @ToDateOrigin
			AND	a.OperatorType < 3;
		
		SELECT	@RowCount	= @@ROWCOUNT
			,	@Duration	= DATEDIFF(millisecond, @Begin, GETDATE())
			;
		
		IF	@Debug = 1
		BEGIN
			-- Force the output to appear immediately
			RAISERROR('From Origin - Insert #tmpDLTrader - Date: "%s" - %d rows - %d ms', 0, 0, @Date, @RowCount, @Duration) WITH NOWAIT;
		END;

		----Captured Data for Tunning
		INSERT INTO dbo.TracePerformanceTrader(CustId, LeagueId, MatchId, EventDate, BetType, TraderBettype, OperatorType, MainDBBetType, TeamId, Grade, fromSP, CapturedDate)
		SELECT CustId, LeagueId, MatchId, EventDate, BetType, TraderBettype, OperatorType, MainDBBetType, TeamId, Grade, @fromSP, @CapturedDate
		FROM	#tmpDLTrader WITH (NOLOCK);
		
		INSERT INTO	#tmpDLwinlostdate (winlostdate)
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
		BEGIN
			-- Force the output to appear immediately
			RAISERROR('From Origin - Insert #tmpDLwinlostdate - Date: "%s" - %d rows - %d ms', 0, 0, @Date, @RowCount, @Duration) WITH NOWAIT;
		END;

		-- No input date range: Default job run
		IF (@IsRunningJob = 1)
		BEGIN
			INSERT INTO dbo.Staging_EventDate (EventDate)
			SELECT winlostdate FROM #tmpDLwinlostdate WITH(NOLOCK)

			SELECT	@RowCount	= @@ROWCOUNT
				,	@Duration	= DATEDIFF(millisecond, @Begin, GETDATE())
				;

			IF	@Debug = 1
			BEGIN
				-- Force the output to appear immediately --
				RAISERROR('From Origin - Insert Staging_EventDate - %d rows - %d ms', 0, 0, @RowCount, @Duration) WITH NOWAIT;
			END;
		END;

		-- SUM(ExtraPT)
		TRUNCATE TABLE	#ExtraPTSportbook;
		INSERT INTO #ExtraPTSportbook
		SELECT SuperId, SUM(ExtraPT) AS ExtraPT, FromDate, ToDate
		FROM
		(
			SELECT SuperId, ExtraPT, FromDate, ToDate
			FROM bodb02.dbo.Acc_GroupExtraPTSetting WITH (NOLOCK)
			WHERE
				(
					@FromDateOrigin BETWEEN FromDate AND ToDate
					OR @ToDateOrigin BETWEEN FromDate AND ToDate
				)
				AND ProductId = 1 AND Sporttype = 0 AND SubProduct = ''
		) A
		GROUP BY SuperId, FromDate, ToDate;

		WHILE	EXISTS (SELECT 1 FROM #tmpDLwinlostdate WITH(NOLOCK))
		BEGIN
			SELECT	TOP(1)
					@WinLostDate = d.winlostdate
			FROM	#tmpDLwinlostdate AS d WITH(NOLOCK);
			
			SELECT @Date = CONVERT(NVARCHAR, @winlostdate, 120);

			TRUNCATE TABLE	#tmpDLFilteredBettransByBatch;
			INSERT INTO	#tmpDLFilteredBettransByBatch (transid, custid, matchid, workshift, specialType, winlostdate, bettype, modds, 
						virtualrate, actualrate, tpositiontaking, srecommend, scomm, ExtraPT, Spread, Stake, WinLost, SMAWinLost, MatchCode, EventDate, SportType, 
						LeagueId, HomeId, AwayId, LiveIndicator, BetChoice)
			SELECT	[transid]			= b.transid
				,	[custid]			= b.custid
				,	[matchid]			= b.matchid
				,	[workshift]			= m.WorkShift
				,	[specialType]		= m.SpecialType
				,	[winlostdate]		= b.winlostdate
				,	[bettype]			= CASE	WHEN b.bettype = 1308
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
				,	[modds]				= b.modds
				,	[virtualrate]		= b.virtualrate
				,	[actualrate]		= b.actualrate
				,	[tpositiontaking]	= b.tpositiontaking
				,	[srecommend]		= b.srecommend
				,	[scomm]				= b.scomm
				,	[ExtraPT]			= es.ExtraPT
				,	[Spread]			= CASE WHEN mm.BetType IN (5, 15) THEN ISNULL(s.Spread, - (4 / mm.Spread - 4)) ELSE mm.Spread END
				,	[Stake]				= CASE WHEN b.modds = 0.25 OR b.modds = - 0.25 THEN ABS(b.stake) / 2 ELSE ABS(b.stake) END
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
			INNER JOIN	#tmpDLScannedMatches AS m WITH (NOLOCK)
					ON	b.matchid = m.matchid
			LEFT JOIN	#ExtraPTSportbook AS es WITH (NOLOCK)
					ON	es.SuperId = b.srecommend
					AND	b.winlostdate BETWEEN es.FromDate AND es.ToDate
			LEFT JOIN	bodb02.dbo.MatchMaxbet AS mm WITH (NOLOCK)
					ON	mm.MatchId = b.matchid
					AND	mm.BetType = b.bettype
			LEFT JOIN	#tmpDLSpread1x2 AS s
					ON	mm.Spread = s.Margin
					AND	mm.BetType IN (5, 15)
			WHERE	b.winlostdate = @winlostdate
				AND	b.statusID IN (112, 113)
				AND	b.Currency NOT IN (20, 27, 28)
				AND b.bettype IN (SELECT BetType FROM #tmpDLFilteredBettypes WITH (NOLOCK));
			
			SELECT	@RowCount	= @@ROWCOUNT
				,	@Duration	= DATEDIFF(millisecond, @Begin, GETDATE())
				;

			IF	@Debug = 1
			BEGIN
				-- Force the output to appear immediately
				RAISERROR('From Origin - Insert #tmpDLFilteredBettransByBatch - Date: "%s" - %d rows - %d ms', 0, 0, @Date, @RowCount, @Duration) WITH NOWAIT;
			END;

				-- "DISTINCT" Prevent Page Splits
			TRUNCATE TABLE	#tmpDLFilteredBettransByBatch_Distinct;
			INSERT INTO	#tmpDLFilteredBettransByBatch_Distinct (transid, custid, matchid, workshift, specialType, winlostdate, bettype, modds, 
						virtualrate, actualrate, tpositiontaking, srecommend, scomm, ExtraPT, Spread, Stake, WinLost, SMAWinLost, MatchCode, EventDate, SportType, 
						LeagueId, HomeId, AwayId, LiveIndicator, BetChoice)
			SELECT	DISTINCT transid, custid, matchid, workshift, specialType, winlostdate, bettype, modds, 
						virtualrate, actualrate, tpositiontaking, srecommend, scomm, ExtraPT, Spread, Stake, WinLost, SMAWinLost, MatchCode, EventDate, SportType, 
						LeagueId, HomeId, AwayId, LiveIndicator, BetChoice
			FROM	#tmpDLFilteredBettransByBatch WITH(NOLOCK);
			
			INSERT INTO	#tmpDLStagingTraderPerformance (CustId, MemberCustId, WorkShift, MatchId, MatchCode, EventDate, SportType, LeagueId, HomeId, AwayId, 
			TeamId, Grade, BetType, Stake, WinLost, SMAWinLost, Comm, BetCount, Spread, ExtraPT, TPositionTaking, VirtualRate, ActualRate, LiveIndicator, BetChoice)
			SELECT	[CustId]			= ISNULL(t.Custid, @IdForUnassignedTrader)
				,	[MemberCustId]		= b.custid
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
				,	[WinLost]			= b.WinLost
				,	[SMAWinLost]		= b.SMAWinLost
				,	[Comm]				= b.scomm --Commission
				,	[BetCount]			= 1 --Live BetCount
				,	[Spread]			= b.Spread
				,	[ExtraPT]			= ISNULL(b.ExtraPT, 0)
				,	[TPositionTaking]	= b.tpositiontaking
				,	[VirtualRate]		= b.virtualrate
				,	[ActualRate]		= b.actualrate
				,	[LiveIndicator]		= b.LiveIndicator
				,	[BetChoice]			= b.BetChoice 
			FROM		#tmpDLFilteredBettransByBatch_Distinct AS b WITH (NOLOCK)
			INNER JOIN #tmpDLSupportedBettypes AS bt WITH(NOLOCK) ON b.BetType = bt.BetType
			LEFT JOIN	#tmpDLTrader AS t WITH (NOLOCK)
					ON	b.winlostdate = t.EventDate
					AND	b.matchid = t.matchid
					AND	(	b.BetType = t.BetType
						OR	(b.bettype = 23 AND t.BetType = 1)
						)
			CROSS APPLY	(
				SELECT	[BetType]	= CASE	WHEN b.BetType = 1 AND b.SpecialType = 0
												THEN 1 --HDP
											WHEN b.BetType = 7
												THEN 7 --1st HDP
											WHEN b.BetType = 3 AND b.SpecialType = 0
												THEN 3 --O/U		
											WHEN b.BetType = 8 AND b.SpecialType = 0
												THEN 8 --1st O/U
											WHEN b.BetType = 2
												THEN 2 --O/E
											WHEN b.BetType = 12
												THEN 12 --1x2
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
											WHEN b.BetType IN (5, 124)
												THEN 5 --1x2	
											WHEN b.BetType IN (15, 125)
												THEN 15 --1st 1x2
											ELSE b.BetType
										END
				) AS ca
			WHERE	b.winlostdate = @winlostdate
			GROUP BY	ISNULL(t.Custid, @IdForUnassignedTrader)
					,	b.custid
					,	ISNULL(b.WorkShift, 1)
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
					,	b.scomm
					,	b.Spread
					,	ISNULL(b.ExtraPT, 0)
					,	b.tpositiontaking
					,	b.virtualrate
					,	b.actualrate
					,	b.LiveIndicator
					,	b.BetChoice
					,	b.transid -- should not be removed since there is a case that extraPT is changed in the range of time --> duplicate row
					;

			SELECT	@RowCount	= @@ROWCOUNT
				,	@Duration	= DATEDIFF(millisecond, @Begin, GETDATE())
				;

			IF	@Debug = 1
			BEGIN
				-- Force the output to appear immediately
				RAISERROR('From Origin - Insert #tmpDLStagingTraderPerformance - Date: "%s" - %d rows - %d ms', 0, 0, @Date, @RowCount, @Duration) WITH NOWAIT;
			END;

			UPDATE t
			SET t.TeamId = @IDForUnknownTeam
				,	t.Grade = @IDForUnknownGrade
			FROM #tmpDLStagingTraderPerformance AS t WITH(ROWLOCK, UPDLOCK)
			WHERE t.CustId = 0;

			DELETE dbo.TraderPerformance WHERE EventDate = @winlostdate AND Bettype IN (SELECT BetType FROM #tmpDLFilteredBettypes WITH (NOLOCK));

			INSERT INTO	dbo.TraderPerformance (CustId, WorkShift, MatchId, MatchCode, EventDate, SportType, LeagueId, HomeId, AwayId, TeamId, Grade, BetType, IsLive, 
			Stake, WinLost, Comm, Stake_AR, WinLost_AR, Comm_AR, BetCount, Spread)
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
				,	[Stake]				= SUM(t.Stake * (1 - t.TPositionTaking - t.ExtraPT) * t.VirtualRate)
				,	[WinLost]			= SUM(((-(t.WinLost + t.SMAWinLost)) + t.WinLost * t.ExtraPT) * t.VirtualRate)
				,	[Comm]				= SUM((t.Comm - (CASE WHEN t.TPositionTaking = 1 THEN 0 ELSE (t.Comm * t.ExtraPT/(1 - t.TPositionTaking)) END)) * (CASE WHEN t.VirtualRate > t.ActualRate THEN t.ActualRate ELSE t.VirtualRate END))
				,	[Stake_AR]			= SUM(t.Stake * (1 - t.TPositionTaking - t.ExtraPT) * (CASE WHEN t.VirtualRate > t.ActualRate THEN t.VirtualRate ELSE t.ActualRate END))
				,	[WinLost_AR]		= SUM(((-(t.WinLost + t.SMAWinLost)) + t.WinLost * t.ExtraPT) * t.ActualRate)
				,	[Comm_AR]			= SUM((t.Comm - (CASE WHEN t.TPositionTaking = 1 THEN 0 ELSE (t.Comm * t.ExtraPT/(1 - t.TPositionTaking)) END)) * t.ActualRate)
				,	[BetCount]			= SUM(CASE WHEN tc.custid IS NULL THEN t.BetCount ELSE 0 END)
				,	[Spread]			= MAX(t.Spread)
			FROM	#tmpDLStagingTraderPerformance AS t WITH(NOLOCK) 
					LEFT JOIN bodb02.dbo.TradeCust tc WITH (NOLOCK) ON t.MemberCustId = tc.custid AND tc.VendorID = 14
			WHERE	t.EventDate = @winlostdate
			GROUP BY t.CustId, t.WorkShift, t.MatchId, t.MatchCode, t.EventDate, t.SportType, t.LeagueId, t.HomeId, t.AwayId, t.TeamId, t.Grade, t.BetType, t.LiveIndicator;
				
			SELECT	@RowCount	= @@ROWCOUNT
				,	@Duration	= DATEDIFF(millisecond, @Begin, GETDATE())
				;

			IF	@Debug = 1
			BEGIN
				-- Force the output to appear immediately
				RAISERROR('From Origin - Insert TraderPerformance - Date: "%s" - %d rows - %d ms', 0, 0, @Date, @RowCount, @Duration) WITH NOWAIT;
			END;
		
			DELETE dbo.TraderPerformance_BetChoice	WHERE EventDate = @winlostdate AND Bettype IN (SELECT BetType FROM #tmpDLFilteredBettypes WITH (NOLOCK));

			INSERT INTO	dbo.TraderPerformance_BetChoice (CustId, MatchId, EventDate, SportType, LeagueId, BetType, BetChoice, IsLive, Stake, WinLost, Comm, Stake_AR, WinLost_AR, Comm_AR, BetCount)
			SELECT		[CustId]			= t.CustId
					,	[MatchId]			= t.matchId
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
					,	[BetCount]			= SUM(CASE WHEN tc.custid IS NULL THEN t.BetCount ELSE 0 END)
			FROM	#tmpDLStagingTraderPerformance AS t WITH(NOLOCK) 
					LEFT JOIN bodb02.dbo.TradeCust tc WITH (NOLOCK) ON t.MemberCustId = tc.custid AND tc.VendorID = 14
			WHERE t.EventDate = @winlostdate AND t.BetChoice IS NOT NULL
			GROUP BY t.CustId, t.MatchId, t.EventDate, t.SportType, t.LeagueId, t.BetType, t.BetChoice, t.LiveIndicator;
				
			SELECT	@RowCount	= @@ROWCOUNT
				,	@Duration	= DATEDIFF(millisecond, @Begin, GETDATE())
				;

			IF	@Debug = 1
			BEGIN
				-- Force the output to appear immediately
				RAISERROR('From Origin - Insert TraderPerformance_BetChoice - Date: "%s" - %d rows - %d ms', 0, 0, @Date, @RowCount, @Duration) WITH NOWAIT;
			END;

			DELETE	d
			FROM	#tmpDLwinlostdate AS d
			WHERE	d.winlostdate = @winlostdate;
				
			SELECT	@RowCount	= @@ROWCOUNT
				,	@Duration	= DATEDIFF(millisecond, @Begin, GETDATE())
				;

			IF	@Debug = 1
			BEGIN
				-- Force the output to appear immediately
				RAISERROR('From Origin - DELETE #tmpDLwinlostdate - Date: "%s" - %d rows - %d ms', 0, 0, @Date, @RowCount, @Duration) WITH NOWAIT;
			END;

			TRUNCATE TABLE #tmpDLStagingTraderPerformance;
			TRUNCATE TABLE #tmpDLFilteredBettransByBatch;
			TRUNCATE TABLE #tmpDLFilteredBettransByBatch_Distinct;
		END;
	END;
END;

GO
/*<info serverAlias="DBTGRS-bodb_TGRS" executers="bodbTGRSNet" isFunction="0" isNested="0"></info>*/