
SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

ALTER PROCEDURE [dbo].[TGRS_OS_Rpt_TraderReport_SportPerformance]
		@ReportType			TINYINT = 1
	,	@TraderId			INT
	,	@FromDate			DATE
	,	@ToDate				DATE
AS
/*
	Created: 20180719@Long
	Task : Get Trader's Report - Sports Performance
	DB:  DBTGRS.bodb_TGRS

	Revisions:

	Ex: @SportId = -1: Show all
		@ReportType = 1: Daily; 2: Monthly
*/


BEGIN
	SET NOCOUNT ON; 

	-- INIT
	DECLARE @FMark			DECIMAL(18, 2)
		,	@TotalTurnover	MONEY;  
  
	SELECT TOP(1) @FMark = ParamValue  
	FROM dbo.OSParameter WITH (NOLOCK)  
	WHERE ParamId = 7; -- FloorMark value 
   
	IF OBJECT_ID('tempdb..#tmpOSSportPerformance') IS NOT NULL 
	BEGIN 
		DROP TABLE #tmpOSSportPerformance;
	END;
  
	CREATE TABLE #tmpOSSportPerformance (  
			SportId			INT   
		,	LeagueId		INT  
		,	Turnover		MONEY  
		,	VWinLoss		MONEY  
		,	Target			DECIMAL(18,2)  
	);  
     
	CREATE CLUSTERED INDEX	#CIX_tmpOSSportPerformanceIdx ON #tmpOSSportPerformance (
			SportId			ASC
	);

	CREATE NONCLUSTERED INDEX	#NCIX_tmpOSSportPerformanceIdx ON #tmpOSSportPerformance (
			LeagueId		ASC
	);

	IF OBJECT_ID('tempdb..#tmpSportPerformanceRegion') IS NOT NULL  
	BEGIN  
		DROP TABLE #tmpSportPerformanceRegion;  
	END;
  
	CREATE TABLE #tmpSportPerformanceRegion (  
			SportId			INT  
		,	RegionCount		INT  
	); 

	CREATE CLUSTERED INDEX	#CIX_tmpSportPerformanceRegionIdx ON #tmpSportPerformanceRegion (
			SportId		ASC
	);
   
	-- START
	IF @ReportType = 1  
	BEGIN  
		INSERT INTO #tmpOSSportPerformance (SportId, LeagueId, Turnover, VWinLoss, Target)  
		SELECT	td.SportId  
			,	td.LeagueId  
			,	SUM(td.Turnover) AS Turnover  
			,	SUM(td.WinLoss - td.Comm) AS 'VWinLoss'  
			,	td.Target  
		FROM dbo.OSSummaryByTrader_Daily AS td WITH (NOLOCK)  
		WHERE td.TraderId = @TraderId
			AND td.EventDate BETWEEN @FromDate AND @ToDate
		GROUP BY td.SportId, td.LeagueId,td.Target;     
	END  
	ELSE IF @ReportType = 2  
	BEGIN  
		INSERT INTO #tmpOSSportPerformance (SportId, LeagueId, Turnover, VWinLoss, Target)  
		SELECT	td.SportId  
			,	td.LeagueId  
			,	SUM(td.Turnover) AS Turnover  
			,	SUM(td.WinLoss - td.Comm) AS 'VWinLoss'  
			,	td.Target  
		FROM dbo.OSSummaryByTrader_Monthly AS td WITH (NOLOCK)  
		WHERE td.TraderId = @TraderId
			AND td.EventDate BETWEEN @FromDate AND @ToDate
		GROUP BY td.SportId
			,	td.LeagueId
			,	td.Target;
	END;    
   
	SELECT @TotalTurnover = SUM(td.Turnover)  
	FROM #tmpOSSportPerformance AS td WITH (NOLOCK);
   
	INSERT INTO #tmpSportPerformanceRegion (  
			SportId  
		,	RegionCount  
	)
	SELECT DISTINCT tpd.SportId  
		,	COUNT(DISTINCT CASE   
						WHEN lr.RegionId IS NULL  
						THEN - 1  
						ELSE lr.RegionId  
						END
					)  
	FROM #tmpOSSportPerformance AS tpd WITH (NOLOCK)  
		LEFT JOIN dbo.OSLeagueRegion AS lr WITH (NOLOCK) ON lr.LeagueId = tpd.LeagueId  
	GROUP BY tpd.SportId;  
  
	SELECT	t.SportId  
		,	s.SportName  
		,	COUNT(DISTINCT t.LeagueId) AS 'NoOfLeague'  
		,	SUM(t.Turnover) AS Turnover  
		,	(SUM(t.VWinLoss) * 100 / SUM(t.Turnover)) AS 'VMargin'  
		,	(SUM(t.Turnover) * 100 / @TotalTurnover) AS 'AverageVTurnover'  
		,	(SUM(t.VWinLoss) * (@FMark) / SUM(t.Turnover)) AS 'PointMargin'  
		,	tpr.RegionCount  
	FROM #tmpOSSportPerformance AS t WITH(NOLOCK)  
		INNER JOIN bodb02.dbo.Sports AS s WITH(NOLOCK) ON t.SportId = s.SportType  
		INNER JOIN #tmpSportPerformanceRegion AS tpr WITH(NOLOCK) ON tpr.SportId = t.SportId  
	GROUP BY t.SportId
		,	s.SportName
		,	tpr.RegionCount;
  
	DROP TABLE #tmpOSSportPerformance;
	DROP TABLE #tmpSportPerformanceRegion;
END;

/* 
GO
GRANT EXECUTE ON [dbo].[TGRS_OS_Rpt_TraderReport_SportPerformance] TO [bodbTGRSNet]
GO
GRANT VIEW DEFINITION ON [dbo].[TGRS_OS_Rpt_TraderReport_SportPerformance] TO [bodbTGRSNet]
GO
*/
