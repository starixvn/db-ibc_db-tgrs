CREATE PROCEDURE [dbo].[Task_StagingOSDataCustomerClass]
		@Debug					BIT = 0
	,	@BeforeMoveBetsDay		BIT = 1	
	,	@GenerateFromDate		SMALLDATETIME = NULL
	,	@GenerateToDate			SMALLDATETIME = NULL
AS
/*  
	Created:	20230606@John.Ngo
	Task :		Staging Data for E-Sports/Basketball trader performance by class
	DB:			DBTGRS.bodb_TGRS
  
	Revisions:
		- 20201112@John.Ngo: Staging Data for E-Sports/Basketball trader performance by class [Redmine ID: 187083]

	Param's Explanation:
		
	Exam: EXECUTE [Task_StagingOSDataCustomerClass] @Debug = 1, @GenerateFromDate = '20190214', @GenerateToDate = '20190304'
*/
BEGIN
	SET NOCOUNT ON;

	-- Common variables
	DECLARE	@IdForUnassignedTrader	INT = 0
		;

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
		,	@winlostdate			DATETIME
		;

	-- Check running job
	DECLARE @IsRunningJob				BIT;
	
	IF (@GenerateFromDate IS NULL OR @GenerateToDate IS NULL)
	BEGIN
		SELECT @IsRunningJob = 1
	END
	--
		
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

	IF	OBJECT_ID('tempdb..#tmpDLAllBettypes') IS NOT NULL
		DROP TABLE	#tmpDLAllBettypes;

	CREATE TABLE	#tmpDLAllBettypes (
			BetType					SMALLINT
		,	AssignmentBetType		SMALLINT
		,	OperatorType			SMALLINT
		,	MainDBBettype			SMALLINT
	);
	
	CREATE CLUSTERED INDEX	#CIX_tmpDLAllBettypes_AssignmentBetType_OperatorType ON #tmpDLAllBettypes (
		AssignmentBetType	ASC,
		OperatorType		ASC
	);

	INSERT INTO #tmpDLAllBettypes(BetType)
	SELECT	DISTINCT m.bettype
	FROM	bodb02.dbo.SportBettypeMatrix AS m WITH(NOLOCK)
	WHERE	m.sporttype IN (2, 43)
		AND m.ProductID = 1
		AND	m.bettype IS NOT NULL;

	UPDATE abt
	SET abt.AssignmentBetType = b.AssignmentBettype,
		abt.OperatorType = b.OperatorType,
		abt.MainDBBettype = b.MainDBBettype
	FROM #tmpDLAllBettypes AS abt
		INNER JOIN dbo.OSBettype b WITH (NOLOCK) ON abt.BetType = b.BettypeId

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

	IF	OBJECT_ID('tempdb..#tmpStagingOSTrader') IS NOT NULL
	BEGIN
		DROP TABLE #tmpStagingOSTrader;
	END;

	CREATE TABLE	#tmpStagingOSTrader (
						TraderId			INT
					,	MatchId				INT
					,	SportType			INT
					,	EventDate			DATETIME
					,	BetType				SMALLINT
					,	UpdatedTime			DATETIME
					,	ID					INT
					,	Detail_X			SMALLINT
					,	Detail_Y			SMALLINT
					,	Detail_Z			SMALLINT
					);

	CREATE CLUSTERED INDEX	#CIX_tmpStagingOSTraderIdx ON #tmpStagingOSTrader (
			EventDate			ASC
		,	MatchId				ASC
		,	BetType				ASC
		,	Detail_X			ASC
		,	Detail_Y			ASC
		,	Detail_Z			ASC
	);

	IF	OBJECT_ID('tempdb..#tmpOSTrader') IS NOT NULL
	BEGIN
		DROP TABLE #tmpOSTrader;
	END;

	CREATE TABLE	#tmpOSTrader (
						TraderId			INT
					,	MatchId				INT
					,	SportType			INT
					,	EventDate			DATETIME
					,	BetType				SMALLINT
					,	betid				BIGINT
					);

	CREATE CLUSTERED INDEX	#CIX_tmpOSTraderIdx ON #tmpOSTrader (
			EventDate			ASC
		,	MatchId				ASC
		,	BetType				ASC
		,	betid				ASC
	);

	IF	OBJECT_ID('tempdb..#tmpWinlostdate') IS NOT NULL
	BEGIN
		DROP TABLE	#tmpWinlostdate;
	END;

	CREATE TABLE	#tmpWinlostdate (
						Winlostdate DATE
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

	IF	OBJECT_ID('tempdb..#tmpFilteredBettransByBatch') IS NOT NULL
	BEGIN
		DROP TABLE	#tmpFilteredBettransByBatch;
	END;

	CREATE TABLE	#tmpFilteredBettransByBatch (
						TransId				BIGINT
					,	CustId				INT
					,	CustomerClass		SMALLINT
					,	MatchId				INT
					,	MatchCode			VARCHAR(100)
					,	Winlostdate			SMALLDATETIME
					,	SportType			INT
					,	LeagueId			INT
					,	Bettype				SMALLINT
					,	Modds				SMALLMONEY
					,	Stake				MONEY
					,	Actual_stake		MONEY
					,	Virtualrate			FLOAT
					,	Actualrate			FLOAT
					,	Winlost				MONEY
					,	Awinlost			MONEY
					,	Mwinlost			MONEY
					,	Swinlost			MONEY
					,	Tpositiontaking		SMALLMONEY
					,	spositiontaking		SMALLMONEY
					,	mpositiontaking		SMALLMONEY
					,	apositiontaking		SMALLMONEY			
					,	Srecommend			INT
					,	Scomm				MONEY
					,	Epositiontaking		SMALLMONEY
					,	LiveIndicator		BIT
					,   BetChoice			NVARCHAR(10)
					,	betid				BIGINT
					,	AdjOdds				SMALLMONEY
					,	OriOdds				SMALLMONEY
					,	statuswinlost		TINYINT
					,	oddstype			TINYINT
					,	isDecOddsOnly		BIT
					);

	CREATE CLUSTERED INDEX	#CIX_tmpFilteredBettransByBatchIdx ON #tmpFilteredBettransByBatch (
						Winlostdate			ASC
					,	MatchId				ASC
					,	Bettype				ASC
					);
	
	CREATE NONCLUSTERED INDEX	#NCIX_tmpFilteredBettransByBatchIdx ON #tmpFilteredBettransByBatch (
					    CustId				ASC
					,	CustomerClass		ASC
					);

	IF	OBJECT_ID('tempdb..#tmpStagingOSTraderPerformance') IS NOT NULL
	BEGIN
		DROP TABLE	#tmpStagingOSTraderPerformance;
	END;

	CREATE TABLE	#tmpStagingOSTraderPerformance (
						TraderId			INT
					,	CustId				INT
					,	CustomerClass		SMALLINT
					,	EventDate			DATE
					,	SportType			INT
					,	LeagueId			INT
					,	MatchId				INT
					,	MatchCode			VARCHAR(100)
					,	BetType				SMALLINT
					,	Stake				MONEY
					,	WinLost				MONEY
					,	SMAWinLost			MONEY
					,	Comm				MONEY
					,	ExtraPT				DECIMAL(9, 8)
					,	TPositionTaking		SMALLMONEY
					,	VirtualRate			FLOAT
					,	ActualRate			FLOAT
					,	LiveIndicator		BIT
					,   BetChoice			NVARCHAR(10)
					,	betid				BIGINT
					);
	
	CREATE CLUSTERED INDEX #CIX_tmpStagingOSTraderPerformanceIdx ON #tmpStagingOSTraderPerformance (
						EventDate			ASC
	); 

	CREATE NONCLUSTERED INDEX	#NCIX_tmpStagingOSTraderPerformanceIdx ON #tmpStagingOSTraderPerformance (
						CustId				ASC
					,	CustomerClass		ASC
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
	
	DECLARE @Odds		FLOAT
		,	@winlost	MONEY
		,	@UpdateById TINYINT = 1; -- 1: by odds, 2: by winlost

	-- No input date range: Default job run
	IF (@IsRunningJob = 1)
	BEGIN
		TRUNCATE TABLE dbo.OSStaging_EventDate;

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

	IF	@IsGetDataFromBK = 1
	BEGIN
		TRUNCATE TABLE #tmpStagingOSTrader;
		TRUNCATE TABLE #tmpOSTrader;
		TRUNCATE TABLE	#ExtraPTSportbook;

		SELECT @Date = '@FromDateBK = ' + CONVERT(NVARCHAR, @FromDateBK, 120) + ', @ToDateBK = ' + CONVERT(NVARCHAR, @ToDateBK, 120);
		
		IF @DotExtraPTDate <= @FromDateBK
		BEGIN

			INSERT INTO	#tmpStagingOSTrader (TraderId, MatchId, SportType, EventDate, BetType, UpdatedTime, ID, Detail_X, Detail_Y, Detail_Z)
			SELECT	[TraderId]		= a.TraderID
				,	[MatchId]		= m.MatchId
				,	[SportType]		= m.Sporttype
				,	[EventDate]		= m.EventDate
				,	[BetType]		= a.bettype
				,	[UpdatedTime]	= a.UpdatedTime
				,	[ID]			= a.ID
				,	[Detail_X]		= CASE WHEN (m.Sporttype = 43 AND a.bettype BETWEEN 9001 AND 9142) THEN a.Detail_X ELSE -1 END
				,	[Detail_Y]		= CASE WHEN (m.Sporttype = 43 AND a.bettype BETWEEN 9001 AND 9142) THEN a.Detail_Y ELSE -1 END 
				,	[Detail_Z]		= -1
			FROM	bodb_archive.dbo.Dot_Admin_Assignment_Trader_bk AS a WITH (NOLOCK)
				INNER JOIN	bodb_Archive.dbo.Match_bk AS m WITH (NOLOCK) ON	a.matchid = m.matchid
			WHERE m.EventDate BETWEEN @FromDateBK AND @ToDateBK
				AND	m.Sporttype IN (2, 43)
				AND m.EventStatus = 'completed'
				AND	m.MatchCode NOT LIKE '%hedge%'
				AND a.TraderId <> 0;

			INSERT INTO	#tmpOSTrader (TraderId, MatchId, SportType, EventDate, BetType, betid)
			SELECT	DISTINCT
					[TraderId]	= a.TraderID
				,	[MatchId]	= a.MatchId
				,	[SportType]	= a.Sporttype
				,	[EventDate]	= a.EventDate
				,	[BetType]	= a.Bettype
				,	[betid]		= CASE WHEN a.Detail_Z <> -1 THEN 0
									WHEN a.Detail_Y <> -1 THEN (80000 + a.Detail_X*100 + a.Detail_Y) -- 80X0Y = 80000 + X*100 + Y
									WHEN a.Detail_X <> -1 THEN (800 + a.Detail_X) -- 80X = 800 + X
									ELSE 0 END -- convert to betid
			FROM	#tmpStagingOSTrader AS a WITH (NOLOCK)
			CROSS APPLY (
							SELECT dt.ID , dt.TraderID, dt.MatchId, dt.Bettype, dt.Detail_X, dt.Detail_Y, dt.Detail_Z,
								ROW_NUMBER() OVER(PARTITION BY dt.MatchId, dt.Bettype, dt.Detail_X, dt.Detail_Y, dt.Detail_Z ORDER BY dt.UpdatedTime DESC, dt.ID DESC) AS Row_Num
							FROM #tmpStagingOSTrader AS dt WITH (NOLOCK)
							WHERE   a.matchid = dt.matchid
								AND a.bettype = dt.bettype
								AND a.Detail_X = dt.Detail_X
								AND a.Detail_Y = dt.Detail_Y
								AND a.Detail_Z = dt.Detail_Z
								AND a.TraderId <> 0
							) dat
			WHERE a.EventDate BETWEEN @FromDateBK AND @ToDateBK
				AND a.ID = dat.ID
				AND dat.Row_Num = 1;

			SELECT	@RowCount	= @@ROWCOUNT
				,	@Duration	= DATEDIFF(millisecond, @Begin, GETDATE())
				;

			IF	@Debug = 1
			BEGIN
				-- Force the output to appear immediately
				RAISERROR('From BK - Insert #tmpOSTrader - Date: "%s" - %d rows - %d ms', 0, 0, @Date, @RowCount, @Duration) WITH NOWAIT;
			END;
		END;

		IF @DotExtraPTDate > @FromDateBK AND @DotExtraPTDate <= @ToDateBK
		BEGIN
			SELECT @Date = '@FromDateBK = ' + CONVERT(NVARCHAR, @FromDateBK, 120) + ', (@DotExtraPTDate - 1) = ' + CONVERT(NVARCHAR, (@DotExtraPTDate - 1), 120);

			INSERT INTO	#tmpOSTrader (TraderId, MatchId, SportType, EventDate, BetType, betid)
			SELECT	DISTINCT
					[TraderId]	= a.OperatorID
				,	[MatchId]	= m.MatchId
				,	[SportType]	= m.Sporttype
				,	[EventDate]	= m.EventDate
				,	[BetType]	= CASE	WHEN a.bettype = 5 AND a.operatortype = 1
											THEN 1
										ELSE ISNULL(b.MainDBBetType, 0) 
									END
				,	0
			FROM	bodb_archive.dbo.Dot_Admin_Assignment_Operator_bk AS a WITH (NOLOCK)
				INNER JOIN	bodb_Archive.dbo.Match_bk AS m WITH (NOLOCK) ON	a.matchid = m.matchid
				LEFT JOIN	#tmpDLAllBettypes AS b WITH (NOLOCK) ON	a.bettype = b.AssignmentBetType
						AND	a.OperatorType = b.OperatorType
			WHERE	m.EventDate BETWEEN @FromDateBK AND (@DotExtraPTDate - 1)
				AND	m.Sporttype IN (2, 43)
				AND m.EventStatus = 'completed'
				AND	m.MatchCode NOT LIKE '%hedge%'
				AND	a.OperatorType < 3
				OPTION (RECOMPILE);
		
			SELECT	@RowCount	= @@ROWCOUNT
				,	@Duration	= DATEDIFF(millisecond, @Begin, GETDATE())
				;

			IF	@Debug = 1
			BEGIN
				-- Force the output to appear immediately
				RAISERROR('From BK - Insert #tmpOSTrader - Date: "%s" - %d rows - %d ms', 0, 0, @Date, @RowCount, @Duration) WITH NOWAIT;
			END;

			-- SUM(ExtraPT)
			INSERT INTO #ExtraPTSportbook
			SELECT SuperId, SUM(ExtraPT) AS ExtraPT, FromDate, ToDate
			FROM
			(
				SELECT SuperId, ExtraPT, FromDate, ToDate
				FROM bodb02.dbo.Acc_GroupExtraPTSetting WITH (NOLOCK)
				WHERE
					(
						@FromDateBK BETWEEN FromDate AND ToDate
						OR (@DotExtraPTDate - 1) BETWEEN FromDate AND ToDate
					)
					AND ProductId = 1 AND Sporttype = 0 AND SubProduct = ''
			) A
			GROUP BY SuperId, FromDate, ToDate;

			SELECT @Date = '@DotExtraPTDate = ' + CONVERT(NVARCHAR, @DotExtraPTDate, 120) + ', @ToDateBK = ' + CONVERT(NVARCHAR, @ToDateBK, 120);

			INSERT INTO	#tmpStagingOSTrader (TraderId, MatchId, SportType, EventDate, BetType, UpdatedTime, ID, Detail_X, Detail_Y, Detail_Z)
			SELECT	[TraderId]		= a.TraderID
				,	[MatchId]		= m.MatchId
				,	[SportType]		= m.Sporttype
				,	[EventDate]		= m.EventDate
				,	[BetType]		= a.bettype
				,	[UpdatedTime]	= a.UpdatedTime
				,	[ID]			= a.ID
				,	[Detail_X]		= CASE WHEN (m.Sporttype = 43 AND a.bettype BETWEEN 9001 AND 9142) THEN a.Detail_X ELSE -1 END
				,	[Detail_Y]		= CASE WHEN (m.Sporttype = 43 AND a.bettype BETWEEN 9001 AND 9142) THEN a.Detail_Y ELSE -1 END 
				,	[Detail_Z]		= -1
			FROM	bodb_archive.dbo.Dot_Admin_Assignment_Trader_bk AS a WITH (NOLOCK)
				INNER JOIN	bodb_Archive.dbo.Match_bk AS m WITH (NOLOCK) ON	a.matchid = m.matchid
			WHERE m.EventDate BETWEEN @DotExtraPTDate AND @ToDateBK
				AND	m.Sporttype IN (2, 43)
				AND m.EventStatus = 'completed'
				AND	m.MatchCode NOT LIKE '%hedge%'
				AND a.TraderId <> 0;

			INSERT INTO	#tmpOSTrader (TraderId, MatchId, SportType, EventDate, BetType, betid)
			SELECT	DISTINCT
					[TraderId]	= a.TraderID
				,	[MatchId]	= a.MatchId
				,	[SportType]	= a.Sporttype
				,	[EventDate]	= a.EventDate
				,	[BetType]	= a.Bettype
				,	[betid]		= CASE WHEN a.Detail_Z <> -1 THEN 0
									WHEN a.Detail_Y <> -1 THEN (80000 + a.Detail_X*100 + a.Detail_Y) -- 80X0Y = 80000 + X*100 + Y
									WHEN a.Detail_X <> -1 THEN (800 + a.Detail_X) -- 80X = 800 + X
									ELSE 0 END -- convert to betid
			FROM	#tmpStagingOSTrader AS a WITH (NOLOCK)
			CROSS APPLY (
							SELECT dt.ID , dt.TraderID, dt.MatchId, dt.Bettype, dt.Detail_X, dt.Detail_Y, dt.Detail_Z,
								ROW_NUMBER() OVER(PARTITION BY dt.MatchId, dt.Bettype, dt.Detail_X, dt.Detail_Y, dt.Detail_Z ORDER BY dt.UpdatedTime DESC, dt.ID DESC) AS Row_Num
							FROM #tmpStagingOSTrader AS dt WITH (NOLOCK)
							WHERE   a.matchid = dt.matchid
								AND a.bettype = dt.bettype
								AND a.Detail_X = dt.Detail_X
								AND a.Detail_Y = dt.Detail_Y
								AND a.Detail_Z = dt.Detail_Z
								AND a.TraderId <> 0
							) dat
			WHERE a.EventDate BETWEEN @DotExtraPTDate AND @ToDateBK
				AND a.ID = dat.ID
				AND dat.Row_Num = 1;
		
			SELECT	@RowCount	= @@ROWCOUNT
				,	@Duration	= DATEDIFF(millisecond, @Begin, GETDATE())
				;

			IF	@Debug = 1
			BEGIN
				-- Force the output to appear immediately
				RAISERROR('From BK - Insert #tmpOSTrader - Date: "%s" - %d rows - %d ms', 0, 0, @Date, @RowCount, @Duration) WITH NOWAIT;
			END;

			SELECT @Date = '@FromDateBK = ' + CONVERT(NVARCHAR, @FromDateBK, 120) + ', @ToDateBK = ' + CONVERT(NVARCHAR, @ToDateBK, 120);
		END;

		IF @DotExtraPTDate > @ToDateBK 
		BEGIN
			INSERT INTO	#tmpOSTrader (TraderId, MatchId, SportType, EventDate, BetType, betid)
			SELECT	DISTINCT
					[TraderId]	= a.OperatorID
				,	[MatchId]	= m.MatchId
				,	[SportType]	= m.Sporttype
				,	[EventDate]	= m.EventDate
				,	[BetType]	= CASE	WHEN a.bettype = 5 AND a.operatortype = 1
											THEN 1
										ELSE ISNULL(b.MainDBBetType, 0) 
									END
				,	0
			FROM	bodb_archive.dbo.Dot_Admin_Assignment_Operator_bk AS a WITH (NOLOCK)
				INNER JOIN	bodb_Archive.dbo.Match_bk AS m WITH (NOLOCK) ON	a.matchid = m.matchid
				LEFT JOIN	#tmpDLAllBettypes AS b WITH (NOLOCK) ON	a.bettype = b.AssignmentBetType
						AND	a.OperatorType = b.OperatorType
			WHERE	m.EventDate BETWEEN @FromDateBK AND @ToDateBK
				AND	m.Sporttype IN (2, 43)
				AND m.EventStatus = 'completed'
				AND	m.MatchCode NOT LIKE '%hedge%'
				AND	a.OperatorType < 3
				OPTION (RECOMPILE);

			SELECT	@RowCount	= @@ROWCOUNT
				,	@Duration	= DATEDIFF(millisecond, @Begin, GETDATE())
				;

			IF	@Debug = 1
			BEGIN
				-- Force the output to appear immediately
				RAISERROR('From BK - Insert #tmpOSTrader - Date: "%s" - %d rows - %d ms', 0, 0, @Date, @RowCount, @Duration) WITH NOWAIT;
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
	
		INSERT INTO	#tmpWinlostdate (winlostdate)
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
			RAISERROR('From BK - Insert #tmpWinlostdate - Date: "%s" - %d rows - %d ms', 0, 0, @Date, @RowCount, @Duration) WITH NOWAIT;
		END;

		-- No input date range: Default job run
		IF (@IsRunningJob = 1)
		BEGIN
			INSERT INTO dbo.OSStaging_EventDate(EventDate)
			SELECT Winlostdate FROM #tmpWinlostdate

			SELECT	@RowCount	= @@ROWCOUNT
				,	@Duration	= DATEDIFF(millisecond, @Begin, GETDATE())
				;

			IF	@Debug = 1
			BEGIN
				-- Force the output to appear immediately --
				RAISERROR('From BK - Insert OSStaging_EventDate - %d rows - %d ms', 0, 0, @RowCount, @Duration) WITH NOWAIT;
			END;
		END;

		WHILE	EXISTS (SELECT 1 FROM #tmpWinlostdate)
		BEGIN
			SELECT	TOP(1)
					@WinLostDate = d.winlostdate
			FROM	#tmpWinlostdate AS d;
			
			SELECT @Date = CONVERT(NVARCHAR, @Winlostdate, 120);

			TRUNCATE TABLE	#tmpFilteredBettransByBatch;
			-- Fix Odds Spread Setting - ReCalculate Original Winlost (b.winlost - b.actual_stake)
			INSERT INTO #tmpFilteredBettransByBatch 
					(TransId, CustId, CustomerClass, MatchId, MatchCode, Winlostdate, SportType, LeagueId, Bettype, Modds, Stake, Actual_stake, Virtualrate, Actualrate, Winlost, Awinlost, Mwinlost, Swinlost, Tpositiontaking,
					spositiontaking, mpositiontaking, apositiontaking, Srecommend, Scomm, Epositiontaking, LiveIndicator, BetChoice, betid, AdjOdds, OriOdds ,statuswinlost, oddstype, isDecOddsOnly)
			SELECT	b.transid, b.custid
				,	[CustomerClass]		= CASE WHEN CAST(b.ExtraInfo AS XML).exist('/p1/@cc') = 1 THEN
											ISNULL(CAST(('<xml>' + b.ExtraInfo + '</xml>') AS XML).value('data(/xml/p1/@cc)[1]','SMALLINT'), 0)
										  ELSE NULL END
				,	b.matchid, m.matchcode, b.winlostdate, m.sporttype, m.leagueid, b.bettype, b.modds, b.stake, b.actual_stake, b.virtualrate, b.actualrate, (b.winlost - b.actual_stake), b.awinlost,
					b.mwinlost, b.swinlost,	b.tpositiontaking, b.spositiontaking, b.mpositiontaking, b.apositiontaking, b.srecommend, b.Scomm, b.epositiontaking, b.liveindicator, b.betteam, betid
				,	[AdjOdds]			= CASE WHEN fdec.OddsType IS NOT NULL THEN b.odds - 1 ELSE b.odds END
				,	[OriOdds]			= CASE WHEN CAST(b.ExtraInfo AS XML).exist('/p1/@oo') = 1 THEN
												CASE WHEN fdec.OddsType IS NOT NULL THEN
													 ISNULL(CAST(('<xml>' + b.ExtraInfo + '</xml>') AS XML).value('data(/xml/p1/@oo)[1]','SMALLMONEY'), 0) - 1
												ELSE ISNULL(CAST(('<xml>' + b.ExtraInfo + '</xml>') AS XML).value('data(/xml/p1/@oo)[1]','SMALLMONEY'), 0) END
										  ELSE NULL END
				,	[statuswinlost]		= b.statuswinlost
				,	[oddstype]			= b.oddstype
				,	[isDecOddsOnly]		= CASE WHEN fdec.OddsType IS NOT NULL THEN 1 ELSE 0 END
			FROM	bodb_Archive.dbo.bettrans_bk AS b WITH (NOLOCK)
				INNER JOIN bodb_Archive.dbo.match_bk m WITH (NOLOCK) ON b.MatchId = m.MatchId
				INNER JOIN bodb02.dbo.SportBettypeMatrix sbm ON m.Sporttype = sbm.SportType AND b.bettype = sbm.BetType AND b.liveindicator = sbm.IsLive
				LEFT JOIN bodb02.dbo.f_Set_OddsTypeBettypes() fdec  ON b.bettype = fdec.BetType
			WHERE	b.winlostdate = @WinLostDate
					AND m.eventdate = @WinLostDate
					AND	b.statusID IN (111,112, 113)
					AND	b.Currency NOT IN (20, 27, 28)
					AND sbm.ProductID = 1
					AND sbm.Sporttype IN (2, 43)
					AND m.EventStatus = 'completed'
					AND	m.MatchCode NOT LIKE '%hedge%'
			OPTION (RECOMPILE);
			
			SELECT	@RowCount	= @@ROWCOUNT
				,	@Duration	= DATEDIFF(millisecond, @Begin, GETDATE())
				;
	
			IF	@Debug = 1
			BEGIN
				-- Force the output to appear immediately
				RAISERROR('From BK - Insert #tmpFilteredBettransByBatch - Date: "%s" - %d rows - %d ms', 0, 0, @Date, @RowCount, @Duration) WITH NOWAIT;
			END;

			-- "DISTINCT" Prevent Page Splits
			DELETE b WITH(ROWLOCK)
			FROM	(	
						SELECT ROW_NUMBER() OVER (PARTITION BY TransId ORDER BY TransId) AS rn
						FROM #tmpFilteredBettransByBatch
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
			FROM #tmpFilteredBettransByBatch AS b
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
				RAISERROR('From BK - ReCalculate Original Winlost #tmpFilteredBettransByBatch - Date: "%s" - %d rows - %d ms', 0, 0, @Date, @RowCount, @Duration) WITH NOWAIT;
			END;
			
			INSERT INTO #tmpStagingOSTraderPerformance (TraderId, CustId, CustomerClass, EventDate, SportType, LeagueId, MatchId, MatchCode, BetType, Stake, WinLost, SMAWinLost, Comm, ExtraPT, TPositionTaking, VirtualRate, ActualRate, LiveIndicator, BetChoice, betid)
			SELECT	[TraderId]			= ISNULL(t.TraderId, @IdForUnassignedTrader)
				,	[MemberCustId]		= b.custid
				,	[CustomerClass]		= b.CustomerClass
				,	[EventDate]			= b.winlostdate
				,	[SportType]			= b.SportType
				,	[LeagueId]			= b.LeagueId
				,	[MatchId]			= b.matchid
				,	[MatchCode]			= b.MatchCode
				,	[BetType]			= b.bettype
				,	[Stake]				= ((CASE WHEN b.modds = 0.25 OR b.modds = -0.25 THEN ABS(b.stake) / 2 ELSE ABS(b.stake) END))
				,	[WinLost]			= b.winlost
				,	[SMAWinLost]		= (b.awinlost + b.mwinlost + b.swinlost)
				,	[Comm]				= b.scomm
				,	[ExtraPT]			= CASE WHEN b.Winlostdate < '20200213' THEN ISNULL(es.ExtraPT, 0) ELSE ISNULL(b.epositiontaking, 0) END
				,	[TPositionTaking]	= b.tpositiontaking
				,	[VirtualRate]		= b.virtualrate
				,	[ActualRate]		= b.actualrate
				,	[LiveIndicator]		= b.LiveIndicator
				,	[BetChoice]			= b.BetChoice
				,	[betid]				= b.betid
			FROM	#tmpFilteredBettransByBatch AS b
				LEFT JOIN	#tmpOSTrader AS t WITH (NOLOCK) ON	b.winlostdate = t.EventDate
					AND	b.matchid = t.matchid
					AND	b.bettype = t.BetType
					AND b.betid = (CASE WHEN t.betid <> 0 THEN t.betid ELSE b.betid END) -- Only mapping betid for 80X, 80X0Y
				LEFT JOIN	#ExtraPTSportbook AS es WITH (NOLOCK) ON es.SuperId = b.srecommend
					AND	b.winlostdate BETWEEN es.FromDate AND es.ToDate
			OPTION (MAXDOP 2);

			SELECT	@RowCount	= @@ROWCOUNT
				,	@Duration	= DATEDIFF(millisecond, @Begin, GETDATE())
				;

			IF	@Debug = 1
			BEGIN
				-- Force the output to appear immediately
				RAISERROR('From BK - Insert #tmpStagingOSTraderPerformance - Date: "%s" - %d rows - %d ms', 0, 0, @Date, @RowCount, @Duration) WITH NOWAIT;
			END;
			
			DELETE tp WITH(ROWLOCK) 
			FROM dbo.OSDataTGRS_CustomerClass AS tp WHERE tp.EventDate = @winlostdate;

			INSERT INTO	dbo.OSDataTGRS_CustomerClass (TraderId, CustomerClass, SportId, LeagueId, MatchId, EventDate, BettypeId, Turnover, WinLoss, Comm, Turnover_AR, WinLoss_AR, Comm_AR, BetCount, IsLive)
			SELECT	[TraderId]		= b.TraderId
				,	[CustomerClass]	= b.CustomerClass
				,	[SportId]		= b.SportType
				,	[LeagueId]		= b.LeagueId
				,	[MatchId]		= b.MatchId
				,	[EventDate]		= b.EventDate
				,	[BettypeId]		= b.BetType
				,	[Turnover]		= SUM(b.Stake * (1 - b.TPositionTaking - b.ExtraPT) * b.VirtualRate)
				,	[WinLoss]		= SUM(((-(b.WinLost + b.SMAWinLost)) + b.WinLost * b.ExtraPT) * b.VirtualRate)
				,	[Comm]			= SUM((b.Comm - (CASE WHEN b.TPositionTaking = 1 THEN 0 ELSE (b.Comm * b.ExtraPT / (1 - b.TPositionTaking)) END)) * (CASE WHEN b.VirtualRate > b.ActualRate THEN b.ActualRate ELSE b.VirtualRate END))
				,	[Turnover_AR]	= SUM(b.Stake * (1 - b.TPositionTaking - b.ExtraPT) * (CASE WHEN b.VirtualRate > b.ActualRate THEN b.VirtualRate ELSE b.ActualRate END))
				,	[WinLoss_AR]	= SUM(((-(b.WinLost + b.SMAWinLost)) + b.WinLost * b.ExtraPT) * b.ActualRate)
				,	[Comm_AR]		= SUM((b.Comm - (CASE WHEN b.TPositionTaking = 1 THEN 0 ELSE (b.Comm * b.ExtraPT/(1 - b.TPositionTaking)) END)) * b.ActualRate)
				,	[BetCount]		= SUM(CASE WHEN tc.custid IS NULL THEN 1 ELSE 0 END)  -- Exclude Cashout Ticket
				,	[IsLive]		= b.LiveIndicator
			FROM	#tmpStagingOSTraderPerformance AS b WITH (NOLOCK)
				LEFT JOIN bodb02.dbo.TradeCust tc WITH (NOLOCK) ON b.CustId = tc.CustId AND tc.VendorID = 14
			WHERE b.eventdate = @WinLostDate
			GROUP BY b.TraderId, b.CustomerClass, b.SportType, b.LeagueId, b.MatchId, b.MatchCode, b.EventDate, b.BetType, b.LiveIndicator;
			
			SELECT	@RowCount	= @@ROWCOUNT
				,	@Duration	= DATEDIFF(millisecond, @Begin, GETDATE())
				;

			IF	@Debug = 1
			BEGIN
				-- Force the output to appear immediately
				RAISERROR('From BK - Insert OSDataTGRS_CustomerClass - Date: "%s" - %d rows - %d ms', 0, 0, @Date, @RowCount, @Duration) WITH NOWAIT;
			END;

			-- Remove batched-data (date) from source
			DELETE
			FROM	#tmpWinlostdate
			WHERE	winlostdate = @winlostdate;
			
			TRUNCATE TABLE	#tmpStagingOSTraderPerformance;
			TRUNCATE TABLE	#tmpFilteredBettransByBatch;
		END;
	END;

	IF	@IsGetDataFrom14 = 1
	BEGIN
		TRUNCATE TABLE #tmpStagingOSTrader;
		TRUNCATE TABLE #tmpOSTrader;
		TRUNCATE TABLE #ExtraPTSportbook;
		
		SELECT @Date = '@FromDate14 = ' + CONVERT(NVARCHAR, @FromDate14, 120) + ', @ToDate14 = ' + CONVERT(NVARCHAR, @ToDate14, 120);

		INSERT INTO	#tmpStagingOSTrader (TraderId, MatchId, SportType, EventDate, BetType, UpdatedTime, ID, Detail_X, Detail_Y, Detail_Z)
			SELECT	[TraderId]		= a.TraderID
				,	[MatchId]		= m.MatchId
				,	[SportType]		= m.Sporttype
				,	[EventDate]		= m.EventDate
				,	[BetType]		= a.bettype
				,	[UpdatedTime]	= a.UpdatedTime
				,	[ID]			= a.ID
				,	[Detail_X]		= CASE WHEN (m.Sporttype = 43 AND a.bettype BETWEEN 9001 AND 9142) THEN a.Detail_X ELSE -1 END
				,	[Detail_Y]		= CASE WHEN (m.Sporttype = 43 AND a.bettype BETWEEN 9001 AND 9142) THEN a.Detail_Y ELSE -1 END 
				,	[Detail_Z]		= -1
			FROM	bodb02.dbo.Dot_Admin_Assignment_Trader AS a WITH (NOLOCK)
			INNER JOIN	bodb02.dbo.Match14 AS m WITH (NOLOCK) ON a.matchid = m.matchid
			WHERE m.EventDate BETWEEN @FromDate14 AND @ToDate14
				AND	m.Sporttype IN (2, 43)
				AND m.EventStatus = 'completed'
				AND	m.MatchCode NOT LIKE '%hedge%'
				AND a.TraderId <> 0;

			INSERT INTO	#tmpOSTrader (TraderId, MatchId, SportType, EventDate, BetType, betid)
			SELECT	DISTINCT
					[TraderId]	= a.TraderID
				,	[MatchId]	= a.MatchId
				,	[SportType]	= a.Sporttype
				,	[EventDate]	= a.EventDate
				,	[BetType]	= a.Bettype
				,	[betid]		= CASE WHEN a.Detail_Z <> -1 THEN 0
									WHEN a.Detail_Y <> -1 THEN (80000 + a.Detail_X*100 + a.Detail_Y) -- 80X0Y = 80000 + X*100 + Y
									WHEN a.Detail_X <> -1 THEN (800 + a.Detail_X) -- 80X = 800 + X
									ELSE 0 END -- convert to betid
			FROM	#tmpStagingOSTrader AS a WITH (NOLOCK)
			CROSS APPLY (
							SELECT dt.ID , dt.TraderID, dt.MatchId, dt.Bettype, dt.Detail_X, dt.Detail_Y, dt.Detail_Z,
								ROW_NUMBER() OVER(PARTITION BY dt.MatchId, dt.Bettype, dt.Detail_X, dt.Detail_Y, dt.Detail_Z ORDER BY dt.UpdatedTime DESC, dt.ID DESC) AS Row_Num
							FROM #tmpStagingOSTrader AS dt WITH (NOLOCK)
							WHERE   a.matchid = dt.matchid
								AND a.bettype = dt.bettype
								AND a.Detail_X = dt.Detail_X
								AND a.Detail_Y = dt.Detail_Y
								AND a.Detail_Z = dt.Detail_Z
								AND a.TraderId <> 0
							) dat
			WHERE a.EventDate BETWEEN @FromDate14 AND @ToDate14
				AND a.ID = dat.ID
				AND dat.Row_Num = 1;

		SELECT	@RowCount	= @@ROWCOUNT
			,	@Duration	= DATEDIFF(millisecond, @Begin, GETDATE())
			;

		IF	@Debug = 1
		BEGIN
			-- Force the output to appear immediately
			RAISERROR('From 14 - Insert #tmpOSTrader - Date: "%s" - %d rows - %d ms', 0, 0, @Date, @RowCount, @Duration) WITH NOWAIT;
		END;
	
		INSERT INTO	#tmpWinlostdate (winlostdate)
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
			RAISERROR('From 14 - Insert #tmpWinlostdate - Date: "%s" - %d rows - %d ms', 0, 0, @Date, @RowCount, @Duration) WITH NOWAIT;
		END;

		-- No input date range: Default job run
		IF (@IsRunningJob = 1)
		BEGIN
			INSERT INTO dbo.OSStaging_EventDate(EventDate)
			SELECT Winlostdate FROM #tmpWinlostdate

			SELECT	@RowCount	= @@ROWCOUNT
				,	@Duration	= DATEDIFF(millisecond, @Begin, GETDATE())
				;

			IF	@Debug = 1
			BEGIN
				-- Force the output to appear immediately --
				RAISERROR('From 14 - Insert OSStaging_EventDate - %d rows - %d ms', 0, 0, @RowCount, @Duration) WITH NOWAIT;
			END;
		END;

		WHILE	EXISTS (SELECT 1 FROM #tmpWinlostdate)
		BEGIN
			SELECT	TOP(1)
					@WinLostDate = d.winlostdate
			FROM	#tmpWinlostdate AS d;
			
			SELECT @Date = CONVERT(NVARCHAR, @winlostdate, 120);

			TRUNCATE TABLE	#tmpFilteredBettransByBatch;
			-- Fix Odds Spread Setting - ReCalculate Original Winlost (b.winlost - b.actual_stake)
			INSERT INTO #tmpFilteredBettransByBatch 
					(TransId, CustId, CustomerClass, MatchId, MatchCode, Winlostdate, SportType, LeagueId, Bettype, Modds, Stake, Actual_stake, Virtualrate, Actualrate, Winlost, Awinlost, Mwinlost, Swinlost, Tpositiontaking,
					spositiontaking, mpositiontaking, apositiontaking, Srecommend, Scomm, Epositiontaking, LiveIndicator, BetChoice, betid, AdjOdds, OriOdds ,statuswinlost, oddstype, isDecOddsOnly)
			SELECT	b.transid, b.custid
				,	[CustomerClass]		= CASE WHEN CAST(b.ExtraInfo AS XML).exist('/p1/@cc') = 1 THEN
											ISNULL(CAST(('<xml>' + b.ExtraInfo + '</xml>') AS XML).value('data(/xml/p1/@cc)[1]','SMALLINT'), 0)
										  ELSE NULL END
				,	b.matchid, m.matchcode, b.winlostdate, m.sporttype, m.leagueid, b.bettype, b.modds, b.stake, b.actual_stake, b.virtualrate, b.actualrate, (b.winlost - b.actual_stake), b.awinlost,
					b.mwinlost, b.swinlost,	b.tpositiontaking, b.spositiontaking, b.mpositiontaking, b.apositiontaking, b.srecommend, b.Scomm, b.epositiontaking, b.liveindicator, b.betteam, betid
				,	[AdjOdds]			= CASE WHEN fdec.OddsType IS NOT NULL THEN b.odds - 1 ELSE b.odds END
				,	[OriOdds]			= CASE WHEN fdec.OddsType IS NOT NULL THEN bi.OriginalOdds - 1 ELSE bi.OriginalOdds END
				,	[statuswinlost]		= b.statuswinlost
				,	[oddstype]			= b.oddstype
				,	[isDecOddsOnly]		= CASE WHEN fdec.OddsType IS NOT NULL THEN 1 ELSE 0 END
			FROM	bodb02.dbo.bettrans14 AS b WITH (NOLOCK)
				INNER JOIN bodb02.dbo.match14 m WITH (NOLOCK) ON b.MatchId = m.MatchId
				INNER JOIN bodb02.dbo.SportBettypeMatrix sbm ON m.Sporttype = sbm.SportType AND b.bettype = sbm.BetType AND b.liveindicator = sbm.IsLive
				LEFT JOIN bodb02.dbo.BettransInfo14 bi WITH (NOLOCK) ON b.transid = bi.transid
				LEFT JOIN bodb02.dbo.f_Set_OddsTypeBettypes() fdec  ON b.bettype = fdec.BetType
			WHERE	b.winlostdate = @WinLostDate
					AND m.eventdate = @WinLostDate
					AND	b.statusID IN (111,112, 113)
					AND	b.Currency NOT IN (20, 27, 28)
					AND sbm.ProductID = 1
					AND sbm.Sporttype IN (2, 43)
					AND m.EventStatus = 'completed'
					AND	m.MatchCode NOT LIKE '%hedge%'
			OPTION (RECOMPILE);
			
			SELECT	@RowCount	= @@ROWCOUNT
				,	@Duration	= DATEDIFF(millisecond, @Begin, GETDATE())
				;
	
			IF	@Debug = 1
			BEGIN
				-- Force the output to appear immediately
				RAISERROR('From 14 - Insert #tmpFilteredBettransByBatch - Date: "%s" - %d rows - %d ms', 0, 0, @Date, @RowCount, @Duration) WITH NOWAIT;
			END;
			
			-- "DISTINCT" Prevent Page Splits
			DELETE b WITH(ROWLOCK)
			FROM	(	
						SELECT ROW_NUMBER() OVER (PARTITION BY TransId ORDER BY TransId) AS rn
						FROM #tmpFilteredBettransByBatch
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
			FROM #tmpFilteredBettransByBatch AS b
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
				RAISERROR('From 14 - ReCalculate Original Winlost #tmpFilteredBettransByBatch - Date: "%s" - %d rows - %d ms', 0, 0, @Date, @RowCount, @Duration) WITH NOWAIT;
			END;

			INSERT INTO #tmpStagingOSTraderPerformance (TraderId, CustId, CustomerClass, EventDate, SportType, LeagueId, MatchId, MatchCode, BetType, Stake, WinLost, SMAWinLost, Comm, ExtraPT, TPositionTaking, VirtualRate, ActualRate, LiveIndicator, BetChoice, betid)
			SELECT	[TraderId]			= ISNULL(t.TraderId, @IdForUnassignedTrader)
				,	[MemberCustId]		= b.custid
				,	[CustomerClass]		= b.CustomerClass
				,	[EventDate]			= b.winlostdate
				,	[SportType]			= b.SportType
				,	[LeagueId]			= b.LeagueId
				,	[MatchId]			= b.matchid
				,	[MatchCode]			= b.MatchCode
				,	[BetType]			= b.bettype
				,	[Stake]				= ((CASE WHEN b.modds = 0.25 OR b.modds = -0.25 THEN ABS(b.stake) / 2 ELSE ABS(b.stake) END))
				,	[WinLost]			= b.winlost
				,	[SMAWinLost]		= (b.awinlost + b.mwinlost + b.swinlost)
				,	[Comm]				= b.scomm
				,	[ExtraPT]			= CASE WHEN b.Winlostdate < '20200213' THEN ISNULL(es.ExtraPT, 0) ELSE ISNULL(b.epositiontaking, 0) END
				,	[TPositionTaking]	= b.tpositiontaking
				,	[VirtualRate]		= b.virtualrate
				,	[ActualRate]		= b.actualrate
				,	[LiveIndicator]		= b.LiveIndicator
				,	[BetChoice]			= b.BetChoice
				,	[betid]				= b.betid
			FROM	#tmpFilteredBettransByBatch AS b
				LEFT JOIN	#tmpOSTrader AS t WITH (NOLOCK) ON	b.winlostdate = t.EventDate
					AND	b.matchid = t.matchid
					AND	b.bettype = t.BetType
					AND b.betid = (CASE WHEN t.betid <> 0 THEN t.betid ELSE b.betid END) -- Only mapping betid for 80X, 80X0Y
				LEFT JOIN	#ExtraPTSportbook AS es WITH (NOLOCK) ON es.SuperId = b.srecommend
					AND	b.winlostdate BETWEEN es.FromDate AND es.ToDate
			OPTION (MAXDOP 2);

			SELECT	@RowCount	= @@ROWCOUNT
				,	@Duration	= DATEDIFF(millisecond, @Begin, GETDATE())
				;

			IF	@Debug = 1
			BEGIN
				-- Force the output to appear immediately
				RAISERROR('From 14 - Insert #tmpStagingOSTraderPerformance - Date: "%s" - %d rows - %d ms', 0, 0, @Date, @RowCount, @Duration) WITH NOWAIT;
			END;

			DELETE tp WITH(ROWLOCK) 
			FROM dbo.OSDataTGRS_CustomerClass AS tp WHERE tp.EventDate = @winlostdate;

			INSERT INTO	dbo.OSDataTGRS_CustomerClass (TraderId, CustomerClass, SportId, LeagueId, MatchId, EventDate, BettypeId, Turnover, WinLoss, Comm, Turnover_AR, WinLoss_AR, Comm_AR, BetCount, IsLive)
			SELECT	[TraderId]		= b.TraderId
				,	[CustomerClass]	= b.CustomerClass
				,	[SportId]		= b.SportType
				,	[LeagueId]		= b.LeagueId
				,	[MatchId]		= b.MatchId
				,	[EventDate]		= b.EventDate
				,	[BettypeId]		= b.BetType
				,	[Turnover]		= SUM(b.Stake * (1 - b.TPositionTaking - b.ExtraPT) * b.VirtualRate)
				,	[WinLoss]		= SUM(((-(b.WinLost + b.SMAWinLost)) + b.WinLost * b.ExtraPT) * b.VirtualRate)
				,	[Comm]			= SUM((b.Comm - (CASE WHEN b.TPositionTaking = 1 THEN 0 ELSE (b.Comm * b.ExtraPT / (1 - b.TPositionTaking)) END)) * (CASE WHEN b.VirtualRate > b.ActualRate THEN b.ActualRate ELSE b.VirtualRate END))
				,	[Turnover_AR]	= SUM(b.Stake * (1 - b.TPositionTaking - b.ExtraPT) * (CASE WHEN b.VirtualRate > b.ActualRate THEN b.VirtualRate ELSE b.ActualRate END))
				,	[WinLoss_AR]	= SUM(((-(b.WinLost + b.SMAWinLost)) + b.WinLost * b.ExtraPT) * b.ActualRate)
				,	[Comm_AR]		= SUM((b.Comm - (CASE WHEN b.TPositionTaking = 1 THEN 0 ELSE (b.Comm * b.ExtraPT/(1 - b.TPositionTaking)) END)) * b.ActualRate)
				,	[BetCount]		= SUM(CASE WHEN tc.custid IS NULL THEN 1 ELSE 0 END)  -- Exclude Cashout Ticket
				,	[IsLive]		= b.LiveIndicator
			FROM	#tmpStagingOSTraderPerformance AS b WITH (NOLOCK)
				LEFT JOIN bodb02.dbo.TradeCust tc WITH (NOLOCK) ON b.CustId = tc.CustId AND tc.VendorID = 14
			WHERE b.eventdate = @WinLostDate
			GROUP BY b.TraderId, b.CustomerClass, b.SportType, b.LeagueId, b.MatchId, b.MatchCode, b.EventDate, b.BetType, b.LiveIndicator;
			
			SELECT	@RowCount	= @@ROWCOUNT
				,	@Duration	= DATEDIFF(millisecond, @Begin, GETDATE())
				;

			IF	@Debug = 1
			BEGIN
				-- Force the output to appear immediately
				RAISERROR('From 14 - Insert OSDataTGRS_CustomerClass - Date: "%s" - %d rows - %d ms', 0, 0, @Date, @RowCount, @Duration) WITH NOWAIT;
			END;
			
			-- Remove batched-data (date) from source
			DELETE
			FROM	#tmpWinlostdate
			WHERE	Winlostdate = @winlostdate;
			
			TRUNCATE TABLE	#tmpStagingOSTraderPerformance;
			TRUNCATE TABLE	#tmpFilteredBettransByBatch;
		END;
	END;
	
	IF	@IsGetDataFromOrigin = 1
	BEGIN	
		TRUNCATE TABLE #tmpStagingOSTrader;
		TRUNCATE TABLE #tmpOSTrader;
		TRUNCATE TABLE #ExtraPTSportbook;
		
		SELECT @Date = '@FromDateOrigin = ' + CONVERT(NVARCHAR, @FromDateOrigin, 120) + ', @ToDateOrigin = ' + CONVERT(NVARCHAR, @ToDateOrigin, 120);
		
		INSERT INTO	#tmpStagingOSTrader (TraderId, MatchId, SportType, EventDate, BetType, UpdatedTime, ID, Detail_X, Detail_Y, Detail_Z)
		SELECT	[TraderId]		= a.TraderID
			,	[MatchId]		= m.MatchId
			,	[SportType]		= m.Sporttype
			,	[EventDate]		= m.EventDate
			,	[BetType]		= a.bettype
			,	[UpdatedTime]	= a.UpdatedTime
			,	[ID]			= a.ID
			,	[Detail_X]		= CASE WHEN (m.Sporttype = 43 AND a.bettype BETWEEN 9001 AND 9142) THEN a.Detail_X ELSE -1 END
			,	[Detail_Y]		= CASE WHEN (m.Sporttype = 43 AND a.bettype BETWEEN 9001 AND 9142) THEN a.Detail_Y ELSE -1 END 
			,	[Detail_Z]		= -1
		FROM	bodb02.dbo.Dot_Admin_Assignment_Trader AS a WITH (NOLOCK)
		INNER JOIN	bodb02.dbo.match AS m WITH (NOLOCK) ON	a.matchid = m.matchid
		WHERE m.EventDate BETWEEN @FromDateOrigin AND @ToDateOrigin
			AND	m.Sporttype IN (2, 43)
			AND m.EventStatus = 'completed'
			AND	m.MatchCode NOT LIKE '%hedge%'
			AND a.TraderId <> 0;

		INSERT INTO	#tmpOSTrader (TraderId, MatchId, SportType, EventDate, BetType, betid)
		SELECT	DISTINCT
				[TraderId]	= a.TraderID
			,	[MatchId]	= a.MatchId
			,	[SportType]	= a.Sporttype
			,	[EventDate]	= a.EventDate
			,	[BetType]	= a.Bettype
			,	[betid]		= CASE WHEN a.Detail_Z <> -1 THEN 0
								WHEN a.Detail_Y <> -1 THEN (80000 + a.Detail_X*100 + a.Detail_Y) -- 80X0Y = 80000 + X*100 + Y
								WHEN a.Detail_X <> -1 THEN (800 + a.Detail_X) -- 80X = 800 + X
								ELSE 0 END -- convert to betid
		FROM	#tmpStagingOSTrader AS a WITH (NOLOCK)
		CROSS APPLY (
						SELECT dt.ID , dt.TraderID, dt.MatchId, dt.Bettype, dt.Detail_X, dt.Detail_Y, dt.Detail_Z,
								ROW_NUMBER() OVER(PARTITION BY dt.MatchId, dt.Bettype, dt.Detail_X, dt.Detail_Y, dt.Detail_Z ORDER BY dt.UpdatedTime DESC, dt.ID DESC) AS Row_Num
						FROM #tmpStagingOSTrader AS dt WITH (NOLOCK)
						WHERE   a.matchid = dt.matchid
							AND a.bettype = dt.bettype
							AND a.Detail_X = dt.Detail_X
							AND a.Detail_Y = dt.Detail_Y
							AND a.Detail_Z = dt.Detail_Z
							AND a.TraderId <> 0
						) dat
		WHERE a.EventDate BETWEEN @FromDateOrigin AND @ToDateOrigin
			AND a.ID = dat.ID
			AND dat.Row_Num = 1;

		SELECT	@RowCount	= @@ROWCOUNT
			,	@Duration	= DATEDIFF(millisecond, @Begin, GETDATE())
			;

		IF	@Debug = 1
		BEGIN
			-- Force the output to appear immediately
			RAISERROR('From Origin - Insert #tmpOSTrader - Date: "%s" - %d rows - %d ms', 0, 0, @Date, @RowCount, @Duration) WITH NOWAIT;
		END;
	
		INSERT INTO	#tmpWinlostdate (winlostdate)
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
			RAISERROR('From Origin - Insert #tmpWinlostdate - Date: "%s" - %d rows - %d ms', 0, 0, @Date, @RowCount, @Duration) WITH NOWAIT;
		END;

		-- No input date range: Default job run
		IF (@IsRunningJob = 1)
		BEGIN
			INSERT INTO dbo.OSStaging_EventDate(EventDate)
			SELECT Winlostdate FROM #tmpWinlostdate

			SELECT	@RowCount	= @@ROWCOUNT
				,	@Duration	= DATEDIFF(millisecond, @Begin, GETDATE())
				;

			IF	@Debug = 1
			BEGIN
				-- Force the output to appear immediately --
				RAISERROR('From Origin - Insert OSStaging_EventDate - %d rows - %d ms', 0, 0, @RowCount, @Duration) WITH NOWAIT;
			END;
		END;

		WHILE	EXISTS (SELECT 1 FROM #tmpWinlostdate)
		BEGIN
			SELECT	TOP(1)
					@WinLostDate = d.winlostdate
			FROM	#tmpWinlostdate AS d;
			
			SELECT @Date = CONVERT(NVARCHAR, @winlostdate, 120);

			TRUNCATE TABLE	#tmpFilteredBettransByBatch;
			-- Fix Odds Spread Setting - ReCalculate Original Winlost (b.winlost - b.actual_stake)
			INSERT INTO #tmpFilteredBettransByBatch 
					(TransId, CustId, CustomerClass, MatchId, MatchCode, Winlostdate, SportType, LeagueId, Bettype, Modds, Stake, Actual_stake, Virtualrate, Actualrate, Winlost, Awinlost, Mwinlost, Swinlost, Tpositiontaking,
					spositiontaking, mpositiontaking, apositiontaking, Srecommend, Scomm, Epositiontaking, LiveIndicator, BetChoice, betid, AdjOdds, OriOdds ,statuswinlost, oddstype, isDecOddsOnly)
			SELECT	b.transid, b.custid
				,	[CustomerClass]		= CASE WHEN CAST(b.ExtraInfo AS XML).exist('/p1/@cc') = 1 THEN
											ISNULL(CAST(('<xml>' + b.ExtraInfo + '</xml>') AS XML).value('data(/xml/p1/@cc)[1]','SMALLINT'), 0)
										  ELSE NULL END
				,	b.matchid, m.matchcode, b.winlostdate, m.sporttype, m.leagueid, b.bettype, b.modds, b.stake, b.actual_stake, b.virtualrate, b.actualrate, (b.winlost - b.actual_stake), b.awinlost,
					b.mwinlost, b.swinlost,	b.tpositiontaking, b.spositiontaking, b.mpositiontaking, b.apositiontaking, b.srecommend, b.Scomm, b.epositiontaking, b.liveindicator, b.betteam, betid
				,	[AdjOdds]			= CASE WHEN fdec.OddsType IS NOT NULL THEN b.odds - 1 ELSE b.odds END
				,	[OriOdds]			= CASE WHEN fdec.OddsType IS NOT NULL THEN bi.OriginalOdds - 1 ELSE bi.OriginalOdds END
				,	[statuswinlost]		= b.statuswinlost
				,	[oddstype]			= b.oddstype
				,	[isDecOddsOnly]		= CASE WHEN fdec.OddsType IS NOT NULL THEN 1 ELSE 0 END
			FROM	bodb02.dbo.bettrans AS b WITH (NOLOCK)
				INNER JOIN bodb02.dbo.match m WITH (NOLOCK) ON b.MatchId = m.MatchId
				INNER JOIN bodb02.dbo.SportBettypeMatrix sbm ON m.Sporttype = sbm.SportType AND b.bettype = sbm.BetType AND b.liveindicator = sbm.IsLive
				LEFT JOIN bodb02.dbo.BettransInfo bi WITH (NOLOCK) ON b.transid = bi.transid
				LEFT JOIN bodb02.dbo.f_Set_OddsTypeBettypes() fdec  ON b.bettype = fdec.BetType
			WHERE	b.winlostdate = @WinLostDate
					AND m.eventdate = @WinLostDate
					AND	b.statusID IN (111,112, 113)
					AND	b.Currency NOT IN (20, 27, 28)
					AND sbm.ProductID = 1
					AND sbm.Sporttype IN (2, 43)
					AND m.EventStatus = 'completed'
					AND	m.MatchCode NOT LIKE '%hedge%'
			OPTION (RECOMPILE);
			
			SELECT	@RowCount	= @@ROWCOUNT
				,	@Duration	= DATEDIFF(millisecond, @Begin, GETDATE())
				;
	
			IF	@Debug = 1
			BEGIN
				-- Force the output to appear immediately
				RAISERROR('From Origin - Insert #tmpFilteredBettransByBatch - Date: "%s" - %d rows - %d ms', 0, 0, @Date, @RowCount, @Duration) WITH NOWAIT;
			END;
			
			-- "DISTINCT" Prevent Page Splits
			DELETE b WITH(ROWLOCK)
			FROM	(	
						SELECT ROW_NUMBER() OVER (PARTITION BY TransId ORDER BY TransId) AS rn
						FROM #tmpFilteredBettransByBatch
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
			FROM #tmpFilteredBettransByBatch AS b
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
				RAISERROR('From Origin - ReCalculate Original Winlost #tmpFilteredBettransByBatch - Date: "%s" - %d rows - %d ms', 0, 0, @Date, @RowCount, @Duration) WITH NOWAIT;
			END;

			INSERT INTO #tmpStagingOSTraderPerformance (TraderId, CustId, CustomerClass, EventDate, SportType, LeagueId, MatchId, MatchCode, BetType, Stake, WinLost, SMAWinLost, Comm, ExtraPT, TPositionTaking, VirtualRate, ActualRate, LiveIndicator, BetChoice, betid)
			SELECT	[TraderId]			= ISNULL(t.TraderId, @IdForUnassignedTrader)
				,	[MemberCustId]		= b.custid
				,	[CustomerClass]		= b.CustomerClass
				,	[EventDate]			= b.winlostdate
				,	[SportType]			= b.SportType
				,	[LeagueId]			= b.LeagueId
				,	[MatchId]			= b.matchid
				,	[MatchCode]			= b.MatchCode
				,	[BetType]			= b.bettype
				,	[Stake]				= ((CASE WHEN b.modds = 0.25 OR b.modds = -0.25 THEN ABS(b.stake) / 2 ELSE ABS(b.stake) END))
				,	[WinLost]			= b.winlost
				,	[SMAWinLost]		= (b.awinlost + b.mwinlost + b.swinlost)
				,	[Comm]				= b.scomm
				,	[ExtraPT]			= CASE WHEN b.Winlostdate < '20200213' THEN ISNULL(es.ExtraPT, 0) ELSE ISNULL(b.epositiontaking, 0) END
				,	[TPositionTaking]	= b.tpositiontaking
				,	[VirtualRate]		= b.virtualrate
				,	[ActualRate]		= b.actualrate
				,	[LiveIndicator]		= b.LiveIndicator
				,	[BetChoice]			= b.BetChoice
				,	[betid]				= b.betid
			FROM	#tmpFilteredBettransByBatch AS b
				LEFT JOIN	#tmpOSTrader AS t WITH (NOLOCK) ON	b.winlostdate = t.EventDate
					AND	b.matchid = t.matchid
					AND	b.bettype = t.BetType
					AND b.betid = (CASE WHEN t.betid <> 0 THEN t.betid ELSE b.betid END) -- Only mapping betid for 80X, 80X0Y
				LEFT JOIN	#ExtraPTSportbook AS es WITH (NOLOCK) ON es.SuperId = b.srecommend
					AND	b.winlostdate BETWEEN es.FromDate AND es.ToDate
			OPTION (MAXDOP 2);

			SELECT	@RowCount	= @@ROWCOUNT
				,	@Duration	= DATEDIFF(millisecond, @Begin, GETDATE())
				;

			IF	@Debug = 1
			BEGIN
				-- Force the output to appear immediately
				RAISERROR('From Origin - Insert #tmpStagingOSTraderPerformance - Date: "%s" - %d rows - %d ms', 0, 0, @Date, @RowCount, @Duration) WITH NOWAIT;
			END;
			
			DELETE tp WITH(ROWLOCK) 
			FROM dbo.OSDataTGRS_CustomerClass AS tp WHERE tp.EventDate = @winlostdate;

			INSERT INTO	dbo.OSDataTGRS_CustomerClass (TraderId, CustomerClass, SportId, LeagueId, MatchId, EventDate, BettypeId, Turnover, WinLoss, Comm, Turnover_AR, WinLoss_AR, Comm_AR, BetCount, IsLive)
			SELECT	[TraderId]		= b.TraderId
				,	[CustomerClass]	= b.CustomerClass
				,	[SportId]		= b.SportType
				,	[LeagueId]		= b.LeagueId
				,	[MatchId]		= b.MatchId
				,	[EventDate]		= b.EventDate
				,	[BettypeId]		= b.BetType
				,	[Turnover]		= SUM(b.Stake * (1 - b.TPositionTaking - b.ExtraPT) * b.VirtualRate)
				,	[WinLoss]		= SUM(((-(b.WinLost + b.SMAWinLost)) + b.WinLost * b.ExtraPT) * b.VirtualRate)
				,	[Comm]			= SUM((b.Comm - (CASE WHEN b.TPositionTaking = 1 THEN 0 ELSE (b.Comm * b.ExtraPT / (1 - b.TPositionTaking)) END)) * (CASE WHEN b.VirtualRate > b.ActualRate THEN b.ActualRate ELSE b.VirtualRate END))
				,	[Turnover_AR]	= SUM(b.Stake * (1 - b.TPositionTaking - b.ExtraPT) * (CASE WHEN b.VirtualRate > b.ActualRate THEN b.VirtualRate ELSE b.ActualRate END))
				,	[WinLoss_AR]	= SUM(((-(b.WinLost + b.SMAWinLost)) + b.WinLost * b.ExtraPT) * b.ActualRate)
				,	[Comm_AR]		= SUM((b.Comm - (CASE WHEN b.TPositionTaking = 1 THEN 0 ELSE (b.Comm * b.ExtraPT/(1 - b.TPositionTaking)) END)) * b.ActualRate)
				,	[BetCount]		= SUM(CASE WHEN tc.custid IS NULL THEN 1 ELSE 0 END)  -- Exclude Cashout Ticket
				,	[IsLive]		= b.LiveIndicator
			FROM	#tmpStagingOSTraderPerformance AS b WITH (NOLOCK)
				LEFT JOIN bodb02.dbo.TradeCust tc WITH (NOLOCK) ON b.CustId = tc.CustId AND tc.VendorID = 14
			WHERE b.eventdate = @WinLostDate
			GROUP BY b.TraderId, b.CustomerClass, b.SportType, b.LeagueId, b.MatchId, b.MatchCode, b.EventDate, b.BetType, b.LiveIndicator;
			
			SELECT	@RowCount	= @@ROWCOUNT
				,	@Duration	= DATEDIFF(millisecond, @Begin, GETDATE())
				;

			IF	@Debug = 1
			BEGIN
				-- Force the output to appear immediately
				RAISERROR('From Origin - Insert OSDataTGRS_CustomerClass - Date: "%s" - %d rows - %d ms', 0, 0, @Date, @RowCount, @Duration) WITH NOWAIT;
			END;
			
			-- Remove batched-data (date) from source
			DELETE
			FROM	#tmpWinlostdate
			WHERE	Winlostdate = @winlostdate;
			
			TRUNCATE TABLE	#tmpStagingOSTraderPerformance;
			TRUNCATE TABLE	#tmpFilteredBettransByBatch;
		END;
	END;
END;

GO
/*<info serverAlias="DBTGRS-bodb_TGRS" executers="bodbTGRSNet" isFunction="0" isNested="0"></info>*/