ALTER PROCEDURE [dbo].[TGRS_OS_Rpt_TraderPerformance_Sport_League_Match_Bettype]
		@SportId			INT
	,	@LeagueId			INT
	,	@MatchIds			VARCHAR(MAX) = ''
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
		- 20210226@John.Ngo: Integrate Cricket AIO [Redmine ID: #150856]

	Param's Explanation (filtered by):
		- @ReportType = 1: Daily, 2: Monthly
		- @LiveType: -1 All; 0 Nonlive; 1 Live
*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @FMark			DECIMAL(18, 2)
		,	@TotalTurnover	MONEY;

	IF	OBJECT_ID('tempdb..#tmpMatches') IS NOT NULL
	BEGIN
		DROP TABLE #tmpMatches;
	END;

	CREATE TABLE	#tmpMatches (
			MatchId				INT NOT NULL PRIMARY KEY
	);

	IF OBJECT_ID('tempdb..#tmpOSBettypePerformance') IS NOT NULL
	BEGIN
		DROP TABLE #tmpOSBettypePerformance;
	END;

	CREATE TABLE #tmpOSBettypePerformance (
			BettypeId		INT
		,	Turnover		MONEY
		,	VWinLoss		MONEY
		,	BetCount		BIGINT
	);

	CREATE CLUSTERED INDEX	#CIX_tmpOSBettypePerformance_BettypeId ON #tmpOSBettypePerformance (
		BettypeId			ASC
	);

	INSERT INTO #tmpMatches(MatchId)
	SELECT val
	FROM dbo.strSplit_Key(@MatchIds, ',');

	INSERT INTO #tmpOSBettypePerformance (
			BettypeId
		,	Turnover
		,	VWinLoss
		,	BetCount
	)
	SELECT	td.BettypeId
		,	SUM(td.Turnover) AS Turnover
		,	SUM(td.WinLoss - td.Comm) AS 'VWinLoss'
		,	SUM(td.BetCount)
	FROM dbo.OSDataTGRS td WITH (NOLOCK)
		INNER JOIN #tmpMatches AS m WITH(NOLOCK) ON td.MatchId = m.MatchId
	WHERE td.EventDate BETWEEN @FromDate AND @ToDate
		AND td.TraderId = @TraderId
		AND td.SportId = @SportId
		AND td.LeagueId = @LeagueId
		AND (@LiveType = -1 OR td.IsLive = @LiveType)
	GROUP BY td.BettypeId;
	
	SELECT @TotalTurnover = SUM(Turnover)
	FROM #tmpOSBettypePerformance;

	SELECT	t.BettypeId AS BettypeId
		,	bt.typenamee AS BettypeName
		,	SUM(t.Turnover) AS Turnover
		,	SUM(t.VWinLoss) AS VWinLoss
		,	SUM(t.BetCount) AS BetCount
	FROM #tmpOSBettypePerformance t WITH (NOLOCK)
		INNER JOIN bodb02.dbo.bettype bt WITH (NOLOCK) ON t.BettypeId = bt.typeid
	GROUP BY t.BettypeId
		,	bt.typenamee;

	DROP TABLE #tmpOSBettypePerformance;
END;

GO
/*<info serverAlias="DBTGRS-bodb_TGRS" executers="bodbTGRSNet" isFunction="0" isNested="0"></info>*/