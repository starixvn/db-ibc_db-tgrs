ALTER PROCEDURE [dbo].[TGRS_Rpt_RobotTrading_Week]
		@FromDate			DATE
	,	@ToDate				DATE
	,	@Model				TINYINT =  3
	,	@LeagueGroupIds		VARCHAR(2000) =  '1'
	,	@TypeSiteIds		VARCHAR(200) =  ''
AS    
/*  
	Created:	20200305@John.Ngo
	Task :		Automation Trading - Report by Week
	DB:			DBTGRS.bodb_TGRS
	Original:  
  
	Revisions: 	
   		- 20200305@John.Ngo: Created [Redmine ID: 129838]

	Param's Explanation: 
		- @Model =  3: TA, 1: RT3
	
	Exam: EXECUTE dbo.TGRS_Rpt_RobotTrading_Week @FromDate = '20200101', @ToDate = '20200215', @Model = 3, @LeagueGroupIds = '1,2,3,4,5,6',	@TypeSiteIds = ''
  
*/  
 
BEGIN 
	SET NOCOUNT ON;

DECLARE @StartDate DATE = @FromDate
	,	@EndDate   DATE = CASE WHEN (DATENAME(DW, @FromDate) = 'Sunday') THEN @FromDate ELSE DATEADD(DAY, (DATEDIFF(DAY, 6, @FromDate) / 7) * 7 + 7, 6) END
	,	@WeekDays  VARCHAR(100);

	IF	OBJECT_ID('tempdb..#tmp8RMPerformance') IS NOT NULL
	BEGIN
		DROP TABLE	#tmp8RMPerformance;
	END;

	CREATE TABLE	#tmp8RMPerformance (
			WeekDays			VARCHAR(100)
		,	StartDate			DATE 
		,	EndDate				DATE
		,   BetCount			INT
		,	Stake_VR			MONEY
		,	WinLoss_VR			MONEY
		,	Stake_AR			MONEY
		,	WinLoss_AR			MONEY
		,	TypeSiteId			TINYINT
		,	PRIMARY KEY CLUSTERED (
				WeekDays		ASC
			,	TypeSiteId		ASC
		)
	);	

	IF	OBJECT_ID('tempdb..#tmpTotalPerformance') IS NOT NULL
	BEGIN
		DROP TABLE	#tmpTotalPerformance;
	END;

	CREATE TABLE	#tmpTotalPerformance (
			WeekDays			VARCHAR(100)
		,	StartDate			DATE 
		,	EndDate				DATE
		,   BetCount			INT
		,   MatchCount			INT
		,	Stake_VR			MONEY
		,	WinLoss_VR			MONEY
		,	Stake_AR			MONEY
		,	WinLoss_AR			MONEY
		,	TypeSiteId			TINYINT
		,	PRIMARY KEY CLUSTERED (
				WeekDays		ASC
			,	TypeSiteId		ASC
		)
	);	

	IF	OBJECT_ID('tempdb..#tmpTotalLMB') IS NOT NULL
	BEGIN
		DROP TABLE	#tmpTotalLMB;
	END;

	CREATE TABLE	#tmpTotalLMB (
			WeekDays			VARCHAR(100)
		,	StartDate			DATE 
		,	EndDate				DATE
		,   LeagueCount			INT
		,   MatchCount			INT
		,   BetCount			INT
		,	PRIMARY KEY CLUSTERED (
				WeekDays		ASC
		)
	);	


	DECLARE @LeagueGroups AS TABLE (LeagueGroupId SMALLINT PRIMARY KEY CLUSTERED)
	IF @LeagueGroupIds <> ''
	BEGIN
		INSERT INTO @LeagueGroups(LeagueGroupId)
		SELECT val 
		FROM dbo.strSplit_Key(@LeagueGroupIds,',');

		IF CHARINDEX('6', @LeagueGroupIds) > 0
		BEGIN
			DELETE FROM @LeagueGroups
			WHERE LeagueGroupId = 6;

			INSERT INTO @LeagueGroups(LeagueGroupId)
			SELECT DISTINCT l.LeagueGroupID
			FROM bodb02.dbo.league AS l WITH(NOLOCK)
			WHERE l.LeagueGroupID NOT IN (1,2,3,4,5);
		END;
	END
	ELSE 
	BEGIN
		INSERT INTO @LeagueGroups
		VALUES(1);
	END;

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
	
	-- Start Cal Week
	DECLARE	@Date TABLE (ID INT IDENTITY(1,1), StartDate DATE ,EndDate DATE, WeekDays VARCHAR(100));

	WHILE (@EndDate < @ToDate)
	BEGIN	
		INSERT @Date(StartDate, EndDate) VALUES(@StartDate, @EndDate);

		UPDATE @Date 
			SET	WeekDays = 'Week '+ CAST((SELECT MAX(ID) FROM @Date) AS VARCHAR(10)) 
		WHERE ID = (SELECT MAX(ID) FROM @Date);

		SELECT @StartDate = DATEADD(DAY, 1, @EndDate);
		SELECT @EndDate = CASE WHEN (DATENAME(DW, @StartDate) = 'Sunday') THEN @StartDate ELSE DATEADD(DAY, (DATEDIFF(DAY, 6, @StartDate) / 7) * 7 + 7, 6) END;
	END;
	
	SELECT @WeekDays  = (CASE WHEN EXISTS (SELECT 1 FROM @Date) THEN 'Week '+ CAST((SELECT MAX(ID) + 1 FROM @Date) AS VARCHAR(10)) ELSE  'Week 1' END);

	INSERT @Date(WeekDays, StartDate, EndDate) VALUES(@WeekDays, @StartDate, @ToDate);

	-- SELECT ID, WeekDays, StartDate, EndDate, DATENAME(DW, StartDate) AS StartName, DATENAME(DW, EndDate) AS EndName FROM @Date;
	-- End Cal Week

	WHILE	EXISTS (SELECT TOP(1) 1	FROM @Date)
		BEGIN
			SELECT	TOP(1)
					@WeekDays = d.WeekDays
				,	@StartDate = d.StartDate
				,	@EndDate = d.EndDate
			FROM	@Date AS d
			ORDER BY WeekDays DESC;

		-- 8RM performance
		INSERT INTO #tmp8RMPerformance(WeekDays, StartDate, EndDate, BetCount, Stake_VR, WinLoss_VR, Stake_AR, WinLoss_AR, TypeSiteId)
		SELECT	@WeekDays
			,	@StartDate
			,	@EndDate
			,	SUM(r.BetCount)
			,	SUM(r.Stake_VR)
			,	- SUM(r.WinLoss_VR - r.Comm_VR)
			,	SUM(r.Stake_AR)
			,	- SUM(r.WinLoss_AR - r.Comm_AR)
			,	r.TypeSiteId
		FROM dbo.RobotTrading AS r WITH(NOLOCK)
			INNER JOIN @LeagueGroups AS lg ON r.LeagueGroupId = lg.LeagueGroupId
			INNER JOIN @Bettypes AS b ON r.BetType = b.BettypeId
			LEFT JOIN @TypeSites AS ts ON r.TypeSiteId = ts.TypeSiteId
		WHERE r.EventDate BETWEEN @StartDate AND @EndDate
			AND r.Is8RM = 1
			AND r.[Type] = @Model
			AND (@TypeSiteIds = '' OR ts.TypeSiteId IS NOT NULL)
		GROUP BY r.TypeSiteId;

		INSERT INTO #tmpTotalPerformance(WeekDays, StartDate, EndDate, BetCount, MatchCount, Stake_VR, WinLoss_VR, Stake_AR, WinLoss_AR, TypeSiteId)
		SELECT	@WeekDays
			,	@StartDate
			,	@EndDate
			,	SUM(r.BetCount)
			,	COUNT(DISTINCT r.MatchId)
			,	SUM(r.Stake_VR)
			,	SUM(r.WinLoss_VR - r.Comm_VR)
			,	SUM(r.Stake_AR)
			,	SUM(r.WinLoss_AR - r.Comm_AR)
			,	r.TypeSiteId
		FROM dbo.RobotTrading AS r WITH(NOLOCK)
			INNER JOIN @LeagueGroups AS lg ON r.LeagueGroupId = lg.LeagueGroupId
			INNER JOIN @Bettypes AS b ON r.BetType = b.BettypeId
			LEFT JOIN @TypeSites AS ts ON r.TypeSiteId = ts.TypeSiteId
		WHERE r.EventDate BETWEEN @StartDate AND @EndDate
			AND r.[Type] = @Model
			AND (@TypeSiteIds = '' OR ts.TypeSiteId IS NOT NULL)
		GROUP BY r.TypeSiteId;
		
		INSERT INTO #tmpTotalLMB(WeekDays, StartDate, EndDate, LeagueCount, MatchCount, BetCount)
		SELECT	@WeekDays
			,	@StartDate
			,	@EndDate
			,	COUNT(DISTINCT r.LeagueId) AS LeagueCount
			,	COUNT(DISTINCT r.MatchId) AS MatchCount
			,	ISNULL(SUM(r.BetCount), 0) AS BetCount
		FROM dbo.RobotTrading AS r WITH(NOLOCK)
			INNER JOIN @LeagueGroups AS lg ON r.LeagueGroupId = lg.LeagueGroupId
			INNER JOIN @Bettypes AS b ON r.BetType = b.BettypeId
			LEFT JOIN @TypeSites AS ts ON r.TypeSiteId = ts.TypeSiteId
		WHERE r.EventDate BETWEEN @StartDate AND @EndDate
			AND r.[Type] = @Model
			AND (@TypeSiteIds = '' OR ts.TypeSiteId IS NOT NULL);

		DELETE	d
		FROM	@Date AS d
		WHERE	d.WeekDays = @WeekDays;
	END;

	-- Total LeagueCount & MatchCount
	SELECT  COUNT(DISTINCT r.LeagueId) AS LeagueCount
		,	COUNT(DISTINCT r.MatchId) AS MatchCount
	FROM dbo.RobotTrading AS r WITH(NOLOCK)
		INNER JOIN @LeagueGroups AS lg ON r.LeagueGroupId = lg.LeagueGroupId
		INNER JOIN @Bettypes AS b ON r.BetType = b.BettypeId
		LEFT JOIN @TypeSites AS ts ON r.TypeSiteId = ts.TypeSiteId
	WHERE r.EventDate BETWEEN @FromDate AND @ToDate
		AND r.[Type] = @Model
		AND (@TypeSiteIds = '' OR ts.TypeSiteId IS NOT NULL);

	-- LeagueCount, MatchCount & BetCount by Week
	SELECT	WeekDays
		,	StartDate
		,	EndDate
		,	LeagueCount	
		,	MatchCount
		,	BetCount
	FROM #tmpTotalLMB AS tm WITH(NOLOCK) WHERE tm.LeagueCount > 0;

	-- Total
	SELECT	SUM(t.Stake_VR) AS Total_Stake_VR
		,	SUM(t.WinLoss_VR) AS Total_WinLoss_VR
		,	CASE WHEN ISNULL(SUM(t.WinLoss_VR), 0) <> 0 THEN SUM(t.WinLoss_VR)*100/SUM(t.Stake_VR) ELSE NULL END AS Total_Margin_VR

		,	SUM(ABS(t.Stake_AR - t.Stake_VR)) AS Total_Stake_VAR
		,	SUM(t.WinLoss_AR - t.WinLoss_VR) AS Total_Winloss_VAR
		,	CASE WHEN ISNULL(SUM(ABS(t.Stake_AR - t.Stake_VR)), 0) <> 0 THEN SUM(t.WinLoss_AR - t.WinLoss_VR)*100/SUM(ABS(t.Stake_AR - t.Stake_VR)) ELSE NULL END AS Total_Margin_VAR

		,	SUM(t.Stake_AR - (CASE WHEN r.WeekDays IS NULL THEN 0 ELSE r.Stake_AR END)) AS Total_Stake_AR
		,	SUM(t.WinLoss_AR + (CASE WHEN r.WeekDays IS NULL THEN 0 ELSE r.WinLoss_AR END)) AS Total_Winloss_AR
		,	CASE WHEN ISNULL(SUM(t.Stake_AR - (CASE WHEN r.WeekDays IS NULL THEN 0 ELSE r.Stake_AR END)), 0) <> 0 THEN SUM(t.WinLoss_AR + (CASE WHEN r.WeekDays IS NULL THEN 0 ELSE r.WinLoss_AR END))*100/SUM(t.Stake_AR - (CASE WHEN r.WeekDays IS NULL THEN 0 ELSE r.Stake_AR END)) ELSE NULL END AS Total_Margin_AR

		,	SUM(CASE WHEN r.WeekDays IS NULL THEN 0 ELSE r.Stake_AR END) AS Total_Stake_8RM
		,	SUM(CASE WHEN r.WeekDays IS NULL THEN 0 ELSE r.WinLoss_AR END) AS Total_Winloss_8RM
		,	CASE WHEN ISNULL(SUM(CASE WHEN r.WeekDays IS NULL THEN 0 ELSE r.Stake_AR END), 0) <> 0 THEN SUM(CASE WHEN r.WeekDays IS NULL THEN 0 ELSE r.WinLoss_AR END)*100/SUM(CASE WHEN r.WeekDays IS NULL THEN 0 ELSE r.Stake_AR END) ELSE NULL END AS Total_Margin_8RM

		,	SUM(t.Stake_AR) AS Total_Stake_AR8RM
		,	SUM(t.WinLoss_AR) AS Total_Winloss_AR8RM
		,	CASE WHEN ISNULL(SUM(t.Stake_AR), 0) <> 0 THEN SUM(t.WinLoss_AR)*100/SUM(t.Stake_AR) ELSE NULL END AS Total_Margin_AR8RM
	FROM #tmpTotalPerformance AS t WITH(NOLOCK)
		LEFT JOIN #tmp8RMPerformance AS r WITH(NOLOCK) ON t.WeekDays = r.WeekDays AND t.TypeSiteId = r.TypeSiteId;
		
	-- Detailed by Week
	SELECT	t.WeekDays, t.StartDate, t.EndDate
		,	t.BetCount
		,	t.MatchCount

		,	t.Stake_VR
		,	t.WinLoss_VR
		,	CASE WHEN ISNULL(t.WinLoss_VR, 0) <> 0 THEN t.WinLoss_VR*100/t.Stake_VR ELSE NULL END AS Margin_VR

		,	ABS(t.Stake_AR - t.Stake_VR) AS Stake_VAR
		,	(t.WinLoss_AR - t.WinLoss_VR) AS Winloss_VAR
		,	CASE WHEN ISNULL(ABS(t.Stake_AR - t.Stake_VR), 0) <> 0 THEN (t.WinLoss_AR - t.WinLoss_VR)*100/ABS(t.Stake_AR - t.Stake_VR) ELSE NULL END AS Margin_VAR

		,	(t.Stake_AR - (CASE WHEN r.WeekDays IS NULL THEN 0 ELSE r.Stake_AR END)) AS Stake_AR
		,	(t.WinLoss_AR + (CASE WHEN r.WeekDays IS NULL THEN 0 ELSE r.WinLoss_AR END)) AS Winloss_AR
		,	CASE WHEN ISNULL((t.Stake_AR - (CASE WHEN r.WeekDays IS NULL THEN 0 ELSE r.Stake_AR END)), 0) <> 0 THEN (t.WinLoss_AR + (CASE WHEN r.WeekDays IS NULL THEN 0 ELSE r.WinLoss_AR END))*100/(t.Stake_AR - (CASE WHEN r.WeekDays IS NULL THEN 0 ELSE r.Stake_AR END)) ELSE NULL END AS Margin_AR

		,	(CASE WHEN r.WeekDays IS NULL THEN 0 ELSE r.Stake_AR END) AS Stake_8RM
		,	(CASE WHEN r.WeekDays IS NULL THEN 0 ELSE r.WinLoss_AR END) AS Winloss_8RM
		,	CASE WHEN ISNULL((CASE WHEN r.WeekDays IS NULL THEN 0 ELSE r.Stake_AR END), 0) <> 0 THEN (CASE WHEN r.WeekDays IS NULL THEN 0 ELSE r.WinLoss_AR END)*100/(CASE WHEN r.WeekDays IS NULL THEN 0 ELSE r.Stake_AR END) ELSE NULL END AS Margin_8RM

		,	t.Stake_AR AS Stake_AR8RM
		,	t.WinLoss_AR AS Winloss_AR8RM
		,	CASE WHEN ISNULL(t.Stake_AR, 0) <> 0 THEN t.WinLoss_AR*100/t.Stake_AR ELSE NULL END AS Margin_AR8RM
		,	t.TypeSiteId
		,	fs.TypeSiteDesc
	FROM #tmpTotalPerformance AS t WITH(NOLOCK)
		LEFT JOIN #tmp8RMPerformance AS r WITH(NOLOCK) ON t.WeekDays = r.WeekDays AND t.TypeSiteId = r.TypeSiteId
		INNER JOIN @FilterSite AS fs ON t.TypeSiteId = fs.TypeSiteId
	WHERE t.BetCount IS NOT NULL;

	DROP TABLE #tmp8RMPerformance;
	DROP TABLE #tmpTotalPerformance;

END;

GO
/*<info serverAlias="DBTGRS-bodb_TGRS" executers="bodbTGRSNet" isFunction="0" isNested="0"></info>*/