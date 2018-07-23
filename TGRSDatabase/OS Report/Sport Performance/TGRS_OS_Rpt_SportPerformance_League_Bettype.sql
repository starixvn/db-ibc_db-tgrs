
SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

ALTER PROCEDURE [dbo].[TGRS_OS_Rpt_SportPerformance_League_Bettype]
		@ReportType			TINYINT = 1
	,	@SportId			INT
	,	@LeagueId			INT
	,	@TraderId			INT = -1
	,	@FromDate			DATE
	,	@ToDate				DATE
AS	
/*  
	Created: 20180720@Long
	Task : Get OS Bettypes Performance  
	DB:  DBTGRS.bodb_TGRS  
	  
	Revisions:  

	Ex: @ReportType = 1: Daily, 2: Monthly

*/

BEGIN
	SET NOCOUNT ON;

	-- INIT
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

	-- START
	IF @ReportType = 1
	BEGIN
		INSERT INTO #tmpOSBettypePerformance (BettypeId, Turnover, VWinLoss, Target)
		SELECT	td.BettypeId
			,	SUM(td.Turnover) AS Turnover
			,	SUM(td.WinLoss - td.Comm) AS 'VWinLoss'
			,	td.Target
		FROM dbo.OSSummaryByTrader_Daily AS td WITH (NOLOCK)
		WHERE td.EventDate BETWEEN @FromDate AND @ToDate
			AND (@TraderId = -1 OR td.TraderId = @TraderId)
			AND td.SportId = @SportId
			AND td.LeagueId = @LeagueId
		GROUP BY td.BettypeId
			,	td.Target;
	END
	ELSE IF @ReportType = 2
	BEGIN
		INSERT INTO #tmpOSBettypePerformance  (BettypeId, Turnover, VWinLoss, Target)
		SELECT	td.BettypeId
			,	SUM(td.Turnover) AS Turnover
			,	SUM(td.WinLoss - td.Comm) AS 'VWinLoss'
			,	td.Target
		FROM dbo.OSSummaryByTrader_Monthly AS td WITH (NOLOCK)
		WHERE td.EventDate BETWEEN @FromDate AND @ToDate
			AND (@TraderId = -1 OR td.TraderId = @TraderId)
			AND td.SportId = @SportId
			AND LeagueId = @LeagueId
		GROUP BY td.BettypeId
			,	td.Target;
	END;

	SELECT @TotalTurnover = SUM(Turnover)
	FROM #tmpOSBettypePerformance WITH(NOLOCK);

	SELECT	t.BettypeId
		,	bt.typenamee AS BettypeName
		,	SUM(t.Turnover) AS Turnover
		,	SUM(t.VWinLoss) AS 'VWinLoss'
		,	(SUM(t.VWinLoss) * 100 / SUM(t.Turnover)) AS 'VMargin'
		,	(SUM(t.Turnover) * 100 / @TotalTurnover) AS 'AverageVTurnover'
		,	(SUM(t.VWinLoss) * (@FMark) / SUM(t.Turnover)) AS 'PointMargin'
	FROM #tmpOSBettypePerformance t WITH (NOLOCK)
		INNER JOIN bodb02.dbo.bettype bt WITH (NOLOCK) ON t.BettypeId = bt.typeid
	GROUP BY t.BettypeId
		,	bt.typenamee;

	DROP TABLE #tmpOSBettypePerformance;
END

/*   
GO  
GRANT EXECUTE ON [dbo].[TGRS_OS_Rpt_SportPerformance_League_Bettype] TO [bodbTGRSNet]  
GO  
GRANT VIEW DEFINITION ON [dbo].[TGRS_OS_Rpt_SportPerformance_League_Bettype] TO [bodbTGRSNet]  
GO  
*/