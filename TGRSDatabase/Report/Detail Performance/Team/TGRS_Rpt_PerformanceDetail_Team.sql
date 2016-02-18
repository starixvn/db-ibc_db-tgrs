ALTER PROCEDURE [dbo].[TGRS_Rpt_PerformanceDetail_Team]  
					@FromDate		DATE
				,	@ToDate			DATE
				,	@TeamIds		VARCHAR(200) =  '0'
				,	@Turnover		MONEY = NULL
				,	@WinLost		MONEY = NULL
				,	@MarginFrom		MONEY = NULL
				,	@MarginTo		MONEY = NULL
				,	@Bettypes		VARCHAR(200) =  '0'
AS    
/*  
	Created:	20160218@Billy
	Task :		Performance Detail Report - Team
	DB:			DBTGRS.bodb_TGRS
	Original:  
	 
	Revisions:

	Param's Explanation:  	
	
	Example: 	
		EXECUTE	TGRS_Rpt_PerformanceDetail_Team 
					@FromDate = '2013-01-01'
				,	@ToDate = '2014-05-31'
				,	@Bettypes = '0', @TeamIds = '18,13'

*/  
 
BEGIN 
	 
	SET NOCOUNT ON;  
	 
	DECLARE	@BettypeList	TABLE (
								BetType			SMALLINT
							);
	DECLARE	@TeamList	TABLE (
								TeamId			SMALLINT
							);
	DECLARE @AVGScore		TABLE (
								TeamId			SMALLINT
							,	Score			MONEY
							);
	DECLARE	@Team			TABLE (
								TeamId			SMALLINT
							,	TeamName		NVARCHAR(50)
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

	WITH TeamDetail AS (
		SELECT	t.TeamId
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
		FROM		dbo.TraderPerformance AS tp WITH (NOLOCK)
		INNER JOIN	dbo.Trader AS t WITH (NOLOCK)
				ON	t.CustId = tp.CustId
		WHERE	tp.EventDate BETWEEN @FromDate AND @ToDate
			AND	tp.BetType IN (SELECT bl.BetType FROM @BettypeList AS bl)
			AND tp.TeamId IN (SELECT tl.TeamId FROM @TeamList AS tl)
		GROUP BY	t.TeamId
	)
	INSERT INTO @Team
		(	TeamId   , TeamName  , TraderCount   , LeagueCount   , MatchCount   , Turnover   , WinLost   , BetCount   , Margin   )
	SELECT	td.TeamId, t.TeamName, td.TraderCount, td.LeagueCount, td.MatchCount, td.Turnover, td.WinLost, td.BetCount, td.Margin
	FROM		TeamDetail td
	INNER JOIN	dbo.Team AS t WITH (NOLOCK)
			ON	t.TeamId = td.TeamId
	WHERE	(@Turnover IS NULL OR td.Turnover >= @Turnover)
		AND	(@WinLost IS NULL OR td.WinLost >= @WinLost)
		AND	(@MarginFrom IS NULL OR td.Margin >= @MarginFrom)
		AND	(@MarginTo IS NULL OR td.Margin <= @MarginTo);

	INSERT INTO @AVGScore
		(	TeamId, Score)
	SELECT	ftsc.TeamId, AVG(ftsc.Score)
	FROM	dbo.f_TraderScoreCalculation(@Bettypes, @FromDate, @ToDate) AS ftsc
	WHERE	ftsc.TeamId IN (SELECT tl.TeamId FROM @TeamList AS tl)
	GROUP BY	ftsc.TeamId;

	UPDATE	t 
	SET		t.Score = s.Score
	FROM		@Team AS t
	INNER JOIN	@AVGScore s
			ON	s.TeamId = t.TeamId;


	SELECT	t.TeamId
		,	t.TeamName
		,	t.TraderCount
		,	t.LeagueCount
		,	t.MatchCount
		,	t.Turnover
		,	t.WinLost
		,	t.BetCount
		,	t.Margin
		,	t.Score 
	FROM	@Team AS t
	ORDER BY	Margin DESC
			,	TeamName ASC;
	
END; 
GO
GRANT EXECUTE ON [dbo].[TGRS_Rpt_PerformanceDetail_Team] TO [bodbTGRSNet];
GO

 