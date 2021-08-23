ALTER PROCEDURE [dbo].[TGRS_Rpt_PerformanceDetail_Bettype_League_Trader]  	
	@FromDate			DATE,
	@ToDate				DATE,		
	@LeagueId			INT,
	@Bettype			SMALLINT,
	@IsExcludeLeagues	BIT = 1,
	@Market				SMALLINT = 1
AS    
/*  
	 Created:	20160315@Thai.Tran
	 Task :		Detail report - Trader detail from Bet Type and League
	 DB:		DB06.bodb_TGRS_UAT & DB061.bodb_TGRS
	 Original:  
 
	 Revisions:      	
		- 20171205@Simon:		get only Live data & Bettypes are not disabled
		- 20180912@Simon:		add league exclusion
		- 20190919@Long.Luu:	Support Nonlive Data [Redmine ID: 118959]
		- 20191023@John.Ngo:	Enhance performance [Redmine ID: 121268]
		- 202100809@Adam.Tran: 	Sports - Performance Real Figures [Redmine: #158981]

	 Param's Explanation:  	
		- @Market: -1 All; 0 Nonlive; 1 Live  

	 Exam: 
		  exec TGRS_Rpt_PerformanceDetail_Bettype_League_Trader @Bettype=3,@LeagueId=10,@FromDate='2016-03-02 00:00:00',@ToDate='2016-03-16 00:00:00'
  
*/  
 
BEGIN 
	SET NOCOUNT ON;	

   CREATE TABLE	#tmpTraderDetail (
			CustID				INT
		,	TeamId				INT
		,	MatchCount			INT
		,	Turnover			MONEY
		,	WinLoss				MONEY
		,	WinLossScore		MONEY
		,	BetCount			INT
		,	Margin				MONEY
		,	TurnoverReal		MONEY
		,	WinLossReal			MONEY
		,	MarginReal			MONEY
		,	SumCategory			MONEY
		,	IsLive				BIT
	);		
	   
    INSERT INTO #tmpTraderDetail (
			CustID
		,	IsLive
		,	MatchCount
		,	Turnover
		,	WinLoss
		,	WinLossScore
		,	BetCount
		,	Margin
		,	TurnoverReal
		,	WinLossReal
		,	MarginReal
		,	SumCategory)
	SELECT	tp.CustId																			AS CustId
		,	tp.IsLive																			AS IsLive
		,	COUNT(DISTINCT tp.MatchId)															AS MatchCount
		,	ISNULL(SUM(tp.Stake), 0)															AS Turnover
		,	ISNULL(SUM(tp.WinLost), 0) - ISNULL(SUM(tp.Comm), 0)							    AS WinLoss		
		,	SUM( (tp.WinLost - tp.Comm) * CASE WHEN tp.Spread * tm.Rate IS NULL THEN 0 ELSE 1 END) 	AS WinLossScore	
		,	ISNULL(SUM(tp.BetCount), 0)															AS BetCount
		,	CASE   WHEN SUM(tp.Stake) = 0 THEN NULL
				   ELSE (SUM(tp.WinLost) - SUM(tp.Comm)) * 100 / SUM(tp.Stake) END				AS Margin
		,	ISNULL(SUM(tp.Stake_Real),0) 														AS TurnoverReal		
		,	ISNULL(SUM(CASE WHEN tp.Is8RM = 0 THEN tp.WinLost_Real ELSE 0 END),0) 				AS WinLossReal
		,	CASE WHEN ISNULL(SUM(tp.Stake_Real),0) <> 0 THEN ISNULL(SUM(CASE WHEN tp.Is8RM = 0 THEN tp.WinLost_Real ELSE 0 END),0) * 100/ISNULL(SUM(tp.Stake_Real),0) ELSE NULL END AS MarginReal
		,	ISNULL(SUM(tp.Stake * ISNULL(s.BenchMark, tp.Spread * tm.Rate)), 0) AS SumCategory
	FROM		dbo.TraderPerformance AS tp WITH (NOLOCK)
		LEFT JOIN	dbo.TargetedMargin AS tm WITH (NOLOCK) ON tm.BetType = tp.BetType
			AND	tm.WorkShift = tp.WorkShift
		LEFT JOIN dbo.Benchmark_SpecialSetting AS s WITH (NOLOCK) ON s.Spread = tp.Spread
			AND	s.Rate = tm.Rate
		LEFT JOIN dbo.LeagueExclusion le WITH(NOLOCK) ON tp.LeagueId = le.LeagueId
	WHERE	tp.LeagueId = @LeagueId
			AND	tp.BetType = @Bettype
			AND	 tp.EventDate BETWEEN @FromDate AND @ToDate			
			AND (@Market = -1 OR tp.IsLive = @Market)
			AND (@IsExcludeLeagues = 0 OR le.LeagueId IS NULL)
	GROUP BY	tp.CustId, tp.IsLive;	
	
	SELECT	td.CustID
		,	t.Username
		,	t.Grade
		,	t.TeamId
		,	tm.TeamName
		,	td.MatchCount
		,	td.Turnover
		,	td.WinLoss
		,	td.BetCount
		,	td.Margin
		,	td.TurnoverReal
		,	td.WinLossReal
		,	td.MarginReal
		,	CASE WHEN td.SumCategory = 0 THEN NULL ELSE td.WinLossScore * 100 / td.SumCategory END AS Score
		,	td.IsLive
	FROM #tmpTraderDetail AS td WITH (NOLOCK)
		INNER JOIN	dbo.Trader AS t WITH (NOLOCK) ON t.CustId = td.CustID
		INNER JOIN	dbo.Team AS tm WITH (NOLOCK) ON	t.TeamId = tm.TeamId
	ORDER BY td.Margin DESC, t.Username ASC;
	
	DROP TABLE #tmpTraderDetail;	
END;

GO

/*<info serverAlias="DB06-bodb_TGRS_UAT" executers="bodbTGRSNet" isFunction="0" isNested="0"></info>*/