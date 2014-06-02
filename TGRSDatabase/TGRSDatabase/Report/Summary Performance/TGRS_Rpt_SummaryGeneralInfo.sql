ALTER PROCEDURE [dbo].[TGRS_Rpt_SummaryGeneralInfo]  
	@ReportType	 TINYINT = 1,
	@FromDate	 DATE,
	@ToDate		 DATE	   
AS    
/*  
 Created:	20140520@Sophia
 Task :		General Info of Summary report
 DB:		DBTGRS.bodb_TGRS
 Original:  
  
 Revisions:      
   			
 Param's Explanation:  
	@ReportType = 1: by Date
			 = 2: By Month
			 = 3: By Year

 Exam: 
	EXEC TGRS_Rpt_SummaryGeneralInfo @FromDate = '2014-05-01', @ToDate = '2014-05-20'
	EXEC TGRS_Rpt_SummaryGeneralInfo @FromDate = '2014-02-01', @ToDate = '2014-04-30'
	EXEC TGRS_Rpt_SummaryGeneralInfo @FromDate = '2012-01-01', @ToDate = '2013-12-31'
  
*/  
 
BEGIN 
	SET NOCOUNT ON  
	IF @ReportType	= 1 --- by date
	BEGIN 
		SELECT  ISNULL(SUM(Stake),0) AS Turnover,  ISNULL(SUM(WinLost),0) -  ISNULL(SUM(Comm),0) AS WinLost, CASE WHEN SUM(Stake) <> 0 THEN (SUM(WinLost)-SUM(Comm))/SUM(Stake) ELSE NULL END AS Margin,  ISNULL(SUM(MatchCount),0) AS MatchCount
		FROM	dbo.SummaryByTeam_Daily WITH (NOLOCK)
		WHERE	EventDate BETWEEN @FromDate AND @ToDate
	END
	ELSE
	BEGIN 
		SELECT  ISNULL(SUM(Stake),0) AS Turnover,  ISNULL(SUM(WinLost),0) -  ISNULL(SUM(Comm),0) AS WinLost,  CASE WHEN SUM(Stake) <> 0 THEN (SUM(WinLost)-SUM(Comm))/SUM(Stake) ELSE NULL END AS Margin,  ISNULL(SUM(MatchCount),0) AS MatchCount
		FROM	dbo.SummaryByTeam_Monthly WITH (NOLOCK)
		WHERE	EventDate BETWEEN @FromDate AND @ToDate	
		
	END

END 
GO
GRANT EXECUTE ON [dbo].[TGRS_Rpt_SummaryGeneralInfo] TO [bodbTGRSNet]
GO

