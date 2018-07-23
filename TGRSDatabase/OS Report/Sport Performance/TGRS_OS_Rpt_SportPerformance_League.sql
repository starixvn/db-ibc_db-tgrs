
SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

ALTER PROCEDURE [dbo].[TGRS_OS_Rpt_SportPerformance_League]
		@ReportType		TINYINT = 1
	,	@SportId		INT = -1
	,	@TraderId		INT = -1
	,	@FromDate		DATE
	,	@ToDate			DATE

/*
	Created: 20180720@Long
	Task : Get OS Sports Performance by League
	DB:  DBTGRS.bodb_TGRS

	Revisions:
	Ex: SportId = -1: Show all
		@ReportType = 1: Daily, 2: Monthly
*/

AS
BEGIN
	SET NOCOUNT ON;

	-- INIT
	DECLARE @FMark				DECIMAL(18, 2)
		,	@TotalTurnover		MONEY;

	SELECT TOP(1) @FMark = ParamValue
	FROM dbo.OSParameter WITH (NOLOCK)
	WHERE ParamId = 7; -- FloorMark value

	IF OBJECT_ID('tempdb..#tmpOSLeaguePerformance') IS NOT NULL
	BEGIN
		DROP TABLE #tmpOSLeaguePerformance;
	END

	CREATE TABLE #tmpOSLeaguePerformance (
			LeagueId		INT
		,	BettypeId		INT
		,	Turnover		MONEY
		,	VWinLoss		MONEY
		,	Target			DECIMAL(18, 2)
	);

	-- START
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
		WHERE (@TraderId = -1 OR td.TraderId = @TraderId)
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
			,	SUM(td.WinLoss - td.Comm) AS VWinLoss
			,	td.Target
		FROM dbo.OSSummaryByTrader_Monthly td WITH (NOLOCK)
		WHERE (@TraderId = -1 OR td.TraderId = @TraderId)
			AND td.EventDate BETWEEN @FromDate AND @ToDate
			AND td.SportId = @SportId
		GROUP BY td.LeagueId
			,	td.BettypeId
			,	td.Target;
	END
	
	SELECT @TotalTurnover = SUM(Turnover)
	FROM #tmpOSLeaguePerformance WITH(NOLOCK);

	SELECT	t.LeagueId
		,	l.LeagueName
		,	COUNT(DISTINCT t.BettypeId) AS NoOfBettype
		,	SUM(t.Turnover) AS Turnover
		,	SUM(t.VWinLoss) AS VWinLoss
		,	(SUM(t.VWinLoss) * 100 / SUM(t.Turnover)) AS VMargin
		,	(SUM(t.Turnover) * 100 / @TotalTurnover) AS AverageVTurnover
		,	(SUM(t.VWinLoss) * (@FMark) / SUM(t.Turnover)) AS PointMargin
	FROM #tmpOSLeaguePerformance t WITH (NOLOCK)
		INNER JOIN bodb02.dbo.league l WITH (NOLOCK) ON t.LeagueId = l.leagueid
	GROUP BY t.LeagueId
		,	LeagueName;

	DROP TABLE #tmpOSLeaguePerformance;
END;

GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

GO 
GRANT EXECUTE ON [dbo].[TGRS_OS_Rpt_SportPerformance_League] TO [bodbTGRSNet]
GO 
GRANT VIEW DEFINITION ON [dbo].[TGRS_OS_Rpt_SportPerformance_League] TO [bodbTGRSNet]
GO 
