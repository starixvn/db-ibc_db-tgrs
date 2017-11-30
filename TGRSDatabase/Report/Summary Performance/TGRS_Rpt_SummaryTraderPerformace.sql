CREATE PROCEDURE [dbo].[TGRS_Rpt_SummaryTraderPerformace]  
	@ReportType	 TINYINT = 1,
	@FromDate	 DATE,
	@ToDate		 DATE,
	@ViewPermission SMALLINT
AS    
/*  
 Created:	20140520@Sophia
 Task :		Summary report - Top Trader performace
 DB:		DBTGRS.bodb_TGRS
 Original:  
  
 Revisions:      
   	- 20171024@Simon: Add ViewPermission param				
 Param's Explanation:  
	@ReportType = 1: by Date
			 = 2: By Month
			 = 3: By Year
			 
	@ViewPermission = 0: all bet types
			 = 1: major bet types
			 = 2: PHAIO bet types
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
		SELECT  TOP 10  P.CustId, CASE WHEN ISNULL(SUM(P.Stake),0) <> 0 THEN (ISNULL(SUM(P.WinLost),0) - ISNULL(SUM(P.Comm),0)) *100 /ISNULL(SUM(P.Stake),0)ELSE NULL END AS Margin		
		FROM	
			dbo.TraderPerformance P WITH (NOLOCK)
			INNER JOIN dbo.Bettype bt WITH (NOLOCK)
				ON P.Bettype = bt.Bettype
		WHERE	
			EventDate BETWEEN @FromDate AND @ToDate
			AND (
					@ViewPermission = 0
					OR bt.BettypeGroup = @ViewPermission
				)
			AND bt.[Disabled] = 0
			AND P.IsLive = 1
		GROUP BY P.CustId
		ORDER BY Margin DESC

		INSERT INTO @Bottom
		SELECT  TOP 10 P.CustId, CASE WHEN ISNULL(SUM(P.Stake),0) <> 0 THEN (ISNULL(SUM(P.WinLost),0) - ISNULL(SUM(P.Comm),0)) *100 /ISNULL(SUM(P.Stake),0)  ELSE NULL END AS Margin	
		FROM	
			dbo.TraderPerformance P WITH (NOLOCK)			 
			INNER JOIN dbo.Bettype bt WITH (NOLOCK)
				ON P.Bettype = bt.Bettype
		WHERE	
			EventDate BETWEEN @FromDate AND @ToDate
			AND (
					@ViewPermission = 0
					OR bt.BettypeGroup = @ViewPermission
				)
			AND P.IsLive = 1
			AND bt.[Disabled] = 0
		GROUP BY P.CustId
		ORDER BY Margin ASC
			
	END
	ELSE  -- By Month, year
	BEGIN
		INSERT INTO @Top
		SELECT  TOP 10 CustId, CASE WHEN ISNULL(SUM(Stake),0) <> 0 THEN (ISNULL(SUM(WinLost),0) - ISNULL(SUM(Comm),0)) *100 /ISNULL(SUM(Stake),0)  ELSE NULL END AS Margin			
		FROM	dbo.SummaryByTrader_Monthly WITH (NOLOCK)			 
		WHERE	
			EventDate BETWEEN @FromDate AND @ToDate
			AND (
					@ViewPermission = 0
					OR BettypeGroup = @ViewPermission
				)
		GROUP BY CustId
		ORDER BY Margin DESC

		INSERT INTO @Bottom
		SELECT  TOP 10 CustId, CASE WHEN ISNULL(SUM(Stake),0) <> 0 THEN (ISNULL(SUM(WinLost),0) - ISNULL(SUM(Comm),0)) *100 /ISNULL(SUM(Stake),0)  ELSE NULL END AS Margin	
		FROM	dbo.SummaryByTrader_Monthly WITH (NOLOCK)			 
		WHERE	
			EventDate BETWEEN @FromDate AND @ToDate
			AND (
					@ViewPermission = 0
					OR BettypeGroup = @ViewPermission
				)
		GROUP BY CustId
		ORDER BY Margin ASC
	END

	SELECT @TopMinMargin = MIN(Margin), @TopMaxMargin = MAX(Margin) FROM @Top 
	SELECT @BottomMinMargin = MIN(Margin), @BottomMaxMargin = MAX(Margin) FROM @Bottom  
	
	SELECT @TopMinMargin AS TopMinMargin, @TopMaxMargin AS TopMaxMargin, @BottomMinMargin AS BottomMinMargin, @BottomMaxMargin AS BottomMaxMargin


END