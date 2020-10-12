ALTER PROCEDURE	[dbo].[Task_StagingOSJuice]
		@Debug					BIT = 0
	,	@BeforeMoveBetsDay		BIT = 1	
	,	@GenerateFromDate		SMALLDATETIME = NULL
	,	@GenerateToDate			SMALLDATETIME = NULL
AS
/*  
	Created:	20170329@Long.Luu
	Task :		Staging Juice for Other Sports on TGRS DB
	DB:			DBTGRS.bodb_TGRS
	Original:
  
	Revisions:
		- 20170712@Billy:	 Change from 200000 rows batch to 100 matchs batch - [Redmine: #79615]
		- 20190108@John:	 Exclude Cashout tickets from Betcount figures in TGR reports [Redmine ID: 107602]
		- 20190121@John:	 Enhance performance for BK [Redmine ID: 107809]
   		- 20190321@John:	 Handling for unassigned trader - [Redmine ID: 109716]
		- 2019528@John:		 Include Draw tickets into all reports and modify Virtual Commission formula [Redmine ID: 114210]
		- 20190704@John.Ngo: Implement change request to the job sum and enhance logic on Extra PT WL calculation [Redmine ID: 116379]
		- 20200420@John.Ngo: Update new table [Dot_Admin_Assignment_Trader] [Redmine ID: 131517]
		- 20200504@John.Ngo: [TGR] Get ExtraPT from epositiontaking column in bettrans table [Redmine ID: 133409]
		- 20200914@John.Ngo: Support AR for OSDataTGRS [Redmine ID: 140875]

	Param's Explanation:
		
	Exam:
	 
*/
BEGIN
	SET NOCOUNT ON;
	
	-- Common variables
	DECLARE	@IdForUnassignedTrader	INT	= 0
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

		-- Force the output to appear immediately
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
					);

	CREATE CLUSTERED INDEX	#CIX_tmpStagingOSTraderIdx ON #tmpStagingOSTrader (
			EventDate			ASC
		,	MatchId				ASC
		,	BetType				ASC
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
					);

	CREATE CLUSTERED INDEX	#CIX_tmpOSTraderIdx ON #tmpOSTrader (
			EventDate			ASC
		,	MatchId				ASC
		,	BetType				ASC
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
					,	MatchId				INT
					,	Winlostdate			SMALLDATETIME
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
					,	Srecommend			INT
					,	Scomm				MONEY
					,	Betteam				VARCHAR(10)
					,	Livehomescore		SMALLINT
					,	Liveawayscore		SMALLINT
					,	Odds				SMALLMONEY
					,	Hdp1				SMALLMONEY
					,	Hdp2				SMALLMONEY
					,	Epositiontaking		SMALLMONEY
					);

	CREATE CLUSTERED INDEX	#CIX_tmpFilteredBettransByBatchIdx ON #tmpFilteredBettransByBatch (
								Winlostdate	ASC
							,	MatchId		ASC
							,	Bettype		ASC
							);

	IF	OBJECT_ID('tempdb..#tmpStagingOSTraderPerformance') IS NOT NULL
	BEGIN
		DROP TABLE	#tmpStagingOSTraderPerformance;
	END;

	CREATE TABLE	#tmpStagingOSTraderPerformance (
						TraderId			INT
					,	EventDate			DATE
					,	MatchId				INT
					,	BetType				SMALLINT
					,	BetTeam				VARCHAR(10)
					,	ScoreHDP			SMALLMONEY
					,	Odds				FLOAT
					,	StakeMY				MONEY
					,	Stake				MONEY
					,	ExtraPT				DECIMAL(9, 8)
					,	TPositionTaking		SMALLMONEY
					,	VirtualRate			FLOAT
					,	ActualRate			FLOAT
					,	Scomm				MONEY
					,	MOdds				SMALLMONEY
					,	StatusID			TINYINT
					);
	
	CREATE CLUSTERED INDEX #CIX_tmpStagingOSTraderPerformanceIdx ON #tmpStagingOSTraderPerformance (
						EventDate			ASC
	); 

	IF	OBJECT_ID('tempdb..#tmpOSDataGroup') IS NOT NULL
	BEGIN
		DROP TABLE #tmpOSDataGroup;
	END;

	CREATE TABLE	#tmpOSDataGroup (
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
					,	AVGOdds_AR			FLOAT
					,	StakeMYBeforeComm_AR MONEY
					,	StakeMY_AR			MONEY
					,	Stake_AR			MONEY
					,	MOdds				SMALLMONEY
					);

	CREATE CLUSTERED INDEX	#CIX_tmpOSDataGroupIdx ON #tmpOSDataGroup (
			EventDate			ASC
		,	MatchId				ASC
		,	BetType				ASC
	);

	IF	OBJECT_ID('tempdb..#tmpOSJuice') IS NOT NULL
	BEGIN
		DROP TABLE #tmpOSJuice;
	END;

	CREATE TABLE	#tmpOSJuice (
						EventDate			DATE
					,	MatchId				INT
					,	BetType				SMALLINT
					,	StakeMYBeforeComm	MONEY
					,	StakeMY				MONEY
					,	Juice				MONEY
					,	StakeMYRJuice		MONEY
					,	StakeMYRTotal		MONEY
					,	ScoreHDP			SMALLMONEY
					,	StakeMYBeforeComm_AR MONEY
					,	StakeMY_AR			MONEY
					,	Juice_AR			MONEY
					,	StakeMYRJuice_AR	MONEY
					,	StakeMYRTotal_AR	MONEY
					);

	CREATE CLUSTERED INDEX	#CIX_tmptmpOSJuiceIdx ON #tmpOSJuice (
								EventDate	ASC
							,	MatchId		ASC
							,	BetType		ASC
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

			-- Force the output to appear immediately
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
		TRUNCATE TABLE #ExtraPTSportbook;

		SELECT @Date = '@FromDateBK = ' + CONVERT(NVARCHAR, @FromDateBK, 120) + ', @ToDateBK = ' + CONVERT(NVARCHAR, @ToDateBK, 120);

		IF @DotExtraPTDate <= @FromDateBK
		BEGIN
			
			INSERT INTO	#tmpStagingOSTrader (TraderId, MatchId, SportType, EventDate, BetType, UpdatedTime, ID)
			SELECT	[TraderId]		= a.TraderID
				,	[MatchId]		= m.MatchId
				,	[SportType]		= m.Sporttype
				,	[EventDate]		= m.EventDate
				,	[BetType]		= a.bettype
				,	[UpdatedTime]	= a.UpdatedTime
				,	[ID]			= a.ID
			FROM	bodb_archive.dbo.Dot_Admin_Assignment_Trader_bk AS a WITH (NOLOCK)
				INNER JOIN	bodb_Archive.dbo.Match_bk AS m WITH (NOLOCK) ON	a.matchid = m.matchid
			WHERE m.EventDate BETWEEN @FromDateBK AND @ToDateBK
				AND	m.Sporttype <> 1
				AND m.EventStatus = 'completed'
				AND	m.MatchCode NOT LIKE '%hedge%'
				AND a.TraderId <> 0;

			INSERT INTO	#tmpOSTrader (TraderId, MatchId, SportType, EventDate, BetType)
			SELECT	DISTINCT
					[TraderId]	= a.TraderID
				,	[MatchId]	= a.MatchId
				,	[SportType]	= a.Sporttype
				,	[EventDate]	= a.EventDate
				,	[BetType]	= a.Bettype
			FROM	#tmpStagingOSTrader AS a WITH (NOLOCK)
			CROSS APPLY (
							SELECT dt.TraderID, dt.MatchId, dt.Bettype,
								ROW_NUMBER() OVER(PARTITION BY dt.MatchId, dt.Bettype ORDER BY dt.UpdatedTime DESC, dt.ID DESC) AS Row_Num
							FROM #tmpStagingOSTrader AS dt WITH (NOLOCK)
							WHERE   a.matchid = dt.matchid
								AND a.bettype = dt.bettype		
								AND a.TraderId <> 0
							) dat
			WHERE a.EventDate BETWEEN @FromDateBK AND @ToDateBK
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
				RAISERROR('From BK - Insert #tmpOSTrader - Date: "%s" - %d rows - %d ms', 0, 0, @Date, @RowCount, @Duration) WITH NOWAIT;
			END;
		END;

		IF @DotExtraPTDate > @FromDateBK AND @DotExtraPTDate <= @ToDateBK
		BEGIN
			SELECT @Date = '@FromDateBK = ' + CONVERT(NVARCHAR, @FromDateBK, 120) + ', (@DotExtraPTDate - 1) = ' + CONVERT(NVARCHAR, (@DotExtraPTDate - 1), 120);

			INSERT INTO	#tmpOSTrader(TraderId, matchid, SportType, EventDate, BetType)
			SELECT	DISTINCT
					[TraderId]	= a.OperatorID
				,	[MatchId]	= m.MatchId
				,	[SportType]	= m.Sporttype
				,	[EventDate]	= m.EventDate
				,	[BetType]	= CASE	WHEN (a.bettype = 1 OR a.bettype = 5) AND a.OperatorType = 1 THEN 1
										WHEN (a.bettype = 1 AND a.OperatorType = 2) THEN 7
										WHEN (a.bettype = 2 AND a.OperatorType = 1) THEN 3
										WHEN (a.bettype = 2 AND a.OperatorType = 2) THEN 8
										WHEN (a.bettype = 3 AND a.OperatorType = 1) THEN 5
										WHEN (a.bettype = 3 AND a.OperatorType = 2) THEN 15
										WHEN (a.bettype = 4 AND a.OperatorType = 1) THEN 2
										WHEN (a.bettype = 4 AND a.OperatorType = 2) THEN 12
										ELSE 0
								  END
			FROM	bodb_Archive.dbo.Dot_Admin_Assignment_Operator_bk AS a WITH (NOLOCK)
			INNER JOIN	bodb_Archive.dbo.Match_bk AS m WITH (NOLOCK) ON	a.matchid = m.matchid
			WHERE	m.eventdate BETWEEN @FromDateBK AND (@DotExtraPTDate - 1)
				AND	m.sporttype <> 1
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

			INSERT INTO	#tmpStagingOSTrader (TraderId, MatchId, SportType, EventDate, BetType, UpdatedTime, ID)
			SELECT	[TraderId]		= a.TraderID
				,	[MatchId]		= m.MatchId
				,	[SportType]		= m.Sporttype
				,	[EventDate]		= m.EventDate
				,	[BetType]		= a.bettype
				,	[UpdatedTime]	= a.UpdatedTime
				,	[ID]			= a.ID
			FROM	bodb_archive.dbo.Dot_Admin_Assignment_Trader_bk AS a WITH (NOLOCK)
				INNER JOIN	bodb_Archive.dbo.Match_bk AS m WITH (NOLOCK) ON	a.matchid = m.matchid
			WHERE m.EventDate BETWEEN @DotExtraPTDate AND @ToDateBK
				AND	m.Sporttype <> 1
				AND m.EventStatus = 'completed'
				AND	m.MatchCode NOT LIKE '%hedge%'
				AND a.TraderId <> 0;

			INSERT INTO	#tmpOSTrader (TraderId, MatchId, SportType, EventDate, BetType)
			SELECT	DISTINCT
					[TraderId]	= a.TraderID
				,	[MatchId]	= a.MatchId
				,	[SportType]	= a.Sporttype
				,	[EventDate]	= a.EventDate
				,	[BetType]	= a.Bettype
			FROM	#tmpStagingOSTrader AS a WITH (NOLOCK)
			CROSS APPLY (
							SELECT dt.TraderID, dt.MatchId, dt.Bettype,
								ROW_NUMBER() OVER(PARTITION BY dt.MatchId, dt.Bettype ORDER BY dt.UpdatedTime DESC, dt.ID DESC) AS Row_Num
							FROM #tmpStagingOSTrader AS dt WITH (NOLOCK)
							WHERE   a.matchid = dt.matchid
								AND a.bettype = dt.bettype		
								AND a.TraderId <> 0
							) dat
			WHERE a.EventDate BETWEEN @DotExtraPTDate AND @ToDateBK
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
				RAISERROR('From BK - Insert #tmpOSTrader - Date: "%s" - %d rows - %d ms', 0, 0, @Date, @RowCount, @Duration) WITH NOWAIT;
			END;

			SELECT @Date = '@FromDateBK = ' + CONVERT(NVARCHAR, @FromDateBK, 120) + ', @ToDateBK = ' + CONVERT(NVARCHAR, @ToDateBK, 120);
		END;

		IF @DotExtraPTDate > @ToDateBK 
		BEGIN
			INSERT INTO	#tmpOSTrader(TraderId, matchid, SportType, EventDate, BetType)
			SELECT	DISTINCT
					[TraderId]	= a.OperatorID
				,	[MatchId]	= m.MatchId
				,	[SportType]	= m.Sporttype
				,	[EventDate]	= m.EventDate
				,	[BetType]	= CASE	WHEN (a.bettype = 1 OR a.bettype = 5) AND a.OperatorType = 1 THEN 1
										WHEN (a.bettype = 1 AND a.OperatorType = 2) THEN 7
										WHEN (a.bettype = 2 AND a.OperatorType = 1) THEN 3
										WHEN (a.bettype = 2 AND a.OperatorType = 2) THEN 8
										WHEN (a.bettype = 3 AND a.OperatorType = 1) THEN 5
										WHEN (a.bettype = 3 AND a.OperatorType = 2) THEN 15
										WHEN (a.bettype = 4 AND a.OperatorType = 1) THEN 2
										WHEN (a.bettype = 4 AND a.OperatorType = 2) THEN 12
										ELSE 0
								  END
			FROM	bodb_Archive.dbo.Dot_Admin_Assignment_Operator_bk AS a WITH (NOLOCK)
			INNER JOIN	bodb_Archive.dbo.Match_bk AS m WITH (NOLOCK) ON	a.matchid = m.matchid
			WHERE	m.eventdate BETWEEN @FromDateBK AND @ToDateBK
				AND	m.sporttype <> 1
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

		WHILE	EXISTS (SELECT 1 FROM #tmpWinlostdate)
		BEGIN
			SELECT	TOP(1)
					@WinLostDate = d.winlostdate
			FROM	#tmpWinlostdate AS d;
			
			SELECT @Date = CONVERT(NVARCHAR, @WinLostDate, 120);

			TRUNCATE TABLE	#tmpFilteredBettransByBatch;
			INSERT INTO	#tmpFilteredBettransByBatch
					(TransId, MatchId, Winlostdate, Bettype, Modds, Stake, Actual_stake, Virtualrate, Actualrate, Winlost, Awinlost, Mwinlost, Swinlost, Tpositiontaking, Srecommend, Scomm, Betteam, Livehomescore, Liveawayscore, Odds, Hdp1, Hdp2, Epositiontaking)
			SELECT	b.transid, b.matchid, b.winlostdate, b.bettype, b.modds, b.stake, b.actual_stake, b.virtualrate, b.actualrate, b.winlost, b.awinlost, b.mwinlost, b.swinlost, b.tpositiontaking, b.srecommend, b.scomm, b.betteam, b.livehomescore, b.liveawayscore, b.odds, b.hdp1, b.Hdp2, ISNULL(b.epositiontaking, 0)
			FROM	bodb_Archive.dbo.bettrans_bk AS b WITH (NOLOCK)
				INNER JOIN bodb_Archive.dbo.match_bk m WITH (NOLOCK) ON b.matchid = m.matchid
				INNER JOIN bodb02.dbo.SportBettypeMatrix sbm ON b.bettype = sbm.BetType and m.sporttype = sbm.SportType
			WHERE	b.winlostdate = @WinLostDate
					AND m.eventdate = @WinLostDate
					AND	b.statusID IN (111,112, 113)
					AND	b.Currency NOT IN (20, 27, 28)
					AND	b.LiveIndicator = 1
					AND	b.bettype IN (1, 3, 7, 8, 2, 12)
					AND sbm.ProductID = 1
					AND sbm.sporttype <> 1
					AND sbm.IsLive = 1
					AND m.EventStatus = 'completed'
					AND	m.MatchCode NOT LIKE '%hedge%';
			
			SELECT	@RowCount	= @@ROWCOUNT
				,	@Duration	= DATEDIFF(millisecond, @Begin, GETDATE())
				;
	
			IF	@Debug = 1
			BEGIN
				-- Force the output to appear immediately
				RAISERROR('From BK - Insert #tmpFilteredBettransByBatch - Date: "%s" - %d rows - %d ms', 0, 0, @Date, @RowCount, @Duration) WITH NOWAIT;
			END;
			
			INSERT INTO #tmpStagingOSTraderPerformance(TraderId, EventDate, MatchId, BetType, BetTeam, ScoreHDP, Odds, StakeMY, Stake, ExtraPT, TPositionTaking, VirtualRate, ActualRate, Scomm, MOdds)
			SELECT	[TraderId]			= ISNULL(t.TraderId, @IdForUnassignedTrader)
				,	[EventDate]			= b.winlostdate
				,	[MatchId]			= b.matchid
				,	[BetType]			= b.bettype
				,	[BetTeam]			= b.betteam
				,	[ScoreHDP]			= (CASE WHEN b.bettype IN (1, 7) THEN (b.hdp1 + b.livehomescore) - (b.hdp2 + b.liveawayscore) ELSE b.hdp1 END)
				,	[Odds]				= b.odds
				,	[StakeMY]			= (CASE WHEN ABS(b.odds) <= 1 THEN 1 ELSE ABS(b.odds) END * (CASE WHEN ABS(b.modds) = 0.25 THEN 0.5 ELSE 1 END) * ABS(b.stake)) -- StakeMY
				,	[Stake]				= ((CASE WHEN ABS(b.modds) = 0.25 THEN 0.5 ELSE 1 END) * ABS(b.stake)) -- Stake
				,	[ExtraPT]			= CASE WHEN b.Winlostdate < '20200213' THEN ISNULL(es.ExtraPT, 0) ELSE ISNULL(b.epositiontaking, 0) END
				,	[TPositionTaking]	= b.tpositiontaking
				,	[VirtualRate]		= b.virtualrate
				,	[ActualRate]		= b.actualrate
				,	[Scomm]				= b.scomm
				,	[MOdds]				= b.modds
			FROM		#tmpFilteredBettransByBatch AS b
			LEFT JOIN	#tmpOSTrader AS t WITH (NOLOCK) ON	b.winlostdate = t.EventDate
					AND	b.matchid = t.matchid
					AND	b.bettype = t.BetType
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
			
			INSERT INTO	#tmpOSDataGroup(TraderId, EventDate, MatchId, BetType, BetTeam, ScoreHDP, MOdds, AVGOdds, StakeMYBeforeComm, StakeMY, Stake, AVGOdds_AR, StakeMYBeforeComm_AR, StakeMY_AR, Stake_AR)
			SELECT	[TraderId]			= t.TraderId
				,	[EventDate]			= t.EventDate
				,	[MatchId]			= t.MatchId
				,	[BetType]			= t.BetType
				,	[BetTeam]			= t.BetTeam
				,	[ScoreHDP]			= t.ScoreHDP
				,	[MOdds]				= t.MOdds
				,	[AVGOdds]			= SUM((CASE WHEN t.Odds < 0 THEN 1 ELSE t.Odds END * t.Stake * (1 - t.TPositionTaking - t.ExtraPT) + (t.Scomm - (CASE WHEN t.TPositionTaking = 1 THEN 0 ELSE (t.Scomm * t.ExtraPT / (1 - t.TPositionTaking)) END))) * t.VirtualRate)
										/ SUM((CASE WHEN t.Odds < 0 THEN -t.Odds ELSE 1 END * t.Stake * (1 - t.TPositionTaking - t.ExtraPT) - (t.Scomm - (CASE WHEN t.TPositionTaking = 1 THEN 0 ELSE (t.Scomm * t.ExtraPT / (1 - t.TPositionTaking)) END))) * t.VirtualRate)
				,	[StakeMYBeforeComm]	= SUM(t.StakeMY * (1 - t.TPositionTaking - t.ExtraPT) * t.VirtualRate)
				,	[StakeMY]			= SUM((t.StakeMY * (1 - t.TPositionTaking - t.ExtraPT) - (t.Scomm - (CASE WHEN t.TPositionTaking = 1 THEN 0 ELSE (t.Scomm * t.ExtraPT / (1 - t.TPositionTaking)) END))) * (CASE WHEN t.VirtualRate > t.ActualRate THEN t.ActualRate ELSE t.VirtualRate END))
				,	[Stake]				= SUM((CASE WHEN t.Odds < 0 THEN -t.Odds ELSE 1 END * t.Stake * (1 - t.TPositionTaking - t.ExtraPT) - (t.Scomm - (CASE WHEN t.TPositionTaking = 1 THEN 0 ELSE (t.Scomm * t.ExtraPT / (1 - t.TPositionTaking)) END))) * (CASE WHEN t.VirtualRate > t.ActualRate THEN t.ActualRate ELSE t.VirtualRate END))
				,	[AVGOdds_AR]		= SUM((CASE WHEN t.Odds < 0 THEN 1 ELSE t.Odds END) * ABS(t.Stake) * (1 - t.TPositionTaking - t.ExtraPT) * (CASE WHEN t.VirtualRate > t.ActualRate THEN t.VirtualRate ELSE t.ActualRate END))
										/ SUM((CASE WHEN t.Odds < 0 THEN -t.Odds ELSE 1 END) * ABS(t.Stake) * (1 - t.TPositionTaking - t.ExtraPT) * (CASE WHEN t.VirtualRate > t.ActualRate THEN t.VirtualRate ELSE t.ActualRate END))
				,	[StakeMYBeforeComm_AR]	= SUM(t.StakeMY * (1 - t.TPositionTaking - t.ExtraPT) * (CASE WHEN t.VirtualRate > t.ActualRate THEN t.VirtualRate ELSE t.ActualRate END))
				,	[StakeMY_AR]		= SUM(t.StakeMY * (1 - t.TPositionTaking - t.ExtraPT) * (CASE WHEN t.VirtualRate > t.ActualRate THEN t.VirtualRate ELSE t.ActualRate END) - (t.Scomm - CASE WHEN t.TPositionTaking = 1 THEN 0 ELSE t.Scomm * t.ExtraPT / (1 - t.TPositionTaking) END) * t.ActualRate)
				,	[Stake_AR]			= SUM(CASE WHEN t.Odds < 0 THEN -t.Odds ELSE 1 END * ABS(t.Stake) * (1 - t.TPositionTaking - t.ExtraPT) * (CASE WHEN t.VirtualRate > t.ActualRate THEN t.VirtualRate ELSE t.ActualRate END) - (t.Scomm - CASE WHEN t.TPositionTaking = 1 THEN 0 ELSE t.Scomm * t.ExtraPT / (1 - t.TPositionTaking) END) * t.ActualRate)
			FROM	#tmpStagingOSTraderPerformance AS t
			GROUP BY t.TraderId, t.EventDate, t.MatchId, t.BetType, t.BetTeam, t.ScoreHDP, t.MOdds;
			
			SELECT	@RowCount	= @@ROWCOUNT
				,	@Duration	= DATEDIFF(millisecond, @Begin, GETDATE())
				;

			IF	@Debug = 1
			BEGIN
				-- Force the output to appear immediately
				RAISERROR('From BK - Insert #tmpOSDataGroup - Date: "%s" - %d rows - %d ms', 0, 0, @Date, @RowCount, @Duration) WITH NOWAIT;
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

		INSERT INTO	#tmpStagingOSTrader (TraderId, MatchId, SportType, EventDate, BetType, UpdatedTime, ID)
		SELECT	[TraderId]		= a.TraderID
			,	[MatchId]		= m.MatchId
			,	[SportType]		= m.Sporttype
			,	[EventDate]		= m.EventDate
			,	[BetType]		= a.bettype
			,	[UpdatedTime]	= a.UpdatedTime
			,	[ID]			= a.ID
		FROM	bodb02.dbo.Dot_Admin_Assignment_Trader AS a WITH (NOLOCK)
		INNER JOIN	bodb02.dbo.Match14 AS m WITH (NOLOCK) ON a.matchid = m.matchid
		WHERE m.EventDate BETWEEN @FromDate14 AND @ToDate14
			AND	m.Sporttype <> 1
			AND m.EventStatus = 'completed'
			AND	m.MatchCode NOT LIKE '%hedge%'
			AND a.TraderId <> 0;

		INSERT INTO	#tmpOSTrader (TraderId, MatchId, SportType, EventDate, BetType)
		SELECT	DISTINCT
				[TraderId]	= a.TraderID
			,	[MatchId]	= a.MatchId
			,	[SportType]	= a.Sporttype
			,	[EventDate]	= a.EventDate
			,	[BetType]	= a.Bettype
		FROM	#tmpStagingOSTrader AS a WITH (NOLOCK)
		CROSS APPLY (
						SELECT dt.TraderID, dt.MatchId, dt.Bettype,
							ROW_NUMBER() OVER(PARTITION BY dt.MatchId, dt.Bettype ORDER BY dt.UpdatedTime DESC, dt.ID DESC) AS Row_Num
						FROM #tmpStagingOSTrader AS dt WITH (NOLOCK)
						WHERE   a.matchid = dt.matchid
							AND a.bettype = dt.bettype		
							AND a.TraderId <> 0
						) dat
		WHERE a.EventDate BETWEEN @FromDate14 AND @ToDate14
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

		WHILE	EXISTS (SELECT 1 FROM #tmpWinlostdate)
		BEGIN
			SELECT	TOP(1)
					@WinLostDate = d.winlostdate
			FROM	#tmpWinlostdate AS d;

			SELECT @Date = CONVERT(NVARCHAR, @WinLostDate, 120);

			TRUNCATE TABLE	#tmpFilteredBettransByBatch;
			INSERT INTO	#tmpFilteredBettransByBatch
					(TransId, MatchId, Winlostdate, Bettype, Modds, Stake, Actual_stake, Virtualrate, Actualrate, Winlost, Awinlost, Mwinlost, Swinlost, Tpositiontaking, Srecommend, Scomm, Betteam, Livehomescore, Liveawayscore, Odds, Hdp1, Hdp2, Epositiontaking)
			SELECT	b.transid, b.matchid, b.winlostdate, b.bettype, b.modds, b.stake, b.actual_stake, b.virtualrate, b.actualrate, b.winlost, b.awinlost, b.mwinlost, b.swinlost, b.tpositiontaking, b.srecommend, b.scomm, b.betteam, b.livehomescore, b.liveawayscore, b.odds, b.hdp1, b.Hdp2, ISNULL(b.epositiontaking, 0)
			FROM	bodb02.dbo.bettrans14 AS b WITH (NOLOCK)
				INNER JOIN bodb02.dbo.match14 m WITH (NOLOCK) ON b.matchid = m.matchid
				INNER JOIN bodb02.dbo.SportBettypeMatrix sbm ON b.bettype = sbm.BetType and m.sporttype = sbm.SportType
			WHERE	b.Winlostdate = @WinLostDate
					AND m.eventdate = @WinLostDate
					AND	b.StatusID IN (111, 112, 113)
					AND	b.Currency NOT IN (20, 27, 28)
					AND	b.LiveIndicator = 1
					AND	b.Bettype IN (1, 3, 7, 8, 2, 12)
					AND sbm.ProductID = 1
					AND sbm.Sporttype <> 1
					AND sbm.IsLive = 1
					AND m.EventStatus = 'completed'
					AND	m.MatchCode NOT LIKE '%hedge%';
			
			SELECT	@RowCount	= @@ROWCOUNT
				,	@Duration	= DATEDIFF(millisecond, @Begin, GETDATE())
				;
	
			IF	@Debug = 1
			BEGIN
				-- Force the output to appear immediately
				RAISERROR('From 14 - Insert #tmpFilteredBettransByBatch - Date: "%s" - %d rows - %d ms', 0, 0, @Date, @RowCount, @Duration) WITH NOWAIT;
			END;
			
			INSERT INTO #tmpStagingOSTraderPerformance(TraderId, EventDate, MatchId, BetType, BetTeam, ScoreHDP, Odds, StakeMY, Stake, ExtraPT, TPositionTaking, VirtualRate, ActualRate, Scomm, MOdds)
			SELECT	[TraderId]			= ISNULL(t.TraderId, @IdForUnassignedTrader)
				,	[EventDate]			= b.winlostdate
				,	[MatchId]			= b.matchid
				,	[BetType]			= b.bettype
				,	[BetTeam]			= b.betteam
				,	[ScoreHDP]			= (CASE WHEN b.bettype IN (1, 7) THEN (b.hdp1 + b.livehomescore) - (b.hdp2 + b.liveawayscore) ELSE b.hdp1 END)
				,	[Odds]				= b.odds
				,	[StakeMY]			= (CASE WHEN ABS(b.odds) <= 1 THEN 1 ELSE ABS(b.odds) END * (CASE WHEN ABS(b.modds) = 0.25 THEN 0.5 ELSE 1 END) * ABS(b.stake)) -- StakeMY
				,	[Stake]				= ((CASE WHEN ABS(b.modds) = 0.25 THEN 0.5 ELSE 1 END) * ABS(b.stake)) -- Stake
				,	[ExtraPT]			= ISNULL(b.epositiontaking, 0)
				,	[TPositionTaking]	= b.tpositiontaking
				,	[VirtualRate]		= b.virtualrate
				,   [ActualRate]		= b.actualrate
				,	[Scomm]				= b.scomm
				,	[MOdds]				= b.modds
			FROM		#tmpFilteredBettransByBatch AS b
			LEFT JOIN	#tmpOSTrader AS t WITH (NOLOCK) ON	b.winlostdate = t.EventDate
					AND	b.matchid = t.matchid
					AND	b.bettype = t.BetType
			OPTION (MAXDOP 2);

			SELECT	@RowCount	= @@ROWCOUNT
				,	@Duration	= DATEDIFF(millisecond, @Begin, GETDATE())
				;
			
			IF	@Debug = 1
			BEGIN
				-- Force the output to appear immediately
				RAISERROR('From 14 - Insert #tmpStagingOSTraderPerformance - Date: "%s" - %d rows - %d ms', 0, 0, @Date, @RowCount, @Duration) WITH NOWAIT;
			END;
			
			INSERT INTO	#tmpOSDataGroup(TraderId, EventDate, MatchId, BetType, BetTeam, ScoreHDP, MOdds, AVGOdds, StakeMYBeforeComm, StakeMY, Stake, AVGOdds_AR, StakeMYBeforeComm_AR, StakeMY_AR, Stake_AR)
			SELECT	[TraderId]			= t.TraderId
				,	[EventDate]			= t.EventDate
				,	[MatchId]			= t.MatchId
				,	[BetType]			= t.BetType
				,	[BetTeam]			= t.BetTeam
				,	[ScoreHDP]			= t.ScoreHDP
				,	[MOdds]				= t.MOdds
				,	[AVGOdds]			= SUM((CASE WHEN t.Odds < 0 THEN 1 ELSE t.Odds END * t.Stake * (1 - t.TPositionTaking - t.ExtraPT) + (t.Scomm - (CASE WHEN t.TPositionTaking = 1 THEN 0 ELSE (t.Scomm * t.ExtraPT / (1 - t.TPositionTaking)) END))) * t.VirtualRate)
										/ SUM((CASE WHEN t.Odds < 0 THEN -t.Odds ELSE 1 END * t.Stake * (1 - t.TPositionTaking - t.ExtraPT) - (t.Scomm - (CASE WHEN t.TPositionTaking = 1 THEN 0 ELSE (t.Scomm * t.ExtraPT / (1 - t.TPositionTaking)) END))) * t.VirtualRate)
				,	[StakeMYBeforeComm]	= SUM(t.StakeMY * (1 - t.TPositionTaking - t.ExtraPT) * t.VirtualRate)
				,	[StakeMY]			= SUM((t.StakeMY * (1 - t.TPositionTaking - t.ExtraPT) - (t.Scomm - (CASE WHEN t.TPositionTaking = 1 THEN 0 ELSE (t.Scomm * t.ExtraPT / (1 - t.TPositionTaking)) END))) * (CASE WHEN t.VirtualRate > t.ActualRate THEN t.ActualRate ELSE t.VirtualRate END))
				,	[Stake]				= SUM((CASE WHEN t.Odds < 0 THEN -t.Odds ELSE 1 END * t.Stake * (1 - t.TPositionTaking - t.ExtraPT) - (t.Scomm - (CASE WHEN t.TPositionTaking = 1 THEN 0 ELSE (t.Scomm * t.ExtraPT / (1 - t.TPositionTaking)) END))) * (CASE WHEN t.VirtualRate > t.ActualRate THEN t.ActualRate ELSE t.VirtualRate END))
				,	[AVGOdds_AR]		= SUM((CASE WHEN t.Odds < 0 THEN 1 ELSE t.Odds END) * ABS(t.Stake) * (1 - t.TPositionTaking - t.ExtraPT) * (CASE WHEN t.VirtualRate > t.ActualRate THEN t.VirtualRate ELSE t.ActualRate END))
										/ SUM((CASE WHEN t.Odds < 0 THEN -t.Odds ELSE 1 END) * ABS(t.Stake) * (1 - t.TPositionTaking - t.ExtraPT) * (CASE WHEN t.VirtualRate > t.ActualRate THEN t.VirtualRate ELSE t.ActualRate END))
				,	[StakeMYBeforeComm_AR]	= SUM(t.StakeMY * (1 - t.TPositionTaking - t.ExtraPT) * (CASE WHEN t.VirtualRate > t.ActualRate THEN t.VirtualRate ELSE t.ActualRate END))
				,	[StakeMY_AR]		= SUM(t.StakeMY * (1 - t.TPositionTaking - t.ExtraPT) * (CASE WHEN t.VirtualRate > t.ActualRate THEN t.VirtualRate ELSE t.ActualRate END) - (t.Scomm - CASE WHEN t.TPositionTaking = 1 THEN 0 ELSE t.Scomm * t.ExtraPT / (1 - t.TPositionTaking) END) * t.ActualRate)
				,	[Stake_AR]			= SUM(CASE WHEN t.Odds < 0 THEN -t.Odds ELSE 1 END * ABS(t.Stake) * (1 - t.TPositionTaking - t.ExtraPT) * (CASE WHEN t.VirtualRate > t.ActualRate THEN t.VirtualRate ELSE t.ActualRate END) - (t.Scomm - CASE WHEN t.TPositionTaking = 1 THEN 0 ELSE t.Scomm * t.ExtraPT / (1 - t.TPositionTaking) END) * t.ActualRate)
			FROM	#tmpStagingOSTraderPerformance AS t
			GROUP BY t.TraderId, t.EventDate, t.MatchId, t.BetType, t.BetTeam, t.ScoreHDP, t.MOdds;
			
			SELECT	@RowCount	= @@ROWCOUNT
				,	@Duration	= DATEDIFF(millisecond, @Begin, GETDATE())
				;

			IF	@Debug = 1
			BEGIN
				-- Force the output to appear immediately
				RAISERROR('From 14 - Insert #tmpOSDataGroup - Date: "%s" - %d rows - %d ms', 0, 0, @Date, @RowCount, @Duration) WITH NOWAIT;
			END;

			-- Remove batched-data (date) from source
			DELETE
			FROM	#tmpWinlostdate
			WHERE	winlostdate = @winlostdate;
			
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

		INSERT INTO	#tmpStagingOSTrader (TraderId, MatchId, SportType, EventDate, BetType, UpdatedTime, ID)
		SELECT	[TraderId]		= a.TraderID
			,	[MatchId]		= m.MatchId
			,	[SportType]		= m.Sporttype
			,	[EventDate]		= m.EventDate
			,	[BetType]		= a.bettype
			,	[UpdatedTime]	= a.UpdatedTime
			,	[ID]			= a.ID
		FROM	bodb02.dbo.Dot_Admin_Assignment_Trader AS a WITH (NOLOCK)
		INNER JOIN	bodb02.dbo.match AS m WITH (NOLOCK) ON	a.matchid = m.matchid
		WHERE m.EventDate BETWEEN @FromDateOrigin AND @ToDateOrigin
			AND	m.Sporttype <> 1
			AND m.EventStatus = 'completed'
			AND	m.MatchCode NOT LIKE '%hedge%'
			AND a.TraderId <> 0;

		INSERT INTO	#tmpOSTrader (TraderId, MatchId, SportType, EventDate, BetType)
		SELECT	DISTINCT
				[TraderId]	= a.TraderID
			,	[MatchId]	= a.MatchId
			,	[SportType]	= a.Sporttype
			,	[EventDate]	= a.EventDate
			,	[BetType]	= a.Bettype
		FROM	#tmpStagingOSTrader AS a WITH (NOLOCK)
		CROSS APPLY (
						SELECT dt.TraderID, dt.MatchId, dt.Bettype,
							ROW_NUMBER() OVER(PARTITION BY dt.MatchId, dt.Bettype ORDER BY dt.UpdatedTime DESC, dt.ID DESC) AS Row_Num
						FROM #tmpStagingOSTrader AS dt WITH (NOLOCK)
						WHERE   a.matchid = dt.matchid
							AND a.bettype = dt.bettype		
							AND a.TraderId <> 0
						) dat
		WHERE a.EventDate BETWEEN @FromDateOrigin AND @ToDateOrigin
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

		WHILE	EXISTS (SELECT 1 FROM #tmpWinlostdate)
		BEGIN
			SELECT	TOP(1)
					@WinLostDate = d.winlostdate
			FROM	#tmpWinlostdate AS d;
			
			SELECT @Date = CONVERT(NVARCHAR, @WinLostDate, 120);

			TRUNCATE TABLE	#tmpFilteredBettransByBatch;
			INSERT INTO	#tmpFilteredBettransByBatch
					(TransId, MatchId, Winlostdate, Bettype, Modds, Stake, Actual_stake, Virtualrate, Actualrate, Winlost, Awinlost, Mwinlost, Swinlost, Tpositiontaking, Srecommend, Scomm, Betteam, Livehomescore, Liveawayscore, Odds, Hdp1, Hdp2, Epositiontaking)
			SELECT	b.transid, b.matchid, b.winlostdate, b.bettype, b.modds, b.stake, b.actual_stake, b.virtualrate, b.actualrate, b.winlost, b.awinlost, b.mwinlost, b.swinlost, b.tpositiontaking, b.srecommend, b.scomm, b.betteam, b.livehomescore, b.liveawayscore, b.odds, b.hdp1, b.Hdp2, ISNULL(b.epositiontaking, 0)
			FROM	bodb02.dbo.bettrans AS b WITH (NOLOCK)
				INNER JOIN bodb02.dbo.match m WITH (NOLOCK) ON b.matchid = m.matchid
				INNER JOIN bodb02.dbo.SportBettypeMatrix sbm ON b.bettype = sbm.BetType and m.sporttype = sbm.SportType
			WHERE	b.winlostdate = @WinLostDate
					AND m.eventdate = @WinLostDate
					AND	b.StatusID IN (111, 112, 113)
					AND	b.Currency NOT IN (20, 27, 28)
					AND	b.LiveIndicator = 1
					AND	b.Bettype IN (1, 3, 7, 8, 2, 12)
					AND sbm.ProductID = 1
					AND sbm.Sporttype <> 1
					AND sbm.IsLive = 1
					AND m.EventStatus = 'completed'
					AND	m.MatchCode NOT LIKE '%hedge%';
			
			SELECT	@RowCount	= @@ROWCOUNT
				,	@Duration	= DATEDIFF(millisecond, @Begin, GETDATE())
				;
	
			IF	@Debug = 1
			BEGIN
				-- Force the output to appear immediately
				RAISERROR('From Origin - Insert #tmpFilteredBettransByBatch - Date: "%s" - %d rows - %d ms', 0, 0, @Date, @RowCount, @Duration) WITH NOWAIT;
			END;
			
			INSERT INTO #tmpStagingOSTraderPerformance(TraderId, EventDate, MatchId, BetType, BetTeam, ScoreHDP, Odds, StakeMY, Stake, ExtraPT, TPositionTaking, VirtualRate, ActualRate, Scomm, MOdds)
			SELECT	[TraderId]			= ISNULL(t.TraderId, @IdForUnassignedTrader)
				,	[EventDate]			= b.winlostdate
				,	[MatchId]			= b.matchid
				,	[BetType]			= b.bettype
				,	[BetTeam]			= b.betteam
				,	[ScoreHDP]			= (CASE WHEN b.bettype IN (1, 7) THEN (b.hdp1 + b.livehomescore) - (b.hdp2 + b.liveawayscore) ELSE b.hdp1 END)
				,	[Odds]				= b.odds
				,	[StakeMY]			= (CASE WHEN ABS(b.odds) <= 1 THEN 1 ELSE ABS(b.odds) END * (CASE WHEN ABS(b.modds) = 0.25 THEN 0.5 ELSE 1 END) * ABS(b.stake)) -- StakeMY
				,	[Stake]				= ((CASE WHEN ABS(b.modds) = 0.25 THEN 0.5 ELSE 1 END) * ABS(b.stake)) -- Stake
				,	[ExtraPT]			= ISNULL(b.epositiontaking, 0)
				,	[TPositionTaking]	= b.tpositiontaking
				,	[VirtualRate]		= b.virtualrate
				,	[ActualRate]		= b.actualrate
				,	[Scomm]				= b.scomm
				,	[MOdds]				= b.modds
			FROM		#tmpFilteredBettransByBatch AS b
			LEFT JOIN	#tmpOSTrader AS t WITH (NOLOCK) ON	b.winlostdate = t.EventDate
					AND	b.matchid = t.matchid
					AND	b.bettype = t.BetType
			OPTION (MAXDOP 2);

			SELECT	@RowCount	= @@ROWCOUNT
				,	@Duration	= DATEDIFF(millisecond, @Begin, GETDATE())
				;

			IF	@Debug = 1
			BEGIN
				-- Force the output to appear immediately
				RAISERROR('From Origin - Insert #tmpStagingOSTraderPerformance - Date: "%s" - %d rows - %d ms', 0, 0, @Date, @RowCount, @Duration) WITH NOWAIT;
			END;
			
			INSERT INTO #tmpOSDataGroup(TraderId, EventDate, MatchId, BetType, BetTeam, ScoreHDP, MOdds, AVGOdds, StakeMYBeforeComm, StakeMY, Stake, AVGOdds_AR, StakeMYBeforeComm_AR, StakeMY_AR, Stake_AR)
			SELECT	[TraderId]			= t.TraderId
				,	[EventDate]			= t.EventDate
				,	[MatchId]			= t.MatchId
				,	[BetType]			= t.BetType
				,	[BetTeam]			= t.BetTeam
				,	[ScoreHDP]			= t.ScoreHDP
				,	[MOdds]				= t.MOdds
				,	[AVGOdds]			= SUM((CASE WHEN t.Odds < 0 THEN 1 ELSE t.Odds END * t.Stake * (1 - t.TPositionTaking - t.ExtraPT) + (t.Scomm - (CASE WHEN t.TPositionTaking = 1 THEN 0 ELSE (t.Scomm * t.ExtraPT / (1 - t.TPositionTaking)) END))) * t.VirtualRate)
										/ SUM((CASE WHEN t.Odds < 0 THEN -t.Odds ELSE 1 END * t.Stake * (1 - t.TPositionTaking - t.ExtraPT) - (t.Scomm - (CASE WHEN t.TPositionTaking = 1 THEN 0 ELSE (t.Scomm * t.ExtraPT / (1 - t.TPositionTaking)) END))) * t.VirtualRate)
				,	[StakeMYBeforeComm]	= SUM(t.StakeMY * (1 - t.TPositionTaking - t.ExtraPT) * t.VirtualRate)
				,	[StakeMY]			= SUM((t.StakeMY * (1 - t.TPositionTaking - t.ExtraPT) - (t.Scomm - (CASE WHEN t.TPositionTaking = 1 THEN 0 ELSE (t.Scomm * t.ExtraPT / (1 - t.TPositionTaking)) END))) * (CASE WHEN t.VirtualRate > t.ActualRate THEN t.ActualRate ELSE t.VirtualRate END))
				,	[Stake]				= SUM((CASE WHEN t.Odds < 0 THEN -t.Odds ELSE 1 END * t.Stake * (1 - t.TPositionTaking - t.ExtraPT) - (t.Scomm - (CASE WHEN t.TPositionTaking = 1 THEN 0 ELSE (t.Scomm * t.ExtraPT / (1 - t.TPositionTaking)) END))) * (CASE WHEN t.VirtualRate > t.ActualRate THEN t.ActualRate ELSE t.VirtualRate END))
				,	[AVGOdds_AR]		= SUM((CASE WHEN t.Odds < 0 THEN 1 ELSE t.Odds END) * ABS(t.Stake) * (1 - t.TPositionTaking - t.ExtraPT) * (CASE WHEN t.VirtualRate > t.ActualRate THEN t.VirtualRate ELSE t.ActualRate END))
										/ SUM((CASE WHEN t.Odds < 0 THEN -t.Odds ELSE 1 END) * ABS(t.Stake) * (1 - t.TPositionTaking - t.ExtraPT) * (CASE WHEN t.VirtualRate > t.ActualRate THEN t.VirtualRate ELSE t.ActualRate END))
				,	[StakeMYBeforeComm_AR]	= SUM(t.StakeMY * (1 - t.TPositionTaking - t.ExtraPT) * (CASE WHEN t.VirtualRate > t.ActualRate THEN t.VirtualRate ELSE t.ActualRate END))
				,	[StakeMY_AR]		= SUM(t.StakeMY * (1 - t.TPositionTaking - t.ExtraPT) * (CASE WHEN t.VirtualRate > t.ActualRate THEN t.VirtualRate ELSE t.ActualRate END) - (t.Scomm - CASE WHEN t.TPositionTaking = 1 THEN 0 ELSE t.Scomm * t.ExtraPT / (1 - t.TPositionTaking) END) * t.ActualRate)
				,	[Stake_AR]			= SUM(CASE WHEN t.Odds < 0 THEN -t.Odds ELSE 1 END * ABS(t.Stake) * (1 - t.TPositionTaking - t.ExtraPT) * (CASE WHEN t.VirtualRate > t.ActualRate THEN t.VirtualRate ELSE t.ActualRate END) - (t.Scomm - CASE WHEN t.TPositionTaking = 1 THEN 0 ELSE t.Scomm * t.ExtraPT / (1 - t.TPositionTaking) END) * t.ActualRate)
			FROM	#tmpStagingOSTraderPerformance AS t
			GROUP BY t.TraderId, t.EventDate, t.MatchId, t.BetType, t.BetTeam, t.ScoreHDP, t.MOdds;
			
			SELECT	@RowCount	= @@ROWCOUNT
				,	@Duration	= DATEDIFF(millisecond, @Begin, GETDATE())
				;
			
			IF	@Debug = 1
			BEGIN
				-- Force the output to appear immediately
				RAISERROR('From Origin - Insert #tmpOSDataGroup - Date: "%s" - %d rows - %d ms', 0, 0, @Date, @RowCount, @Duration) WITH NOWAIT;
			END;

			-- Remove batched-data (date) from source
			DELETE
			FROM	#tmpWinlostdate
			WHERE	winlostdate = @winlostdate;
			
			TRUNCATE TABLE	#tmpStagingOSTraderPerformance;
			TRUNCATE TABLE	#tmpFilteredBettransByBatch;
		END;
	END;

	IF	OBJECT_ID('tempdb..#tmpSumTotal') IS NOT NULL
		DROP TABLE	#tmpSumTotal;

	CREATE TABLE	#tmpSumTotal (
						EventDate			DATE
					,	MatchId				INT
					,	BetType				SMALLINT
					,	StakeMYBeforeComm	MONEY
					,	Juice				MONEY
					,	StakeMYRJuice		MONEY
					,	StakeMYBeforeComm_AR MONEY
					,	Juice_AR			MONEY
					,	StakeMYRJuice_AR	MONEY
					);

	IF	OBJECT_ID('tempdb..#tmpResults') IS NOT NULL
		DROP TABLE	#tmpResults;

	CREATE TABLE	#tmpResults (
						EventDate			DATE
					,	MatchId				INT
					,	BetType				SMALLINT
					,	StakeMYBeforeComm	MONEY
					,	Juice				MONEY
					,	StakeMYRJuice		MONEY
					,	StakeMYBeforeComm_AR MONEY
					,	Juice_AR			MONEY
					,	StakeMYRJuice_AR	MONEY
					);

	INSERT INTO	#tmpOSJuice(EventDate, MatchId, BetType, ScoreHDP, StakeMYBeforeComm, StakeMY, Juice, StakeMYRJuice, StakeMYRTotal, StakeMYBeforeComm_AR, StakeMY_AR, Juice_AR, StakeMYRJuice_AR, StakeMYRTotal_AR)
	SELECT	[EventDate]			= temp1.EventDate
		,	[MatchId]			= temp1.MatchId
		,	[BetType]			= temp1.BetType
		,	[ScoreHDP]			= temp1.ScoreHDP
		,	[StakeMYBeforeComm]	= SUM(temp1.StakeMYBeforeComm)
		,	[StakeMY]			= SUM(temp1.StakeMY)
		,	[Juice]				= SUM(ISNULL(CASE	WHEN temp1.BetTeam IN ('h')
														THEN	CASE WHEN temp2.Stake * (1 + ABS(temp2.AVGOdds)) / (1 + ABS(temp1.AVGOdds)) > temp1.Stake THEN temp1.Stake ELSE temp2.Stake * (1 + ABS(temp2.AVGOdds)) / (1 + ABS(temp1.AVGOdds)) END * CASE WHEN temp1.AVGOdds > 0 THEN 1 ELSE -temp1.AVGOdds END
															-	CASE WHEN temp1.Stake * (1 + ABS(temp1.AVGOdds)) / (1 + ABS(temp2.AVGOdds)) > temp2.Stake THEN temp2.Stake ELSE temp1.Stake * (1 + ABS(temp1.AVGOdds)) / (1 + ABS(temp2.AVGOdds)) END * CASE WHEN temp2.AVGOdds > 0 THEN temp2.AVGOdds ELSE 1 END
													ELSE 0
											 END, 0))
		,	[StakeMYRJuice]		= SUM(ISNULL(CASE	WHEN temp1.BetTeam IN ('h') 
														THEN	CASE WHEN temp2.Stake * (1 + ABS(temp2.AVGOdds)) / (1 + ABS(temp1.AVGOdds)) > temp1.Stake THEN temp1.Stake ELSE temp2.Stake * (1 + ABS(temp2.AVGOdds)) / (1 + ABS(temp1.AVGOdds)) END * CASE WHEN ABS(temp1.AVGOdds) > 1 THEN ABS(temp1.AVGOdds) ELSE 1 END
															+	CASE WHEN temp1.Stake * (1 + ABS(temp1.AVGOdds)) / (1 + ABS(temp2.AVGOdds)) > temp2.Stake THEN temp2.Stake ELSE temp1.Stake * (1 + ABS(temp1.AVGOdds)) / (1 + ABS(temp2.AVGOdds)) END * CASE WHEN ABS(temp2.AVGOdds) > 1 THEN ABS(temp2.AVGOdds) ELSE 1 END

													ELSE 0
											 END, 0))
		,	[StakeMYRTotal]		= SUM(ISNULL((CASE	WHEN temp1.BetTeam IN ('h')
														THEN	temp1.Stake * CASE WHEN ABS(temp1.AVGOdds) > 1 THEN ABS(temp1.AVGOdds) ELSE 1 END
															+	temp2.Stake * CASE WHEN ABS(temp2.AVGOdds) > 1 THEN ABS(temp2.AVGOdds) ELSE 1 END
														ELSE 0
											 END), 0))
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
	FROM		#tmpOSDataGroup AS temp1 WITH (NOLOCK)
	LEFT JOIN	#tmpOSDataGroup AS temp2
			ON	temp1.MatchId = temp2.MatchId
			AND	temp1.BetType = temp2.BetType
			AND	temp1.ScoreHDP = temp2.ScoreHDP
			AND	temp1.BetTeam <> temp2.BetTeam
	GROUP BY temp1.MatchId, temp1.BetType, temp1.EventDate, temp1.ScoreHDP;

	INSERT INTO	#tmpSumTotal(EventDate, MatchId, BetType, StakeMYBeforeComm, Juice, StakeMYRJuice, StakeMYBeforeComm_AR, Juice_AR, StakeMYRJuice_AR)
	SELECT	[EventDate]			= t.EventDate
		,	[MatchId]			= t.MatchId
		,	[BetType]			= t.BetType
		,	[StakeMYBeforeComm]	= SUM(t.StakeMYBeforeComm)
		,	[Juice]				= SUM(t.Juice)
		,	[StakeMYRJuice]		= SUM(CASE WHEN t.StakeMYRTotal = 0 THEN 0 ELSE t.StakeMYBeforeComm * t.StakeMYRJuice / t.StakeMYRTotal END) -- Before comm
		,	[StakeMYBeforeComm_AR]	= SUM(t.StakeMYBeforeComm_AR)
		,	[Juice_AR]			= SUM(t.Juice_AR)
		,	[StakeMYRJuice_AR]	= SUM(CASE WHEN t.StakeMYRTotal_AR = 0 THEN 0 ELSE CAST(t.StakeMYBeforeComm_AR AS DECIMAL(38,18)) * t.StakeMYRJuice_AR / t.StakeMYRTotal_AR END) -- Before comm
	FROM	#tmpOSJuice AS t
	GROUP BY t.MatchId, t.BetType, t.EventDate, t.ScoreHDP;

	INSERT INTO	#tmpResults(EventDate, MatchId, BetType, StakeMYBeforeComm, Juice, StakeMYRJuice, StakeMYBeforeComm_AR, Juice_AR, StakeMYRJuice_AR)
	SELECT	[EventDate]			= t.EventDate
		,	[MatchId]			= t.MatchId
		,	[BetType]			= t.BetType
		,	[StakeMYBeforeComm]	= SUM(t.StakeMYBeforeComm)
		,	[Juice]				= SUM(t.Juice)
		,	[StakeMYRJuice]		= SUM(t.StakeMYRJuice)
		,	[StakeMYBeforeComm_AR]	= SUM(t.StakeMYBeforeComm_AR)
		,	[Juice_AR]			= SUM(t.Juice_AR)
		,	[StakeMYRJuice_AR]	= SUM(t.StakeMYRJuice_AR)
	FROM	#tmpSumTotal AS t
	GROUP BY t.MatchId, t.BetType, t.EventDate;

	UPDATE	tp
	SET		tp.Juice			= t.Juice
		,	tp.StakeMYR			= t.StakeMYBeforeComm
		,	tp.StakeMYRJuice	= t.StakeMYRJuice
		,	tp.Juice_AR			= t.Juice_AR
		,	tp.StakeMYR_AR		= t.StakeMYBeforeComm_AR
		,	tp.StakeMYRJuice_AR = t.StakeMYRJuice_AR
	FROM	dbo.OSDataTGRS AS tp WITH (ROWLOCK, UPDLOCK)
	INNER JOIN	#tmpResults AS t WITH (NOLOCK)
			ON	t.MatchId = tp.MatchId
			AND	t.BetType = tp.BettypeId
	WHERE	tp.EventDate = t.EventDate
		AND tp.IsLive = 1; -- Temporarily update Juice for live tickets only

	SELECT	@RowCount	= @@ROWCOUNT
		,	@Duration	= DATEDIFF(millisecond, @Begin, GETDATE())
	;

	IF	@Debug = 1
	BEGIN
		-- Force the output to appear immediately
		RAISERROR('Update Juice for OSDataTGRS - %d rows - %d ms', 0, 0, @RowCount, @Duration) WITH NOWAIT;
	END;
	
END;
	
GO
/*<info serverAlias="DBTGRS-bodb_TGRS" executers="bodbTGRSNet" isFunction="0" isNested="0"></info>*/