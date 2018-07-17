
SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

ALTER PROCEDURE [dbo].[TGRS_OS_Rpt_TraderPerformance_Sport_League_Match_Bettype]
		@SportId			INT
	,	@LeagueId			INT
	,	@MatchId			INT
	,	@TraderId			INT
	,	@FromDate			DATE
	,	@ToDate				DATE
AS	
/*  
	Created: 20180716@Long
	Task : Get OS Bettypes Performance  
	DB:  DBTGRS.bodb_TGRS  
	  
	Revisions:  

	Ex: @ReportType = 1: Daily, 2: Monthly

*/

BEGIN
	SET NOCOUNT ON;

	DECLARE @FMark			DECIMAL(18, 2)
		,	@TotalTurnover	MONEY;

	IF OBJECT_ID('tempdb..#tmpOSBettypePerformance') IS NOT NULL
	BEGIN
		DROP TABLE #tmpOSBettypePerformance
	END;

	CREATE TABLE #tmpOSBettypePerformance (
			BettypeId		INT
		,	Turnover		MONEY
		,	VWinLoss		MONEY
	);

	INSERT INTO #tmpOSBettypePerformance (
			BettypeId
		,	Turnover
		,	VWinLoss
	)
	SELECT	td.BettypeId
		,	SUM(td.Turnover) AS Turnover
		,	SUM(td.WinLoss - td.Comm) AS 'VWinLoss'
	FROM dbo.OSDataTGRS td WITH (NOLOCK)
	WHERE td.EventDate BETWEEN @FromDate AND @ToDate
		AND td.TraderId = @TraderId
		AND td.SportId = @SportId
		AND td.LeagueId = @LeagueId
		AND td.MatchId = @MatchId
	GROUP BY td.BettypeId;
	
	SELECT @TotalTurnover = SUM(Turnover)
	FROM #tmpOSBettypePerformance;

	SELECT	t.BettypeId AS BettypeId
		,	bt.typenamee AS BettypeName
		,	SUM(Turnover) AS Turnover
		,	SUM(VWinLoss) AS 'VWinLoss'
	FROM #tmpOSBettypePerformance t WITH (NOLOCK)
		INNER JOIN bodb02.dbo.bettype bt WITH (NOLOCK) ON t.BettypeId = bt.typeid
	GROUP BY t.BettypeId
		,	bt.typenamee;

	DROP TABLE #tmpOSBettypePerformance;
END;

/*   
GO  
GRANT EXECUTE ON [dbo].[TGRS_OS_Rpt_TraderPerformance_Sport_League_Match_Bettype] TO [bodbTGRSNet]  
GO  
GRANT VIEW DEFINITION ON [dbo].[TGRS_OS_Rpt_TraderPerformance_Sport_League_Match_Bettype] TO [bodbTGRSNet]  
GO  
*/


