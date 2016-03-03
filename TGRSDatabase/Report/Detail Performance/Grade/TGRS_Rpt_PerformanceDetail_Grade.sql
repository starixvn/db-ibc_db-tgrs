ALTER PROCEDURE	[dbo].[TGRS_Rpt_PerformanceDetail_Grade]  
					@FromDate		DATE
				,	@ToDate			DATE
				,	@Turnover		MONEY			= NULL
				,	@WinLost		MONEY			= NULL
				,	@MarginFrom		MONEY			= NULL
				,	@MarginTo		MONEY			= NULL
				,	@Bettypes		VARCHAR(200)	= '0'
AS
/*  
	Created:	20160217@Billy
	Task :		Performance Detail Report - Grade
	DB:			DBTGRS.bodb_TGRS
	Original:  
	 
	Revisions:
		- 20160301@Billy: US011 - Modify Trader's Score - [Redmine: #53084]

	Param's Explanation:  	
	
	Example: 	
		EXECUTE	TGRS_Rpt_PerformanceDetail_Grade  
					@FromDate = '2014-11-19 00:00:00'
				,	@WinLost = NULL
				,	@Turnover = NULL
				,	@MarginTo = NULL
				,	@MarginFrom = NULL
				,	@Bettypes = '0'
				,	@ToDate = '2014-12-03 00:00:00'
*/  
 
BEGIN 
	
	SET NOCOUNT ON;  
	 
	CREATE TABLE #ScoreDetail (
								CustID				INT
							,	WinLost				MONEY
							,	SumCategory			MONEY
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
							,	WinLost			MONEY
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

	INSERT INTO	#ScoreDetail (
					CustID
				,	WinLost
				,	SumCategory
				)
	SELECT	tp.CustId
		,	ISNULL(SUM(tp.WinLost), 0) - ISNULL(SUM(tp.Comm), 0)	AS WinLost
		,	SUM(tp.Stake * tp.Spread * tm.Rate)						AS SumCategory
	FROM		dbo.TraderPerformance AS tp WITH (NOLOCK)
	INNER JOIN	dbo.TargetedMargin AS tm WITH (NOLOCK)
			ON	tm.BetType = tp.BetType
			AND	tm.WorkShift = tp.WorkShift
	WHERE	tp.EventDate BETWEEN @FromDate AND @ToDate
		AND	tp.BetType IN (SELECT bl.bettype FROM @BettypeList AS bl)
	GROUP BY	tp.CustId;

	WITH GradeDetail AS (
		SELECT	t.Grade													AS Grade
			,	COUNT(DISTINCT tp.CustId)								AS TraderCount
			,	COUNT(DISTINCT tp.LeagueId)								AS LeagueCount
			,	COUNT(DISTINCT tp.MatchId)								AS MatchCount
			,	ISNULL(SUM(tp.Stake), 0)								AS Turnover
			,	ISNULL(SUM(tp.WinLost), 0) - ISNULL(SUM(tp.Comm), 0)	AS WinLost
			,	ISNULL(SUM(tp.BetCount), 0)								AS BetCount
			,	CASE	WHEN ISNULL(SUM(tp.Stake), 0) = 0
						THEN NULL
						ELSE (ISNULL(SUM(tp.WinLost), 0) - ISNULL(SUM(tp.Comm), 0)) * 100 / ISNULL(SUM(tp.Stake), 0)
				END														AS Margin
		FROM		dbo.TraderPerformance	AS tp WITH (NOLOCK)
		INNER JOIN	dbo.Trader				AS t WITH (NOLOCK)
				ON t.CustId = tp.CustId
		WHERE	tp.EventDate BETWEEN @FromDate AND @ToDate
			AND	tp.BetType IN (SELECT bl.bettype FROM @BettypeList AS bl)
		GROUP BY	t.Grade
	)
	INSERT INTO @Grade 
		(	Grade   , TraderCount   , LeagueCount   , MatchCount   , Turnover   , WinLost   , BetCount   , Margin   )
	SELECT	gd.Grade, gd.TraderCount, gd.LeagueCount, gd.MatchCount, gd.Turnover, gd.WinLost, gd.BetCount, gd.Margin
	FROM	GradeDetail gd
	WHERE	(@Turnover IS NULL OR gd.Turnover >= @Turnover)
		AND	(@WinLost IS NULL OR gd.WinLost >= @WinLost)
		AND	(@MarginFrom IS NULL OR gd.Margin >= @MarginFrom)
		AND	(@MarginTo IS NULL OR gd.Margin <= @MarginTo);

	WITH score AS (
		SELECT	t.Grade
			,	AVG(CASE WHEN sd.SumCategory = 0 THEN NULL ELSE sd.WinLost * 100 / sd.SumCategory END) AS Score
		FROM	#ScoreDetail AS sd WITH (NOLOCK)
		INNER JOIN	dbo.Trader AS t WITH (NOLOCK)
				ON	t.CustId = sd.CustID
		GROUP BY t.Grade
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
		,	WinLost
		,	BetCount
		,	Margin
		,	Score 
	FROM	@Grade
	ORDER BY	Margin	DESC
			,	Grade	ASC;
	
	DROP TABLE #ScoreDetail;
END; 
GO
GRANT EXECUTE ON [dbo].[TGRS_Rpt_PerformanceDetail_Grade] TO [bodbTGRSNet];
GO

 