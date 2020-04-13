CREATE PROCEDURE [dbo].[TGRS_Rpt_RobotTrading_BetType_League_Match]
		@FromDate			DATE
	,	@ToDate				DATE
	,	@Model				TINYINT =  3
	,	@MatchIds			VARCHAR(MAX) =  ''
	,	@BettypeId			SMALLINT
	,	@TypeSiteIds		VARCHAR(200) =  ''
AS    
/*  
	Created:	20200325@John.Ngo
	Task :		Robot Trading - Bettype - League - Match
	DB:			DBTGRS.bodb_TGRS
	Original:  
  
	Revisions: 	
		- 20200325@John.Ngo: Automation Trading by Period/Bettype - Drill down to event performance [Redmine ID: 130791]
		- 20200407@John.Ngo: Separate LeagueGroupId (1 -> 11) [Redmine ID: 132038]

	Param's Explanation: 
		- @Model =  3: TA, 1: RT3
	Exam: 
  
*/  
 
BEGIN 
	SET NOCOUNT ON;

	IF	OBJECT_ID('tempdb..#tmp8RMPerformance') IS NOT NULL
	BEGIN
		DROP TABLE	#tmp8RMPerformance;
	END;

	CREATE TABLE	#tmp8RMPerformance (
			EventDate			DATE
		,	MatchId				INT
		,	BetType				SMALLINT
		,   BetCount			INT
		,	Stake_VR			MONEY
		,	WinLoss_VR			MONEY
		,	Stake_AR			MONEY
		,	WinLoss_AR			MONEY
		,	TypeSiteId			TINYINT
		,	PRIMARY KEY CLUSTERED (
				MatchId			ASC
			,	BetType			ASC
			,	TypeSiteId		ASC
		)
	);	

	IF	OBJECT_ID('tempdb..#tmpTotalPerformance') IS NOT NULL
	BEGIN
		DROP TABLE	#tmpTotalPerformance;
	END;

	CREATE TABLE	#tmpTotalPerformance (
			EventDate			DATE
		,	MatchId				INT
		,	BetType				SMALLINT
		,   BetCount			INT
		,   MatchCount			INT
		,	Stake_VR			MONEY
		,	WinLoss_VR			MONEY
		,	Stake_AR			MONEY
		,	WinLoss_AR			MONEY
		,	TypeSiteId			TINYINT
		,	PRIMARY KEY CLUSTERED (
				MatchId			ASC
			,	BetType			ASC
			,	TypeSiteId		ASC
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

	DECLARE @Matches AS TABLE (MatchId INT PRIMARY KEY CLUSTERED)
	IF @MatchIds <> ''
	BEGIN
		INSERT INTO @Matches(MatchId)
		SELECT val 
		FROM dbo.strSplit_Key(@MatchIds,',');
	END;

	DECLARE @LeagueGroups AS TABLE (LeagueGroupId SMALLINT PRIMARY KEY CLUSTERED)
	BEGIN
		INSERT INTO @LeagueGroups(LeagueGroupId)
		VALUES (1),(2),(3),(4),(5),(6),(7),(8),(9),(10),(11);
	END;

	INSERT INTO #tmp8RMPerformance(EventDate, MatchId, BetType, BetCount, Stake_VR, WinLoss_VR, Stake_AR, WinLoss_AR, TypeSiteId)
	SELECT	r.EventDate
		,	r.MatchId
		,	r.BetType
		,	SUM(r.BetCount)
		,	SUM(r.Stake_VR)
		,	- SUM(r.WinLoss_VR - r.Comm_VR)
		,	SUM(r.Stake_AR)
		,	- SUM(r.WinLoss_AR - r.Comm_AR)
		,	r.TypeSiteId
	FROM dbo.RobotTrading AS r WITH(NOLOCK)
		INNER JOIN @LeagueGroups AS lgr ON r.LeagueGroupId = lgr.LeagueGroupId
		INNER JOIN @Matches AS m ON r.MatchId = m.MatchId
		LEFT JOIN @TypeSites AS ts ON r.TypeSiteId = ts.TypeSiteId
	WHERE r.EventDate BETWEEN @FromDate AND @ToDate
		AND r.Is8RM = 1
		AND r.[Type] = @Model
		AND r.BetType = @BettypeId
		AND (@TypeSiteIds = '' OR ts.TypeSiteId IS NOT NULL)
	GROUP BY r.EventDate, r.MatchId, r.BetType, r.TypeSiteId;

	INSERT INTO #tmpTotalPerformance(EventDate, MatchId, BetType, BetCount, MatchCount, Stake_VR, WinLoss_VR, Stake_AR, WinLoss_AR, TypeSiteId)
	SELECT  r.EventDate
		,	r.MatchId
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
		INNER JOIN @Matches AS m ON r.MatchId = m.MatchId
		LEFT JOIN @TypeSites AS ts ON r.TypeSiteId = ts.TypeSiteId
	WHERE r.EventDate BETWEEN @FromDate AND @ToDate
		AND r.[Type] = @Model
		AND r.BetType = @BettypeId
		AND (@TypeSiteIds = '' OR ts.TypeSiteId IS NOT NULL)
	GROUP BY r.EventDate, r.MatchId, r.BetType, r.TypeSiteId;

	-- MatchId, MatchCount & BetCount by BetType - League - Match
	SELECT	r.EventDate
		,	r.MatchId
		,	r.HomeId
		,	r.AwayId
		,	COUNT(DISTINCT r.MatchId) AS MatchCount
		,	ISNULL(SUM(r.BetCount), 0) AS BetCount
	FROM dbo.RobotTrading AS r WITH(NOLOCK)
		INNER JOIN @LeagueGroups AS lgr ON r.LeagueGroupId = lgr.LeagueGroupId
		INNER JOIN @Matches AS m ON r.MatchId = m.MatchId
		LEFT JOIN @TypeSites AS ts ON r.TypeSiteId = ts.TypeSiteId
	WHERE r.EventDate BETWEEN @FromDate AND @ToDate
		AND r.[Type] = @Model
		AND r.BetType = @BettypeId
		AND (@TypeSiteIds = '' OR ts.TypeSiteId IS NOT NULL)
	GROUP BY r.EventDate, r.LeagueId, r.MatchId, r.HomeId,	r.AwayId
	ORDER BY r.EventDate DESC;

	-- Detailed by Bettype - League - Match
	SELECT	t.EventDate
		,	t.MatchId
		,	t.BetCount
		,	t.MatchCount

		,	t.Stake_VR
		,	t.WinLoss_VR
		,	CASE WHEN ISNULL(t.WinLoss_VR, 0) <> 0 THEN t.WinLoss_VR*100/t.Stake_VR ELSE NULL END AS Margin_VR

		,	ABS(t.Stake_AR - t.Stake_VR) AS Stake_VAR
		,	(t.WinLoss_AR - t.WinLoss_VR) AS Winloss_VAR
		,	CASE WHEN ISNULL(ABS(t.Stake_AR - t.Stake_VR), 0) <> 0 THEN (t.WinLoss_AR - t.WinLoss_VR)*100/ABS(t.Stake_AR - t.Stake_VR) ELSE NULL END AS Margin_VAR

		,	(t.Stake_AR - (CASE WHEN r.MatchId IS NULL THEN 0 ELSE r.Stake_AR END)) AS Stake_AR
		,	(t.WinLoss_AR + (CASE WHEN r.MatchId IS NULL THEN 0 ELSE r.WinLoss_AR END)) AS Winloss_AR
		,	CASE WHEN ISNULL((t.Stake_AR - (CASE WHEN r.MatchId IS NULL THEN 0 ELSE r.Stake_AR END)), 0) <> 0 THEN (t.WinLoss_AR + (CASE WHEN r.MatchId IS NULL THEN 0 ELSE r.WinLoss_AR END))*100/(t.Stake_AR - (CASE WHEN r.MatchId IS NULL THEN 0 ELSE r.Stake_AR END)) ELSE NULL END AS Margin_AR

		,	(CASE WHEN r.MatchId IS NULL THEN 0 ELSE r.Stake_AR END) AS Stake_8RM
		,	(CASE WHEN r.MatchId IS NULL THEN 0 ELSE r.WinLoss_AR END) AS Winloss_8RM
		,	CASE WHEN ISNULL((CASE WHEN r.MatchId IS NULL THEN 0 ELSE r.Stake_AR END), 0) <> 0 THEN (CASE WHEN r.MatchId IS NULL THEN 0 ELSE r.WinLoss_AR END)*100/(CASE WHEN r.MatchId IS NULL THEN 0 ELSE r.Stake_AR END) ELSE NULL END AS Margin_8RM

		,	t.Stake_AR AS Stake_AR8RM
		,	t.WinLoss_AR AS Winloss_AR8RM
		,	CASE WHEN ISNULL(t.Stake_AR, 0) <> 0 THEN t.WinLoss_AR*100/t.Stake_AR ELSE NULL END AS Margin_AR8RM
		,	t.TypeSiteId
		,	fs.TypeSiteDesc
	FROM #tmpTotalPerformance AS t WITH(NOLOCK)
		LEFT JOIN #tmp8RMPerformance AS r WITH(NOLOCK) ON t.MatchId = r.MatchId AND t.TypeSiteId = r.TypeSiteId
		INNER JOIN @FilterSite AS fs ON t.TypeSiteId = fs.TypeSiteId
	WHERE t.BetCount IS NOT NULL
	ORDER BY t.EventDate DESC;

	DROP TABLE #tmp8RMPerformance;
	DROP TABLE #tmpTotalPerformance;
END;

GO
/*<info serverAlias="DBTGRS-bodb_TGRS" executers="bodbTGRSNet" isFunction="0" isNested="0"></info>*/