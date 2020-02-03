ALTER PROCEDURE [dbo].[TGRS_Rpt_RobotTrading_Model]
		@FromDate			DATE
	,	@ToDate				DATE

AS    
/*  
	Created:	202001210@John.Ngo
	Task :		[TGR Soccer] RT3 Performance - Model Comparision Report [Redmine ID: 127208]
	DB:			DBTGRS.bodb_TGRS
	Original:  
  
	Revisions: 	
   		- 20200120@John.Ngo:	Created [Redmine ID: 127208]

	Param's Explanation:  	

	Exam:
*/  
 
BEGIN 
	SET NOCOUNT ON;

	IF	OBJECT_ID('tempdb..#tmp8RMPerformance') IS NOT NULL
	BEGIN
		DROP TABLE	#tmp8RMPerformance;
	END;

	CREATE TABLE	#tmp8RMPerformance (
			LeagueId			INT PRIMARY KEY CLUSTERED
		,	MatchCount			INT
		,   BetCount			INT
		,	Stake_VR			MONEY
		,	WinLoss_VR			MONEY
		,	Stake_AR			MONEY
		,	WinLoss_AR			MONEY
		,	[Type]				TINYINT
	);	

	IF	OBJECT_ID('tempdb..#tmpTotalPerformance') IS NOT NULL
	BEGIN
		DROP TABLE	#tmpTotalPerformance;
	END;

	CREATE TABLE	#tmpTotalPerformance (
			LeagueId			INT PRIMARY KEY CLUSTERED
		,	MatchCount			INT
		,   BetCount			INT
		,	Stake_VR			MONEY
		,	WinLoss_VR			MONEY
		,	Stake_AR			MONEY
		,	WinLoss_AR			MONEY
		,	[Type]				TINYINT
	);	
	
	-- RT3 No Trader Performance ('Italy Serie B' -- 30, 'ENGLISH LEAGUE ONE' -- 81, 'GERMANY 3RD LIGA' -- 4412, 'SCOTLAND PREMIERSHIP' -- 41565)
	DECLARE @NoTraderLeagues AS TABLE (LeagueId INT PRIMARY KEY CLUSTERED)
	BEGIN
		INSERT INTO @NoTraderLeagues(LeagueId)
		VALUES (30), (81), (4412), (41565), (4);
	END

	DECLARE @Bettypes AS TABLE (BettypeId SMALLINT PRIMARY KEY CLUSTERED);
	INSERT INTO @Bettypes(BettypeId)
	VALUES (1), (3), (7), (8);
	
	INSERT INTO #tmp8RMPerformance(LeagueId, MatchCount, BetCount, Stake_VR, WinLoss_VR, Stake_AR, WinLoss_AR, [Type])
	SELECT	r.LeagueId
		,	COUNT(DISTINCT r.MatchId)
		,	SUM(r.BetCount)
		,	SUM(r.Stake_VR)
		,	- SUM(r.WinLoss_VR - r.Comm_VR)
		,	SUM(r.Stake_AR)
		,	- SUM(r.WinLoss_AR - r.Comm_AR)
		,	r.[Type]
	FROM dbo.RobotTrading AS r WITH(NOLOCK)
		INNER JOIN @Bettypes AS b ON r.BetType = b.BettypeId
	WHERE r.EventDate BETWEEN @FromDate AND @ToDate
		AND r.Is8RM = 1
		AND r.[Type] IN (1,3)
	GROUP BY r.LeagueId, r.[Type];

	INSERT INTO #tmpTotalPerformance(LeagueId, MatchCount, BetCount, Stake_VR, WinLoss_VR, Stake_AR, WinLoss_AR, [Type])
	SELECT r.LeagueId
		,	COUNT(DISTINCT r.MatchId)
		,	SUM(r.BetCount)
		,	SUM(r.Stake_VR)
		,	SUM(r.WinLoss_VR - r.Comm_VR)
		,	SUM(r.Stake_AR)
		,	SUM(r.WinLoss_AR - r.Comm_AR)
		,	r.[Type]
	FROM dbo.RobotTrading AS r WITH(NOLOCK)
		INNER JOIN @Bettypes AS b ON r.BetType = b.BettypeId
	WHERE r.EventDate BETWEEN @FromDate AND @ToDate
		AND r.[Type] IN (1,3)
	GROUP BY r.LeagueId, r.[Type];

	-- League & Match Count
	SELECT COUNT(DISTINCT r.LeagueId) AS LeagueCount
		,	COUNT(DISTINCT r.MatchId) AS MatchCount
	FROM dbo.RobotTrading AS r WITH(NOLOCK)
		INNER JOIN @Bettypes AS b ON r.BetType = b.BettypeId
	WHERE r.EventDate BETWEEN @FromDate AND @ToDate
		AND r.[Type] IN (1,3);

	-- Total
	SELECT	SUM(t.Stake_VR) AS Total_Stake_VR
		,	SUM(t.WinLoss_VR) AS Total_WinLoss_VR
		,	CASE WHEN ISNULL(SUM(t.WinLoss_VR), 0) <> 0 THEN SUM(t.WinLoss_VR)*100/SUM(t.Stake_VR) ELSE NULL END AS Total_Margin_VR

		,	SUM(ABS(t.Stake_AR - t.Stake_VR)) AS Total_Stake_VAR
		,	SUM(t.WinLoss_AR - t.WinLoss_VR) AS Total_Winloss_VAR
		,	CASE WHEN ISNULL(SUM(ABS(t.Stake_AR - t.Stake_VR)), 0) <> 0 THEN SUM(t.WinLoss_AR - t.WinLoss_VR)*100/SUM(ABS(t.Stake_AR - t.Stake_VR)) ELSE NULL END AS Total_Margin_VAR

		,	SUM(t.Stake_AR - r.Stake_AR) AS Total_Stake_AR
		,	SUM(t.WinLoss_AR + r.WinLoss_AR) AS Total_Winloss_AR
		,	CASE WHEN ISNULL(SUM(t.Stake_AR - r.Stake_AR), 0) <> 0 THEN SUM(t.WinLoss_AR + r.WinLoss_AR)*100/SUM(t.Stake_AR - r.Stake_AR) ELSE NULL END AS Total_Margin_AR

		,	SUM(r.Stake_AR) AS Total_Stake_8RM
		,	SUM(r.WinLoss_AR) AS Total_Winloss_8RM
		,	CASE WHEN ISNULL(SUM(r.Stake_AR), 0) <> 0 THEN SUM(r.WinLoss_AR)*100/SUM(r.Stake_AR) ELSE NULL END AS Total_Margin_8RM

		,	SUM(t.Stake_AR) AS Total_Stake_AR8RM
		,	SUM(t.WinLoss_AR) AS Total_Winloss_AR8RM
		,	CASE WHEN ISNULL(SUM(t.Stake_AR), 0) <> 0 THEN SUM(t.WinLoss_AR)*100/SUM(t.Stake_AR) ELSE NULL END AS Total_Margin_AR8RM
	FROM #tmpTotalPerformance AS t WITH(NOLOCK)
		INNER JOIN #tmp8RMPerformance AS r WITH(NOLOCK) ON t.LeagueId = r.LeagueId AND t.[Type] = r.[Type];

	-- Detailed

	SELECT	'RT3 wTP' AS Model
		,	SUM(t.MatchCount) AS MatchCount
		,	SUM(t.BetCount) AS BetCount

		,	SUM(t.Stake_VR) AS Stake_VR
		,	SUM(t.WinLoss_VR) AS WinLoss_VR
		,	CASE WHEN ISNULL(SUM(t.WinLoss_VR), 0) <> 0 THEN SUM(t.WinLoss_VR)*100/SUM(t.Stake_VR) ELSE NULL END AS Margin_VR

		,	ABS(SUM(t.Stake_AR - t.Stake_VR)) AS Stake_VAR
		,	SUM(t.WinLoss_AR - t.WinLoss_VR) AS Winloss_VAR
		,	CASE WHEN ISNULL(ABS(SUM(t.Stake_AR - t.Stake_VR)), 0) <> 0 THEN SUM(t.WinLoss_AR - t.WinLoss_VR)*100/ABS(SUM(t.Stake_AR - t.Stake_VR)) ELSE NULL END AS Margin_VAR

		,	SUM(t.Stake_AR - r.Stake_AR) AS Stake_AR
		,	SUM(t.WinLoss_AR + r.WinLoss_AR) AS Winloss_AR
		,	CASE WHEN ISNULL((SUM(t.Stake_AR - r.Stake_AR)), 0) <> 0 THEN SUM(t.WinLoss_AR + r.WinLoss_AR)*100/SUM(t.Stake_AR - r.Stake_AR) ELSE NULL END AS Margin_AR

		,	SUM(r.Stake_AR) AS Stake_8RM
		,	SUM(r.WinLoss_AR) AS Winloss_8RM
		,	CASE WHEN ISNULL(SUM(r.Stake_AR), 0) <> 0 THEN SUM(r.WinLoss_AR)*100/SUM(r.Stake_AR) ELSE NULL END AS Margin_8RM

		,	SUM(t.Stake_AR) AS Stake_AR8RM
		,	SUM(t.WinLoss_AR) AS Winloss_AR8RM
		,	CASE WHEN ISNULL(SUM(t.Stake_AR), 0) <> 0 THEN SUM(t.WinLoss_AR)*100/SUM(t.Stake_AR) ELSE NULL END AS Margin_AR8RM
	FROM #tmpTotalPerformance AS t WITH(NOLOCK)
		INNER JOIN #tmp8RMPerformance AS r WITH(NOLOCK) ON t.LeagueId = r.LeagueId AND t.[Type] = r.[Type]
		LEFT JOIN @NoTraderLeagues AS ntl ON r.LeagueId = ntl.LeagueId
	WHERE ntl.LeagueId IS NULL 
		AND r.[Type] = 1
	UNION ALL
	SELECT	'RT3 NoTP' AS Model
		,	SUM(t.MatchCount) AS MatchCount
		,	SUM(t.BetCount) AS BetCount

		,	SUM(t.Stake_VR) AS Stake_VR
		,	SUM(t.WinLoss_VR) AS WinLoss_VR
		,	CASE WHEN ISNULL(SUM(t.WinLoss_VR), 0) <> 0 THEN SUM(t.WinLoss_VR)*100/SUM(t.Stake_VR) ELSE NULL END AS Margin_VR

		,	ABS(SUM(t.Stake_AR - t.Stake_VR)) AS Stake_VAR
		,	SUM(t.WinLoss_AR - t.WinLoss_VR) AS Winloss_VAR
		,	CASE WHEN ISNULL(ABS(SUM(t.Stake_AR - t.Stake_VR)), 0) <> 0 THEN SUM(t.WinLoss_AR - t.WinLoss_VR)*100/ABS(SUM(t.Stake_AR - t.Stake_VR)) ELSE NULL END AS Margin_VAR

		,	SUM(t.Stake_AR - r.Stake_AR) AS Stake_AR
		,	SUM(t.WinLoss_AR + r.WinLoss_AR) AS Winloss_AR
		,	CASE WHEN ISNULL((SUM(t.Stake_AR - r.Stake_AR)), 0) <> 0 THEN SUM(t.WinLoss_AR + r.WinLoss_AR)*100/SUM(t.Stake_AR - r.Stake_AR) ELSE NULL END AS Margin_AR

		,	SUM(r.Stake_AR) AS Stake_8RM
		,	SUM(r.WinLoss_AR) AS Winloss_8RM
		,	CASE WHEN ISNULL(SUM(r.Stake_AR), 0) <> 0 THEN SUM(r.WinLoss_AR)*100/SUM(r.Stake_AR) ELSE NULL END AS Margin_8RM

		,	SUM(t.Stake_AR) AS Stake_AR8RM
		,	SUM(t.WinLoss_AR) AS Winloss_AR8RM
		,	CASE WHEN ISNULL(SUM(t.Stake_AR), 0) <> 0 THEN SUM(t.WinLoss_AR)*100/SUM(t.Stake_AR) ELSE NULL END AS Margin_AR8RM
	FROM #tmpTotalPerformance AS t WITH(NOLOCK)
		INNER JOIN #tmp8RMPerformance AS r WITH(NOLOCK) ON t.LeagueId = r.LeagueId AND t.[Type] = r.[Type]
		INNER JOIN @NoTraderLeagues AS ntl ON r.LeagueId = ntl.LeagueId
	WHERE r.[Type] = 1
	UNION ALL
	SELECT	'TA' AS Model
		,	SUM(t.MatchCount) AS MatchCount
		,	SUM(t.BetCount) AS BetCount

		,	SUM(t.Stake_VR) AS Stake_VR
		,	SUM(t.WinLoss_VR) AS WinLoss_VR
		,	CASE WHEN ISNULL(SUM(t.WinLoss_VR), 0) <> 0 THEN SUM(t.WinLoss_VR)*100/SUM(t.Stake_VR) ELSE NULL END AS Margin_VR

		,	ABS(SUM(t.Stake_AR - t.Stake_VR)) AS Stake_VAR
		,	SUM(t.WinLoss_AR - t.WinLoss_VR) AS Winloss_VAR
		,	CASE WHEN ISNULL(ABS(SUM(t.Stake_AR - t.Stake_VR)), 0) <> 0 THEN SUM(t.WinLoss_AR - t.WinLoss_VR)*100/ABS(SUM(t.Stake_AR - t.Stake_VR)) ELSE NULL END AS Margin_VAR

		,	SUM(t.Stake_AR - r.Stake_AR) AS Stake_AR
		,	SUM(t.WinLoss_AR + r.WinLoss_AR) AS Winloss_AR
		,	CASE WHEN ISNULL((SUM(t.Stake_AR - r.Stake_AR)), 0) <> 0 THEN SUM(t.WinLoss_AR + r.WinLoss_AR)*100/SUM(t.Stake_AR - r.Stake_AR) ELSE NULL END AS Margin_AR

		,	SUM(r.Stake_AR) AS Stake_8RM
		,	SUM(r.WinLoss_AR) AS Winloss_8RM
		,	CASE WHEN ISNULL(SUM(r.Stake_AR), 0) <> 0 THEN SUM(r.WinLoss_AR)*100/SUM(r.Stake_AR) ELSE NULL END AS Margin_8RM

		,	SUM(t.Stake_AR) AS Stake_AR8RM
		,	SUM(t.WinLoss_AR) AS Winloss_AR8RM
		,	CASE WHEN ISNULL(SUM(t.Stake_AR), 0) <> 0 THEN SUM(t.WinLoss_AR)*100/SUM(t.Stake_AR) ELSE NULL END AS Margin_AR8RM
	FROM #tmpTotalPerformance AS t WITH(NOLOCK)
		INNER JOIN #tmp8RMPerformance AS r WITH(NOLOCK) ON t.LeagueId = r.LeagueId AND t.[Type] = r.[Type]
	WHERE r.[Type] = 3;

	DROP TABLE #tmp8RMPerformance;
	DROP TABLE #tmpTotalPerformance;
END;

GO
/*<info serverAlias="DBTGRS-bodb_TGRS" executers="bodbTGRSNet" isFunction="0" isNested="0"></info>*/