
ALTER PROCEDURE [dbo].[TGRS_Rpt_NewPerformanceDetail_Bettype_League_Trader] 
		@FromDate				DATE
	,	@ToDate					DATE
	,	@LeagueId				INT
	,	@Bettype				SMALLINT
	,	@IsExcludeLeagues		BIT = 1
AS
/*  
 Created:	20170110@Aaron
 Task :		New Detail report - Trader detail from Bet Type and League
 DB:		DBTGRS.bodb_TGRS
 Original:  
 
 Revisions:      	
		- 20170316@Long: apply TO's Leftover
		- 20171205@Simon: get only Live data & Bettypes are not disabled
		- 20180911@Long:	Support excluding Leagues from report [Redmine ID: #100322]  
 
 Param's Explanation:  	

 Exam: 
	  	  exec TGRS_Rpt_NewPerformanceDetail_Bettype_League_Trader @Bettype=3,@LeagueId=10,@FromDate='2016-03-02 00:00:00',@ToDate='2016-03-16 00:00:00'
  
*/
BEGIN
	SET NOCOUNT ON;

	CREATE TABLE #TraderDetail (
			CustID			INT
		,	TeamId			INT
		,	MatchCount		INT
		,	Turnover		MONEY
		,	TurnoverJuice	MONEY
		,	Juice			MONEY
		,	WinLoss			MONEY
		,	WinLossScore	MONEY
		,	BetCount		INT
		,	SumCategory		MONEY
	);

	INSERT INTO #TraderDetail (
			CustID
		,	MatchCount
		,	Turnover
		,	TurnoverJuice
		,	Juice
		,	WinLoss
		,	WinLossScore
		,	BetCount
		,	SumCategory
	)
	SELECT tp.CustId AS CustId
		,COUNT(DISTINCT tp.MatchId) AS MatchCount
		,ISNULL(SUM(tp.StakeMYR), 0) AS Turnover
		,ISNULL(SUM(tp.StakeMYRJuice), 0) AS TurnoverJuice
		,ISNULL(SUM(tp.Juice), 0) AS Juice
		,ISNULL(SUM(tp.WinLost), 0) - ISNULL(SUM(tp.Comm), 0) AS WinLoss
		,SUM((tp.WinLost - tp.Comm) * CASE 
				WHEN tp.Spread * tm.Rate IS NULL
					THEN 0
				ELSE 1
				END) AS WinLossScore
		,ISNULL(SUM(tp.BetCount), 0) AS BetCount
		,ISNULL(SUM(tp.StakeMYR * ISNULL(s.BenchMark, tp.Spread * tm.Rate)), 0) AS SumCategory
	FROM dbo.TraderPerformance AS tp WITH (NOLOCK)
	LEFT JOIN dbo.TargetedMargin AS tm WITH (NOLOCK) ON tm.BetType = tp.BetType
		AND tm.WorkShift = tp.WorkShift
	LEFT JOIN dbo.Benchmark_SpecialSetting AS s WITH (NOLOCK) ON s.Spread = tp.Spread
		AND s.Rate = tm.Rate
	WHERE tp.LeagueId = @LeagueId
		AND tp.BetType = @Bettype
		AND tp.EventDate BETWEEN @FromDate AND @ToDate
		AND tp.IsLive = 1
		AND (@IsExcludeLeagues = 0 OR (tp.LeagueId NOT IN (SELECT le.LeagueId FROM dbo.LeagueExclusion le WHERE le.LeagueId = tp.LeagueId)))
	GROUP BY tp.CustId;

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
	FROM #TraderDetail AS td
		INNER JOIN dbo.Trader AS t WITH (NOLOCK) ON t.CustId = td.CustID
		INNER JOIN dbo.Team AS tm WITH (NOLOCK) ON t.TeamId = tm.TeamId;

	DROP TABLE #TraderDetail;
END;

/*
GO
GRANT EXECUTE ON [dbo].[TGRS_Rpt_NewPerformanceDetail_Bettype_League_Trader] TO [bodbTGRSNet]
GO
GRANT VIEW DEFINITION ON [dbo].[TGRS_Rpt_NewPerformanceDetail_Bettype_League_Trader] TO [bodbTGRSNet ]
GO
*/

/*<info serverAlias="DBTGRS-bodb_TGRS" executers="bodbTGRSNet" isFunction="0" isNested="0"></info>*/