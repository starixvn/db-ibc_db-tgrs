/*<info serverAlias="DBTGRS-bodb_TGRS" executers="wsv_tgrs" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[TGRS_OS_Rpt_TraderPerformance_Sport_League]
		@ReportType			TINYINT  = 1
	,	@SportId			INT
	,	@TraderId			INT
	,	@FromDate			DATE
	,	@ToDate				DATE
	,	@LiveType			SMALLINT = -1
AS	
/*  
	Created: 20170418@John.Ngo  
	Task : Get OS Leagues Performance  
	DB:  DBTGRS.bodb_TGRS  
	  
	Revisions:  
		- 20180716@Long: return MatchCount value [Redmine: #94315]
		- 20181030@Long: Adding Betcount column to OS's reports [Redmine ID: #101741]
		- 20200914@John.Ngo: Support Live/Nonlive for OSDataTGRS [Redmine ID: #140875]
		- 20250514@Della: Fix default param @LiveType (#225204)

	Ex: @ReportType = 1: Daily, 2: Monthly
		- @LiveType: -1 All; 0 Nonlive; 1 Live
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
		,	BetCount		BIGINT
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
			,	BetCount
		)
		SELECT	td.LeagueId
			,	td.BettypeId
			,	SUM(td.Turnover) AS Turnover
			,	SUM(td.WinLoss - td.Comm) AS 'VWinLoss'
			,	td.Target
			,	SUM(td.BetCount)
		FROM dbo.OSSummaryByTrader_Daily td WITH (NOLOCK)
			INNER JOIN dbo.OSTrader t WITH (NOLOCK) ON t.TraderId = td.TraderId
		WHERE td.TraderId = @TraderId
			AND td.EventDate BETWEEN @FromDate AND @ToDate
			AND td.SportId = @SportId
			AND (@LiveType = -1 OR td.IsLive = @LiveType)
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
			,	BetCount
		)
		SELECT	td.LeagueId
			,	td.BettypeId
			,	SUM(td.Turnover) AS Turnover
			,	SUM(td.WinLoss - td.Comm) AS 'VWinLoss'
			,	td.Target
			,	SUM(td.BetCount)
		FROM dbo.OSSummaryByTrader_Monthly td WITH (NOLOCK)
			INNER JOIN dbo.OSTrader t WITH (NOLOCK) ON t.TraderId = td.TraderId
		WHERE td.TraderId = @TraderId
			AND td.EventDate BETWEEN @FromDate AND @ToDate
			AND td.SportId = @SportId
			AND (@LiveType = -1 OR td.IsLive = @LiveType)
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
		,	SUM(t.BetCount) AS BetCount
	FROM #tmpOSLeaguePerformance t WITH (NOLOCK)
		INNER JOIN bodb02.dbo.league l WITH (NOLOCK) ON t.LeagueId = l.leagueid
		CROSS APPLY (
			SELECT	COUNT(DISTINCT ostp.MatchId) AS MatchCount
			FROM dbo.OSDataTGRS AS ostp WITH(NOLOCK)
			WHERE ostp.EventDate BETWEEN @FromDate AND @ToDate
				AND ostp.TraderId = @TraderId
				AND (ostp.SportId = @SportId OR @SportId = - 1)
				AND ostp.LeagueId = t.LeagueId
				AND (@LiveType = -1 OR ostp.IsLive = @LiveType)
			GROUP BY ostp.LeagueId
		) AS LeagueMatchCount
	GROUP BY t.LeagueId
		,	l.LeagueName
		,	LeagueMatchCount.MatchCount;

	DROP TABLE #tmpOSLeaguePerformance;
END;

GO
/*<info serverAlias="DBTGRS-bodb_TGRS" executers="bodbTGRSNet" isFunction="0" isNested="0"></info>*/