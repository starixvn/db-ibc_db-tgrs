/*<info serverAlias="DBTGRS-bodb_TGRS" executers="wsv_tgrs" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[TGRS_OS_Rpt_SportPerformance]
		@ReportType		TINYINT  = 1
	,	@SportId		INT		 = -1
	,	@FromDate		DATE
	,	@ToDate			DATE
	,	@LiveType		SMALLINT = 1
AS
/*
	Created: 20160810@John.Ngo
	Task : Get OS Sports Performance
	DB:  DBTGRS.bodb_TGRS
	Original:

	Revisions:
		- 20181030@Long: Adding Betcount column to OS's reports [Redmine ID: #101741]
		- 20200914@John.Ngo: Support Live/Nonlive for OSDataTGRS [Redmine ID: #140875]

	Param's Explanation (filtered by):
	Ex: SportId = -1: Show all
		- @ReportType = 1: Daily, 2: Monthly
		- @LiveType: -1 All; 0 Nonlive; 1 Live
*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @FMark			DECIMAL(18, 2)
		,	@TotalTurnover	MONEY;

	SELECT TOP 1 @FMark = ParamValue
	FROM dbo.OSParameter WITH (NOLOCK)
	WHERE ParamId = 7; -- FloorMark value
	
	IF OBJECT_ID('tempdb..#tmpOSSportPerformance') IS NOT NULL DROP TABLE #tmpOSSportPerformance;

	CREATE TABLE #tmpOSSportPerformance (
			SportId		INT 
		,	LeagueId	INT
		,	Turnover	MONEY
		,	VWinLoss	MONEY
		,	Target		DECIMAL(18,2)
		,	BetCount	BIGINT
	);
	  
	CREATE CLUSTERED INDEX	#CIX_tmpOSSportPerformancee_SportId ON #tmpOSSportPerformance (
		SportId		ASC
	);

	IF OBJECT_ID('tempdb..#tmpSportPerformanceRegion') IS NOT NULL
	BEGIN
		DROP TABLE #tmpSportPerformanceRegion
	END;

	CREATE TABLE #tmpSportPerformanceRegion (
			SportId INT
		,	RegionCount INT
	);
	
	CREATE CLUSTERED INDEX	#CIX_SportPerformanceRegion_SportId ON #tmpSportPerformanceRegion (
		SportId		ASC
	);

	IF @ReportType = 1
	BEGIN
		INSERT INTO #tmpOSSportPerformance (SportId,LeagueId,Turnover,VWinLoss,Target,BetCount)
		SELECT	td.SportId
			,	td.LeagueId
			,	SUM(td.Turnover) AS Turnover
			,	SUM(td.WinLoss - td.Comm) AS 'VWinLoss'
			,	td.Target
			,	SUM(td.BetCount)
		FROM dbo.OSSummaryByTrader_Daily td WITH (NOLOCK)
		WHERE td.EventDate BETWEEN @FromDate AND @ToDate 
			AND (@SportId = -1 OR @SportId = td.SportId)
			AND (@LiveType = -1 OR td.IsLive = @LiveType)
		GROUP BY td.SportId, td.LeagueId, td.Target;			
	END;
	ELSE IF @ReportType = 2
	BEGIN
		INSERT INTO #tmpOSSportPerformance (SportId,LeagueId,Turnover,VWinLoss,Target,BetCount)
		SELECT	td.SportId
			,	td.LeagueId
			,	SUM(td.Turnover) AS Turnover
			,	SUM(td.WinLoss - td.Comm) AS 'VWinLoss'
			,	td.Target
			,	SUM(td.BetCount)
		FROM dbo.OSSummaryByTrader_Monthly td WITH (NOLOCK)
		WHERE td.EventDate BETWEEN @FromDate AND @ToDate 
			AND (@SportId = -1 OR @SportId = td.SportId)
			AND (@LiveType = -1 OR td.IsLive = @LiveType)
		GROUP BY td.SportId, td.LeagueId, td.Target
	END;
	
	SELECT @TotalTurnover = SUM(Turnover)
	FROM dbo.OSSummaryByTrader_Daily td WITH (NOLOCK)
	WHERE td.EventDate BETWEEN @FromDate AND @ToDate
		AND (@LiveType = -1 OR td.IsLive = @LiveType);
	
	INSERT INTO #tmpSportPerformanceRegion (
			SportId
		,	RegionCount
	)
	SELECT DISTINCT tpd.SportId
		,	COUNT(DISTINCT CASE 
				WHEN lr.RegionId IS NULL
					THEN - 1
				ELSE lr.RegionId
				END)
	FROM #tmpOSSportPerformance tpd WITH (NOLOCK)
		LEFT JOIN dbo.OSLeagueRegion lr WITH (NOLOCK) ON lr.LeagueId = tpd.LeagueId
	GROUP BY tpd.SportId;

	-----Select
	SELECT	t.SportId
		,	s.SportName
		,	COUNT(DISTINCT LeagueId) AS 'NoOfLeague'
		,	SUM(Turnover) AS Turnover
		,	SUM(VWinLoss) AS 'VWinLoss'
		,	(SUM(VWinLoss) * 100 / SUM(Turnover)) AS 'VMargin'
		,	(SUM(Turnover) * 100 / @TotalTurnover) AS 'AverageVTurnover'
		,	(SUM(VWinLoss) * (@FMark) / SUM(Turnover)) AS 'PointMargin'
		,	tpr.RegionCount
		,	SUM(t.BetCount) AS BetCount
	FROM #tmpOSSportPerformance t WITH(NOLOCK)
		INNER JOIN bodb02.dbo.Sports s WITH(NOLOCK) ON t.SportId = s.SportType
		INNER JOIN #tmpSportPerformanceRegion tpr WITH (NOLOCK) ON tpr.SportId = t.SportId
	GROUP BY t.SportId, s.SportName, tpr.RegionCount;

	DROP TABLE #tmpOSSportPerformance;
	DROP TABLE #tmpSportPerformanceRegion;
END;

GO
/*<info serverAlias="DBTGRS-bodb_TGRS" executers="bodbTGRSNet" isFunction="0" isNested="0"></info>*/