
SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

ALTER PROCEDURE [dbo].[TGRS_OS_Rpt_TraderPerformance_Sport_League_Bettype]
		@ReportType			TINYINT = 1
	,	@SportId			INT
	,	@LeagueId			INT
	,	@TraderId			INT
	,	@FromDate			DATE
	,	@ToDate				DATE
AS	
	/*  
	Created: 20180716@Long
	Task : Get OS Bettypes Performance  
	DB:  DBTGRS.bodb_TGRS  
	  
	Revisions:  

	Ex: @ReportType = 1: Daily, 2: Monthly

	*/

BEGIN
	SET NOCOUNT ON;

	DECLARE @FMark			DECIMAL(18, 2)
		,	@TotalTurnover	MONEY;

	SELECT TOP 1 @FMark = ParamValue
	FROM dbo.OSParameter WITH (NOLOCK)
	WHERE ParamId = 7; -- FloorMark value

	IF OBJECT_ID('tempdb..#tmpOSBettypePerformance') IS NOT NULL
	BEGIN
		DROP TABLE #tmpOSBettypePerformance
	END;

	CREATE TABLE #tmpOSBettypePerformance (
			BettypeId		INT
		,	Turnover		MONEY
		,	VWinLoss		MONEY
		,	Target			DECIMAL(18, 2)
	);

	IF @ReportType = 1
	BEGIN
		INSERT INTO #tmpOSBettypePerformance (
				BettypeId
			,	Turnover
			,	VWinLoss
			,	Target
		)
		SELECT	td.BettypeId
			,	SUM(td.Turnover) AS Turnover
			,	SUM(td.WinLoss - td.Comm) AS 'VWinLoss'
			,	td.Target
		FROM dbo.OSSummaryByTrader_Daily td WITH (NOLOCK)
		INNER JOIN dbo.OSTrader t WITH (NOLOCK) ON t.TraderId = td.TraderId
		WHERE td.TraderId = @TraderId
		AND td.EventDate BETWEEN @FromDate AND @ToDate
			AND td.SportId = @SportId
			AND LeagueId = @LeagueId
		GROUP BY td.BettypeId
			,	td.Target;
	END
	ELSE IF @ReportType = 2
	BEGIN
		INSERT INTO #tmpOSBettypePerformance (
				BettypeId
			,	Turnover
			,	VWinLoss
			,	Target
		)
		SELECT	td.BettypeId
			,	SUM(td.Turnover) AS Turnover
			,	SUM(td.WinLoss - td.Comm) AS 'VWinLoss'
			,	td.Target
		FROM dbo.OSSummaryByTrader_Monthly td WITH (NOLOCK)
			INNER JOIN dbo.OSTrader t WITH (NOLOCK) ON t.TraderId = td.TraderId
		WHERE td.TraderId = @TraderId
			AND td.EventDate BETWEEN @FromDate AND @ToDate
			AND td.SportId = @SportId
			AND LeagueId = @LeagueId
		GROUP BY td.BettypeId
			,	td.Target;
	END;
	
	SELECT @TotalTurnover = SUM(Turnover)
	FROM #tmpOSBettypePerformance;

	SELECT	t.BettypeId
		,	bt.typenamee AS BettypeName
		,	SUM(Turnover) AS Turnover
		,	SUM(VWinLoss) AS 'VWinLoss'
		,	(SUM(VWinLoss) * 100 / SUM(Turnover)) AS 'VMargin'
		,	(SUM(Turnover) * 100 / @TotalTurnover) AS 'AverageVTurnover'
		,	(SUM(VWinLoss) * (@FMark) / SUM(Turnover)) AS 'PointMargin'
	FROM #tmpOSBettypePerformance t WITH (NOLOCK)
		INNER JOIN bodb02.dbo.bettype bt WITH (NOLOCK) ON t.BettypeId = bt.typeid
	GROUP BY t.BettypeId
		,	bt.typenamee;

	DROP TABLE #tmpOSBettypePerformance;
END;

/*   
GO  
GRANT EXECUTE ON [dbo].[TGRS_OS_Rpt_TraderPerformance_Sport_League_Bettype] TO [bodbTGRSNet]  
GO  
GRANT VIEW DEFINITION ON [dbo].[TGRS_OS_Rpt_TraderPerformance_Sport_League_Bettype] TO [bodbTGRSNet]  
GO  
*/


