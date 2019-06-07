ALTER PROCEDURE [dbo].[TGRS_Rpt_NewPerformanceDetail_LeagueAllMatch] 
	 @FromDate DATE
	,@ToDate DATE
	,@LeagueName NVARCHAR(100) = ''
	,@IsExcludeLeagues	BIT = 1

AS
/*  
 Created:	20190607@John.Ngo
 Task :		Get all matches in Performance Details (Juice & LO) - League [Redmine ID: 114879]
 DB:		DBTGRS.bodb_TGRS
 
 Revisions:      	
	- 20190607@John.Ngo: Get all matches in Performance Details (Juice & LO) - League [Redmine ID: 114879]
	
 Param's Explanation:
 Exam: 
	  	  EXEC TGRS_Rpt_NewPerformanceDetail_LeagueAllMatch @FromDate = '2019-05-01', @ToDate= '2019-06-01', @LeagueName = '', @IsExcludeLeagues = 0
  
*/
BEGIN
	SET NOCOUNT ON;

	SELECT P.LeagueId
		,L.LeagueName 
		,P.MatchId
		,P.HomeId
		,P.AwayId
		,P.EventDate
		,ISNULL(SUM(P.StakeMYR), 0) AS Turnover
		,ISNULL(SUM(P.StakeMYRJuice), 0) AS TurnoverJuice
		,ISNULL(SUM(P.Juice), 0) AS Juice
		,ISNULL(SUM(P.WinLost), 0) - ISNULL(SUM(P.Comm), 0) AS WinLoss
		,ISNULL(SUM(P.BetCount), 0) AS BetCount
	FROM dbo.TraderPerformance P WITH (NOLOCK)
	INNER JOIN bodb02.dbo.League L WITH (NOLOCK) ON P.LeagueId = L.LeagueId
	LEFT JOIN dbo.BetType TN WITH (NOLOCK) ON TN.BetType = P.BetType
	WHERE P.EventDate BETWEEN @FromDate AND @ToDate
		AND (ISNULL(@LeagueName, '') = '' OR L.LeagueName LIKE '%' + @LeagueName + '%')
		AND TN.MainDBBetType IN (1,3,7,8)
		AND TN.[Disabled] = 0
		AND P.IsLive = 1
		AND (@IsExcludeLeagues = 0 OR (P.LeagueId NOT IN (SELECT le.LeagueId FROM dbo.LeagueExclusion le WITH(NOLOCK))))
	GROUP BY P.LeagueId 
		,L.LeagueName
		,P.MatchId
		,P.HomeId
		,P.AwayId
		,P.EventDate
END

GO
/*<info serverAlias="DBTGRS-bodb_TGRS" executers="bodbTGRSNet" isFunction="0" isNested="0"></info>*/