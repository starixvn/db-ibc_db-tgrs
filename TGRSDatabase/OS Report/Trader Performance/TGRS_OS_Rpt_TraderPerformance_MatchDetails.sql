
SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

ALTER PROCEDURE [dbo].[TGRS_OS_Rpt_TraderPerformance_MatchDetails]
		@TraderId			INT
	,	@FromDate			DATE = '2016-01-01'
	,	@ToDate				DATE = '2017-12-31'
	,	@SportId			INT = - 1
AS
/*
	Created: 20180713@Long
	Task : Get OS Trader Performance - Match Details
	DB:  DBTGRS.bodb_TGRS

	Revisions:

	Params Explaination:
*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @IncrementTimes			DECIMAL(18, 2)
		,	@IncrementValue			DECIMAL(18, 2)
		,	@FloorMark				DECIMAL(18, 2);

	SELECT @IncrementTimes = ParamValue
	FROM [bodb_TGRS].[dbo].[OSParameter] WITH (NOLOCK)
	WHERE ParamId = 3;

	SELECT @IncrementValue = ParamValue
	FROM [bodb_TGRS].[dbo].[OSParameter] WITH (NOLOCK)
	WHERE ParamId = 5;

	SELECT @FloorMark = ParamValue
	FROM [bodb_TGRS].[dbo].[OSParameter] WITH (NOLOCK)
	WHERE ParamId = 7;

	IF @SportId IS NULL
	BEGIN
		SET @SportId = - 1;
	END;

	IF OBJECT_ID('tempdb..#tmpTraderPerformanceDetail') IS NOT NULL
	BEGIN
		DROP TABLE #tmpTraderPerformanceDetail
	END

	CREATE TABLE #tmpTraderPerformanceDetail (
			LeagueId			INT
		,	MatchId				INT
		,	EventDate			DATETIME
		,	Turnover			MONEY
		,	WinLoss				MONEY
		,	EventProductCount	INT
		,	Target				DECIMAL(18,4)
	);
	CREATE CLUSTERED INDEX	#CIX_tmpTraderPerformanceDetailIdx ON #tmpTraderPerformanceDetail (
			LeagueId			ASC
		,	MatchId				ASC
		,	EventDate			ASC
	);

	IF OBJECT_ID('tempdb..#tmpTraderPerformanceDetailByBettype') IS NOT NULL
	BEGIN
		DROP TABLE #tmpTraderPerformanceDetailByBettype
	END

	CREATE TABLE #tmpTraderPerformanceDetailByBettype (
			TraderId			INT
		,	SportId				INT
		,	BettypeId			INT
		,	Turnover			MONEY
		,	WinLoss				MONEY
		,	Point				MONEY
		,	EventProductCount	INT
	);

	CREATE CLUSTERED INDEX	#CIX_tmpTraderPerformanceDetailByBettypeIdx ON #tmpTraderPerformanceDetailByBettype (
			TraderId			ASC
		,	SportId				ASC
	);
	
	-- START --
	INSERT INTO #tmpTraderPerformanceDetail (
			LeagueId
		,	MatchId
		,	EventDate
		,	Turnover
		,	WinLoss
		,	EventProductCount
		,	Target
	)
	SELECT	tp.LeagueId
		,	tp.MatchId
		,	tp.EventDate
		,	SUM(tp.Turnover) AS Turnover
		,	SUM(tp.Winloss - tp.Comm) AS Winloss
		,	COUNT(DISTINCT tp.BettypeId) AS EventProductCount
		,	tp.Target
	FROM dbo.OSDataTGRS tp WITH (NOLOCK)
		JOIN dbo.OSTrader t WITH (NOLOCK) ON t.TraderId = tp.TraderId
	WHERE tp.EventDate BETWEEN @FromDate AND @ToDate
		AND tp.TraderId = @TraderId
		AND (
			tp.SportId = @SportId
			OR @SportId = - 1
		)
	GROUP BY tp.LeagueId
		,	tp.MatchId
		,	tp.EventDate
		,	tp.Target;

	/*INSERT INTO #tmpTraderPerformanceDetailByBettype (
			TraderId
		,	SportId
		,	BettypeId
		,	Turnover
		,	WinLoss
		,	Point
		,	EventProductCount
	)*/
	SELECT	tp.LeagueId
		,	tp.MatchId
		,	tp.EventDate
		,	m.homeid AS HomeId
		,	m.awayid AS AwayId
		,	(SUM(tp.WinLoss) * 100 / SUM(tp.Turnover)) AS Margin
		,	tp.Turnover
		,	tp.Winloss
		,	tp.Turnover * 100 / SUM(tp.Turnover) OVER (
			PARTITION BY tp.LeagueId
				,tp.MatchId
			) * (
			@FloorMark / 100 + (
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
	FROM #tmpTraderPerformanceDetail tp WITH (NOLOCK)
		INNER JOIN bodb02.dbo.match m WITH(NOLOCK) ON tp.MatchId = m.matchid
	GROUP BY tp.LeagueId
		,	tp.MatchId
		,	tp.EventDate
		,	m.homeid
		,	m.awayid
		,	tp.Turnover		
		,	tp.Winloss
		,	tp.EventProductCount
		,	tp.Target;
	
	DROP TABLE #tmpTraderPerformanceDetail;
END

/* 
GO 
 GRANT EXECUTE ON [dbo].[TGRS_OS_Rpt_TraderPerformance_MatchDetails] TO [bodbTGRSNet]
GO 
 GRANT VIEW DEFINITION ON [dbo].[TGRS_OS_Rpt_TraderPerformance_MatchDetails] TO [bodbTGRSNet]
GO 
*/


