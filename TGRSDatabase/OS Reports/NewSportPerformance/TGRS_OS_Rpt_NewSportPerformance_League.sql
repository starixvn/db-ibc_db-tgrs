/*<info serverAlias="DBTGRS-bodb_TGRS" executers="wsv_tgrs" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[TGRS_OS_Rpt_NewSportPerformance_League]
		@ReportType		TINYINT = 1
	,	@SportId		INT
	,	@FromDate		DATE
	,	@ToDate			DATE
	,	@LiveType		SMALLINT = -1
AS	
/*  
	Created: 20170403@Aaron 
	Task : Get new OS Leagues Performance  
	DB:  DBTGRS.bodb_TGRS  
	  
	Revisions:
		- 20181030@Long: Adding Betcount column to OS's reports [Redmine ID: #101741]
		- 20200914@John.Ngo: Support Live/Nonlive for OSDataTGRS [Redmine ID: #140875]
		- 20250514@Della: Fix default param @LiveType (#225204)

	Param's Explanation (filtered by):
		Ex: @ReportType = 1: Daily, 2: Monthly
		- @LiveType: -1 All; 0 Nonlive; 1 Live

*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @FMark			DECIMAL(18, 2)
		,	@TotalTurnover	MONEY;

	SELECT TOP 1 @FMark = ParamValue
	FROM dbo.OSParameter WITH (NOLOCK)
	WHERE ParamId = 7; -- FloorMark value
	
	IF OBJECT_ID('tempdb..#tmpOSLeaguePerformance') IS NOT NULL
		DROP TABLE #tmpOSLeaguePerformance;

	CREATE TABLE #tmpOSLeaguePerformance (
			LeagueId		INT
		,	BettypeId		INT
		,	Turnover		MONEY
		,	WinLoss			MONEY
		,	Target			DECIMAL(18, 2)
		,	JuiceTurnover	MONEY
		,	JuiceWinLoss	MONEY
		,	BetCount		BIGINT
	);
	  
	CREATE CLUSTERED INDEX	#CIX_tmpOSLeaguePerformance_SportId ON #tmpOSLeaguePerformance (
		LeagueId			ASC
	);

	IF @ReportType = 1
	BEGIN
		INSERT INTO #tmpOSLeaguePerformance (
				LeagueId
			,	BettypeId
			,	Turnover
			,	WinLoss
			,	Target
			,	JuiceTurnover
			,	JuiceWinLoss
			,	BetCount
		)
		SELECT	td.LeagueId
			,	td.BettypeId
			,	SUM(td.StakeMYR) AS Turnover
			,	SUM(td.Winloss - td.Comm) AS Winloss
			,	td.Target
			,	SUM(td.StakeMYRJuice) AS JuiceTurnover
			,	SUM(td.Juice) AS JuiceWinloss
			,	SUM(td.BetCount)
		FROM dbo.OSSummaryByTrader_Daily td WITH (NOLOCK)
		WHERE td.EventDate BETWEEN @FromDate AND @ToDate
			AND td.SportId = @SportId
			AND td.BettypeId IN (1,2,3,7,8,12)
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
			,	WinLoss
			,	Target
			,	JuiceTurnover
			,	JuiceWinLoss
			,	BetCount
		)
		SELECT	td.LeagueId
			,	td.BettypeId
			,	SUM(td.StakeMYR) AS Turnover
			,	SUM(td.Winloss - td.Comm) AS Winloss
			,	td.Target
			,	SUM(td.StakeMYRJuice) AS JuiceTurnover
			,	SUM(td.Juice) AS JuiceWinloss
			,	SUM(td.BetCount)
		FROM dbo.OSSummaryByTrader_Monthly td WITH (NOLOCK)
		WHERE td.EventDate BETWEEN @FromDate AND @ToDate
			AND td.SportId = @SportId
			AND td.BettypeId IN (1,2,3,7,8,12)
			AND (@LiveType = -1 OR td.IsLive = @LiveType)
		GROUP BY td.LeagueId
			,	td.BettypeId
			,	td.Target;
	END;
	
	SELECT @TotalTurnover = SUM(Turnover)
	FROM #tmpOSLeaguePerformance WITH(NOLOCK);

	--Select
	SELECT	t.LeagueId
		,	l.LeagueName
		,	COUNT(DISTINCT BettypeId) AS NoOfBettype
		,	SUM(Turnover) AS Turnover
		,	SUM(WinLoss) AS WinLoss
		,	SUM(JuiceTurnover) AS JuiceTurnover
		,	SUM(JuiceWinloss) AS JuiceWinloss
		,	(SUM(Turnover) * 100 / @TotalTurnover) AS AverageVTurnover
		,	(SUM(WinLoss) * (@FMark) / SUM(Turnover)) AS PointMargin
		,	SUM(t.BetCount) AS BetCount
	FROM #tmpOSLeaguePerformance t WITH (NOLOCK)
		INNER JOIN bodb02.dbo.league l WITH (NOLOCK) ON t.LeagueId = l.leagueid
	GROUP BY t.LeagueId
		,	l.LeagueName;

	DROP TABLE #tmpOSLeaguePerformance;
END;

GO
/*<info serverAlias="DBTGRS-bodb_TGRS" executers="bodbTGRSNet" isFunction="0" isNested="0"></info>*/