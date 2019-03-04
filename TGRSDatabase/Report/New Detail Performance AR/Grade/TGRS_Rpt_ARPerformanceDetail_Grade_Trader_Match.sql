CREATE PROCEDURE [dbo].[TGRS_Rpt_ARPerformanceDetail_Grade_Trader_Match] 
		@FromDate				DATE
	,	@ToDate					DATE
	,	@CustId					INT
	,	@IsExcludeLeagues		BIT = 1
AS
/* 
	Created:	20190304@John
	Task :		New AR Detail report Grade Performance - Detail Match
	DB:			DBTGRS.bodb_TGRS
	Original:  
	 
	Revisions:
		- 20190304@John: Create new [Redmine ID: #108920]	
	
	Example: 
		EXEC [TGRS_Rpt_ARPerformanceDetail_Grade_Trader_Match] @FromDate = '2016-03-01', @ToDate= '2016-12-30', @CustID = 2457
  
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
	FROM dbo.TraderPerformance P WITH (NOLOCK)
	LEFT JOIN dbo.BetType TN WITH (NOLOCK) ON TN.BetType = P.BetType
	WHERE P.EventDate BETWEEN @FromDate AND @ToDate
		AND P.CustId = @CustId
		AND TN.MainDBBetType IN (1,3,7,8)
		AND TN.[Disabled] = 0
		AND P.IsLive = 1
		AND (@IsExcludeLeagues = 0 OR (P.LeagueId NOT IN (SELECT le.LeagueId FROM dbo.LeagueExclusion le WITH(NOLOCK))))
	GROUP BY P.MatchId
		,P.LeagueId
		,P.HomeId
		,P.AwayId
		,P.EventDate;
END;

GO
/*<info serverAlias="DBTGRS-bodb_TGRS" executers="bodbTGRSNet" isFunction="0" isNested="0"></info>*/