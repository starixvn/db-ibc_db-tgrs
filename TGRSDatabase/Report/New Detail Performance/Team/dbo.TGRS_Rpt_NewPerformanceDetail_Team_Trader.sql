
/****** Object:  Stored Procedure dbo.TGRS_Rpt_NewPerformanceDetail_Team_Trader    Script Date: 1/17/2017 11:20:01 AM ******/

/****** Object:  Stored Procedure dbo.TGRS_Rpt_PerformanceDetail_Team_Trader    Script Date: 4/1/2016 8:22:16 AM ******/
CREATE PROCEDURE [dbo].[TGRS_Rpt_NewPerformanceDetail_Team_Trader] 
	 @FromDate DATE
	,@ToDate DATE
	,@TeamId SMALLINT
AS
/*
  Created:		20170111@Aaron
  Task :		New Performance Detail Report - Trader
  DB:			DBTGRS.bodb_TGRS
  Original:

  Revisions:
		- 20170316@Long: apply TO's Leftover

  Param's Explanation:

  Example:
    EXECUTE	TGRS_Rpt_NewPerformanceDetail_Team_Trader
            @FromDate = '2013-01-01'
          ,	@ToDate= '2014-05-31'
          ,	@TeamId = '1'
*/
BEGIN
	SET NOCOUNT ON;

	CREATE TABLE #TraderDetail (
		CustID INT
		,LeagueCount INT
		,MatchCount INT
		,Turnover MONEY
		,TurnoverJuice MONEY
		,Juice MONEY
		,WinLoss MONEY
		,WinLossScore MONEY
		,BetCount INT
		,SumCategory MONEY
		);

	INSERT INTO #TraderDetail (
		CustID
		,LeagueCount
		,MatchCount
		,Turnover
		,TurnoverJuice
		,Juice
		,WinLoss
		,WinLossScore
		,BetCount
		,SumCategory
		)
	SELECT tp.CustId
		,COUNT(DISTINCT tp.LeagueId) AS LeagueCount
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
	INNER JOIN dbo.Trader AS t WITH (NOLOCK) ON t.CustId = tp.CustId
	LEFT JOIN dbo.TargetedMargin AS tm WITH (NOLOCK) ON tm.BetType = tp.BetType
		AND tm.WorkShift = tp.WorkShift
	LEFT JOIN dbo.Benchmark_SpecialSetting AS s WITH (NOLOCK) ON s.Spread = tp.Spread
		AND s.Rate = tm.Rate
	LEFT JOIN dbo.BetType TN WITH (NOLOCK) ON TN.BetType = tp.BetType
	WHERE tp.EventDate BETWEEN @FromDate AND @ToDate
		AND t.TeamId = @TeamId
		AND TN.MainDBBetType IN (1,3,7,8)
		AND TN.[Disabled] = 0
		AND tp.IsLive = 1
	GROUP BY tp.CustId;

	SELECT td.CustId
		,t.Username AS TraderName
		,t.Grade
		,td.LeagueCount
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
	INNER JOIN dbo.Trader AS t WITH (NOLOCK) ON t.CustId = td.CustId
	INNER JOIN dbo.Team AS tm WITH (NOLOCK) ON t.TeamId = tm.TeamId

	DROP TABLE #TraderDetail;
END;
/*
GO
GRANT EXECUTE ON [dbo].[TGRS_Rpt_NewPerformanceDetail_Team_Trader] TO [bodbTGRSNet]
GO
GRANT VIEW DEFINITION ON [dbo].[TGRS_Rpt_NewPerformanceDetail_Team_Trader] TO [bodbTGRSNet ]
GO
*/