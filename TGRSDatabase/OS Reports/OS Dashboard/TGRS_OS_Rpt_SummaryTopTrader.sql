
SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

/****** Object:  Stored Procedure dbo.TGRS_OS_Rpt_SummaryTopTrader    Script Date: 3/7/2017 3:10:47 PM ******/

CREATE PROCEDURE [dbo].[TGRS_OS_Rpt_SummaryTopTrader] 
	 @Top TINYINT = 10
	,@IsBottom BIT = 0
	,@FromDate DATE
	,@ToDate DATE
AS
/*  
 Created:	20170224@Aaron
 Task :		Summary report - Top Traders
 DB:		DBTGRS.bodb_TGRS
 Original:  
  
 Revisions:      
   			
 Param's Explanation:
	@Top	= XX:  Rows to display

	@IsBottom = 0: List top traders
			  = 1: List bottom traders

 Exam: 
	EXEC TGRS_OS_Rpt_SummaryTopTrader @Top = 10, @IsBottom = 1, @FromDate = '2017-01-01', @ToDate = '2017-03-01'
  
*/
BEGIN
	SET NOCOUNT ON;
		
	SET @FromDate = DATEADD(m, DATEDIFF(m, 0, @FromDate), 0);
	SET @ToDate = DATEADD(m, DATEDIFF(m, 0, @ToDate), 0);

	IF ISNULL(@IsBottom, 0) = 0
	BEGIN
		SELECT TOP (@Top) td.TraderName AS Username
			,ISNULL(SUM(tp.Turnover), 0) AS Turnover
			,ISNULL(SUM(tp.WinLoss), 0) - ISNULL(SUM(tp.Comm), 0) AS WinLoss
		FROM dbo.OSSummaryByTrader_Monthly tp WITH (NOLOCK)
		INNER JOIN dbo.OSTrader td WITH (NOLOCK) ON td.TraderId = tp.TraderId
		WHERE tp.EventDate BETWEEN @FromDate AND @ToDate
		GROUP BY td.TraderName
		ORDER BY CASE 
				WHEN ISNULL(SUM(tp.Turnover), 0) <> 0
					THEN (ISNULL(SUM(tp.WinLoss), 0) - ISNULL(SUM(tp.Comm), 0)) / ISNULL(SUM(tp.Turnover), 0)
				ELSE NULL
				END DESC
	END
	ELSE
	BEGIN
		SELECT TOP (@Top) td.TraderName AS Username
			,ISNULL(SUM(tp.Turnover), 0) AS Turnover
			,ISNULL(SUM(tp.WinLoss), 0) - ISNULL(SUM(tp.Comm), 0) AS WinLoss
		FROM dbo.OSSummaryByTrader_Monthly tp WITH (NOLOCK)
		INNER JOIN dbo.OSTrader td WITH (NOLOCK) ON td.TraderId = tp.TraderId
		WHERE tp.EventDate BETWEEN @FromDate AND @ToDate
		GROUP BY td.TraderName
		ORDER BY CASE 
				WHEN ISNULL(SUM(tp.Turnover), 0) <> 0
					THEN (ISNULL(SUM(tp.WinLoss), 0) - ISNULL(SUM(tp.Comm), 0)) / ISNULL(SUM(tp.Turnover), 0)
				ELSE NULL
				END ASC
	END
END

/*   
GO  
GRANT EXECUTE ON [dbo].[TGRS_OS_Rpt_SummaryTopTrader] TO [bodbTGRSNet]  
GO  
GRANT VIEW DEFINITION ON [dbo].[TGRS_OS_Rpt_SummaryTopTrader] TO [bodbTGRSNet]  
GO  
*/
GO

SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO


GO 
 GRANT EXECUTE ON [dbo].[TGRS_OS_Rpt_SummaryTopTrader] TO [bodbTGRSNet]
GO 
 GRANT VIEW DEFINITION ON [dbo].[TGRS_OS_Rpt_SummaryTopTrader] TO [bodbTGRSNet]
GO 
