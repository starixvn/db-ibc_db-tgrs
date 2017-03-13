
SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

/****** Object:  Stored Procedure dbo.TGRS_OS_Rpt_SportPerformance    Script Date: 3/7/2017 3:10:48 PM ******/

CREATE PROCEDURE [dbo].[TGRS_OS_Rpt_SportPerformance]
	 @ReportType TINYINT = 1
	,@SportId INT = -1
	,@FromDate DATE
	,@ToDate DATE

/*
Created: 20160810@John.Ngo
Task : Get OS Sports Performance
DB:  DBTGRS.bodb_TGRS

Revisions:
Ex: SportId = -1: Show all
    @ReportType = 1: Daily, 2: Monthly
*/

AS
BEGIN
	SET NOCOUNT ON
	DECLARE @FMark DECIMAL(18, 2)

	SELECT TOP 1 @FMark = ParamValue
	FROM dbo.OSParameter WITH (NOLOCK)
	WHERE ParamId = 7 -- FloorMark value
	
	IF OBJECT_ID('tempdb..#tmpOSSportPerformance') IS NOT NULL DROP TABLE #tmpOSSportPerformance;

	 CREATE TABLE #tmpOSSportPerformance (
	   SportId    INT 
	  ,LeagueId   INT
	  ,Turnover   MONEY
	  ,VWinLoss MONEY
	  ,Target   DECIMAL(18,2)
	  );
	
	IF @ReportType = 1
		BEGIN
			INSERT INTO #tmpOSSportPerformance (SportId,LeagueId,Turnover,VWinLoss,Target)
				SELECT td.SportId
				,td.LeagueId
				,SUM(td.Turnover) AS Turnover
				,SUM(td.WinLoss - td.Comm) AS 'VWinLoss'
				,td.Target
			FROM dbo.OSSummaryByTrader_Daily td WITH (NOLOCK)
			WHERE td.EventDate BETWEEN @FromDate AND @ToDate AND (@SportId = -1 OR @SportId = td.SportId) 
			GROUP BY td.SportId, td.LeagueId,td.Target
			
		END
	ELSE IF @ReportType = 2
		BEGIN
			INSERT INTO #tmpOSSportPerformance (SportId,LeagueId,Turnover,VWinLoss,Target)
			SELECT td.SportId
				,td.LeagueId
				,SUM(td.Turnover) AS Turnover
				,SUM(td.WinLoss - td.Comm) AS 'VWinLoss'
				,td.Target
			FROM dbo.OSSummaryByTrader_Monthly td WITH (NOLOCK)
			WHERE td.EventDate BETWEEN @FromDate AND @ToDate AND (@SportId = -1 OR @SportId = td.SportId) 
			GROUP BY td.SportId, td.LeagueId,td.Target
		END

	DECLARE @TotalTurnover MONEY
	
	SELECT @TotalTurnover = SUM(Turnover)
	FROM dbo.OSSummaryByTrader_Daily td WITH (NOLOCK)
	WHERE td.EventDate BETWEEN @FromDate AND @ToDate 

	-----Select
	SELECT SportId
		,SportName
		,COUNT(DISTINCT LeagueId) AS 'NoOfLeague'
		,Sum(Turnover) AS Turnover
		,SUM(VWinLoss) AS 'VWinLoss'
		,(SUM(VWinLoss) * 100 / SUM(Turnover)) AS 'VMargin'
		,(SUM(Turnover) * 100 / @TotalTurnover) AS 'AverageVTurnover'
		,(SUM(VWinLoss) * (@FMark) / SUM(Turnover)) AS 'PointMargin'	
	FROM #tmpOSSportPerformance t
		INNER JOIN bodb02.dbo.Sports s WITH(NOLOCK) ON t.SportId = s.SportType
	GROUP BY SportId, SportName

	DROP TABLE #tmpOSSportPerformance
END

/* 
GO
GRANT EXECUTE ON [dbo].[TGRS_OS_Rpt_SportPerformance] TO [bodbTGRSNet]
GO
GRANT VIEW DEFINITION ON [dbo].[TGRS_OS_Rpt_SportPerformance] TO [bodbTGRSNet]
GO
*/


GO

SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO


GO 
 GRANT EXECUTE ON [dbo].[TGRS_OS_Rpt_SportPerformance] TO [bodbTGRSNet]
GO 
 GRANT VIEW DEFINITION ON [dbo].[TGRS_OS_Rpt_SportPerformance] TO [bodbTGRSNet]
GO 
