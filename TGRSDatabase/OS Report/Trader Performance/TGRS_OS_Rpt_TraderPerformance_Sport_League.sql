
SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

ALTER PROCEDURE [dbo].[TGRS_OS_Rpt_TraderPerformance_Sport_League]
		@ReportType			TINYINT = 1
	,	@SportId			INT
	,	@TraderId			INT
	,	@FromDate			DATE
	,	@ToDate				DATE
AS	
/*  
	Created: 20170418@John.Ngo  
	Task : Get OS Leagues Performance  
	DB:  DBTGRS.bodb_TGRS  
	  
	Revisions:  
		- 20180716@Long: return MatchCount value [Redmine: #94315]

	Ex: @ReportType = 1: Daily, 2: Monthly
*/

BEGIN
	SET NOCOUNT ON;

	DECLARE @FMark			DECIMAL(18, 2)
		,	@TotalTurnover	MONEY;

	IF OBJECT_ID('tempdb..#tmpOSLeaguePerformance') IS NOT NULL
	BEGIN
		DROP TABLE #tmpOSLeaguePerformance;
	END;

	CREATE TABLE #tmpOSLeaguePerformance (
			LeagueId		INT
		,	BettypeId		INT
		,	Turnover		MONEY
		,	VWinLoss		MONEY
		,	Target			DECIMAL(18, 2)
	);

	-- START
	SELECT TOP(1) @FMark = ParamValue
	FROM dbo.OSParameter WITH (NOLOCK)
	WHERE ParamId = 7; -- FloorMark value
	
	IF @ReportType = 1
	BEGIN
		INSERT INTO #tmpOSLeaguePerformance (
				LeagueId
			,	BettypeId
			,	Turnover
			,	VWinLoss
			,	Target
		)
		SELECT	td.LeagueId
			,	td.BettypeId
			,	SUM(td.Turnover) AS Turnover
			,	SUM(td.WinLoss - td.Comm) AS 'VWinLoss'
			,	td.Target
		FROM dbo.OSSummaryByTrader_Daily td WITH (NOLOCK)
			INNER JOIN dbo.OSTrader t WITH (NOLOCK) ON t.TraderId = td.TraderId
		WHERE td.TraderId = @TraderId
			AND td.EventDate BETWEEN @FromDate AND @ToDate
			AND td.SportId = @SportId
		GROUP BY td.LeagueId
			,	td.BettypeId
			,	td.Target;
	END
	ELSE IF @ReportType = 2
	BEGIN
		INSERT INTO #tmpOSLeaguePerformance (
				LeagueId
			,	BettypeId
			,	Turnover
			,	VWinLoss
			,	Target
		)
		SELECT	td.LeagueId
			,	td.BettypeId
			,	SUM(td.Turnover) AS Turnover
			,	SUM(td.WinLoss - td.Comm) AS 'VWinLoss'
			,	td.Target
		FROM dbo.OSSummaryByTrader_Monthly td WITH (NOLOCK)
			INNER JOIN dbo.OSTrader t WITH (NOLOCK) ON t.TraderId = td.TraderId
		WHERE td.TraderId = @TraderId
			AND td.EventDate BETWEEN @FromDate AND @ToDate
			AND td.SportId = @SportId
		GROUP BY td.LeagueId
			,	td.BettypeId
			,	td.Target;
	END;
	
	SELECT @TotalTurnover = SUM(Turnover)
	FROM #tmpOSLeaguePerformance WITH(NOLOCK);

	SELECT	t.LeagueId AS LeagueId
		,	l.LeagueName AS LeagueName
		,	COUNT(DISTINCT t.BettypeId) AS 'NoOfBettype'
		,	LeagueMatchCount.MatchCount AS 'NoOfMatch'
		,	SUM(t.Turnover) AS Turnover
		,	SUM(t.VWinLoss) AS 'VWinLoss'
		,	(SUM(t.VWinLoss) * 100 / SUM(t.Turnover)) AS 'VMargin'
		,	(SUM(t.Turnover) * 100 / @TotalTurnover) AS 'AverageVTurnover'
		,	(SUM(t.VWinLoss) * (@FMark) / SUM(t.Turnover)) AS 'PointMargin'
	FROM #tmpOSLeaguePerformance t WITH (NOLOCK)
		INNER JOIN bodb02.dbo.league l WITH (NOLOCK) ON t.LeagueId = l.leagueid
		CROSS APPLY (
			SELECT	COUNT(DISTINCT ostp.MatchId) AS MatchCount
			FROM dbo.OSDataTGRS ostp WITH(NOLOCK)
			WHERE ostp.EventDate BETWEEN @FromDate AND @ToDate
				AND ostp.TraderId = @TraderId
				AND (
					ostp.SportId = @SportId
					OR @SportId = - 1
				)
				AND ostp.LeagueId = t.LeagueId
			GROUP BY ostp.LeagueId
		) AS LeagueMatchCount
	GROUP BY t.LeagueId
		,	l.LeagueName
		,	LeagueMatchCount.MatchCount;

	DROP TABLE #tmpOSLeaguePerformance;
END;

/* 
GO 
 GRANT EXECUTE ON [dbo].[TGRS_OS_Rpt_TraderPerformance_Sport_League] TO [bodbTGRSNet]
GO 
 GRANT VIEW DEFINITION ON [dbo].[TGRS_OS_Rpt_TraderPerformance_Sport_League] TO [bodbTGRSNet]
GO 
*/


