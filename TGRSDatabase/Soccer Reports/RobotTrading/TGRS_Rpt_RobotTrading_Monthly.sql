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
	
	IF (DATEADD(MONTH, 2, @FromDate) >= @ToDate)
	BEGIN
		-- 8RM performance
		INSERT INTO #tmp8RMPerformance(RptMonth, BetCount, Stake_VR, WinLoss_VR, Stake_AR, WinLoss_AR, TypeSiteId)
		SELECT	CAST(MONTH(r.EventDate) AS VARCHAR) + '/01/' + CAST(YEAR(r.EventDate) AS VARCHAR) AS DATE
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
		FROM dbo.RobotTrading AS r WITH(NOLOCK)
			INNER JOIN @LeagueGroups AS lg ON r.LeagueGroupId = lg.LeagueGroupId
			INNER JOIN @Bettypes AS b ON r.BetType = b.BettypeId
			LEFT JOIN @TypeSites AS ts ON r.TypeSiteId = ts.TypeSiteId
		WHERE r.EventDate BETWEEN @FromDate AND @ToDate
			AND r.[Type] = @Model
			AND (@TypeSiteIds = '' OR ts.TypeSiteId IS NOT NULL)
		GROUP BY YEAR(r.EventDate), MONTH(r.EventDate), r.TypeSiteId;
	END
	ELSE
	BEGIN
		-- 8RM performance
		INSERT INTO #tmp8RMPerformance(RptMonth, BetCount, Stake_VR, WinLoss_VR, Stake_AR, WinLoss_AR, TypeSiteId)
		SELECT	@FirstMonthFromDate
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
		WHERE r.EventDate BETWEEN @FirstMonthFromDate AND @FirstMonthToDate
			AND r.Is8RM = 1
			AND r.[Type] = @Model
			AND (@TypeSiteIds = '' OR ts.TypeSiteId IS NOT NULL)
		GROUP BY r.TypeSiteId;

		INSERT INTO #tmp8RMPerformance(RptMonth, BetCount, Stake_VR, WinLoss_VR, Stake_AR, WinLoss_AR, TypeSiteId)
		SELECT	CAST(MONTH(r.EventDate) AS VARCHAR) + '/01/' + CAST(YEAR(r.EventDate) AS VARCHAR) AS DATE
			,	SUM(r.BetCount)
			,	SUM(r.Stake_VR)
			,	- SUM(r.WinLoss_VR - r.Comm_VR)
			,	SUM(r.Stake_AR)
			,	- SUM(r.WinLoss_AR - r.Comm_AR)
			,	r.TypeSiteId
		FROM dbo.RobotTrading_BetTypeMonthly AS r WITH(NOLOCK)
			INNER JOIN @LeagueGroups AS lg ON r.LeagueGroupId = lg.LeagueGroupId
			INNER JOIN @Bettypes AS b ON r.BetType = b.BettypeId
			LEFT JOIN @TypeSites AS ts ON r.TypeSiteId = ts.TypeSiteId
		WHERE r.EventDate BETWEEN @TheRestFromDate AND @TheRestToDate
			AND r.Is8RM = 1
			AND r.[Type] = @Model
			AND (@TypeSiteIds = '' OR ts.TypeSiteId IS NOT NULL)
		GROUP BY YEAR(r.EventDate), MONTH(r.EventDate), r.TypeSiteId;

		INSERT INTO #tmp8RMPerformance(RptMonth, BetCount, Stake_VR, WinLoss_VR, Stake_AR, WinLoss_AR, TypeSiteId)
		SELECT	@LastMonthFromDate
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
		WHERE r.EventDate BETWEEN @LastMonthFromDate AND @LastMonthToDate
			AND r.Is8RM = 1
			AND r.[Type] = @Model
			AND (@TypeSiteIds = '' OR ts.TypeSiteId IS NOT NULL)
		GROUP BY r.TypeSiteId;

		-- All others performance
		INSERT INTO #tmpTotalPerformance(RptMonth, BetCount, MatchCount, Stake_VR, WinLoss_VR, Stake_AR, WinLoss_AR, TypeSiteId)
		SELECT	@FirstMonthFromDate
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
		WHERE r.EventDate BETWEEN @FirstMonthFromDate AND @FirstMonthToDate
			AND r.[Type] = @Model
			AND (@TypeSiteIds = '' OR ts.TypeSiteId IS NOT NULL)
		GROUP BY r.TypeSiteId;

		INSERT INTO #tmpTotalPerformance(RptMonth, BetCount, MatchCount, Stake_VR, WinLoss_VR, Stake_AR, WinLoss_AR, TypeSiteId)
		SELECT	CAST(MONTH(r.EventDate) AS VARCHAR) + '/01/' + CAST(YEAR(r.EventDate) AS VARCHAR) AS DATE
			,	SUM(r.BetCount)
			,	SUM(mc.MatchCount)
			,	SUM(r.Stake_VR)
			,	SUM(r.WinLoss_VR - r.Comm_VR)
			,	SUM(r.Stake_AR)
			,	SUM(r.WinLoss_AR - r.Comm_AR)
			,	r.TypeSiteId
		FROM dbo.RobotTrading_BetTypeMonthly AS r WITH(NOLOCK)
			INNER JOIN @LeagueGroups AS lg ON r.LeagueGroupId = lg.LeagueGroupId
			INNER JOIN @Bettypes AS b ON r.BetType = b.BettypeId
			LEFT JOIN @TypeSites AS ts ON r.TypeSiteId = ts.TypeSiteId
			CROSS APPLY	(
				SELECT	[MatchCount]	= CASE	WHEN r.Is8RM = 1 THEN 0
											ELSE r.MatchCount
										END
				) AS mc
		WHERE r.EventDate BETWEEN @TheRestFromDate AND @TheRestToDate
			AND r.[Type] = @Model
			AND (@TypeSiteIds = '' OR ts.TypeSiteId IS NOT NULL)
		GROUP BY YEAR(r.EventDate), MONTH(r.EventDate), r.TypeSiteId;

		INSERT INTO #tmpTotalPerformance(RptMonth, BetCount, MatchCount, Stake_VR, WinLoss_VR, Stake_AR, WinLoss_AR, TypeSiteId)
		SELECT	@LastMonthFromDate
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
		WHERE r.EventDate BETWEEN @LastMonthFromDate AND @LastMonthToDate
			AND r.[Type] = @Model
			AND (@TypeSiteIds = '' OR ts.TypeSiteId IS NOT NULL)
		GROUP BY r.TypeSiteId;
	END;

	-- League & Match Count
	SELECT COUNT(DISTINCT r.LeagueId) AS LeagueCount
		,	COUNT(DISTINCT r.MatchId) AS MatchCount
	FROM dbo.RobotTrading AS r WITH(NOLOCK)
		INNER JOIN @LeagueGroups AS lg ON r.LeagueGroupId = lg.LeagueGroupId
		INNER JOIN @Bettypes AS b ON r.BetType = b.BettypeId
		LEFT JOIN @TypeSites AS ts ON r.TypeSiteId = ts.TypeSiteId
	WHERE r.EventDate BETWEEN @FromDate AND @ToDate
		AND r.[Type] = @Model
		AND (@TypeSiteIds = '' OR ts.TypeSiteId IS NOT NULL);

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
		
	-- Detailed by Bettype
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