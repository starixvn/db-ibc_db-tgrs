ALTER PROCEDURE	[dbo].[TGRS_Rpt_PerformanceDetail_Grade]  
		@FromDate			DATE
	,	@ToDate				DATE
	,	@LeagueGroupIds		VARCHAR(2000) = ''
	,	@Turnover			MONEY			= NULL
	,	@WinLoss			MONEY			= NULL
	,	@MarginFrom			MONEY			= NULL
	,	@MarginTo			MONEY			= NULL
	,	@TurnoverReal		MONEY 			= NULL
	,	@WinLossReal		MONEY 			= NULL
	,	@MarginFromReal		MONEY 			= NULL
	,	@MarginToReal		MONEY 			= NULL
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
		- 20191023@John.Ngo:	Enhance performance [Redmine ID: 121268]
		- 20200713@John.Ngo:	Performance Detail - Support filter by league group [Redmine ID: 137276]
		- 20210827@Adam.Tran: 	Sports - Performance Real Figures [Redmine: #158981]

	Param's Explanation:  
		- @Market: -1 All; 0 Nonlive; 1 Live	
	
	Example: 	
		EXECUTE	TGRS_Rpt_PerformanceDetail_Grade  @FromDate = '2016-02-15 00:00:00', @ToDate = '2016-03-14 00:00:00', @Bettypes = '1,3,5'				
*/  
 
BEGIN 	
	SET NOCOUNT ON;  
	
	DECLARE @LeagueGroups AS TABLE (LeagueGroupId SMALLINT PRIMARY KEY CLUSTERED)
	IF @LeagueGroupIds <> ''
	BEGIN
		INSERT INTO @LeagueGroups(LeagueGroupId)
		SELECT val 
		FROM dbo.strSplit_Key(@LeagueGroupIds,',');

		IF CHARINDEX('12', @LeagueGroupIds) > 0
		BEGIN
			DELETE FROM @LeagueGroups
			WHERE LeagueGroupId = 12;

			INSERT INTO @LeagueGroups(LeagueGroupId)
			SELECT DISTINCT l.LeagueGroupID
			FROM bodb02.dbo.league AS l WITH(NOLOCK)
			WHERE l.LeagueGroupID NOT IN (1,2,3,4,5,6,7,8,9,10,11);
		END;
	END;
	
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
		,	Margin			MONEY
		,	TurnoverReal	MONEY
		,	WinLossReal		MONEY		
		,	MarginReal		MONEY
		,	BetCount		INT
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
		INNER JOIN bodb02.dbo.League AS L WITH (NOLOCK) ON tp.LeagueId = L.LeagueId
		INNER JOIN	dbo.TargetedMargin AS tm WITH (NOLOCK) ON tm.BetType = tp.BetType AND tm.WorkShift = tp.WorkShift
		LEFT JOIN @LeagueGroups AS lg ON L.LeagueGroupId = lg.LeagueGroupId
		LEFT JOIN dbo.Benchmark_SpecialSetting AS s WITH (NOLOCK) ON s.Spread = tp.Spread AND s.Rate = tm.Rate
				AND (@Market = -1 OR tp.IsLive = @Market)
		LEFT JOIN dbo.LeagueExclusion le WITH(NOLOCK) ON tp.LeagueId = le.LeagueId
	WHERE	tp.EventDate BETWEEN @FromDate AND @ToDate
		AND	tp.BetType IN (SELECT bl.bettype FROM @BettypeList AS bl)
		AND (@IsExcludeLeagues = 0 OR le.LeagueId IS NULL)
		AND (@LeagueGroupIds = '' OR lg.LeagueGroupId IS NOT NULL)
	GROUP BY	tp.CustId, tp.Grade, tp.IsLive;

	WITH GradeDetail AS (
		SELECT	tp.Grade												AS Grade
			,	tp.IsLive												AS IsLive
			,	COUNT(DISTINCT tp.CustId)								AS TraderCount
			,	COUNT(DISTINCT tp.LeagueId)								AS LeagueCount
			,	COUNT(DISTINCT tp.MatchId)								AS MatchCount
			,	ISNULL(SUM(tp.Stake), 0)								AS Turnover
			,	ISNULL(SUM(tp.WinLost), 0) - ISNULL(SUM(tp.Comm), 0)	AS WinLoss
			,	CASE WHEN ISNULL(SUM(tp.Stake), 0) = 0 THEN NULL ELSE (ISNULL(SUM(tp.WinLost), 0) - ISNULL(SUM(tp.Comm), 0)) * 100 / ISNULL(SUM(tp.Stake), 0) END														  AS Margin
			,	ISNULL(SUM(tp.Stake_Real),0) 							AS TurnoverReal
			,	ISNULL(SUM(CASE WHEN tp.Is8RM = 0 THEN tp.WinLost_Real ELSE 0 END),0) 	AS WinLossReal
			,	CASE WHEN ISNULL(SUM(tp.Stake_Real),0) <> 0 THEN ISNULL(SUM(CASE WHEN tp.Is8RM = 0 THEN tp.WinLost_Real ELSE 0 END),0) * 100/ISNULL(SUM(tp.Stake_Real),0) ELSE NULL END 							   AS MarginReal
			,	ISNULL(SUM(tp.BetCount), 0)								AS BetCount
		FROM	dbo.TraderPerformance	AS tp WITH (NOLOCK)
			INNER JOIN bodb02.dbo.League AS L WITH (NOLOCK) ON tp.LeagueId = L.LeagueId
			LEFT JOIN @LeagueGroups AS lg ON L.LeagueGroupId = lg.LeagueGroupId
			LEFT JOIN dbo.LeagueExclusion le WITH(NOLOCK) ON tp.LeagueId = le.LeagueId
		WHERE	tp.EventDate BETWEEN @FromDate AND @ToDate
			AND	tp.BetType IN (SELECT bl.bettype FROM @BettypeList AS bl)
			AND (@Market = -1 OR tp.IsLive = @Market)
			AND (@IsExcludeLeagues = 0 OR le.LeagueId IS NULL)
			AND (@LeagueGroupIds = '' OR lg.LeagueGroupId IS NOT NULL)
		GROUP BY	tp.Grade, tp.IsLive
	)
	INSERT INTO @Grade (Grade
		, 	TraderCount
		, 	LeagueCount
		, 	MatchCount
		, 	Turnover
		, 	WinLoss		
		, 	Margin
		, 	TurnoverReal
		, 	WinLossReal
		, 	MarginReal
		, 	BetCount
		, 	IsLive)
	SELECT	gd.Grade
		, 	gd.TraderCount
		, 	gd.LeagueCount
		, 	gd.MatchCount
		, 	gd.Turnover
		, 	gd.WinLoss		
		, 	gd.Margin
		, 	gd.TurnoverReal
		, 	gd.WinLossReal
		, 	gd.MarginReal
		, 	gd.BetCount
		, 	gd.IsLive
	FROM	GradeDetail gd
	WHERE	(@Turnover IS NULL OR gd.Turnover >= @Turnover)
		AND	(@WinLoss IS NULL OR gd.WinLoss >= @WinLoss)
		AND	(@MarginFrom IS NULL OR gd.Margin >= @MarginFrom)
		AND	(@MarginTo IS NULL OR gd.Margin <= @MarginTo)
		AND (@TurnoverReal IS NULL OR gd.TurnoverReal >= @TurnoverReal)
		AND (@WinLossReal IS NULL  OR gd.WinLossReal >= @WinLossReal)
		AND (@MarginFromReal IS NULL  OR gd.MarginReal >= @MarginFromReal)
		AND (@MarginToReal IS NULL OR gd.MarginReal <= @MarginToReal);

	WITH score AS (
		SELECT	sd.Grade
			,	sd.IsLive
			,	AVG(CASE WHEN sd.SumCategory = 0 THEN NULL ELSE sd.WinLoss * 100 / sd.SumCategory END) AS Score
		FROM	#ScoreDetail AS sd WITH (NOLOCK)
		GROUP BY sd.Grade, sd.IsLive
	)
	UPDATE  g
	SET		g.Score = s.Score
	FROM		@Grade AS g
	INNER JOIN	score AS s ON	s.Grade = g.Grade AND s.IsLive = g.IsLive;

	SELECT	Grade
		,	TraderCount
		,	LeagueCount
		,	MatchCount
		,	Turnover
		,	WinLoss		
		,	Margin
		,	TurnoverReal
		,	WinLossReal
		,	MarginReal
		,	BetCount
		,	Score 
		,	IsLive
	FROM	@Grade
	ORDER BY	Margin	DESC
			,	Grade	ASC;
	
	DROP TABLE #ScoreDetail;
END;

GO
