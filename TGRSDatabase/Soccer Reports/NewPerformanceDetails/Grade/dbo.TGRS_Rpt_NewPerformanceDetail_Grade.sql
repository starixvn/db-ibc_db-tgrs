
ALTER PROCEDURE [dbo].[TGRS_Rpt_NewPerformanceDetail_Grade] 
		@FromDate				DATE
	,	@ToDate					DATE
	,	@IsExcludeLeagues		BIT = 1
	,	@Market					SMALLINT = 1
AS
/*  
	Created:	20170106@Aaron
	Task :		New Performance Detail Report - Grade
	DB:			DBTGRS.bodb_TGRS
	Original:  
	 
	Revisions:
		- 20170316@Long.Luu:	apply TO's Leftover
		- 20171205@Simon:		get only Live data & Bettypes are not disabled
		- 20180911@Long.Luu:	Support excluding Leagues from report [Redmine ID: #100322]  
		- 20190919@Long.Luu:	Support Nonlive Data [Redmine ID: 118959]

	Param's Explanation:  	
		- @Market: -1 All; 0 Nonlive; 1 Live
	
	Example: 	
				EXECUTE	TGRS_Rpt_NewPerformanceDetail_Grade  
					@FromDate = '2016-02-15 00:00:00'
				,	@ToDate = '2016-03-14 00:00:00'
*/
BEGIN
	SET NOCOUNT ON;

	CREATE TABLE #ScoreDetail (
			CustID			INT
		,	IsLive			BIT
		,	WinLoss			MONEY
		,	SumCategory		MONEY
	);

	DECLARE @Grade TABLE (
			Grade			TINYINT
		,	TraderCount		INT
		,	LeagueCount		INT
		,	MatchCount		INT
		,	Turnover		MONEY
		,	TurnoverJuice	MONEY
		,	Juice			MONEY
		,	WinLoss			MONEY
		,	BetCount		INT
		,	Score			MONEY
		,	IsLive			BIT
	);

	INSERT INTO #ScoreDetail (
			CustID
		,	IsLive
		,	WinLoss
		,	SumCategory
	)
	SELECT	tp.CustId
		,	tp.IsLive
		,	ISNULL(SUM(tp.WinLost), 0) - ISNULL(SUM(tp.Comm), 0) AS WinLoss
		,	ISNULL(SUM(tp.StakeMYR * ISNULL(s.BenchMark, tp.Spread * tm.Rate)), 0) AS SumCategory
	FROM dbo.TraderPerformance AS tp WITH (NOLOCK)
		INNER JOIN dbo.TargetedMargin AS tm WITH (NOLOCK) ON tm.BetType = tp.BetType AND tm.WorkShift = tp.WorkShift
		LEFT JOIN dbo.Benchmark_SpecialSetting AS s WITH (NOLOCK) ON s.Spread = tp.Spread AND s.Rate = tm.Rate	
		LEFT JOIN dbo.BetType AS TN WITH (NOLOCK) ON TN.BetType = tp.BetType
	WHERE tp.EventDate BETWEEN @FromDate AND @ToDate
		AND TN.MainDBBetType IN (1, 3, 7, 8)
		AND TN.[Disabled] = 0
		AND (@Market = -1 OR tp.IsLive = @Market)
		AND (@IsExcludeLeagues = 0 OR (tp.LeagueId NOT IN (SELECT le.LeagueId FROM dbo.LeagueExclusion AS le WITH(NOLOCK))))
	GROUP BY tp.CustId, tp.IsLive;

	WITH GradeDetail
	AS (
		SELECT	t.Grade AS Grade
			,	tp.IsLive AS IsLive
			,	COUNT(DISTINCT tp.CustId) AS TraderCount
			,	COUNT(DISTINCT tp.LeagueId) AS LeagueCount
			,	COUNT(DISTINCT tp.MatchId) AS MatchCount
			,	ISNULL(SUM(tp.StakeMYR), 0) AS Turnover
			,	ISNULL(SUM(tp.StakeMYRJuice), 0) AS TurnoverJuice
			,	ISNULL(SUM(tp.Juice), 0) AS Juice
			,	ISNULL(SUM(tp.WinLost), 0) - ISNULL(SUM(tp.Comm), 0) AS WinLoss
			,	ISNULL(SUM(tp.BetCount), 0) AS BetCount
		FROM dbo.TraderPerformance AS tp WITH (NOLOCK)
			INNER JOIN dbo.Trader AS t WITH (NOLOCK) ON t.CustId = tp.CustId
			LEFT JOIN dbo.BetType AS TN WITH (NOLOCK) ON TN.BetType = tp.BetType
		WHERE tp.EventDate BETWEEN @FromDate AND @ToDate
			AND TN.MainDBBetType IN (1,3,7,8)
			AND TN.[Disabled] = 0
			AND (@Market = -1 OR tp.IsLive = @Market)
			AND (@IsExcludeLeagues = 0 OR (tp.LeagueId NOT IN (SELECT le.LeagueId FROM dbo.LeagueExclusion AS le WITH(NOLOCK))))
		GROUP BY t.Grade, tp.IsLive
		)
	INSERT INTO @Grade (
			Grade
		,	IsLive
		,	TraderCount
		,	LeagueCount
		,	MatchCount
		,	Turnover
		,	TurnoverJuice
		,	Juice
		,	WinLoss
		,	BetCount
	)
	SELECT	gd.Grade
		,	gd.IsLive
		,	gd.TraderCount
		,	gd.LeagueCount
		,	gd.MatchCount
		,	gd.Turnover
		,	gd.TurnoverJuice
		,	gd.Juice
		,	gd.WinLoss
		,	gd.BetCount
	FROM GradeDetail gd;

	WITH Score
	AS (
		SELECT	t.Grade
			,	sd.IsLive
			,	AVG(CASE 
					WHEN sd.SumCategory = 0
						THEN NULL
					ELSE sd.WinLoss * 100 / sd.SumCategory
					END) AS Score
		FROM #ScoreDetail AS sd WITH (NOLOCK)
			INNER JOIN dbo.Trader AS t WITH (NOLOCK) ON t.CustId = sd.CustID
		GROUP BY t.Grade, sd.IsLive
		)
	UPDATE g
	SET g.Score = s.Score
	FROM @Grade AS g
	INNER JOIN score AS s ON s.Grade = g.Grade AND s.IsLive = g.IsLive;

	SELECT	Grade
		,	IsLive
		,	TraderCount
		,	LeagueCount
		,	MatchCount
		,	Turnover
		,	TurnoverJuice
		,	Juice
		,	WinLoss
		,	BetCount
		,	Score
	FROM @Grade g;

	DROP TABLE #ScoreDetail;
END;

GO
/*<info serverAlias="DBTGRS-bodb_TGRS" executers="bodbTGRSNet" isFunction="0" isNested="0"></info>*/