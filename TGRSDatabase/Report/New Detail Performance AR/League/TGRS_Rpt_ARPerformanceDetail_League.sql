CREATE PROCEDURE [dbo].[TGRS_Rpt_ARPerformanceDetail_League] 
	 @FromDate DATE
	,@ToDate DATE
	,@LeagueName NVARCHAR(100) = ''
	,@IsExcludeLeagues	BIT = 1
AS
/* 
	Created:	20190304@John
	Task :		New AR Detail report League Performance
	DB:			DBTGRS.bodb_TGRS
	Original:  
	 
	Revisions:
		- 20190304@John: Create new [Redmine ID: #108920]

 Exam: 
	  	  EXEC  TGRS_Rpt_NewPerformanceDetail_League @FromDate = '2014-01-01', @ToDate= '2016-05-30' 
  
*/
BEGIN
	SET NOCOUNT ON;

	SELECT P.LeagueId
		,L.LeagueName
		,ISNULL(COUNT(DISTINCT P.CustId), 0) AS TraderCount
		,ISNULL(COUNT(DISTINCT P.MatchId), 0) AS MatchCount
		,ISNULL(SUM(P.StakeMYR_AR), 0) AS Turnover
		,ISNULL(SUM(P.StakeMYRJuice_AR), 0) AS TurnoverJuice
		,ISNULL(SUM(P.Juice_AR), 0) AS Juice
		,ISNULL(SUM(P.WinLost_AR), 0) - ISNULL(SUM(P.Comm_AR), 0) AS WinLoss
		,ISNULL(SUM(BetCount), 0) AS BetCount
	FROM dbo.TraderPerformance P WITH (NOLOCK)
	INNER JOIN bodb02.dbo.League L WITH (NOLOCK) ON P.LeagueId = L.LeagueId
	LEFT JOIN dbo.BetType TN WITH (NOLOCK) ON TN.BetType = P.BetType
	WHERE P.EventDate BETWEEN @FromDate AND @ToDate
		AND (ISNULL(@LeagueName, '') = '' OR L.LeagueName LIKE '%' + @LeagueName + '%')
		AND TN.MainDBBetType IN (1,3,7,8)
		AND P.IsLive = 1
		AND TN.[Disabled] = 0
		AND (@IsExcludeLeagues = 0 OR (P.LeagueId NOT IN (SELECT le.LeagueId FROM dbo.LeagueExclusion le WITH(NOLOCK))))
	GROUP BY P.LeagueId ,L.LeagueName
END

GO
/*<info serverAlias="DBTGRS-bodb_TGRS" executers="bodbTGRSNet" isFunction="0" isNested="0"></info>*/