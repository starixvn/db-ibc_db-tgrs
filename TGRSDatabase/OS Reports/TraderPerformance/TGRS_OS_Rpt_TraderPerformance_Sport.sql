/*<info serverAlias="DBTGRS-bodb_TGRS" executers="wsv_tgrs" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[TGRS_OS_Rpt_TraderPerformance_Sport] 
		@ReportType		TINYINT  = 1
	,	@TraderId		INT
	,	@FromDate		DATE
	,	@ToDate			DATE
	,	@SportId		INT	 = - 1
	,	@LiveType		SMALLINT = -1
AS	
/*
	Created: 20160810@Aaron
	Task : Get OS Sport Performance of a trader
	DB:  DBTGRS.bodb_TGRS
	Original:

	Revisions:
		- 20170307@Aaron:	Added @ReportType and calculate the score by league
		- 20170316@Aaron:	Added @SportId
		- 20170418@John:	Added 'NoOfLeague'
		- 20181030@Long:	Adding Betcount column to OS's reports [Redmine ID: #101741]
		- 20200914@John.Ngo: Support Live/Nonlive for OSDataTGRS [Redmine ID: #140875]
		- 20250514@Della: Fix default param @LiveType (#225204)

	Param's Explanation (filtered by):
		- @LiveType: -1 All; 0 Nonlive; 1 Live
*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @IncrementTimes DECIMAL(18, 2)
		,	@IncrementValue DECIMAL(18, 2)
		,	@FloorMark		DECIMAL(18, 2)
		,	@SumTurnover	MONEY;

	SELECT @IncrementTimes = ParamValue
	FROM [dbo].[OSParameter] WITH (NOLOCK)
	WHERE ParamId = 3;

	SELECT @IncrementValue = ParamValue
	FROM [dbo].[OSParameter] WITH (NOLOCK)
	WHERE ParamId = 5;

	SELECT @FloorMark = ParamValue
	FROM [dbo].[OSParameter] WITH (NOLOCK)
	WHERE ParamId = 7;

	IF @SportId IS NULL
	BEGIN
		SET @SportId = - 1
	END;

	IF OBJECT_ID('tempdb..#TraderPerformanceDetail') IS NOT NULL
	BEGIN
		DROP TABLE #TraderPerformanceDetail
	END;

	CREATE TABLE #TraderPerformanceDetail (
			SportId				INT
		,	LeagueId			INT
		,	BettypeId			INT
		,	Turnover			MONEY
		,	WinLoss				MONEY
		,	EventProductCount	INT
		,	Target				DECIMAL(18, 4)
		,	BetCount			BIGINT
	);
	
	CREATE CLUSTERED INDEX	#CIX_TraderPerformanceDetail_SportId ON #TraderPerformanceDetail (
		SportId					ASC
	);

	IF OBJECT_ID('tempdb..#tmpSportPerformanceDetail') IS NOT NULL
	BEGIN
		DROP TABLE #tmpSportPerformanceDetail
	END;

	CREATE TABLE #tmpSportPerformanceDetail (
			SportId				INT
		,	LeagueId			INT
		,	BettypeId			INT
		,	Turnover			MONEY
		,	WinLoss				MONEY
		,	Point				MONEY
		,	EventProductCount	INT
		,	BetCount			BIGINT
	);
	
	CREATE CLUSTERED INDEX	#CIX_tmpSportPerformanceDetail_SportId ON #tmpSportPerformanceDetail (
		SportId					ASC
	);

	IF @ReportType = 1
	BEGIN
		INSERT INTO #TraderPerformanceDetail (
				SportId
			,	LeagueId
			,	BettypeId
			,	Turnover
			,	WinLoss
			,	EventProductCount
			,	Target
			,	BetCount
		)
		SELECT	tp.SportId
			,	tp.LeagueId
			,	tp.BettypeId
			,	SUM(tp.Turnover) AS Turnover
			,	SUM(tp.Winloss - tp.Comm) AS Winloss
			,	SUM(tp.MatchCount) AS EventProductCount
			,	tp.Target
			,	SUM(tp.BetCount)
		FROM dbo.OSSummaryByTrader_Daily tp WITH (NOLOCK)
			JOIN dbo.OSTrader t WITH (NOLOCK) ON t.TraderId = tp.TraderId
		WHERE tp.TraderId = @TraderId
			AND tp.EventDate BETWEEN @FromDate AND @ToDate
			AND (tp.SportId = @SportId OR @SportId = - 1)
			AND (@LiveType = -1 OR tp.IsLive = @LiveType)
		GROUP BY tp.TraderId
			,	tp.SportId
			,	tp.LeagueId
			,	tp.BettypeId
			,	tp.Target;
	END
	ELSE IF @ReportType = 2
	BEGIN
		INSERT INTO #TraderPerformanceDetail (
				SportId
			,	LeagueId
			,	BettypeId
			,	Turnover
			,	WinLoss
			,	EventProductCount
			,	Target
			,	BetCount
		)
		SELECT	tp.SportId
			,	tp.LeagueId
			,	tp.BettypeId
			,	SUM(tp.Turnover) AS Turnover
			,	SUM(tp.Winloss - tp.Comm) AS Winloss
			,	SUM(tp.MatchCount) AS EventProductCount
			,	tp.Target
			,	SUM(tp.BetCount)
		FROM dbo.OSSummaryByTrader_Monthly tp WITH (NOLOCK)
			JOIN dbo.OSTrader t WITH (NOLOCK) ON t.TraderId = tp.TraderId
		WHERE tp.TraderId = @TraderId
			AND tp.EventDate BETWEEN @FromDate AND @ToDate
			AND (tp.SportId = @SportId OR @SportId = - 1)
			AND (@LiveType = -1 OR tp.IsLive = @LiveType)
		GROUP BY tp.TraderId
			,	tp.SportId
			,	tp.LeagueId
			,	tp.BettypeId
			,	tp.Target;
	END;

	INSERT INTO #tmpSportPerformanceDetail (
			SportId
		,	LeagueId
		,	BettypeId
		,	Turnover
		,	WinLoss
		,	Point
		,	EventProductCount
		,	BetCount
	)
	SELECT	tp.SportId
		,	tp.LeagueId
		,	tp.BettypeId
		,	tp.Turnover
		,	tp.Winloss AS Winloss
		,	tp.Turnover * 100 / SUM(tp.Turnover) OVER (PARTITION BY tp.SportId) 
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
		,	tp.EventProductCount AS EventProductCount
		,	tp.BetCount
	FROM #TraderPerformanceDetail tp WITH (NOLOCK);

	SELECT @SumTurnover = SUM(tp.Turnover)
	FROM #TraderPerformanceDetail tp WITH (NOLOCK);

	SELECT	sd.SportId
		,	s.SportName
		,	COUNT(DISTINCT LeagueId) AS 'NoOfLeague'
		,	CASE 
			WHEN SUM(sd.Point) * SUM(sd.Turnover) / @SumTurnover > 100
				THEN 100
			ELSE SUM(sd.Point) * SUM(sd.Turnover) / @SumTurnover
			END AS TotalPoint
		,	(SUM(sd.WinLoss) * 100 / SUM(sd.Turnover)) AS Margin
		,	SUM(sd.Turnover) AS Turnover
		,	SUM(sd.WinLoss) AS WinLoss
		,	SUM(sd.EventProductCount) AS EventProductCount
		,	SUM(sd.BetCount) AS BetCount
	FROM #tmpSportPerformanceDetail sd WITH (NOLOCK)
		INNER JOIN bodb02.dbo.Sports s WITH(NOLOCK) ON s.SportType = sd.SportId
	GROUP BY sd.SportId
		,	s.SportName;

	DROP TABLE #tmpSportPerformanceDetail;
	DROP TABLE #TraderPerformanceDetail;
END;

GO
/*<info serverAlias="DBTGRS-bodb_TGRS" executers="bodbTGRSNet" isFunction="0" isNested="0"></info>*/