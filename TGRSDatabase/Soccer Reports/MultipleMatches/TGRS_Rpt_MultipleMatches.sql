ALTER PROCEDURE [dbo].[TGRS_Rpt_MultipleMatches]
		@FromDate			DATE = '20191001'
	,	@ToDate				DATE = '20191206'
	,	@GradeIds			VARCHAR(200)  = '' -- All
	,	@TeamIds			VARCHAR(200)  = '' -- All
	,	@Bettypes			VARCHAR(2000) = '1,3,7,8'
	,	@MultipleMatches	VARCHAR(200)  = '' -- All
	,	@IsExcludeLeagues	BIT			  = 1
	,	@Market				SMALLINT	  = 1
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

	DECLARE	@GradeList TABLE (
			Grade			TINYINT PRIMARY KEY
	);

	DECLARE	@TeamList TABLE (
			TeamId			SMALLINT PRIMARY KEY
	);

	DECLARE	@BettypeList TABLE (
			BetType			SMALLINT PRIMARY KEY
	);

	DECLARE	@MultipleMatchesList TABLE (
			MultipleMatchesId TINYINT PRIMARY KEY
	);

	IF	OBJECT_ID('tempdb..#tmpMatchesInfo') IS NOT NULL
	BEGIN
		DROP TABLE #tmpMatchesInfo;
	END;

	CREATE TABLE	#tmpMatchesInfo (
			CustId				INT NOT NULL
		,	MatchId				INT NOT NULL
		,	EventDate			DATETIME
		,	Turnover			MONEY
		,	WinLoss				MONEY
		,	BetCount			INT
		,	Margin				MONEY
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
		,	Username			VARCHAR(50)
		,	Grade				TINYINT
		,	TeamId				SMALLINT
		,	MatchGroup			INT
		,	MultipleMatchCount	TINYINT
		,   MatchList			VARCHAR(MAX)
		,	Turnover			MONEY
		,	WinLoss				MONEY
		,	BetCount			INT
	);

	CREATE CLUSTERED INDEX	#CIX_tmpMatchesMultiple_CustId ON #tmpMatchesMultiple (
			CustId				ASC
	);

	CREATE NONCLUSTERED INDEX	#CIX_tmpMatchesMultiple_Grade ON #tmpMatchesMultiple (
			Grade				ASC
	);
	
	IF	OBJECT_ID('tempdb..#tmpMatchesInfoMultiple') IS NOT NULL
	BEGIN
		DROP TABLE #tmpMatchesInfoMultiple;
	END;

	CREATE TABLE	#tmpMatchesInfoMultiple (
			CustId				INT NOT NULL
		,	MatchGroup			INT
		,	MatchId				INT NOT NULL
		,	GlobalShowTime		SMALLDATETIME
	);

	CREATE CLUSTERED INDEX	#CIX_#tmpMatchesInfoMultiple_CustId ON #tmpMatchesInfoMultiple (
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

	IF	@GradeIds <> ''
		 INSERT INTO @GradeList (Grade)
		 SELECT ssk.val FROM dbo.strSplit_Key(@GradeIds, ',') ssk;
	ELSE
		 INSERT INTO @GradeList (Grade)
		 SELECT DISTINCT t.Grade FROM dbo.Trader AS t WITH (NOLOCK);

	IF	@TeamIds <> ''
		 INSERT INTO @TeamList (TeamId)
		 SELECT ssk.val FROM dbo.strSplit_Key(@TeamIds, ',') ssk;
	ELSE 
		 INSERT INTO @TeamList (TeamId)
		 SELECT	t.TeamId FROM dbo.Team AS t WITH (NOLOCK);

	IF	@Bettypes <> ''
		 INSERT INTO @BettypeList (Bettype)
		 SELECT ssk.val FROM dbo.strSplit_Key(@Bettypes, ',') ssk;
	ELSE 
		 INSERT INTO @BettypeList (bettype)
		 SELECT bt.BetType FROM	dbo.BetType AS bt WITH (NOLOCK) WHERE bt.BetType IN (1,3,7,8);

	IF	@MultipleMatches <> ''
		 INSERT INTO @MultipleMatchesList (MultipleMatchesId)
		 SELECT ssk.val FROM dbo.strSplit_Key(@MultipleMatches, ',') ssk;

	-- Get Trader-Match in range
	INSERT INTO #tmpMatchesInfo(CustId, MatchId, EventDate, Turnover, WinLoss, BetCount)
	SELECT DISTINCT tp.CustId
		,	tp.MatchId
		,	tp.EventDate
		,	ISNULL(SUM(tp.Stake), 0)								AS Turnover
		,	ISNULL(SUM(tp.WinLost), 0) - ISNULL(SUM(tp.Comm), 0)	AS WinLoss
		,	ISNULL(SUM(tp.BetCount), 0)								AS BetCount
	FROM dbo.TraderPerformance AS tp WITH(NOLOCK)
		INNER JOIN bodb02.dbo.League AS l WITH(NOLOCK) ON tp.LeagueId = l.LeagueId
		LEFT JOIN dbo.LeagueExclusion le WITH(NOLOCK) ON tp.LeagueId = le.LeagueId
		INNER JOIN @BettypeList AS b ON b.Bettype = tp.BetType
	WHERE tp.EventDate BETWEEN @FromDate AND @ToDate
		AND (@IsExcludeLeagues = 0 OR le.LeagueId IS NULL)
		AND (@Market = -1 OR tp.IsLive = @Market)
		AND tp.CustId <> 0
	GROUP BY tp.CustId
		,	tp.MatchId
		,	tp.EventDate;

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

	-- Traverse through all traders, making recurive for each
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
		INSERT INTO #tmpMatchesInfoMultiple(CustId, MatchGroup, MatchId, GlobalShowTime)
		SELECT CustId, MatchGroup, MatchId, GlobalShowTime
		FROM rs;

		DELETE	t WITH(ROWLOCK)
		FROM	#tmpTraders AS t
		WHERE	t.CustId = @CurrentTrader;
	END;

	INSERT INTO #tmpMatchesMultiple(CustId, Username, Grade, TeamId, MatchGroup, MultipleMatchCount, MatchList, Turnover, WinLoss, BetCount)
	SELECT mm1.CustId, t.Username, t.Grade, t.TeamId, mm1.MatchGroup
		,	COUNT (1) AS MultipleMatchCount
		,	STUFF((SELECT ',', CONVERT(VARCHAR(MAX), mm2.MatchId) 
									FROM #tmpMatchesInfoMultiple mm2 WITH (NOLOCK)
									WHERE mm1.CustId = mm2.CustId AND mm1.MatchGroup = mm2.MatchGroup
									FOR XML PATH('')), 1, 1, '')	
		,	SUM(mi.Turnover)							AS Turnover
		,	SUM(mi.WinLoss)								AS WinLoss
		,	SUM(mi.BetCount)							AS BetCount										
	FROM #tmpMatchesInfoMultiple mm1 WITH (NOLOCK) 
		INNER JOIN #tmpMatchesInfo mi WITH (NOLOCK) ON mm1.CustId = mi.CustId AND mm1.MatchId = mi.MatchId
		INNER JOIN dbo.Trader AS t WITH(NOLOCK) ON mm1.CustId = t.CustId
	WHERE (@GradeIds = '' OR t.Grade IN (SELECT Grade FROM @GradeList))
		AND (@TeamIds = '' OR t.TeamId IN (SELECT TeamId FROM @TeamList))
	GROUP BY mm1.CustId, t.Username, t.Grade, t.TeamId, mm1.MatchGroup;
	
	SELECT	m.CustId
		,	m.Username
		,	m.Grade
		,	t.TeamName
		,	m.MultipleMatchCount AS MultipleMatches
		,	COUNT(1) AS MultipleTimes
		,	STUFF((SELECT '#', CONVERT(VARCHAR(MAX), m2.MatchList) 
									FROM #tmpMatchesMultiple m2 WITH (NOLOCK)
									WHERE m.CustId = m2.CustId AND m.MultipleMatchCount = m2.MultipleMatchCount
									FOR XML PATH('')), 1, 1, '') AS MatchList
		,	SUM(m.Turnover) AS Turnover
		,	SUM(m.WinLoss) AS Winloss
		,	SUM(m.BetCount) AS BetCount
		,	SUM(m.WinLoss) * 100 / SUM(m.Turnover) AS Margin
	FROM #tmpMatchesMultiple AS m WITH(NOLOCK)
		INNER JOIN dbo.Team AS t WITH(NOLOCK) ON m.TeamId = t.TeamId
	WHERE (@MultipleMatches = '' OR m.MultipleMatchCount IN (SELECT MultipleMatchesId FROM @MultipleMatchesList))
	GROUP BY m.CustId, m.Username, m.Grade, t.TeamName, m.MultipleMatchCount
	ORDER BY m.Username, m.MultipleMatchCount ASC;
END;

GO
/*<info serverAlias="DBTGRS-bodb_TGRS" executers="bodbTGRSNet" isFunction="0" isNested="0"></info>*/