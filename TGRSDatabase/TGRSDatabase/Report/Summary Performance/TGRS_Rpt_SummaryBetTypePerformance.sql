ALTER PROCEDURE [dbo].[TGRS_Rpt_SummaryBetTypePerformance]  
	@ReportType	 TINYINT = 1,
	@FromDate	 DATE,
	@ToDate		 DATE	   
AS    
/*  
 Created:	20140520@Sophia
 Task :		Summary report- BetType Performance
 DB:		DBTGRS.bodb_TGRS
 Original:  
  
 Revisions:      
   			
 Param's Explanation:  
 	@ReportType = 1: by Date
			 = 2: By Month
			 = 3: By Year

 Exam: 
	EXEC TGRS_Rpt_SummaryBetTypePerformance @FromDate = '2014-05-01', @ToDate = '2014-05-20' 
  
*/  
 
BEGIN 
	SET NOCOUNT ON  



	IF @ReportType	= 1 --- by date
	BEGIN 		
		SELECT  B.BetType, B.TypeName, 
				ISNULL(SUM(Stake),0) AS Turnover, 
				ISNULL(SUM(WinLost),0) -  ISNULL(SUM(Comm),0) AS WinLost, 
				CASE WHEN  ISNULL(SUM(Stake),0) <> 0 THEN (ISNULL(SUM(WinLost),0) -  ISNULL(SUM(Comm),0))/ ISNULL(SUM(Stake),0) ELSE NULL END AS Margin 
		FROM	dbo.SummaryByBetType_Daily S WITH (NOLOCK)
			INNER JOIN	dbo.BetType B WITH (NOLOCK) 
					ON	S.BetType = B.BetType
		WHERE	EventDate BETWEEN @FromDate AND @ToDate
		GROUP BY B.BetType, B.TypeName, B.OrderId
		ORDER BY B.OrderId

	END
	ELSE
	BEGIN		
		SELECT  B.BetType, B.TypeName, 
				ISNULL(SUM(Stake),0) AS Turnover,  
				ISNULL(SUM(WinLost),0) -  ISNULL(SUM(Comm),0) AS WinLost, 
				CASE WHEN  ISNULL(SUM(Stake),0) <> 0 THEN (ISNULL(SUM(WinLost),0) -  ISNULL(SUM(Comm),0))/ ISNULL(SUM(Stake),0) ELSE NULL END AS Margin 
		FROM	dbo.SummaryByBetType_Monthly S WITH (NOLOCK)
			INNER JOIN	dbo.BetType B WITH (NOLOCK) 
					ON	S.BetType = B.BetType
		WHERE	EventDate BETWEEN @FromDate AND @ToDate
		GROUP BY B.BetType, B.TypeName, B.OrderId
		ORDER BY B.OrderId

	END


END 
GO
GRANT EXECUTE ON [dbo].[TGRS_Rpt_SummaryBetTypePerformance] TO [bodbTGRSNet]
GO

