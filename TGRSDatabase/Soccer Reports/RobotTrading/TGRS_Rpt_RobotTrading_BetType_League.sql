ALTER PROCEDURE [dbo].[TGRS_Rpt_RobotTrading_BetType_League]
		@FromDate			DATE
	,	@ToDate				DATE
	,	@Model				TINYINT =  3
	,	@LeagueIds			VARCHAR(MAX) =  ''
	,	@BettypeId			SMALLINT
	,	@TypeSiteIds		VARCHAR(200) =  ''
AS    
/*  
	Created:	20200325@John.Ngo
	Task :		Robot Trading - Bettype - League
	DB:			DBTGRS.bodb_TGRS
	Original:  
  
	Revisions:
		- 20200325@John.Ngo: Automation Trading by Period/Bettype - Drill down to event performance [Redmine ID: 130791]
		- 20200407@John.Ngo: Separate LeagueGroupId (1 -> 11) [Redmine ID: 132038]

	Param's Explanation: 
		- @Model =  3: TA, 1: RT3
	
	Exam: EXECUTE TGRS_Rpt_RobotTrading_BetType_League @FromDate = '20200101', @ToDate = '20200401', @Model =  3,	@LeagueIds = '1837,27,30,49218,50191,53006,53007,63059', @BettypeId	= 1, @TypeSiteIds	=  ''
  
*/  
 
BEGIN 
	SET NOCOUNT ON;

		IF	OBJECT_ID('tempdb..#tmp8RMPerformance') IS NOT NULL
	BEGIN
		DROP TABLE	#tmp8RMPerformance;
	END;

	CREATE TABLE	#tmp8RMPerformance (
			LeagueId			INT
		,	BetType				SMALLINT
		,   BetCount			INT
		,	Stake_VR			MONEY
		,	WinLoss_VR			MONEY
		,	Stake_AR			MONEY
		,	WinLoss_AR			MONEY
		,	TypeSiteId			TINYINT
		,	PRIMARY KEY CLUSTERED (
				LeagueId		ASC
			,	BetType			ASC
			,	TypeSiteId		ASC
		)
	);	

	IF	OBJECT_ID('tempdb..#tmpTotalPerformance') IS NOT NULL
	BEGIN
		DROP TABLE	#tmpTotalPerformance;
	END;

	CREATE TABLE	#tmpTotalPerformance (
			LeagueId			INT
		,	BetType				SMALLINT
		,   BetCount			INT
		,   MatchCount			INT
		,	Stake_VR			MONEY
		,	WinLoss_VR			MONEY
		,	Stake_AR			MONEY
		,	WinLoss_AR			MONEY
		,	TypeSiteId			TINYINT
		,	PRIMARY KEY CLUSTERED (
				LeagueId		ASC
			,	BetType			ASC
			,	TypeSiteId		ASC
		)
	);	

	IF	OBJECT_ID('tempdb..#tmpLM') IS NOT NULL
	BEGIN
		DROP TABLE	#tmpLM;
	END;

	CREATE TABLE	#tmpLM (
			LeagueId			INT
		,	LeagueName			NVARCHAR(500)
		,	MatchId				INT
		,   BetCount			INT

		,	PRIMARY KEY CLUSTERED (
				LeagueId		ASC
			,	MatchId			ASC
		)
	);	

	DECLARE @FilterSite AS TABLE (TypeSiteId TINYINT PRIMARY KEY CLUSTERED, TypeSiteDesc VARCHAR(20));
	INSERT INTO @FilterSite(TypeSiteId, TypeSiteDesc)
	SELECT DISTINCT TypeSiteId, TypeSiteDesc FROM dbo.FilteredSite WITH(NOLOCK);

	IF @TypeSiteIds <> ''
	BEGIN
		DECLARE @TypeSites AS TABLE (TypeSiteId TINYINT PRIMARY KEY CLUSTERED);
		INSERT INTO @TypeSites(TypeSiteId)
		SELECT val FROM dbo.strSplit_Key(@TypeSiteIds,',');
	END;

	DECLARE @Leagues AS TABLE (LeagueId INT PRIMARY KEY CLUSTERED)
	IF @LeagueIds <> ''
	BEGIN
		INSERT INTO @Leagues(LeagueId)
		SELECT val 
		FROM dbo.strSplit_Key(@LeagueIds,',');
	END;

	DECLARE @LeagueGroups AS TABLE (LeagueGroupId SMALLINT PRIMARY KEY CLUSTERED)
	BEGIN
		INSERT INTO @LeagueGroups(LeagueGroupId)
		VALUES (1),(2),(3),(4),(5),(6),(7),(8),(9),(10),(11);
	END;

	INSERT INTO #tmp8RMPerformance(LeagueId, BetType, BetCount, Stake_VR, WinLoss_VR, Stake_AR, WinLoss_AR, TypeSiteId)
	SELECT	r.LeagueId
		,	r.BetType
		,	SUM(r.BetCount)
		,	SUM(r.Stake_VR)
		,	- SUM(r.WinLoss_VR - r.Comm_VR)
		,	SUM(r.Stake_AR)
		,	- SUM(r.WinLoss_AR - r.Comm_AR)
		,	r.TypeSiteId
	FROM dbo.RobotTrading AS r WITH(NOLOCK)
		INNER JOIN @LeagueGroups AS lgr ON r.LeagueGroupId = lgr.LeagueGroupId
		INNER JOIN @Leagues AS lg ON r.LeagueId = lg.LeagueId
		LEFT JOIN @TypeSites AS ts ON r.TypeSiteId = ts.TypeSiteId
	WHERE r.EventDate BETWEEN @FromDate AND @ToDate
		AND r.Is8RM = 1
		AND r.[Type] = @Model
		AND r.BetType = @BettypeId
		AND (@TypeSiteIds = '' OR ts.TypeSiteId IS NOT NULL)
	GROUP BY r.LeagueId, r.BetType, r.TypeSiteId;

	INSERT INTO #tmpTotalPerformance(LeagueId, BetType, BetCount, MatchCount, Stake_VR, WinLoss_VR, Stake_AR, WinLoss_AR, TypeSiteId)
	SELECT  r.LeagueId
		,	r.BetType
		,	SUM(r.BetCount)
		,	COUNT(DISTINCT r.MatchId)
		,	SUM(r.Stake_VR)
		,	SUM(r.WinLoss_VR - r.Comm_VR)
		,	SUM(r.Stake_AR)
		,	SUM(r.WinLoss_AR - r.Comm_AR)
		,	r.TypeSiteId
	FROM dbo.RobotTrading AS r WITH(NOLOCK)
		INNER JOIN @LeagueGroups AS lgr ON r.LeagueGroupId = lgr.LeagueGroupId
		INNER JOIN @Leagues AS lg ON r.LeagueId = lg.LeagueId
		LEFT JOIN @TypeSites AS ts ON r.TypeSiteId = ts.TypeSiteId
	WHERE r.EventDate BETWEEN @FromDate AND @ToDate
		AND r.[Type] = @Model
		AND r.BetType = @BettypeId
		AND (@TypeSiteIds = '' OR ts.TypeSiteId IS NOT NULL)
	GROUP BY r.LeagueId, r.BetType, r.TypeSiteId;

	-- LeagueCount, MatchCount & BetCount by BetType
	INSERT INTO #tmpLM (LeagueId, LeagueName, MatchId, BetCount)
	SELECT	DISTINCT r.LeagueId
		,	l.LeagueName
		,	r.MatchId
		,   ISNULL(SUM(r.BetCount), 0) AS BetCount
	FROM dbo.RobotTrading AS r WITH(NOLOCK)
		INNER JOIN @LeagueGroups AS lgr ON r.LeagueGroupId = lgr.LeagueGroupId
		INNER JOIN @Leagues AS lg ON r.LeagueId = lg.LeagueId
		INNER JOIN bodb02.dbo.league AS l ON l.LeagueId = lg.LeagueId
		LEFT JOIN @TypeSites AS ts ON r.TypeSiteId = ts.TypeSiteId
	WHERE r.EventDate BETWEEN @FromDate AND @ToDate
		AND r.[Type] = @Model
		AND r.BetType = @BettypeId
		AND (@TypeSiteIds = '' OR ts.TypeSiteId IS NOT NULL)
	GROUP BY r.LeagueId, l.LeagueName, r.MatchId
	
	SELECT	lm.LeagueId
		,	lm.LeagueName
		,	COUNT(lm.MatchId) AS MatchCount
		,	STUFF((SELECT ',', CONVERT(VARCHAR(MAX), lm2.MatchId)
					FROM #tmpLM lm2 WITH (NOLOCK)
					WHERE lm.LeagueId = lm2.LeagueId
					FOR XML PATH('')), 1, 1, '') AS MatchIdList
		,	ISNULL(SUM(lm.BetCount), 0) AS BetCount
	FROM #tmpLM lm WITH (NOLOCK)
	GROUP BY lm.LeagueId, lm.LeagueName
	ORDER BY lm.LeagueId ASC;

	-- Detailed by Bettype - LeagueId
	SELECT	t.LeagueId
		,	t.BetCount
		,	t.MatchCount

		,	t.Stake_VR
		,	t.WinLoss_VR
		,	CASE WHEN ISNULL(t.WinLoss_VR, 0) <> 0 THEN t.WinLoss_VR*100/t.Stake_VR ELSE NULL END AS Margin_VR

		,	ABS(t.Stake_AR - t.Stake_VR) AS Stake_VAR
		,	(t.WinLoss_AR - t.WinLoss_VR) AS Winloss_VAR
		,	CASE WHEN ISNULL(ABS(t.Stake_AR - t.Stake_VR), 0) <> 0 THEN (t.WinLoss_AR - t.WinLoss_VR)*100/ABS(t.Stake_AR - t.Stake_VR) ELSE NULL END AS Margin_VAR

		,	(t.Stake_AR - (CASE WHEN r.LeagueId IS NULL THEN 0 ELSE r.Stake_AR END)) AS Stake_AR
		,	(t.WinLoss_AR + (CASE WHEN r.LeagueId IS NULL THEN 0 ELSE r.WinLoss_AR END)) AS Winloss_AR
		,	CASE WHEN ISNULL((t.Stake_AR - (CASE WHEN r.LeagueId IS NULL THEN 0 ELSE r.Stake_AR END)), 0) <> 0 THEN (t.WinLoss_AR + (CASE WHEN r.LeagueId IS NULL THEN 0 ELSE r.WinLoss_AR END))*100/(t.Stake_AR - (CASE WHEN r.LeagueId IS NULL THEN 0 ELSE r.Stake_AR END)) ELSE NULL END AS Margin_AR

		,	(CASE WHEN r.LeagueId IS NULL THEN 0 ELSE r.Stake_AR END) AS Stake_8RM
		,	(CASE WHEN r.LeagueId IS NULL THEN 0 ELSE r.WinLoss_AR END) AS Winloss_8RM
		,	CASE WHEN ISNULL((CASE WHEN r.LeagueId IS NULL THEN 0 ELSE r.Stake_AR END), 0) <> 0 THEN (CASE WHEN r.LeagueId IS NULL THEN 0 ELSE r.WinLoss_AR END)*100/(CASE WHEN r.LeagueId IS NULL THEN 0 ELSE r.Stake_AR END) ELSE NULL END AS Margin_8RM

		,	t.Stake_AR AS Stake_AR8RM
		,	t.WinLoss_AR AS Winloss_AR8RM
		,	CASE WHEN ISNULL(t.Stake_AR, 0) <> 0 THEN t.WinLoss_AR*100/t.Stake_AR ELSE NULL END AS Margin_AR8RM
		,	t.TypeSiteId
		,	fs.TypeSiteDesc
	FROM #tmpTotalPerformance AS t WITH(NOLOCK)
		LEFT JOIN #tmp8RMPerformance AS r WITH(NOLOCK) ON t.LeagueId = r.LeagueId AND t.TypeSiteId = r.TypeSiteId
		INNER JOIN @FilterSite AS fs ON t.TypeSiteId = fs.TypeSiteId
	WHERE t.BetCount IS NOT NULL
	ORDER BY t.LeagueId ASC;

	DROP TABLE #tmp8RMPerformance;
	DROP TABLE #tmpTotalPerformance;
END;

GO
/*<info serverAlias="DBTGRS-bodb_TGRS" executers="bodbTGRSNet" isFunction="0" isNested="0"></info>*/