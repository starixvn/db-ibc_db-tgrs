ALTER PROCEDURE [dbo].[TGRS_Rpt_SummaryTeamPerformance]  
	@ReportType	 	TINYINT = 1,
	@FromDate	 	DATE,
	@ToDate		 	DATE,
	@ViewPermission SMALLINT,
	@IsExcludeLeagues	BIT = 1
AS    
/*  
 Created:	20140520@Sophia
 Task :		Summary report- Team Performance
 DB:		DBTGRS.bodb_TGRS
 Original:  
  
 Revisions:   
   	- 20171024@Simon: Add ViewPermission param		
	- 20180912@Simon: add league exclusion

 Param's Explanation:  
	@ReportType = 1: by Date
			 = 2: By Month
			 = 3: By Year
			 
	@ViewPermission = 0: all bet types
			 = 1: major bet types
			 = 2: PHAIO bet types
 Exam: 
	EXEC TGRS_Rpt_SummaryTeamPerformance @FromDate = '2014-05-01', @ToDate = '2014-05-20'
  
*/  
 
BEGIN 
	SET NOCOUNT ON  
	IF @ReportType	= 1 --- by date
	BEGIN 
		SELECT  T.TeamId, T.TeamName, 
				ISNULL(SUM(Stake),0) AS Turnover, 
				ISNULL(SUM(WinLost),0) - ISNULL(SUM(Comm),0) AS WinLost, 
				CASE WHEN ISNULL(SUM(Stake),0) <> 0 THEN (ISNULL(SUM(WinLost),0) - ISNULL(SUM(Comm),0))* 100/ISNULL(SUM(Stake),0) ELSE NULL END AS Margin 
		FROM	dbo.SummaryByTeam_Daily S WITH (NOLOCK)
			INNER JOIN	dbo.Team T WITH (NOLOCK) 
					ON	T.TeamId = S.TeamId
		WHERE	
				S.EventDate BETWEEN @FromDate AND @ToDate
				AND (
						@ViewPermission = 0
						OR BettypeGroup = @ViewPermission
					)
				AND (@IsExcludeLeagues = 0 OR (S.LeagueId NOT IN (SELECT le.LeagueId FROM dbo.LeagueExclusion le WHERE le.LeagueId = S.LeagueId)))
		GROUP BY T.TeamId, T.TeamName
		ORDER BY Margin DESC
	END
	ELSE
	BEGIN
		SELECT  T.TeamId, T.TeamName, 
				ISNULL(SUM(Stake),0) AS Turnover, 
				ISNULL(SUM(WinLost),0) - ISNULL(SUM(Comm),0) AS WinLost, 
				CASE WHEN ISNULL(SUM(Stake),0) <> 0 THEN (ISNULL(SUM(WinLost),0) - ISNULL(SUM(Comm),0))* 100/ISNULL(SUM(Stake),0) ELSE NULL END AS Margin 
		FROM	dbo.SummaryByTeam_Monthly S WITH (NOLOCK)
			INNER JOIN	dbo.Team T WITH (NOLOCK) 
					ON	T.TeamId = S.TeamId
		WHERE	
				S.EventDate BETWEEN @FromDate AND @ToDate
				AND (
						@ViewPermission = 0
						OR BettypeGroup = @ViewPermission
					)
				AND (@IsExcludeLeagues = 0 OR (S.LeagueId NOT IN (SELECT le.LeagueId FROM dbo.LeagueExclusion le WHERE le.LeagueId = S.LeagueId)))
		GROUP BY T.TeamId, T.TeamName
		ORDER BY Margin DESC 
	END

END 
GO
GRANT EXECUTE ON [dbo].[TGRS_Rpt_SummaryTeamPerformance] TO [bodbTGRSNet]
GO

