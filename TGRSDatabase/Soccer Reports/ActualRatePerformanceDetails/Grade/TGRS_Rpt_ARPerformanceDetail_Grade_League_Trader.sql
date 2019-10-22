ALTER PROCEDURE [dbo].[TGRS_Rpt_ARPerformanceDetail_Grade_League_Trader] 
		@FromDate				DATE
	,	@ToDate					DATE
	,	@Grade					INT
	,	@LeagueId				INT
	,	@IsExcludeLeagues		BIT = 1
	,	@Market					SMALLINT = 1
AS
/* 
	Created:	20190304@John
	Task :		New AR Performance Details (Juice & Leftover) Report - Grade - League - Trader
	DB:			DBTGRS.bodb_TGRS
	Original:  
	 
	Revisions:
		- 20190304@John: Create new [Redmine ID: #108920]		
		- 20190919@John.Ngo:	Support Nonlive Data [Redmine ID: 118959]

	Param's Explanation (filtered by):
		- @Market:	-1 All; 0 Nonlive; 1 Live
	
	Example: 
		EXEC [TGRS_Rpt_ARPerformanceDetail_Grade_League_Trader] @FromDate = '2019-02-13', @ToDate= '2019-03-05', @Grade = 1, @LeagueId = 1085
  
*/
BEGIN
	SET NOCOUNT ON;

	CREATE TABLE #TraderDetail (
		CustID INT
		,TeamId INT
		,LeagueCount INT
		,MatchCount INT
		,Turnover MONEY
		,TurnoverJuice MONEY
		,Juice MONEY
		,WinLoss MONEY
		,WinLossScore MONEY
		,BetCount INT
		,SumCategory MONEY
		,IsLive	BIT
	);

	INSERT INTO #TraderDetail (
		CustID
		,MatchCount
		,Turnover
		,TurnoverJuice
		,Juice
		,WinLoss
		,WinLossScore
		,BetCount
		,SumCategory
		,IsLive
	)
	SELECT tp.CustId AS CustId
		,COUNT(DISTINCT tp.MatchId) AS MatchCount
		,ISNULL(SUM(tp.StakeMYR_AR), 0) AS Turnover
		,ISNULL(SUM(tp.StakeMYRJuice_AR), 0) AS TurnoverJuice
		,ISNULL(SUM(tp.Juice_AR), 0) AS Juice
		,ISNULL(SUM(tp.WinLost_AR), 0) - ISNULL(SUM(tp.Comm_AR), 0) AS WinLoss
		,SUM((tp.WinLost_AR - tp.Comm_AR) * CASE 
				WHEN tp.Spread * tm.Rate IS NULL
					THEN 0
				ELSE 1
				END) AS WinLossScore
		,ISNULL(SUM(tp.BetCount), 0) AS BetCount
		,ISNULL(SUM(tp.StakeMYR_AR * ISNULL(s.BenchMark, tp.Spread * tm.Rate)), 0) AS SumCategory
		,tp.IsLive
	FROM dbo.TraderPerformance AS tp WITH (NOLOCK)
	INNER JOIN dbo.Trader AS t WITH (NOLOCK) ON tp.CustId = t.CustId
	LEFT JOIN dbo.TargetedMargin AS tm WITH (NOLOCK) ON tm.BetType = tp.BetType
		AND tm.WorkShift = tp.WorkShift
	LEFT JOIN dbo.Benchmark_SpecialSetting AS s WITH (NOLOCK) ON s.Spread = tp.Spread
		AND s.Rate = tm.Rate
	LEFT JOIN dbo.BetType TN WITH (NOLOCK) ON TN.BetType = tp.BetType
	WHERE tp.EventDate BETWEEN @FromDate AND @ToDate
		AND t.Grade = @Grade
		AND tp.LeagueId = @LeagueId
		AND TN.MainDBBetType IN (1,3,7,8)
		AND TN.[Disabled] = 0
		AND (@Market = -1 OR tp.IsLive = @Market)
		AND (@IsExcludeLeagues = 0 OR (tp.LeagueId NOT IN (SELECT le.LeagueId FROM dbo.LeagueExclusion le WITH(NOLOCK))))
	GROUP BY tp.CustId, tp.IsLive;

	SELECT td.CustID
		,t.Username AS TraderName
		,t.Grade
		,t.TeamId
		,tm.TeamName
		,td.MatchCount
		,td.Turnover
		,td.TurnoverJuice
		,td.Juice
		,td.WinLoss
		,td.BetCount
		,CASE 
			WHEN td.SumCategory = 0
				THEN NULL
			ELSE td.WinLossScore * 100 / td.SumCategory
			END AS Score
		,td.IsLive
	FROM #TraderDetail AS td
		INNER JOIN dbo.Trader AS t WITH (NOLOCK) ON t.CustId = td.CustID
		INNER JOIN dbo.Team AS tm WITH (NOLOCK) ON t.TeamId = tm.TeamId;

	DROP TABLE #TraderDetail;
END;

GO
/*<info serverAlias="DBTGRS-bodb_TGRS" executers="bodbTGRSNet" isFunction="0" isNested="0"></info>*/