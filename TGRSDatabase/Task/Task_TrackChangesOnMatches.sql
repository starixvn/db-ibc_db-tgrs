USE [bodb_TGRS]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE	[dbo].[Task_TrackChangesOnMatches]
		@Debug					BIT = 0
AS
/*
	Created:	20180307@Long
	Task :		Track changes on matches [Redmine ID: 89493]
	DB:			DBTGRS.bodb_TGRS
	Original:
  
	Revisions:
   		-	20180502@Long: change the way to get date range

	Param's Explanation:
		
	Exam: EXEC Task_TrackChangesOnMatches] @Debug BIT = 0
	 
*/
BEGIN;
	SET NOCOUNT ON;
	
	DECLARE	@Begin				DATETIME = GETDATE()
		,	@RowCount			INT
		,	@Duration			INT
		,	@Msg				NVARCHAR(MAX)
		;

	IF	OBJECT_ID('tempdb..#tmpDateToTraceChangesOnMatch') IS NOT NULL
	BEGIN;
		DROP TABLE	#tmpDateToTraceChangesOnMatch;
	END;

	CREATE TABLE	#tmpDateToTraceChangesOnMatch (
			EventDate			DATE
	);

	-- Track changes on matches	
	IF	OBJECT_ID('tempdb..#tmpTraderSummarizedDataOld') IS NOT NULL
	BEGIN;
		DROP TABLE	#tmpTraderSummarizedDataOld;
	END;

	CREATE TABLE	#tmpTraderSummarizedDataOld (
			MatchId				INT
		,	EventDate			DATE
		,	CustId				INT
		,	SportType			INT
		,	BetType				SMALLINT
		,	Turnover			MONEY
		,	WinLoss				MONEY
		,	BetCount			INT
	);

	CREATE CLUSTERED INDEX	#CIX_tmpTraderSummarizedOldDataIdx ON #tmpTraderSummarizedDataOld (
			MatchId				ASC
		,	CustId				ASC
		,	SportType			ASC
		,	BetType				ASC
	);

	IF	OBJECT_ID('tempdb..#tmpTraderSummarizedDataNew') IS NOT NULL
	BEGIN;
		DROP TABLE	#tmpTraderSummarizedDataNew;
	END;

	CREATE TABLE	#tmpTraderSummarizedDataNew (
			MatchId				INT
		,	EventDate			DATE
		,	CustId				INT
		,	SportType			INT
		,	BetType				SMALLINT
		,	Turnover			MONEY
		,	WinLoss				MONEY
		,	BetCount			INT
	);

	CREATE CLUSTERED INDEX	#CIX_tmpTraderSummarizedDataNewIdx ON #tmpTraderSummarizedDataNew (
			MatchId				ASC
		,	CustId				ASC
		,	SportType			ASC
		,	BetType				ASC
	);

	IF	OBJECT_ID('tempdb..#tmpChangedMatches') IS NOT NULL
	BEGIN;
		DROP TABLE	#tmpChangedMatches;
	END;

	CREATE TABLE	#tmpChangedMatches (
			MatchId				INT
		,	EventDate			DATE
		,	CustId				INT
		,	SportType			INT
		,	BetType				SMALLINT
	);

	CREATE CLUSTERED INDEX	#CIX_#tmpChangedMatchesIdx ON #tmpChangedMatches (
			MatchId				ASC
		,	CustId				ASC
		,	SportType			ASC
		,	BetType				ASC
	);

	-- retrive the old data from changedmatches
	INSERT INTO #tmpTraderSummarizedDataOld(MatchId, EventDate, CustId, SportType, BetType, Turnover, WinLoss, BetCount)
	SELECT	[MatchId]		= tp.MatchId
		,	[EventDate]		= tp.EventDate
		,	[CustId]		= tp.CustId
		,	[SportType]		= tp.SportType
		,	[BetType]		= tp.BetType
		,	[Turnover]		= tp.PreviousTurnover
		,	[WinLoss]		= tp.PreviousWinloss
		,	[BetCount]		= tp.PreviousBetCount
	FROM dbo.ChangedMatches tp WITH(NOLOCK)
	WHERE tp.CapturedDate = '1999-01-01';

	SELECT	@RowCount	= @@ROWCOUNT
		,	@Duration	= DATEDIFF(millisecond, @Begin, GETDATE())
		;

	IF	@Debug = 1
	BEGIN
		-- Force the output to appear immediately --
		RAISERROR('From TraderPerformance - Insert #tmpTraderSummarizedDataOld - %d rows - %d ms', 0, 0, @RowCount, @Duration) WITH NOWAIT;
	END;

	DELETE FROM dbo.ChangedMatches
	WHERE CapturedDate = '1999-01-01';
	
	INSERT INTO #tmpDateToTraceChangesOnMatch (EventDate)
	SELECT DISTINCT o.EventDate
	FROM #tmpTraderSummarizedDataOld o;

	SELECT	@RowCount	= @@ROWCOUNT
		,	@Duration	= DATEDIFF(millisecond, @Begin, GETDATE())
		;
			
	IF	@Debug = 1
	BEGIN;
		-- Force the output to appear immediately --
		RAISERROR('Track Changes on Matches - Insert #tmpDateToTraceChangesOnMatch - %d rows - %d ms', 0, 0, @RowCount, @Duration) WITH NOWAIT;
	END;

	-- check data changed on matches
	INSERT INTO #tmpTraderSummarizedDataNew(MatchId, EventDate, CustId, SportType, BetType, Turnover, WinLoss, BetCount)
	SELECT	[MatchId]		= tp.MatchId
		,	[EventDate]		= tp.EventDate
		,	[CustId]		= tp.CustId
		,	[SportType]		= tp.SportType
		,	[BetType]		= tp.BetType
		,	[Turnover]		= SUM(tp.Stake)
		,	[WinLoss]		= SUM(tp.WinLost)
		,	[BetCount]		= SUM(tp.BetCount)
	FROM dbo.TraderPerformance tp WITH(NOLOCK)
		INNER JOIN #tmpDateToTraceChangesOnMatch d ON tp.EventDate = d.EventDate
	GROUP BY tp.MatchId
		,	tp.EventDate
		,	tp.CustId
		,	tp.SportType
		,	tp.BetType;

	SELECT	@RowCount	= @@ROWCOUNT
		,	@Duration	= DATEDIFF(millisecond, @Begin, GETDATE())
		;

	IF	@Debug = 1
	BEGIN
		-- Force the output to appear immediately --
		RAISERROR('From TraderPerformance - Insert #tmpTraderSummarizedDataNew - %d rows - %d ms', 0, 0, @RowCount, @Duration) WITH NOWAIT;
	END;

	-- IF (SELECT COUNT(1) FROM #tmpTraderSummarizedDataOld) = (SELECT COUNT(1) FROM #tmpTraderSummarizedDataNew)
	BEGIN
		INSERT INTO #tmpChangedMatches(MatchId, EventDate, CustId, SportType, BetType)
		SELECT	[MatchId]		= n.MatchId
			,	[EventDate]		= n.EventDate
			,	[CustId]		= n.CustId
			,	[SportType]		= n.SportType
			,	[BetType]		= n.BetType
		FROM (
			SELECT MatchId, EventDate, CustId, SportType, BetType, Turnover, WinLoss, BetCount
			FROM #tmpTraderSummarizedDataOld
			UNION ALL
			SELECT MatchId, EventDate, CustId, SportType, BetType, Turnover, WinLoss, BetCount
			FROM #tmpTraderSummarizedDataNew) AS n
		GROUP BY n.MatchId, n.EventDate, n.SportType, n.BetType, n.CustId
		HAVING MAX(n.Turnover) - MIN(n.Turnover) > 0.1
			OR ABS(MAX(n.WinLoss) - MIN(n.WinLoss)) > 0.1
			OR MAX(n.BetCount) - MIN(n.BetCount) > 1
			OR COUNT(1) < 2;

		INSERT INTO dbo.ChangedMatches(MatchId, EventDate, CustId, SportType, BetType, PreviousTurnover, PreviousWinloss, PreviousBetCount, Turnover, Winloss, BetCount, CapturedDate)
		SELECT	[MatchId]				= m.MatchId
			,	[EventDate]				= m.EventDate
			,	[CustId]				= m.CustId
			,	[SportType]				= m.SportType
			,	[BetType]				= m.BetType
			,	[PreviousTurnover]		= o.Turnover
			,	[PreviousWinloss]		= o.WinLoss
			,	[PreviousBetCount]		= o.BetCount
			,	[Turnover]				= n.Turnover
			,	[Winloss]				= n.WinLoss
			,	[BetCount]				= n.BetCount
			,	[CapturedDate]			= GETDATE()
		FROM #tmpChangedMatches m
			LEFT JOIN #tmpTraderSummarizedDataOld o ON m.MatchId = o.MatchId AND m.CustId = o.CustId AND m.SportType = o.SportType AND m.BetType = o.BetType
			LEFT JOIN #tmpTraderSummarizedDataNew n ON m.MatchId = n.MatchId AND m.CustId = n.CustId AND m.SportType = n.SportType AND m.BetType = n.BetType;

		SELECT	@RowCount	= @@ROWCOUNT
			,	@Duration	= DATEDIFF(millisecond, @Begin, GETDATE())
			;

		IF	@Debug = 1
		BEGIN
			-- Force the output to appear immediately --
			RAISERROR('From #tmpTraderSummarizedDataOld and #tmpTraderSummarizedDataNew - Insert ChangedMatches - %d rows - %d ms', 0, 0, @RowCount, @Duration) WITH NOWAIT;
		END;
	END;
	
END;	