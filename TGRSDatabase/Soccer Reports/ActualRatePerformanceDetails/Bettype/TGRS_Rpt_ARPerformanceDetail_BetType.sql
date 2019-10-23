ALTER PROCEDURE [dbo].[TGRS_Rpt_ARPerformanceDetail_BetType] 
		@FromDate			DATE
	,	@ToDate				DATE
	,	@IsExcludeLeagues	BIT = 1
	,	@Market				SMALLINT = 1
AS
/*
	Created:	20190304@John
	Task :		New AR Performance Details (Juice & Leftover) Report - BetType
	DB:			DBTGRS.bodb_TGRS
	Original:  
	 
	Revisions:
		- 20190304@John: Create new [Redmine ID: #108920]		
		- 20190919@John.Ngo:	Support Nonlive Data [Redmine ID: 118959]
		- 20191023@John.Ngo:	Enhance performance [Redmine ID: 121268]

	Param's Explanation (filtered by):
		- @Market:	-1 All; 0 Nonlive; 1 Live

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
		,P.IsLive
	INTO #TraderPerformanceTemp
	FROM dbo.TraderPerformance P WITH (NOLOCK)
		LEFT JOIN dbo.LeagueExclusion le WITH(NOLOCK) ON P.LeagueId = le.LeagueId
	WHERE P.EventDate BETWEEN @FromDate AND @ToDate
		AND (@Market = -1 OR P.IsLive = @Market)
		AND (@IsExcludeLeagues = 0 OR le.LeagueId IS NULL)
	GROUP BY P.BetType, P.IsLive;

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
		,P.IsLive
	FROM #TraderPerformanceTemp P
		LEFT JOIN dbo.BetType TN WITH (NOLOCK) ON TN.BetType = P.BetType
	WHERE TN.MainDBBetType IN (1,3,7,8)
		AND TN.[Disabled] = 0;

	DROP TABLE #TraderPerformanceTemp;
END;

GO
/*<info serverAlias="DBTGRS-bodb_TGRS" executers="bodbTGRSNet" isFunction="0" isNested="0"></info>*/