ALTER PROCEDURE [dbo].[TGRS_Rpt_SummaryTeamPerformance]  
		@ReportType	 		TINYINT = 1
	,	@FromDate	 		DATE
	,	@ToDate		 		DATE
	,	@ViewPermission		SMALLINT
	,	@IsExcludeLeagues	BIT = 1
	,	@Market				SMALLINT = 1
AS    
/*  
 Created:	20140520@Sophia
 Task :		Summary report- Team Performance
 DB:		DBTGRS.bodb_TGRS
 Original:  
  
 Revisions:   
   		- 20171024@Simon: Add ViewPermission param		
		- 20180912@Simon: add league exclusion
		- 20190919@John.Ngo:	Support Nonlive Data [Redmine ID: 118959]
		- 20191023@John.Ngo:	Enhance performance [Redmine ID: 121268]

 Param's Explanation (filtered by):
		- @Market:	-1 All; 0 Nonlive; 1 Live 
		- @ReportType = 1: by Date
					  = 2: By Month
					  = 3: By Year
			 
		- @ViewPermission = 0: all bet types
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
				ISNULL(SUM(S.Stake),0) AS Turnover, 
				ISNULL(SUM(S.WinLost),0) - ISNULL(SUM(S.Comm),0) AS WinLost, 
				CASE WHEN ISNULL(SUM(S.Stake),0) <> 0 THEN (ISNULL(SUM(S.WinLost),0) - ISNULL(SUM(S.Comm),0))* 100/ISNULL(SUM(S.Stake),0) ELSE NULL END AS Margin,
				S.IsLive
		FROM	dbo.SummaryByTeam_Daily S WITH (NOLOCK)
			INNER JOIN	dbo.Team T WITH (NOLOCK) ON	T.TeamId = S.TeamId
			LEFT JOIN dbo.LeagueExclusion le WITH(NOLOCK) ON S.LeagueId = le.LeagueId
		WHERE	S.EventDate BETWEEN @FromDate AND @ToDate
				AND (@Market = -1 OR S.IsLive = @Market)
				AND (
						@ViewPermission = 0
						OR BettypeGroup = @ViewPermission
					)
				AND (@IsExcludeLeagues = 0 OR le.LeagueId IS NULL)
		GROUP BY T.TeamId, T.TeamName, S.IsLive
		ORDER BY Margin DESC
	END
	ELSE
	BEGIN
		SELECT  T.TeamId, T.TeamName, 
				ISNULL(SUM(S.Stake),0) AS Turnover, 
				ISNULL(SUM(S.WinLost),0) - ISNULL(SUM(S.Comm),0) AS WinLost, 
				CASE WHEN ISNULL(SUM(S.Stake),0) <> 0 THEN (ISNULL(SUM(S.WinLost),0) - ISNULL(SUM(S.Comm),0))* 100/ISNULL(SUM(S.Stake),0) ELSE NULL END AS Margin,
				S.IsLive 
		FROM	dbo.SummaryByTeam_Monthly S WITH (NOLOCK)
			INNER JOIN	dbo.Team T WITH (NOLOCK) ON	T.TeamId = S.TeamId
			LEFT JOIN dbo.LeagueExclusion le WITH(NOLOCK) ON S.LeagueId = le.LeagueId
		WHERE	S.EventDate BETWEEN @FromDate AND @ToDate
				AND (@Market = -1 OR S.IsLive = @Market)
				AND (
						@ViewPermission = 0
						OR BettypeGroup = @ViewPermission
					)
				AND (@IsExcludeLeagues = 0 OR le.LeagueId IS NULL)
		GROUP BY T.TeamId, T.TeamName, S.IsLive
		ORDER BY Margin DESC 
	END

END 

GO
/*<info serverAlias="DBTGRS-bodb_TGRS" executers="bodbTGRSNet" isFunction="0" isNested="0"></info>*/