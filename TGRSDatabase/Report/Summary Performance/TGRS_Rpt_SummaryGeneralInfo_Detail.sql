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
	EXEC TGRS_Rpt_SummaryGeneralInfo_Detail @FromDate = '2014-05-01', @ToDate = '2014-12-01',  @ReportType = 2
	
	EXEC TGRS_Rpt_SummaryGeneralInfo_Detail @FromDate = '2014-05-01', @ToDate = '2014-12-01',  @ReportType = 1

*/  
 
BEGIN 
	SET NOCOUNT ON  

	DECLARE @MatchCount AS TABLE (EventDate DATE, MatchCount INT)

	IF @ReportType = 2
	BEGIN 
		SELECT @FromDate = DATEADD(DD, -DAY(@FromDate)+1, @FromDate)
		SELECT @ToDate =  DATEADD(DD, -1, DATEADD(mm, DATEDIFF(m,0,@ToDate)+1,0) )


		INSERT INTO @MatchCount (EventDate, MatchCount)		 
		SELECT  DATEADD(DD, -DAY(EventDate)+1, EventDate), COUNT(DISTINCT MatchId)
		FROM    dbo.TraderPerformance  WITH (NOLOCK)
		WHERE   EventDate BETWEEN @FromDate AND @ToDate
		GROUP BY DATEADD(DD,-DAY(EventDate)+1, EventDate) 


		SELECT  S.EventDate,
				ISNULL(SUM(Stake),0) AS Turnover,  
				ISNULL(SUM(WinLost),0) - ISNULL(SUM(Comm),0) AS WinLost,  
				CASE WHEN ISNULL(SUM(Stake),0) <> 0 THEN (ISNULL(SUM(WinLost),0) - ISNULL(SUM(Comm),0)) * 100/ISNULL(SUM(Stake),0) ELSE NULL END AS Margin, 
				M.MatchCount
		FROM	dbo.SummaryByTeam_Monthly S WITH (NOLOCK)
			INNER JOIN @MatchCount M 
				ON M.EventDate = S.EventDate
		WHERE	S.EventDate BETWEEN @FromDate AND @ToDate	
		GROUP BY S.EventDate, M.MatchCount
	END	
	ELSE 
	BEGIN 
		SELECT  S.EventDate,
				ISNULL(SUM(Stake),0) AS Turnover,  
				ISNULL(SUM(WinLost),0) - ISNULL(SUM(Comm),0) AS WinLost,  
				CASE WHEN ISNULL(SUM(Stake),0) <> 0 THEN (ISNULL(SUM(WinLost),0) - ISNULL(SUM(Comm),0)) * 100/ISNULL(SUM(Stake),0) ELSE NULL END AS Margin, 
				SUM(S.MatchCount) AS MatchCount
		FROM	dbo.SummaryByTeam_Daily S WITH (NOLOCK)
		WHERE	S.EventDate BETWEEN @FromDate AND @ToDate	
		GROUP BY S.EventDate 

	END 

END 
GO
GRANT EXECUTE ON [dbo].[TGRS_Rpt_SummaryGeneralInfo_Detail] TO [bodbTGRSNet]
GO

