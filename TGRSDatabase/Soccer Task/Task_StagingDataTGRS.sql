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
	DB:			DB06.bodb_TGRS_UAT & DB061.bodb_TGRS
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
		- 20190822@Long.Luu: Grade brokendown for details performance [Redmine ID: 117030]
		- 20190822@Long.Luu: Suppport Non-Live Data [Redmine ID: 118959]
		- 20200331@John.Ngo: Update new table [Dot_Admin_Assignment_Trader] [Redmine ID: 120634]
		- 20200416@John.Ngo: [TGR] Extend league data type [Redmine ID: 132630]
		- 20200429@John.Ngo: [TGR] Get ExtraPT from epositiontaking column in bettrans table [Redmine ID: 133409]
		- 20200721@John.Ngo: New Negative Bettype No Of Corner HDP [Redmine ID: 138095]
		- 20201017@John.Ngo: TGR - Integrate Adjustmnet Odds Spread of Licensee [Redmine ID: 142421]
		- 20201112@John.Ngo: TGR - Enhance formula of calculating adjusted odds by Licensee [Redmine ID: 145246]
   		- 20210726@Adam.Tran: TGR - Sports - Performance Real Figures [Redmine: #158981]
		- 20210916@John.Ngo: Add Fast Market Bettype [Redmine: #157999]
		- 20220117@John.Ngo: Support view down for Total Goal, Time Machine and Corner bettype [Redmine: #166679]
		- 20220222@John.Ngo: Ignore wrong xml data in bettrans_bk (Transid: 111674398151) [Redmine: #161859]
		- 20230103@John.Ngo: Fix Odds Spread Setting - ReCalculate Original Winlost [Redmine ID: 182351]
		- 20240217@Jaden.Tang: Remove TradeCust table (#206895)
		- 20250611@Jaden.Tang: Re-allow hedge match (#227903)
		- 20250409@Jaden.Tang: Add VarianceVR for TGRS Staging Data [Redmine ID: #213765]
		- 20250707@Jaden.Tang: Add SiteID for TGRS Staging Data [Redmine ID: #231812]
		
	Param's Explanation:
		- @Bettype = 0: All bettype
	Exam:
	 
*/
BEGIN
	SET NOCOUNT ON;

	-- Common variables
	DECLARE	@IdForLiveUnassignedTrader		INT = 0
		,	@IdForNonLiveUnassignedTrader	INT = -1;

	DECLARE	@Begin					DATETIME = GETDATE()
		,	@RowCount				INT
		,	@Duration				INT
		,	@Msg					NVARCHAR(MAX)
		,	@Date					NVARCHAR(250)
		,	@DotExtraPTDate			DATETIME = '20200213'
		;

	DECLARE @BalanceUpDay			SMALLDATETIME
		,	@MoveBetsDay			SMALLDATETIME
		,	@Yesterday				SMALLDATETIME
		,	@Today					SMALLDATETIME
		,	@Winlostdate			DATETIME
		;
	
	-- Check running job
	DECLARE @IsRunningJob				BIT;
	
	IF (@GenerateFromDate IS NULL OR @GenerateToDate IS NULL)
	BEGIN
		SELECT @IsRunningJob = 1;
	END;
	--

	IF	OBJECT_ID('tempdb..#tmpDLSupportedBettypes') IS NOT NULL
		DROP TABLE	#tmpDLSupportedBettypes;

	CREATE TABLE	#tmpDLSupportedBettypes (
			BetType					SMALLINT PRIMARY KEY
		,	IsBetChoiceDetail		BIT DEFAULT ((0))
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

	INSERT INTO #tmpDLSupportedBettypes(BetType, IsBetChoiceDetail)
	SELECT	DISTINCT b.bettype, b.IsBetChoiceDetail
	FROM	dbo.BetType AS b WITH (NOLOCK)
	WHERE	b.BetType > 0;

	DECLARE @tmpDLSpread1x2 TABLE (
			Margin					MONEY
		,	Spread					MONEY
	);
						
	INSERT INTO	@tmpDLSpread1x2 (Margin, Spread)
	VALUES	(1.05  , 0.2   )
		,	(1.08  , 0.3   )
		,	(1.10  , 0.36  )
		,	(1.12  , 0.44  )
		,	(1.15  , 0.52  )
		;
				
	-- BU & MB
	DECLARE @tmpDLBUMBData TABLE (
			BUDay	SMALLDATETIME
		,	MBDay	SMALLDATETIME
	);

	INSERT INTO @tmpDLBUMBData(BUDay,MBDay)
	EXECUTE bodb02.dbo.Age_SelBalanceUpDay;

	SELECT	TOP(1)
			@BalanceUpDay	= BUDay
		,	@MoveBetsDay	= MBDay
	FROM @tmpDLBUMBData;

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
			  MatchId		INT NOT NULL PRIMARY KEY CLUSTERED
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
	
	CREATE NONCLUSTERED INDEX #IX_tmpDLScannedMatches_EventDate ON #tmpDLScannedMatches (
		EventDate	ASC
	);

	IF	OBJECT_ID('tempdb..#tmpDLTrader') IS NOT NULL
	BEGIN
		DROP TABLE #tmpDLTrader;
	END;

	CREATE TABLE	#tmpDLTrader (
			TraderId			INT
		,	LeagueId			INT
		,	MatchId				INT
		,	EventDate			DATETIME
		,	BetType				INT
		,	TeamId				INT
		,	Grade				TINYINT
	);

	CREATE CLUSTERED INDEX	#CIX_tmpDLTraderIdx ON #tmpDLTrader (
			EventDate			ASC
		,	MatchId				ASC
		,	BetType				ASC
	);

	IF	OBJECT_ID('tempdb..#tmpDLTraderbk') IS NOT NULL
		BEGIN
			DROP TABLE #tmpDLTraderbk;
		END;

		CREATE TABLE	#tmpDLTraderbk (
				TraderId			INT
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

		CREATE CLUSTERED INDEX	#CIX_tmpDLTraderbkIdx ON #tmpDLTraderbk (
				EventDate			ASC
			,	MatchId				ASC
			,	BetType				ASC
		);
		
	IF	OBJECT_ID('tempdb..#tmp8RMMembers') IS NOT NULL
		BEGIN
			DROP TABLE #tmp8RMMembers;
		END;

	CREATE TABLE	#tmp8RMMembers (
			CustId			INT PRIMARY KEY CLUSTERED
	);

	IF	OBJECT_ID('tempdb..#tmpDLwinlostdate') IS NOT NULL
	BEGIN
		DROP TABLE	#tmpDLwinlostdate;
	END;

	CREATE TABLE	#tmpDLwinlostdate (
		Winlostdate				DATE
	);

	IF	OBJECT_ID('tempdb..#ExtraPTSportbook') IS NOT NULL
	BEGIN
		DROP TABLE	#ExtraPTSportbook;
	END;

	CREATE TABLE #ExtraPTSportbook
	(
			SuperId		INT
		,	ExtraPT		MONEY
		,	FromDate	DATETIME
		,	ToDate		DATETIME
	);

	IF	OBJECT_ID('tempdb..#tmpDLFilteredBettransByBatch') IS NOT NULL
	BEGIN
		DROP TABLE	#tmpDLFilteredBettransByBatch;
	END;

	CREATE TABLE	#tmpDLFilteredBettransByBatch (
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
	
	CREATE CLUSTERED INDEX #IX_tmpDLFilteredBettransByBatchIdx ON #tmpDLFilteredBettransByBatch (
			Winlostdate			ASC
		,	MatchId				ASC
		,	BetType				ASC
	);

	CREATE NONCLUSTERED INDEX #CIX_tmpDLFilteredBettransByBatch_CustIdIdx ON #tmpDLFilteredBettransByBatch (
			CustId				ASC
	);

	IF	OBJECT_ID('tempdb..#tmpDLStagingTraderPerformance') IS NOT NULL
	BEGIN
		DROP TABLE	#tmpDLStagingTraderPerformance;
	END;

	CREATE TABLE	#tmpDLStagingTraderPerformance (
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
		,	SiteID				INT NULL -- Added SiteID
	);
	
	CREATE CLUSTERED INDEX #CIX_tmpDLStagingTraderPerformanceIdx ON #tmpDLStagingTraderPerformance (
			EventDate			ASC
	); 

	CREATE NONCLUSTERED INDEX #IX_tmpDLStagingTraderPerformance_CustIdIdx ON #tmpDLStagingTraderPerformance (
			CustId				ASC
	);

	-- customers in bodb02 frequently get deleted due to inactivity, need to get missing data from DW (bk range)
	-- note that this run slowly, so for large batch, we should use an adhoc customer table
	CREATE TABLE #tmpHistoryCustomer (CustID INT PRIMARY KEY CLUSTERED, [Site] VARCHAR(200));
	-- support vairables for performance
	DECLARE @MinDWCustID INT, @MaxDWCustID INT

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
	
	DECLARE @Odds		FLOAT
		,	@winlost	MONEY
		,	@UpdateById TINYINT = 1; -- 1: by odds, 2: by winlost

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
				END;
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

	-- Compute the date range for origin, 14, & bk if any (You guys should not touch here)
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
		TRUNCATE TABLE dbo.TrackChangesOnMatches_Queue;
		DECLARE @OldCapturedDate DATETIME = GETDATE();
		
		INSERT INTO dbo.TrackChangesOnMatches_Queue(MatchId, EventDate, SportType, BetType, OldCapturedDate, OldTraderID, OldTurnOver, OldWinlost, OldBetCount)
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
			,	tp.BetType	
			;

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
	
	INSERT INTO #tmp8RMMembers(CustId)
	SELECT c.custid
	FROM bodb02.dbo.custInfo AS c WITH(NOLOCK)
	WHERE c.recommend = 52466;

	IF	@IsGetDataFromBK = 1
	BEGIN
		TRUNCATE TABLE #tmpDLTrader;
		TRUNCATE TABLE #tmpDLScannedMatches;
		TRUNCATE TABLE #ExtraPTSportbook;
		
		SELECT @Date = '@FromDateBK = ' + CONVERT(NVARCHAR, @FromDateBK, 120) + ', @ToDateBK = ' + CONVERT(NVARCHAR, @ToDateBK, 120);

		-- GET Scanned Match List: Completed Soccer Match
		INSERT INTO #tmpDLScannedMatches(MatchId, EventDate, KickOffTime,WorkShift, MatchCode, LeagueId, SportType, HomeId, AwayId, LeagueName, HomeName, SpecialType)
		SELECT	  m.matchid
				, m.eventdate
				, m.kickofftime
	 			, CASE	WHEN CAST(m.kickofftime AS TIME) >= '00:00:00' AND CAST(m.kickofftime AS TIME) < '06:00:00'
								THEN 1 --  Afternoon: 12:00:00 ~ 17:59:59 (GMT + 8)
							WHEN CAST(m.kickofftime AS TIME) >= '06:00:00' AND CAST(m.kickofftime AS TIME) < '16:00:00'
								THEN 2 -- Night: 18:00:00 ~ 3:59:59 (GMT + 8)				
							--WHEN CAST(m.kickofftime AS TIME) >= '16:00:00' AND CAST(m.kickofftime AS TIME) <'24:00:00'THEN 3 --  Midnight: 4:00:00 ~ 11:59:59 (GMT + 8)
							ELSE 3
				  END AS WorkShift
				, m.MatchCode
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
				AND m.EventStatus = 'completed';
		
		IF @DotExtraPTDate <= @FromDateBK
		BEGIN
			INSERT INTO	#tmpDLTraderbk (TraderId, LeagueId, MatchId, EventDate, BetType, TeamId, Grade)
			SELECT	DISTINCT
					[TraderId]		= a.TraderID
				,	[LeagueId]		= m.LeagueId
				,	[MatchId]		= m.MatchId
				,	[EventDate]		= m.EventDate
				,	[BetType]		= a.BetType
				,	[TeamId]		= td_T.TeamId
				,	[Grade]			= td_G.Grade
			FROM	bodb_archive.dbo.Dot_Admin_Assignment_Trader_bk AS a WITH (NOLOCK)
				INNER JOIN #tmpDLScannedMatches AS m WITH (NOLOCK) ON m.matchId = a.matchId
				INNER JOIN #tmpDLFilteredBettypes AS b WITH (NOLOCK) ON b.BetType = a.bettype
				LEFT JOIN dbo.TraderGrade_History AS td_G WITH (NOLOCK) ON td_G.CustID = a.TraderID
						AND	m.EventDate BETWEEN td_G.BeginDate AND ISNULL(td_G.EndDate, @Today + 10)
				LEFT JOIN dbo.TraderTeam_History AS td_T WITH (NOLOCK) ON	td_T.CustID = a.TraderID
						AND	m.EventDate BETWEEN td_T.BeginDate AND ISNULL(td_T.EndDate, @Today + 10)
				CROSS APPLY (
							SELECT dt.TraderID, dt.MatchId, dt.Bettype,
								ROW_NUMBER() OVER(PARTITION BY dt.MatchId, dt.Bettype ORDER BY dt.UpdatedTime DESC, dt.ID DESC) AS Row_Num
							FROM bodb_archive.dbo.Dot_Admin_Assignment_Trader_bk AS dt WITH (NOLOCK)
							WHERE   a.matchid = dt.matchid
								AND a.bettype = dt.bettype		
								AND a.TraderId <> 0
							) dat
			WHERE	m.EventDate BETWEEN @FromDateBK AND @ToDateBK
					AND a.TraderId <> 0
					AND a.TraderID = dat.TraderID
					AND a.MatchId = dat.MatchId
					AND a.Bettype = dat.Bettype
					AND dat.Row_Num = 1;	
		
			SELECT	@RowCount	= @@ROWCOUNT
				,	@Duration	= DATEDIFF(millisecond, @Begin, GETDATE())
				;

			IF	@Debug = 1
			BEGIN
				-- Force the output to appear immediately
				RAISERROR('From BK - Insert #tmpDLTraderbk - Date: "%s" - %d rows - %d ms', 0, 0, @Date, @RowCount, @Duration) WITH NOWAIT;
			END;
		END;

		IF @DotExtraPTDate > @FromDateBK AND @DotExtraPTDate <= @ToDateBK
		BEGIN
			SELECT @Date = '@FromDateBK = ' + CONVERT(NVARCHAR, @FromDateBK, 120) + ', (@DotExtraPTDate - 1) = ' + CONVERT(NVARCHAR, (@DotExtraPTDate - 1), 120);

			INSERT INTO	#tmpDLTraderbk (TraderId, LeagueId, MatchId, EventDate, BetType, TraderBettype, OperatorType, MainDBBetType, TeamId, Grade)
			SELECT	DISTINCT
					[TraderId]		= a.OperatorID
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
			FROM		bodb_archive.dbo.Dot_Admin_Assignment_Operator_bk AS a WITH (NOLOCK)
			INNER JOIN	#tmpDLScannedMatches AS m WITH (NOLOCK) ON m.MatchId = a.matchId
			LEFT JOIN	dbo.BetType AS b WITH(NOLOCK) ON a.bettype = b.AssignmentBetType
					AND	a.OperatorType = b.OperatorType
			LEFT JOIN	dbo.TraderGrade_History AS td_G WITH (NOLOCK) ON td_G.CustID = a.OperatorID
					AND	m.EventDate BETWEEN td_G.BeginDate AND ISNULL(td_G.EndDate, @Today + 10)
			LEFT JOIN	dbo.TraderTeam_History AS td_T WITH (NOLOCK) ON	td_T.CustID = a.OperatorID
					AND	m.EventDate BETWEEN td_T.BeginDate AND ISNULL(td_T.EndDate, @Today + 10)
			WHERE	m.EventDate BETWEEN @FromDateBK AND (@DotExtraPTDate - 1)
				AND	a.OperatorType < 3;
		
			SELECT	@RowCount	= @@ROWCOUNT
				,	@Duration	= DATEDIFF(millisecond, @Begin, GETDATE())
				;

			IF	@Debug = 1
			BEGIN
				-- Force the output to appear immediately
				RAISERROR('From BK - Insert #tmpDLTraderbk - Date: "%s" - %d rows - %d ms', 0, 0, @Date, @RowCount, @Duration) WITH NOWAIT;
			END;

			-- SUM(ExtraPT)
			INSERT INTO #ExtraPTSportbook
			SELECT SuperId, SUM(ExtraPT) AS ExtraPT, FromDate, ToDate
			FROM
			(
				SELECT SuperId, ExtraPT, FromDate, ToDate
				FROM bodb02.dbo.Acc_GroupExtraPTSetting WITH (NOLOCK)
				WHERE ( @FromDateBK BETWEEN FromDate AND ToDate
						OR (@DotExtraPTDate - 1) BETWEEN FromDate AND ToDate )
						AND ProductId = 1 AND Sporttype = 0 AND SubProduct = ''
			) A
			GROUP BY SuperId, FromDate, ToDate;

			SELECT @Date = '@DotExtraPTDate = ' + CONVERT(NVARCHAR, @DotExtraPTDate, 120) + ', @ToDateBK = ' + CONVERT(NVARCHAR, @ToDateBK, 120);

			INSERT INTO	#tmpDLTraderbk (TraderId, LeagueId, MatchId, EventDate, BetType, TeamId, Grade)
			SELECT	DISTINCT
					[TraderId]		= a.TraderID
				,	[LeagueId]		= m.LeagueId
				,	[MatchId]		= m.MatchId
				,	[EventDate]		= m.EventDate
				,	[BetType]		= a.BetType
				,	[TeamId]		= td_T.TeamId
				,	[Grade]			= td_G.Grade
			FROM	bodb_archive.dbo.Dot_Admin_Assignment_Trader_bk AS a WITH (NOLOCK)
				INNER JOIN #tmpDLScannedMatches AS m WITH (NOLOCK) ON m.matchId = a.matchId
				INNER JOIN #tmpDLFilteredBettypes AS b WITH (NOLOCK) ON b.BetType = a.bettype
				LEFT JOIN dbo.TraderGrade_History AS td_G WITH (NOLOCK) ON td_G.CustID = a.TraderID
						AND	m.EventDate BETWEEN td_G.BeginDate AND ISNULL(td_G.EndDate, @Today + 10)
				LEFT JOIN dbo.TraderTeam_History AS td_T WITH (NOLOCK) ON	td_T.CustID = a.TraderID
						AND	m.EventDate BETWEEN td_T.BeginDate AND ISNULL(td_T.EndDate, @Today + 10)
				CROSS APPLY (
							SELECT dt.TraderID, dt.MatchId, dt.Bettype,
								ROW_NUMBER() OVER(PARTITION BY dt.MatchId, dt.Bettype ORDER BY dt.UpdatedTime DESC, dt.ID DESC) AS Row_Num
							FROM bodb_archive.dbo.Dot_Admin_Assignment_Trader_bk AS dt WITH (NOLOCK)
							WHERE   a.matchid = dt.matchid
								AND a.bettype = dt.bettype		
								AND a.TraderId <> 0
							) dat
			WHERE	m.EventDate BETWEEN @DotExtraPTDate AND @ToDateBK
					AND a.TraderId <> 0
					AND a.TraderID = dat.TraderID
					AND a.MatchId = dat.MatchId
					AND a.Bettype = dat.Bettype
					AND dat.Row_Num = 1;
		
			SELECT	@RowCount	= @@ROWCOUNT
				,	@Duration	= DATEDIFF(millisecond, @Begin, GETDATE())
				;

			IF	@Debug = 1
			BEGIN
				-- Force the output to appear immediately
				RAISERROR('From BK - Insert #tmpDLTraderbk - Date: "%s" - %d rows - %d ms', 0, 0, @Date, @RowCount, @Duration) WITH NOWAIT;
			END;

			SELECT @Date = '@FromDateBK = ' + CONVERT(NVARCHAR, @FromDateBK, 120) + ', @ToDateBK = ' + CONVERT(NVARCHAR, @ToDateBK, 120);
		END;

		IF @DotExtraPTDate > @ToDateBK 
		BEGIN
			
			INSERT INTO	#tmpDLTraderbk (TraderId, LeagueId, MatchId, EventDate, BetType, TraderBettype, OperatorType, MainDBBetType, TeamId, Grade)
			SELECT	DISTINCT
					[TraderId]		= a.OperatorID
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
			FROM		bodb_archive.dbo.Dot_Admin_Assignment_Operator_bk AS a WITH (NOLOCK)
			INNER JOIN	#tmpDLScannedMatches AS m WITH (NOLOCK) ON m.MatchId = a.matchId
			LEFT JOIN	dbo.BetType AS b WITH(NOLOCK) ON a.bettype = b.AssignmentBetType
					AND	a.OperatorType = b.OperatorType
			LEFT JOIN	dbo.TraderGrade_History AS td_G WITH (NOLOCK) ON td_G.CustID = a.OperatorID
					AND	m.EventDate BETWEEN td_G.BeginDate AND ISNULL(td_G.EndDate, @Today + 10)
			LEFT JOIN	dbo.TraderTeam_History AS td_T WITH (NOLOCK) ON	td_T.CustID = a.OperatorID
					AND	m.EventDate BETWEEN td_T.BeginDate AND ISNULL(td_T.EndDate, @Today + 10)
			WHERE	m.EventDate BETWEEN @FromDateBK AND @ToDateBK
				AND	a.OperatorType < 3;
		
			SELECT	@RowCount	= @@ROWCOUNT
				,	@Duration	= DATEDIFF(millisecond, @Begin, GETDATE())
				;

			IF	@Debug = 1
			BEGIN
				-- Force the output to appear immediately
				RAISERROR('From BK - Insert #tmpDLTraderbk - Date: "%s" - %d rows - %d ms', 0, 0, @Date, @RowCount, @Duration) WITH NOWAIT;
			END;
		
			-- SUM(ExtraPT)
			INSERT INTO #ExtraPTSportbook
			SELECT SuperId, SUM(ExtraPT) AS ExtraPT, FromDate, ToDate
			FROM
			(
				SELECT SuperId, ExtraPT, FromDate, ToDate
				FROM bodb02.dbo.Acc_GroupExtraPTSetting WITH (NOLOCK)
				WHERE ( @FromDateBK BETWEEN FromDate AND ToDate
						OR @ToDateBK BETWEEN FromDate AND ToDate )
						AND ProductId = 1 AND Sporttype = 0 AND SubProduct = ''
			) A
			GROUP BY SuperId, FromDate, ToDate;

		END;

		INSERT INTO	#tmpDLwinlostdate (Winlostdate)
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
			SELECT Winlostdate FROM #tmpDLwinlostdate WITH(NOLOCK)

			SELECT	@RowCount	= @@ROWCOUNT
				,	@Duration	= DATEDIFF(millisecond, @Begin, GETDATE())
				;

			IF	@Debug = 1
			BEGIN
				-- Force the output to appear immediately --
				RAISERROR('From BK - Insert Staging_EventDate - %d rows - %d ms', 0, 0, @RowCount, @Duration) WITH NOWAIT;
			END;
		END;

		WHILE	EXISTS (SELECT 1 FROM #tmpDLwinlostdate)
		BEGIN
			SELECT	TOP(1)
					@WinLostDate = d.Winlostdate
			FROM	#tmpDLwinlostdate AS d WITH(NOLOCK)
			ORDER BY Winlostdate DESC;
			
			SELECT @Date = CONVERT(NVARCHAR, @WinLostDate, 120);

			TRUNCATE TABLE	#tmpDLFilteredBettransByBatch;
			-- Fix Odds Spread Setting - ReCalculate Original Winlost (b.winlost - b.actual_stake)
			INSERT INTO	#tmpDLFilteredBettransByBatch (TransId, CustId, MatchId, WorkShift, SpecialType, Winlostdate, Bettype, Modds, Virtualrate, Actualrate, Tpositiontaking,
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
				,	[OriOdds]			= CASE WHEN b.transid = 111674398151 THEN NULL
											   WHEN CAST(b.ExtraInfo AS XML).exist('/p1/@oo') = 1 THEN
												CASE WHEN fdec.OddsType IS NOT NULL THEN
													 ISNULL(CAST(('<xml>' + b.ExtraInfo + '</xml>') AS XML).value('data(/xml/p1/@oo)[1]','SMALLMONEY'), 0) - 1
												ELSE ISNULL(CAST(('<xml>' + b.ExtraInfo + '</xml>') AS XML).value('data(/xml/p1/@oo)[1]','SMALLMONEY'), 0) END
										  ELSE NULL END
				,	[statuswinlost]		= b.statuswinlost
				,	[oddstype]			= b.oddstype
				,	[isDecOddsOnly]		= CASE WHEN fdec.OddsType IS NOT NULL THEN 1 ELSE 0 END
				,	[VarianceVR]		= CASE WHEN b.actualrate <> 0 THEN CAST((b.virtualrate / b.actualrate - 1) AS DECIMAL(9,6)) ELSE NULL END -- Calculate VarianceVR
			FROM bodb_Archive.dbo.bettrans_bk AS b WITH (NOLOCK)
				INNER JOIN #tmpDLScannedMatches AS m WITH (NOLOCK) ON b.matchId = m.matchId
				INNER JOIN #tmpDLFilteredBettypes AS bt WITH(NOLOCK) ON b.bettype = bt.BetType
				LEFT JOIN #ExtraPTSportbook AS es WITH (NOLOCK) ON es.SuperId = b.srecommend
						AND	b.winlostdate BETWEEN es.FromDate AND es.ToDate
				LEFT JOIN bodb_Archive.dbo.MatchMaxbet_bk AS mm WITH (NOLOCK) ON mm.matchId = b.matchId AND	mm.BetType = b.bettype
				LEFT JOIN @tmpDLSpread1x2 AS s ON	mm.Spread = s.Margin AND mm.BetType IN (5, 15)
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
				-- Force the output to appear immediately
				RAISERROR('From BK - Insert #tmpDLFilteredBettransByBatch - Date: "%s" - %d rows - %d ms', 0, 0, @Date, @RowCount, @Duration) WITH NOWAIT;
			END;

				-- "DISTINCT" Prevent Page Splits
			DELETE b WITH(ROWLOCK)
			FROM	(	
						SELECT ROW_NUMBER() OVER (PARTITION BY TransId ORDER BY TransId) AS rn
						FROM #tmpDLFilteredBettransByBatch
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
			FROM #tmpDLFilteredBettransByBatch AS b
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
				RAISERROR('From BK - ReCalculate Original Winlost #tmpDLFilteredBettransByBatch - Date: "%s" - %d rows - %d ms', 0, 0, @Date, @RowCount, @Duration) WITH NOWAIT;
			END;
			
			SELECT @MinDWCustID = MIN(CustID), @MaxDWCustID = MAX(CustID)
			FROM #tmpDLFilteredBettransByBatch
            WHERE CustID NOT IN (SELECT custid FROM bodb02.dbo.vw_customer);

			INSERT INTO #tmpHistoryCustomer  (CustID, Site)
            SELECT CustID, Site
            FROM bodb02.dbo.vw_customer c
            WHERE custid IN (SELECT CustID FROM #tmpDLFilteredBettransByBatch)
            OPTION (RECOMPILE);

			INSERT INTO #tmpHistoryCustomer  (CustID, Site)
			SELECT CustID, Site
			FROM DBWH.bodb_Account.dbo.vw_customer
			WHERE CustID BETWEEN @MinDWCustID AND @MaxDWCustID
              AND CustID NOT IN (SELECT custid FROM bodb02.dbo.vw_customer)
            OPTION (RECOMPILE);

			INSERT INTO	#tmpDLStagingTraderPerformance (TraderId, CustId, WorkShift, MatchId, MatchCode, EventDate, SportType, LeagueId, HomeId, AwayId, 
			TeamId, Grade, BetType, Stake, WinLost, SMAWinLost, Comm, BetCount, Spread, ExtraPT, TPositionTaking, VirtualRate, ActualRate, LiveIndicator, hdp1, hdp2, oddsspread, Is8RM, BetChoice, IsBetChoiceDetail
			, VarianceVR, SiteID
			)
			SELECT	[TraderId]			= CASE WHEN b.LiveIndicator = 0 THEN @IdForNonLiveUnassignedTrader ELSE ISNULL(t.TraderId, @IdForLiveUnassignedTrader) END
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
				,	[VarianceVR]		= b.VarianceVR -- Added VarianceVR
				,	[SiteID]			= s.SiteId
			FROM	#tmpDLFilteredBettransByBatch AS b WITH (NOLOCK)
				INNER JOIN #tmpDLSupportedBettypes AS bt WITH(NOLOCK) ON b.BetType = bt.BetType
				INNER JOIN #tmpHistoryCustomer AS c WITH(NOLOCK) ON b.custid = c.CustId
				INNER JOIN bodb02.dbo.site AS s WITH(NOLOCK) ON c.Site = s.site
				LEFT JOIN #tmpDLTraderbk AS t WITH (NOLOCK)
						ON	b.winlostdate = t.EventDate
						AND	b.matchId = t.matchId
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
					) AS ca
			WHERE	b.winlostdate = @Winlostdate;

			SELECT	@RowCount	= @@ROWCOUNT
				,	@Duration	= DATEDIFF(millisecond, @Begin, GETDATE())
				;
			
			IF	@Debug = 1
			BEGIN
				-- Force the output to appear immediately
				RAISERROR('From BK - Insert #tmpDLStagingTraderPerformance - Date: "%s" - %d rows - %d ms', 0, 0, @Date, @RowCount, @Duration) WITH NOWAIT;
			END;

			UPDATE stp WITH(ROWLOCK, UPDLOCK)
			SET stp.TeamId = t.TeamId
				,	stp.Grade = t.Grade
			FROM #tmpDLStagingTraderPerformance AS stp
			INNER JOIN dbo.Trader t WITH (NOLOCK) ON t.CustId IN (@IdForLiveUnassignedTrader, @IdForNonLiveUnassignedTrader) AND stp.TraderId = t.CustId;
			
			DELETE tp WITH(ROWLOCK) 
			FROM dbo.TraderPerformance AS tp
				INNER JOIN #tmpDLFilteredBettypes AS bt ON tp.BetType = bt.BetType
			WHERE tp.EventDate = @Winlostdate;

			INSERT INTO	dbo.TraderPerformance (CustId, WorkShift, MatchId, MatchCode, EventDate, SportType, LeagueId, HomeId, AwayId, TeamId, Grade, BetType, IsLive,
			Stake, WinLost, Comm, Stake_AR, WinLost_AR, Comm_AR, Is8RM, Stake_Real, WinLost_Real, Stake_VAR, WinLost_VAR, BetCount, Spread, VarianceVR, SiteID)
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
				,   [VarianceVR]		= t.VarianceVR
				,   [SiteID]			= t.SiteID
			FROM	#tmpDLStagingTraderPerformance AS t WITH(NOLOCK)
			WHERE t.EventDate = @winlostdate
			GROUP BY t.TraderId, t.WorkShift, t.matchId, t.matchCode, t.EventDate, t.SportType, t.LeagueId, t.HomeId, t.AwayId, t.TeamId, t.Grade, t.BetType, t.LiveIndicator, t.Is8RM
			    , t.VarianceVR, t.SiteID;

			SELECT	@RowCount	= @@ROWCOUNT
				,	@Duration	= DATEDIFF(millisecond, @Begin, GETDATE())
				;

			IF	@Debug = 1
			BEGIN
				-- Force the output to appear immediately
				RAISERROR('From BK - Insert TraderPerformance - Date: "%s" - %d rows - %d ms', 0, 0, @Date, @RowCount, @Duration) WITH NOWAIT;
			END;
		
			DELETE tpc WITH(ROWLOCK) 
			FROM dbo.TraderPerformance_BetChoice AS tpc
				INNER JOIN #tmpDLFilteredBettypes AS bt ON tpc.BetType = bt.BetType
			WHERE tpc.EventDate = @winlostdate;

			INSERT INTO	dbo.TraderPerformance_BetChoice (CustId, MatchId, EventDate, SportType, LeagueId, BetType, BetChoice, IsLive, Stake, WinLost, Comm, Stake_AR, WinLost_AR, Comm_AR, Is8RM, Stake_Real, WinLost_Real, Stake_VAR, WinLost_VAR, BetCount
			, VarianceVR, SiteID)
			SELECT		[CustId]			= t.TraderId
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
					,	[Is8RM]				= t.Is8RM					
					,	[Stake_Real]		= SUM((CASE WHEN t.TPositionTaking = 1 THEN 0 ELSE (1 - t.TPositionTaking - t.ExtraPT) END * ABS(t.Stake) * t.ActualRate) * (CASE WHEN t.VirtualRate > t.ActualRate THEN t.VirtualRate/t.ActualRate ELSE 1 END))
					,	[WinLost_Real]		= SUM(-((t.WinLost + t.SMAWinLost) + t.Comm) * t.ActualRate + (CASE WHEN t.TPositionTaking = 1 THEN 0 ELSE t.WinLost + t.Comm/(1 - t.TPositionTaking) END ) * t.ExtraPT * t.ActualRate)
					,	[Stake_VAR]			= SUM(CASE WHEN t.TPositionTaking = 1 THEN 0 ELSE (1 - t.TPositionTaking - t.ExtraPT) END  * ABS(t.Stake) * t.ActualRate * (CASE WHEN t.VirtualRate > t.ActualRate THEN (t.VirtualRate/t.ActualRate -1) ELSE -(t.VirtualRate/t.ActualRate - 1) END))
					,	[WinLost_VAR]		= SUM((t.WinLost + t.SMAWinLost - (CASE WHEN t.TPositionTaking = 1 THEN 0 ELSE t.WinLost * t.ExtraPT END) + (CASE WHEN t.VirtualRate < t.ActualRate THEN (t.Comm - CASE WHEN t.TPositionTaking=1 THEN 0 ELSE t.Comm * t.ExtraPT/(1-t.TPositionTaking) END) ELSE 0 END)) * (t.VirtualRate/t.ActualRate - 1)*t.ActualRate)
					,	[BetCount]			= SUM(t.BetCount)
					,	[VarianceVR]		= t.VarianceVR
					,	[SiteID]			= t.SiteID
			FROM	#tmpDLStagingTraderPerformance AS t WITH(NOLOCK)
			WHERE t.EventDate = @winlostdate AND t.BetChoice IS NOT NULL
			GROUP BY t.TraderId, t.matchId, t.EventDate, t.SportType, t.LeagueId, t.BetType, t.BetChoice, t.LiveIndicator, t.Is8RM, t.VarianceVR, t.SiteID;
				
			SELECT	@RowCount	= @@ROWCOUNT
				,	@Duration	= DATEDIFF(millisecond, @Begin, GETDATE())
				;
			
			IF	@Debug = 1
			BEGIN
				-- Force the output to appear immediately
				RAISERROR('From BK - Insert TraderPerformance_BetChoice - Date: "%s" - %d rows - %d ms', 0, 0, @Date, @RowCount, @Duration) WITH NOWAIT;
			END;

			DELETE tpc WITH(ROWLOCK) 
			FROM dbo.TraderPerformance_BetChoice_Detail AS tpc
				INNER JOIN #tmpDLSupportedBettypes AS bt ON tpc.BetType = bt.BetType
			WHERE tpc.EventDate = @winlostdate AND bt.IsBetChoiceDetail = 1;

			INSERT INTO	dbo.TraderPerformance_BetChoice_Detail (CustId, MatchId, EventDate, SportType, LeagueId, BetType, betteam, IsLive, hdp1, hdp2, oddsspread, Stake, WinLost, Comm, Stake_AR, WinLost_AR, Comm_AR, Is8RM, Stake_Real, WinLost_Real, Stake_VAR, WinLost_VAR, BetCount
			, VarianceVR, SiteID)
			SELECT		[CustId]			= t.TraderId
					,	[MatchId]			= t.matchId
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
			FROM	#tmpDLStagingTraderPerformance AS t WITH(NOLOCK)
			WHERE t.EventDate = @winlostdate 
				AND t.BetChoice IS NOT NULL
				AND t.IsBetChoiceDetail = 1
			GROUP BY t.TraderId, t.matchId, t.EventDate, t.SportType, t.LeagueId, t.BetType, t.BetChoice, t.LiveIndicator, t.hdp1, t.hdp2, t.oddsspread, t.Is8RM, t.VarianceVR, t.SiteID;
				
			SELECT	@RowCount	= @@ROWCOUNT
				,	@Duration	= DATEDIFF(millisecond, @Begin, GETDATE())
				;
			
			IF	@Debug = 1
			BEGIN
				-- Force the output to appear immediately
				RAISERROR('From BK - Insert TraderPerformance_BetChoice_Detail - Date: "%s" - %d rows - %d ms', 0, 0, @Date, @RowCount, @Duration) WITH NOWAIT;
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
			TRUNCATE TABLE #tmpHistoryCustomer;
		END;
	END;

	IF	@IsGetDataFrom14 = 1
	BEGIN
		TRUNCATE TABLE #tmpDLTrader;
		TRUNCATE TABLE #tmpDLScannedMatches;
		TRUNCATE TABLE #ExtraPTSportbook;
		
		SELECT @Date = '@FromDate14 = ' + CONVERT(NVARCHAR, @FromDate14, 120) + ', @ToDate14 = ' + CONVERT(NVARCHAR, @ToDate14, 120);

		-- GET Scanned Match List: Completed Soccer Match
		INSERT INTO #tmpDLScannedMatches(MatchId, EventDate, KickOffTime,WorkShift, MatchCode, LeagueId, SportType, HomeId, AwayId, LeagueName, HomeName, SpecialType)
		SELECT	  m.matchid
				, m.eventdate
				, m.kickofftime
	 			, CASE	WHEN CAST(m.kickofftime AS TIME) >= '00:00:00' AND CAST(m.kickofftime AS TIME) < '06:00:00'
								THEN 1 --  Afternoon: 12:00:00 ~ 17:59:59 (GMT + 8)
							WHEN CAST(m.kickofftime AS TIME) >= '06:00:00' AND CAST(m.kickofftime AS TIME) < '16:00:00'
								THEN 2 -- Night: 18:00:00 ~ 3:59:59 (GMT + 8)				
							--WHEN CAST(m.kickofftime AS TIME) >= '16:00:00' AND CAST(m.kickofftime AS TIME) <'24:00:00'THEN 3 --  Midnight: 4:00:00 ~ 11:59:59 (GMT + 8)
							ELSE 3
				  END AS WorkShift
				, m.MatchCode
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
				AND m.EventStatus = 'completed';
		
		INSERT INTO	#tmpDLTrader (TraderId, LeagueId, MatchId, EventDate, BetType, TeamId, Grade)
		SELECT	DISTINCT
				[TraderId]		= a.TraderID
			,	[LeagueId]		= m.LeagueId
			,	[MatchId]		= m.MatchId
			,	[EventDate]		= m.EventDate
			,	[BetType]		= a.bettype
			,	[TeamId]		= td_T.TeamId
			,	[Grade]			= td_G.Grade
		FROM	bodb02.dbo.Dot_Admin_Assignment_Trader AS a WITH (NOLOCK)
			INNER JOIN #tmpDLScannedMatches AS m WITH (NOLOCK) ON m.matchId = a.matchId
			INNER JOIN #tmpDLFilteredBettypes AS b WITH (NOLOCK) ON b.BetType = a.bettype
			LEFT JOIN dbo.TraderGrade_History AS td_G WITH (NOLOCK)	ON	td_G.CustID = a.TraderID
					AND	m.EventDate BETWEEN td_G.BeginDate AND ISNULL(td_G.EndDate, @Today + 10)
			LEFT JOIN dbo.TraderTeam_History AS td_T WITH (NOLOCK) ON td_T.CustID = a.TraderID
					AND	m.EventDate BETWEEN td_T.BeginDate AND ISNULL(td_T.EndDate, @Today + 10)
		CROSS APPLY (
					SELECT dt.TraderID, dt.MatchId, dt.Bettype,
						ROW_NUMBER() OVER(PARTITION BY dt.MatchId, dt.Bettype ORDER BY dt.UpdatedTime DESC, dt.ID DESC) AS Row_Num
					FROM bodb02.dbo.Dot_Admin_Assignment_Trader AS dt WITH (NOLOCK)
					WHERE   a.matchid = dt.matchid
						AND a.bettype = dt.bettype		
						AND a.TraderId <> 0
					) dat
		WHERE	m.EventDate BETWEEN @FromDate14 AND @ToDate14
				AND a.TraderId <> 0
				AND a.TraderID = dat.TraderID
				AND a.MatchId = dat.MatchId
				AND a.Bettype = dat.Bettype
				AND dat.Row_Num = 1;	
		
		SELECT	@RowCount	= @@ROWCOUNT
			,	@Duration	= DATEDIFF(millisecond, @Begin, GETDATE())
			;

		IF	@Debug = 1
		BEGIN
			-- Force the output to appear immediately
			RAISERROR('From 14 - Insert #tmpDLTrader - Date: "%s" - %d rows - %d ms', 0, 0, @Date, @RowCount, @Duration) WITH NOWAIT;
		END;
		
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

		WHILE	EXISTS (SELECT 1 FROM #tmpDLwinlostdate WITH(NOLOCK))
		BEGIN
			SELECT	TOP(1)
					@WinLostDate = d.winlostdate
			FROM	#tmpDLwinlostdate AS d WITH(NOLOCK)
			ORDER BY winlostdate DESC;

			SELECT @Date = CONVERT(NVARCHAR, @winlostdate, 120);
			
			TRUNCATE TABLE	#tmpDLFilteredBettransByBatch;
			-- Fix Odds Spread Setting - ReCalculate Original Winlost (b.winlost - b.actual_stake)
			INSERT INTO	#tmpDLFilteredBettransByBatch (TransId, CustId, MatchId, WorkShift, SpecialType, Winlostdate, Bettype, Modds, Virtualrate, Actualrate, Tpositiontaking,
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
				,	[OriOdds]			= CASE WHEN fdec.OddsType IS NOT NULL THEN bi.OriginalOdds - 1 ELSE bi.OriginalOdds END
				,	[statuswinlost]		= b.statuswinlost
				,	[oddstype]			= b.oddstype
				,	[isDecOddsOnly]		= CASE WHEN fdec.OddsType IS NOT NULL THEN 1 ELSE 0 END
				,	[VarianceVR]		= CASE WHEN b.actualrate <> 0 THEN CAST((b.virtualrate / b.actualrate - 1) AS DECIMAL(9,6)) ELSE NULL END -- Calculate VarianceVR
			FROM	bodb02.dbo.bettrans14 AS b WITH (NOLOCK)
				INNER JOIN #tmpDLScannedMatches AS m WITH (NOLOCK) ON	b.matchId = m.matchId
				INNER JOIN #tmpDLFilteredBettypes AS bt WITH(NOLOCK) ON b.bettype = bt.BetType
				LEFT JOIN bodb02.dbo.MatchMaxbet14 AS mm WITH (NOLOCK) ON	mm.matchId = b.matchId AND	mm.BetType = b.bettype
				LEFT JOIN @tmpDLSpread1x2 AS s ON	mm.Spread = s.Margin AND mm.BetType IN (5, 15)
				LEFT JOIN bodb02.dbo.BettransInfo14 bi WITH (NOLOCK) ON b.transid = bi.transid
				LEFT JOIN bodb02.dbo.f_Set_OddsTypeBettypes() fdec  ON b.bettype = fdec.BetType
				LEFT JOIN #tmp8RMMembers AS t8 WITH(NOLOCK) ON b.CustId = t8.CustId
			WHERE	b.winlostdate = @winlostdate
				AND	b.statusID IN (112, 113)
				AND	b.Currency NOT IN (20, 27, 28)
			OPTION (RECOMPILE);
			
			SELECT	@RowCount	= @@ROWCOUNT
				,	@Duration	= DATEDIFF(millisecond, @Begin, GETDATE())
				;

			IF	@Debug = 1
			BEGIN
				-- Force the output to appear immediately
				RAISERROR('From 14 - Insert #tmpDLFilteredBettransByBatch - Date: "%s" - %d rows - %d ms', 0, 0, @Date, @RowCount, @Duration) WITH NOWAIT;
			END;

				-- "DISTINCT" Prevent Page Splits
			DELETE b WITH(ROWLOCK)
			FROM	(	
						SELECT ROW_NUMBER() OVER (PARTITION BY TransId ORDER BY TransId) AS rn
						FROM #tmpDLFilteredBettransByBatch
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
			FROM #tmpDLFilteredBettransByBatch AS b
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
				RAISERROR('From 14 - ReCalculate Original Winlost #tmpDLFilteredBettransByBatch - Date: "%s" - %d rows - %d ms', 0, 0, @Date, @RowCount, @Duration) WITH NOWAIT;
			END;

			INSERT INTO	#tmpDLStagingTraderPerformance (TraderId, CustId, WorkShift, MatchId, MatchCode, EventDate, SportType, LeagueId, HomeId, AwayId, 
			TeamId, Grade, BetType, Stake, WinLost, SMAWinLost, Comm, BetCount, Spread, ExtraPT, TPositionTaking, VirtualRate, ActualRate, LiveIndicator, hdp1, hdp2, oddsspread, Is8RM, BetChoice, IsBetChoiceDetail
			, VarianceVR, SiteID
			)
			SELECT	[TraderId]			= CASE WHEN b.LiveIndicator = 0 THEN @IdForNonLiveUnassignedTrader ELSE ISNULL(t.TraderId, @IdForLiveUnassignedTrader) END
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
			FROM	#tmpDLFilteredBettransByBatch AS b WITH (NOLOCK)
				INNER JOIN #tmpDLSupportedBettypes AS bt WITH(NOLOCK) ON b.BetType = bt.BetType
				INNER JOIN bodb02.dbo.customer AS c WITH(NOLOCK) ON b.custid = c.CustId
				INNER JOIN bodb02.dbo.site AS s WITH(NOLOCK) ON c.Site = s.site
				LEFT JOIN #tmpDLTraderbk AS t WITH (NOLOCK)
						ON	b.winlostdate = t.EventDate
						AND	b.matchId = t.matchId
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
					) AS ca
			WHERE	b.winlostdate = @winlostdate;

			SELECT	@RowCount	= @@ROWCOUNT
				,	@Duration	= DATEDIFF(millisecond, @Begin, GETDATE())
				;

			IF	@Debug = 1
			BEGIN
				-- Force the output to appear immediately
				RAISERROR('From 14 - Insert #tmpDLStagingTraderPerformance - Date: "%s" - %d rows - %d ms', 0, 0, @Date, @RowCount, @Duration) WITH NOWAIT;
			END;

			UPDATE stp WITH(ROWLOCK, UPDLOCK)
			SET stp.TeamId = t.TeamId
				,	stp.Grade = t.Grade
			FROM #tmpDLStagingTraderPerformance AS stp
			INNER JOIN dbo.Trader t WITH (NOLOCK) ON t.CustId IN (@IdForLiveUnassignedTrader, @IdForNonLiveUnassignedTrader) AND stp.TraderId = t.CustId;

			DELETE tp WITH(ROWLOCK) 
			FROM dbo.TraderPerformance AS tp
				INNER JOIN #tmpDLFilteredBettypes AS bt ON tp.BetType = bt.BetType
			WHERE tp.EventDate = @winlostdate;

			INSERT INTO	dbo.TraderPerformance (CustId, WorkShift, MatchId, MatchCode, EventDate, SportType, LeagueId, HomeId, AwayId, TeamId, Grade, BetType, IsLive, 
			Stake, WinLost, Comm, Stake_AR, WinLost_AR, Comm_AR, Is8RM, Stake_Real, WinLost_Real, Stake_VAR, WinLost_VAR, BetCount, Spread, VarianceVR, SiteID
			)
			SELECT	[CustId]			= t.TraderId
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
				,	[Is8RM]				= t.Is8RM
				,	[Stake_Real]		= SUM((CASE WHEN t.TPositionTaking = 1 THEN 0 ELSE (1 - t.TPositionTaking - t.ExtraPT) END * ABS(t.Stake) * t.ActualRate) * (CASE WHEN t.VirtualRate > t.ActualRate THEN t.VirtualRate/t.ActualRate ELSE 1 END))
				,	[WinLost_Real]		= SUM(-((t.WinLost + t.SMAWinLost) + t.Comm) * t.ActualRate + (CASE WHEN t.TPositionTaking = 1 THEN 0 ELSE t.WinLost + t.Comm/(1 - t.TPositionTaking) END ) * t.ExtraPT * t.ActualRate)
				,	[Stake_VAR]			= SUM(CASE WHEN t.TPositionTaking = 1 THEN 0 ELSE (1 - t.TPositionTaking - t.ExtraPT) END  * ABS(t.Stake) * t.ActualRate * (CASE WHEN t.VirtualRate > t.ActualRate THEN (t.VirtualRate/t.ActualRate -1) ELSE -(t.VirtualRate/t.ActualRate - 1) END))
				,	[WinLost_VAR]		= SUM((t.WinLost + t.SMAWinLost - (CASE WHEN t.TPositionTaking = 1 THEN 0 ELSE t.WinLost * t.ExtraPT END) + (CASE WHEN t.VirtualRate < t.ActualRate THEN (t.Comm - CASE WHEN t.TPositionTaking=1 THEN 0 ELSE t.Comm * t.ExtraPT/(1-t.TPositionTaking) END) ELSE 0 END)) * (t.VirtualRate/t.ActualRate - 1)*t.ActualRate)
				,	[BetCount]			= SUM(t.BetCount)
				,	[Spread]			= MAX(t.Spread)
				,	[VarianceVR]		= t.VarianceVR
				,	[SiteID]			= t.SiteID
			FROM	#tmpDLStagingTraderPerformance AS t WITH(NOLOCK)
			WHERE	t.EventDate = @winlostdate
			GROUP BY t.TraderId, t.WorkShift, t.matchId, t.matchCode, t.EventDate, t.SportType, t.LeagueId, t.HomeId, t.AwayId, t.TeamId, t.Grade, t.BetType, t.LiveIndicator, t.Is8RM
			, t.VarianceVR, t.SiteID;
				
			SELECT	@RowCount	= @@ROWCOUNT
				,	@Duration	= DATEDIFF(millisecond, @Begin, GETDATE())
				;

			IF	@Debug = 1
			BEGIN
				-- Force the output to appear immediately
				RAISERROR('From 14 - Insert TraderPerformance - Date: "%s" - %d rows - %d ms', 0, 0, @Date, @RowCount, @Duration) WITH NOWAIT;
			END;
		
			DELETE tpc WITH(ROWLOCK) 
			FROM dbo.TraderPerformance_BetChoice AS tpc
				INNER JOIN #tmpDLFilteredBettypes AS bt ON tpc.BetType = bt.BetType
			WHERE tpc.EventDate = @winlostdate;

			INSERT INTO	dbo.TraderPerformance_BetChoice (CustId, MatchId, EventDate, SportType, LeagueId, BetType, BetChoice, IsLive, Stake, WinLost, Comm, Stake_AR, WinLost_AR, Comm_AR, Is8RM, Stake_Real, WinLost_Real, Stake_VAR, WinLost_VAR, BetCount
			, VarianceVR, SiteID
			)
			SELECT		[CustId]			= t.TraderId
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
					,	[Is8RM]				= t.Is8RM					
					,	[Stake_Real]		= SUM((CASE WHEN t.TPositionTaking = 1 THEN 0 ELSE (1 - t.TPositionTaking - t.ExtraPT) END * ABS(t.Stake) * t.ActualRate) * (CASE WHEN t.VirtualRate > t.ActualRate THEN t.VirtualRate/t.ActualRate ELSE 1 END))
					,	[WinLost_Real]		= SUM(-((t.WinLost + t.SMAWinLost) + t.Comm) * t.ActualRate + (CASE WHEN t.TPositionTaking = 1 THEN 0 ELSE t.WinLost + t.Comm/(1 - t.TPositionTaking) END ) * t.ExtraPT * t.ActualRate)
					,	[Stake_VAR]			= SUM(CASE WHEN t.TPositionTaking = 1 THEN 0 ELSE (1 - t.TPositionTaking - t.ExtraPT) END  * ABS(t.Stake) * t.ActualRate * (CASE WHEN t.VirtualRate > t.ActualRate THEN (t.VirtualRate/t.ActualRate -1) ELSE -(t.VirtualRate/t.ActualRate - 1) END))
					,	[WinLost_VAR]		= SUM((t.WinLost + t.SMAWinLost - (CASE WHEN t.TPositionTaking = 1 THEN 0 ELSE t.WinLost * t.ExtraPT END) + (CASE WHEN t.VirtualRate < t.ActualRate THEN (t.Comm - CASE WHEN t.TPositionTaking=1 THEN 0 ELSE t.Comm * t.ExtraPT/(1-t.TPositionTaking) END) ELSE 0 END)) * (t.VirtualRate/t.ActualRate - 1)*t.ActualRate)
					,	[BetCount]			= SUM(t.BetCount)
					,	[VarianceVR]		= t.VarianceVR
					,	[SiteID]			= t.SiteID
			FROM	#tmpDLStagingTraderPerformance AS t WITH(NOLOCK)
			WHERE t.EventDate = @winlostdate AND t.BetChoice IS NOT NULL
			GROUP BY t.TraderId, t.matchId, t.EventDate, t.SportType, t.LeagueId, t.BetType, t.BetChoice, t.LiveIndicator, t.Is8RM
			, t.VarianceVR, t.SiteID;
				
			SELECT	@RowCount	= @@ROWCOUNT
				,	@Duration	= DATEDIFF(millisecond, @Begin, GETDATE())
				;

			IF	@Debug = 1
			BEGIN
				-- Force the output to appear immediately
				RAISERROR('From 14 - Insert TraderPerformance_BetChoice - Date: "%s" - %d rows - %d ms', 0, 0, @Date, @RowCount, @Duration) WITH NOWAIT;
			END;

			DELETE tpc WITH(ROWLOCK) 
			FROM dbo.TraderPerformance_BetChoice_Detail AS tpc
				INNER JOIN #tmpDLSupportedBettypes AS bt ON tpc.BetType = bt.BetType
			WHERE tpc.EventDate = @winlostdate AND bt.IsBetChoiceDetail = 1;

			INSERT INTO	dbo.TraderPerformance_BetChoice_Detail (CustId, MatchId, EventDate, SportType, LeagueId, BetType, betteam, IsLive, hdp1, hdp2, oddsspread, Stake, WinLost, Comm, Stake_AR, WinLost_AR, Comm_AR, Is8RM, Stake_Real, WinLost_Real, Stake_VAR, WinLost_VAR, BetCount
			, VarianceVR, SiteID
			)
			SELECT		[CustId]			= t.TraderId
					,	[MatchId]			= t.matchId
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
			FROM	#tmpDLStagingTraderPerformance AS t WITH(NOLOCK)
			WHERE t.EventDate = @winlostdate 
				AND t.BetChoice IS NOT NULL
				AND t.IsBetChoiceDetail = 1
			GROUP BY t.TraderId, t.matchId, t.EventDate, t.SportType, t.LeagueId, t.BetType, t.BetChoice, t.LiveIndicator, t.hdp1, t.hdp2, t.oddsspread, t.Is8RM
			, t.VarianceVR, t.SiteID;
				
			SELECT	@RowCount	= @@ROWCOUNT
				,	@Duration	= DATEDIFF(millisecond, @Begin, GETDATE())
				;
			
			IF	@Debug = 1
			BEGIN
				-- Force the output to appear immediately
				RAISERROR('From 14 - Insert TraderPerformance_BetChoice_Detail - Date: "%s" - %d rows - %d ms', 0, 0, @Date, @RowCount, @Duration) WITH NOWAIT;
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
			TRUNCATE TABLE #tmpHistoryCustomer;
		END;
	END;
	
	IF	@IsGetDataFromOrigin = 1
	BEGIN
		TRUNCATE TABLE #tmpDLTrader;
		TRUNCATE TABLE #tmpDLScannedMatches;
		TRUNCATE TABLE #ExtraPTSportbook;

		SELECT @Date = '@FromDateOrigin = ' + CONVERT(NVARCHAR, @FromDateOrigin, 120) + ', @ToDateOrigin = ' + CONVERT(NVARCHAR, @ToDateOrigin, 120);

		-- GET Scanned Match List: Completed Soccer Match
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
				, m.MatchCode
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
				AND m.EventStatus = 'completed';
		
		-- REMOVE Scanned Match List: if existing any Ticket has not been settled (ruben <> 1)
		DELETE	sm
		FROM	#tmpDLScannedMatches AS sm WITH (ROWLOCK)
		WHERE	sm.MatchId  IN ( SELECT	TOP(1) b.MatchId
								 FROM	bodb02.dbo.bettrans AS b WITH(NOLOCK) 
								 WHERE	b.matchid = sm.matchid
									AND b.Currency NOT IN (20, 27, 28)
									AND b.ruben <> 1);		
		
		INSERT INTO	#tmpDLTrader (TraderID, LeagueId, MatchId, EventDate, BetType, TeamId, Grade)
		SELECT	DISTINCT
				[TraderID]		= a.TraderID
			,	[LeagueId]		= m.LeagueId
			,	[MatchId]		= m.MatchId
			,	[EventDate]		= m.EventDate
			,	[BetType]		= a.BetType
			,	[TeamId]		= td_T.TeamId
			,	[Grade]			= td_G.Grade
		FROM	bodb02.dbo.Dot_Admin_Assignment_Trader AS a WITH (NOLOCK)
			INNER JOIN #tmpDLScannedMatches AS m WITH (NOLOCK) ON m.MatchId = a.Matchid
			INNER JOIN #tmpDLFilteredBettypes AS b WITH (NOLOCK) ON b.BetType = a.bettype
			LEFT JOIN dbo.TraderGrade_History AS td_G WITH (NOLOCK)	ON	td_G.CustID = a.TraderID
					AND	m.EventDate BETWEEN td_G.BeginDate AND ISNULL(td_G.EndDate, @Today + 10)
			LEFT JOIN dbo.TraderTeam_History AS td_T WITH (NOLOCK) ON td_T.CustID = a.TraderID
					AND	m.EventDate BETWEEN td_T.BeginDate AND ISNULL(td_T.EndDate, @Today + 10)
			CROSS APPLY (
						SELECT dt.TraderID, dt.MatchId, dt.Bettype,
							ROW_NUMBER() OVER(PARTITION BY dt.MatchId, dt.Bettype ORDER BY dt.UpdatedTime DESC, dt.ID DESC) AS Row_Num
						FROM bodb02.dbo.Dot_Admin_Assignment_Trader AS dt WITH (NOLOCK)
						WHERE   a.matchid = dt.matchid
							AND a.bettype = dt.bettype		
							AND a.TraderId <> 0
						) dat
		WHERE	m.EventDate BETWEEN @FromDateOrigin AND @ToDateOrigin
				AND a.TraderId <> 0
				AND a.TraderID = dat.TraderID
				AND a.MatchId = dat.MatchId
				AND a.Bettype = dat.Bettype
				AND dat.Row_Num = 1;
		
		SELECT	@RowCount	= @@ROWCOUNT
			,	@Duration	= DATEDIFF(millisecond, @Begin, GETDATE())
			;
		
		IF	@Debug = 1
		BEGIN
			-- Force the output to appear immediately
			RAISERROR('From Origin - Insert #tmpDLTrader - Date: "%s" - %d rows - %d ms', 0, 0, @Date, @RowCount, @Duration) WITH NOWAIT;
		END;
 		
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

		WHILE	EXISTS (SELECT 1 FROM #tmpDLwinlostdate WITH(NOLOCK))
		BEGIN
			SELECT	TOP(1)
					@WinLostDate = d.winlostdate
			FROM	#tmpDLwinlostdate AS d WITH(NOLOCK)
			ORDER BY winlostdate DESC;
			
			SELECT @Date = CONVERT(NVARCHAR, @winlostdate, 120);

			TRUNCATE TABLE	#tmpDLFilteredBettransByBatch;
			-- Fix Odds Spread Setting - ReCalculate Original Winlost (b.winlost - b.actual_stake)
			INSERT INTO	#tmpDLFilteredBettransByBatch (TransId, CustId, MatchId, WorkShift, SpecialType, Winlostdate, Bettype, Modds, Virtualrate, Actualrate, Tpositiontaking,
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
				,	[OriOdds]			= CASE WHEN fdec.OddsType IS NOT NULL THEN bi.OriginalOdds - 1 ELSE bi.OriginalOdds END
				,	[statuswinlost]		= b.statuswinlost
				,	[oddstype]			= b.oddstype
				,	[isDecOddsOnly]		= CASE WHEN fdec.OddsType IS NOT NULL THEN 1 ELSE 0 END
				,	[VarianceVR]		= CASE WHEN b.actualrate <> 0 THEN CAST((b.virtualrate / b.actualrate - 1) AS DECIMAL(9,6)) ELSE NULL END -- Calculate VarianceVR
			FROM	bodb02.dbo.bettrans AS b WITH (NOLOCK)
				INNER JOIN	#tmpDLScannedMatches AS m WITH (NOLOCK) ON	b.matchid = m.matchid
				INNER JOIN  #tmpDLFilteredBettypes AS bt WITH(NOLOCK) ON b.bettype = bt.BetType
				LEFT JOIN	bodb02.dbo.MatchMaxbet AS mm WITH (NOLOCK) ON mm.MatchId = b.matchid AND mm.BetType = b.bettype
				LEFT JOIN	@tmpDLSpread1x2 AS s ON	mm.Spread = s.Margin AND mm.BetType IN (5, 15)
				LEFT JOIN #tmp8RMMembers AS t8 WITH(NOLOCK) ON b.CustId = t8.CustId
				LEFT JOIN bodb02.dbo.BettransInfo bi WITH (NOLOCK) ON b.transid = bi.transid
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
				-- Force the output to appear immediately
				RAISERROR('From Origin - Insert #tmpDLFilteredBettransByBatch - Date: "%s" - %d rows - %d ms', 0, 0, @Date, @RowCount, @Duration) WITH NOWAIT;
			END;

				-- "DISTINCT" Prevent Page Splits
			DELETE b WITH(ROWLOCK)
			FROM	(	
						SELECT ROW_NUMBER() OVER (PARTITION BY TransId ORDER BY TransId) AS rn
						FROM #tmpDLFilteredBettransByBatch
					) AS b
			WHERE b.rn > 1;
			
			-- Odds Spread Setting - ReCalculate Original Winlost
			-- Jaden: After investigation, OriOdds is always equal to AdjOdds (2025) so case 2 never happens
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
			FROM #tmpDLFilteredBettransByBatch AS b
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
				RAISERROR('From Origin - ReCalculate Original Winlost #tmpDLFilteredBettransByBatch - Date: "%s" - %d rows - %d ms', 0, 0, @Date, @RowCount, @Duration) WITH NOWAIT;
			END;

			INSERT INTO	#tmpDLStagingTraderPerformance (TraderId, CustId, WorkShift, MatchId, MatchCode, EventDate, SportType, LeagueId, HomeId, AwayId, 
			TeamId, Grade, BetType, Stake, WinLost, SMAWinLost, Comm, BetCount, Spread, ExtraPT, TPositionTaking, VirtualRate, ActualRate, LiveIndicator, hdp1, hdp2, oddsspread, Is8RM, BetChoice, IsBetChoiceDetail,
			VarianceVR, SiteID)
			SELECT	[TraderId]			= CASE WHEN b.LiveIndicator = 0 THEN @IdForNonLiveUnassignedTrader ELSE ISNULL(t.TraderId, @IdForLiveUnassignedTrader) END
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
			FROM	#tmpDLFilteredBettransByBatch AS b WITH (NOLOCK)
				INNER JOIN #tmpDLSupportedBettypes AS bt WITH(NOLOCK) ON b.BetType = bt.BetType
				INNER JOIN bodb02.dbo.customer AS c WITH(NOLOCK) ON b.custid = c.CustId
				INNER JOIN bodb02.dbo.site AS s WITH(NOLOCK) ON c.Site = s.site
				LEFT JOIN #tmpDLTrader AS t WITH (NOLOCK)
						ON	b.winlostdate = t.EventDate
						AND	b.matchid = t.matchid
						AND	(b.BetType = t.BetType OR	(b.bettype = 23 AND t.BetType = 1))
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
				-- Force the output to appear immediately
				RAISERROR('From Origin - Insert #tmpDLStagingTraderPerformance - Date: "%s" - %d rows - %d ms', 0, 0, @Date, @RowCount, @Duration) WITH NOWAIT;
			END;

			UPDATE stp WITH(ROWLOCK, UPDLOCK)
			SET stp.TeamId = t.TeamId
				,	stp.Grade = t.Grade
			FROM #tmpDLStagingTraderPerformance AS stp
			INNER JOIN dbo.Trader t WITH (NOLOCK) ON t.CustId IN (@IdForLiveUnassignedTrader, @IdForNonLiveUnassignedTrader) AND stp.TraderId = t.CustId;

			DELETE tp WITH(ROWLOCK) 
			FROM dbo.TraderPerformance AS tp
				INNER JOIN #tmpDLFilteredBettypes AS bt ON tp.BetType = bt.BetType
			WHERE tp.EventDate = @winlostdate;

			INSERT INTO	dbo.TraderPerformance (CustId, WorkShift, MatchId, MatchCode, EventDate, SportType, LeagueId, HomeId, AwayId, TeamId, Grade, BetType, IsLive, 
			Stake, WinLost, Comm, Stake_AR, WinLost_AR, Comm_AR, Is8RM, Stake_Real, WinLost_Real, Stake_VAR, WinLost_VAR, BetCount, Spread, VarianceVR, SiteID)
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
			FROM	#tmpDLStagingTraderPerformance AS t WITH(NOLOCK) 
			WHERE	t.EventDate = @winlostdate
			GROUP BY t.TraderId, t.WorkShift, t.MatchId, t.MatchCode, t.EventDate, t.SportType, t.LeagueId, t.HomeId, t.AwayId, t.TeamId, t.Grade, t.BetType, t.LiveIndicator, t.Is8RM,
				t.VarianceVR, t.SiteID;
				
			SELECT	@RowCount	= @@ROWCOUNT
				,	@Duration	= DATEDIFF(millisecond, @Begin, GETDATE())
				;

			IF	@Debug = 1
			BEGIN
				-- Force the output to appear immediately
				RAISERROR('From Origin - Insert TraderPerformance - Date: "%s" - %d rows - %d ms', 0, 0, @Date, @RowCount, @Duration) WITH NOWAIT;
			END;
		
			DELETE tpc WITH(ROWLOCK) 
			FROM dbo.TraderPerformance_BetChoice AS tpc
				INNER JOIN #tmpDLFilteredBettypes AS bt ON tpc.BetType = bt.BetType
			WHERE tpc.EventDate = @winlostdate;

			INSERT INTO	dbo.TraderPerformance_BetChoice (CustId, MatchId, EventDate, SportType, LeagueId, BetType, BetChoice, IsLive, Stake, WinLost, Comm, Stake_AR, WinLost_AR, Comm_AR, Is8RM, Stake_Real, WinLost_Real, Stake_VAR, WinLost_VAR, BetCount, 
				VarianceVR, SiteID)
			SELECT		[CustId]			= t.TraderId
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
					,	[Is8RM]				= t.Is8RM
					,	[Stake_Real]		= SUM((CASE WHEN t.TPositionTaking = 1 THEN 0 ELSE (1 - t.TPositionTaking - t.ExtraPT) END * ABS(t.Stake) * t.ActualRate) * (CASE WHEN t.VirtualRate > t.ActualRate THEN t.VirtualRate/t.ActualRate ELSE 1 END))
					,	[WinLost_Real]		= SUM(-((t.WinLost + t.SMAWinLost) + t.Comm) * t.ActualRate + (CASE WHEN t.TPositionTaking = 1 THEN 0 ELSE t.WinLost + t.Comm/(1 - t.TPositionTaking) END ) * t.ExtraPT * t.ActualRate)
					,	[Stake_VAR]			= SUM(CASE WHEN t.TPositionTaking = 1 THEN 0 ELSE (1 - t.TPositionTaking - t.ExtraPT) END  * ABS(t.Stake) * t.ActualRate * (CASE WHEN t.VirtualRate > t.ActualRate THEN (t.VirtualRate/t.ActualRate -1) ELSE -(t.VirtualRate/t.ActualRate - 1) END))
					,	[WinLost_VAR]		= SUM((t.WinLost + t.SMAWinLost - (CASE WHEN t.TPositionTaking = 1 THEN 0 ELSE t.WinLost * t.ExtraPT END) + (CASE WHEN t.VirtualRate < t.ActualRate THEN (t.Comm - CASE WHEN t.TPositionTaking=1 THEN 0 ELSE t.Comm * t.ExtraPT/(1-t.TPositionTaking) END) ELSE 0 END)) * (t.VirtualRate/t.ActualRate - 1)*t.ActualRate)
					,	[BetCount]			= SUM(t.BetCount)
					,	[VarianceVR]		= t.VarianceVR
					,	[SiteID]			= t.SiteID
			FROM	#tmpDLStagingTraderPerformance AS t WITH(NOLOCK) 
			WHERE t.EventDate = @winlostdate AND t.BetChoice IS NOT NULL
			GROUP BY t.TraderId, t.MatchId, t.EventDate, t.SportType, t.LeagueId, t.BetType, t.BetChoice, t.LiveIndicator, t.Is8RM,
				t.VarianceVR, t.SiteID;
				
			SELECT	@RowCount	= @@ROWCOUNT
				,	@Duration	= DATEDIFF(millisecond, @Begin, GETDATE())
				;

			IF	@Debug = 1
			BEGIN
				-- Force the output to appear immediately
				RAISERROR('From Origin - Insert TraderPerformance_BetChoice - Date: "%s" - %d rows - %d ms', 0, 0, @Date, @RowCount, @Duration) WITH NOWAIT;
			END;

			DELETE tpc WITH(ROWLOCK) 
			FROM dbo.TraderPerformance_BetChoice_Detail AS tpc
				INNER JOIN #tmpDLSupportedBettypes AS bt ON tpc.BetType = bt.BetType
			WHERE tpc.EventDate = @winlostdate AND bt.IsBetChoiceDetail = 1;

			INSERT INTO	dbo.TraderPerformance_BetChoice_Detail (CustId, MatchId, EventDate, SportType, LeagueId, BetType, betteam, IsLive, hdp1, hdp2, oddsspread, Stake, WinLost, Comm, Stake_AR, WinLost_AR, Comm_AR, Is8RM, Stake_Real, WinLost_Real, Stake_VAR, WinLost_VAR, BetCount, 
				VarianceVR, SiteID)
			SELECT		[CustId]			= t.TraderId
					,	[MatchId]			= t.matchId
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
			FROM	#tmpDLStagingTraderPerformance AS t WITH(NOLOCK)
			WHERE t.EventDate = @winlostdate 
				AND t.BetChoice IS NOT NULL
				AND t.IsBetChoiceDetail = 1
			GROUP BY t.TraderId, t.matchId, t.EventDate, t.SportType, t.LeagueId, t.BetType, t.BetChoice, t.LiveIndicator, t.hdp1, t.hdp2, t.oddsspread, t.Is8RM,
				t.VarianceVR, t.SiteID;
				
			SELECT	@RowCount	= @@ROWCOUNT
				,	@Duration	= DATEDIFF(millisecond, @Begin, GETDATE())
				;
			
			IF	@Debug = 1
			BEGIN
				-- Force the output to appear immediately
				RAISERROR('From Origin - Insert TraderPerformance_BetChoice_Detail - Date: "%s" - %d rows - %d ms', 0, 0, @Date, @RowCount, @Duration) WITH NOWAIT;
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
			TRUNCATE TABLE #tmpHistoryCustomer;
		END;
	END;
END;

GO

/*<info serverAlias="DBTGRS-bodb_TGRS" executers="wsv_tgrs" isFunction="0" isNested="0"></info>*/
