
/****** Object:  Stored Procedure dbo.TGRS_Rpt_NewPerformanceDetail_Grade    Script Date: 1/17/2017 11:20:00 AM ******/

CREATE PROCEDURE [dbo].[TGRS_Rpt_NewPerformanceDetail_Grade] 
	 @FromDate DATE
	,@ToDate DATE
AS
/*  
	Created:	20170106@Aaron
	Task :		New Performance Detail Report - Grade
	DB:			DBTGRS.bodb_TGRS
	Original:  
	 
	Revisions:
		- 20170316@Long: apply TO's Leftover
		- 20171205@Simon: get only Live data & Bettypes are not disabled

	Param's Explanation:  	
	
	Example: 	
				EXECUTE	TGRS_Rpt_NewPerformanceDetail_Grade  
					@FromDate = '2016-02-15 00:00:00'
				,	@ToDate = '2016-03-14 00:00:00'
*/
BEGIN
	SET NOCOUNT ON;

	CREATE TABLE #ScoreDetail (
		CustID INT
		,WinLoss MONEY
		,SumCategory MONEY
	);

	DECLARE @Grade TABLE (
		Grade TINYINT
		,TraderCount INT
		,LeagueCount INT
		,MatchCount INT
		,Turnover MONEY
		,TurnoverJuice MONEY
		,Juice MONEY
		,WinLoss MONEY
		,BetCount INT
		,Score MONEY
	);

	INSERT INTO #ScoreDetail (
		CustID
		,WinLoss
		,SumCategory
	)
	SELECT tp.CustId
		,ISNULL(SUM(tp.WinLost), 0) - ISNULL(SUM(tp.Comm), 0) AS WinLoss
		,ISNULL(SUM(tp.StakeMYR * ISNULL(s.BenchMark, tp.Spread * tm.Rate)), 0) AS SumCategory
	FROM dbo.TraderPerformance AS tp WITH (NOLOCK)
		INNER JOIN dbo.TargetedMargin AS tm WITH (NOLOCK) ON tm.BetType = tp.BetType
			AND tm.WorkShift = tp.WorkShift
		LEFT JOIN dbo.Benchmark_SpecialSetting AS s WITH (NOLOCK) ON s.Spread = tp.Spread
			AND s.Rate = tm.Rate	
		LEFT JOIN dbo.BetType TN WITH (NOLOCK) ON TN.BetType = tp.BetType
	WHERE tp.EventDate BETWEEN @FromDate AND @ToDate
		AND TN.MainDBBetType IN (1,3,7,8)
		AND TN.[Disabled] = 0
		AND tp.IsLive = 1
	GROUP BY tp.CustId;

	WITH GradeDetail
	AS (
		SELECT t.Grade AS Grade
			,COUNT(DISTINCT tp.CustId) AS TraderCount
			,COUNT(DISTINCT tp.LeagueId) AS LeagueCount
			,COUNT(DISTINCT tp.MatchId) AS MatchCount
			,ISNULL(SUM(tp.StakeMYR), 0) AS Turnover
			,ISNULL(SUM(tp.StakeMYRJuice), 0) AS TurnoverJuice
			,ISNULL(SUM(tp.Juice), 0) AS Juice
			,ISNULL(SUM(tp.WinLost), 0) - ISNULL(SUM(tp.Comm), 0) AS WinLoss
			,ISNULL(SUM(tp.BetCount), 0) AS BetCount
		FROM dbo.TraderPerformance AS tp WITH (NOLOCK)
		INNER JOIN dbo.Trader AS t WITH (NOLOCK) ON t.CustId = tp.CustId
		LEFT JOIN dbo.BetType TN WITH (NOLOCK) ON TN.BetType = tp.BetType
		WHERE tp.EventDate BETWEEN @FromDate AND @ToDate
			AND TN.MainDBBetType IN (1,3,7,8)
			AND TN.[Disabled] = 0
			AND tp.IsLive = 1
		GROUP BY t.Grade
		)
	INSERT INTO @Grade (
		Grade
		,TraderCount
		,LeagueCount
		,MatchCount
		,Turnover
		,TurnoverJuice
		,Juice
		,WinLoss
		,BetCount
		)
	SELECT gd.Grade
		,gd.TraderCount
		,gd.LeagueCount
		,gd.MatchCount
		,gd.Turnover
		,gd.TurnoverJuice
		,gd.Juice
		,gd.WinLoss
		,gd.BetCount
	FROM GradeDetail gd;

	WITH Score
	AS (
		SELECT t.Grade
			,AVG(CASE 
					WHEN sd.SumCategory = 0
						THEN NULL
					ELSE sd.WinLoss * 100 / sd.SumCategory
					END) AS Score
		FROM #ScoreDetail AS sd WITH (NOLOCK)
		INNER JOIN dbo.Trader AS t WITH (NOLOCK) ON t.CustId = sd.CustID
		GROUP BY t.Grade
		)
	UPDATE g
	SET g.Score = s.Score
	FROM @Grade AS g
	INNER JOIN score AS s ON s.Grade = g.Grade;

	SELECT Grade
		,TraderCount
		,LeagueCount
		,MatchCount
		,Turnover
		,TurnoverJuice
		,Juice
		,WinLoss
		,BetCount
		,Score
	FROM @Grade g;

	DROP TABLE #ScoreDetail;
END;
/*
GO
GRANT EXECUTE ON [dbo].[TGRS_Rpt_NewPerformanceDetail_Grade] TO [bodbTGRSNet]
GO
GRANT VIEW DEFINITION ON [dbo].[TGRS_Rpt_NewPerformanceDetail_Grade] TO [bodbTGRSNet ]
GO
*/