ALTER PROCEDURE [dbo].[TGRS_Rpt_RobotTrading_Event_League]
		@FromDate			DATE
	,	@ToDate				DATE
	,	@Model				TINYINT =  3
	,	@LeagueIds			VARCHAR(MAX) =  ''
	,	@TypeSiteIds		VARCHAR(200) =  ''
	,	@IsExportExcel		BIT = 0

AS    
/*  
	Created:	20200313@John.Ngo
	Task :		Automation Trading - Report by Event - League
	DB:			DBTGRS.bodb_TGRS
	Original:  
  
	Revisions: 	
   		- 20200313@John.Ngo: Created [Redmine ID: 130393]

	Param's Explanation: 
		- @Model =  3: TA, 1: RT3
	
	Exam: EXECUTE dbo.TGRS_Rpt_RobotTrading_Event_League @FromDate = '20200101', @ToDate = '20200215', @Model = 3, @LeagueIds =  '1837,53006', @TypeSiteIds = ''
  
*/  
 
BEGIN 
	SET NOCOUNT ON;

	IF	OBJECT_ID('tempdb..#tmp8RMPerformance') IS NOT NULL
	BEGIN
		DROP TABLE	#tmp8RMPerformance;
	END;

	CREATE TABLE	#tmp8RMPerformance (
			LeagueGroupId		SMALLINT
		,	LeagueId			INT
		,   BetCount			INT
		,	Stake_VR			MONEY
		,	WinLoss_VR			MONEY
		,	Stake_AR			MONEY
		,	WinLoss_AR			MONEY
		,	TypeSiteId			TINYINT
		,	PRIMARY KEY CLUSTERED (
				LeagueGroupId	ASC
			,	LeagueId		ASC
			,	TypeSiteId		ASC
		)
	);	

	IF	OBJECT_ID('tempdb..#tmpTotalPerformance') IS NOT NULL
	BEGIN
		DROP TABLE	#tmpTotalPerformance;
	END;

	CREATE TABLE	#tmpTotalPerformance (
			LeagueGroupId		SMALLINT
		,	LeagueId			INT
		,   BetCount			INT
		,   MatchCount			INT
		,	Stake_VR			MONEY
		,	WinLoss_VR			MONEY
		,	Stake_AR			MONEY
		,	WinLoss_AR			MONEY
		,	TypeSiteId			TINYINT
		,	PRIMARY KEY CLUSTERED (
				LeagueGroupId	ASC
			,	LeagueId		ASC
			,	TypeSiteId		ASC
		)
	);	

	DECLARE @Bettypes AS TABLE (BettypeId SMALLINT PRIMARY KEY CLUSTERED);
	INSERT INTO @Bettypes(BettypeId)
	VALUES (1), (3), (7), (8);
	
	DECLARE @FilterSite AS TABLE (TypeSiteId TINYINT PRIMARY KEY CLUSTERED, TypeSiteDesc VARCHAR(20));
	INSERT INTO @FilterSite(TypeSiteId, TypeSiteDesc)
	SELECT DISTINCT TypeSiteId, TypeSiteDesc FROM dbo.FilteredSite WITH(NOLOCK);

	IF @TypeSiteIds <> ''
	BEGIN
		DECLARE @TypeSites AS TABLE (TypeSiteId TINYINT PRIMARY KEY CLUSTERED);
		INSERT INTO @TypeSites(TypeSiteId)
		SELECT val FROM dbo.strSplit_Key(@TypeSiteIds,',');
	END;

	IF @IsExportExcel = 0
	BEGIN
		DECLARE @Leagues AS TABLE (LeagueId INT PRIMARY KEY CLUSTERED)
		IF @LeagueIds <> ''
		BEGIN
			INSERT INTO @Leagues(LeagueId)
			SELECT val 
			FROM dbo.strSplit_Key(@LeagueIds,',');
		END;
	END;

	-- Export to excel file
	IF @IsExportExcel = 1
	BEGIN
		INSERT INTO @Leagues(LeagueId)
		SELECT DISTINCT r.LeagueId
		FROM dbo.RobotTrading AS r WITH(NOLOCK)
			INNER JOIN @Bettypes AS b ON r.BetType = b.BettypeId
			LEFT JOIN @TypeSites AS ts ON r.TypeSiteId = ts.TypeSiteId
		WHERE r.EventDate BETWEEN @FromDate AND @ToDate
			AND r.[Type] = @Model
			AND (@TypeSiteIds = '' OR ts.TypeSiteId IS NOT NULL);
	END;

	-- 8RM performance
	INSERT INTO #tmp8RMPerformance(LeagueGroupId, LeagueId, BetCount, Stake_VR, WinLoss_VR, Stake_AR, WinLoss_AR, TypeSiteId)
	SELECT	r.LeagueGroupId
		,	r.LeagueId
		,	SUM(r.BetCount)
		,	SUM(r.Stake_VR)
		,	- SUM(r.WinLoss_VR - r.Comm_VR)
		,	SUM(r.Stake_AR)
		,	- SUM(r.WinLoss_AR - r.Comm_AR)
		,	r.TypeSiteId
	FROM dbo.RobotTrading AS r WITH(NOLOCK)
		INNER JOIN @Leagues AS lg ON r.LeagueId = lg.LeagueId
		INNER JOIN @Bettypes AS b ON r.BetType = b.BettypeId
		LEFT JOIN @TypeSites AS ts ON r.TypeSiteId = ts.TypeSiteId
	WHERE r.EventDate BETWEEN @FromDate AND @ToDate
		AND r.Is8RM = 1
		AND r.[Type] = @Model
		AND (@TypeSiteIds = '' OR ts.TypeSiteId IS NOT NULL)
	GROUP BY r.LeagueGroupId, r.LeagueId, r.TypeSiteId;

	INSERT INTO #tmpTotalPerformance(LeagueGroupId, LeagueId, BetCount, MatchCount, Stake_VR, WinLoss_VR, Stake_AR, WinLoss_AR, TypeSiteId)
	SELECT	r.LeagueGroupId
		,	r.LeagueId
		,	SUM(r.BetCount)
		,	COUNT(DISTINCT r.MatchId)
		,	SUM(r.Stake_VR)
		,	SUM(r.WinLoss_VR - r.Comm_VR)
		,	SUM(r.Stake_AR)
		,	SUM(r.WinLoss_AR - r.Comm_AR)
		,	r.TypeSiteId
	FROM dbo.RobotTrading AS r WITH(NOLOCK)
		INNER JOIN @Leagues AS lg ON r.LeagueId = lg.LeagueId
		INNER JOIN @Bettypes AS b ON r.BetType = b.BettypeId
		LEFT JOIN @TypeSites AS ts ON r.TypeSiteId = ts.TypeSiteId
	WHERE r.EventDate BETWEEN @FromDate AND @ToDate
		AND r.[Type] = @Model
		AND (@TypeSiteIds = '' OR ts.TypeSiteId IS NOT NULL)
	GROUP BY r.LeagueGroupId, r.LeagueId, r.TypeSiteId;

	-- LeagueGroupId, LeagueId, MatchCount & BetCount by Event (LeagueGroupId) - LeagueId
	SELECT	r.LeagueGroupId
		,	r.LeagueId
		,	l.LeagueName
		,	COUNT(DISTINCT r.MatchId) AS MatchCount
		,	STUFF((SELECT DISTINCT ',', CONVERT(VARCHAR(MAX), r2.MatchId)
					FROM dbo.RobotTrading r2 WITH (NOLOCK)
						INNER JOIN @Bettypes AS b ON r2.BetType = b.BettypeId
						LEFT JOIN @TypeSites AS ts ON r2.TypeSiteId = ts.TypeSiteId
					WHERE r.LeagueId = r2.LeagueId AND r2.[Type] = @Model
						AND (@TypeSiteIds = '' OR ts.TypeSiteId IS NOT NULL)
					FOR XML PATH('')), 1, 1, '') AS MatchIdList
		,	ISNULL(SUM(r.BetCount), 0) AS BetCount
	FROM dbo.RobotTrading AS r WITH(NOLOCK)
		INNER JOIN @Leagues AS lg ON r.LeagueId = lg.LeagueId
		INNER JOIN bodb02.dbo.league AS l ON l.LeagueId = lg.LeagueId
		INNER JOIN @Bettypes AS b ON r.BetType = b.BettypeId
		LEFT JOIN @TypeSites AS ts ON r.TypeSiteId = ts.TypeSiteId
	WHERE r.EventDate BETWEEN @FromDate AND @ToDate
		AND r.[Type] = @Model
		AND (@TypeSiteIds = '' OR ts.TypeSiteId IS NOT NULL)
	GROUP BY r.LeagueGroupId, r.LeagueId, l.leaguename;

	-- Detailed by Event (LeagueGroupId) - LeagueId
	SELECT	t.LeagueGroupId
		,	t.LeagueId
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
	ORDER BY t.LeagueGroupId ASC, t.LeagueId ASC;

	DROP TABLE #tmp8RMPerformance;
	DROP TABLE #tmpTotalPerformance;
END;

GO
/*<info serverAlias="DBTGRS-bodb_TGRS" executers="bodbTGRSNet" isFunction="0" isNested="0"></info>*/