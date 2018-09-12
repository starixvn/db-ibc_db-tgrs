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
		-	20180724@CaseyHuynh: Enhance SP
	Param's Explanation:
		
	Exam: EXEC Task_TrackChangesOnMatches] @Debug BIT = 0
	 
*/
BEGIN
	SET NOCOUNT ON;
	
	DECLARE	@Begin				DATETIME = GETDATE()
		,	@RowCount			INT
		,	@Duration			INT
		;

	IF	OBJECT_ID('tempdb..#tmpTraceMatch') IS NOT NULL
	BEGIN
		DROP TABLE	#tmpTraceMatch;
	END;

	CREATE TABLE	#tmpTraceMatch (
			MatchId				INT
	);

	-- Track changes on matches	
	IF	OBJECT_ID('tempdb..#tmpTraderSummarizedDataOld') IS NOT NULL
	BEGIN
		DROP TABLE	#tmpTraderSummarizedDataOld;
	END;

	CREATE TABLE	#tmpTraderSummarizedDataOld (
			MatchId				INT
		,	EventDate			DATE
		,	SportType			INT
		,	BetType				SMALLINT
		,	OldCapturedDate		DATETIME
		,	OldTraderID			INT
		,	OldTurnover			MONEY
		,	OldWinLost			MONEY
		,	OldBetCount			INT
	);

	CREATE CLUSTERED INDEX	#CIX_tmpTraderSummarizedOldDataIdx ON #tmpTraderSummarizedDataOld (
			MatchId				ASC
		,	EventDate			ASC
		,	SportType			ASC
		,	BetType				ASC
	);

	IF	OBJECT_ID('tempdb..#tmpTraderSummarizedDataNew') IS NOT NULL
	BEGIN
		DROP TABLE	#tmpTraderSummarizedDataNew;
	END;

	CREATE TABLE	#tmpTraderSummarizedDataNew (
			MatchId				INT
		,	EventDate			DATE
		,	SportType			INT
		,	BetType				SMALLINT
		,	NewCapturedDate		DATETIME
		,	NewTraderID			INT
		,	NewTurnover			MONEY
		,	NewWinLost			MONEY
		,	NewBetCount			INT
	);

	CREATE CLUSTERED INDEX	#CIX_tmpTraderSummarizedNewDataIdx ON #tmpTraderSummarizedDataNew (
			MatchId				ASC
		,	EventDate			ASC
		,	SportType			ASC
		,	BetType				ASC
	);

	
	---GET TRACEMATCH
	INSERT INTO #tmpTraderSummarizedDataOld(MatchId, EventDate, SportType, BetType, OldCapturedDate, OldTraderID, OldTurnover, OldWinLost, OldBetCount)
	SELECT	[MatchId]		= mt.MatchId
		,	[EventDate]		= mt.EventDate
		,	[SportType]		= mt.SportType
		,	[BetType]		= mt.BetType
		,	[OldCapturedDate] = mt.OldCapturedDate
		,	[OldTraderID]		= mt.OldTraderID
		,	[OldTurnover]		= mt.OldTurnover
		,	[OldWinLost]		= mt.OldWinlost
		,	[OldBetCount]		= mt.OldBetCount
	FROM dbo.TrackChangesOnMatches_Queue mt WITH(NOLOCK)

	SELECT	@RowCount	= @@ROWCOUNT
		,	@Duration	= DATEDIFF(millisecond, @Begin, GETDATE());

	IF	@Debug = 1
	BEGIN
		-- Force the output to appear immediately --
		RAISERROR('From TraderPerformance - Insert #tmpTraderSummarizedDataOld - %d rows - %d ms', 0, 0, @RowCount, @Duration) WITH NOWAIT;
	END;
		
	INSERT INTO #tmpTraceMatch (MatchId)
	SELECT DISTINCT o.MatchId
	FROM #tmpTraderSummarizedDataOld AS o WITH(NOLOCK);

	SELECT	@RowCount	= @@ROWCOUNT
		,	@Duration	= DATEDIFF(millisecond, @Begin, GETDATE());
			
	IF	@Debug = 1
	BEGIN
		-- Force the output to appear immediately --
		RAISERROR('Track Changes on Matches - Insert #tmpTraceMatch- %d rows - %d ms', 0, 0, @RowCount, @Duration) WITH NOWAIT;
	END;

	-- check data changed on matches
	DECLARE @NewCapturedDate DATETIME = GETDATE();
	INSERT INTO #tmpTraderSummarizedDataNew(MatchId, EventDate,  SportType, BetType, NewCapturedDate, NewTraderID, NewTurnover, NewWinLost, NewBetCount)
	SELECT	tp.MatchId
		,	tp.EventDate
		,	tp.SportType
		,	tp.BetType
		,	@NewCapturedDate
		,	MAX(tp.CustId)
		,	SUM(tp.Stake)
		,	SUM(tp.WinLost)
		,	SUM(tp.BetCount)
	FROM dbo.TraderPerformance AS tp WITH(NOLOCK)
		INNER JOIN #tmpTraceMatch AS tm WITH(NOLOCK) ON tp.matchid = tm.MatchId
	GROUP BY tp.MatchId
		,	tp.EventDate
		,	tp.SportType
		,	tp.BetType;

	SELECT	@RowCount	= @@ROWCOUNT
		,	@Duration	= DATEDIFF(millisecond, @Begin, GETDATE());

	IF	@Debug = 1
	BEGIN
		-- Force the output to appear immediately --
		RAISERROR('From TraderPerformance - Insert #tmpTraderSummarizedDataNew - %d rows - %d ms', 0, 0, @RowCount, @Duration) WITH NOWAIT;
	END;

	---INSERT DIFFERENCE RECORDS
	INSERT INTO TrackChangedMatch(MatchId, EventDate,  SportType, BetType, OldCapturedDate, OldTraderID, OldBetCount, OldTurnover, OldWinLost
					, NewCapturedDate, NewTraderID, NewBetCount, NewTurnover, NewWinLost, IsNotified)
	SELECT	ISNULL(o.MatchId, n.MatchId)
			, ISNULL(o.EventDate, n.EventDate)
			, ISNULL(o.SportType, n.SportType)
			, ISNULL(o.BetType, n.BetType)
			, o.OldCapturedDate
			, o.OldTraderID
			, o.OldBetCount
			, o.OldTurnover
			, o.OldWinLost
			, n.NewCapturedDate
			, n.NewTraderID
			, n.NewBetCount
			, n.NewTurnover
			, n.NewWinLost
			, 0 AS IsNotified
	FROM	#tmpTraderSummarizedDataOld AS o WITH (NOLOCK)
			FULL OUTER JOIN #tmpTraderSummarizedDataNew AS n WITH (NOLOCK) 
				ON o.MatchId = n.MatchId AND o.BetType = n.BetType
	WHERE  ABS(o.OldTurnover - n.NewTurnover) > 0.1
			OR ABS(o.OldWinLost - n.NewWinLost) > 0.1
			OR o.OldBetCount != n.NewBetCount
			OR o.OldTraderID != n.NewTraderID
			OR o.MatchId IS NULL
			OR n.MatchId IS NULL

	SELECT	@RowCount	= @@ROWCOUNT
		,	@Duration	= DATEDIFF(millisecond, @Begin, GETDATE());

	IF	@Debug = 1
	BEGIN
		-- Force the output to appear immediately --
		RAISERROR('From #tmpTraderSummarizedDataOld and #tmpTraderSummarizedDataNew - Insert ChangedMatches - %d rows - %d ms', 0, 0, @RowCount, @Duration) WITH NOWAIT;
	END;

	------------------DELETE OLD TRACE DATA-------------------
	----ALL Match BEFORE 14 days
	DELETE	tpt
	FROM	dbo.TracePerformanceTrader as tpt WITH (ROWLOCK)
	WHERE	DATEDIFF(DAY, tpt.CapturedDate, @NewCapturedDate) > 14;

	DELETE	tpsm
	FROM	dbo.TracePerformanceScannedMatches as tpsm WITH (ROWLOCK)
	WHERE	DATEDIFF(DAY, tpsm.CapturedDate, @NewCapturedDate) > 14;	
	
	DELETE	tsmi
	FROM	dbo.TraceScannedMatchesInfo as tsmi WITH (ROWLOCK)
	WHERE	DATEDIFF(DAY, tsmi.CapturedDate, @NewCapturedDate) > 14;
	
	----All Matches NOT IN ChangedData
	DELETE	tpt
	FROM	dbo.TracePerformanceTrader as tpt WITH (ROWLOCK)
			LEFT JOIN dbo.TrackChangedMatch tcm WITH(NOLOCK) on tpt.MatchId = tcm.MatchId
	WHERE	tcm.MatchId IS NULL;
	
	DELETE	tpsm
	FROM	dbo.TracePerformanceScannedMatches as tpsm WITH (ROWLOCK)
			LEFT JOIN dbo.TrackChangedMatch tcm WITH(NOLOCK) on tpsm.MatchId = tcm.MatchId
	WHERE	tcm.MatchId IS NULL;
	
	DELETE	tsmi
	FROM	dbo.TraceScannedMatchesInfo as tsmi WITH (ROWLOCK)
			LEFT JOIN dbo.TrackChangedMatch tcm WITH(NOLOCK) on tsmi.MatchId = tcm.MatchId
	WHERE	tcm.MatchId IS NULL;
	
END;
/*<info serverAlias="DBTGRS-bodb_TGRS" executers="bodbTGRSNet" isFunction="0" isNested="0"></info>*/