ALTER PROCEDURE [dbo].[TGRS_OS_Rpt_TraderPerformance_MatchDetails]
		@TraderId			INT
	,	@LeagueId			INT
	,	@FromDate			DATE	 = '2021-02-01'
	,	@ToDate				DATE	 = '2021-01-01'
	,	@SportId			INT	 	 = - 1
	,	@LiveType			SMALLINT = 1
AS
/*
	Created: 20180713@Long
	Task : Get OS Trader Performance - Match Details
	DB:  DBTGRS.bodb_TGRS
	Original:

	Revisions:
		- 20181030@Long: Adding Betcount column to OS's reports [Redmine ID: #101741]
		- 20200914@John.Ngo: Support Live/Nonlive for OSDataTGRS [Redmine ID: #140875]
		- 20210226@John.Ngo: Integrate Cricket AIO [Redmine ID: #150856]

	Params Explaination:
		- @LiveType: -1 All; 0 Nonlive; 1 Live
*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @IncrementTimes			DECIMAL(18, 2)
		,	@IncrementValue			DECIMAL(18, 2)
		,	@FloorMark				DECIMAL(18, 2);

	SELECT @IncrementTimes = ParamValue
	FROM dbo.[OSParameter] WITH (NOLOCK)
	WHERE ParamId = 3;

	SELECT @IncrementValue = ParamValue
	FROM dbo.[OSParameter] WITH (NOLOCK)
	WHERE ParamId = 5;

	SELECT @FloorMark = ParamValue
	FROM dbo.[OSParameter] WITH (NOLOCK)
	WHERE ParamId = 7;
	
	DECLARE @BalanceUpDay			SMALLDATETIME
		,	@MoveBetsDay			SMALLDATETIME;

	IF	OBJECT_ID('tempdb..#BUMBData') IS NOT NULL
	BEGIN;
		DROP TABLE	#BUMBData;
	END;

	CREATE TABLE	#BUMBData (
			BUDay	SMALLDATETIME
		,	MBDay	SMALLDATETIME
	);

	INSERT INTO #BUMBData(BUDay,MBDay)
	EXECUTE bodb02.dbo.Age_SelBalanceUpDay;

	SELECT	TOP(1)
			@BalanceUpDay	= BUDay
		,	@MoveBetsDay	= MBDay
	FROM #BUMBData WITH(NOLOCK);

	IF @SportId IS NULL
	BEGIN
		SET @SportId = - 1;
	END;

	IF OBJECT_ID('tempdb..#tmpTraderPerformanceDetail') IS NOT NULL
	BEGIN
		DROP TABLE #tmpTraderPerformanceDetail;
	END

	CREATE TABLE #tmpTraderPerformanceDetail (
			LeagueId			INT
		,	MatchId				INT
		,	EventDate			DATETIME
		,	Turnover			MONEY
		,	WinLoss				MONEY
		,	EventProductCount	INT
		,	Target				DECIMAL(18,4)
		,	BetCount			BIGINT
	);
	CREATE CLUSTERED INDEX	#CIX_tmpTraderPerformanceDetailIdx ON #tmpTraderPerformanceDetail (
			LeagueId			ASC
		,	MatchId				ASC
		,	EventDate			ASC
	);

	IF OBJECT_ID('tempdb..#tmpTraderPerformanceDetailByBettype') IS NOT NULL
	BEGIN
		DROP TABLE #tmpTraderPerformanceDetailByBettype;
	END

	CREATE TABLE #tmpTraderPerformanceDetailByBettype (
			TraderId			INT
		,	SportId				INT
		,	BettypeId			INT
		,	Turnover			MONEY
		,	WinLoss				MONEY
		,	Point				MONEY
		,	EventProductCount	INT
		,	BetCount			BIGINT
	);

	CREATE CLUSTERED INDEX	#CIX_tmpTraderPerformanceDetailByBettypeIdx ON #tmpTraderPerformanceDetailByBettype (
			TraderId			ASC
		,	SportId				ASC
	);

	IF OBJECT_ID('tempdb..#tmpFinalResults') IS NOT NULL
	BEGIN
		DROP TABLE #tmpFinalResults;
	END

	CREATE TABLE #tmpFinalResults (
			LeagueId			INT
		,	MatchId				INT
		,	EventDate			DATETIME
		,	HomeId				INT
		,	AwayId				INT
		,	ParentID			INT
		,	ChildMatchType		TINYINT
		,	Margin				MONEY
		,	Turnover			MONEY
		,	WinLoss				MONEY
		,	Point				MONEY
		,	EventProductCount	INT
		,	BetCount			BIGINT
	);

	-- Initialize date range
	DECLARE @IsGetDataFromOrigin	BIT = 0
		,	@IsGetDataFrom14		BIT = 0
		,	@IsGetDataFromBK		BIT = 0;

	DECLARE @FromDateOrigin			SMALLDATETIME = NULL
		,	@ToDateOrigin			SMALLDATETIME = NULL
		,	@FromDate14				SMALLDATETIME = NULL
		,	@ToDate14				SMALLDATETIME = NULL
		,	@FromDateBK				SMALLDATETIME = NULL
		,	@ToDateBK				SMALLDATETIME = NULL;

	-- Return immediately if wrong date range
	IF @ToDate < @FromDate
	BEGIN
		RAISERROR('ToDate < FromDate: Unacceptable!', 0, 0) WITH NOWAIT;
		RETURN;
	END;

	IF @FromDate < @BalanceUpDay
	BEGIN
		SELECT @IsGetDataFromBK = 1;
	END
	ELSE IF @FromDate <= @MoveBetsDay
	BEGIN
		SELECT @IsGetDataFrom14 = 1;
	END
	ELSE IF @FromDate > @MoveBetsDay
	BEGIN
		SELECT @IsGetDataFromOrigin = 1;
	END;

	IF @ToDate < @BalanceUpDay
	BEGIN
		SELECT @IsGetDataFromBK = 1;
	END
	ELSE IF @ToDate <= @MoveBetsDay
	BEGIN
		SELECT @IsGetDataFrom14 = 1;
	END
	ELSE IF @ToDate > @MoveBetsDay
	BEGIN
		SELECT @IsGetDataFromOrigin = 1;
	END;

	IF @FromDate < @BalanceUpDay AND @ToDate > @MoveBetsDay
	BEGIN
		SELECT @IsGetDataFromBK = 1;
		SELECT @IsGetDataFrom14 = 1;
		SELECT @IsGetDataFromOrigin = 1;
	END;

	IF @IsGetDataFromBK = 1 AND @IsGetDataFromOrigin = 1
	BEGIN
		SELECT	@FromDateOrigin = @MoveBetsDay + 1
				,	@ToDateOrigin = @ToDate
				,	@FromDate14 = @BalanceUpDay
				,	@ToDate14 = @MoveBetsDay
				,	@FromDateBK = @FromDate 
				,	@ToDateBK = @BalanceUpDay - 1;
	END;

	IF @IsGetDataFromBK = 1 AND @IsGetDataFrom14 = 1 AND @IsGetDataFromOrigin = 0
	BEGIN
		SELECT	@FromDate14 = @BalanceUpDay
				,	@ToDate14 = @ToDate
				,	@FromDateBK = @FromDate 
				,	@ToDateBK = @BalanceUpDay - 1;
	END;

	IF @IsGetDataFromBK = 0 AND @IsGetDataFrom14 = 1 AND @IsGetDataFromOrigin = 1
	BEGIN
		SELECT	@FromDateOrigin = @MoveBetsDay + 1
				,	@ToDateOrigin = @ToDate
				,	@FromDate14 = @FromDate
				,	@ToDate14 = @MoveBetsDay;
	END;

	IF @IsGetDataFromBK = 1 AND @IsGetDataFrom14 = 0 AND @IsGetDataFromOrigin = 0
	BEGIN
		SELECT	@FromDateBK = @FromDate 
				,	@ToDateBK = @ToDate;
	END;

	IF @IsGetDataFromBK = 0 AND @IsGetDataFrom14 = 1 AND @IsGetDataFromOrigin = 0
	BEGIN
		SELECT	@FromDate14 = @FromDate
				,	@ToDate14 = @ToDate;
	END;

	IF @IsGetDataFromBK = 0 AND @IsGetDataFrom14 = 0 AND @IsGetDataFromOrigin = 1
	BEGIN
		SELECT	@FromDateOrigin = @FromDate
				,	@ToDateOrigin = @ToDate;
	END;

	IF @IsGetDataFromBK = 1 AND @IsGetDataFrom14 = 1 AND @IsGetDataFromOrigin = 1
	BEGIN
		SELECT	@FromDateOrigin = @MoveBetsDay + 1
				,	@ToDateOrigin = @ToDate
				,	@FromDate14 = @BalanceUpDay
				,	@ToDate14 = @MoveBetsDay
				,	@FromDateBK = @FromDate 
				,	@ToDateBK = @BalanceUpDay - 1;
	END;

	-- START --
	INSERT INTO #tmpTraderPerformanceDetail (
			LeagueId
		,	MatchId
		,	EventDate
		,	Turnover
		,	WinLoss
		,	EventProductCount
		,	Target
		,	BetCount
	)
	SELECT	tp.LeagueId
		,	tp.MatchId
		,	tp.EventDate
		,	SUM(tp.Turnover) AS Turnover
		,	SUM(tp.Winloss - tp.Comm) AS Winloss
		,	COUNT(DISTINCT tp.BettypeId) AS EventProductCount
		,	tp.Target
		,	SUM(tp.BetCount)
	FROM dbo.OSDataTGRS tp WITH (NOLOCK)
		JOIN dbo.OSTrader t WITH (NOLOCK) ON t.TraderId = tp.TraderId
	WHERE tp.EventDate BETWEEN @FromDate AND @ToDate
		AND tp.TraderId = @TraderId
		AND (tp.SportId = @SportId OR @SportId = - 1)
		AND tp.LeagueId = @LeagueId
		AND (@LiveType = -1 OR tp.IsLive = @LiveType)
	GROUP BY tp.LeagueId
		,	tp.MatchId
		,	tp.EventDate
		,	tp.Target;

	IF @IsGetDataFromBK = 1
	BEGIN
		INSERT INTO #tmpFinalResults (
				LeagueId
			,	MatchId
			,	EventDate
			,	HomeId
			,	AwayId
			,	ParentID
			,	ChildMatchType
			,	Margin
			,	Turnover
			,	WinLoss
			,	Point
			,	EventProductCount
			,	BetCount
		)
		SELECT	tp.LeagueId
			,	tp.MatchId
			,	tp.EventDate
			,	m.homeid AS HomeId
			,	m.awayid AS AwayId
			,	m.ParentID
			,	200 --m.ChildMatchType
			,	(SUM(tp.WinLoss) * 100 / SUM(tp.Turnover)) AS Margin
			,	tp.Turnover
			,	tp.Winloss
			,	tp.Turnover * 100 / SUM(tp.Turnover) OVER (PARTITION BY tp.LeagueId, tp.MatchId)
				* (@FloorMark / 100 + (
					(
						CASE 
							WHEN FLOOR(((tp.Winloss * 100 / tp.Turnover) - tp.Target) / @IncrementValue) >= @IncrementTimes
								THEN @IncrementTimes
							WHEN FLOOR(((tp.Winloss * 100 / tp.Turnover) - tp.Target) / @IncrementValue) <= - @IncrementTimes
								THEN - @IncrementTimes
							ELSE FLOOR(((tp.Winloss * 100 / tp.Turnover) - tp.Target) / @IncrementValue)
							END
						) + 1
					) / @IncrementTimes
				) AS Point
			,	tp.EventProductCount
			,	SUM(tp.BetCount)
		FROM #tmpTraderPerformanceDetail tp WITH (NOLOCK)
			INNER JOIN DBARC.bodb_Archive.dbo.Match_bk AS m WITH(NOLOCK) ON tp.MatchId = m.matchid
			WHERE m.eventdate BETWEEN @FromDateBK AND @ToDateBK
		GROUP BY tp.LeagueId
			,	tp.MatchId
			,	tp.EventDate
			,	m.homeid
			,	m.awayid
			,	m.ParentID
			--,	m.ChildMatchType
			,	tp.Turnover		
			,	tp.Winloss
			,	tp.EventProductCount
			,	tp.Target;
	END;

	IF	@IsGetDataFrom14 = 1
	BEGIN
		INSERT INTO #tmpFinalResults (
				LeagueId
			,	MatchId
			,	EventDate
			,	HomeId
			,	AwayId
			,	ParentID
			,	ChildMatchType
			,	Margin
			,	Turnover
			,	WinLoss
			,	Point
			,	EventProductCount
			,	BetCount
		)
		SELECT	tp.LeagueId
			,	tp.MatchId
			,	tp.EventDate
			,	m.homeid AS HomeId
			,	m.awayid AS AwayId
			,	m.ParentID
			,	m.ChildMatchType
			,	(SUM(tp.WinLoss) * 100 / SUM(tp.Turnover)) AS Margin
			,	tp.Turnover
			,	tp.Winloss
			,	tp.Turnover * 100 / SUM(tp.Turnover) OVER (PARTITION BY tp.LeagueId, tp.MatchId)
				* (@FloorMark / 100 + (
					(
						CASE 
							WHEN FLOOR(((tp.Winloss * 100 / tp.Turnover) - tp.Target) / @IncrementValue) >= @IncrementTimes
								THEN @IncrementTimes
							WHEN FLOOR(((tp.Winloss * 100 / tp.Turnover) - tp.Target) / @IncrementValue) <= - @IncrementTimes
								THEN - @IncrementTimes
							ELSE FLOOR(((tp.Winloss * 100 / tp.Turnover) - tp.Target) / @IncrementValue)
							END
						) + 1
					) / @IncrementTimes
				) AS Point
			,	tp.EventProductCount
			,	SUM(tp.BetCount)
		FROM #tmpTraderPerformanceDetail tp WITH (NOLOCK)
			INNER JOIN bodb02.dbo.Match14 AS m WITH(NOLOCK) ON tp.MatchId = m.matchid
			WHERE m.eventdate BETWEEN @FromDate14 AND @ToDate14
		GROUP BY tp.LeagueId
			,	tp.MatchId
			,	tp.EventDate
			,	m.homeid
			,	m.awayid			
			,	m.ParentID
			,	m.ChildMatchType
			,	tp.Turnover		
			,	tp.Winloss
			,	tp.EventProductCount
			,	tp.Target;
	END;

	IF	@IsGetDataFromOrigin = 1
	BEGIN
		INSERT INTO #tmpFinalResults (
				LeagueId
			,	MatchId
			,	EventDate
			,	HomeId
			,	AwayId
			,	ParentID
			,	ChildMatchType
			,	Margin
			,	Turnover
			,	WinLoss
			,	Point
			,	EventProductCount
			,	BetCount
		)
		SELECT	tp.LeagueId
			,	tp.MatchId
			,	tp.EventDate
			,	m.homeid AS HomeId
			,	m.awayid AS AwayId
			,	m.ParentID
			,	m.ChildMatchType
			,	(SUM(tp.WinLoss) * 100 / SUM(tp.Turnover)) AS Margin
			,	tp.Turnover
			,	tp.Winloss
			,	tp.Turnover * 100 / SUM(tp.Turnover) OVER (PARTITION BY tp.LeagueId, tp.MatchId)
				* (@FloorMark / 100 + (
					(
						CASE 
							WHEN FLOOR(((tp.Winloss * 100 / tp.Turnover) - tp.Target) / @IncrementValue) >= @IncrementTimes
								THEN @IncrementTimes
							WHEN FLOOR(((tp.Winloss * 100 / tp.Turnover) - tp.Target) / @IncrementValue) <= - @IncrementTimes
								THEN - @IncrementTimes
							ELSE FLOOR(((tp.Winloss * 100 / tp.Turnover) - tp.Target) / @IncrementValue)
							END
						) + 1
					) / @IncrementTimes
				) AS Point
			,	tp.EventProductCount
			,	SUM(tp.BetCount)
		FROM #tmpTraderPerformanceDetail tp WITH (NOLOCK)
			INNER JOIN bodb02.dbo.match m WITH(NOLOCK) ON tp.MatchId = m.matchid
			WHERE m.eventdate BETWEEN @FromDateOrigin AND @ToDateOrigin
		GROUP BY tp.LeagueId
			,	tp.MatchId
			,	tp.EventDate
			,	m.homeid
			,	m.awayid
			,	m.ParentID
			,	m.ChildMatchType
			,	tp.Turnover		
			,	tp.Winloss
			,	tp.EventProductCount
			,	tp.Target;
		IF @SportId = 50 -- Cricket (Main match is running)
			BEGIN
				IF	OBJECT_ID('tempdb..#tmpOrgMatches') IS NOT NULL
				BEGIN
					DROP TABLE #tmpOrgMatches;
				END;

				CREATE TABLE	#tmpOrgMatches (
						MatchId				INT NOT NULL PRIMARY KEY
				);

				INSERT INTO #tmpOrgMatches (MatchId)
				SELECT DISTINCT fn.ParentID FROM #tmpFinalResults fn WITH (NOLOCK) 
				WHERE fn.eventdate BETWEEN @FromDateOrigin AND @ToDateOrigin
					AND fn.ChildMatchType = 200;

				INSERT INTO #tmpFinalResults (
						LeagueId
					,	MatchId
					,	EventDate
					,	HomeId
					,	AwayId
					,	ParentID
					,	ChildMatchType
					,	Margin
					,	Turnover
					,	WinLoss
					,	Point
					,	EventProductCount
					,	BetCount
				)
				SELECT	m.LeagueId
					,	m.MatchId
					,	m.EventDate
					,	m.homeid AS HomeId
					,	m.awayid AS AwayId
					,	m.ParentID
					,	m.ChildMatchType
					,	0 AS Margin
					,	0 AS Turnover
					,	0 AS Winloss
					,	0 AS Point
					,	0 AS EventProductCount
					,	0 AS BetCount
				FROM #tmpOrgMatches om WITH (NOLOCK)
					INNER JOIN bodb02.dbo.match m WITH(NOLOCK) ON om.MatchId = m.matchid
					LEFT JOIN #tmpFinalResults fn WITH(NOLOCK) ON om.MatchId = fn.matchid
				WHERE m.eventdate BETWEEN @FromDateOrigin AND @ToDateOrigin
					AND fn.MatchId IS NULL;

			END;
	
	END;

	SELECT	LeagueId
		,	MatchId
		,	EventDate
		,	HomeId
		,	AwayId
		,	ParentID
		,	ChildMatchType
		,	Margin
		,	Turnover
		,	WinLoss
		,	Point
		,	EventProductCount
		,	BetCount
	FROM #tmpFinalResults WITH(NOLOCK);

	DROP TABLE #tmpTraderPerformanceDetail;
	DROP TABLE #tmpFinalResults;

END;

GO
/*<info serverAlias="DBTGRS-bodb_TGRS" executers="bodbTGRSNet" isFunction="0" isNested="0"></info>*/