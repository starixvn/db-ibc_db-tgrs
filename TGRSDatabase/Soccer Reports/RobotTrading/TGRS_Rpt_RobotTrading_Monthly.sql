ALTER PROCEDURE [dbo].[TGRS_Rpt_RobotTrading_Monthly]
		@FromDate			DATE
	,	@ToDate				DATE
	,	@Model				TINYINT =  3
	,	@LeagueGroupIds		VARCHAR(2000) =  '1'
	,	@TypeSiteIds		VARCHAR(200) =  ''
AS    
/*  
	Created:	20191230@Long.Luu
	Task :		Robot Trading - Monthly
	DB:			DBTGRS.bodb_TGRS
	Original:  
  
	Revisions: 	
   		- 20191227@Long.Luu: Created [Redmine ID: 123714]
		- 20200120@John.Ngo: [TGR Soccer] RT3 Performance - Model Comparision Report [Redmine ID: 127208]
		- 20200210@John.Ngo: [TGR Soccer] RT3 - Adding TA model into Robot Trading by Bettype and Month [Redmine ID: 128184]
		- 20200310@John.Ngo: Automation Trading - Report by Week (LeagueCount) [Redmine ID: 129838]
		- 20200325@John.Ngo: Automation Trading by Period/Bettype - Drill down to event performance [Redmine ID: 130791]
		- 20200407@John.Ngo: Separate LeagueGroupId (1 -> 11) [Redmine ID: 132038]
		- 20200424@John.Ngo: Update logic @FirstMonthFromDate [Redmine ID: 131517]
		- 20200706@John.Ngo: TA Performance - Exclude major leagues from June 25 [Redmine ID: 137063]

	Param's Explanation: 
		- @Model =  3: TA, 1: RT3
	Exam: 
  
*/  
 
BEGIN 
	SET NOCOUNT ON;

	DECLARE @FromDateMonth	INT = MONTH(@FromDate),
			@FromDateYear	INT = YEAR(@FromDate),
			@ToDateMonth	INT = MONTH(@ToDate),
			@ToDateYear		INT = YEAR(@ToDate);

	DECLARE @FirstMonthFromDate DATE = @FromDate,
			@FirstMonthToDate	DATE,
			@LastMonthFromDate	DATE = CAST(CAST(@ToDateMonth AS VARCHAR) + '/01/' + CAST(@ToDateYear AS VARCHAR) AS DATE),
			@LastMonthToDate	DATE = @ToDate,
			@TheRestFromDate	DATE = CAST(CAST(MONTH(DATEADD(MONTH, 1, @FromDate)) AS VARCHAR) + '/01/' + CAST(YEAR(DATEADD(MONTH, 1, @FromDate)) AS VARCHAR) AS DATE),
			@TheRestToDate		DATE;
	SELECT	@FirstMonthToDate = DATEADD(DAY, -1, @TheRestFromDate)
		,	@TheRestToDate = DATEADD(DAY, -1, @LastMonthFromDate);

	IF	OBJECT_ID('tempdb..#tmpRobotTrading') IS NOT NULL
	BEGIN
		DROP TABLE	#tmpRobotTrading;
	END;

	CREATE TABLE	#tmpRobotTrading (
			TraderId			INT
		,	MatchId				INT
		,	LeagueId			INT
		,	LeagueGroupId		SMALLINT
		,	EventDate			DATE
		,	BetType				SMALLINT
		,	Is8RM				BIT
		,   BetCount			INT
		,   MatchCount			INT
		,	Stake_VR			MONEY
		,	WinLoss_VR			MONEY
		,	Comm_VR				MONEY
		,	Stake_AR			MONEY
		,	WinLoss_AR			MONEY
		,	Comm_AR				MONEY
		,	TypeSiteId			TINYINT
		,	[Type]				TINYINT
	);	

	CREATE CLUSTERED INDEX	#CIX_tmpRobotTrading_EventDate ON #tmpRobotTrading (
			EventDate			ASC
	);	

	CREATE NONCLUSTERED INDEX	#IX_tmpRobotTradingIdx ON #tmpRobotTrading (
			MatchId				ASC
		,	BetType				ASC
		,	Is8RM				ASC
		,	[Type]				ASC
	);

	IF	OBJECT_ID('tempdb..#tmp8RMPerformance') IS NOT NULL
	BEGIN
		DROP TABLE	#tmp8RMPerformance;
	END;

	CREATE TABLE	#tmp8RMPerformance (
			RptMonth			DATE
		,   BetCount			INT
		,	Stake_VR			MONEY
		,	WinLoss_VR			MONEY
		,	Stake_AR			MONEY
		,	WinLoss_AR			MONEY
		,	TypeSiteId			TINYINT
		,	PRIMARY KEY CLUSTERED (
				RptMonth		ASC
			,	TypeSiteId		ASC
		)
	);	

	IF	OBJECT_ID('tempdb..#tmpTotalPerformance') IS NOT NULL
	BEGIN
		DROP TABLE	#tmpTotalPerformance;
	END;

	CREATE TABLE	#tmpTotalPerformance (
			RptMonth			DATE
		,   BetCount			INT
		,   MatchCount			INT
		,	Stake_VR			MONEY
		,	WinLoss_VR			MONEY
		,	Stake_AR			MONEY
		,	WinLoss_AR			MONEY
		,	TypeSiteId			TINYINT
		,	PRIMARY KEY CLUSTERED (
				RptMonth		ASC
			,	TypeSiteId		ASC
		)
	);	

	DECLARE @LeagueGroups AS TABLE (LeagueGroupId SMALLINT PRIMARY KEY CLUSTERED)
	IF @LeagueGroupIds <> ''
	BEGIN
		INSERT INTO @LeagueGroups(LeagueGroupId)
		SELECT val 
		FROM dbo.strSplit_Key(@LeagueGroupIds,',');
	END
	ELSE 
	BEGIN
		INSERT INTO @LeagueGroups
		VALUES(1);
	END;

	DECLARE @Bettypes AS TABLE (BettypeId SMALLINT PRIMARY KEY CLUSTERED);
	INSERT INTO @Bettypes(BettypeId)
	VALUES (1), (3), (7), (8);
	
	-- LeagueExclusion from 'June 25, 2020 -> Today'
	DECLARE @LeagueExclusionDate DATE = '20200625'
	DECLARE @LeagueExclusion AS TABLE (LeagueId INT PRIMARY KEY CLUSTERED);
	INSERT INTO @LeagueExclusion(LeagueId)
	VALUES (3), (4), (5), (43);

	DECLARE @FilterSite AS TABLE (TypeSiteId TINYINT PRIMARY KEY CLUSTERED, TypeSiteDesc VARCHAR(20));
	INSERT INTO @FilterSite(TypeSiteId, TypeSiteDesc)
	SELECT DISTINCT TypeSiteId, TypeSiteDesc FROM dbo.FilteredSite WITH(NOLOCK);

	IF @TypeSiteIds <> ''
	BEGIN
		DECLARE @TypeSites AS TABLE (TypeSiteId TINYINT PRIMARY KEY CLUSTERED);
		INSERT INTO @TypeSites(TypeSiteId)
		SELECT val FROM dbo.strSplit_Key(@TypeSiteIds,',');
	END;
	
	IF @LeagueExclusionDate <= @FromDate OR (@LeagueExclusionDate > @FromDate AND @LeagueExclusionDate > @ToDate)
		BEGIN
			INSERT INTO #tmpRobotTrading(TraderId, MatchId, EventDate, BetType, LeagueId, LeagueGroupId, Is8RM, BetCount, Stake_VR, WinLoss_VR, Comm_VR, Stake_AR, WinLoss_AR, Comm_AR, TypeSiteId, [Type])
			SELECT	r.TraderId
				,	r.MatchId
				,	r.EventDate
				,	r.BetType
				,	r.LeagueId
				,	r.LeagueGroupId
				,	r.Is8RM
				,	r.BetCount
				,	r.Stake_VR
				,	r.WinLoss_VR
				,	r.Comm_VR
				,	r.Stake_AR
				,	r.WinLoss_AR 
				,	r.Comm_AR
				,	r.TypeSiteId
				,	r.[Type]
			FROM dbo.RobotTrading AS r WITH(NOLOCK)
				INNER JOIN @Bettypes AS b ON r.BetType = b.BettypeId
				LEFT JOIN @TypeSites AS ts ON r.TypeSiteId = ts.TypeSiteId
				LEFT JOIN @LeagueExclusion AS le ON r.LeagueId = le.LeagueId
			WHERE r.EventDate BETWEEN @FromDate AND @ToDate
				AND r.LeagueGroupId IN (1,2,3,4,5,6,7,8,9,10,11)
				AND r.[Type] = @Model
				AND (@TypeSiteIds = '' OR ts.TypeSiteId IS NOT NULL)
				AND (le.LeagueId IS NULL);
		END;

	IF @LeagueExclusionDate > @FromDate AND @LeagueExclusionDate <= @ToDate
		BEGIN
			INSERT INTO #tmpRobotTrading(TraderId, MatchId, EventDate, BetType, LeagueId, LeagueGroupId, Is8RM, BetCount, Stake_VR, WinLoss_VR, Comm_VR, Stake_AR, WinLoss_AR, Comm_AR, TypeSiteId, [Type])
			SELECT	r.TraderId
				,	r.MatchId
				,	r.EventDate
				,	r.BetType
				,	r.LeagueId
				,	r.LeagueGroupId
				,	r.Is8RM
				,	r.BetCount
				,	r.Stake_VR
				,	r.WinLoss_VR
				,	r.Comm_VR
				,	r.Stake_AR
				,	r.WinLoss_AR 
				,	r.Comm_AR
				,	r.TypeSiteId
				,	r.[Type]
			FROM dbo.RobotTrading AS r WITH(NOLOCK)
				INNER JOIN @Bettypes AS b ON r.BetType = b.BettypeId
				LEFT JOIN @TypeSites AS ts ON r.TypeSiteId = ts.TypeSiteId
			WHERE r.EventDate BETWEEN @FromDate AND DATEADD(DD,-1,@LeagueExclusionDate)
				AND r.LeagueGroupId IN (1,2,3,4,5,6,7,8,9,10,11)
				AND r.[Type] = @Model
				AND (@TypeSiteIds = '' OR ts.TypeSiteId IS NOT NULL);
			
			INSERT INTO #tmpRobotTrading(TraderId, MatchId, EventDate, BetType, LeagueId, LeagueGroupId, Is8RM, BetCount, Stake_VR, WinLoss_VR, Comm_VR, Stake_AR, WinLoss_AR, Comm_AR, TypeSiteId, [Type])
			SELECT	r.TraderId
				,	r.MatchId
				,	r.EventDate
				,	r.BetType
				,	r.LeagueId
				,	r.LeagueGroupId
				,	r.Is8RM
				,	r.BetCount
				,	r.Stake_VR
				,	r.WinLoss_VR
				,	r.Comm_VR
				,	r.Stake_AR
				,	r.WinLoss_AR 
				,	r.Comm_AR
				,	r.TypeSiteId
				,	r.[Type]
			FROM dbo.RobotTrading AS r WITH(NOLOCK)
				INNER JOIN @Bettypes AS b ON r.BetType = b.BettypeId
				LEFT JOIN @TypeSites AS ts ON r.TypeSiteId = ts.TypeSiteId
				LEFT JOIN @LeagueExclusion AS le ON r.LeagueId = le.LeagueId
			WHERE r.EventDate BETWEEN @LeagueExclusionDate AND @ToDate
				AND r.LeagueGroupId IN (1,2,3,4,5,6,7,8,9,10,11)
				AND r.[Type] = @Model
				AND (@TypeSiteIds = '' OR ts.TypeSiteId IS NOT NULL)
				AND (le.LeagueId IS NULL);
		END;

		-- Update lastest LeagueGroupId
		UPDATE c
		SET c.LeagueGroupId = mm.LeagueGroupId
		FROM #tmpRobotTrading c
			INNER JOIN (
						SELECT m.LeagueId , m.LeagueGroupId, ROW_NUMBER() OVER(PARTITION BY m.LeagueId ORDER BY m.EventDate DESC) AS Row_Num
						FROM #tmpRobotTrading m
						) mm ON mm.LeagueId = c.LeagueId
		WHERE mm.Row_Num = 1;

		-- 8RM performance
		INSERT INTO #tmp8RMPerformance(RptMonth, BetCount, Stake_VR, WinLoss_VR, Stake_AR, WinLoss_AR, TypeSiteId)
		SELECT	CAST(MONTH(r.EventDate) AS VARCHAR) + '/01/' + CAST(YEAR(r.EventDate) AS VARCHAR) AS DATE
			,	SUM(r.BetCount)
			,	SUM(r.Stake_VR)
			,	- SUM(r.WinLoss_VR - r.Comm_VR)
			,	SUM(r.Stake_AR)
			,	- SUM(r.WinLoss_AR - r.Comm_AR)
			,	r.TypeSiteId
		FROM #tmpRobotTrading AS r WITH(NOLOCK)
			INNER JOIN @LeagueGroups AS lg ON r.LeagueGroupId = lg.LeagueGroupId
			INNER JOIN @Bettypes AS b ON r.BetType = b.BettypeId
			LEFT JOIN @TypeSites AS ts ON r.TypeSiteId = ts.TypeSiteId
		WHERE r.EventDate BETWEEN @FromDate AND @ToDate
			AND r.Is8RM = 1
			AND r.[Type] = @Model
			AND (@TypeSiteIds = '' OR ts.TypeSiteId IS NOT NULL)
		GROUP BY YEAR(r.EventDate), MONTH(r.EventDate), r.TypeSiteId;

		INSERT INTO #tmpTotalPerformance(RptMonth, BetCount, MatchCount, Stake_VR, WinLoss_VR, Stake_AR, WinLoss_AR, TypeSiteId)
		SELECT	CAST(MONTH(r.EventDate) AS VARCHAR) + '/01/' + CAST(YEAR(r.EventDate) AS VARCHAR) AS DATE
			,	SUM(r.BetCount)
			,	COUNT(DISTINCT r.MatchId)
			,	SUM(r.Stake_VR)
			,	SUM(r.WinLoss_VR - r.Comm_VR)
			,	SUM(r.Stake_AR)
			,	SUM(r.WinLoss_AR - r.Comm_AR)
			,	r.TypeSiteId
		FROM #tmpRobotTrading AS r WITH(NOLOCK)
			INNER JOIN @LeagueGroups AS lg ON r.LeagueGroupId = lg.LeagueGroupId
			INNER JOIN @Bettypes AS b ON r.BetType = b.BettypeId
			LEFT JOIN @TypeSites AS ts ON r.TypeSiteId = ts.TypeSiteId
		WHERE r.EventDate BETWEEN @FromDate AND @ToDate
			AND r.[Type] = @Model
			AND (@TypeSiteIds = '' OR ts.TypeSiteId IS NOT NULL)
		GROUP BY YEAR(r.EventDate), MONTH(r.EventDate), r.TypeSiteId;
	
	-- Total LeagueCount & MatchCount
	SELECT COUNT(DISTINCT r.LeagueId) AS LeagueCount
		,	COUNT(DISTINCT r.MatchId) AS MatchCount
	FROM #tmpRobotTrading AS r WITH(NOLOCK)
		INNER JOIN @LeagueGroups AS lg ON r.LeagueGroupId = lg.LeagueGroupId
		INNER JOIN @Bettypes AS b ON r.BetType = b.BettypeId
		LEFT JOIN @TypeSites AS ts ON r.TypeSiteId = ts.TypeSiteId
	WHERE r.EventDate BETWEEN @FromDate AND @ToDate
		AND r.[Type] = @Model
		AND (@TypeSiteIds = '' OR ts.TypeSiteId IS NOT NULL);

	-- LeagueCount, MatchCount & BetCount by Month
	SELECT	CAST(YEAR(r.EventDate) AS VARCHAR) + '-' + CAST(MONTH(r.EventDate) AS VARCHAR) + '-01' AS RptMonth
		,	COUNT(DISTINCT r.LeagueId) AS LeagueCount
		,	STUFF((SELECT DISTINCT ',', CONVERT(VARCHAR(MAX), r2.LeagueId)
						FROM #tmpRobotTrading r2 WITH (NOLOCK)
							INNER JOIN @LeagueGroups AS lg ON r2.LeagueGroupId = lg.LeagueGroupId
							INNER JOIN @Bettypes AS b ON r2.BetType = b.BettypeId
							LEFT JOIN @TypeSites AS ts ON r2.TypeSiteId = ts.TypeSiteId
						WHERE r2.EventDate BETWEEN @FromDate AND @ToDate
							AND r2.[Type] = @Model
							AND (@TypeSiteIds = '' OR ts.TypeSiteId IS NOT NULL)
							AND (CAST(YEAR(r2.EventDate) AS VARCHAR) + '-' + CAST(MONTH(r2.EventDate) AS VARCHAR) + '-01') = (CAST(YEAR(r.EventDate) AS VARCHAR) + '-' + CAST(MONTH(r.EventDate) AS VARCHAR) + '-01')
						FOR XML PATH('')), 1, 1, '') AS LeagueIdList
		,	COUNT(DISTINCT r.MatchId) AS MatchCount
		,	SUM(r.BetCount) AS BetCount
	FROM #tmpRobotTrading AS r WITH(NOLOCK)
		INNER JOIN @LeagueGroups AS lg ON r.LeagueGroupId = lg.LeagueGroupId
		INNER JOIN @Bettypes AS b ON r.BetType = b.BettypeId
		LEFT JOIN @TypeSites AS ts ON r.TypeSiteId = ts.TypeSiteId
	WHERE r.EventDate BETWEEN @FromDate AND @ToDate
		AND r.[Type] = @Model
		AND (@TypeSiteIds = '' OR ts.TypeSiteId IS NOT NULL)
	GROUP BY CAST(YEAR(r.EventDate) AS VARCHAR) + '-' + CAST(MONTH(r.EventDate) AS VARCHAR) + '-01';

	-- Total
	SELECT	SUM(t.Stake_VR) AS Total_Stake_VR
		,	SUM(t.WinLoss_VR) AS Total_WinLoss_VR
		,	CASE WHEN ISNULL(SUM(t.WinLoss_VR), 0) <> 0 THEN SUM(t.WinLoss_VR)*100/SUM(t.Stake_VR) ELSE NULL END AS Total_Margin_VR

		,	SUM(ABS(t.Stake_AR - t.Stake_VR)) AS Total_Stake_VAR
		,	SUM(t.WinLoss_AR - t.WinLoss_VR) AS Total_Winloss_VAR
		,	CASE WHEN ISNULL(SUM(ABS(t.Stake_AR - t.Stake_VR)), 0) <> 0 THEN SUM(t.WinLoss_AR - t.WinLoss_VR)*100/SUM(ABS(t.Stake_AR - t.Stake_VR)) ELSE NULL END AS Total_Margin_VAR

		,	SUM(t.Stake_AR - (CASE WHEN r.RptMonth IS NULL THEN 0 ELSE r.Stake_AR END)) AS Total_Stake_AR
		,	SUM(t.WinLoss_AR + (CASE WHEN r.RptMonth IS NULL THEN 0 ELSE r.WinLoss_AR END)) AS Total_Winloss_AR
		,	CASE WHEN ISNULL(SUM(t.Stake_AR - (CASE WHEN r.RptMonth IS NULL THEN 0 ELSE r.Stake_AR END)), 0) <> 0 THEN SUM(t.WinLoss_AR + (CASE WHEN r.RptMonth IS NULL THEN 0 ELSE r.WinLoss_AR END))*100/SUM(t.Stake_AR - (CASE WHEN r.RptMonth IS NULL THEN 0 ELSE r.Stake_AR END)) ELSE NULL END AS Total_Margin_AR

		,	SUM(CASE WHEN r.RptMonth IS NULL THEN 0 ELSE r.Stake_AR END) AS Total_Stake_8RM
		,	SUM(CASE WHEN r.RptMonth IS NULL THEN 0 ELSE r.WinLoss_AR END) AS Total_Winloss_8RM
		,	CASE WHEN ISNULL(SUM(CASE WHEN r.RptMonth IS NULL THEN 0 ELSE r.Stake_AR END), 0) <> 0 THEN SUM(CASE WHEN r.RptMonth IS NULL THEN 0 ELSE r.WinLoss_AR END)*100/SUM(CASE WHEN r.RptMonth IS NULL THEN 0 ELSE r.Stake_AR END) ELSE NULL END AS Total_Margin_8RM

		,	SUM(t.Stake_AR) AS Total_Stake_AR8RM
		,	SUM(t.WinLoss_AR) AS Total_Winloss_AR8RM
		,	CASE WHEN ISNULL(SUM(t.Stake_AR), 0) <> 0 THEN SUM(t.WinLoss_AR)*100/SUM(t.Stake_AR) ELSE NULL END AS Total_Margin_AR8RM
	FROM #tmpTotalPerformance AS t WITH(NOLOCK)
		LEFT JOIN #tmp8RMPerformance AS r WITH(NOLOCK) ON t.RptMonth = r.RptMonth AND t.TypeSiteId = r.TypeSiteId;
		
	-- Detailed by Month
	SELECT	t.RptMonth
		,	t.BetCount
		,	t.MatchCount

		,	t.Stake_VR
		,	t.WinLoss_VR
		,	CASE WHEN ISNULL(t.WinLoss_VR, 0) <> 0 THEN t.WinLoss_VR*100/t.Stake_VR ELSE NULL END AS Margin_VR

		,	ABS(t.Stake_AR - t.Stake_VR) AS Stake_VAR
		,	(t.WinLoss_AR - t.WinLoss_VR) AS Winloss_VAR
		,	CASE WHEN ISNULL(ABS(t.Stake_AR - t.Stake_VR), 0) <> 0 THEN (t.WinLoss_AR - t.WinLoss_VR)*100/ABS(t.Stake_AR - t.Stake_VR) ELSE NULL END AS Margin_VAR

		,	(t.Stake_AR - (CASE WHEN r.RptMonth IS NULL THEN 0 ELSE r.Stake_AR END)) AS Stake_AR
		,	(t.WinLoss_AR + (CASE WHEN r.RptMonth IS NULL THEN 0 ELSE r.WinLoss_AR END)) AS Winloss_AR
		,	CASE WHEN ISNULL((t.Stake_AR - (CASE WHEN r.RptMonth IS NULL THEN 0 ELSE r.Stake_AR END)), 0) <> 0 THEN (t.WinLoss_AR + (CASE WHEN r.RptMonth IS NULL THEN 0 ELSE r.WinLoss_AR END))*100/(t.Stake_AR - (CASE WHEN r.RptMonth IS NULL THEN 0 ELSE r.Stake_AR END)) ELSE NULL END AS Margin_AR

		,	(CASE WHEN r.RptMonth IS NULL THEN 0 ELSE r.Stake_AR END) AS Stake_8RM
		,	(CASE WHEN r.RptMonth IS NULL THEN 0 ELSE r.WinLoss_AR END) AS Winloss_8RM
		,	CASE WHEN ISNULL((CASE WHEN r.RptMonth IS NULL THEN 0 ELSE r.Stake_AR END), 0) <> 0 THEN (CASE WHEN r.RptMonth IS NULL THEN 0 ELSE r.WinLoss_AR END)*100/(CASE WHEN r.RptMonth IS NULL THEN 0 ELSE r.Stake_AR END) ELSE NULL END AS Margin_8RM

		,	t.Stake_AR AS Stake_AR8RM
		,	t.WinLoss_AR AS Winloss_AR8RM
		,	CASE WHEN ISNULL(t.Stake_AR, 0) <> 0 THEN t.WinLoss_AR*100/t.Stake_AR ELSE NULL END AS Margin_AR8RM
		,	t.TypeSiteId
		,	fs.TypeSiteDesc
	FROM #tmpTotalPerformance AS t WITH(NOLOCK)
		LEFT JOIN #tmp8RMPerformance AS r WITH(NOLOCK) ON t.RptMonth = r.RptMonth AND t.TypeSiteId = r.TypeSiteId
		INNER JOIN @FilterSite AS fs ON t.TypeSiteId = fs.TypeSiteId
	WHERE t.BetCount IS NOT NULL;

	DROP TABLE #tmp8RMPerformance;
	DROP TABLE #tmpTotalPerformance;
END;

GO
/*<info serverAlias="DBTGRS-bodb_TGRS" executers="bodbTGRSNet" isFunction="0" isNested="0"></info>*/