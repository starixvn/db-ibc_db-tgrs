ALTER PROCEDURE [dbo].[TGRS_Basketball_Rpt_SummaryTraderPerformance] 
		@FromDate		DATE
	,	@ToDate			DATE
	,	@ReportType		TINYINT = 1
AS    
/*  
 Created:	20200805@John.Ngo
 Task :		Summary Trader Performance Report
 DB:		DBTGRS.bodb_TGRS
 Original:  
  
 Revisions:      
		- 20200803@John.Ngo: Summary Trader Performance Report [Redmine ID: 138645]

 Param's Explanation (filtered by):
		- @ReportType = 1: By Date
					  = 2: By Month

 Exam: 
	EXEC TGRS_Basketball_Rpt_SummaryTraderPerformance @FromDate = '2020-05-01', @ToDate = '2020-07-31'
  
*/ 

BEGIN
	SET NOCOUNT ON;

	IF @ReportType	= 1  -- By Date 
	BEGIN
		SELECT td.TraderName AS Username
			,	ISNULL(SUM(os.Turnover), 0) AS Turnover
			,	ISNULL(SUM(os.WinLoss), 0) - ISNULL(SUM(os.Comm), 0) AS WinLoss
			,	CASE WHEN ISNULL(SUM(os.Turnover),0) <> 0
					THEN (ISNULL(SUM(os.WinLoss),0) - ISNULL(SUM(os.Comm),0)) * 100/ISNULL(SUM(os.Turnover),0)
				ELSE NULL END AS Margin
		FROM dbo.OSDataTGRS os WITH (NOLOCK)
		INNER JOIN dbo.OSTrader td WITH (NOLOCK) ON td.TraderId = os.TraderId
		WHERE os.EventDate BETWEEN @FromDate AND @ToDate
			AND os.SportId = 2
		GROUP BY td.TraderName
		ORDER BY 
			CASE WHEN ISNULL(SUM(os.Turnover), 0) <> 0
				THEN (ISNULL(SUM(os.WinLoss), 0) - ISNULL(SUM(os.Comm), 0)) / ISNULL(SUM(os.Turnover), 0)
			ELSE NULL END ASC;
	END;

	IF @ReportType	= 2  -- By Month 
	BEGIN
		-- First of Month
		SET @FromDate = DATEADD(m, DATEDIFF(m, 0, @FromDate), 0);
		SET @ToDate = DATEADD(m, DATEDIFF(m, 0, @ToDate), 0);

		SELECT td.TraderName AS Username
			,	ISNULL(SUM(sm.Turnover), 0) AS Turnover
			,	ISNULL(SUM(sm.WinLoss), 0) - ISNULL(SUM(sm.Comm), 0) AS WinLoss
			,	CASE WHEN ISNULL(SUM(sm.Turnover),0) <> 0 
					THEN (ISNULL(SUM(sm.WinLoss),0) - ISNULL(SUM(sm.Comm),0)) * 100/ISNULL(SUM(sm.Turnover),0) 
				ELSE NULL END AS Margin
		FROM dbo.OSSummaryByTrader_Monthly sm WITH (NOLOCK)
		INNER JOIN dbo.OSTrader td WITH (NOLOCK) ON td.TraderId = sm.TraderId
		WHERE sm.EventDate BETWEEN @FromDate AND @ToDate
			AND sm.SportId = 2
		GROUP BY td.TraderName
		ORDER BY 			
			CASE WHEN ISNULL(SUM(sm.Turnover), 0) <> 0
				THEN (ISNULL(SUM(sm.WinLoss), 0) - ISNULL(SUM(sm.Comm), 0)) / ISNULL(SUM(sm.Turnover), 0)
			ELSE NULL END ASC;
	END;
END;

GO
/*<info serverAlias="DBTGRS-bodb_TGRS" executers="bodbTGRSNet" isFunction="0" isNested="0"></info>*/