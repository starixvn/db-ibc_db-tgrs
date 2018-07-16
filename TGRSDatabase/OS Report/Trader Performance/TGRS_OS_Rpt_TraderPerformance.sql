
SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

/****** Object:  Stored Procedure dbo.TGRS_OS_Rpt_TraderPerformance    Script Date: 3/7/2017 3:10:48 PM ******/

ALTER PROCEDURE [dbo].[TGRS_OS_Rpt_TraderPerformance]
		@ReportType			TINYINT = 1
	,	@TraderName			NVARCHAR(50) = NULL
	,	@FromDate			DATE = '2016-01-01'
	,	@ToDate				DATE = '2017-12-31'
	,	@SportId			INT = - 1
AS
/*
	Created: 20160810@Aaron
	Task : Get OS Trader Performance
	DB:  DBTGRS.bodb_TGRS

	Revisions:
		- 20170307@Aaron:	Added @ReportType and calculate the score by league
		- 20170316@Aaron:	Added @SportId
		- 20170320@Aaron:	Return RegionCount
		- 20180713@Long:	Support Match Details info [Redmine ID: 94315] & rearrange sql

	Params Explaination:
		- @ReportType: 1 report by Day, 2 report by Month
*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @IncrementTimes			DECIMAL(18, 2)
		,	@IncrementValue			DECIMAL(18, 2)
		,	@FloorMark				DECIMAL(18, 2);

	SELECT @IncrementTimes = ParamValue
	FROM [bodb_TGRS].[dbo].[OSParameter] WITH (NOLOCK)
	WHERE ParamId = 3;

	SELECT @IncrementValue = ParamValue
	FROM [bodb_TGRS].[dbo].[OSParameter] WITH (NOLOCK)
	WHERE ParamId = 5;

	SELECT @FloorMark = ParamValue
	FROM [bodb_TGRS].[dbo].[OSParameter] WITH (NOLOCK)
	WHERE ParamId = 7;

	IF @SportId IS NULL
	BEGIN
		SET @SportId = - 1;
	END;

	IF OBJECT_ID('tempdb..#tmpTraderPerformanceDetail') IS NOT NULL
	BEGIN
		DROP TABLE #tmpTraderPerformanceDetail
	END

	CREATE TABLE #tmpTraderPerformanceDetail (
			TraderId			INT
		,	SportId				INT
		,	LeagueId			INT
		,	BettypeId			INT
		,	Turnover			MONEY
		,	WinLoss				MONEY
		,	EventProductCount	INT
		,	Target				DECIMAL(18,4)
	);

	CREATE CLUSTERED INDEX	#CIX_tmpTraderPerformanceDetailIdx ON #tmpTraderPerformanceDetail (
			TraderId			ASC
		,	SportId				ASC
	);

	IF OBJECT_ID('tempdb..#tmpTraderPerformanceDetailByBettype') IS NOT NULL
	BEGIN
		DROP TABLE #tmpTraderPerformanceDetailByBettype
	END

	CREATE TABLE #tmpTraderPerformanceDetailByBettype (
			TraderId			INT
		,	SportId				INT
		,	BettypeId			INT
		,	Turnover			MONEY
		,	WinLoss				MONEY
		,	Point				MONEY
		,	EventProductCount	INT
	);

	CREATE CLUSTERED INDEX	#CIX_tmpTraderPerformanceDetailByBettypeIdx ON #tmpTraderPerformanceDetailByBettype (
			TraderId			ASC
		,	SportId				ASC
	);

	IF OBJECT_ID('tempdb..#tmpTraderPerformanceDetailBySport') IS NOT NULL
	BEGIN
		DROP TABLE #tmpTraderPerformanceDetailBySport
	END

	CREATE TABLE #tmpTraderPerformanceDetailBySport (
			TraderId			INT
		,	SportId				INT
		,	Turnover			MONEY
		,	WinLoss				MONEY
		,	Point				MONEY
		,	EventProductCount	INT
	);

	CREATE CLUSTERED INDEX	#CIX_tmpTraderPerformanceDetailBySportIdx ON #tmpTraderPerformanceDetailBySport (
			TraderId			ASC
		,	SportId				ASC
	);

	IF OBJECT_ID('tempdb..#tmpTraderPerformanceRegion') IS NOT NULL
	BEGIN
		DROP TABLE #tmpTraderPerformanceRegion
	END

	CREATE TABLE #tmpTraderPerformanceRegion (
			TraderId			INT
		,	RegionCount			INT
	);

	CREATE CLUSTERED INDEX	#CIX_tmpTraderPerformanceRegionIdx ON #tmpTraderPerformanceRegion (
			TraderId
	);

	IF OBJECT_ID('tempdb..#tmpTraderPointDeduction') IS NOT NULL
	BEGIN
		DROP TABLE #tmpTraderPointDeduction
	END
	CREATE TABLE #tmpTraderPointDeduction (
			TraderId			INT
		,	PointDeduction		MONEY
	);

	CREATE CLUSTERED INDEX	#CIX_tmpTraderPointDeductionIdx ON #tmpTraderPointDeduction (
			TraderId			ASC
	);

	IF OBJECT_ID('tempdb..#tmpTraderMatchCount') IS NOT NULL
	BEGIN
		DROP TABLE #tmpTraderMatchCount
	END

	CREATE TABLE #tmpTraderMatchCount (
			TraderId			INT
		,	MatchCount			INT
	);

	CREATE CLUSTERED INDEX	#CIX_tmpTraderMatchCountIdx ON #tmpTraderMatchCount (
			TraderId			ASC
	);
	
	-- START --
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
		)
		SELECT	tp.TraderId
			,	tp.SportId
			,	tp.LeagueId
			,	tp.BettypeId
			,	SUM(tp.Turnover) AS Turnover
			,	SUM(tp.Winloss - tp.Comm) AS Winloss
			,	SUM(tp.MatchCount) AS EventProductCount
			,	tp.Target
		FROM dbo.OSSummaryByTrader_Daily tp WITH (NOLOCK)
			JOIN dbo.OSTrader t WITH (NOLOCK) ON t.TraderId = tp.TraderId
		WHERE (
				ISNULL(@TraderName, '') = ''
				OR t.TraderName LIKE '%' + @TraderName + '%'
			)
			AND tp.EventDate BETWEEN @FromDate AND @ToDate
			AND (
				tp.SportId = @SportId
				OR @SportId = - 1
			)
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
		)
		SELECT	tp.TraderId
			,	tp.SportId
			,	tp.LeagueId
			,	tp.BettypeId
			,	SUM(tp.Turnover) AS Turnover
			,	SUM(tp.Winloss - tp.Comm) AS Winloss
			,	SUM(tp.MatchCount) AS EventProductCount
			,	tp.Target
		FROM dbo.OSSummaryByTrader_Monthly tp WITH (NOLOCK)
			JOIN dbo.OSTrader t WITH (NOLOCK) ON t.TraderId = tp.TraderId
		WHERE (
				ISNULL(@TraderName, '') = ''
				OR t.TraderName LIKE '%' + @TraderName + '%'
			)
			AND tp.EventDate BETWEEN @FromDate AND @ToDate
			AND (
				tp.SportId = @SportId
				OR @SportId = - 1
			)
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
		,	Point
		,	EventProductCount
	)
	SELECT	tp.TraderId
		,	tp.SportId
		,	tp.BettypeId
		,	tp.Turnover
		,	tp.Winloss AS Winloss
		,	tp.Turnover * 100 / SUM(tp.Turnover) OVER (
			PARTITION BY tp.TraderId
			,tp.SportId
			) * (
			@FloorMark / 100 + (
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
	FROM #tmpTraderPerformanceDetail tp WITH (NOLOCK);

	INSERT INTO #tmpTraderPerformanceDetailBySport (
			TraderId
		,	SportId
		,	Turnover
		,	WinLoss
		,	Point
		,	EventProductCount
	)
	SELECT	tp.TraderId
		,	tp.SportId
		,	tp.Turnover
		,	tp.Winloss AS Winloss
		,	tp.Point * ByTraderAndSport.Turnover / ByTrader.Turnover AS Point
		,	tp.EventProductCount AS EventProductCount
	FROM #tmpTraderPerformanceDetailByBettype tp WITH (NOLOCK)
	CROSS APPLY (
		SELECT SUM(_tp.Turnover)
		FROM #tmpTraderPerformanceDetailByBettype _tp
		WHERE _tp.TraderId = tp.TraderId
			AND _tp.SportId = tp.SportId
		) ByTraderAndSport(Turnover)
	CROSS APPLY (
		SELECT SUM(_tp.Turnover)
		FROM #tmpTraderPerformanceDetailByBettype _tp
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
			FROM #tmpTraderPerformanceDetailByBettype WITH (NOLOCK)
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
		,COUNT(DISTINCT CASE 
				WHEN lr.RegionId IS NULL
					THEN - 1
				ELSE lr.RegionId
				END)
	FROM #tmpTraderPerformanceDetail tpd WITH (NOLOCK)
		LEFT JOIN dbo.OSLeagueRegion lr WITH (NOLOCK) ON lr.LeagueId = tpd.LeagueId
	GROUP BY tpd.TraderId;

	INSERT INTO #tmpTraderMatchCount (
			TraderId
		,	MatchCount
	)
	SELECT	ostp.TraderId
		,	COUNT(DISTINCT ostp.MatchId) AS MatchCount
	FROM dbo.OSDataTGRS ostp WITH(NOLOCK)
	WHERE ostp.EventDate BETWEEN @FromDate AND @ToDate
	GROUP BY ostp.TraderId;

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
		,	(SUM(td.WinLoss) * 100 / SUM(td.Turnover)) AS Margin
		,	SUM(td.Turnover) AS Turnover
		,	SUM(td.WinLoss) AS WinLoss
		,	COUNT(DISTINCT td.SportId) AS SportCount
		,	SUM(td.EventProductCount) AS EventProductCount
		,	SUM(tmc.MatchCount) AS MatchCount
	FROM #tmpTraderPerformanceDetailBySport td WITH (NOLOCK)
		INNER JOIN dbo.OSTrader tr WITH (NOLOCK) ON tr.TraderId = td.TraderId
		INNER JOIN #tmpTraderMatchCount tmc WITH(NOLOCK) ON tmc.TraderId = td.TraderId
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
	
	DROP TABLE #tmpTraderMatchCount;
	DROP TABLE #tmpTraderPointDeduction;
	DROP TABLE #tmpTraderPerformanceDetailByBettype;
	DROP TABLE #tmpTraderPerformanceDetailBySport;
	DROP TABLE #tmpTraderPerformanceDetail;
	DROP TABLE #tmpTraderPerformanceRegion;
END;

/* 
GO
GRANT EXECUTE ON [dbo].[TGRS_OS_Rpt_TraderPerformance] TO [bodbTGRSNet]
GO
GRANT VIEW DEFINITION ON [dbo].[TGRS_OS_Rpt_TraderPerformance] TO [bodbTGRSNet]
GO
*/

GO
