
/****** Object:  Stored Procedure dbo.TGRS_Rpt_NewPerformanceDetail_Grade_Trader    Script Date: 1/17/2017 11:20:00 AM ******/

/****** Object:  Stored Procedure dbo.TGRS_Rpt_PerformanceDetail_Grade_Trader    Script Date: 4/1/2016 8:22:17 AM ******/
CREATE PROCEDURE [dbo].[TGRS_Rpt_NewPerformanceDetail_Grade_Trader] 
	 @FromDate DATE
	,@ToDate DATE
	,@Grade INT
AS
/*  
	Created:	20170109@Aaron
	Task:		New Detail report Grade Performance - Detail Trader
	DB:			DBTGRS.bodb_TGRS
	Original:  
	 
	Revisions:
		- 20170316@Long: apply TO's Leftover
	  			
	Param's Explanation:  	
	
	Example: 
		EXEC [TGRS_Rpt_PerformanceDetail_Grade_Trader] @FromDate = '2016-03-01', @ToDate= '2017-03-28', @Grade = 1
  
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
	SELECT tp.CustId AS CustId
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
	INNER JOIN dbo.Trader AS t WITH (NOLOCK) ON tp.CustId = t.CustId
	LEFT JOIN dbo.TargetedMargin AS tm WITH (NOLOCK) ON tm.BetType = tp.BetType
		AND tm.WorkShift = tp.WorkShift
	LEFT JOIN dbo.Benchmark_SpecialSetting AS s WITH (NOLOCK) ON s.Spread = tp.Spread
		AND s.Rate = tm.Rate
	LEFT JOIN dbo.BetType TN WITH (NOLOCK) ON TN.BetType = tp.BetType
	WHERE tp.EventDate BETWEEN @FromDate
			AND @ToDate
		AND t.Grade = @Grade
		AND TN.MainDBBetType IN (1,3,7,8)
		AND TN.[Disabled] = 0
		AND tp.IsLive = 1
	GROUP BY tp.CustId;

	SELECT td.CustID
		,t.Username AS TraderName
		,t.Grade
		,t.TeamId
		,tm.TeamName
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
	INNER JOIN dbo.Trader AS t WITH (NOLOCK) ON t.CustId = td.CustID
	INNER JOIN dbo.Team AS tm WITH (NOLOCK) ON t.TeamId = tm.TeamId

	DROP TABLE #TraderDetail;
END;

/*
GO
GRANT EXECUTE ON [dbo].[TGRS_Rpt_NewPerformanceDetail_Grade_Trader] TO [bodbTGRSNet]
GO
GRANT VIEW DEFINITION ON [dbo].[TGRS_Rpt_NewPerformanceDetail_Grade_Trader] TO [bodbTGRSNet ]
GO
*/