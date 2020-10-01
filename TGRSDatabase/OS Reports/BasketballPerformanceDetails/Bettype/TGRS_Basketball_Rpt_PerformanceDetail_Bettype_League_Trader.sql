CREATE PROCEDURE [dbo].[TGRS_Basketball_Rpt_PerformanceDetail_Bettype_League_Trader]  	
		@FromDate			DATE
	,	@ToDate				DATE
	,	@LeagueId			INT
	,	@Bettype			SMALLINT
	,	@LiveType			SMALLINT = 1
AS    
/*  
	Created:	20200918@John.Ngo
	Task :		Basketball Performance Detail - Bettype - League - Trader
	DB:			DBTGRS.bodb_TGRS
	Original:  
  
	Revisions: 	
   		- 20200918@John.Ngo:	Basketball Performance Detail - Bettype - League - Trader [Redmine ID: 140875]

	Param's Explanation:  	
		- @LiveType: -1 All; 0 Nonlive; 1 Live

	 Exam: 
		  exec TGRS_Basketball_Rpt_PerformanceDetail_Bettype_League_Trader @Bettype=20,@LeagueId=10,@FromDate='2020-01-01',@ToDate='2020-12-30'
  
*/  
 
BEGIN 
	SET NOCOUNT ON;

	IF	OBJECT_ID('tempdb..#tmpTraderDetail') IS NOT NULL
	BEGIN
		DROP TABLE #tmpTraderDetail;
	END;

	CREATE TABLE	#tmpTraderDetail (
			TraderId			INT
		,	TeamId				INT
		,	MatchCount			INT
		,	Turnover			MONEY
		,	WinLoss				MONEY
		,	BetCount			INT
		,	Margin				MONEY
		,	IsLive				BIT
	);	

	CREATE CLUSTERED INDEX	#CIX_tmpTraderDetail_TraderId_TeamId ON #tmpTraderDetail (
			TraderId			ASC
		,	TeamId				ASC
	);

	INSERT INTO #tmpTraderDetail (
			TraderId
		,	IsLive
		,	MatchCount
		,	Turnover
		,	WinLoss
		,	BetCount
		,	Margin
	)
	SELECT	tp.TraderId																			AS TraderId
		,	tp.IsLive																			AS IsLive
		,	COUNT(DISTINCT tp.MatchId)															AS MatchCount
		,	ISNULL(SUM(tp.Turnover), 0)															AS Turnover
		,	ISNULL(SUM(tp.WinLoss), 0) - ISNULL(SUM(tp.Comm), 0)							    AS WinLoss
		,	ISNULL(SUM(tp.BetCount), 0)															AS BetCount
		,	CASE WHEN ISNULL(SUM(tp.Turnover), 0) <> 0 THEN (ISNULL(SUM(tp.WinLoss), 0)- ISNULL(SUM(tp.Comm), 0)) * 100/ISNULL(SUM(tp.Turnover), 0) ELSE NULL END AS Margin	
	FROM	dbo.OSDataTGRS AS tp WITH (NOLOCK)
	WHERE	tp.LeagueId = @LeagueId
			AND	tp.BettypeId = @Bettype
			AND	tp.EventDate BETWEEN @FromDate AND @ToDate			
			AND tp.SportId = 2
			AND (@LiveType = -1 OR tp.IsLive = @LiveType)
	GROUP BY	tp.TraderId, tp.IsLive;
	
	SELECT	td.TraderId
		,	t.TraderName
		,	t.GradeId
		,	t.TeamId
		,	tm.TeamName
		,	td.MatchCount
		,	td.Turnover
		,	td.WinLoss
		,	td.BetCount
		,	td.Margin
		,	td.IsLive
	FROM		#tmpTraderDetail AS td WITH (NOLOCK)
	INNER JOIN	dbo.OSTrader AS t WITH (NOLOCK) ON	t.TraderId = td.TraderId
	LEFT JOIN	dbo.OSTeam AS tm WITH (NOLOCK) 	ON	t.TeamId = tm.TeamId
	ORDER BY	td.Margin DESC, t.TraderName ASC;
	
	DROP TABLE #tmpTraderDetail;

END;

GO
/*<info serverAlias="DBTGRS-bodb_TGRS" executers="bodbTGRSNet" isFunction="0" isNested="0"></info>*/