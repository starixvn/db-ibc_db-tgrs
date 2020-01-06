ALTER PROCEDURE [dbo].[TGRS_Rpt_RobotTrading_BetType]
	@FromDate			DATE,
	@ToDate				DATE,
	@LeagueGroupIds		VARCHAR(2000) =  '1'
AS    
/*  
	Created:	20191227@Long.Luu
	Task :		Robot Trading - Bettype
	DB:			DBTGRS.bodb_TGRS
	Original:  
  
	Revisions: 	
   		- 20191227@Long.Luu:	Created [Redmine ID: 123714]

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
			BetType				SMALLINT PRIMARY KEY
		,   BetCount			INT
		,	Stake_VR			MONEY
		,	WinLoss_VR			MONEY
		,	Stake_AR			MONEY
		,	WinLoss_AR			MONEY
	);	

	IF	OBJECT_ID('tempdb..#tmpTotalPerformance') IS NOT NULL
	BEGIN
		DROP TABLE	#tmpTotalPerformance;
	END;

	CREATE TABLE	#tmpTotalPerformance (
			BetType				SMALLINT PRIMARY KEY
		,   BetCount			INT
		,	Stake_VR			MONEY
		,	WinLoss_VR			MONEY
		,	Stake_AR			MONEY
		,	WinLoss_AR			MONEY
	);	

	DECLARE @LeagueGroups AS TABLE (LeagueGroupId SMALLINT)
	IF @LeagueGroupIds <> ''
		INSERT INTO @LeagueGroups(LeagueGroupId)
		SELECT val 
		FROM dbo.strSplit_Key(@LeagueGroupIds,',');
	ELSE 
		INSERT INTO @LeagueGroups
		VALUES(1);

	INSERT INTO #tmp8RMPerformance(BetType, BetCount, Stake_VR, WinLoss_VR, Stake_AR, WinLoss_AR)
	SELECT	r.BetType
		,	SUM(r.BetCount)
		,	SUM(r.Stake_VR)
		,	- SUM(r.WinLoss_VR - r.Comm_VR)
		,	SUM(r.Stake_AR)
		,	- SUM(r.WinLoss_AR - r.Comm_AR)
	FROM dbo.RobotTrading AS r WITH(NOLOCK)
		INNER JOIN @LeagueGroups AS lg ON r.LeagueGroupId = lg.LeagueGroupId
	WHERE r.EventDate BETWEEN @FromDate AND @ToDate
		AND r.Is8RM = 1
	GROUP BY r.BetType;

	INSERT INTO #tmpTotalPerformance(BetType, BetCount, Stake_VR, WinLoss_VR, Stake_AR, WinLoss_AR)
	SELECT r.BetType
		,	SUM(r.BetCount)
		,	SUM(r.Stake_VR)
		,	SUM(r.WinLoss_VR - r.Comm_VR)
		,	SUM(r.Stake_AR)
		,	SUM(r.WinLoss_AR - r.Comm_AR)
	FROM dbo.RobotTrading AS r WITH(NOLOCK)
		INNER JOIN @LeagueGroups AS lg ON r.LeagueGroupId = lg.LeagueGroupId
	WHERE r.EventDate BETWEEN @FromDate AND @ToDate
	GROUP BY r.BetType;

	-- League & Match Count
	SELECT COUNT(DISTINCT r.LeagueId) AS LeagueCount
		,	COUNT(DISTINCT r.MatchId) AS MatchCount
	FROM dbo.RobotTrading AS r WITH(NOLOCK)
		INNER JOIN @LeagueGroups AS lg ON r.LeagueGroupId = lg.LeagueGroupId
	WHERE r.EventDate BETWEEN @FromDate AND @ToDate;

	-- Total
	SELECT	SUM(t.Stake_VR) AS Total_Stake_VR
		,	SUM(t.WinLoss_VR) AS Total_WinLoss_VR
		,	CASE WHEN ISNULL(SUM(t.WinLoss_VR), 0) <> 0 THEN SUM(t.WinLoss_VR)*100/SUM(t.Stake_VR) ELSE NULL END AS Total_Margin_VR

		,	SUM(ABS(t.Stake_AR - t.Stake_VR)) AS Total_Stake_VAR
		,	ABS(SUM(t.WinLoss_AR - t.WinLoss_VR)) AS Total_Winloss_VAR
		,	CASE WHEN ISNULL(SUM(ABS(t.Stake_AR - t.Stake_VR)), 0) <> 0 THEN ABS(SUM(t.WinLoss_AR - t.WinLoss_VR))*100/SUM(ABS(t.Stake_AR - t.Stake_VR)) ELSE NULL END AS Total_Margin_VAR

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
		INNER JOIN #tmp8RMPerformance AS r WITH(NOLOCK) ON t.BetType = r.BetType;

	-- Detailed by Bettype
	SELECT	t.BetType
		,	t.BetCount

		,	t.Stake_VR
		,	t.WinLoss_VR
		,	CASE WHEN ISNULL(t.WinLoss_VR, 0) <> 0 THEN t.WinLoss_VR*100/t.Stake_VR ELSE NULL END AS Margin_VR

		,	ABS(t.Stake_AR - t.Stake_VR) AS Stake_VAR
		,	ABS(t.WinLoss_AR - t.WinLoss_VR) AS Winloss_VAR
		,	CASE WHEN ISNULL(ABS(t.Stake_AR - t.Stake_VR), 0) <> 0 THEN ABS(t.WinLoss_AR - t.WinLoss_VR)*100/ABS(t.Stake_AR - t.Stake_VR) ELSE NULL END AS Margin_VAR

		,	(t.Stake_AR - r.Stake_AR) AS Stake_AR
		,	(t.WinLoss_AR + r.WinLoss_AR) AS Winloss_AR
		,	CASE WHEN ISNULL((t.Stake_AR - r.Stake_AR), 0) <> 0 THEN (t.WinLoss_AR + r.WinLoss_AR)*100/(t.Stake_AR - r.Stake_AR) ELSE NULL END AS Margin_AR

		,	r.Stake_AR AS Stake_8RM
		,	r.WinLoss_AR AS Winloss_8RM
		,	CASE WHEN ISNULL(r.Stake_AR, 0) <> 0 THEN r.WinLoss_AR*100/r.Stake_AR ELSE NULL END AS Margin_8RM

		,	t.Stake_AR AS Stake_AR8RM
		,	t.WinLoss_AR AS Winloss_AR8RM
		,	CASE WHEN ISNULL(t.Stake_AR, 0) <> 0 THEN t.WinLoss_AR*100/t.Stake_AR ELSE NULL END AS Margin_AR8RM
	FROM #tmpTotalPerformance AS t WITH(NOLOCK)
		INNER JOIN #tmp8RMPerformance AS r WITH(NOLOCK) ON t.BetType = r.BetType;

	DROP TABLE #tmp8RMPerformance;
	DROP TABLE #tmpTotalPerformance;
END;

GO
/*<info serverAlias="DBTGRS-bodb_TGRS" executers="bodbTGRSNet" isFunction="0" isNested="0"></info>*/