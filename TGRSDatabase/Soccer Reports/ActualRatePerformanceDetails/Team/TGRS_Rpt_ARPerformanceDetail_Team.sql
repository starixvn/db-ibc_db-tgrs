ALTER PROCEDURE [dbo].[TGRS_Rpt_ARPerformanceDetail_Team] 
		@FromDate			DATE
	,	@ToDate				DATE
	,	@TeamIds			VARCHAR(200) = '0'
	,	@IsExcludeLeagues	BIT = 1
	,	@Market				SMALLINT = 1
AS
/* 
	Created:	20190304@John
	Task :		New AR Performance Details (Juice & Leftover) Report - Team
	DB:			DBTGRS.bodb_TGRS
	Original:  
	 
	Revisions:
		- 20190304@John: Create new [Redmine ID: #108920]
		- 20190919@John.Ngo:	Support Nonlive Data [Redmine ID: 118959]

	Param's Explanation (filtered by):
		- @Market:	-1 All; 0 Nonlive; 1 Live
			
	Example:	
		EXECUTE	TGRS_Rpt_ARPerformanceDetail_Team @FromDate = '2019-02-22', @ToDate = '2019-03-05', @TeamIds = '0'

*/
BEGIN
	SET NOCOUNT ON;

	CREATE TABLE #ScoreDetail (
		 CustID INT
		,WinLoss MONEY
		,SumCategory MONEY
		,IsLive	BIT
	);

	DECLARE @TeamList TABLE (TeamId SMALLINT);

	DECLARE @Team TABLE (
		 TeamId SMALLINT
		,TeamName NVARCHAR(50)
		,TraderCount INT
		,LeagueCount INT
		,MatchCount INT
		,Turnover MONEY
		,TurnoverJuice MONEY
		,Juice MONEY
		,WinLoss MONEY
		,BetCount INT
		,Score MONEY
		,IsLive BIT
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
		,WinLoss
		,SumCategory
		,IsLive
	)
	SELECT tp.CustId
		,ISNULL(SUM(tp.WinLost_AR), 0) - ISNULL(SUM(tp.Comm_AR), 0) AS WinLoss
		,ISNULL(SUM(tp.StakeMYR_AR * ISNULL(s.BenchMark, tp.Spread * tm.Rate)), 0) AS SumCategory
		,tp.IsLive
	FROM dbo.TraderPerformance AS tp WITH (NOLOCK)
		INNER JOIN dbo.TargetedMargin AS tm WITH (NOLOCK) ON tm.BetType = tp.BetType
			AND tm.WorkShift = tp.WorkShift
		LEFT JOIN dbo.Benchmark_SpecialSetting AS s WITH (NOLOCK) ON s.Spread = tp.Spread
			AND s.Rate = tm.Rate
		LEFT JOIN dbo.BetType TN WITH (NOLOCK) ON TN.BetType = tp.BetType
	WHERE tp.EventDate BETWEEN @FromDate
			AND @ToDate
		AND TN.MainDBBetType IN (1,3,7,8)
		AND TN.[Disabled] = 0
		AND (@Market = -1 OR tp.IsLive = @Market)
		AND (@IsExcludeLeagues = 0 OR (tp.LeagueId NOT IN (SELECT le.LeagueId FROM dbo.LeagueExclusion le WITH(NOLOCK))))
	GROUP BY tp.CustId, tp.IsLive;

	WITH TeamDetail
	AS (
		SELECT t.TeamId
			,COUNT(DISTINCT tp.CustId) AS TraderCount
			,COUNT(DISTINCT tp.LeagueId) AS LeagueCount
			,COUNT(DISTINCT tp.MatchId) AS MatchCount
			,ISNULL(SUM(tp.StakeMYR_AR), 0) AS Turnover
			,ISNULL(SUM(tp.StakeMYRJuice_AR), 0) AS TurnoverJuice
			,ISNULL(SUM(tp.Juice_AR), 0) AS Juice
			,ISNULL(SUM(tp.WinLost_AR), 0) - ISNULL(SUM(tp.Comm_AR), 0) AS WinLoss
			,ISNULL(SUM(tp.BetCount), 0) AS BetCount
			,tp.IsLive
		FROM dbo.TraderPerformance AS tp WITH (NOLOCK)
			INNER JOIN dbo.Trader AS t WITH (NOLOCK) ON t.CustId = tp.CustId
			LEFT JOIN dbo.BetType TN WITH (NOLOCK) ON TN.BetType = tp.BetType
		WHERE tp.EventDate BETWEEN @FromDate
				AND @ToDate
			AND TN.MainDBBetType IN (1,3,7,8)
			AND t.TeamId IN (
				SELECT tl.TeamId
				FROM @TeamList AS tl
				)
			AND TN.[Disabled] = 0
			AND (@Market = -1 OR tp.IsLive = @Market)
			AND (@IsExcludeLeagues = 0 OR (tp.LeagueId NOT IN (SELECT le.LeagueId FROM dbo.LeagueExclusion le WITH(NOLOCK))))
		GROUP BY t.TeamId, tp.IsLive
		)
	INSERT INTO @Team (
		TeamId
		,TeamName
		,TraderCount
		,LeagueCount
		,MatchCount
		,Turnover
		,TurnoverJuice
		,Juice
		,WinLoss
		,BetCount
		,IsLive
	)
	SELECT td.TeamId
		,t.TeamName
		,td.TraderCount
		,td.LeagueCount
		,td.MatchCount
		,td.Turnover
		,td.TurnoverJuice
		,td.Juice
		,td.WinLoss
		,td.BetCount
		,td.IsLive
	FROM TeamDetail td
		INNER JOIN dbo.Team AS t WITH (NOLOCK) ON t.TeamId = td.TeamId;
	
	WITH score AS (
			SELECT t.TeamId
					,AVG(CASE 
						WHEN sd.SumCategory = 0
							THEN NULL
						ELSE sd.WinLoss * 100 / sd.SumCategory
						END) AS Score
					,sd.IsLive
			FROM #ScoreDetail AS sd WITH (NOLOCK)
			INNER JOIN dbo.Trader AS t WITH (NOLOCK) ON t.CustId = sd.CustID
			GROUP BY t.TeamId, sd.IsLive
			)
	UPDATE t
	SET t.Score = s.Score
	FROM @Team AS t
	INNER JOIN score AS s ON s.TeamId = t.TeamId AND s.IsLive = t.IsLive;

	SELECT t.TeamId
		,t.TeamName
		,t.TraderCount
		,t.LeagueCount
		,t.MatchCount
		,t.Turnover
		,t.TurnoverJuice
		,t.Juice
		,t.WinLoss
		,t.BetCount
		,t.Score
		,t.IsLive
	FROM @Team AS t;

	DROP TABLE #ScoreDetail;
END;

GO
/*<info serverAlias="DBTGRS-bodb_TGRS" executers="bodbTGRSNet" isFunction="0" isNested="0"></info>*/