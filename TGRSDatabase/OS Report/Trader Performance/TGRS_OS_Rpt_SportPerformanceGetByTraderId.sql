
SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

/****** Object:  Stored Procedure dbo.TGRS_OS_Rpt_SportPerformanceGetByTraderId    Script Date: 3/7/2017 3:10:48 PM ******/

CREATE PROCEDURE [dbo].[TGRS_OS_Rpt_SportPerformanceGetByTraderId]
		@ReportType		TINYINT = 1
	,	@TraderId		INT
	,	@FromDate		DATE
	,	@ToDate			DATE

/*
	Created: 20160810@Long
	Task : Get OS Sport Performance of a trader
	DB:  DBTGRS.bodb_TGRS

	Revisions:
		- 20170307@Aaron: Added @ReportType and calculate the score by league
*/

AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @IncrementTimes DECIMAL(18, 2)
		,	@IncrementValue DECIMAL(18, 2)
		,	@FloorMark		DECIMAL(18, 2)
		,	@SumTurnover	MONEY;

	SELECT @IncrementTimes = ParamValue
	FROM dbo.[OSParameter] WITH (NOLOCK)
	WHERE ParamId = 3;

	SELECT @IncrementValue = ParamValue
	FROM dbo.[OSParameter] WITH (NOLOCK)
	WHERE ParamId = 5;

	SELECT @FloorMark = ParamValue
	FROM dbo.[OSParameter] WITH (NOLOCK)
	WHERE ParamId = 7;
	
	IF OBJECT_ID('tempdb..#TraderPerformanceDetail') IS NOT NULL
	BEGIN
		DROP TABLE #TraderPerformanceDetail
	END

	CREATE TABLE #TraderPerformanceDetail (
			SportId				INT
		,	LeagueId			INT
		,	BettypeId			INT
		,	Turnover			MONEY
		,	WinLoss				MONEY
		,	EventProductCount	INT
		,	Target				DECIMAL(18,4)
	);

	IF OBJECT_ID('tempdb..#SportPerformanceDetail') IS NOT NULL
	BEGIN
		DROP TABLE #SportPerformanceDetail
	END

	CREATE TABLE #SportPerformanceDetail (
			SportId				INT
		,	BettypeId			INT
		,	Turnover			MONEY
		,	WinLoss				MONEY
		,	Point				MONEY
		,	EventProductCount	INT
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
		)
		SELECT	tp.SportId
			,	tp.LeagueId
			,	tp.BettypeId
			,	SUM(tp.Turnover) AS Turnover
			,	SUM(tp.Winloss - tp.Comm) AS Winloss
			,	SUM(tp.MatchCount) AS EventProductCount
			,	tp.Target
		FROM dbo.OSSummaryByTrader_Daily tp WITH (NOLOCK)
		JOIN dbo.OSTrader t WITH (NOLOCK) ON t.TraderId = tp.TraderId
		WHERE tp.TraderId = @TraderId
			AND tp.EventDate BETWEEN @FromDate AND @ToDate
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
		)
		SELECT	tp.SportId
			,	tp.LeagueId
			,	tp.BettypeId
			,	SUM(tp.Turnover) AS Turnover
			,	SUM(tp.Winloss - tp.Comm) AS Winloss
			,	SUM(tp.MatchCount) AS EventProductCount
			,	tp.Target
		FROM dbo.OSSummaryByTrader_Monthly tp WITH (NOLOCK)
		JOIN dbo.OSTrader t WITH (NOLOCK) ON t.TraderId = tp.TraderId
		WHERE tp.TraderId = @TraderId
			AND tp.EventDate BETWEEN @FromDate AND @ToDate
		GROUP BY tp.TraderId
			,	tp.SportId
			,	tp.LeagueId
			,	tp.BettypeId
			,	tp.Target;
	END

	INSERT INTO #SportPerformanceDetail (
			SportId
		,	BettypeId
		,	Turnover
		,	WinLoss
		,	Point
		,	EventProductCount
	)
	SELECT	tp.SportId
		,	tp.BettypeId
		,	tp.Turnover
		,	tp.Winloss AS Winloss
		,	tp.Turnover * 100 / SUM(tp.Turnover) OVER (PARTITION BY tp.SportId) * (
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
		,	tp.EventProductCount AS EventProductCount
	FROM #TraderPerformanceDetail tp WITH (NOLOCK);
	
	SELECT @SumTurnover = SUM(tp.Turnover)
	FROM #TraderPerformanceDetail tp WITH (NOLOCK);

	SELECT	sd.SportId
		,	s.SportName
		,	CASE	WHEN SUM(sd.Point) * SUM(sd.Turnover)/ @SumTurnover > 100 THEN 100
				ELSE SUM(sd.Point) * SUM(sd.Turnover)/ @SumTurnover END AS TotalPoint
		,	(SUM(sd.WinLoss) * 100 / SUM(sd.Turnover)) AS Margin
		,	SUM(sd.Turnover) AS Turnover
		,	SUM(sd.WinLoss) AS WinLoss
		,	SUM(sd.EventProductCount) AS EventProductCount
	FROM #SportPerformanceDetail sd WITH (NOLOCK)
		JOIN bodb02.dbo.Sports s WITH (NOLOCK) ON s.SportType = sd.SportId
	GROUP BY sd.SportId
		,	s.SportName
	ORDER BY Turnover DESC, WinLoss DESC, Margin DESC;

	DROP TABLE #SportPerformanceDetail;
	DROP TABLE #TraderPerformanceDetail;
END;

/* 
GO
GRANT EXECUTE ON [dbo].[TGRS_OS_Rpt_SportPerformanceGetByTraderId] TO [bodbTGRSNet]
GO
GRANT VIEW DEFINITION ON [dbo].[TGRS_OS_Rpt_SportPerformanceGetByTraderId] TO [bodbTGRSNet]
GO
*/


GO

SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO


GO 
 GRANT EXECUTE ON [dbo].[TGRS_OS_Rpt_SportPerformanceGetByTraderId] TO [bodbTGRSNet]
GO 
 GRANT VIEW DEFINITION ON [dbo].[TGRS_OS_Rpt_SportPerformanceGetByTraderId] TO [bodbTGRSNet]
GO 
