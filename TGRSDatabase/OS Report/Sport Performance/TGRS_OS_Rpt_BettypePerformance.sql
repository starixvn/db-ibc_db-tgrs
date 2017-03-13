
SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

/****** Object:  Stored Procedure dbo.TGRS_OS_Rpt_BettypePerformance    Script Date: 3/7/2017 3:10:48 PM ******/

CREATE PROCEDURE [dbo].[TGRS_OS_Rpt_BettypePerformance]  
  @ReportType TINYINT = 1
 ,@SportId INT
 ,@LeagueId INT
 ,@FromDate DATE  
 ,@ToDate DATE  
  
/*  
Created: 20160810@John.Ngo  
Task : Get OS Bettypes Performance  
DB:  DBTGRS.bodb_TGRS  
  
Revisions:  

Ex: @ReportType = 1: Daily, 2: Monthly

*/  
  
AS  
BEGIN  
 SET NOCOUNT ON
	DECLARE @FMark DECIMAL(18, 2)
	
	SELECT TOP 1 @FMark = ParamValue
	FROM dbo.OSParameter WITH (NOLOCK)
	WHERE ParamId = 7 -- FloorMark value
	
	IF OBJECT_ID('tempdb..#tmpOSBettypePerformance') IS NOT NULL DROP TABLE #tmpOSBettypePerformance;

	 CREATE TABLE #tmpOSBettypePerformance (
	   BettypeId   INT
	  ,Turnover   MONEY
	  ,VWinLoss MONEY
	  ,Target   DECIMAL(18,2)
	  );

IF @ReportType = 1
   BEGIN 
   INSERT INTO #tmpOSBettypePerformance (BettypeId,Turnover,VWinLoss,Target)  
    SELECT td.BettypeId
     ,SUM(td.Turnover) AS Turnover  
     ,SUM(td.WinLoss - td.Comm) AS 'VWinLoss'
     ,td.Target 
    FROM dbo.OSSummaryByTrader_Daily td WITH (NOLOCK)  
    WHERE td.EventDate BETWEEN @FromDate AND @ToDate
    AND td.SportId = @SportId AND LeagueId = @LeagueId
    GROUP BY td.BettypeId,td.Target
   END  
ELSE IF @ReportType = 2
   BEGIN
   INSERT INTO #tmpOSBettypePerformance (BettypeId,Turnover,VWinLoss,Target)  
    SELECT td.BettypeId
     ,SUM(td.Turnover) AS Turnover  
     ,SUM(td.WinLoss - td.Comm) AS 'VWinLoss'
     ,td.Target
    FROM dbo.OSSummaryByTrader_Monthly td WITH (NOLOCK)  
    WHERE td.EventDate BETWEEN @FromDate AND @ToDate  
    AND td.SportId = @SportId AND LeagueId = @LeagueId
    GROUP BY td.BettypeId, td.Target
  END  

  DECLARE @TotalTurnover MONEY
  SELECT  @TotalTurnover = SUM(Turnover) FROM #tmpOSBettypePerformance
  --Select
	SELECT BettypeId
		,typenamee AS BettypeName
		,Sum(Turnover) AS Turnover
		,SUM(VWinLoss) AS 'VWinLoss'
		,(SUM(VWinLoss) * 100 / SUM(Turnover)) AS 'VMargin'
		,(SUM(Turnover) * 100 / @TotalTurnover) AS 'AverageVTurnover'
		,(SUM(VWinLoss) * (@FMark) / SUM(Turnover)) AS 'PointMargin'
	FROM #tmpOSBettypePerformance t WITH (NOLOCK)
		INNER JOIN bodb02.dbo.bettype bt WITH(NOLOCK) ON t.BettypeId = bt.typeid
	GROUP by BettypeId, typenamee
	DROP TABLE #tmpOSBettypePerformance	
END  
  
/*   
GO  
GRANT EXECUTE ON [dbo].[TGRS_OS_Rpt_BettypePerformance] TO [bodbTGRSNet]  
GO  
GRANT VIEW DEFINITION ON [dbo].[TGRS_OS_Rpt_BettypePerformance] TO [bodbTGRSNet]  
GO  
*/  

GO

SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO


GO 
 GRANT EXECUTE ON [dbo].[TGRS_OS_Rpt_BettypePerformance] TO [bodbTGRSNet]
GO 
 GRANT VIEW DEFINITION ON [dbo].[TGRS_OS_Rpt_BettypePerformance] TO [bodbTGRSNet]
GO 
