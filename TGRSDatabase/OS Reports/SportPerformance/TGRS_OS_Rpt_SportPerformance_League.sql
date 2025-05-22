/*<info serverAlias="DBTGRS-bodb_TGRS" executers="wsv_tgrs" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[TGRS_OS_Rpt_SportPerformance_League]
		@ReportType		TINYINT  = 1
	,	@SportId		INT		 = -1
	,	@TraderId		INT		 = -1
	,	@FromDate		DATE
	,	@ToDate			DATE
	,	@LiveType		SMALLINT = -1
AS
/*
	Created: 20180720@Long
	Task : Get OS Sports Performance by League
	DB:  DBTGRS.bodb_TGRS
	Original:

	Revisions:
		- 20181030@Long: Adding Betcount column to OS's reports [Redmine ID: #101741]
		- 20200914@John.Ngo: Support Live/Nonlive for OSDataTGRS [Redmine ID: #140875]
		- 20250513@Della: Fix default param @LiveType (#225204)

	Param's Explanation (filtered by):
		Ex: SportId = -1: Show all
			- @ReportType = 1: Daily, 2: Monthly
			- @LiveType: -1 All; 0 Nonlive; 1 Live
*/
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
		,	BetCount		BIGINT
	);
	  
	CREATE CLUSTERED INDEX	#CIX_tmpOSLeaguePerformance_LeagueId ON #tmpOSLeaguePerformance (
		LeagueId			ASC
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
			,	BetCount
		)
		SELECT	td.LeagueId
			,	td.BettypeId
			,	SUM(td.Turnover) AS Turnover
			,	SUM(td.WinLoss - td.Comm) AS 'VWinLoss'
			,	td.Target
			,	SUM(td.BetCount)
		FROM dbo.OSSummaryByTrader_Daily td WITH (NOLOCK)
		WHERE (@TraderId = -1 OR td.TraderId = @TraderId)
			AND td.EventDate BETWEEN @FromDate AND @ToDate
			AND td.SportId = @SportId
			AND (@LiveType = -1 OR td.IsLive = @LiveType)
		GROUP BY td.LeagueId
			,	td.BettypeId
			,	td.Target;
	END;
	ELSE IF @ReportType = 2
	BEGIN
		INSERT INTO #tmpOSLeaguePerformance (
				LeagueId
			,	BettypeId
			,	Turnover
			,	VWinLoss
			,	Target
			,	BetCount
		)
		SELECT	td.LeagueId
			,	td.BettypeId
			,	SUM(td.Turnover) AS Turnover
			,	SUM(td.WinLoss - td.Comm) AS VWinLoss
			,	td.Target
			,	SUM(td.BetCount)
		FROM dbo.OSSummaryByTrader_Monthly td WITH (NOLOCK)
		WHERE (@TraderId = -1 OR td.TraderId = @TraderId)
			AND td.EventDate BETWEEN @FromDate AND @ToDate
			AND td.SportId = @SportId
			AND (@LiveType = -1 OR td.IsLive = @LiveType)
		GROUP BY td.LeagueId
			,	td.BettypeId
			,	td.Target;
	END;
	
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
		,	SUM(t.BetCount) AS BetCount
	FROM #tmpOSLeaguePerformance t WITH (NOLOCK)
		INNER JOIN bodb02.dbo.league l WITH (NOLOCK) ON t.LeagueId = l.leagueid
	GROUP BY t.LeagueId
		,	l.LeagueName;

	DROP TABLE #tmpOSLeaguePerformance;
END;

GO
/*<info serverAlias="DBTGRS-bodb_TGRS" executers="bodbTGRSNet" isFunction="0" isNested="0"></info>*/