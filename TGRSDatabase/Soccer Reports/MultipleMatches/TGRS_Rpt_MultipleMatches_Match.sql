ALTER PROCEDURE [dbo].[TGRS_Rpt_MultipleMatches_Match]
		@FromDate			DATE = '20191001'
	,	@ToDate				DATE = '20191206'
	,	@CustId				INT
	,	@MatchIds			VARCHAR(MAX) = ''
	,	@Bettypes			VARCHAR(2000) = '1,3,7,8'
	,	@IsExcludeLeagues	BIT			  = 1
	,	@Market				SMALLINT	  = 1
AS    
/*  
	Created:	20191204@Long.Luu
	Task :		Multiple Matches Report - drill down to Match
	DB:			DBTGRS.bodb_TGRS
	Original:  
  
	Revisions: 	
   		- 20191204@Long.Luu:	Created [Remine Id: 118960]

	Param's Explanation:  	

	Exam:   
*/  
 
BEGIN 
	SET NOCOUNT ON;
	
	DECLARE	@BettypeList TABLE (
			BetType			SMALLINT PRIMARY KEY
	);

	IF	OBJECT_ID('tempdb..#tmpMatchesInfo') IS NOT NULL
	BEGIN
		DROP TABLE #tmpMatchesInfo;
	END;

	CREATE TABLE	#tmpMatchesInfo (
			MatchId				INT NOT NULL PRIMARY KEY
		,	MatchGroup			INT
	);

	IF	OBJECT_ID('tempdb..#tmpMatches') IS NOT NULL
	BEGIN
		DROP TABLE #tmpMatches;
	END;

	CREATE TABLE	#tmpMatches (
			MatchId				INT NOT NULL PRIMARY KEY
		,	EventDate			DATETIME
		,	GlobalShowTime		SMALLDATETIME
		,	MatchGroup			INT
		,	HomeId				INT
		,	AwayId				INT
		,	LeagueName			NVARCHAR(500)
		,	Turnover			MONEY
		,	WinLoss				MONEY
		,	BetCount			INT
		,	Margin				MONEY
	);

	CREATE NONCLUSTERED INDEX	#IX_tmpMatches_GlobalShowTime ON #tmpMatches (
			GlobalShowTime		ASC
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

	IF	@Bettypes <> ''
		 INSERT INTO @BettypeList (Bettype)
		 SELECT ssk.val FROM dbo.strSplit_Key(@Bettypes, ',') ssk;
	ELSE 
		 INSERT INTO @BettypeList (bettype)
		 SELECT bt.BetType FROM	dbo.BetType AS bt WITH (NOLOCK) WHERE bt.BetType IN (1,3,7,8);
	
	INSERT INTO #tmpMatchesInfo(MatchId, MatchGroup)
	SELECT s2.val, s1.rank
	FROM dbo.strSplit_Key(@MatchIds, '#') s1
	CROSS APPLY dbo.strSplit_Key(s1.val, ',') s2;

	-- Get Trader-Match in range
	INSERT INTO #tmpMatches(MatchId, EventDate, LeagueName, MatchGroup, Turnover, WinLoss, BetCount, Margin)
	SELECT	tp.MatchId
		,	tp.EventDate
		,	l.leaguename
		,	m.MatchGroup
		,	ISNULL(SUM(tp.Stake), 0)								AS Turnover
		,	ISNULL(SUM(tp.WinLost), 0) - ISNULL(SUM(tp.Comm), 0)	AS WinLoss
		,	ISNULL(SUM(tp.BetCount), 0)								AS BetCount
		,	(ISNULL(SUM(tp.WinLost), 0) - ISNULL(SUM(tp.Comm), 0)) * 100 / ISNULL(SUM(tp.Stake), 0) AS Margin
	FROM dbo.TraderPerformance AS tp WITH(NOLOCK)
		INNER JOIN #tmpMatchesInfo AS m WITH(NOLOCK) ON tp.MatchId = m.MatchId
		INNER JOIN bodb02.dbo.league AS l WITH(NOLOCK) ON tp.LeagueId = l.leagueid
		LEFT JOIN dbo.LeagueExclusion le WITH(NOLOCK) ON tp.LeagueId = le.LeagueId
		INNER JOIN @BettypeList AS b ON b.Bettype = tp.BetType
	WHERE tp.EventDate BETWEEN @FromDate AND @ToDate
		AND tp.CustId = @CustId
		AND (@IsExcludeLeagues = 0 OR le.LeagueId IS NULL)
		AND (@Market = -1 OR tp.IsLive = @Market)
	GROUP BY tp.MatchId
		,	tp.EventDate
		,	l.leaguename
		,	m.MatchGroup;

	IF(@IsGetDataFromOrigin = 1)
	BEGIN
		UPDATE t WITH(ROWLOCK, UPDLOCK)
		SET t.GlobalShowTime = m.GlobalShowTime
			,	t.HomeId = m.homeid
			,	t.AwayId = m.awayid
		FROM #tmpMatches AS t
			INNER JOIN bodb02.dbo.Match AS m WITH(NOLOCK) ON t.MatchId = m.matchid;
	END;

	IF(@IsGetDataFrom14 = 1)
	BEGIN
		UPDATE t WITH(ROWLOCK, UPDLOCK)
		SET t.GlobalShowTime = m.GlobalShowTime
			,	t.HomeId = m.homeid
			,	t.AwayId = m.awayid
		FROM #tmpMatches AS t
			INNER JOIN bodb02.dbo.match14 AS m WITH(NOLOCK) ON t.MatchId = m.matchid;
	END;

	IF(@IsGetDataFromBK = 1)
	BEGIN
		UPDATE t WITH(ROWLOCK, UPDLOCK)
		SET t.GlobalShowTime = m.GlobalShowTime
			,	t.HomeId = m.homeid
			,	t.AwayId = m.awayid
		FROM #tmpMatches AS t
			INNER JOIN bodb_Archive.dbo.match_bk AS m WITH(NOLOCK) ON t.MatchId = m.matchid;
	END;
	
	-- Return data
	SELECT	m.MatchId
		,	m.EventDate
		,	m.GlobalShowTime
		,	m.HomeId
		,	m.AwayId
		,	m.MatchGroup
		,	m.LeagueName
		,	m.Turnover
		,	m.WinLoss
		,	m.BetCount
		,	m.Margin
	FROM #tmpMatches AS m WITH(NOLOCK);
END;

GO
/*<info serverAlias="DBTGRS-bodb_TGRS" executers="bodbTGRSNet" isFunction="0" isNested="0"></info>*/