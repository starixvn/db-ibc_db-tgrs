ALTER PROCEDURE	[dbo].[Task_StagingOSDataTGRS]
		@Debug					BIT = 0
	,	@BeforeMoveBetsDay		BIT = 1	
	,	@GenerateFromDate		SMALLDATETIME = NULL
	,	@GenerateToDate			SMALLDATETIME = NULL
AS
/*  
	Created:	20160810@Long.Luu
	Task :		Staging Data for Other Sports on TGRS DB
	DB:			DBTGRS.bodb_TGRS
	Original:
  
	Revisions:  
		- 20170227@Aaron:	 Added MatchCount
		- 20170306@John:	 Change table OSDataTGRS
		- 20170330@Long:	 Apply ExtraPT
   		- 20170711@Billy:	 Remove delete OSStagingDataTGRS part to update Juice for next step - [Redmine: #79615]
		- 20180928@Long:	 Support more bettypes - [Redmine: #83185]
		- 20190108@John:	 Exclude Cashout tickets from Betcount figures in TGR reports [Redmine ID: 107602]
		- 20190121@John:	 Enhance performance for BK [Redmine ID: 107809]
		- 20190218@Harvey:	 Get more OS bettypes - [Redmine ID: 109005]
		- 20190305@Harvey:	 Handling for unassigned trader - [Redmine ID: 109716]
		- 20190321@John:	 Update log and performance  [Redmine ID: 109716]
		- 2019528@John:		 Include Draw tickets into all reports and modify Virtual Commission formula [Redmine ID: 114210]
		- 20190704@John.Ngo: Implement change request to the job sum and enhance logic on Extra PT WL calculation [Redmine ID: 116379]
		- 20200417@John.Ngo: Update new table [Dot_Admin_Assignment_Trader] [Redmine ID: 131517]
		- 20200504@John.Ngo: [TGR] Get ExtraPT from epositiontaking column in bettrans table [Redmine ID: 133409]

	Param's Explanation:
		
	Exam: EXECUTE [Task_StagingOSDataTGRS] @Debug = 1, @GenerateFromDate = '20190214', @GenerateToDate = '20190304'
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
	WHERE	m.sporttype <> 1
		AND m.ProductID = 1
		AND	m.bettype IS NOT NULL
	UNION
	SELECT	DISTINCT b.BettypeId
	FROM	dbo.OSBettype AS b WITH (NOLOCK)
	WHERE	b.BettypeId < 0;

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
					,	CustId				INT
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
					,	Epositiontaking		SMALLMONEY
					);

	CREATE CLUSTERED INDEX	#CIX_tmpFilteredBettrans14ByBatchIdx ON #tmpFilteredBettransByBatch (
						Winlostdate			ASC
					,	MatchId				ASC
					,	Bettype				ASC
					);
	
	CREATE NONCLUSTERED INDEX	#NCIX_tmpFilteredBettrans14ByBatchIdx ON #tmpFilteredBettransByBatch (
					    CustId				ASC
					);

	IF	OBJECT_ID('tempdb..#tmpStagingOSTraderPerformance') IS NOT NULL
	BEGIN
		DROP TABLE	#tmpStagingOSTraderPerformance;
	END;

	CREATE TABLE	#tmpStagingOSTraderPerformance (
						TraderId			INT
					,	CustId				INT
					,	EventDate			DATE
					,	MatchId				INT
					,	BetType				SMALLINT
					,	Stake				MONEY
					,	WinLost				MONEY
					,	SMAWinLost			MONEY
					,	Comm				MONEY
					,	ExtraPT				DECIMAL(9, 8)
					,	TPositionTaking		SMALLMONEY
					,	VirtualRate			FLOAT
					,	ActualRate			FLOAT
					);
	
	CREATE CLUSTERED INDEX #CIX_tmpStagingOSTraderPerformanceIdx ON #tmpStagingOSTraderPerformance (
						EventDate			ASC
	); 

	CREATE NONCLUSTERED INDEX	#NCIX_tmpStagingOSTraderPerformanceIdx ON #tmpStagingOSTraderPerformance (
						CustId				ASC
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
		TRUNCATE TABLE #tmpOSTrader;
		TRUNCATE TABLE	#ExtraPTSportbook;

		SELECT @Date = '@FromDateBK = ' + CONVERT(NVARCHAR, @FromDateBK, 120) + ', @ToDateBK = ' + CONVERT(NVARCHAR, @ToDateBK, 120);
		
		IF @DotExtraPTDate <= @FromDateBK
		BEGIN
			INSERT INTO	#tmpOSTrader (TraderId, MatchId, SportType, EventDate, BetType)
			SELECT	DISTINCT
					[TraderId]	= a.TraderID
				,	[MatchId]	= m.MatchId
				,	[SportType]	= m.Sporttype
				,	[EventDate]	= m.EventDate
				,	[BetType]	= a.Bettype
			FROM	bodb_archive.dbo.Dot_Admin_Assignment_Trader_bk AS a WITH (NOLOCK)
				INNER JOIN	bodb_Archive.dbo.Match_bk AS m WITH (NOLOCK) ON	a.matchid = m.matchid
				LEFT JOIN	#tmpDLAllBettypes AS b WITH (NOLOCK) ON	a.bettype = b.BetType
			CROSS APPLY (
							SELECT dt.TraderID, dt.MatchId, dt.Bettype,
								ROW_NUMBER() OVER(PARTITION BY dt.MatchId, dt.Bettype ORDER BY dt.UpdatedTime DESC, dt.ID DESC) AS Row_Num
							FROM bodb_archive.dbo.Dot_Admin_Assignment_Trader_bk AS dt WITH (NOLOCK)
							WHERE   a.matchid = dt.matchid
								AND a.bettype = dt.bettype		
								AND a.TraderId <> 0
							) dat
			WHERE	m.EventDate BETWEEN @FromDateBK AND @ToDateBK
				AND	m.Sporttype <> 1
				AND m.EventStatus = 'completed'
				AND	m.MatchCode NOT LIKE '%hedge%'
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
				RAISERROR('From BK - Insert #tmpOSTrader - Date: "%s" - %d rows - %d ms', 0, 0, @Date, @RowCount, @Duration) WITH NOWAIT;
			END;
		END;

		IF @DotExtraPTDate > @FromDateBK AND @DotExtraPTDate <= @ToDateBK
		BEGIN
			SELECT @Date = '@FromDateBK = ' + CONVERT(NVARCHAR, @FromDateBK, 120) + ', (@DotExtraPTDate - 1) = ' + CONVERT(NVARCHAR, (@DotExtraPTDate - 1), 120);

			INSERT INTO	#tmpOSTrader (TraderId, MatchId, SportType, EventDate, BetType)
			SELECT	DISTINCT
					[TraderId]	= a.OperatorID
				,	[MatchId]	= m.MatchId
				,	[SportType]	= m.Sporttype
				,	[EventDate]	= m.EventDate
				,	[BetType]	= CASE	WHEN a.bettype = 5 AND a.operatortype = 1
											THEN 1
										ELSE ISNULL(b.MainDBBetType, 0) 
									END
			FROM	bodb_archive.dbo.Dot_Admin_Assignment_Operator_bk AS a WITH (NOLOCK)
				INNER JOIN	bodb_Archive.dbo.Match_bk AS m WITH (NOLOCK) ON	a.matchid = m.matchid
				LEFT JOIN	#tmpDLAllBettypes AS b WITH (NOLOCK) ON	a.bettype = b.AssignmentBetType
						AND	a.OperatorType = b.OperatorType
			WHERE	m.EventDate BETWEEN @FromDateBK AND (@DotExtraPTDate - 1)
				AND	m.Sporttype <> 1
				AND m.EventStatus = 'completed'
				AND	m.MatchCode NOT LIKE '%hedge%'
				AND	a.OperatorType < 3;
		
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

			INSERT INTO	#tmpOSTrader (TraderId, MatchId, SportType, EventDate, BetType)
			SELECT	DISTINCT
					[TraderId]	= a.TraderID
				,	[MatchId]	= m.MatchId
				,	[SportType]	= m.Sporttype
				,	[EventDate]	= m.EventDate
				,	[BetType]	= a.Bettype
			FROM	bodb_archive.dbo.Dot_Admin_Assignment_Trader_bk AS a WITH (NOLOCK)
				INNER JOIN	bodb_Archive.dbo.Match_bk AS m WITH (NOLOCK) ON	a.matchid = m.matchid
				LEFT JOIN	#tmpDLAllBettypes AS b WITH (NOLOCK) ON	a.bettype = b.BetType
			CROSS APPLY (
							SELECT dt.TraderID, dt.MatchId, dt.Bettype,
								ROW_NUMBER() OVER(PARTITION BY dt.MatchId, dt.Bettype ORDER BY dt.UpdatedTime DESC, dt.ID DESC) AS Row_Num
							FROM bodb_archive.dbo.Dot_Admin_Assignment_Trader_bk AS dt WITH (NOLOCK)
							WHERE   a.matchid = dt.matchid
								AND a.bettype = dt.bettype		
								AND a.TraderId <> 0
							) dat
			WHERE	m.EventDate BETWEEN @DotExtraPTDate AND @ToDateBK
				AND	m.Sporttype <> 1
				AND m.EventStatus = 'completed'
				AND	m.MatchCode NOT LIKE '%hedge%'
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
				RAISERROR('From BK - Insert #tmpOSTrader - Date: "%s" - %d rows - %d ms', 0, 0, @Date, @RowCount, @Duration) WITH NOWAIT;
			END;

			SELECT @Date = '@FromDateBK = ' + CONVERT(NVARCHAR, @FromDateBK, 120) + ', @ToDateBK = ' + CONVERT(NVARCHAR, @ToDateBK, 120);
		END;

		IF @DotExtraPTDate > @ToDateBK 
		BEGIN
			INSERT INTO	#tmpOSTrader (TraderId, MatchId, SportType, EventDate, BetType)
			SELECT	DISTINCT
					[TraderId]	= a.OperatorID
				,	[MatchId]	= m.MatchId
				,	[SportType]	= m.Sporttype
				,	[EventDate]	= m.EventDate
				,	[BetType]	= CASE	WHEN a.bettype = 5 AND a.operatortype = 1
											THEN 1
										ELSE ISNULL(b.MainDBBetType, 0) 
									END
			FROM	bodb_archive.dbo.Dot_Admin_Assignment_Operator_bk AS a WITH (NOLOCK)
				INNER JOIN	bodb_Archive.dbo.Match_bk AS m WITH (NOLOCK) ON	a.matchid = m.matchid
				LEFT JOIN	#tmpDLAllBettypes AS b WITH (NOLOCK) ON	a.bettype = b.AssignmentBetType
						AND	a.OperatorType = b.OperatorType
			WHERE	m.EventDate BETWEEN @FromDateBK AND @ToDateBK
				AND	m.Sporttype <> 1
				AND m.EventStatus = 'completed'
				AND	m.MatchCode NOT LIKE '%hedge%'
				AND	a.OperatorType < 3;

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
			INSERT INTO #tmpFilteredBettransByBatch 
					(TransId, CustId, MatchId, Winlostdate, Bettype, Modds, Stake, Actual_stake, Virtualrate, Actualrate, Winlost, Awinlost, Mwinlost, Swinlost, Tpositiontaking, Srecommend, Scomm, Epositiontaking)
			SELECT	b.transid, b.custid, b.matchid, b.winlostdate, b.bettype, b.modds, b.stake, b.actual_stake, b.virtualrate, b.actualrate, b.winlost, b.awinlost, b.mwinlost, b.swinlost, b.tpositiontaking, b.srecommend, b.Scomm, ISNULL(b.epositiontaking, 0)	
			FROM	bodb_Archive.dbo.bettrans_bk AS b WITH (NOLOCK)
				INNER JOIN bodb_Archive.dbo.match_bk m WITH (NOLOCK) ON b.MatchId = m.MatchId
				INNER JOIN bodb02.dbo.SportBettypeMatrix sbm ON b.bettype = sbm.BetType and m.Sporttype = sbm.SportType
			WHERE	b.winlostdate = @WinLostDate
					AND	b.statusID IN (111,112, 113)
					AND	b.Currency NOT IN (20, 27, 28)
					AND	b.LiveIndicator = 1
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
				RAISERROR('From BK - Insert #tmpFilteredBettransByBatch - Date: "%s" - %d rows - %d ms', 0, 0, @Date, @RowCount, @Duration) WITH NOWAIT;
			END;
			
			INSERT INTO #tmpStagingOSTraderPerformance (TraderId, CustId, EventDate, MatchId, BetType, Stake, WinLost, SMAWinLost, Comm, ExtraPT, TPositionTaking, VirtualRate, ActualRate)
			SELECT	[TraderId]			= ISNULL(t.TraderId, @IdForUnassignedTrader)
				,	[MemberCustId]		= b.custid
				,	[EventDate]			= b.winlostdate
				,	[MatchId]			= b.matchid
				,	[BetType]			= b.bettype
				,	[Stake]				= ((CASE WHEN b.modds = 0.25 OR b.modds = -0.25 THEN ABS(b.stake) / 2 ELSE ABS(b.stake) END)) --Turnover
				,	[WinLost]			= (b.winlost - b.actual_stake)  --Winlost
				,	[SMAWinLost]		= (b.awinlost + b.mwinlost + b.swinlost)  --SMAWinlost
				,	[Comm]				= b.scomm  --Commission
				,	[ExtraPT]			= CASE WHEN b.Winlostdate < '20200213' THEN ISNULL(es.ExtraPT, 0) ELSE ISNULL(b.epositiontaking, 0) END
				,	[TPositionTaking]	= b.tpositiontaking
				,	[VirtualRate]		= b.virtualrate
				,	[ActualRate]		= b.actualrate
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
			
			DELETE dbo.OSDataTGRS WHERE EventDate = @winlostdate;

			INSERT INTO	dbo.OSDataTGRS (TraderId, MatchId, MatchCode, EventDate, SportId, LeagueId, BettypeId, Turnover, WinLoss, Comm, BetCount, Target)
			SELECT	[TraderId]		= b.TraderId
				,	[MatchId]		= m.MatchId
				,	[MatchCode]		= m.matchcode
				,	[EventDate]		= b.EventDate
				,	[SportId]		= m.SportType
				,	[LeagueId]		= m.LeagueId
				,	[BettypeId]		= b.BetType
				,	[Turnover]		= SUM(b.Stake * (1 - b.TPositionTaking - b.ExtraPT) * b.VirtualRate)
				,	[WinLoss]		= SUM(((-(b.WinLost + b.SMAWinLost)) + b.WinLost * b.ExtraPT) * b.VirtualRate)
				,	[Comm]			= SUM((b.Comm - (CASE WHEN b.TPositionTaking = 1 THEN 0 ELSE (b.Comm * b.ExtraPT / (1 - b.TPositionTaking)) END)) * (CASE WHEN b.VirtualRate > b.ActualRate THEN b.ActualRate ELSE b.VirtualRate END))
				,	[BetCount]		= SUM(CASE WHEN tc.custid IS NULL THEN 1 ELSE 0 END)  --Exclude Cashout Ticket				
				,	[Target]		= dbo.f_GetOSTargetBySportLeagueBettype(m.sporttype, m.leagueid, b.BetType, m.eventdate)
			FROM		#tmpStagingOSTraderPerformance AS b WITH (NOLOCK)
				INNER JOIN	bodb_Archive.dbo.Match_bk AS m WITH (NOLOCK) ON	b.MatchId = m.MatchId
				LEFT JOIN bodb02.dbo.TradeCust tc WITH (NOLOCK) ON b.CustId = tc.CustId AND tc.VendorID = 14
			WHERE m.eventdate = @WinLostDate
			GROUP BY b.TraderId, m.MatchId, m.MatchCode, b.EventDate, m.SportType, m.LeagueId, b.BetType, m.EventDate;
			
			SELECT	@RowCount	= @@ROWCOUNT
				,	@Duration	= DATEDIFF(millisecond, @Begin, GETDATE())
				;

			IF	@Debug = 1
			BEGIN
				-- Force the output to appear immediately
				RAISERROR('From BK - Insert OSDataTGRS - Date: "%s" - %d rows - %d ms', 0, 0, @Date, @RowCount, @Duration) WITH NOWAIT;
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
		TRUNCATE TABLE #tmpOSTrader;
		TRUNCATE TABLE	#ExtraPTSportbook;
		SELECT @Date = '@FromDate14 = ' + CONVERT(NVARCHAR, @FromDate14, 120) + ', @ToDate14 = ' + CONVERT(NVARCHAR, @ToDate14, 120);

		INSERT INTO	#tmpOSTrader (TraderId, MatchId, SportType, EventDate, BetType)
		SELECT	DISTINCT
				[TraderId]	= a.TraderID
			,	[MatchId]	= m.MatchId
			,	[SportType]	= m.Sporttype
			,	[EventDate]	= m.EventDate
			,	[BetType]	= a.bettype
		FROM	bodb02.dbo.Dot_Admin_Assignment_Trader AS a WITH (NOLOCK)
			INNER JOIN	bodb02.dbo.Match14 AS m WITH (NOLOCK) ON a.matchid = m.matchid
			LEFT JOIN	#tmpDLAllBettypes AS b WITH (NOLOCK) ON	a.bettype = b.BetType
		CROSS APPLY (
					SELECT dt.TraderID, dt.MatchId, dt.Bettype,
						ROW_NUMBER() OVER(PARTITION BY dt.MatchId, dt.Bettype ORDER BY dt.UpdatedTime DESC, dt.ID DESC) AS Row_Num
					FROM bodb02.dbo.Dot_Admin_Assignment_Trader AS dt WITH (NOLOCK)
					WHERE   a.matchid = dt.matchid
						AND a.bettype = dt.bettype		
						AND a.TraderId <> 0
					) dat
		WHERE	m.EventDate BETWEEN @FromDate14 AND @ToDate14
			AND	m.Sporttype <> 1
			AND m.EventStatus = 'completed'
			AND	m.MatchCode NOT LIKE '%hedge%'
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
			INSERT INTO #tmpFilteredBettransByBatch 
				   (TransId, CustId, MatchId, Winlostdate, Bettype, Modds, Stake, Actual_stake, Virtualrate, Actualrate, Winlost, Awinlost, Mwinlost, Swinlost, Tpositiontaking, Srecommend, Scomm, Epositiontaking)
			SELECT	b.transid, b.custid, b.matchid, b.winlostdate, b.bettype, b.modds, b.stake, b.actual_stake, b.virtualrate, b.actualrate, b.winlost, b.awinlost, b.mwinlost, b.swinlost, b.tpositiontaking, b.srecommend, b.Scomm, ISNULL(b.epositiontaking, 0)
			FROM	bodb02.dbo.bettrans14 AS b WITH (NOLOCK)
				INNER JOIN bodb02.dbo.match14 m WITH (NOLOCK) ON b.MatchId = m.MatchId
				INNER JOIN bodb02.dbo.SportBettypeMatrix sbm ON b.Bettype = sbm.BetType and m.Sporttype = sbm.SportType
			WHERE	b.Winlostdate = @WinLostDate
					AND	b.StatusID IN (111,112, 113)
					AND	b.Currency NOT IN (20, 27, 28)
					AND	b.LiveIndicator = 1
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
			
			INSERT INTO #tmpStagingOSTraderPerformance (TraderId, CustId, EventDate, MatchId, BetType, Stake, WinLost, SMAWinLost, Comm, ExtraPT, TPositionTaking, VirtualRate, ActualRate)
			SELECT	[TraderId]			= ISNULL(t.TraderId, @IdForUnassignedTrader)
				,	[CustId]			= b.custid
				,	[EventDate]			= b.winlostdate
				,	[MatchId]			= b.matchid
				,	[BetType]			= b.bettype
				,	[Stake]				= ((CASE WHEN b.modds = 0.25 OR b.modds = -0.25 THEN ABS(b.stake) / 2 ELSE ABS(b.stake) END)) --Turnover
				,	[WinLost]			= (b.winlost - b.actual_stake)  --Winlost
				,	[SMAWinLost]		= (b.awinlost + b.mwinlost + b.swinlost)  --SMAWinlost
				,	[Comm]				= b.scomm  --Commission
				,	[ExtraPT]			= ISNULL(b.epositiontaking, 0)
				,	[TPositionTaking]	= b.tpositiontaking
				,	[VirtualRate]		= b.virtualrate
				,   [ActualRate]		= b.actualrate
			FROM		#tmpFilteredBettransByBatch AS b
				LEFT JOIN	#tmpOSTrader AS t WITH (NOLOCK)	ON	b.winlostdate = t.EventDate
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
			
			DELETE dbo.OSDataTGRS WHERE EventDate = @winlostdate;

			INSERT INTO	dbo.OSDataTGRS (TraderId, MatchId, MatchCode, EventDate, SportId, LeagueId, BettypeId, Turnover, WinLoss, Comm, BetCount, Target)
			SELECT	[TraderId]		= b.TraderId
				,	[MatchId]		= m.MatchId
				,	[MatchCode]		= m.matchcode
				,	[EventDate]		= b.EventDate
				,	[SportId]		= m.SportType
				,	[LeagueId]		= m.LeagueId
				,	[BettypeId]		= b.BetType
				,	[Turnover]		= SUM(b.Stake * (1 - b.TPositionTaking - b.ExtraPT) * b.VirtualRate)
				,	[WinLoss]		= SUM(((-(b.WinLost + b.SMAWinLost)) + b.WinLost * b.ExtraPT) * b.VirtualRate)
				,	[Comm]			= SUM((b.Comm - (CASE WHEN b.TPositionTaking = 1 THEN 0 ELSE (b.Comm * b.ExtraPT / (1 - b.TPositionTaking)) END)) * (CASE WHEN b.VirtualRate > b.ActualRate THEN b.ActualRate ELSE b.VirtualRate END))
				,	[BetCount]		= SUM(CASE WHEN tc.custid IS NULL THEN 1 ELSE 0 END)  --Exclude Cashout Ticket				
				,	[Target]		= dbo.f_GetOSTargetBySportLeagueBettype(m.sporttype, m.leagueid, b.BetType, m.eventdate)
			FROM	#tmpStagingOSTraderPerformance AS b WITH (NOLOCK)
				INNER JOIN	bodb02.dbo.match14 AS m WITH (NOLOCK) ON b.MatchId = m.MatchId
				LEFT JOIN bodb02.dbo.TradeCust tc WITH (NOLOCK) ON b.CustId = tc.CustId AND tc.VendorID = 14
			WHERE m.EventDate = @WinLostDate
			GROUP BY b.TraderId, m.MatchId, m.MatchCode, b.EventDate, m.SportType, m.LeagueId, b.BetType, m.EventDate;
			
			SELECT	@RowCount	= @@ROWCOUNT
				,	@Duration	= DATEDIFF(millisecond, @Begin, GETDATE())
				;

			IF	@Debug = 1
			BEGIN
				-- Force the output to appear immediately
				RAISERROR('From 14 - Insert OSDataTGRS - Date: "%s" - %d rows - %d ms', 0, 0, @Date, @RowCount, @Duration) WITH NOWAIT;
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
		TRUNCATE TABLE #tmpOSTrader;
		TRUNCATE TABLE	#ExtraPTSportbook;
		SELECT @Date = '@FromDateOrigin = ' + CONVERT(NVARCHAR, @FromDateOrigin, 120) + ', @ToDateOrigin = ' + CONVERT(NVARCHAR, @ToDateOrigin, 120);
		
		INSERT INTO	#tmpOSTrader (TraderId, MatchId, SportType, EventDate, BetType)
		SELECT	DISTINCT
				[TraderId]		= a.TraderID
			,	[MatchId]		= m.MatchId
			,	[SportType]		= m.Sporttype
			,	[EventDate]		= m.EventDate
			,	[BetType]		= a.bettype
		FROM	bodb02.dbo.Dot_Admin_Assignment_Trader AS a WITH (NOLOCK)
			INNER JOIN	bodb02.dbo.match AS m WITH (NOLOCK) ON	a.matchid = m.matchid
			LEFT JOIN	#tmpDLAllBettypes AS b WITH (NOLOCK) ON	a.bettype = b.BetType
		CROSS APPLY (
						SELECT dt.TraderID, dt.MatchId, dt.Bettype,
							ROW_NUMBER() OVER(PARTITION BY dt.MatchId, dt.Bettype ORDER BY dt.UpdatedTime DESC, dt.ID DESC) AS Row_Num
						FROM bodb02.dbo.Dot_Admin_Assignment_Trader AS dt WITH (NOLOCK)
						WHERE   a.matchid = dt.matchid
							AND a.bettype = dt.bettype		
							AND a.TraderId <> 0
						) dat
		WHERE	m.EventDate BETWEEN @FromDateOrigin AND @ToDateOrigin
			AND	m.Sporttype <> 1
			AND m.EventStatus = 'completed'
			AND	m.MatchCode NOT LIKE '%hedge%'
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
			INSERT INTO #tmpFilteredBettransByBatch 
					(TransId, CustId, MatchId, Winlostdate, Bettype, Modds, Stake, Actual_stake, Virtualrate, Actualrate, Winlost, Awinlost, Mwinlost, Swinlost, Tpositiontaking, Srecommend, Scomm, Epositiontaking)
			SELECT	b.transid, b.custid, b.matchid, b.winlostdate, b.bettype, b.modds, b.stake, b.actual_stake, b.virtualrate, b.actualrate, b.winlost, b.awinlost, b.mwinlost, b.swinlost, b.tpositiontaking, b.srecommend, b.scomm, ISNULL(b.epositiontaking, 0)
			FROM	bodb02.dbo.bettrans AS b WITH (NOLOCK)
				INNER JOIN bodb02.dbo.match m WITH (NOLOCK) ON b.matchid = m.matchid
				INNER JOIN bodb02.dbo.SportBettypeMatrix sbm ON b.bettype = sbm.BetType and m.sporttype = sbm.SportType
			WHERE	b.Winlostdate = @WinLostDate
					AND	b.StatusID IN (111,112, 113)
					AND	b.Currency NOT IN (20, 27, 28)
					AND	b.LiveIndicator = 1
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
			
			INSERT INTO #tmpStagingOSTraderPerformance (TraderId, CustId, EventDate, MatchId, BetType, Stake, WinLost, SMAWinLost, Comm, ExtraPT, TPositionTaking, VirtualRate, ActualRate)
			SELECT	[TraderId]			= ISNULL(t.TraderId, @IdForUnassignedTrader)
				,	[CustId]			= b.custid
				,	[EventDate]			= b.winlostdate
				,	[MatchId]			= b.matchid
				,	[BetType]			= b.bettype
				,	[Stake]				= ((CASE WHEN b.modds = 0.25 OR b.modds = -0.25 THEN ABS(b.stake) / 2 ELSE ABS(b.stake) END)) --Turnover
				,	[WinLost]			= (b.winlost - b.actual_stake)  --Winlost
				,	[SMAWinLost]		= (b.awinlost + b.mwinlost + b.swinlost)  --SMAWinlost
				,	[Comm]				= b.scomm  --Commission
				,	[ExtraPT]			= ISNULL(b.epositiontaking, 0)
				,	[TPositionTaking]	= b.tpositiontaking
				,	[VirtualRate]		= b.virtualrate
				,   [ActualRate]		= b.actualrate
			FROM	#tmpFilteredBettransByBatch AS b
				LEFT JOIN	#tmpOSTrader AS t WITH (NOLOCK)	ON	b.winlostdate = t.EventDate
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
			
			DELETE dbo.OSDataTGRS WHERE EventDate = @winlostdate;

			INSERT INTO dbo.OSDataTGRS(TraderId, MatchId, MatchCode, EventDate, SportId, LeagueId, BettypeId, Turnover, WinLoss, Comm, BetCount, Target)
			SELECT	[TraderId]		= b.TraderId
				,	[MatchId]		= m.MatchId
				,	[MatchCode]		= m.MatchCode
				,	[EventDate]		= b.EventDate
				,	[SportId]		= m.Sporttype
				,	[LeagueId]		= m.LeagueId
				,	[BettypeId]		= b.BetType
				,	[Turnover]		= SUM(b.Stake * (1 - b.TPositionTaking - b.ExtraPT) * b.VirtualRate)
				,	[WinLoss]		= SUM(((-(b.WinLost + b.SMAWinLost)) + b.WinLost * b.ExtraPT) * b.VirtualRate)
				,	[Comm]			= SUM((b.Comm - (CASE WHEN b.TPositionTaking = 1 THEN 0 ELSE (b.Comm * b.ExtraPT / (1 - b.TPositionTaking)) END)) * (CASE WHEN b.VirtualRate > b.ActualRate THEN b.ActualRate ELSE b.VirtualRate END))
				,	[BetCount]		= SUM(CASE WHEN tc.custid IS NULL THEN 1 ELSE 0 END) --Live BetCount	
				,	[Target]		= dbo.f_GetOSTargetBySportLeagueBettype(m.sporttype, m.leagueid, b.BetType, m.eventdate)
			FROM	#tmpStagingOSTraderPerformance AS b WITH (NOLOCK)
				INNER JOIN	bodb02.dbo.match AS m WITH (NOLOCK) ON	b.MatchId = m.MatchId
				LEFT JOIN bodb02.dbo.TradeCust tc WITH (NOLOCK) ON b.CustId = tc.CustId AND tc.VendorID = 14
			WHERE m.EventDate = @WinLostDate
			GROUP BY b.TraderId, m.MatchId, m.MatchCode, b.EventDate, m.SportType, m.LeagueId, b.BetType, m.EventDate;
			
			SELECT	@RowCount	= @@ROWCOUNT
				,	@Duration	= DATEDIFF(millisecond, @Begin, GETDATE())
				;
			IF	@Debug = 1
			BEGIN
				-- Force the output to appear immediately
				RAISERROR('From Origin - Insert OSDataTGRS - Date: "%s" - %d rows - %d ms', 0, 0, @Date, @RowCount, @Duration) WITH NOWAIT;
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