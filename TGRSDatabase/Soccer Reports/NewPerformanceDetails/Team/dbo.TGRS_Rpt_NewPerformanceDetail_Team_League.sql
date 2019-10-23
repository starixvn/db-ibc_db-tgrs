ALTER PROCEDURE [dbo].[TGRS_Rpt_NewPerformanceDetail_Team_League] 
		@FromDate			DATE
	,	@ToDate				DATE
	,	@TeamId				SMALLINT
	,	@IsExcludeLeagues	BIT = 1
	,	@Market				SMALLINT = 1
AS
/*
	Created:	20170111@Aaron
	Task :		New Detail report - League detail from Team
	DB:			DBTGRS.bodb_TGRS
	Original:

	Revisions:
		- 20170316@Long.Luu:	apply TO's Leftover
		- 20171205@Simon:		get only Live data & Bettypes are not disabled
		- 20180912@Simon:		add league exclusion
		- 20190919@Long.Luu:	Support Nonlive Data [Redmine ID: 118959]
		- 20191023@John.Ngo:	Enhance performance [Redmine ID: 121268]

	Param's Explanation:
		- @Market: -1 All; 0 Nonlive; 1 Live

	Exam:
		EXEC  TGRS_Rpt_NewPerformanceDetail_Team_League @FromDate = '2016/03/23', @ToDate= '2016/3/28', @TeamId = 11

*/
BEGIN
	SET NOCOUNT ON

	SELECT	P.LeagueId
		,	L.LeagueName
		,	P.IsLive
		,	ISNULL(COUNT(DISTINCT P.CustId), 0) AS TraderCount
		,	ISNULL(COUNT(DISTINCT P.MatchId), 0) AS MatchCount
		,	ISNULL(SUM(P.StakeMYR), 0) AS Turnover
		,	ISNULL(SUM(P.StakeMYRJuice), 0) AS TurnoverJuice
		,	ISNULL(SUM(P.Juice), 0) AS Juice
		,	ISNULL(SUM(P.WinLost), 0) - ISNULL(SUM(P.Comm), 0) AS WinLoss
		,	ISNULL(SUM(P.BetCount), 0) AS BetCount
	FROM dbo.TraderPerformance AS P WITH (NOLOCK)
		INNER JOIN bodb02.dbo.League AS L WITH (NOLOCK) ON P.LeagueId = L.LeagueId
		INNER JOIN Trader AS T WITH (NOLOCK) ON T.CustId = P.CustId
		LEFT JOIN dbo.BetType AS TN WITH (NOLOCK) ON TN.BetType = P.BetType
		LEFT JOIN dbo.LeagueExclusion le WITH(NOLOCK) ON P.LeagueId = le.LeagueId
	WHERE P.EventDate BETWEEN @FromDate AND @ToDate
		AND T.TeamId = @TeamId
		AND TN.MainDBBetType IN (1, 3, 7, 8)
		AND TN.[Disabled] = 0
		AND (@Market = -1 OR P.IsLive = @Market)
		AND (@IsExcludeLeagues = 0 OR le.LeagueId IS NULL)
	GROUP BY P.LeagueId
		,	L.LeagueName
		,	P.IsLive;
END;

GO
/*<info serverAlias="DBTGRS-bodb_TGRS" executers="bodbTGRSNet" isFunction="0" isNested="0"></info>*/