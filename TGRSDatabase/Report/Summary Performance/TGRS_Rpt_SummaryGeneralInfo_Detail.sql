ALTER PROCEDURE [dbo].[TGRS_Rpt_SummaryGeneralInfo_Detail]  
	@ReportType	 TINYINT = 2,
	@FromDate	 DATE,
	@ToDate		 DATE	   
AS    
/*  
 Created:	20141211@Sophia
 Task :		General Info of Summary report detail by Month/ Date
 DB:		DBTGRS/bodb_TGRS
 Original:  
  
 Revisions:      
	 
   			
 Param's Explanation:  
	@ReportType = 1: by Date
			 = 2: By Month
			 = 3: By Year

 Exam: 
	EXEC TGRS_Rpt_SummaryGeneralInfo_Detail @FromDate = '2014-05-01', @ToDate = '2014-05-20', = @ReportType = 2
	
	EXEC TGRS_Rpt_SummaryGeneralInfo_Detail @FromDate = '2014-05-01', @ToDate = '2014-05-20', = @ReportType = 1

*/  
 
BEGIN 
	SET NOCOUNT ON  

	DECLARE @MatchCount INT
	 
	SELECT @MatchCount = COUNT(DISTINCT T.MatchId)
	FROM   dbo.TraderPerformance T WITH (NOLOCK)
	WHERE  T.EventDate BETWEEN @FromDate AND @ToDate


	IF @ReportType	= 1 --- by date
	BEGIN 
		SELECT  S.EventDate,
				ISNULL(SUM(S.Stake),0) AS Turnover,  
				ISNULL(SUM(S.WinLost),0) - ISNULL(SUM(S.Comm),0) AS WinLost, 
				CASE WHEN ISNULL(SUM(S.Stake),0) <> 0 THEN (ISNULL(SUM(S.WinLost),0) - ISNULL(SUM(S.Comm),0)) * 100/ISNULL(SUM(S.Stake),0) ELSE NULL END AS Margin,
				@MatchCount as MatchCount				
		FROM	dbo.SummaryByTeam_Daily S WITH (NOLOCK)		
		WHERE	S.EventDate BETWEEN @FromDate AND @ToDate
		GROUP BY S.EventDate
	
		
	END
	ELSE
	BEGIN 
		SELECT  EventDate,
				ISNULL(SUM(Stake),0) AS Turnover,  
				ISNULL(SUM(WinLost),0) - ISNULL(SUM(Comm),0) AS WinLost,  
				CASE WHEN ISNULL(SUM(Stake),0) <> 0 THEN (ISNULL(SUM(WinLost),0) - ISNULL(SUM(Comm),0)) * 100/ISNULL(SUM(Stake),0) ELSE NULL END AS Margin, 
				@MatchCount as MatchCount
		FROM	dbo.SummaryByTeam_Monthly WITH (NOLOCK)
		WHERE	EventDate BETWEEN @FromDate AND @ToDate	
		GROUP BY EventDate
		
	END

END 
GO
GRANT EXECUTE ON [dbo].[TGRS_Rpt_SummaryGeneralInfo_Detail] TO [bodbTGRSNet]
GO

