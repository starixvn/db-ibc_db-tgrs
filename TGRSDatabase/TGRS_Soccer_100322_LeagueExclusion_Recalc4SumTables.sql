/*
Creator: 20180905@LongLuu
Task:  Create tables for TGRS's League Exclusion
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

TRUNCATE TABLE [dbo].[SummaryByTeam_Daily];

WHILE	EXISTS (SELECT 1 FROM #tmpWinlostDate)
BEGIN;
	SELECT	TOP(1)
			@WinLostDate = d.winlostdate
	FROM	#tmpWinlostDate AS d;

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
-- STEP 2: Sum MONTHLY
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

DECLARE @StartDate		DATE
	,	@EndDate		DATE;

WHILE	EXISTS (SELECT 1 FROM #tmpWinlostDate)
BEGIN;
	SELECT	TOP(1)
			@WinLostDate = d.winlostdate
	FROM	#tmpWinlostDate AS d;

	SELECT @StartDate = @WinLostDate;
	SELECT @EndDate = DATEADD(DD, -1 , DATEADD(MM, 1, @StartDate));
 
	-- [SummaryByTrader_Monthly] table
	DELETE [dbo].[SummaryByTrader_Monthly] WHERE EventDate = @WinLostDate;

	INSERT INTO [dbo].[SummaryByTrader_Monthly]
	(
			[Eventdate]
		,	[CustId]
		,	[LeagueId]
		,	[WorkShift]
		,	[Stake]
		,	[WinLost]
		,	[Comm]
		,	[BetCount]
		,	[MatchCount]
		,	[BettypeGroup]
	)
	SELECT	@WinLostDate [Eventdate]
		,	s.[CustId]
		,	s.[LeagueId]
		,	s.[WorkShift]
		,	SUM(s.[Stake]) [Stake]
		,	SUM(s.[WinLost]) [WinLost]
		,	SUM(s.[Comm]) [Comm]
		,	SUM(s.[BetCount]) [BetCount]
		,	COUNT(DISTINCT s.[MatchId])[MatchCount]
		,	g.[BettypeGroup]
	 FROM [dbo].[TraderPerformance] s WITH(NOLOCK)
		INNER JOIN #tmpBettypeGroup g WITH(NOLOCK) ON s.BetType = g.BetType
	 WHERE EventDate BETWEEN @StartDate AND @EndDate
		AND IsLive = 1
	 GROUP BY [CustId]
		,	s.[LeagueId]
		,	s.[WorkShift]
		,	g.[BettypeGroup];

	-- [SummaryByBetType_Monthly] table
	DELETE [dbo].[SummaryByBetType_Monthly]	WHERE EventDate = @WinLostDate;

	INSERT INTO [dbo].[SummaryByBetType_Monthly]
	(
			[EventDate]
		,	[LeagueId]
		,	[BetType]
		,	[WorkShift]
		,	[Stake]
		,	[WinLost]
		,	[Comm]
		,	[BetCount]
		,	[MatchCount]
	)
	SELECT @WinLostDate [EventDate]
		,	[LeagueId]
		,	[BetType]
		,	[WorkShift]
		,	SUM([Stake]) [Stake]
		,	SUM([WinLost]) [WinLost]
		,	SUM([Comm]) [Comm]
		,	SUM([BetCount]) BetCount
		,	COUNT(DISTINCT [MatchId])[MatchCount]
	FROM [dbo].[TraderPerformance] WITH(NOLOCK)
	WHERE EventDate BETWEEN @StartDate AND @EndDate
		AND IsLive = 1
	GROUP BY [LeagueId]
		,	[BetType]
		,	[WorkShift]

	-- [SummaryByLeague_Monthly] table
	DELETE [dbo].SummaryByLeague_Monthly	WHERE EventDate = @WinLostDate;

	INSERT INTO [dbo].[SummaryByLeague_Monthly]
	(
			[EventDate]
		,	[LeagueId]
		,	[WorkShift]
		,	[Stake]
		,	[WinLost]
		,	[Comm]
		,	[BetCount]
		,	[MatchCount]
		,	[BettypeGroup]
	)
	SELECT	@WinLostDate [EventDate]
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
	GROUP BY [LeagueId]
		,	s.[WorkShift]
		,	g.[BettypeGroup];

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

TRUNCATE TABLE #tmpWinlostDate;

RAISERROR('Done for SUM MONTHLY', 0, 0, 1, 1) WITH NOWAIT;

---------------------------------------------------
-- STEP 3: Sum MONTHLY - With LIVEINDICATOR
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

-- Create table TraderPerformance
IF	OBJECT_ID('tempdb..#tmpTraderPerformance') IS NOT NULL
BEGIN;
	DROP TABLE #tmpTraderPerformance;
END;

CREATE TABLE #tmpTraderPerformance(
		[CustId]		INT NOT NULL,
		[MatchId]		INT NOT NULL,
		[EventDate]		DATE NOT NULL,
		[SportType]		SMALLINT NULL,
		[BetType]		SMALLINT NOT NULL,
		[IsLive]		SMALLINT NOT NULL,
		[LeagueId]		INT NULL,
		[TeamId]		SMALLINT NULL,
		[Grade]			TINYINT NULL,
		[Stake]			MONEY NULL,
		[WinLost]		MONEY NULL,
		[Comm]			MONEY NULL,
		[BetCount]		INT NULL,
		[HomeId]		INT NULL,
		[AwayId]		INT NULL,
		[MatchCode]		VARCHAR(100) NULL,
		[WorkShift]		TINYINT NULL,
		[Spread]		MONEY NULL,
		[Juice]			MONEY NULL,
		[StakeMYR]		MONEY NULL,
		[StakeMYRJuice] MONEY NULL
);

CREATE CLUSTERED INDEX	#CIX_tmpTraderPerformanceIdx ON #tmpTraderPerformance (
		[CustId]		ASC
	,	[EventDate]		DESC
	,	[MatchId]		ASC
	,	[SportType]		ASC
	,	[BetType]		ASC
	,	[IsLive]		ASC
);

DECLARE @CurrentMonthStartDate		DATE
	,	@CurrentMonthEndDate		DATE;

WHILE	EXISTS (SELECT 1 FROM #tmpWinlostDate)
BEGIN;
	SELECT	TOP(1)
			@WinLostDate = d.winlostdate
	FROM	#tmpWinlostDate AS d;

	SELECT	@CurrentMonthStartDate =	@WinLostDate;
	SELECT	@CurrentMonthEndDate =		DATEADD(DD, -1 , DATEADD(MM, 1, @CurrentMonthStartDate));
		
	-- Insert tickets
	INSERT INTO #tmpTraderPerformance(
			[CustId],
			[MatchId],
			[EventDate],
			[SportType],
			[BetType],
			[LeagueId],
			[TeamId],
			[Grade],
			[Stake],
			[WinLost],
			[Comm],
			[BetCount],
			[HomeId],
			[AwayId],
			[MatchCode],
			[WorkShift],
			[Spread],
			[IsLive]
	)
	SELECT  tp.[CustId],
			tp.[MatchId],
			tp.[EventDate],
			tp.[SportType],
			tp.[BetType],
			tp.[LeagueId],
			tp.[TeamId],
			tp.[Grade],
			tp.[Stake],
			tp.[WinLost],
			tp.[Comm],
			tp.[BetCount],
			tp.[HomeId],
			tp.[AwayId],
			tp.[MatchCode],
			tp.[WorkShift],
			tp.[Spread],
			tp.[IsLive]
	FROM dbo.[TraderPerformance] tp WITH(NOLOCK)
		INNER JOIN dbo.BetType bt WITH (NOLOCK) ON tp.Bettype = bt.Bettype
	WHERE tp.EventDate BETWEEN @CurrentMonthStartDate AND @CurrentMonthEndDate;

	-- Rearrange bettype
	UPDATE #tmpTraderPerformance
	SET Bettype = 1
	WHERE Bettype = 7;

	UPDATE #tmpTraderPerformance
	SET Bettype = 3
	WHERE Bettype = 8;

	UPDATE #tmpTraderPerformance
	SET Bettype = 5
	WHERE Bettype = 15;

	UPDATE #tmpTraderPerformance
	SET Bettype = 0 -- Other Bettypes
	WHERE Bettype NOT IN (1, 3, 7, 8, 5, 15);

	-- Insert data for TraderPerformance Monthly
	DELETE [dbo].[TraderPerformance_Monthly]	
	WHERE EventDate = @CurrentMonthStartDate;

	INSERT INTO [dbo].[TraderPerformance_Monthly]
	(
			[CustId]
		,	[LeagueId]
		,	[EventDate]
		,	[SportType]
		,	[BetType]
		,	[IsLive]
		,	[Turnover]
		,	[WinLoss]
		,	[Comm]
		,	[BetCount]
	)
	SELECT tpp.CustId
		,	tpp.LeagueId
		,	@CurrentMonthStartDate AS EventDate
		,	tpp.SportType
		,	tpp.BetType
		,	tpp.IsLive
		,	SUM(tpp.Stake) AS Turnover
		,	SUM(tpp.WinLost) AS WinLoss
		,	SUM(tpp.Comm) AS Comm
		,	SUM(tpp.BetCount) AS BetCount
	FROM #tmpTraderPerformance tpp
	GROUP BY tpp.CustId
		,	tpp.LeagueId
		,	tpp.SportType
		,	tpp.BetType
		,	tpp.IsLive;

	INSERT INTO [dbo].[TraderPerformance_Monthly]
	(
			[CustId]
		,	[LeagueId]
		,	[EventDate]
		,	[SportType]
		,	[BetType]
		,	[IsLive]
		,	[Turnover]
		,	[WinLoss]
		,	[Comm]
		,	[BetCount]
	)
	SELECT tpp.CustId
		,	tpp.LeagueId
		,	@CurrentMonthStartDate AS EventDate
		,	tpp.SportType
		,	tpp.BetType
		,	-1 AS IsLive
		,	SUM(tpp.Stake) AS Turnover
		,	SUM(tpp.WinLost) AS WinLoss
		,	SUM(tpp.Comm) AS Comm
		,	SUM(tpp.BetCount) AS BetCount
	FROM #tmpTraderPerformance tpp
	GROUP BY tpp.CustId
		,	tpp.LeagueId
		,	tpp.SportType
		,	tpp.BetType;

	INSERT INTO [dbo].[TraderPerformance_Monthly]
	(
			[CustId]
		,	[LeagueId]
		,	[EventDate]
		,	[SportType]
		,	[BetType]
		,	[IsLive]
		,	[Turnover]
		,	[WinLoss]
		,	[Comm]
		,	[BetCount]
	)
	SELECT tpp.CustId
		,	tpp.LeagueId
		,	@CurrentMonthStartDate AS EventDate
		,	tpp.SportType
		,	-1 AS BetType
		,	tpp.IsLive
		,	SUM(tpp.Stake) AS Turnover
		,	SUM(tpp.WinLost) AS WinLoss
		,	SUM(tpp.Comm) AS Comm
		,	SUM(tpp.BetCount) AS BetCount
	FROM #tmpTraderPerformance tpp
	GROUP BY tpp.CustId
		,	tpp.LeagueId
		,	tpp.SportType
		,	tpp.IsLive;

	INSERT INTO [dbo].[TraderPerformance_Monthly]
	(
			[CustId]
		,	[LeagueId]
		,	[EventDate]
		,	[SportType]
		,	[BetType]
		,	[IsLive]
		,	[Turnover]
		,	[WinLoss]
		,	[Comm]
		,	[BetCount]
	)
	SELECT tpp.CustId
		,	tpp.LeagueId
		,	@CurrentMonthStartDate AS EventDate
		,	tpp.SportType
		,	-1 AS BetType
		,	-1 AS IsLive
		,	SUM(tpp.Stake) AS Turnover
		,	SUM(tpp.WinLost) AS WinLoss
		,	SUM(tpp.Comm) AS Comm
		,	SUM(tpp.BetCount) AS BetCount
	FROM #tmpTraderPerformance tpp
	GROUP BY tpp.CustId
		,	tpp.LeagueId
		,	tpp.SportType;

	-- Insert data for TraderMatchCount_Monthly table	
	DELETE [dbo].[TraderMatchCount_Monthly]	
	WHERE EventDate = @CurrentMonthStartDate;

	INSERT INTO dbo.TraderMatchCount_Monthly
	(
			[CustId]
		,	[LeagueId]
		,	[EventDate]
		,	[SportType]
		,	[BetType]
		,	[IsLive]
		,	[MatchCount]
	)
	SELECT	tp.CustId
		,	tp.LeagueId
		,	@CurrentMonthStartDate AS EventDate
		,	tp.SportType
		,	tp.BetType
		,	tp.IsLive
		,	COUNT(DISTINCT tp.MatchId) AS MatchCount
	FROM #tmpTraderPerformance tp
	GROUP BY tp.CustId
		,	tp.LeagueId
		,	tp.SportType
		,	tp.BetType
		,	tp.IsLive;

	INSERT INTO dbo.TraderMatchCount_Monthly
	(
			[CustId]
		,	[LeagueId]
		,	[EventDate]
		,	[SportType]
		,	[BetType]
		,	[IsLive]
		,	[MatchCount]
	)
	SELECT	tp.CustId
		,	tp.LeagueId
		,	@CurrentMonthStartDate AS EventDate
		,	tp.SportType
		,	tp.BetType
		,	-1 AS IsLive
		,	COUNT(DISTINCT tp.MatchId) AS MatchCount
	FROM #tmpTraderPerformance tp
	GROUP BY tp.CustId
		,	tp.LeagueId
		,	tp.SportType
		,	tp.BetType;

	INSERT INTO dbo.TraderMatchCount_Monthly
	(
			[CustId]
		,	[LeagueId]
		,	[EventDate]
		,	[SportType]
		,	[BetType]
		,	[IsLive]
		,	[MatchCount]
	)
	SELECT	tp.CustId
		,	tp.LeagueId
		,	@CurrentMonthStartDate AS EventDate
		,	tp.SportType
		,	-1 AS BetType
		,	tp.IsLive
		,	COUNT(DISTINCT tp.MatchId) AS MatchCount
	FROM #tmpTraderPerformance tp
	GROUP BY tp.CustId
		,	tp.LeagueId
		,	tp.SportType
		,	tp.IsLive;

	INSERT INTO dbo.TraderMatchCount_Monthly
	(
			[CustId]
		,	[LeagueId]
		,	[EventDate]
		,	[SportType]
		,	[BetType]
		,	[IsLive]
		,	[MatchCount]
	)
	SELECT	tp.CustId
		,	tp.LeagueId
		,	@CurrentMonthStartDate AS EventDate
		,	tp.SportType
		,	-1 AS BetType
		,	-1 AS IsLive
		,	COUNT(DISTINCT tp.MatchId) AS MatchCount
	FROM #tmpTraderPerformance tp
	GROUP BY tp.CustId
		,	tp.LeagueId
		,	tp.SportType;

	DELETE	d
	FROM	#tmpWinlostDate AS d
	WHERE	d.winlostdate = @WinlostDate;

	TRUNCATE TABLE #tmpTraderPerformance;
END;

TRUNCATE TABLE #tmpWinlostDate;	

RAISERROR('Done for SUM MONTHLY with LIVEINDICATOR', 0, 0, 1, 1) WITH NOWAIT;

---------------------------------------------------
-- STEP 4: Sum YEARLY
INSERT INTO	#tmpWinlostDate (winlostdate)
SELECT	tally.EventDate
FROM	(
	SELECT	[NoYears] = DATEDIFF(YEAR, @FromDate, @ToDate) + 1
) cnt
CROSS APPLY	(
	SELECT	TOP(cnt.NoYears)
			[EventDate] = DATEADD(YEAR, ROW_NUMBER() OVER(ORDER BY (SELECT NULL)) - 1, @FromDate)
	FROM		(VALUES (0), (0), (0), (0), (0), (0), (0), (0), (0), (0)) x10(n)
	CROSS APPLY	(VALUES (0), (0), (0), (0), (0), (0), (0), (0), (0), (0)) x100(n)
	CROSS APPLY	(VALUES (0), (0), (0), (0), (0), (0), (0), (0), (0), (0)) x1000(n)
) tally;

DECLARE @CurrentYearStartDate		DATE
	,	@CurrentYearEndDate			DATE
	,	@Year						INT;

WHILE	EXISTS (SELECT 1 FROM #tmpWinlostDate)
BEGIN;
	SELECT	TOP(1)
			@WinLostDate = d.winlostdate
	FROM	#tmpWinlostDate AS d;

	SELECT @CurrentYearStartDate = @WinLostDate;
	SELECT @CurrentYearEndDate = DATEADD(DD, -1 , DATEADD(MM, 1, @CurrentYearStartDate));
	 
	-- Update data for TraderPerformance Yearly
	SELECT @Year = YEAR(@CurrentYearStartDate);

	DELETE [dbo].[TraderPerformance_Yearly]	
	WHERE [Year] = @Year;

	INSERT INTO [dbo].[TraderPerformance_Yearly]
	(
			[CustId]
		,	[LeagueId]
		,	[Year]
		,	[SportType]
		,	[BetType]
		,	[IsLive]
		,	[Turnover]
		,	[WinLoss]
		,	[Comm]
		,	[BetCount]
	)
	SELECT	tpp.CustId
		,	tpp.LeagueId
		,	@Year AS [Year]
		,	tpp.SportType
		,	tpp.BetType
		,	tpp.IsLive
		,	SUM(tpp.Turnover) AS Turnover
		,	SUM(tpp.WinLoss) AS WinLoss
		,	SUM(tpp.Comm) AS Comm
		,	SUM(tpp.BetCount) AS BetCount
	FROM [dbo].[TraderPerformance_Monthly] tpp WITH(NOLOCK)
	WHERE tpp.EventDate BETWEEN @CurrentYearStartDate AND @CurrentYearEndDate
	GROUP BY tpp.CustId
		,	tpp.LeagueId
		,	tpp.SportType
		,	tpp.BetType
		,	tpp.IsLive;
		
	-- Update data for TraderMatchCount_Yearly	
	DELETE [dbo].[TraderMatchCount_Yearly]	
	WHERE [Year] = @Year;

	INSERT INTO dbo.[TraderMatchCount_Yearly]
	(
			[CustId]
		,	[LeagueId]
		,	[Year]
		,	[SportType]
		,	[BetType]
		,	[IsLive]
		,	[MatchCount]
	)
	SELECT	tp.CustId
		,	tp.LeagueId
		,	@Year AS [Year]
		,	tp.SportType
		,	tp.BetType
		,	tp.IsLive
		,	SUM(tp.MatchCount) AS MatchCount
	FROM TraderMatchCount_Monthly tp WITH(NOLOCK)
	WHERE tp.EventDate BETWEEN @CurrentYearStartDate AND @CurrentYearEndDate
	GROUP BY tp.CustId
		,	tp.LeagueId
		,	tp.SportType
		,	tp.BetType
		,	tp.IsLive;

	DELETE	d
	FROM	#tmpWinlostDate AS d
	WHERE	d.winlostdate = @WinlostDate;
END;

DROP TABLE #tmpWinlostDate;
DROP TABLE #tmpBettypeGroup;

RAISERROR('Done for SUM YEARLY', 0, 0, 1, 1) WITH NOWAIT;