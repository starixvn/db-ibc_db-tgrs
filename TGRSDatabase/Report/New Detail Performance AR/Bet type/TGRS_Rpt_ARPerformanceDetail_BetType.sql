CREATE PROCEDURE [dbo].[TGRS_Rpt_ARPerformanceDetail_BetType] 
		@FromDate			DATE
	,	@ToDate				DATE
	,	@IsExcludeLeagues	BIT = 1
AS
/*
	Created:	20190304@John
	Task :		New AR Performance Details (Juice & Leftover) Report - BetType
	DB:			DBTGRS.bodb_TGRS
	Original:  
	 
	Revisions:
		- 20190304@John: Create new [Redmine ID: #108920]		

	Exam: 
	  	 EXEC  [TGRS_Rpt_ARPerformanceDetail_BetType] @FromDate = '2019-01-01', @ToDate= '2019-03-05' 
  
*/
BEGIN
	SET NOCOUNT ON;

	SELECT P.BetType
		,ISNULL(COUNT(DISTINCT P.CustId), 0) AS TraderCount
		,ISNULL(COUNT(DISTINCT P.LeagueId), 0) AS LeagueCount
		,ISNULL(COUNT(DISTINCT P.MatchId), 0) AS MatchCount
		,ISNULL(SUM(P.StakeMYR_AR), 0) AS Turnover
		,ISNULL(SUM(P.StakeMYRJuice_AR), 0) AS TurnoverJuice
		,ISNULL(SUM(P.Juice_AR), 0) AS Juice
		,ISNULL(SUM(P.WinLost_AR), 0) - ISNULL(SUM(P.Comm_AR), 0) AS WinLoss
		,ISNULL(SUM(P.BetCount), 0) AS BetCount
	INTO #TraderPerformanceTemp
	FROM dbo.TraderPerformance P WITH (NOLOCK)
	WHERE P.EventDate BETWEEN @FromDate AND @ToDate
		AND P.IsLive = 1
		AND (@IsExcludeLeagues = 0 OR (P.LeagueId NOT IN (SELECT le.LeagueId FROM dbo.LeagueExclusion le WITH(NOLOCK))))
	GROUP BY P.BetType;

	SELECT P.BetType
		,TN.TypeName
		,P.TraderCount
		,P.LeagueCount
		,P.MatchCount
		,P.Turnover
		,P.WinLoss
		,P.TurnoverJuice
		,P.Juice
		,P.BetCount
	FROM #TraderPerformanceTemp P
		LEFT JOIN dbo.BetType TN WITH (NOLOCK) ON TN.BetType = P.BetType
	WHERE TN.MainDBBetType IN (1,3,7,8)
		AND TN.[Disabled] = 0;

	DROP TABLE #TraderPerformanceTemp;
END;

GO
/*<info serverAlias="DBTGRS-bodb_TGRS" executers="bodbTGRSNet" isFunction="0" isNested="0"></info>*/