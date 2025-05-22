/*<info serverAlias="DBTGRS-bodb_TGRS" executers="wsv_tgrs" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[TGRS_OS_Rpt_NewSportPerformance_League_Bettype]
		@ReportType		TINYINT = 1
	,	@SportId		INT
	,	@LeagueId		INT
	,	@FromDate		DATE
	,	@ToDate			DATE
	,	@LiveType		SMALLINT = -1
AS
/*  
	Created: 20170403@Aaron 
	Task : Get new OS Bettypes Performance  
	DB:  DBTGRS.bodb_TGRS  
	 Original:

	Revisions:
		- 20181030@Long: Adding Betcount column to OS's reports [Redmine ID: #101741]
		- 20200914@John.Ngo: Support Live/Nonlive for OSDataTGRS [Redmine ID: #140875]
		- 20250513@Della: Fix default param @LiveType (#225204)

	Param's Explanation (filtered by):
		Ex: - @ReportType = 1: Daily, 2: Monthly
			- @LiveType: -1 All; 0 Nonlive; 1 Live

*/
BEGIN
	SET NOCOUNT ON

	DECLARE @FMark			DECIMAL(18, 2)
		,	@TotalTurnover	MONEY;

	SELECT TOP 1 @FMark = ParamValue
	FROM dbo.OSParameter WITH (NOLOCK)
	WHERE ParamId = 7; -- FloorMark value

	IF OBJECT_ID('tempdb..#tmpOSBettypePerformance') IS NOT NULL
		DROP TABLE #tmpOSBettypePerformance;

	CREATE TABLE #tmpOSBettypePerformance (
			BettypeId		INT
		,	Turnover		MONEY
		,	WinLoss			MONEY
		,	Target			DECIMAL(18, 2)
		,	JuiceTurnover	MONEY
		,	JuiceWinLoss	MONEY
		,	BetCount		BIGINT
	);
	  
	CREATE CLUSTERED INDEX	#CIX_tmpOSBettypePerformance_BettypeId ON #tmpOSBettypePerformance (
		BettypeId			ASC
	);

	IF @ReportType = 1
	BEGIN
		INSERT INTO #tmpOSBettypePerformance (
				BettypeId
			,	Turnover
			,	WinLoss
			,	Target
			,	JuiceTurnover
			,	JuiceWinLoss
			,	BetCount
		)
		SELECT	td.BettypeId
			,	SUM(td.StakeMYR) AS Turnover
			,	SUM(td.Winloss - td.Comm) AS Winloss
			,	td.Target
			,	SUM(td.StakeMYRJuice) AS JuiceTurnover
			,	SUM(td.Juice) AS JuiceWinloss
			,	SUM(td.BetCount)
		FROM dbo.OSSummaryByTrader_Daily td WITH (NOLOCK)
		WHERE td.EventDate BETWEEN @FromDate AND @ToDate
			AND td.SportId = @SportId
			AND LeagueId = @LeagueId
			AND td.BettypeId IN(1,2,3,7,8,12)
			AND (@LiveType = -1 OR td.IsLive = @LiveType)
		GROUP BY td.BettypeId
			,	td.Target;
	END;
	ELSE IF @ReportType = 2
	BEGIN
		INSERT INTO #tmpOSBettypePerformance (
				BettypeId
			,	Turnover
			,	WinLoss
			,	Target
			,	JuiceTurnover
			,	JuiceWinLoss
			,	BetCount
		)
		SELECT	td.BettypeId
			,	SUM(td.StakeMYR) AS Turnover
			,	SUM(td.Winloss - td.Comm) AS Winloss
			,	td.Target
			,	SUM(td.StakeMYRJuice) AS JuiceTurnover
			,	SUM(td.Juice) AS JuiceWinloss
			,	SUM(td.BetCount)
		FROM dbo.OSSummaryByTrader_Monthly td WITH (NOLOCK)
		WHERE td.EventDate BETWEEN @FromDate AND @ToDate
			AND td.SportId = @SportId
			AND LeagueId = @LeagueId
			AND td.BettypeId IN(1,2,3,7,8,12)
			AND (@LiveType = -1 OR td.IsLive = @LiveType)
		GROUP BY td.BettypeId
			,	td.Target;
	END;

	SELECT @TotalTurnover = SUM(Turnover)
	FROM #tmpOSBettypePerformance;

	--Select
	SELECT	t.BettypeId
		,	bt.typenamee AS BettypeName
		,	SUM(Turnover) AS Turnover
		,	SUM(WinLoss) AS WinLoss
		,	SUM(JuiceTurnover) AS JuiceTurnover
		,	SUM(JuiceWinloss) AS JuiceWinloss
		,	(SUM(Turnover) * 100 / @TotalTurnover) AS AverageVTurnover
		,	(SUM(WinLoss) * (@FMark) / SUM(Turnover)) AS PointMargin
		,	SUM(t.BetCount) AS BetCount
	FROM #tmpOSBettypePerformance t WITH (NOLOCK)
		INNER JOIN bodb02.dbo.bettype bt WITH (NOLOCK) ON t.BettypeId = bt.typeid
	GROUP BY t.BettypeId
		,	bt.typenamee;

	DROP TABLE #tmpOSBettypePerformance;
END;

GO
/*<info serverAlias="DBTGRS-bodb_TGRS" executers="bodbTGRSNet" isFunction="0" isNested="0"></info>*/