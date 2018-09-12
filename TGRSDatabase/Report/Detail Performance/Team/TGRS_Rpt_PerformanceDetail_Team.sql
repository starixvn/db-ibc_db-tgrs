ALTER PROCEDURE [dbo].[TGRS_Rpt_PerformanceDetail_Team]  
					@FromDate		DATE
				,	@ToDate			DATE
				,	@TeamIds		VARCHAR(200) =  '0'
				,	@Turnover		MONEY = NULL
				,	@WinLoss		MONEY = NULL
				,	@MarginFrom		MONEY = NULL
				,	@MarginTo		MONEY = NULL
				,	@Bettypes		VARCHAR(2000) =  '0'
				,	@IsExcludeLeagues	BIT = 1
AS    
/*  
	Created:	20160218@Billy
	Task :		Performance Detail Report - Team
	DB:			DBTGRS.bodb_TGRS
	Original:  
	 
	Revisions:
		- 20160301@Billy: US011 - Modify Trader's Score - [Redmine: #53084]
		- 20160315@Thai: US018 - Modify Trader's Score - [Redmine: #53987]
		- 20171019@Simon: Change VARCHAR(200) to VARCHAR(2000)
		- 20171205@Simon: get only Live data & Bettypes are not disabled
		- 20180912@Simon: add league exclusion

	Param's Explanation:  	
	
	Example: 	
		EXECUTE	TGRS_Rpt_PerformanceDetail_Team 
					@FromDate = '2016-02-22'
				,	@ToDate = '2016-03-14'
				,	@Bettypes = '1,3,5', @TeamIds = '0'
*/  
 
BEGIN 
	 
	SET NOCOUNT ON;  
	 
	CREATE TABLE #ScoreDetail (
			CustID			INT
		,	WinLoss			MONEY
		,	SumCategory		MONEY
	);

	DECLARE	@BettypeList TABLE (
			BetType			SMALLINT
	);
	DECLARE	@TeamList TABLE (
			TeamId			SMALLINT
	);
	DECLARE	@Team TABLE (
			TeamId			SMALLINT
		,	TeamName		NVARCHAR(50)
		,	TraderCount		INT
		,	LeagueCount		INT
		,	MatchCount		INT
		,	Turnover		MONEY
		,	WinLoss			MONEY
		,	BetCount		INT
		,	Margin			MONEY
		,	Score			MONEY
	);

	IF	@Bettypes <> '0'
		 INSERT INTO @BettypeList
		 	(	bettype)
		 SELECT ssk.val
		 FROM	dbo.strSplit_Key(@Bettypes, ',') ssk;
	ELSE 
		 INSERT INTO @BettypeList
		 	(	bettype)
		 SELECT bt.BetType 
		 FROM	dbo.BetType AS bt WITH (NOLOCK);

	IF	@TeamIds <> '0'
		 INSERT INTO @TeamList
		 	(	TeamId)
		 SELECT ssk.val
		 FROM	dbo.strSplit_Key(@TeamIds, ',') ssk;
	ELSE 
		 INSERT INTO @TeamList
		 	(	TeamId)
		 SELECT	t.TeamId
		 FROM	dbo.Team AS t WITH (NOLOCK);

	INSERT INTO	#ScoreDetail (
			CustID
		,	WinLoss
		,	SumCategory
	)
	SELECT	tp.CustId
		,	ISNULL(SUM(tp.WinLost), 0) - ISNULL(SUM(tp.Comm), 0)	AS WinLoss				
		,	ISNULL(SUM(tp.Stake * ISNULL(s.BenchMark, tp.Spread * tm.Rate)), 0) AS SumCategory
	FROM		dbo.TraderPerformance AS tp WITH (NOLOCK)
		INNER JOIN	dbo.TargetedMargin AS tm WITH (NOLOCK)
				ON	tm.BetType = tp.BetType
				AND	tm.WorkShift = tp.WorkShift
		LEFT JOIN dbo.Benchmark_SpecialSetting AS s WITH (NOLOCK)
				ON	s.Spread = tp.Spread
				AND	s.Rate = tm.Rate
	WHERE	tp.EventDate BETWEEN @FromDate AND @ToDate
		AND	tp.BetType IN (SELECT bl.bettype FROM @BettypeList AS bl)
		AND tp.IsLive = 1
		AND (@IsExcludeLeagues = 0 OR (tp.LeagueId NOT IN (SELECT le.LeagueId FROM dbo.LeagueExclusion le WHERE le.LeagueId = tp.LeagueId)))
	GROUP BY	tp.CustId;

	WITH TeamDetail AS (
		SELECT	t.TeamId
			,	COUNT(DISTINCT tp.CustId)								AS TraderCount
			,	COUNT(DISTINCT tp.LeagueId)								AS LeagueCount
			,	COUNT(DISTINCT tp.MatchId)								AS MatchCount
			,	ISNULL(SUM(tp.Stake), 0)								AS Turnover
			,	ISNULL(SUM(tp.WinLost), 0) - ISNULL(SUM(tp.Comm), 0)	AS WinLoss
			,	ISNULL(SUM(tp.BetCount), 0)								AS BetCount
			,	CASE	WHEN ISNULL(SUM(tp.Stake), 0) = 0
						THEN NULL
						ELSE (ISNULL(SUM(tp.WinLost), 0) - ISNULL(SUM(tp.Comm), 0)) * 100 / ISNULL(SUM(tp.Stake), 0)
				END														AS Margin
		FROM		dbo.TraderPerformance AS tp WITH (NOLOCK)
		INNER JOIN	dbo.Trader AS t WITH (NOLOCK)
				ON	t.CustId = tp.CustId
		WHERE	tp.EventDate BETWEEN @FromDate AND @ToDate
			AND	tp.BetType IN (SELECT bl.BetType FROM @BettypeList AS bl)
			AND	t.TeamId IN (SELECT tl.TeamId FROM @TeamList AS tl)
			AND tp.IsLive = 1
			AND (@IsExcludeLeagues = 0 OR (tp.LeagueId NOT IN (SELECT le.LeagueId FROM dbo.LeagueExclusion le WHERE le.LeagueId = tp.LeagueId)))
		GROUP BY	t.TeamId
	)
	INSERT INTO @Team
		(	TeamId   , TeamName  , TraderCount   , LeagueCount   , MatchCount   , Turnover   , WinLoss   , BetCount   , Margin   )
	SELECT	td.TeamId, t.TeamName, td.TraderCount, td.LeagueCount, td.MatchCount, td.Turnover, td.WinLoss, td.BetCount, td.Margin
	FROM		TeamDetail td
		INNER JOIN	dbo.Team AS t WITH (NOLOCK)
				ON	t.TeamId = td.TeamId
	WHERE	(@Turnover IS NULL OR td.Turnover >= @Turnover)
		AND	(@WinLoss IS NULL OR td.WinLoss >= @WinLoss)
		AND	(@MarginFrom IS NULL OR td.Margin >= @MarginFrom)
		AND	(@MarginTo IS NULL OR td.Margin <= @MarginTo);

	WITH score AS (
		SELECT	t.TeamId
			,	AVG(CASE WHEN sd.SumCategory = 0 THEN NULL ELSE sd.WinLoss * 100 / sd.SumCategory END) AS Score
		FROM	#ScoreDetail AS sd WITH (NOLOCK)
		INNER JOIN	dbo.Trader AS t WITH (NOLOCK)
				ON	t.CustId = sd.CustID
		GROUP BY t.TeamId
	)
	UPDATE  t
	SET		t.Score = s.Score
	FROM		@Team AS t
	INNER JOIN	score AS s
			ON	s.TeamId = t.TeamId;

	SELECT	t.TeamId
		,	t.TeamName
		,	t.TraderCount
		,	t.LeagueCount
		,	t.MatchCount
		,	t.Turnover
		,	t.WinLoss
		,	t.BetCount
		,	t.Margin
		,	t.Score 
	FROM	@Team AS t
	ORDER BY	Margin DESC
			,	TeamName ASC;
	
	DROP TABLE #ScoreDetail;
END;