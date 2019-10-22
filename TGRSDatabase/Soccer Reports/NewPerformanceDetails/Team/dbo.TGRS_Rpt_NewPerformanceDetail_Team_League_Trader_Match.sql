ALTER PROCEDURE [dbo].[TGRS_Rpt_NewPerformanceDetail_Team_League_Trader_Match] 
		@FromDate			DATE
	,	@ToDate				DATE
	,	@CustId				INT
	,	@TeamId				SMALLINT
	,	@LeagueId			INT
	,	@IsExcludeLeagues	BIT = 1
	,	@Market				SMALLINT = 1
AS
/*
    Created:	20170111@Simon
    TASk:		New Detail report Trader Performance - Detail Match
    DB:			DBTGRS.bodb_TGRS
    Original:

	Revisions:
		- 20170316@Long.Luu:	apply TO's Leftover
		- 20171205@Simon:		get only Live data & Bettypes are not disabled
		- 20180912@Simon:		add league exclusion
		- 20190919@Long.Luu:	Support Nonlive Data [Redmine ID: 118959]
		
    Param's ExplanatiON:
		- @Market: -1 All; 0 Nonlive; 1 Live

    Example:
		EXEC [TGRS_Rpt_NewPerformanceDetail_Team_League_Trader_Match] @FromDate = '2014-01-01', @ToDate= '2014-12-30', @CustID = 1530768, @TeamId= 5, @LeagueId = 8

*/
BEGIN
	SET NOCOUNT ON;

	SELECT	P.MatchId
		,	P.LeagueId
		,	P.HomeId
		,	P.AwayId
		,	P.EventDate
		,	P.IsLive
		,	ISNULL(SUM(P.StakeMYR), 0) AS Turnover
		,	ISNULL(SUM(P.StakeMYRJuice), 0) AS TurnoverJuice
		,	ISNULL(SUM(P.Juice), 0) AS Juice
		,	ISNULL(SUM(P.WinLost), 0) - ISNULL(SUM(P.Comm), 0) AS WinLoss
		,	ISNULL(SUM(BetCount), 0) AS BetCount
	FROM dbo.TraderPerformance AS P WITH (NOLOCK)
		INNER JOIN dbo.Trader AS T WITH (NOLOCK) ON T.CustId = P.CustId
		LEFT JOIN dbo.BetType AS TN WITH (NOLOCK) ON TN.BetType = P.BetType
	WHERE P.EventDate BETWEEN @FromDate AND @ToDate
		AND P.CustId = @CustId
		AND T.TeamId = @TeamId
		AND P.LeagueId = @LeagueId
		AND TN.MainDBBetType IN (1, 3, 7, 8)
		AND TN.[Disabled] = 0
		AND (@Market = -1 OR P.IsLive = @Market)
		AND (@IsExcludeLeagues = 0 OR (P.LeagueId NOT IN (SELECT le.LeagueId FROM dbo.LeagueExclusion AS le WITH(NOLOCK))))
	GROUP BY P.MatchId
		,	P.LeagueId
		,	P.HomeId
		,	P.AwayId
		,	P.EventDate
		,	P.IsLive;
END;

GO
/*<info serverAlias="DBTGRS-bodb_TGRS" executers="bodbTGRSNet" isFunction="0" isNested="0"></info>*/