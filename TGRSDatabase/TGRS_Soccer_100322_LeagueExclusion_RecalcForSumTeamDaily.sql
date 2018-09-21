/*
Creator: 20180921@LongLuu
Task:  Re-sum data for table [SummaryByTeam_Daily]
Server:  bodb_TGRS

Reviewer: Billy
*/ 

---------------------------------------------------
-- STEP 0: ARRANGE
DECLARE @FromDate		DATETIME = '2011-01-01'
	,	@ToDate			DATETIME = GETDATE();

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

IF	OBJECT_ID('tempdb..#tmpWinlostDate') IS NOT NULL
BEGIN;
	DROP TABLE	#tmpWinlostDate;
END;

CREATE TABLE	#tmpWinlostDate (
	winlostdate			DATE
);

---------------------------------------------------
-- STEP 1: Sum DAILY
DECLARE @WinlostDate	DATE;

--INSERT INTO	#tmpWinlostDate (winlostdate)
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
	CROSS APPLY	(VALUES (0), (0), (0), (0), (0), (0), (0), (0), (0), (0)) x10000(n)
	CROSS APPLY	(VALUES (0), (0), (0), (0), (0), (0), (0), (0), (0), (0)) x100000(n)
) tally;

WHILE	EXISTS (SELECT 1 FROM #tmpWinlostDate)
BEGIN;
	SELECT	TOP(1)
			@WinLostDate = d.winlostdate
	FROM	#tmpWinlostDate AS d;
		
	DELETE [dbo].[SummaryByTeam_Daily]	
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

RAISERROR('Done for SUM DAILY', 0, 0, 1, 1) WITH NOWAIT;