ALTER PROCEDURE [dbo].[TGRS_OS_Rpt_TraderPerformance_Sport_League_Bettype]
		@SportId			INT
	,	@LeagueId			INT
	,	@TraderId			INT
	,	@FromDate			DATE
	,	@ToDate				DATE
	,	@LiveType			SMALLINT = 1
AS	
/*  
	Created: 20180716@Long
	Task : Get OS Bettypes Performance  
	DB:  DBTGRS.bodb_TGRS  
	  
	Revisions:  	
		- 20181030@Long: Adding Betcount column to OS's reports [Redmine ID: #101741]
		- 20200914@John.Ngo: Support Live/Nonlive for OSDataTGRS [Redmine ID: #140875]
		- 20230103@John.Ngo: [TGS OS] Allow view data details into Map/Game/Set [Redmine ID: 182351]
		
	Param's Explanation (filtered by):
		- @ReportType = 1: Daily, 2: Monthly
		- @LiveType: -1 All; 0 Nonlive; 1 Live
*/

BEGIN
	SET NOCOUNT ON;

	DECLARE @FMark			DECIMAL(18, 2)
		,	@TotalTurnover	MONEY;

	SELECT TOP(1) @FMark = ParamValue
	FROM dbo.OSParameter WITH (NOLOCK)
	WHERE ParamId = 7; -- FloorMark value

	IF OBJECT_ID('tempdb..#tmpOSBettypePerformance') IS NOT NULL
	BEGIN
		DROP TABLE #tmpOSBettypePerformance;
	END;

	CREATE TABLE #tmpOSBettypePerformance (
			BettypeId		INT
		,	BetId			BIGINT
		,	Turnover		MONEY
		,	VWinLoss		MONEY
		,	BetCount		BIGINT
	);

	INSERT INTO #tmpOSBettypePerformance (
			BettypeId
		,	BetId
		,	Turnover
		,	VWinLoss
		,	BetCount
	)
	SELECT	P.BettypeId
		,	CASE WHEN (P.SportId = 43 AND P.BettypeId BETWEEN 9001 AND 9142) THEN P.BetId ELSE 0 END
		,	SUM(P.Turnover) AS Turnover
		,	SUM(P.WinLoss - P.Comm) AS 'VWinLoss'
		,	SUM(P.BetCount)
	FROM dbo.OSDataTGRS_BetChoice AS P WITH (NOLOCK)
	WHERE P.TraderId = @TraderId
		AND P.EventDate BETWEEN @FromDate AND @ToDate
		AND P.SportId = @SportId
		AND P.LeagueId = @LeagueId
		AND (@LiveType = -1 OR P.IsLive = @LiveType)
	GROUP BY P.BettypeId
		,	CASE WHEN (P.SportId = 43 AND P.BettypeId BETWEEN 9001 AND 9142) THEN P.BetId ELSE 0 END;

	SELECT @TotalTurnover = SUM(Turnover)
	FROM #tmpOSBettypePerformance WITH(NOLOCK);

	SELECT	t.BettypeId
		,	t.BetId
		,	SUM(Turnover) AS Turnover
		,	SUM(VWinLoss) AS 'VWinLoss'
		,	(SUM(VWinLoss) * 100 / SUM(Turnover)) AS 'VMargin'
		,	(SUM(Turnover) * 100 / @TotalTurnover) AS 'AverageVTurnover'
		,	(SUM(VWinLoss) * (@FMark) / SUM(Turnover)) AS 'PointMargin'
		,	SUM(t.BetCount) AS BetCount
	FROM #tmpOSBettypePerformance t WITH (NOLOCK)
	GROUP BY t.BettypeId
		,	t.BetId;

	DROP TABLE #tmpOSBettypePerformance;
END;

GO
/*<info serverAlias="DBTGRS-bodb_TGRS" executers="bodbTGRSNet" isFunction="0" isNested="0"></info>*/