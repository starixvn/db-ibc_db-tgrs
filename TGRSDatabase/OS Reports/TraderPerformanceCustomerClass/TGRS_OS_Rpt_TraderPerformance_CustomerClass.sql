CREATE PROCEDURE [dbo].[TGRS_OS_Rpt_TraderPerformance_CustomerClass]
		@FromDate				DATE		 	= '2023-01-01'
	,	@ToDate					DATE		 	= '2023-06-06'
	,	@TraderName				NVARCHAR(50) 	= ''
	,	@SportId				INT		 	 	= - 1
	,	@CustomerClassIds		NVARCHAR(2000)	= '-999'
	,	@AllCustomerClassIds	NVARCHAR(2000)	= '200,201,202,203,204,205,2000,2001,2002,2003,2004,2005,2100,2101,2102,2103,2104,2105,2200,2201,2202,2203,2204,2205,2303,2304,2305,2403,2404,2405,300,301,302,303,304,3000,3001,3002,3003,3004,3100,3101,3200,3201,400,401,901,902,999,1001,1010,2500,2503,2504,2505,4000'
AS
/*
	Created:	20230606@John.Ngo
	Task :		Staging Data for E-Sports/Basketball trader performance by class
	DB:			DBTGRS.bodb_TGRS
  
	Revisions:
		- 20201112@John.Ngo: Staging Data for E-Sports/Basketball trader performance by class [Redmine ID: 187083]

	Params Explaination:
		- @CustomerClass: -999 Unknown;

	Exam: EXECUTE [TGRS_OS_Rpt_TraderPerformance_CustomerClass]  @FromDate = '2023-01-01', @ToDate= '2023-06-06', @SportId = -1, @CustomerClassIds = '-999'
*/
BEGIN
	SET NOCOUNT ON;

	IF @SportId IS NULL
	BEGIN
		SET @SportId = - 1;
	END;

	IF OBJECT_ID('tempdb..#tmpTraderPerformanceCC') IS NOT NULL
	BEGIN
		DROP TABLE #tmpTraderPerformanceCC;
	END

	CREATE TABLE #tmpTraderPerformanceCC (
			TraderId			INT
	    ,	CustomerClass		SMALLINT
	    ,	SportId				INT
	    ,	LeagueId			INT
	    ,	MatchId				INT
	    ,	EventDate			DATE
	    ,	BettypeId			SMALLINT
	    ,	Turnover			MONEY
	    ,	Winloss				MONEY
	    ,	Comm				MONEY
	    ,	Turnover_AR			MONEY
	    ,	WinLoss_AR			MONEY
	    ,	Comm_AR				MONEY
	    ,	BetCount			INT 
	);

	CREATE CLUSTERED INDEX	#CIX_tmpTraderPerformanceCC_EventDate ON #tmpTraderPerformanceCC (
			EventDate			ASC
	);
	
	CREATE NONCLUSTERED INDEX #IX_tmpTraderPerformanceCCIdx ON #tmpTraderPerformanceCC (
			TraderId			ASC
	    ,	CustomerClass		ASC
	    ,	SportId				ASC
	);

	-- @AllCustomerClassIds
	IF	OBJECT_ID('tempdb..#tmpAllCustomerClass') IS NOT NULL
	BEGIN
		DROP TABLE	#tmpAllCustomerClass;
	END;

	CREATE TABLE #tmpAllCustomerClass (
			CustomerClass 		SMALLINT PRIMARY KEY CLUSTERED
	);
	
	INSERT INTO #tmpAllCustomerClass(CustomerClass)
	SELECT val 
	FROM dbo.strSplit_Key(@AllCustomerClassIds,',') cc
	WHERE cc.val <> -999;

	-- @CustomerClassIds
	IF	OBJECT_ID('tempdb..#tmpCustomerClass') IS NOT NULL
	BEGIN
		DROP TABLE	#tmpCustomerClass;
	END;

	CREATE TABLE #tmpCustomerClass (
			CustomerClass 		SMALLINT PRIMARY KEY CLUSTERED
	);
	
	IF @CustomerClassIds <> ''
	BEGIN
		INSERT INTO #tmpCustomerClass(CustomerClass)
		SELECT val 
		FROM dbo.strSplit_Key(@CustomerClassIds,',') cc
		WHERE cc.val <> -999;
	END;
	
	-- START --
	INSERT INTO #tmpTraderPerformanceCC (
			TraderId
	    ,	CustomerClass
	    ,	SportId
	    ,	LeagueId
	    ,	MatchId
	    ,	BettypeId
	    ,	Turnover
	    ,	Winloss
	    ,	Comm
	    ,	Turnover_AR
	    ,	WinLoss_AR
	    ,	Comm_AR
	    ,	BetCount
	)
	SELECT	tp.TraderId
		,	ISNULL(tp.CustomerClass, 0)
	    ,	tp.SportId
	    ,	tp.LeagueId
	    ,	tp.MatchId
	    ,	tp.BettypeId
		,	SUM(tp.Turnover)
		,	SUM(tp.Winloss)
		,   SUM(tp.Comm)
		,	SUM(tp.Turnover_AR)
		,	SUM(tp.WinLoss_AR)
		,   SUM(tp.Comm_AR)
		,	SUM(tp.BetCount)
	FROM dbo.OSDataTGRS_CustomerClass tp WITH (NOLOCK)
		INNER JOIN #tmpCustomerClass AS cc ON cc.CustomerClass = tp.CustomerClass
	WHERE tp.EventDate BETWEEN @FromDate AND @ToDate
		AND (tp.SportId = @SportId OR @SportId = - 1)
	GROUP BY tp.TraderId
		,	tp.CustomerClass
	    ,	tp.SportId
	    ,	tp.LeagueId
	    ,	tp.MatchId
	    ,	tp.BettypeId;
		
	IF CHARINDEX('-999', @CustomerClassIds) > 0
		BEGIN
			INSERT INTO #tmpTraderPerformanceCC (
					TraderId
				,	CustomerClass
				,	SportId
				,	LeagueId
				,	MatchId
				,	BettypeId
				,	Turnover
				,	Winloss
				,	Comm
				,	Turnover_AR
				,	WinLoss_AR
				,	Comm_AR
				,	BetCount
			)
			SELECT	tp.TraderId
				,	ISNULL(tp.CustomerClass, 0)
				,	tp.SportId
				,	tp.LeagueId
				,	tp.MatchId
				,	tp.BettypeId
				,	SUM(tp.Turnover)
				,	SUM(tp.Winloss)
				,   SUM(tp.Comm)
				,	SUM(tp.Turnover_AR)
				,	SUM(tp.WinLoss_AR)
				,   SUM(tp.Comm_AR)
				,	SUM(tp.BetCount)
			FROM dbo.OSDataTGRS_CustomerClass tp WITH (NOLOCK)
				LEFT JOIN #tmpAllCustomerClass AS acc ON acc.CustomerClass = tp.CustomerClass
			WHERE tp.EventDate BETWEEN @FromDate AND @ToDate
				AND (tp.SportId = @SportId OR @SportId = - 1)
				AND acc.CustomerClass IS NULL
			GROUP BY tp.TraderId
				,	tp.CustomerClass
				,	tp.SportId
				,	tp.LeagueId
				,	tp.MatchId
				,	tp.BettypeId;
		END;
	
	SELECT	tp.TraderId
		,	tr.TraderName
		,	tp.SportId
		,	CAST(tp.CustomerClass AS NVARCHAR(8)) AS CustomerClass
		,	CASE WHEN ISNULL(SUM(tp.Winloss), 0) <> 0 THEN (ISNULL(SUM(tp.Winloss), 0) - ISNULL(SUM (tp.Comm), 0)) * 100/ISNULL(SUM(tp.Turnover), 0) ELSE NULL END AS Margin
		,	ISNULL(SUM(tp.Turnover), 0) AS Turnover
		,	ISNULL(SUM(tp.Winloss), 0) - ISNULL(SUM (tp.Comm), 0) AS WinLoss
		,	CASE WHEN ISNULL(SUM(tp.WinLoss_AR), 0) <> 0 THEN (ISNULL(SUM(tp.WinLoss_AR), 0) - ISNULL(SUM (tp.Comm_AR), 0)) * 100/ISNULL(SUM(tp.Turnover_AR), 0) ELSE NULL END AS MarginReal
		,	ISNULL(SUM(tp.Turnover_AR), 0) AS TurnoverReal
		,	ISNULL(SUM(tp.WinLoss_AR), 0) - ISNULL(SUM (tp.Comm_AR), 0) AS WinLossReal
		,	SUM(tp.BetCount) AS BetCount
	FROM #tmpTraderPerformanceCC tp WITH (NOLOCK)
		INNER JOIN dbo.OSTrader tr WITH (NOLOCK) ON tr.TraderId = tp.TraderId
	WHERE (@TraderName = '' OR tr.TraderName LIKE '%' + @TraderName + '%')
	GROUP BY tp.TraderId
		,	tr.TraderName
		,	tp.SportId
		,	tp.CustomerClass
	ORDER BY tr.TraderName, CAST(tp.CustomerClass AS NVARCHAR(8));

	DROP TABLE #tmpAllCustomerClass;
	DROP TABLE #tmpCustomerClass;
	DROP TABLE #tmpTraderPerformanceCC;
END;

GO
/*<info serverAlias="DBTGRS-bodb_TGRS" executers="bodbTGRSNet" isFunction="0" isNested="0"></info>*/