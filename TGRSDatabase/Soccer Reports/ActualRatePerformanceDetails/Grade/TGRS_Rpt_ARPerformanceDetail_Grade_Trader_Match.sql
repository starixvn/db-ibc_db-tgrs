ALTER PROCEDURE [dbo].[TGRS_Rpt_ARPerformanceDetail_Grade_Trader_Match] 
		@FromDate				DATE
	,	@ToDate					DATE
	,	@CustId					INT
	,	@IsExcludeLeagues		BIT = 1
	,	@Market					SMALLINT = 1
AS
/* 
	Created:	20190304@John
	Task :		New AR Performance Details (Juice & Leftover) Report - Grade - Trader - Match
	DB:			DBTGRS.bodb_TGRS
	Original:  
	 
	Revisions:
		- 20190304@John: Create new [Redmine ID: #108920]	
		- 20190919@John.Ngo:	Support Nonlive Data [Redmine ID: 118959]

	Param's Explanation (filtered by):
		- @Market:	-1 All; 0 Nonlive; 1 Live
			
	Example: 
		EXEC [TGRS_Rpt_ARPerformanceDetail_Grade_Trader_Match] @FromDate = '2019-02-01', @ToDate= '2019-03-05', @CustID = 2457
  
*/
BEGIN
	SET NOCOUNT ON;

	SELECT P.MatchId
		,P.LeagueId
		,P.HomeId
		,P.AwayId
		,P.EventDate
		,ISNULL(SUM(P.StakeMYR_AR), 0) AS Turnover
		,ISNULL(SUM(P.StakeMYRJuice_AR), 0) AS TurnoverJuice
		,ISNULL(SUM(P.Juice_AR), 0) AS Juice
		,ISNULL(SUM(P.WinLost_AR), 0) - ISNULL(SUM(P.Comm_AR), 0) AS WinLoss
		,ISNULL(SUM(P.BetCount), 0) AS BetCount
		,P.IsLive
	FROM dbo.TraderPerformance P WITH (NOLOCK)
	LEFT JOIN dbo.BetType TN WITH (NOLOCK) ON TN.BetType = P.BetType
	WHERE P.EventDate BETWEEN @FromDate AND @ToDate
		AND P.CustId = @CustId
		AND TN.MainDBBetType IN (1,3,7,8)
		AND TN.[Disabled] = 0
		AND (@Market = -1 OR P.IsLive = @Market)
		AND (@IsExcludeLeagues = 0 OR (P.LeagueId NOT IN (SELECT le.LeagueId FROM dbo.LeagueExclusion le WITH(NOLOCK))))
	GROUP BY P.MatchId
		,P.LeagueId
		,P.HomeId
		,P.AwayId
		,P.EventDate
		,P.IsLive;
END;

GO
/*<info serverAlias="DBTGRS-bodb_TGRS" executers="bodbTGRSNet" isFunction="0" isNested="0"></info>*/