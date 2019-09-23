ALTER PROCEDURE	[dbo].[TGRS_Rpt_PerformanceDetail_Grade]  
		@FromDate			DATE
	,	@ToDate				DATE
	,	@Turnover			MONEY			= NULL
	,	@WinLoss			MONEY			= NULL
	,	@MarginFrom			MONEY			= NULL
	,	@MarginTo			MONEY			= NULL
	,	@Bettypes			VARCHAR(2000)	= '0'
	,	@IsExcludeLeagues	BIT				= 1
	,	@Market				SMALLINT		= 1
AS
/*  
	Created:	20160217@Billy
	Task :		Performance Detail Report - Grade
	DB:			DBTGRS.bodb_TGRS
	Original:  
	 
	Revisions:
		- 20160301@Billy:		US011 - Modify Trader's Score - [Redmine: #53084]
		- 20160315@Thai:		US018 - Modify Trader's Score - [Redmine: #53987]
		- 20171019@Simon:		Change VARCHAR(200) to VARCHAR(2000)
		- 20171205@Simon:		get only Live data & Bettypes are not disabled
		- 20180912@Simon:		add league exclusion
		- 20190822@Long.Luu:	grade brokendown for details performance [Redmine ID: 117030]
		- 20190919@Long.Luu:	Support Nonlive Data [Redmine ID: 118959]

	Param's Explanation:  
		- @Market: -1 All; 0 Nonlive; 1 Live	
	
	Example: 	
		EXECUTE	TGRS_Rpt_PerformanceDetail_Grade  
					@FromDate = '2016-02-15 00:00:00'
				,	@WinLoss = NULL
				,	@Turnover = NULL
				,	@MarginTo = NULL
				,	@MarginFrom = NULL
				,	@Bettypes = '1,3,5'
				,	@ToDate = '2016-03-14 00:00:00'
*/  
 
BEGIN 	
	SET NOCOUNT ON;  
	 
	CREATE TABLE #ScoreDetail (
			CustID			INT
		,	Grade			TINYINT
		,	WinLoss			MONEY
		,	SumCategory		MONEY
		,	IsLive			BIT
	);

	DECLARE	@BettypeList	TABLE (
			bettype			SMALLINT
	);

	DECLARE	@Grade			TABLE (
			Grade			TINYINT
		,	TraderCount		INT
		,	LeagueCount		INT
		,	MatchCount		INT
		,	Turnover		MONEY
		,	WinLoss			MONEY
		,	BetCount		INT
		,	Margin			MONEY
		,	Score			MONEY
		,	IsLive			BIT
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

	INSERT INTO	#ScoreDetail (
			CustID
		,	Grade
		,	IsLive
		,	WinLoss
		,	SumCategory
	)
	SELECT	tp.CustId
		,	tp.Grade
		,	tp.IsLive
		,	ISNULL(SUM(tp.WinLost), 0) - ISNULL(SUM(tp.Comm), 0)	AS WinLoss		
		,	ISNULL(SUM(tp.Stake * ISNULL(s.BenchMark, tp.Spread * tm.Rate)), 0) AS SumCategory
	FROM		dbo.TraderPerformance AS tp WITH (NOLOCK)
	INNER JOIN	dbo.TargetedMargin AS tm WITH (NOLOCK)
			ON	tm.BetType = tp.BetType
			AND	tm.WorkShift = tp.WorkShift
	LEFT JOIN dbo.Benchmark_SpecialSetting AS s WITH (NOLOCK)
			ON	s.Spread = tp.Spread
			AND	s.Rate = tm.Rate
			AND (@Market = -1 OR tp.IsLive = @Market)
			AND (@IsExcludeLeagues = 0 OR (tp.LeagueId NOT IN (SELECT le.LeagueId FROM dbo.LeagueExclusion AS le WITH(NOLOCK))))
	WHERE	tp.EventDate BETWEEN @FromDate AND @ToDate
		AND	tp.BetType IN (SELECT bl.bettype FROM @BettypeList AS bl)
	GROUP BY	tp.CustId, tp.Grade, tp.IsLive;

	WITH GradeDetail AS (
		SELECT	tp.Grade												AS Grade
			,	tp.IsLive												AS IsLive
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
		FROM	dbo.TraderPerformance	AS tp WITH (NOLOCK)
		WHERE	tp.EventDate BETWEEN @FromDate AND @ToDate
			AND	tp.BetType IN (SELECT bl.bettype FROM @BettypeList AS bl)
			AND (@Market = -1 OR tp.IsLive = @Market)
			AND (@IsExcludeLeagues = 0 OR (tp.LeagueId NOT IN (SELECT le.LeagueId FROM dbo.LeagueExclusion AS le WITH(NOLOCK))))
		GROUP BY	tp.Grade, tp.IsLive
	)
	INSERT INTO @Grade (Grade, TraderCount, LeagueCount, MatchCount, Turnover, WinLoss, BetCount, Margin, IsLive)
	SELECT	gd.Grade, gd.TraderCount, gd.LeagueCount, gd.MatchCount, gd.Turnover, gd.WinLoss, gd.BetCount, gd.Margin, gd.IsLive
	FROM	GradeDetail gd
	WHERE	(@Turnover IS NULL OR gd.Turnover >= @Turnover)
		AND	(@WinLoss IS NULL OR gd.WinLoss >= @WinLoss)
		AND	(@MarginFrom IS NULL OR gd.Margin >= @MarginFrom)
		AND	(@MarginTo IS NULL OR gd.Margin <= @MarginTo);

	WITH score AS (
		SELECT	sd.Grade
			,	AVG(CASE WHEN sd.SumCategory = 0 THEN NULL ELSE sd.WinLoss * 100 / sd.SumCategory END) AS Score
		FROM	#ScoreDetail AS sd WITH (NOLOCK)
		GROUP BY sd.Grade
	)
	UPDATE  g
	SET		g.Score = s.Score
	FROM		@Grade AS g
	INNER JOIN	score AS s
			ON	s.Grade = g.Grade;

	SELECT	Grade
		,	TraderCount
		,	LeagueCount
		,	MatchCount
		,	Turnover
		,	WinLoss
		,	BetCount
		,	Margin
		,	Score 
		,	IsLive
	FROM	@Grade
	ORDER BY	Margin	DESC
			,	Grade	ASC;
	
	DROP TABLE #ScoreDetail;
END;

GO
/*<info serverAlias="DBTGRS-bodb_TGRS" executers="bodbTGRSNet" isFunction="0" isNested="0"></info>*/