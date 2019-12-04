ALTER PROCEDURE [dbo].[TGRS_Rpt_MultipleMatches]
	@FromDate			DATE,
	@ToDate				DATE
AS    
/*  
	Created:	20191204@Long.Luu
	Task :		Multiple Matches Report
	DB:			DBTGRS.bodb_TGRS
	Original:  
  
	Revisions: 	
   		- 20191204@Long.Luu:	Created [Remine Id: 118960]

	Param's Explanation:  	

	Exam:   
*/  
 
BEGIN 
	SET NOCOUNT ON;

	IF	OBJECT_ID('tempdb..#tmpMatchesInfo') IS NOT NULL
	BEGIN
		DROP TABLE #tmpMatchesInfo;
	END;

	CREATE TABLE	#tmpMatchesInfo (
			CustId				INT NOT NULL
		,	MatchId				INT NOT NULL
		,	EventDate			DATETIME
		,	GlobalShowTime		SMALLDATETIME
	);

	CREATE CLUSTERED INDEX	#CIX_tmpMatchesInfo_CustIdMatchId ON #tmpMatchesInfo (
			CustId				ASC
		,	MatchId				ASC
	);

	IF	OBJECT_ID('tempdb..#tmpMatches') IS NOT NULL
	BEGIN
		DROP TABLE #tmpMatches;
	END;

	CREATE TABLE	#tmpMatches (
			CustId				INT NOT NULL
		,	MatchId				INT NOT NULL
		,	EventDate			DATETIME
		,	GlobalShowTime		SMALLDATETIME	
		,	OrderedIndex		INT
	);
	
	CREATE CLUSTERED INDEX	#CIX_tmpMatches_CustIdMatchId ON #tmpMatches (
			CustId				ASC
		,	MatchId				ASC
	);

	CREATE NONCLUSTERED INDEX	#IX_tmpMatches_GlobalShowTime ON #tmpMatches (
			GlobalShowTime		ASC
	);

	CREATE NONCLUSTERED INDEX	#IX_tmpMatches_OrderedIndex ON #tmpMatches (
			OrderedIndex		ASC
	);

	IF	OBJECT_ID('tempdb..#tmpTraders') IS NOT NULL
	BEGIN
		DROP TABLE #tmpTraders;
	END;

	CREATE TABLE	#tmpTraders (
			CustId				INT NOT NULL PRIMARY KEY
	);

	IF	OBJECT_ID('tempdb..#tmpMatchesMultiple') IS NOT NULL
	BEGIN
		DROP TABLE #tmpMatchesMultiple;
	END;

	CREATE TABLE	#tmpMatchesMultiple (
			CustId				INT NOT NULL
		,	MatchGroup			INT
		,	MatchCount			TINYINT
	);

	CREATE CLUSTERED INDEX	#CIX_tmpMatchesMultiple_CustId ON #tmpMatchesMultiple (
			CustId				ASC
	);

	-- Initialize date range
	DECLARE @IsGetDataFromOrigin	BIT = 0
		,	@IsGetDataFrom14		BIT = 0
		,	@IsGetDataFromBK		BIT = 0;

	DECLARE @BalanceUpDay			SMALLDATETIME
		,	@MoveBetsDay			SMALLDATETIME;

	IF	OBJECT_ID('tempdb..#tmpDLBUMBData') IS NOT NULL
	BEGIN
		DROP TABLE	#tmpDLBUMBData
	END;

	CREATE TABLE	#tmpDLBUMBData (
			BUDay	SMALLDATETIME
		,	MBDay	SMALLDATETIME
	);
	
	-- Get MB & BU dates
	INSERT INTO #tmpDLBUMBData(BUDay,MBDay)
	EXECUTE bodb02.dbo.Age_SelBalanceUpDay;

	SELECT	TOP(1)
			@BalanceUpDay	= BUDay
		,	@MoveBetsDay	= MBDay
	FROM #tmpDLBUMBData;

	-- Compute Date range
	IF @FromDate < @BalanceUpDay
	BEGIN
		SELECT @IsGetDataFromBK = 1
	END
	ELSE IF @FromDate <= @MoveBetsDay
	BEGIN
		SELECT @IsGetDataFrom14 = 1
	END
	ELSE IF @FromDate > @MoveBetsDay
	BEGIN
		SELECT @IsGetDataFromOrigin = 1
	END;

	IF @ToDate < @BalanceUpDay
	BEGIN
		SELECT @IsGetDataFromBK = 1
	END
	ELSE IF @ToDate <= @MoveBetsDay
	BEGIN
		SELECT @IsGetDataFrom14 = 1
	END
	ELSE IF @ToDate > @MoveBetsDay
	BEGIN
		SELECT @IsGetDataFromOrigin = 1
	END;

	IF @FromDate < @BalanceUpDay AND @ToDate > @MoveBetsDay
	BEGIN
		SELECT @IsGetDataFromBK = 1
		SELECT @IsGetDataFrom14 = 1
		SELECT @IsGetDataFromOrigin = 1
	END;

	-- Get Trader-Match in range FROM-TO
	INSERT INTO #tmpMatchesInfo(CustId, MatchId, EventDate)
	SELECT DISTINCT t.[CustId]
		,	t.[MatchId]
		,	t.[EventDate]
	FROM [bodb_TGRS].[dbo].[TraderPerformance] AS t WITH(NOLOCK)
	WHERE t.CustId <> -1 
	AND t.BetType IN (1,3,7,8)
	AND t.EventDate BETWEEN @FromDate AND @ToDate
	AND t.IsLive = 1;

	IF(@IsGetDataFromOrigin = 1)
	BEGIN
		UPDATE t WITH(ROWLOCK, UPDLOCK)
		SET t.GlobalShowTime = m.GlobalShowTime
		FROM #tmpMatchesInfo AS t
		INNER JOIN bodb02.dbo.Match AS m WITH(NOLOCK) ON t.MatchId = m.matchid;
	END;

	IF(@IsGetDataFrom14 = 1)
	BEGIN
		UPDATE t WITH(ROWLOCK, UPDLOCK)
		SET t.GlobalShowTime = m.GlobalShowTime
		FROM #tmpMatchesInfo AS t
		INNER JOIN bodb02.dbo.match14 AS m WITH(NOLOCK) ON t.MatchId = m.matchid;
	END;

	IF(@IsGetDataFromBK = 1)
	BEGIN
		UPDATE t WITH(ROWLOCK, UPDLOCK)
		SET t.GlobalShowTime = m.GlobalShowTime
		FROM #tmpMatchesInfo AS t
		INNER JOIN bodb_Archive.dbo.match_bk AS m WITH(NOLOCK) ON t.MatchId = m.matchid;
	END;

	-- Get all traders have traded in the report range
	INSERT INTO #tmpTraders(CustId)
	SELECT DISTINCT t. CustId
	FROM #tmpMatchesInfo AS t WITH(NOLOCK);

	DECLARE @CurrentTrader INT;
	WHILE	EXISTS (SELECT 1 FROM #tmpTraders)
	BEGIN
		SELECT	TOP(1) @CurrentTrader = t.CustId
		FROM	#tmpTraders AS t WITH(NOLOCK);
	
		TRUNCATE TABLE #tmpMatches;

		INSERT INTO #tmpMatches(CustId, MatchId, EventDate, GlobalShowTime, OrderedIndex)
		SELECT m.CustId, m.MatchId, m.EventDate, m.GlobalShowTime, ROW_NUMBER() OVER (ORDER BY m.GlobalShowTime)
		FROM #tmpMatchesInfo AS m WITH(NOLOCK)
		WHERE m.CustId = @CurrentTrader;

		;WITH rs AS
		(
			SELECT	t1.CustId, t1.MatchId, t1.EventDate, t1.GlobalShowTime, t1.OrderedIndex
				,	1 AS MatchOrder, ROW_NUMBER() OVER (ORDER BY t1.GlobalShowTime) AS MatchGroup
			FROM #tmpMatches AS t1 WITH(NOLOCK)
				LEFT JOIN #tmpMatches AS t2 WITH(NOLOCK) ON t1.OrderedIndex - 1 = t2.OrderedIndex 
			WHERE DATEDIFF(MINUTE, t2.GlobalShowTime, t1.GlobalShowTime) > 30 OR t2.matchid IS NULL

			UNION ALL

			SELECT	t1.CustId, t1.MatchId, t1.EventDate, t1.GlobalShowTime, t1.OrderedIndex
				,	rs.MatchOrder + 1, rs.MatchGroup
			FROM rs 
				INNER JOIN #tmpMatches AS t1 WITH(NOLOCK) ON rs.OrderedIndex + 1 = t1.OrderedIndex
			WHERE DATEDIFF(MINUTE, rs.GlobalShowTime, t1.GlobalShowTime) <= 30
		)
		INSERT INTO #tmpMatchesMultiple(CustId, MatchGroup, MatchCount)
		SELECT DISTINCT CustId, MatchGroup, COUNT(1)
		FROM rs 
		GROUP BY CustId, MatchGroup;

		DELETE	t WITH(ROWLOCK)
		FROM	#tmpTraders AS t
		WHERE	t.CustId = @CurrentTrader;
	END;

	SELECT m.CustId, m.MatchCount, COUNT(1) AS MultipleTimes
	FROM #tmpMatchesMultiple AS m WITH(NOLOCK)
	GROUP BY m.CustId, m.MatchCount
	ORDER BY m.CustId DESC;
END;

GO
/*<info serverAlias="DBTGRS-bodb_TGRS" executers="bodbTGRSNet" isFunction="0" isNested="0"></info>*/