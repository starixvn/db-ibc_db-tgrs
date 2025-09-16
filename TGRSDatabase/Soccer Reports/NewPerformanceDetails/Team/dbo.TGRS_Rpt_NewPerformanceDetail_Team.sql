ALTER PROCEDURE [dbo].[TGRS_Rpt_NewPerformanceDetail_Team] 
		@FromDate			DATE
	,	@ToDate				DATE
	,	@TeamIds			VARCHAR(200) = '0'
	,	@IsExcludeLeagues	BIT = 1
	,	@Market				SMALLINT = 1
AS
/*  
	Created:	20170111@Aaron
	Task :		New Performance Detail Report - Team
	DB:			DBTGRS.bodb_TGRS
	Original:  
	 
	Revisions:
		- 20170316@Long.Luu:	apply TO's Leftover
		- 20171205@Simon:		get only Live data & Bettypes are not disabled
		- 20180912@Simon:		add league exclusion
		- 20190919@Long.Luu:	Support Nonlive Data [Redmine ID: 118959]
		- 20191023@John.Ngo:	Enhance performance [Redmine ID: 121268]
		- 20250916@Jaden.Tang: Use new table TraderJuicePerformance [Redmine ID: 237899]

	Param's Explanation:  
		- @Market: -1 All; 0 Nonlive; 1 Live	
	
	Example: 	
		EXECUTE	TGRS_Rpt_NewPerformanceDetail_Team  @FromDate = '2016-02-22', @ToDate = '2016-03-14', @TeamIds = '0';

*/
BEGIN
	SET NOCOUNT ON;

	CREATE TABLE #ScoreDetail (
			CustID			INT
		,	IsLive			BIT
		,	WinLoss			MONEY
		,	SumCategory		MONEY
	);

	DECLARE @TeamList TABLE (TeamId SMALLINT);

	DECLARE @Team TABLE (
			TeamId			SMALLINT
		,	TeamName		NVARCHAR(50)
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

	IF @TeamIds <> '0'
		INSERT INTO @TeamList (TeamId)
		SELECT ssk.val
		FROM dbo.strSplit_Key(@TeamIds, ',') ssk;
	ELSE
		INSERT INTO @TeamList (TeamId)
		SELECT t.TeamId
		FROM dbo.Team AS t WITH (NOLOCK);

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
	FROM dbo.TraderJuicePerformance AS tp WITH (NOLOCK)
		INNER JOIN dbo.TargetedMargin AS tm WITH (NOLOCK) ON tm.BetType = tp.BetType AND tm.WorkShift = tp.WorkShift
		LEFT JOIN dbo.Benchmark_SpecialSetting AS s WITH (NOLOCK) ON s.Spread = tp.Spread AND s.Rate = tm.Rate
		LEFT JOIN dbo.LeagueExclusion le WITH(NOLOCK) ON tp.LeagueId = le.LeagueId
		LEFT JOIN dbo.BetType AS TN WITH (NOLOCK) ON TN.BetType = tp.BetType
	WHERE tp.EventDate BETWEEN @FromDate AND @ToDate
		AND TN.MainDBBetType IN (1, 3, 7, 8)
		AND TN.[Disabled] = 0
		AND (@Market = -1 OR tp.IsLive = @Market)
		AND (@IsExcludeLeagues = 0 OR le.LeagueId IS NULL)
	GROUP BY tp.CustId, tp.IsLive;

	WITH TeamDetail
	AS (
		SELECT	t.TeamId
			,	tp.IsLive
			,	COUNT(DISTINCT tp.CustId) AS TraderCount
			,	COUNT(DISTINCT tp.LeagueId) AS LeagueCount
			,	COUNT(DISTINCT tp.MatchId) AS MatchCount
			,	ISNULL(SUM(tp.StakeMYR), 0) AS Turnover
			,	ISNULL(SUM(tp.StakeMYRJuice), 0) AS TurnoverJuice
			,	ISNULL(SUM(tp.Juice), 0) AS Juice
			,	ISNULL(SUM(tp.WinLost), 0) - ISNULL(SUM(tp.Comm), 0) AS WinLoss
			,	ISNULL(SUM(tp.BetCount), 0) AS BetCount
		FROM dbo.TraderJuicePerformance AS tp WITH (NOLOCK)
			INNER JOIN dbo.Trader AS t WITH (NOLOCK) ON t.CustId = tp.CustId
			LEFT JOIN dbo.BetType AS TN WITH (NOLOCK) ON TN.BetType = tp.BetType
			LEFT JOIN dbo.LeagueExclusion le WITH(NOLOCK) ON tp.LeagueId = le.LeagueId
		WHERE tp.EventDate BETWEEN @FromDate AND @ToDate
			AND TN.MainDBBetType IN (1, 3, 7, 8)
			AND t.TeamId IN (SELECT tl.TeamId FROM @TeamList AS tl)
			AND TN.[Disabled] = 0
			AND (@Market = -1 OR tp.IsLive = @Market)
			AND (@IsExcludeLeagues = 0 OR le.LeagueId IS NULL)
		GROUP BY t.TeamId, tp.IsLive
		)
	INSERT INTO @Team (
			TeamId
		,	TeamName
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
	SELECT	td.TeamId
		,	t.TeamName
		,	td.IsLive
		,	td.TraderCount
		,	td.LeagueCount
		,	td.MatchCount
		,	td.Turnover
		,	td.TurnoverJuice
		,	td.Juice
		,	td.WinLoss
		,	td.BetCount
	FROM TeamDetail AS td
		INNER JOIN dbo.Team AS t WITH (NOLOCK) ON t.TeamId = td.TeamId;
	
	WITH score AS (
			SELECT t.TeamId
				,	sd.IsLive
				,	AVG(CASE 
						WHEN sd.SumCategory = 0
							THEN NULL
						ELSE sd.WinLoss * 100 / sd.SumCategory
						END) AS Score
			FROM #ScoreDetail AS sd WITH (NOLOCK)
				INNER JOIN dbo.Trader AS t WITH (NOLOCK) ON t.CustId = sd.CustID
			GROUP BY t.TeamId, sd.IsLive
			)
	UPDATE t
	SET t.Score = s.Score
	FROM @Team AS t
		INNER JOIN score AS s ON s.TeamId = t.TeamId AND s.IsLive = t.IsLive;

	SELECT	t.TeamId
		,	t.TeamName
		,	t.IsLive
		,	t.TraderCount
		,	t.LeagueCount
		,	t.MatchCount
		,	t.Turnover
		,	t.TurnoverJuice
		,	t.Juice
		,	t.WinLoss
		,	t.BetCount
		,	t.Score
	FROM @Team AS t;

	DROP TABLE #ScoreDetail;
END;

GO
/*<info serverAlias="DBTGRS-bodb_TGRS" executers="wsv_tgrs" isFunction="0" isNested="0"></info>*/