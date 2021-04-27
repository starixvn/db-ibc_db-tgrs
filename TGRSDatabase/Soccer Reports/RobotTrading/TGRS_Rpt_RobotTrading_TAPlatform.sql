ALTER PROCEDURE [dbo].[TGRS_Rpt_RobotTrading_TAPlatform]
		@FromDate			DATE
	,	@ToDate				DATE
	,	@LeagueIds			VARCHAR(MAX) =  ''	
AS
/*
	Created:	20210420@Adam.Tran
	Task:		Automation Trading - Report Spread 8% Live Performance
	DB:			DBTGRS.bodb_TGRS
	Original:
	
	Revisions:
		- 20210420@Adam.Tran: Created [Redmine ID: 152889]
		
	Param's Explanation:
		- @IsLess8
		- @IsLastWeek
		- @IsMonitoringLeague
		
	Exam: EXECUTE dbo.TGRS_Rpt_RobotTrading_TAPlatform @FromDate = '20210320', @ToDate = '20210420' 
*/

BEGIN
	SET NOCOUNT ON;
	
	IF	OBJECT_ID('tempdb..#tmpRobotTrading') IS NOT NULL
	BEGIN
		DROP TABLE	#tmpRobotTrading;
	END;
	
	CREATE TABLE	#tmpRobotTrading (		
			MatchId				INT
		,	LeagueId			INT
		,	LeagueName			NVARCHAR(500)
		,	LeagueGroupId		SMALLINT
		,	GroupName			VARCHAR(20)
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
	);	
	
	CREATE CLUSTERED INDEX	#CIX_tmpRobotTrading_EventDate ON #tmpRobotTrading (
			EventDate			ASC
	);
	
	CREATE NONCLUSTERED INDEX	#IX_tmpRobotTradingIdx ON #tmpRobotTrading (
			LeagueId			ASC
		,	MatchId				ASC
		,	BetType				ASC
	);	
	
	IF	OBJECT_ID('tempdb..#tmpTotalPerformance') IS NOT NULL
	BEGIN
		DROP TABLE	#tmpTotalPerformance;
	END;
	
	CREATE TABLE	#tmpTotalPerformance (
			LeagueGroupId		SMALLINT
		,	GroupName			VARCHAR(20)
		,	LeagueId			INT
		,	LeagueName			NVARCHAR(500)
		,	EventDate			DATE
		,	BetType				SMALLINT
		,   BetCount			INT
		,   MatchCount			INT
		,	Stake_VR			MONEY
		,	WinLoss_VR			MONEY
		,	Stake_AR			MONEY
		,	WinLoss_AR			MONEY		
		,	PRIMARY KEY CLUSTERED (
				LeagueGroupId	ASC
			,	LeagueId		ASC
			,	BetType			ASC
			,	EventDate		ASC
		)
	);
	
	DECLARE @Leagues AS TABLE (LeagueId INT PRIMARY KEY CLUSTERED)
	IF @LeagueIds <> ''
	BEGIN
		INSERT INTO @Leagues(LeagueId)
		SELECT val
		FROM dbo.strSplit_Key(@LeagueIds,',');
	END;

	DECLARE @Bettypes AS TABLE (BettypeId SMALLINT PRIMARY KEY CLUSTERED);
		INSERT INTO @Bettypes(BettypeId)
		VALUES (1), (3), (7), (8);

	INSERT INTO #tmpRobotTrading(MatchId, LeagueId, LeagueName, LeagueGroupId, GroupName, EventDate, BetType, Is8RM, BetCount, Stake_VR, WinLoss_VR, Comm_VR, Stake_AR, WinLoss_AR, Comm_AR)
	SELECT	r.MatchId		
		,	r.LeagueId
		,	lg.LeagueName
		,	r.LeagueGroupId
		,	lg.[Group]
		,	r.EventDate
		,	r.BetType
		,	r.Is8RM
		,	r.BetCount
		,	r.Stake_VR
		,	r.WinLoss_VR
		,	r.Comm_VR
		,	r.Stake_AR
		,	r.WinLoss_AR
		,	r.Comm_AR
	FROM dbo.RobotTrading AS r WITH(NOLOCK)
		INNER JOIN @Leagues AS l ON r.LeagueId = l.LeagueId	
		INNER JOIN bodb02.dbo.league AS lg ON r.LeagueId = lg.LeagueId
	WHERE r.EventDate BETWEEN @FromDate AND @ToDate;
	
	INSERT INTO #tmpTotalPerformance(LeagueGroupId, GroupName, LeagueId, LeagueName, EventDate, BetType, BetCount, MatchCount, Stake_VR, WinLoss_VR, Stake_AR, WinLoss_AR)
	SELECT	r.LeagueGroupId
		,	r.GroupName
		,	r.LeagueId
		,	r.LeagueName
		,	r.EventDate
		,	r.BetType
		,	ISNULL(SUM(r.BetCount), 0) AS BetCount
		,	COUNT(DISTINCT r.MatchId)
		,	SUM(r.Stake_VR)
		,	SUM(r.WinLoss_VR - r.Comm_VR)
		,	SUM(r.Stake_AR)
		,	SUM(r.WinLoss_AR - r.Comm_AR)		
	FROM #tmpRobotTrading AS r WITH(NOLOCK)
	GROUP BY r.LeagueGroupId, r.GroupName, r.LeagueId, r.LeagueName, r.EventDate, r.BetType;
		
	SELECT 	t.LeagueId
		,	t.LeagueName
		,	t.EventDate
		,	t.LeagueGroupId	
		,	t.GroupName
		,	t.BetType
		,	t.MatchCount
		,	t.BetCount
		
		,	ABS(t.Stake_AR - t.Stake_VR) AS Stake_VAR
		,	(t.WinLoss_AR - t.WinLoss_VR) AS Winloss_VAR
		,	CASE WHEN ISNULL(ABS(t.Stake_AR - t.Stake_VR), 0) <> 0 THEN (t.WinLoss_AR - t.WinLoss_VR)*100/ABS(t.Stake_AR - t.Stake_VR) ELSE NULL END AS Margin_VAR
		
		,	t.Stake_VR
		,	t.WinLoss_VR
		,	CASE WHEN ISNULL(t.WinLoss_VR, 0) <> 0 THEN t.WinLoss_VR*100/t.Stake_VR ELSE NULL END AS Margin_VR
		
		,	t.Stake_AR AS Stake_AR8RM
		,	t.WinLoss_AR AS Winloss_AR8RM
		,	CASE WHEN ISNULL(t.Stake_AR, 0) <> 0 THEN t.WinLoss_AR*100/t.Stake_AR ELSE NULL END AS Margin_AR8RM		
	FROM #tmpTotalPerformance AS t WITH(NOLOCK)		
	WHERE t.BetCount IS NOT NULL
	ORDER BY t.LeagueGroupId ASC, t.LeagueId ASC;
	
	DROP TABLE #tmpRobotTrading;
	DROP TABLE #tmpTotalPerformance;
END;

GO
/*<info serverAlias="DBTGRS-bodb_TGRS" executers="bodbTGRSNet" isFunction="0" isNested="0"></info>*/