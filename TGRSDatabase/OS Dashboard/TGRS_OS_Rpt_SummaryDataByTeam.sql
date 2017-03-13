
SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

/****** Object:  Stored Procedure dbo.TGRS_OS_Rpt_SummaryDataByTeam    Script Date: 3/7/2017 3:10:48 PM ******/

CREATE PROCEDURE [dbo].[TGRS_OS_Rpt_SummaryDataByTeam]
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
	EXEC TGRS_OS_Rpt_SummaryDataByTeam @FromDate = '2016-01-01', @ToDate = '2017-03-23'
  
*/
BEGIN
	SET NOCOUNT ON;
		
	SET @FromDate = DATEADD(m, DATEDIFF(m, 0, @FromDate), 0);
	SET @ToDate = DATEADD(m, DATEDIFF(m, 0, @ToDate), 0);

	SELECT ISNULL(SUM(tp.Turnover), 0) AS Turnover
		,ISNULL(SUM(tp.WinLoss), 0) - ISNULL(SUM(tp.Comm), 0) AS WinLoss
		,t.TeamName
	FROM dbo.OSSummaryByTrader_Monthly tp WITH (NOLOCK)
	INNER JOIN dbo.OSTrader td WITH (NOLOCK) ON td.TraderId = tp.TraderId
	LEFT JOIN dbo.OSTeam t WITH (NOLOCK) ON t.TeamId = td.TeamId
	WHERE tp.EventDate BETWEEN @FromDate AND @ToDate
	GROUP BY t.TeamName;
END
/*   
GO  
GRANT EXECUTE ON [dbo].[TGRS_OS_Rpt_SummaryDataByTeam] TO [bodbTGRSNet]  
GO  
GRANT VIEW DEFINITION ON [dbo].[TGRS_OS_Rpt_SummaryDataByTeam] TO [bodbTGRSNet]  
GO  
*/
GO

SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO


GO 
 GRANT EXECUTE ON [dbo].[TGRS_OS_Rpt_SummaryDataByTeam] TO [bodbTGRSNet]
GO 
 GRANT VIEW DEFINITION ON [dbo].[TGRS_OS_Rpt_SummaryDataByTeam] TO [bodbTGRSNet]
GO 
