/*
Creator: 20180905@LongLuu
Task:  Remove Unused Teams [Redmine ID: #100750]
Server:  bodb_TGRS

Reviewer: Billy
*/ 

---------------------------------------------------
-- STEP 0: ARRANGE
DECLARE @FromDate		DATETIME = '2011-01-01'
	,	@ToDate			DATETIME = GETDATE();

IF	OBJECT_ID('tempdb..#tmpTraderTeams') IS NOT NULL
BEGIN
	DROP TABLE #tmpTraderTeams;
END;

CREATE TABLE	#tmpTraderTeams (
		CustId			INT
	,	BeginDate		DATE
	,	EndDate			DATE
	,	TeamId			INT
	,	PrevTeam		INT
	,	NextTeam		INT
);

CREATE CLUSTERED INDEX	#CIX_tmpTraderTeamsIdx ON #tmpTraderTeams (
		CustId			ASC
	,	BeginDate		ASC
	,	EndDate			ASC
);

IF	OBJECT_ID('tempdb..#tmpWinlostDate') IS NOT NULL
BEGIN;
	DROP TABLE	#tmpWinlostDate;
END;

CREATE TABLE	#tmpWinlostDate (
	winlostdate			DATE
);

IF	OBJECT_ID('tempdb..#tmpBettypeGroup') IS NOT NULL
BEGIN
	DROP TABLE #tmpBettypeGroup;
END;

CREATE TABLE	#tmpBettypeGroup (
		BetType			SMALLINT
	,	BettypeGroup	TINYINT
);

CREATE CLUSTERED INDEX	#CIX_tmpRTBettypeGroupIdx ON #tmpBettypeGroup (
		BetType			ASC
);

INSERT INTO #tmpBettypeGroup(BetType, BettypeGroup)
SELECT DISTINCT b.BetType
	,	b.BettypeGroup
FROM dbo.BetType b WITH(NOLOCK);

---------------------------------------------------
-- STEP 1: CALC THE PREV AND NEXT TEAM TO MIGRATE
INSERT INTO #tmpTraderTeams(CustId, BeginDate, EndDate, TeamId, PrevTeam, NextTeam)
SELECT	t.CustId
	,	t.BeginDate
	,	t.EndDate
	,	t.TeamId
	,	ISNULL((SELECT TOP 1 ISNULL(a.TeamId,0) AS PrevT
		FROM dbo.TraderTeam_History AS a WITH(NOLOCK)
		WHERE a.CustId = t.CustId
			AND a.EndDate < t.BeginDate
			AND a.TeamId NOT IN (3,4,6,7,8,9,10,12)
		ORDER BY a.BeginDate DESC), NULL) AS PrevT
	,	ISNULL((SELECT TOP 1 ISNULL(b.TeamId,0) AS NextT
		FROM dbo.TraderTeam_History AS b WITH(NOLOCK)
		WHERE b.CustId = t.CustId
			AND b.BeginDate > t.EndDate
			AND b.TeamId NOT IN (3,4,6,7,8,9,10,12)
		ORDER BY b.BeginDate ASC), NULL) AS NextT
FROM dbo.TraderTeam_History AS t WITH(NOLOCK)
WHERE t.TeamId IN (3,4,6,7,8,9,10,12);

---------------------------------------------------
-- STEP 2: UPDATE THE DATA FROM TRADER PERFORMANCE
UPDATE t WITH(ROWLOCK, UPDLOCK)
SET t.TeamId = ISNULL(a.PrevTeam, a.NextTeam)
FROM dbo.TraderPerformance AS t
	INNER JOIN #tmpTraderTeams a WITH(NOLOCK) ON t.CustId = a.CustId
		AND t.EventDate BETWEEN a.BeginDate AND a.EndDate;
		
RAISERROR('Done for Re-Calc TRADER PERFORMANCE', 0, 0, 1, 1) WITH NOWAIT;

---------------------------------------------------
-- STEP 3: RE-SUM FOR SummaryByTeam_Daily
DECLARE @WinlostDate	DATE;

INSERT INTO	#tmpWinlostDate (winlostdate)
SELECT	tally.EventDate
FROM	(
	SELECT	[NoDays] = DATEDIFF(DAY, @FromDate, @ToDate) + 1
) cnt
CROSS APPLY	(
	SELECT	TOP(cnt.NoDays)
			[EventDate] = DATEADD(DAY, ROW_NUMBER() OVER(ORDER BY (SELECT NULL)) - 1, @FromDate)
	FROM		(VALUES (0), (0), (0), (0), (0), (0), (0), (0), (0), (0)) x10(n)
	CROSS APPLY	(VALUES (0), (0), (0), (0), (0), (0), (0), (0), (0), (0)) x100(n)
	CROSS APPLY	(VALUES (0), (0), (0), (0), (0), (0), (0), (0), (0), (0)) x1000(n)
) tally;

WHILE	EXISTS (SELECT 1 FROM #tmpWinlostDate)
BEGIN
	SELECT	TOP(1)
			@WinLostDate = d.winlostdate
	FROM	#tmpWinlostDate AS d;

	DELETE FROM [dbo].[SummaryByTeam_Daily]
	WHERE EventDate = @WinLostDate;

	INSERT INTO [dbo].[SummaryByTeam_Daily]
	(
			[EventDate]
		,	[TeamId]
		,	[LeagueId]
		,	[WorkShift]
		,	[Stake]
		,	[WinLost]
		,	[Comm]
		,	[BetCount]
		,	[MatchCount]
		,	[BettypeGroup]
	)
	SELECT @WinlostDate [EventDate]
		,	s.[TeamId]
		,	s.[LeagueId]
		,	s.[WorkShift]
		,	SUM(s.[Stake]) [Stake]
		,	SUM(s.[WinLost]) [WinLost]
		,	SUM(s.[Comm]) [Comm]
		,	SUM(s.[BetCount]) BetCount
		,	COUNT(DISTINCT s.[MatchId])[MatchCount]
		,	g.[BettypeGroup]
	FROM [dbo].[TraderPerformance] s WITH(NOLOCK)
		INNER JOIN #tmpBettypeGroup g WITH(NOLOCK) ON s.BetType = g.BetType
	WHERE EventDate = @WinlostDate
		AND IsLive = 1
	GROUP BY [TeamId]
		,	s.[LeagueId]
		,	s.[WorkShift]
		,	g.[BettypeGroup];

	DELETE	d
	FROM	#tmpWinlostDate AS d
	WHERE	d.winlostdate = @WinlostDate;
END;

TRUNCATE TABLE #tmpWinlostDate;

RAISERROR('Done for SUM DAILY', 0, 0, 1, 1) WITH NOWAIT;

---------------------------------------------------
-- STEP 4: RE-SUM FOR SummaryByTeam_Monthly
DECLARE @StartDate		DATE
	,	@EndDate		DATE;

INSERT INTO	#tmpWinlostDate (winlostdate)
SELECT	tally.EventDate
FROM	(
	SELECT	[NoMonths] = DATEDIFF(MONTH, @FromDate, @ToDate) + 1
) cnt
CROSS APPLY	(
	SELECT	TOP(cnt.NoMonths)
			[EventDate] = DATEADD(MONTH, ROW_NUMBER() OVER(ORDER BY (SELECT NULL)) - 1, @FromDate)
	FROM		(VALUES (0), (0), (0), (0), (0), (0), (0), (0), (0), (0)) x10(n)
	CROSS APPLY	(VALUES (0), (0), (0), (0), (0), (0), (0), (0), (0), (0)) x100(n)
	CROSS APPLY	(VALUES (0), (0), (0), (0), (0), (0), (0), (0), (0), (0)) x1000(n)
) tally;
		
WHILE	EXISTS (SELECT 1 FROM #tmpWinlostDate)
BEGIN;
	SELECT	TOP(1)
			@WinLostDate = d.winlostdate
	FROM	#tmpWinlostDate AS d;

	SELECT @StartDate = DATEADD(DD, -DAY(@WinLostDate) + 1, @WinLostDate);
	SELECT @EndDate = DATEADD(DD, -1 , DATEADD(MM, 1, @StartDate));
 
	-- [SummaryByTeam_Monthly] table
	DELETE [dbo].SummaryByTeam_Monthly	WHERE EventDate = @WinLostDate;

	INSERT INTO [dbo].[SummaryByTeam_Monthly]
	(
			[EventDate]
		,	[TeamId]
		,	[LeagueId]
		,	[WorkShift]
		,	[Stake]
		,	[WinLost]
		,	[Comm]
		,	[BetCount]
		,	[MatchCount]
		,	[BettypeGroup]
	)
	SELECT @WinLostDate [EventDate]
		,	s.[TeamId]
		,	s.[LeagueId]
		,	s.[WorkShift]
		,	SUM(s.[Stake]) [Stake]
		,	SUM(s.[WinLost]) [WinLost]
		,	SUM(s.[Comm]) [Comm]
		,	SUM(s.[BetCount]) BetCount
		,	COUNT(DISTINCT s.[MatchId])[MatchCount]
		,	g.[BettypeGroup]
	FROM [dbo].[TraderPerformance] s WITH(NOLOCK)
		INNER JOIN #tmpBettypeGroup g WITH(NOLOCK) ON s.BetType = g.BetType
	WHERE EventDate BETWEEN @StartDate AND @EndDate
		AND IsLive = 1
	GROUP BY [TeamId]
		,	s.[LeagueId]
		,	s.[WorkShift]
		,	g.[BettypeGroup];

	DELETE	d
	FROM	#tmpWinlostDate AS d
	WHERE	d.winlostdate = @WinlostDate;
END;

---------------------------------------------------
-- STEP 5: MIGRATE DATA FOR TraderTeam_History
UPDATE t WITH(ROWLOCK, UPDLOCK)
SET t.TeamId = ISNULL(a.PrevTeam, a.NextTeam)
FROM dbo.TraderTeam_History AS t
	INNER JOIN #tmpTraderTeams a WITH(NOLOCK) ON t.CustId = a.CustId
		AND t.BeginDate = a.BeginDate AND t.EndDate = a.EndDate;
		
RAISERROR('Done for TraderTeam_History', 0, 0, 1, 1) WITH NOWAIT;
