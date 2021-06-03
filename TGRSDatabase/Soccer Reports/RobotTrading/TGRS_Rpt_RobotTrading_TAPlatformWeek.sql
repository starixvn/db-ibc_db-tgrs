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
		
	Exam: EXECUTE dbo.TGRS_Rpt_RobotTrading_TAPlatformWeek @FromDate = '20210320', @ToDate = '20210420', @LeagueIds='3,4,5,8,19'
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
		,	HomeId				INT
		,	AwayId				INT
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
			EventDate			DATE
		,	BetType				SMALLINT
		,   BetCount			INT
		,	Stake_VR			MONEY
		,	WinLoss_VR			MONEY
		,	Stake_AR			MONEY
		,	WinLoss_AR			MONEY		
		,	PRIMARY KEY CLUSTERED (			
				BetType			ASC
			,	EventDate		ASC
		)
	);
	
	IF	OBJECT_ID('tempdb..#tmpLM') IS NOT NULL
	BEGIN
		DROP TABLE	#tmpLM;
	END;

	CREATE TABLE	#tmpLM (
			StartDate			DATE 
		,	EndDate				DATE	
		,	LeagueId			INT
		,	MatchId				INT		
		,	HomeId				INT
		,	AwayId				INT
		,	PRIMARY KEY CLUSTERED (
				LeagueId		ASC		
			,	MatchId			ASC				
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
		,	LeagueIdList		VARCHAR(MAX)
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
	DECLARE	@Date TABLE (ID INT IDENTITY(1,1), StartDate DATE ,EndDate DATE, WeekDays VARCHAR(100));
	
	WHILE (@EndDate < @ToDate)
	BEGIN	
		INSERT @Date(StartDate, EndDate) VALUES(@StartDate, @EndDate);

		UPDATE @Date 
			SET	WeekDays = CAST((SELECT MAX(ID) FROM @Date) AS VARCHAR(100)) 
		WHERE ID = (SELECT MAX(ID) FROM @Date);

		SELECT @StartDate = DATEADD(DAY, 1, @EndDate);
		SELECT @EndDate = CASE WHEN (DATENAME(DW, @StartDate) = 'Sunday') THEN @StartDate ELSE DATEADD(DAY, (DATEDIFF(DAY, 6, @StartDate) / 7) * 7 + 7, 6) END;
	END;

	INSERT @Date(StartDate, EndDate) VALUES(@StartDate, @ToDate);

	UPDATE @Date 
		SET	WeekDays = CAST((SELECT MAX(ID) FROM @Date) AS VARCHAR(100)) 
	WHERE ID = (SELECT MAX(ID) FROM @Date);


	INSERT INTO #tmpRobotTrading(MatchId, LeagueId, HomeId, AwayId, EventDate, BetType, Is8RM, BetCount, Stake_VR, WinLoss_VR, Comm_VR, Stake_AR, WinLoss_AR, Comm_AR)
	SELECT	r.MatchId		
		,	r.LeagueId
		,	r.HomeId
		,	r.AwayId
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
	
	WHILE	EXISTS (SELECT TOP(1) 1	FROM @Date)
		BEGIN
			SELECT	TOP(1)
					@WeekDays = d.WeekDays
				,	@StartDate = d.StartDate
				,	@EndDate = d.EndDate
			FROM	@Date AS d
			ORDER BY WeekDays DESC;
						
			INSERT INTO #tmpTotalLMB(WeekDays, StartDate, EndDate, LeagueIdList, MatchCount, BetCount)
			SELECT	@WeekDays
				,	@StartDate
				,	@EndDate
				,	STUFF((SELECT DISTINCT ',', CONVERT(VARCHAR(MAX), r2.LeagueId)
						FROM #tmpRobotTrading r2 WITH (NOLOCK)
						WHERE r2.EventDate BETWEEN @StartDate AND @EndDate
						FOR XML PATH('')), 1, 1, '') AS LeagueIdList
				,	COUNT(DISTINCT r.MatchId) AS MatchCount
				,	ISNULL(SUM(r.BetCount), 0) AS BetCount
			FROM #tmpRobotTrading AS r WITH(NOLOCK)
			WHERE r.EventDate BETWEEN @StartDate AND @EndDate;
						
			INSERT INTO #tmpLM (StartDate, EndDate, LeagueId, MatchId, HomeId, AwayId)
			SELECT DISTINCT @StartDate
				,	@EndDate
				,	r.LeagueId
				,	r.MatchId
				,	r.HomeId
				,	r.AwayId
			FROM #tmpRobotTrading AS r WITH(NOLOCK)
			WHERE r.EventDate BETWEEN @StartDate AND @EndDate
			GROUP BY r.LeagueId, r.MatchId, r.HomeId, r.AwayId;	
			
			DELETE	d
			FROM	@Date AS d
			WHERE	d.WeekDays = @WeekDays;
		END;	
	
	INSERT INTO #tmpTotalPerformance(EventDate, BetType, BetCount, Stake_VR, WinLoss_VR, Stake_AR, WinLoss_AR)
	SELECT	r.EventDate
		,	r.BetType
		,	ISNULL(SUM(r.BetCount), 0) AS BetCount
		,	SUM(r.Stake_VR)
		,	SUM(r.WinLoss_VR - r.Comm_VR)
		,	SUM(r.Stake_AR)
		,	SUM(r.WinLoss_AR - r.Comm_AR)
	FROM #tmpRobotTrading AS r WITH(NOLOCK)
	GROUP BY r.EventDate, r.BetType;		
	
	-- LeagueId MatchList
	SELECT  lm.StartDate
		,	lm.EndDate
		,	lm.LeagueId		
		,	STUFF((SELECT ',', CONVERT(VARCHAR(MAX), lm2.HomeId), '-' , CONVERT(VARCHAR(MAX), lm2.AwayId)
					FROM #tmpLM lm2 WITH (NOLOCK)
					WHERE lm.StartDate = lm2.StartDate AND lm.EndDate = lm2.EndDate AND lm.LeagueId = lm2.LeagueId
					FOR XML PATH('')), 1, 1, '') AS MatchList
	FROM #tmpLM AS lm WITH(NOLOCK)
	GROUP BY lm.StartDate, lm.EndDate, lm.LeagueId;
		
	-- BetCount by Week
	SELECT	tm.StartDate
		,	tm.EndDate
		,	tm.LeagueIdList
		,	tm.BetCount
	FROM #tmpTotalLMB AS tm WITH(NOLOCK) WHERE tm.BetCount > 0;
	
	-- Detailed
	SELECT 	t.EventDate	
		,	t.BetType
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
	WHERE t.BetCount IS NOT NULL;
	
	DROP TABLE #tmpRobotTrading;
	DROP TABLE #tmpTotalPerformance;
	DROP TABLE #tmpTotalLMB;
	DROP TABLE #tmpLM;
END;

GO
/*<info serverAlias="DBTGRS-bodb_TGRS" executers="bodbTGRSNet" isFunction="0" isNested="0"></info>*/