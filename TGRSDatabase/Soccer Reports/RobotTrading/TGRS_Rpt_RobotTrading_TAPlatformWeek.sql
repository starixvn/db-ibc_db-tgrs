ALTER PROCEDURE [dbo].[TGRS_Rpt_RobotTrading_TAPlatformWeek]
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
		
	Exam: EXECUTE dbo.TGRS_Rpt_RobotTrading_TAPlatformWeek @FromDate = '20210320', @ToDate = '20210420' 
*/

BEGIN
	SET NOCOUNT ON;
	
	DECLARE @StartDate DATE = @FromDate
	,	@EndDate   DATE = CASE WHEN (DATENAME(DW, @FromDate) = 'Sunday') THEN @FromDate ELSE DATEADD(DAY, (DATEDIFF(DAY, 6, @FromDate) / 7) * 7 + 7, 6) END
	,	@WeekDays  VARCHAR(100);
	
	IF	OBJECT_ID('tempdb..#tmpRobotTrading') IS NOT NULL
	BEGIN
		DROP TABLE	#tmpRobotTrading;
	END;
	
	CREATE TABLE	#tmpRobotTrading (		
			MatchId				INT
		,	LeagueId			INT		
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
		EventDate	ASC
	);
	
	CREATE NONCLUSTERED INDEX	#IX_tmpRobotTradingIdx ON #tmpRobotTrading (			
		LeagueId	ASC				
	);	
	
	IF	OBJECT_ID('tempdb..#tmpTotalPerformance') IS NOT NULL
	BEGIN
		DROP TABLE	#tmpTotalPerformance;
	END;
	
	CREATE TABLE	#tmpTotalPerformance (		
			LeagueId			INT		
		,	EventDate			DATE
		,	BetType				SMALLINT
		,   BetCount			INT
		,   MatchCount			INT
		,	Stake_VR			MONEY
		,	WinLoss_VR			MONEY
		,	Stake_AR			MONEY
		,	WinLoss_AR			MONEY		
		,	PRIMARY KEY CLUSTERED (			
				LeagueId		ASC
			,	BetType			ASC
			,	EventDate		ASC
		)
	);
	
	IF	OBJECT_ID('tempdb..#tmpTotalLMB') IS NOT NULL
	BEGIN
		DROP TABLE	#tmpTotalLMB;
	END;

	CREATE TABLE	#tmpTotalLMB (
			WeekDays			VARCHAR(2)
		,	StartDate			DATE 
		,	EndDate				DATE
		,   LeagueCount			INT
		,	LeagueIdList		VARCHAR(100)
		,   MatchCount			INT
		,   BetCount			INT
		,	PRIMARY KEY CLUSTERED (
				WeekDays		ASC
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
		
	-- Start Cal Week
	DECLARE	@Date TABLE (ID INT IDENTITY(1,1), StartDate DATE ,EndDate DATE, WeekDays VARCHAR(2));

	WHILE (@EndDate < @ToDate)
	BEGIN	
		INSERT @Date(StartDate, EndDate) VALUES(@StartDate, @EndDate);

		UPDATE @Date 
			SET	WeekDays = CAST((SELECT MAX(ID) FROM @Date) AS VARCHAR(2)) 
		WHERE ID = (SELECT MAX(ID) FROM @Date);

		SELECT @StartDate = DATEADD(DAY, 1, @EndDate);
		SELECT @EndDate = CASE WHEN (DATENAME(DW, @StartDate) = 'Sunday') THEN @StartDate ELSE DATEADD(DAY, (DATEDIFF(DAY, 6, @StartDate) / 7) * 7 + 7, 6) END;
	END;

	INSERT @Date(StartDate, EndDate) VALUES(@StartDate, @ToDate);

	UPDATE @Date 
		SET	WeekDays = CAST((SELECT MAX(ID) FROM @Date) AS VARCHAR(2)) 
	WHERE ID = (SELECT MAX(ID) FROM @Date);

	INSERT INTO #tmpRobotTrading(MatchId, LeagueId, EventDate, BetType, Is8RM, BetCount, Stake_VR, WinLoss_VR, Comm_VR, Stake_AR, WinLoss_AR, Comm_AR)
	SELECT	r.MatchId		
		,	r.LeagueId
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
		INNER JOIN @Bettypes AS b ON r.BetType = b.BettypeId
	WHERE r.EventDate BETWEEN @FromDate AND @ToDate AND r.Type = 3;
	
	select * FROM @Date;
	
	WHILE	EXISTS (SELECT TOP(1) 1	FROM @Date)
		BEGIN
			SELECT	TOP(1)
					@WeekDays = d.WeekDays
				,	@StartDate = d.StartDate
				,	@EndDate = d.EndDate
			FROM	@Date AS d
			ORDER BY WeekDays DESC;
						
			INSERT INTO #tmpTotalLMB(WeekDays, StartDate, EndDate, LeagueCount, LeagueIdList, MatchCount, BetCount)
			SELECT	@WeekDays
				,	@StartDate
				,	@EndDate
				,	COUNT(DISTINCT r.LeagueId) AS LeagueCount
				,	STUFF((SELECT DISTINCT ',', CONVERT(VARCHAR(MAX), r2.LeagueId)
						FROM #tmpRobotTrading r2 WITH (NOLOCK)
						WHERE r2.EventDate BETWEEN @StartDate AND @EndDate
						FOR XML PATH('')), 1, 1, '') AS LeagueIdList
				,	COUNT(DISTINCT r.MatchId) AS MatchCount
				,	ISNULL(SUM(r.BetCount), 0) AS BetCount
			FROM #tmpRobotTrading AS r WITH(NOLOCK)
			WHERE r.EventDate BETWEEN @StartDate AND @EndDate;
			
			DELETE	d
			FROM	@Date AS d
			WHERE	d.WeekDays = @WeekDays;
		END;
	
	INSERT INTO #tmpTotalPerformance(LeagueId, EventDate, BetType, BetCount, MatchCount, Stake_VR, WinLoss_VR, Stake_AR, WinLoss_AR)
	SELECT 	r.LeagueId
		,	r.EventDate
		,	r.BetType
		,	ISNULL(SUM(r.BetCount), 0) AS BetCount
		,	COUNT(DISTINCT r.MatchId)
		,	SUM(r.Stake_VR)
		,	SUM(r.WinLoss_VR - r.Comm_VR)
		,	SUM(r.Stake_AR)
		,	SUM(r.WinLoss_AR - r.Comm_AR)
	FROM #tmpRobotTrading AS r WITH(NOLOCK)
	GROUP BY r.LeagueId, r.EventDate, r.BetType;
		
	-- LeagueCount, MatchCount & BetCount by Week
	SELECT	tm.WeekDays
		,	tm.StartDate
		,	tm.EndDate
		,	tm.LeagueCount
		,	tm.LeagueIdList
		,	tm.MatchCount
		,	tm.BetCount
	FROM #tmpTotalLMB AS tm WITH(NOLOCK) WHERE tm.LeagueCount > 0;
	
	-- Detailed
	SELECT 	t.LeagueId
		,	l.LeagueName
		,	t.EventDate
		,	l.LeagueGroupID as LeagueGroupId
		,	l.[Group] AS GroupName
		,	t.BetType
		,	t.MatchCount
		,	t.BetCount
		
		,	ABS(t.Stake_AR - t.Stake_VR) AS Stake_VAR
		,	(t.WinLoss_AR - t.WinLoss_VR) AS WinLoss_VAR
		,	CASE WHEN ISNULL(ABS(t.Stake_AR - t.Stake_VR), 0) <> 0 THEN (t.WinLoss_AR - t.WinLoss_VR)*100/ABS(t.Stake_AR - t.Stake_VR) ELSE NULL END AS Margin_VAR
		
		,	t.Stake_VR
		,	t.WinLoss_VR
		,	CASE WHEN ISNULL(t.WinLoss_VR, 0) <> 0 THEN t.WinLoss_VR*100/t.Stake_VR ELSE NULL END AS Margin_VR
		
		,	t.Stake_AR AS Stake_AR8RM
		,	t.WinLoss_AR AS WinLoss_AR8RM
		,	CASE WHEN ISNULL(t.Stake_AR, 0) <> 0 THEN t.WinLoss_AR*100/t.Stake_AR ELSE NULL END AS Margin_AR8RM		
	FROM #tmpTotalPerformance AS t WITH(NOLOCK)	
		INNER JOIN bodb02.dbo.league AS l ON l.LeagueId = t.LeagueId
	WHERE t.BetCount IS NOT NULL
	ORDER BY l.LeagueGroupID ASC, t.LeagueId ASC;
	
	DROP TABLE #tmpRobotTrading;
	DROP TABLE #tmpTotalPerformance;
	DROP TABLE #tmpTotalLMB;
END;

GO
/*<info serverAlias="DBTGRS-bodb_TGRS" executers="bodbTGRSNet" isFunction="0" isNested="0"></info>*/