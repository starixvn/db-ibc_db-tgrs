ALTER PROCEDURE [dbo].[TGRS_Rpt_SummaryTeamPerformance]  
	@ReportType	 TINYINT = 1,
	@FromDate	 DATE,
	@ToDate		 DATE	   
AS    
/*  
 Created:	20140520@Sophia
 Task :		Summary report- Team Performance
 DB:		DBTGRS.bodb_TGRS
 Original:  
  
 Revisions:      
   			
 Param's Explanation:  
	@ReportType = 1: by Date
			 = 2: By Month
			 = 3: By Year
 Exam: 
	EXEC TGRS_Rpt_SummaryTeamPerformance  @FromDate = '2014-05-01', @ToDate = '2014-05-20'
  
*/  
 
BEGIN 
	SET NOCOUNT ON  
	IF @ReportType	= 1 --- by date
	BEGIN 
		SELECT  T.TeamId, T.TeamName, 
				ISNULL(SUM(Stake),0) AS Turnover, 
				ISNULL(SUM(WinLost),0) - ISNULL(SUM(Comm),0) AS WinLost, 
				CASE WHEN ISNULL(SUM(Stake),0) <> 0 THEN (ISNULL(SUM(WinLost),0) - ISNULL(SUM(Comm),0))/ISNULL(SUM(Stake),0) ELSE NULL END AS Margin 
		FROM	dbo.SummaryByTeam_Daily S WITH (NOLOCK)
			INNER JOIN	dbo.Team T WITH (NOLOCK) 
					ON	T.TeamId = S.TeamId
		WHERE	S.EventDate BETWEEN @FromDate AND @ToDate
		GROUP BY T.TeamId, T.TeamName
		ORDER BY Margin DESC
	END
	ELSE
	BEGIN
		SELECT  T.TeamId, T.TeamName, 
				ISNULL(SUM(Stake),0) AS Turnover, 
				ISNULL(SUM(WinLost),0) - ISNULL(SUM(Comm),0) AS WinLost, 
				CASE WHEN ISNULL(SUM(Stake),0) <> 0 THEN (ISNULL(SUM(WinLost),0) - ISNULL(SUM(Comm),0))/ISNULL(SUM(Stake),0) ELSE NULL END AS Margin 
		FROM	dbo.SummaryByTeam_Monthly S WITH (NOLOCK)
			INNER JOIN	dbo.Team T WITH (NOLOCK) 
					ON	T.TeamId = S.TeamId
		WHERE	S.EventDate BETWEEN @FromDate AND @ToDate
		GROUP BY T.TeamId, T.TeamName
		ORDER BY Margin DESC 
	END

END 
GO
GRANT EXECUTE ON [dbo].[TGRS_Rpt_SummaryTeamPerformance] TO [bodbTGRSNet]
GO

