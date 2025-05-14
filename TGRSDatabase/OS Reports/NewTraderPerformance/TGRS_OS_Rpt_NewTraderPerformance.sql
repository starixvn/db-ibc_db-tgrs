/*<info serverAlias="DBTGRS-bodb_TGRS" executers="wsv_tgrs" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[TGRS_OS_Rpt_NewTraderPerformance] 
		@ReportType		TINYINT		 = 1
	,	@TraderName		NVARCHAR(50) = NULL
	,	@FromDate		DATE		 = '2016-01-01'
	,	@ToDate			DATE		 = '2017-12-31'
	,	@SportId		INT			 = -1
	,	@LiveType		SMALLINT	 = -1

AS
/*
	Created: 20170403@Aaron
	Task : Get new OS Trader Performance
	DB:  DBTGRS.bodb_TGRS
	Original:

	Revisions:
		- 20181030@Long: Adding Betcount column to OS's reports [Redmine ID: #101741]
		- 20200914@John.Ngo: Support Live/Nonlive for OSDataTGRS [Redmine ID: #140875]
		- 20250514@Della: Fix default param @LiveType (#225204)  

	Param's Explanation (filtered by):
		- @LiveType: -1 All; 0 Nonlive; 1 Live

*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @IncrementTimes DECIMAL(18, 2)
		,	@IncrementValue DECIMAL(18, 2)
		,	@FloorMark		DECIMAL(18, 2);

	SELECT @IncrementTimes = ParamValue
	FROM [dbo].[OSParameter] WITH (NOLOCK)
	WHERE ParamId = 3;

	SELECT @IncrementValue = ParamValue
	FROM [dbo].[OSParameter] WITH (NOLOCK)
	WHERE ParamId = 5;

	SELECT @FloorMark = ParamValue
	FROM [dbo].[OSParameter] WITH (NOLOCK)
	WHERE ParamId = 7;

	IF @SportId IS NULL
	BEGIN
		SET @SportId = - 1;
	END;

	IF OBJECT_ID('tempdb..#tmpTraderPerformanceDetail') IS NOT NULL
	BEGIN
		DROP TABLE #tmpTraderPerformanceDetail
	END;

	CREATE TABLE #tmpTraderPerformanceDetail (
			TraderId			INT
		,	SportId				INT
		,	LeagueId			INT
		,	BettypeId			INT
		,	Turnover			MONEY
		,	WinLoss				MONEY
		,	JuiceTurnover		MONEY
		,	JuiceWinLoss		MONEY
		,	EventProductCount	INT
		,	Target				DECIMAL(18, 4)
		,	BetCount			BIGINT
	);
	
	CREATE CLUSTERED INDEX #CIX_tmpTraderPerformanceDetail_TraderIdSportId ON #tmpTraderPerformanceDetail (
			TraderId
		,	SportId
	);

	IF OBJECT_ID('tempdb..#tmpTraderPerformanceDetailByBettype') IS NOT NULL
	BEGIN
		DROP TABLE #tmpTraderPerformanceDetailByBettype
	END;

	CREATE TABLE #tmpTraderPerformanceDetailByBettype (
			TraderId			INT
		,	SportId				INT
		,	BettypeId			INT
		,	Turnover			MONEY
		,	WinLoss				MONEY
		,	JuiceTurnover		MONEY
		,	JuiceWinLoss		MONEY
		,	Point				MONEY
		,	EventProductCount	INT
		,	BetCount			BIGINT
	);

	CREATE CLUSTERED INDEX TPDB_TraderId_SportId ON #tmpTraderPerformanceDetailByBettype (
			TraderId
		,	SportId
	);

	IF OBJECT_ID('tempdb..#tmpTraderPerformanceDetailBySport') IS NOT NULL
	BEGIN
		DROP TABLE #tmpTraderPerformanceDetailBySport
	END;

	CREATE TABLE #tmpTraderPerformanceDetailBySport (
			TraderId			INT
		,	SportId				INT
		,	Turnover			MONEY
		,	WinLoss				MONEY
		,	JuiceTurnover		MONEY
		,	JuiceWinLoss		MONEY
		,	Point				MONEY
		,	EventProductCount	INT
		,	BetCount			BIGINT
	);

	CREATE CLUSTERED INDEX TPDS_TraderId ON #tmpTraderPerformanceDetailBySport (TraderId);

	CREATE INDEX TPDS_TraderId_SportId ON #tmpTraderPerformanceDetailBySport (
			TraderId
		,	SportId
	);

	IF OBJECT_ID('tempdb..#tmpTraderPerformanceRegion') IS NOT NULL
	BEGIN
		DROP TABLE #tmpTraderPerformanceRegion
	END;

	CREATE TABLE #tmpTraderPerformanceRegion (
			TraderId			INT
		,	RegionCount			INT
	);

	CREATE CLUSTERED INDEX TPR_TraderId ON #tmpTraderPerformanceRegion (TraderId);

	IF OBJECT_ID('tempdb..#tmpTraderPointDeduction') IS NOT NULL
	BEGIN
		DROP TABLE #tmpTraderPointDeduction
	END;

	CREATE TABLE #tmpTraderPointDeduction (
			TraderId			INT
		,	PointDeduction		MONEY
	);

	CREATE CLUSTERED INDEX TPD_TraderId ON #tmpTraderPointDeduction (TraderId);

	IF @ReportType = 1
	BEGIN
		INSERT INTO #tmpTraderPerformanceDetail (
				TraderId
			,	SportId
			,	LeagueId
			,	BettypeId
			,	Turnover
			,	WinLoss
			,	EventProductCount
			,	Target
			,	JuiceTurnover
			,	JuiceWinLoss
			,	BetCount
		)
		SELECT	tp.TraderId
			,	tp.SportId
			,	tp.LeagueId
			,	tp.BettypeId
			,	SUM(tp.StakeMYR) AS Turnover
			,	SUM(tp.Winloss - tp.Comm) AS Winloss
			,	SUM(tp.MatchCount) AS EventProductCount
			,	tp.Target
			,	SUM(tp.StakeMYRJuice) AS JuiceTurnover
			,	SUM(tp.Juice) AS JuiceWinloss
			,	SUM(tp.BetCount)
		FROM dbo.OSSummaryByTrader_Daily tp WITH (NOLOCK)
			JOIN dbo.OSTrader t WITH (NOLOCK) ON t.TraderId = tp.TraderId
		WHERE (ISNULL(@TraderName, '') = ''
				OR t.TraderName LIKE '%' + @TraderName + '%')
			AND tp.EventDate BETWEEN @FromDate AND @ToDate
			AND (tp.SportId = @SportId OR @SportId = - 1)
			AND tp.BettypeId IN (1,2,3,7,8,12)
			AND (@LiveType = -1 OR tp.IsLive = @LiveType)
		GROUP BY tp.TraderId
			,	tp.SportId
			,	tp.LeagueId
			,	tp.BettypeId
			,	tp.Target;
	END
	ELSE IF @ReportType = 2
	BEGIN
		INSERT INTO #tmpTraderPerformanceDetail (
				TraderId
			,	SportId
			,	LeagueId
			,	BettypeId
			,	Turnover
			,	WinLoss
			,	EventProductCount
			,	Target
			,	JuiceTurnover
			,	JuiceWinLoss
			,	BetCount
		)
		SELECT	tp.TraderId
			,	tp.SportId
			,	tp.LeagueId
			,	tp.BettypeId
			,	SUM(tp.StakeMYR) AS Turnover
			,	SUM(tp.Winloss - tp.Comm) AS Winloss
			,	SUM(tp.MatchCount) AS EventProductCount
			,	tp.Target
			,	SUM(tp.StakeMYRJuice) AS JuiceTurnover
			,	SUM(tp.Juice) AS JuiceWinloss
			,	SUM(tp.BetCount)
		FROM dbo.OSSummaryByTrader_Monthly tp WITH (NOLOCK)
			JOIN dbo.OSTrader t WITH (NOLOCK) ON t.TraderId = tp.TraderId
		WHERE (ISNULL(@TraderName, '') = ''
				OR t.TraderName LIKE '%' + @TraderName + '%')
			AND tp.EventDate BETWEEN @FromDate AND @ToDate
			AND (tp.SportId = @SportId OR @SportId = - 1)
			AND tp.BettypeId IN (1,2,3,7,8,12)
			AND (@LiveType = -1 OR tp.IsLive = @LiveType)
		GROUP BY tp.TraderId
			,	tp.SportId
			,	tp.LeagueId
			,	tp.BettypeId
			,	tp.Target;
	END;

	INSERT INTO #tmpTraderPerformanceDetailByBettype (
			TraderId
		,	SportId
		,	BettypeId
		,	Turnover
		,	WinLoss
		,	JuiceTurnover
		,	JuiceWinLoss
		,	Point
		,	EventProductCount
		,	BetCount
	)
	SELECT	tp.TraderId
		,	tp.SportId
		,	tp.BettypeId
		,	tp.Turnover
		,	tp.Winloss
		,	tp.JuiceTurnover
		,	tp.JuiceWinloss
		,	tp.Turnover * 100 / SUM(tp.Turnover) OVER (PARTITION BY tp.TraderId, tp.SportId) 
			* (@FloorMark / 100 + (
				(
					CASE 
						WHEN FLOOR(((tp.Winloss * 100 / tp.Turnover) - tp.Target) / @IncrementValue) >= @IncrementTimes
							THEN @IncrementTimes
						WHEN FLOOR(((tp.Winloss * 100 / tp.Turnover) - tp.Target) / @IncrementValue) <= - @IncrementTimes
							THEN - @IncrementTimes
						ELSE FLOOR(((tp.Winloss * 100 / tp.Turnover) - tp.Target) / @IncrementValue)
						END
					) + 1
				) / @IncrementTimes
			) AS Point
		,	tp.EventProductCount
		,	tp.BetCount
	FROM #tmpTraderPerformanceDetail tp WITH (NOLOCK);

	INSERT INTO #tmpTraderPerformanceDetailBySport (
			TraderId
		,	SportId
		,	Turnover
		,	WinLoss
		,	JuiceTurnover
		,	JuiceWinloss
		,	Point
		,	EventProductCount
		,	BetCount
	)
	SELECT	tp.TraderId
		,	tp.SportId
		,	tp.Turnover
		,	tp.Winloss AS Winloss
		,	tp.JuiceTurnover
		,	tp.JuiceWinloss
		,	tp.Point * ByTraderAndSport.Turnover / ByTrader.Turnover AS Point
		,	tp.EventProductCount AS EventProductCount		
		,	tp.BetCount
	FROM #tmpTraderPerformanceDetailByBettype tp WITH (NOLOCK)
	CROSS APPLY (
		SELECT SUM(_tp.Turnover)
		FROM #tmpTraderPerformanceDetailByBettype _tp WITH(NOLOCK)
		WHERE _tp.TraderId = tp.TraderId
			AND _tp.SportId = tp.SportId
		) ByTraderAndSport(Turnover)
	CROSS APPLY (
		SELECT SUM(_tp.Turnover)
		FROM #tmpTraderPerformanceDetailByBettype _tp WITH(NOLOCK)
		WHERE _tp.TraderId = tp.TraderId
		) ByTrader(Turnover);
		
	INSERT INTO #tmpTraderPointDeduction (
			TraderId
		,	PointDeduction
	)
	SELECT	d.TraderId
		,	SUM(COALESCE(d.DeductionValue, 0)) AS PointDeduction
	FROM dbo.OSTraderPointDeduction d WITH (NOLOCK)
	WHERE d.TraderId IN (
			SELECT DISTINCT TraderId
			FROM #tmpTraderPerformanceDetailByBettype WITH(NOLOCK)
			)
		AND (
			d.DeductionDate IS NULL
			OR d.DeductionDate BETWEEN @FromDate AND @ToDate
			)
	GROUP BY d.TraderId;

	INSERT INTO #tmpTraderPerformanceRegion (
			TraderId
		,	RegionCount
	)
	SELECT DISTINCT tpd.TraderId
		,	COUNT(DISTINCT CASE 
				WHEN lr.RegionId IS NULL
					THEN - 1
				ELSE lr.RegionId
				END)
	FROM #tmpTraderPerformanceDetail tpd WITH (NOLOCK)
		LEFT JOIN dbo.OSLeagueRegion lr WITH (NOLOCK) ON lr.LeagueId = tpd.LeagueId
	GROUP BY tpd.TraderId;

	SELECT	td.TraderId
		,	tr.TraderName
		,	te.TeamName
		,	gr.GradeName
		,	tpr.RegionCount
		,	CASE 
			WHEN SUM(td.Point) > 100
				THEN 100
			ELSE SUM(td.Point)
			END - COALESCE(d.PointDeduction, 0) AS TotalPoint
		,	d.PointDeduction
		,	SUM(td.JuiceTurnover) AS JuiceTurnover
		,	SUM(td.JuiceWinLoss) AS JuiceWinLoss
		,	SUM(td.Turnover) AS Turnover
		,	SUM(td.WinLoss) AS WinLoss
		,	COUNT(DISTINCT td.SportId) AS SportCount
		,	SUM(td.EventProductCount) AS EventProductCount
		,	SUM(td.BetCount) AS BetCount
	FROM #tmpTraderPerformanceDetailBySport td WITH (NOLOCK)
		INNER JOIN dbo.OSTrader tr WITH (NOLOCK) ON tr.TraderId = td.TraderId
		INNER JOIN #tmpTraderPerformanceRegion tpr WITH (NOLOCK) ON tpr.TraderId = td.TraderId
		LEFT JOIN dbo.OSTeam te WITH (NOLOCK) ON te.TeamId = tr.TeamId
		LEFT JOIN dbo.OSGrade gr WITH (NOLOCK) ON gr.GradeId = tr.GradeId
		LEFT JOIN #tmpTraderPointDeduction d WITH (NOLOCK) ON d.TraderId = td.TraderId
	GROUP BY td.TraderId
		,	tr.TraderName
		,	te.TeamName
		,	gr.GradeName
		,	d.PointDeduction
		,	tpr.RegionCount
	ORDER BY tr.TraderName ASC;

	DROP TABLE #tmpTraderPointDeduction;
	DROP TABLE #tmpTraderPerformanceDetailByBettype;
	DROP TABLE #tmpTraderPerformanceDetailBySport;
	DROP TABLE #tmpTraderPerformanceDetail;
	DROP TABLE #tmpTraderPerformanceRegion;
END;

GO
/*<info serverAlias="DBTGRS-bodb_TGRS" executers="bodbTGRSNet" isFunction="0" isNested="0"></info>*/