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
	DECLARE @TopMinMargin MONEY, @TopMaxMargin MONEY, @BottomMinMargin MONEY, @BottomMaxMargin MONEY

	IF @ReportType	= 1 --- By Date
	BEGIN 
		INSERT INTO @Top
		SELECT  TOP 10  CustId, CASE WHEN ISNULL(SUM(Stake),0) <> 0 THEN (ISNULL(SUM(WinLost),0) - ISNULL(SUM(Comm),0))/ISNULL(SUM(Stake),0) *100 ELSE NULL END AS Margin		
		FROM	dbo.TraderPerformance P WITH (NOLOCK)			 
		WHERE	EventDate BETWEEN @FromDate AND @ToDate
		GROUP BY CustId
		ORDER BY Margin DESC

		INSERT INTO @Bottom
		SELECT  TOP 10 CustId, CASE WHEN ISNULL(SUM(Stake),0) <> 0 THEN (ISNULL(SUM(WinLost),0) - ISNULL(SUM(Comm),0))/ISNULL(SUM(Stake),0) *100 ELSE NULL END AS Margin	
		FROM	dbo.TraderPerformance WITH (NOLOCK)			 
		WHERE	EventDate BETWEEN @FromDate AND @ToDate
		GROUP BY CustId
		ORDER BY Margin ASC
			
	END
	ELSE  -- By Month, year
	BEGIN
		INSERT INTO @Top
		SELECT  TOP 10 CustId, CASE WHEN ISNULL(SUM(Stake),0) <> 0 THEN (ISNULL(SUM(WinLost),0) - ISNULL(SUM(Comm),0))/ISNULL(SUM(Stake),0) *100 ELSE NULL END AS Margin			
		FROM	dbo.SummaryByTrader_Monthly WITH (NOLOCK)			 
		WHERE	EventDate BETWEEN @FromDate AND @ToDate
		GROUP BY CustId
		ORDER BY Margin DESC

		INSERT INTO @Bottom
		SELECT  TOP 10 CustId, CASE WHEN ISNULL(SUM(Stake),0) <> 0 THEN (ISNULL(SUM(WinLost),0) - ISNULL(SUM(Comm),0))/ISNULL(SUM(Stake),0) *100 ELSE NULL END AS Margin	
		FROM	dbo.SummaryByTrader_Monthly WITH (NOLOCK)			 
		WHERE	EventDate BETWEEN @FromDate AND @ToDate
		GROUP BY CustId
		ORDER BY Margin ASC
	END

	SELECT @TopMinMargin = MIN(Margin), @TopMaxMargin = MAX(Margin) FROM @Top 
	SELECT @BottomMinMargin = MIN(Margin), @BottomMaxMargin = MAX(Margin) FROM @Bottom  
	
	SELECT @TopMinMargin AS TopMinMargin, @TopMaxMargin AS TopMaxMargin, @BottomMinMargin AS BottomMinMargin, @BottomMaxMargin AS BottomMaxMargin


END 
GO
GRANT EXECUTE ON [dbo].[TGRS_Rpt_SummaryTraderPerformace] TO [bodbTGRSNet]
GO

 