
/****** Object:  Stored Procedure dbo.TGRS_Rpt_NewPerformanceDetail_Team_League    Script Date: 1/17/2017 11:20:01 AM ******/

/****** Object:  Stored Procedure dbo.TGRS_Rpt_PerformanceDetail_Team_League    Script Date: 4/1/2016 8:22:16 AM ******/
ALTER PROCEDURE [dbo].[TGRS_Rpt_NewPerformanceDetail_Team_League] 
	 @FromDate DATE
	,@ToDate DATE
	,@TeamId SMALLINT
	,@IsExcludeLeagues	BIT = 1
AS
/*
 Created:	20170111@Aaron
 Task :		New Detail report - League detail from Team
 DB:		DBTGRS.bodb_TGRS
 Original:

 Revisions:
		- 20170316@Long: apply TO's Leftover
		- 20171205@Simon: get only Live data & Bettypes are not disabled
		- 20180912@Simon: add league exclusion

 Param's Explanation:

 Exam:
	  EXEC  TGRS_Rpt_NewPerformanceDetail_Team_League @FromDate = '2016/03/23', @ToDate= '2016/3/28', @TeamId = 11

*/
BEGIN
	SET NOCOUNT ON

	SELECT P.LeagueId
		,L.LeagueName
		,ISNULL(COUNT(DISTINCT P.CustId), 0) AS TraderCount
		,ISNULL(COUNT(DISTINCT P.MatchId), 0) AS MatchCount
		,ISNULL(SUM(P.StakeMYR), 0) AS Turnover
		,ISNULL(SUM(P.StakeMYRJuice), 0) AS TurnoverJuice
		,ISNULL(SUM(P.Juice), 0) AS Juice
		,ISNULL(SUM(P.WinLost), 0) - ISNULL(SUM(P.Comm), 0) AS WinLoss
		,ISNULL(SUM(P.BetCount), 0) AS BetCount
	FROM dbo.TraderPerformance P WITH (NOLOCK)
		INNER JOIN bodb02.dbo.League L WITH (NOLOCK) ON P.LeagueId = L.LeagueId
		INNER JOIN Trader T WITH (NOLOCK) ON T.CustId = P.CustId
		LEFT JOIN dbo.BetType TN WITH (NOLOCK) ON TN.BetType = P.BetType
	WHERE P.EventDate BETWEEN @FromDate
			AND @ToDate
		AND T.TeamId = @TeamId
		AND TN.MainDBBetType IN (1,3,7,8)
		AND TN.[Disabled] = 0
		AND P.IsLive = 1
		AND (@IsExcludeLeagues = 0 OR (L.LeagueId NOT IN (SELECT le.LeagueId FROM dbo.LeagueExclusion le WHERE le.LeagueId = L.LeagueId)))
	GROUP BY P.LeagueId
		,L.LeagueName;
END

/*
GO
GRANT EXECUTE ON [dbo].[TGRS_Rpt_NewPerformanceDetail_Team_League] TO [bodbTGRSNet]
GO
GRANT VIEW DEFINITION ON [dbo].[TGRS_Rpt_NewPerformanceDetail_Team_League] TO [bodbTGRSNet ]
GO
*/

/*<info serverAlias="DBTGRS-bodb_TGRS" executers="bodbTGRSNet" isFunction="0" isNested="0"></info>*/