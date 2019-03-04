CREATE PROCEDURE [dbo].[TGRS_Rpt_ARPerformanceDetail_League_Trader_Match_Bettype] 
	 @FromDate DATE
	,@ToDate DATE
	,@LeagueId INT
	,@CustId INT
	,@MatchId INT
	,@IsExcludeLeagues	BIT = 1
AS
/* 
	Created:	20190304@John
	Task :		New AR Detail report League Performance - Detail Bettype based on League, Trader and Match
	DB:			DBTGRS.bodb_TGRS
	Original:  
	 
	Revisions:
		- 20190304@John: Create new [Redmine ID: #108920]

 Exam: 
				
		exec TGRS_Rpt_ARPerformanceDetail_League_Trader_Match_Bettype @FromDate='2016-02-15 00:00:00',@LeagueId=30730,@CustId=14228019,@MatchId=16922489,@ToDate='2016-02-29 00:00:00'	
  
*/
BEGIN
	SET NOCOUNT ON;

	CREATE TABLE #BettypeDetail (
		BetType SMALLINT
		,TypeName NVARCHAR(100)
		,Turnover MONEY
		,TurnoverJuice MONEY
		,Juice MONEY
		,WinLoss MONEY
		,WinLossScore MONEY
		,BetCount INT
		,SumCategory MONEY
	);

	INSERT INTO #BettypeDetail (
		BetType
		,TypeName
		,Turnover
		,TurnoverJuice
		,Juice
		,WinLoss
		,WinLossScore
		,BetCount
		,SumCategory
	)
	SELECT tp.BetType
		,TN.TypeName
		,ISNULL(SUM(tp.StakeMYR_AR), 0) AS Turnover
		,ISNULL(SUM(tp.StakeMYRJuice_AR), 0) AS TurnoverJuice
		,ISNULL(SUM(tp.Juice_AR), 0) AS Juice
		,ISNULL(SUM(tp.WinLost_AR), 0) - ISNULL(SUM(tp.Comm_AR), 0) AS WinLoss
		,SUM((tp.WinLost_AR - tp.Comm_AR) * CASE 
				WHEN tp.Spread * tm.Rate IS NULL
					THEN 0
				ELSE 1
				END) AS WinLossScore
		,ISNULL(SUM(tp.BetCount), 0) AS BetCount
		,ISNULL(SUM(tp.StakeMYR_AR * ISNULL(s.BenchMark, tp.Spread * tm.Rate)), 0) AS SumCategory
	FROM dbo.TraderPerformance AS tp WITH (NOLOCK)
		INNER JOIN dbo.Trader AS t WITH (NOLOCK) ON t.CustId = tp.CustId
		LEFT JOIN dbo.TargetedMargin AS tm WITH (NOLOCK) ON tm.BetType = tp.BetType
			AND tm.WorkShift = tp.WorkShift
		LEFT JOIN dbo.Benchmark_SpecialSetting AS s WITH (NOLOCK) ON s.Spread = tp.Spread
			AND s.Rate = tm.Rate
		LEFT JOIN dbo.BetType TN WITH (NOLOCK) ON TN.BetType = tp.BetType
	WHERE tp.CustId = @CustId
		AND tp.LeagueId = @LeagueId
		AND tp.MatchId = @MatchId
		AND tp.EventDate BETWEEN @FromDate AND @ToDate
		AND TN.MainDBBetType IN (1,3,7,8)
		AND TN.[Disabled] = 0
		AND tp.IsLive = 1
		AND (@IsExcludeLeagues = 0 OR (tp.LeagueId NOT IN (SELECT le.LeagueId FROM dbo.LeagueExclusion le WITH(NOLOCK))))
	GROUP BY tp.BetType
		,TN.TypeName;

	SELECT bd.BetType
		,bd.TypeName
		,bd.Turnover
		,bd.WinLoss
		,bd.BetCount
		,bd.TurnoverJuice
		,bd.Juice
		,CASE 
			WHEN bd.SumCategory = 0
				THEN NULL
			ELSE bd.WinLossScore * 100 / bd.SumCategory
			END AS Score
	FROM #BettypeDetail AS bd;

	DROP TABLE #BettypeDetail;
END

GO
/*<info serverAlias="DBTGRS-bodb_TGRS" executers="bodbTGRSNet" isFunction="0" isNested="0"></info>*/