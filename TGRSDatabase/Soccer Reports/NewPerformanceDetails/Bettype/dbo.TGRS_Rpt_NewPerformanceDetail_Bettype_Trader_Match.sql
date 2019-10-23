ALTER PROCEDURE [dbo].[TGRS_Rpt_NewPerformanceDetail_Bettype_Trader_Match] 
		@FromDate				DATE
	,	@ToDate					DATE
	,	@CustId					INT
	,	@Bettype				SMALLINT
	,	@IsExcludeLeagues		BIT = 1
	,	@Market					SMALLINT = 1
AS
/*  
	Created:	20170110@Aaron
	Task:		New Detail report - View Match detail from Bet Type, League and Trader
	DB:			DBTGRS.bodb_TGRS
	Original:      
	  		
	Revisions:
		- 20170316@Long.Luu:	apply TO's Leftover
		- 20171205@Simon:		get only Live data & Bettypes are not disabled
		- 20180911@Long.Luu:	Support excluding Leagues from report [Redmine ID: #100322]  
		- 20190919@Long.Luu:	Support Nonlive Data [Redmine ID: 118959]
		- 20191023@John.Ngo:	Enhance performance [Redmine ID: 121268]
		
	Param's Explanation:  
		- @Market: -1 All; 0 Nonlive; 1 Live	
	
	Example: 
		exec [TGRS_Rpt_PerformanceDetail_Bettype_Trader_Match] @Bettype=3,@FromDate='2016-03-02 00:00:00',@ToDate='2016-03-16 00:00:00',@CustId=2438
  
*/
BEGIN
	SET NOCOUNT ON;

	CREATE TABLE #TraderDetail (
			MatchId			INT
		,	LeagueId		INT
		,	HomeId			INT
		,	AwayId			INT
		,	EventDate		DATETIME
		,	Turnover		MONEY
		,	TurnoverJuice	MONEY
		,	Juice			MONEY
		,	WinLoss			MONEY
		,	WinLossScore	MONEY
		,	BetCount		INT
		,	SumCategory		MONEY
		,	IsLive			BIT
	);

	INSERT INTO #TraderDetail (
			MatchId
		,	LeagueId
		,	HomeId
		,	AwayId
		,	EventDate
		,	IsLive
		,	Turnover
		,	TurnoverJuice
		,	Juice
		,	WinLoss
		,	WinLossScore
		,	BetCount
		,	SumCategory
	)
	SELECT	tp.MatchId
		,	tp.LeagueId
		,	tp.HomeId
		,	tp.AwayId
		,	tp.EventDate
		,	tp.IsLive
		,	ISNULL(SUM(tp.StakeMYR), 0) AS Turnover
		,	ISNULL(SUM(tp.StakeMYRJuice), 0) AS TurnoverJuice
		,	ISNULL(SUM(tp.Juice), 0) AS Juice
		,	ISNULL(SUM(tp.WinLost), 0) - ISNULL(SUM(tp.Comm), 0) AS WinLoss
		,	SUM((tp.WinLost - tp.Comm) * CASE 
				WHEN tp.Spread * tm.Rate IS NULL
					THEN 0
				ELSE 1
				END) AS WinLossScore
		,	ISNULL(SUM(tp.BetCount), 0) AS BetCount
		,	ISNULL(SUM(tp.StakeMYR * ISNULL(s.BenchMark, tp.Spread * tm.Rate)), 0) AS SumCategory
	FROM dbo.TraderPerformance AS tp WITH (NOLOCK)
		INNER JOIN dbo.Trader AS t WITH (NOLOCK) ON t.CustId = tp.CustId
		LEFT JOIN dbo.TargetedMargin AS tm WITH (NOLOCK) ON tm.BetType = tp.BetType AND tm.WorkShift = tp.WorkShift
		LEFT JOIN dbo.Benchmark_SpecialSetting AS s WITH (NOLOCK) ON s.Spread = tp.Spread AND s.Rate = tm.Rate
		LEFT JOIN dbo.LeagueExclusion le WITH(NOLOCK) ON tp.LeagueId = le.LeagueId
	WHERE tp.CustId = @CustId
		AND tp.BetType = @Bettype
		AND tp.EventDate BETWEEN @FromDate AND @ToDate
		AND (@Market = -1 OR tp.IsLive = @Market)
		AND (@IsExcludeLeagues = 0 OR le.LeagueId IS NULL)
	GROUP BY tp.MatchId
		,	tp.LeagueId
		,	tp.HomeId
		,	tp.AwayId
		,	tp.EventDate
		,	tp.IsLive;

	SELECT	td.MatchId
		,	td.LeagueId
		,	td.HomeId
		,	td.AwayId
		,	td.EventDate
		,	td.IsLive
		,	td.Turnover
		,	td.Turnover
		,	td.WinLoss
		,	td.TurnoverJuice
		,	td.Juice
		,	td.BetCount
		,	CASE 
				WHEN td.SumCategory = 0
					THEN NULL
				ELSE td.WinLossScore * 100 / td.SumCategory
				END AS Score
	FROM #TraderDetail AS td WITH(NOLOCK);

	DROP TABLE #TraderDetail;
END;

GO
/*<info serverAlias="DBTGRS-bodb_TGRS" executers="bodbTGRSNet" isFunction="0" isNested="0"></info>*/