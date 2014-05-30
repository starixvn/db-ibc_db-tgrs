ALTER PROCEDURE [dbo].[TGRS_Rpt_SummaryTraderPerformace]  
	@ReportType	 TINYINT = 1,
	@FromDate	 DATE,
	@ToDate		 DATE    
AS    
/*  
 Created:	20140520@Sophia
 Task :		Summary report - Top Trader performace
 DB:		DBTGRS.bodb_TGRS
 Original:  
  
 Revisions:      
   			
 Param's Explanation:  
	@ReportType = 1: by Date
			 = 2: By Month
			 = 3: By Year

 Exam: 
	EXEC TGRS_Rpt_SummaryTraderPerformace @ReportType = 1, @FromDate = '2014-05-01', @ToDate = '2014-05-20'
	EXEC TGRS_Rpt_SummaryTraderPerformace @ReportType = 2, @FromDate = '2014-02-01', @ToDate = '2014-04-30'
	EXEC TGRS_Rpt_SummaryTraderPerformace @ReportType = 3, @FromDate = '2012-01-01', @ToDate = '2013-12-31'
  
*/  
 
BEGIN 
	SET NOCOUNT ON 
	
	DECLARE @Top AS TABLE (CustId INT, Margin MONEY) 
	DECLARE @Bottom AS TABLE (CustId INT, Margin MONEY) 

	IF @ReportType	= 1 --- By Date
	BEGIN 
		INSERT INTO @Top
		SELECT  TOP 10  CustId, CASE WHEN SUM(Stake) <> 0 THEN (SUM(WinLost)-SUM(Comm))/SUM(Stake) ELSE NULL END AS Margin		
		FROM	dbo.rpt_TraderPerformance P WITH (NOLOCK)			 
		WHERE	EventDate BETWEEN @FromDate AND @ToDate
		GROUP BY CustId
		ORDER BY Margin DESC

		INSERT INTO @Bottom
		SELECT  TOP 10 CustId,CASE WHEN SUM(Stake) <> 0 THEN (SUM(WinLost)-SUM(Comm))/SUM(Stake) ELSE NULL END AS Margin
		FROM	dbo.rpt_TraderPerformance WITH (NOLOCK)			 
		WHERE	EventDate BETWEEN @FromDate AND @ToDate
		GROUP BY CustId
		ORDER BY Margin ASC
			
	END
	ELSE  -- By Month, year
	BEGIN
		INSERT INTO @Top
		SELECT  TOP 10 CustId,CASE WHEN SUM(Stake) <> 0 THEN (SUM(WinLost)-SUM(Comm))/SUM(Stake) ELSE NULL END AS Margin		
		FROM	dbo.SummaryByTrader_Monthly WITH (NOLOCK)			 
		WHERE	EventDate BETWEEN @FromDate AND @ToDate
		GROUP BY CustId
		ORDER BY Margin DESC

		INSERT INTO @Bottom
		SELECT  TOP 10 CustId, CASE WHEN SUM(Stake) <> 0 THEN (SUM(WinLost)-SUM(Comm))/SUM(Stake) ELSE NULL END AS Margin
		FROM	dbo.SummaryByTrader_Monthly WITH (NOLOCK)			 
		WHERE	EventDate BETWEEN @FromDate AND @ToDate
		GROUP BY CustId
		ORDER BY Margin ASC
	END

	SELECT  MIN(Margin) AS TopMinMargin, MAX(Margin) AS TopMaxMargin FROM @Top 
	SELECT  MIN(Margin) AS BottomMinMargin, MAX(Margin) AS BottomMaxMargin FROM @Bottom  


END 
GO
GRANT EXECUTE ON [dbo].[TGRS_Rpt_SummaryTraderPerformace] TO [bodbTGRSNet]
GO

 