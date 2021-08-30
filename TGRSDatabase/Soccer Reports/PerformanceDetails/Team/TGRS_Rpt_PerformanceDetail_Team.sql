ALTER PROCEDURE [dbo].[TGRS_Rpt_PerformanceDetail_Team]  
		@FromDate			DATE
	,	@ToDate				DATE
	,	@LeagueGroupIds		VARCHAR(2000) = ''
	,	@TeamIds			VARCHAR(200) =  '0'
	,	@Turnover			MONEY = NULL
	,	@WinLoss			MONEY = NULL
	,	@MarginFrom			MONEY = NULL
	,	@MarginTo			MONEY = NULL
	,	@TurnoverReal		MONEY = NULL
	,	@WinLossReal		MONEY = NULL
	,	@MarginFromReal		MONEY = NULL
	,	@MarginToReal		MONEY = NULL
	,	@Bettypes			VARCHAR(2000) =  '0'
	,	@IsExcludeLeagues	BIT = 1
	,	@Market				SMALLINT = 1
AS    
/*  
	Created:	20160218@Billy
	Task :		Performance Detail Report - Team
	DB:			DBTGRS.bodb_TGRS
	Original:  
	 
	Revisions:
		- 20160301@Billy:		US011 - Modify Trader's Score - [Redmine: #53084]
		- 20160315@Thai:		US018 - Modify Trader's Score - [Redmine: #53987]
		- 20171019@Simon:		Change VARCHAR(200) to VARCHAR(2000)
		- 20171205@Simon:		get only Live data & Bettypes are not disabled
		- 20180912@Simon:		add league exclusion
		- 20190919@Long.Luu:	Support Nonlive Data [Redmine ID: 118959]
		- 20191023@John.Ngo:	Enhance performance [Redmine ID: 121268]
		- 20200713@John.Ngo:	Performance Detail - Support filter by league group [Redmine ID: 137276]
		- 20210827@Adam.Tran: 	Sports - Performance Real Figures [Redmine: #158981]

	Param's Explanation:  
		- @Market: -1 All; 0 Nonlive; 1 Live	
	
	Example: 	
		EXECUTE	TGRS_Rpt_PerformanceDetail_Team @FromDate = '2016-02-22', @ToDate = '2016-03-14', @Bettypes = '1,3,5', @TeamIds = '0'
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
		,	IsLive			BIT
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
		,	IsLive
		,	WinLoss
		,	SumCategory
	)
	SELECT	tp.CustId
		,	tp.IsLive
		,	ISNULL(SUM(tp.WinLost), 0) - ISNULL(SUM(tp.Comm), 0)	AS WinLoss				
		,	ISNULL(SUM(tp.Stake * ISNULL(s.BenchMark, tp.Spread * tm.Rate)), 0) AS SumCategory
	FROM	dbo.TraderPerformance AS tp WITH (NOLOCK)
		INNER JOIN bodb02.dbo.League AS L WITH (NOLOCK) ON tp.LeagueId = L.LeagueId
		INNER JOIN	dbo.TargetedMargin AS tm WITH (NOLOCK) ON tm.BetType = tp.BetType AND tm.WorkShift = tp.WorkShift
		LEFT JOIN @LeagueGroups AS lg ON L.LeagueGroupId = lg.LeagueGroupId
		LEFT JOIN dbo.Benchmark_SpecialSetting AS s WITH (NOLOCK) ON s.Spread = tp.Spread AND s.Rate = tm.Rate
		LEFT JOIN dbo.LeagueExclusion le WITH(NOLOCK) ON tp.LeagueId = le.LeagueId
	WHERE	tp.EventDate BETWEEN @FromDate AND @ToDate
		AND	tp.BetType IN (SELECT bl.bettype FROM @BettypeList AS bl)
		AND (@Market = -1 OR tp.IsLive = @Market)
		AND (@IsExcludeLeagues = 0 OR le.LeagueId IS NULL)
		AND (@LeagueGroupIds = '' OR lg.LeagueGroupId IS NOT NULL)
	GROUP BY tp.CustId, tp.IsLive;

	WITH TeamDetail AS (
		SELECT	t.TeamId
			,	tp.IsLive
			,	COUNT(DISTINCT tp.CustId)								AS TraderCount
			,	COUNT(DISTINCT tp.LeagueId)								AS LeagueCount
			,	COUNT(DISTINCT tp.MatchId)								AS MatchCount
			,	ISNULL(SUM(tp.Stake), 0)								AS Turnover
			,	ISNULL(SUM(tp.WinLost), 0) - ISNULL(SUM(tp.Comm), 0)	AS WinLoss			
			,	CASE WHEN ISNULL(SUM(tp.Stake), 0) = 0 THEN NULL ELSE (ISNULL(SUM(tp.WinLost), 0) - ISNULL(SUM(tp.Comm), 0)) * 100 / ISNULL(SUM(tp.Stake), 0)   END														 AS Margin
			,	ISNULL(SUM(tp.Stake_Real),0) 							AS TurnoverReal
			,	ISNULL(SUM(CASE WHEN tp.Is8RM = 0 THEN tp.WinLost_Real ELSE 0 END),0) 	AS WinLossReal
			,	CASE WHEN ISNULL(SUM(tp.Stake_Real),0) <> 0 THEN ISNULL(SUM(CASE WHEN tp.Is8RM = 0 THEN tp.WinLost_Real ELSE 0 END),0) * 100/ISNULL(SUM(tp.Stake_Real),0) ELSE NULL END 							   AS MarginReal
			,	ISNULL(SUM(tp.BetCount), 0)								AS BetCount
		FROM	dbo.TraderPerformance AS tp WITH (NOLOCK)
			INNER JOIN bodb02.dbo.League AS L WITH (NOLOCK) ON tp.LeagueId = L.LeagueId
			INNER JOIN	dbo.Trader AS t WITH (NOLOCK) ON	t.CustId = tp.CustId
			LEFT JOIN @LeagueGroups AS lg ON L.LeagueGroupId = lg.LeagueGroupId
			LEFT JOIN dbo.LeagueExclusion le WITH(NOLOCK) ON tp.LeagueId = le.LeagueId
		WHERE	tp.EventDate BETWEEN @FromDate AND @ToDate
			AND	tp.BetType IN (SELECT bl.BetType FROM @BettypeList AS bl)
			AND	t.TeamId IN (SELECT tl.TeamId FROM @TeamList AS tl)
			AND (@Market = -1 OR tp.IsLive = @Market)
			AND (@IsExcludeLeagues = 0 OR le.LeagueId IS NULL)
			AND (@LeagueGroupIds = '' OR lg.LeagueGroupId IS NOT NULL)
		GROUP BY t.TeamId, tp.IsLive
	)
	INSERT INTO @Team (TeamId
		, 	TeamName
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
	SELECT	td.TeamId
		, 	t.TeamName
		, 	td.TraderCount
		, 	td.LeagueCount
		, 	td.MatchCount
		, 	td.Turnover
		, 	td.WinLoss
		, 	td.Margin
		, 	td.TurnoverReal
		, 	td.WinLossReal
		, 	td.MarginReal
		, 	td.BetCount
		, 	td.IsLive
	FROM	TeamDetail td
		INNER JOIN	dbo.Team AS t WITH (NOLOCK) ON t.TeamId = td.TeamId
	WHERE	(@Turnover IS NULL OR td.Turnover >= @Turnover)
		AND	(@WinLoss IS NULL OR td.WinLoss >= @WinLoss)
		AND	(@MarginFrom IS NULL OR td.Margin >= @MarginFrom)
		AND	(@MarginTo IS NULL OR td.Margin <= @MarginTo)
		AND (@TurnoverReal IS NULL OR td.TurnoverReal >= @TurnoverReal)
		AND (@WinLossReal IS NULL  OR td.WinLossReal >= @WinLossReal)
		AND (@MarginFromReal IS NULL  OR td.MarginReal >= @MarginFromReal)
		AND (@MarginToReal IS NULL OR td.MarginReal <= @MarginToReal);

	WITH score AS (
		SELECT	t.TeamId
			,	sd.IsLive
			,	AVG(CASE WHEN sd.SumCategory = 0 THEN NULL ELSE sd.WinLoss * 100 / sd.SumCategory END) AS Score
		FROM	#ScoreDetail AS sd WITH (NOLOCK)
		INNER JOIN	dbo.Trader AS t WITH (NOLOCK) ON t.CustId = sd.CustID
		GROUP BY t.TeamId, sd.IsLive
	)
	UPDATE  t
	SET		t.Score = s.Score
	FROM		@Team AS t
	INNER JOIN	Score AS s
			ON	s.TeamId = t.TeamId AND t.IsLive = s.IsLive;

	SELECT	t.TeamId
		,	t.TeamName
		,	t.TraderCount
		,	t.LeagueCount
		,	t.MatchCount
		,	t.Turnover
		,	t.WinLoss		
		,	t.Margin
		,	t.TurnoverReal
		,	t.WinLossReal		
		,	t.MarginReal
		,	t.BetCount
		,	t.Score 
		,	t.IsLive
	FROM	@Team AS t
	ORDER BY	Margin DESC 
			,	TeamName ASC;
	
	DROP TABLE #ScoreDetail;
END;

GO
/*<info serverAlias="DBTGRS-bodb_TGRS" executers="bodbTGRSNet" isFunction="0" isNested="0"></info>*/