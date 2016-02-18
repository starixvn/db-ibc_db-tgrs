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
	DECLARE @AVGScore		TABLE (
								Grade			TINYINT
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

	INSERT INTO @AVGScore(Grade, Score)
	SELECT	ftsc.Grade, AVG(ftsc.Score)
	FROM	dbo.f_TraderScoreCalculation(@Bettypes, @FromDate, @ToDate) AS ftsc
	GROUP BY	ftsc.Grade;
	
	UPDATE  g
	SET		g.Score = s.Score
	FROM		@Grade AS g
	INNER JOIN	@AVGScore AS s
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

END; 
GO
GRANT EXECUTE ON [dbo].[TGRS_Rpt_PerformanceDetail_Grade] TO [bodbTGRSNet];
GO

 