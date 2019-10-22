
SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

/****** Object:  Stored Procedure dbo.TGRS_OS_Rpt_SummaryDataByRegion    Script Date: 3/7/2017 3:10:48 PM ******/

CREATE PROCEDURE [dbo].[TGRS_OS_Rpt_SummaryDataByRegion]
	 @FromDate DATE
	,@ToDate DATE
AS
/*  
 Created:	20170307@Aaron
 Task :		Summary report - Get All data from a range of months
 DB:		DBTGRS.bodb_TGRS
 Original:  
  
 Revisions:      
   			
 Param's Explanation:

 Exam: 
	EXEC TGRS_OS_Rpt_SummaryDataByRegion @FromDate = '2016-01-01', @ToDate = '2017-02-23'
  
*/
BEGIN
	SET NOCOUNT ON;
		
	SET @FromDate = DATEADD(m, DATEDIFF(m, 0, @FromDate), 0);
	SET @ToDate = DATEADD(m, DATEDIFF(m, 0, @ToDate), 0);

	SELECT ISNULL(SUM(tp.Turnover), 0) AS Turnover
		,ISNULL(SUM(tp.WinLoss), 0) - ISNULL(SUM(tp.Comm), 0) AS WinLoss
		,r.RegionName
	FROM dbo.OSSummaryByTrader_Monthly tp WITH (NOLOCK)
	LEFT JOIN dbo.OSLeagueRegion lr WITH (NOLOCK) ON tp.LeagueId = lr.LeagueId
	LEFT JOIN dbo.OSRegion r WITH (NOLOCK) ON r.RegionId = lr.RegionId
	WHERE tp.EventDate BETWEEN @FromDate AND @ToDate
	GROUP BY r.RegionName;
END;