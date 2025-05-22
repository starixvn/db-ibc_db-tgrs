/*<info serverAlias="DBTGRS-bodb_TGRS" executers="wsv_tgrs" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[TGRS_OS_Rpt_TraderPerformance_Sport_League_Match_Bettype]
		@SportId			INT
	,	@LeagueId			INT
	,	@MatchIds			VARCHAR(MAX) = ''
	,	@TraderId			INT
	,	@FromDate			DATE
	,	@ToDate				DATE
	,	@LiveType			SMALLINT = -1
AS	
/*  
	Created: 20180716@Long
	Task : Get OS Bettypes Performance  
	DB:  DBTGRS.bodb_TGRS  
	  
	Revisions:  
		- 20181030@Long: Adding Betcount column to OS's reports [Redmine ID: #101741]
		- 20200914@John.Ngo: Support Live/Nonlive for OSDataTGRS [Redmine ID: #140875]
		- 20210226@John.Ngo: Integrate Cricket AIO [Redmine ID: #150856]
		- 20230103@John.Ngo: [TGS OS] Allow view data details into Map/Game/Set [Redmine ID: 182351]
		- 20250514@Della: Fix default param @LiveType (#225204)

	Param's Explanation (filtered by):
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
		,	BetId			BIGINT
		,	Turnover		MONEY
		,	VWinLoss		MONEY
		,	BetCount		BIGINT
	);

	CREATE CLUSTERED INDEX	#CIX_tmpOSBettypePerformance_BettypeId ON #tmpOSBettypePerformance (
			BettypeId		ASC
		,	BetId			ASC
	);

	INSERT INTO #tmpMatches(MatchId)
	SELECT val
	FROM dbo.strSplit_Key(@MatchIds, ',');

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
		INNER JOIN #tmpMatches AS m WITH(NOLOCK) ON P.MatchId = m.MatchId
	WHERE P.EventDate BETWEEN @FromDate AND @ToDate
		AND P.TraderId = @TraderId
		AND P.SportId = @SportId
		AND P.LeagueId = @LeagueId
		AND (@LiveType = -1 OR P.IsLive = @LiveType)
	GROUP BY P.BettypeId
		,	CASE WHEN (P.SportId = 43 AND P.BettypeId BETWEEN 9001 AND 9142) THEN P.BetId ELSE 0 END;
	
	SELECT @TotalTurnover = SUM(Turnover)
	FROM #tmpOSBettypePerformance;

	SELECT	t.BettypeId AS BettypeId
		,	t.BetId AS BetId
		,	SUM(t.Turnover) AS Turnover
		,	SUM(t.VWinLoss) AS VWinLoss
		,	SUM(t.BetCount) AS BetCount
	FROM #tmpOSBettypePerformance t WITH (NOLOCK)
	GROUP BY t.BettypeId
		,	t.BetId;

	DROP TABLE #tmpOSBettypePerformance;
END;

GO
/*<info serverAlias="DBTGRS-bodb_TGRS" executers="bodbTGRSNet" isFunction="0" isNested="0"></info>*/