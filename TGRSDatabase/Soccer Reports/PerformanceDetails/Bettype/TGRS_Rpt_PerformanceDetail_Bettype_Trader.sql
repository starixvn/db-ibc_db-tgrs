ALTER PROCEDURE [dbo].[TGRS_Rpt_PerformanceDetail_Bettype_Trader]  	
	@FromDate			DATE,
	@ToDate				DATE,			
	@Bettype			SMALLINT,
	@IsExcludeLeagues	BIT = 1,
	@Market				SMALLINT = 1
AS    
/*  
	Created:	20160329@Thai.Tran
	Task :		Detail report - Trader detail from Bet Type
	DB:		DBTGRS.bodb_TGRS
	Original:  
 
	Revisions:      	
		- 20171205@Simon:		get only Live data & Bettypes are not disabled
		- 20180912@Simon:		add league exclusion
		- 20190919@Long.Luu:	Support Nonlive Data [Redmine ID: 118959]
 
	Param's Explanation:  
		- @Market: -1 All; 0 Nonlive; 1 Live 	

	Exam: 
		exec [TGRS_Rpt_PerformanceDetail_Bettype_Trader] @Bettype=3,@FromDate='2016-03-02 00:00:00',@ToDate='2016-03-16 00:00:00'
  
*/  
 
BEGIN 
	SET NOCOUNT ON;

	CREATE TABLE	#TraderDetail (
			CustID				INT
		,	TeamId				INT
		,	LeagueCount			INT				
		,	MatchCount			INT
		,	Turnover			MONEY
		,	WinLoss				MONEY
		,	WinLossScore		MONEY
		,	BetCount			INT
		,	Margin				MONEY
		,	SumCategory			MONEY
		,	IsLive				BIT
	);	
	   
	INSERT INTO #TraderDetail (
			CustID
		,	IsLive
		,	LeagueCount
		,	MatchCount
		,	Turnover
		,	WinLoss
		,	WinLossScore
		,	BetCount
		,	Margin
		,	SumCategory
	)
	SELECT	tp.CustId																			AS CustId
		,	tp.IsLive																			AS IsLive
		,	COUNT(DISTINCT tp.LeagueId)															AS LeagueCount
		,	COUNT(DISTINCT tp.MatchId)															AS MatchCount
		,	ISNULL(SUM(tp.Stake), 0)															AS Turnover
		,	ISNULL(SUM(tp.WinLost), 0) - ISNULL(SUM(tp.Comm), 0)							    AS WinLoss		
		,	SUM( (tp.WinLost - tp.Comm) * CASE WHEN tp.Spread * tm.Rate IS NULL THEN 0 ELSE 1 END) 	AS WinLossScore	
		,	ISNULL(SUM(tp.BetCount), 0)															AS BetCount
		,	CASE   WHEN SUM(tp.Stake) = 0 THEN NULL
					ELSE (SUM(tp.WinLost) - SUM(tp.Comm)) * 100 / SUM(tp.Stake) END				AS Margin		
		,	ISNULL(SUM(tp.Stake * ISNULL(s.BenchMark, tp.Spread * tm.Rate)), 0) AS SumCategory
	FROM		dbo.TraderPerformance AS tp WITH (NOLOCK)
	LEFT JOIN	dbo.TargetedMargin AS tm WITH (NOLOCK)
			ON	tm.BetType = tp.BetType
			AND	tm.WorkShift = tp.WorkShift
	LEFT JOIN dbo.Benchmark_SpecialSetting AS s WITH (NOLOCK)
			ON	s.Spread = tp.Spread
			AND	s.Rate = tm.Rate
	WHERE	tp.BetType = @Bettype
			AND	 tp.EventDate BETWEEN @FromDate AND @ToDate		
			AND (@Market = -1 OR tp.IsLive = @Market)
			AND (@IsExcludeLeagues = 0 OR (tp.LeagueId NOT IN (SELECT le.LeagueId FROM dbo.LeagueExclusion AS le WITH(NOLOCK))))
	GROUP BY	tp.CustId, tp.IsLive;
	
	SELECT	td.CustID
		,	t.Username
		,	t.Grade
		,	t.TeamId
		,	tm.TeamName
		,	td.LeagueCount
		,	td.MatchCount
		,	td.Turnover
		,	td.WinLoss
		,	td.BetCount
		,	td.Margin
		,	CASE WHEN td.SumCategory = 0 THEN NULL ELSE td.WinLossScore * 100 / td.SumCategory END AS Score
		,	td.IsLive
	FROM		#TraderDetail AS td WITH (NOLOCK)
	INNER JOIN	dbo.Trader AS t WITH (NOLOCK)
			ON	t.CustId = td.CustID
	INNER JOIN	dbo.Team AS tm WITH (NOLOCK) 
			ON	t.TeamId = tm.TeamId
	ORDER BY	td.Margin DESC, t.Username ASC;
	
	DROP TABLE #TraderDetail;
END;

GO
/*<info serverAlias="DBTGRS-bodb_TGRS" executers="bodbTGRSNet" isFunction="0" isNested="0"></info>*/