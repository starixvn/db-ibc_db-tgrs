CREATE PROCEDURE [dbo].[TGRS_Rpt_ARPerformanceDetail_Bettype_League_Trader_Match] 
		@FromDate				DATE
	,	@ToDate					DATE
	,	@LeagueId				INT
	,	@CustId					INT
	,	@Bettype				SMALLINT
	,	@IsExcludeLeagues		BIT = 1
AS
/*  
	Created:	20190304@John
	Task :		New AR Detail report - View Match detail from Bet Type, League and Trader
	DB:			DBTGRS.bodb_TGRS
	Original:  
	 
	Revisions:
		- 20190304@John: Create new [Redmine ID: #108920]
	
	Example: 
		exec TGRS_Rpt_ARPerformanceDetail_Bettype_League_Trader_Match @Bettype=3,@LeagueId=3162,@FromDate='2016-03-02 00:00:00',@ToDate='2016-03-16 00:00:00',@CustId=2438
  
*/
BEGIN
	SET NOCOUNT ON;

	CREATE TABLE #TraderDetail (
		MatchId INT
		,HomeId INT
		,AwayId INT
		,EventDate DATETIME
		,Turnover MONEY
		,TurnoverJuice MONEY
		,Juice MONEY
		,WinLoss MONEY
		,WinLossScore MONEY
		,BetCount INT
		,SumCategory MONEY
	);

	INSERT INTO #TraderDetail (
		MatchId
		,HomeId
		,AwayId
		,EventDate
		,Turnover
		,WinLoss
		,WinLossScore
		,BetCount
		,TurnoverJuice
		,Juice
		,SumCategory
	)
	SELECT tp.MatchId
		,tp.HomeId
		,tp.AwayId
		,tp.EventDate
		,ISNULL(SUM(tp.StakeMYR_AR), 0) AS Turnover
		,ISNULL(SUM(tp.WinLost_AR), 0) - ISNULL(SUM(tp.Comm_AR), 0) AS WinLoss
		,SUM((tp.WinLost_AR - tp.Comm_AR) * CASE 
				WHEN tp.Spread * tm.Rate IS NULL
					THEN 0
				ELSE 1
				END) AS WinLossScore
		,ISNULL(SUM(tp.BetCount), 0) AS BetCount
		,ISNULL(SUM(tp.StakeMYRJuice_AR), 0) AS TurnoverJuice
		,ISNULL(SUM(tp.Juice_AR), 0) AS Juice
		,ISNULL(SUM(tp.StakeMYR_AR * ISNULL(s.BenchMark, tp.Spread * tm.Rate)), 0) AS SumCategory
	FROM dbo.TraderPerformance AS tp WITH (NOLOCK)
	INNER JOIN dbo.Trader AS t WITH (NOLOCK) ON t.CustId = tp.CustId
	LEFT JOIN dbo.TargetedMargin AS tm WITH (NOLOCK) ON tm.BetType = tp.BetType
		AND tm.WorkShift = tp.WorkShift
	LEFT JOIN dbo.Benchmark_SpecialSetting AS s WITH (NOLOCK) ON s.Spread = tp.Spread
		AND s.Rate = tm.Rate
	WHERE tp.CustId = @CustId
		AND tp.LeagueId = @LeagueId
		AND tp.BetType = @Bettype
		AND tp.EventDate BETWEEN @FromDate AND @ToDate
		AND tp.IsLive = 1
		AND (@IsExcludeLeagues = 0 OR (tp.LeagueId NOT IN (SELECT le.LeagueId FROM dbo.LeagueExclusion le WITH(NOLOCK))))
	GROUP BY tp.MatchId
		,tp.LeagueId
		,tp.HomeId
		,tp.AwayId
		,tp.EventDate;

	SELECT td.MatchId
		,td.HomeId
		,td.AwayId
		,td.EventDate
		,td.Turnover
		,td.WinLoss
		,td.BetCount
		,td.TurnoverJuice
		,td.Juice
		,CASE 
			WHEN td.SumCategory = 0
				THEN NULL
			ELSE td.WinLossScore * 100 / td.SumCategory
			END AS Score
	FROM #TraderDetail AS td;

	DROP TABLE #TraderDetail;
END;

GO
/*<info serverAlias="DBTGRS-bodb_TGRS" executers="bodbTGRSNet" isFunction="0" isNested="0"></info>*/