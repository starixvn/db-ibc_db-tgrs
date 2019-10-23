ALTER PROCEDURE [dbo].[TGRS_Rpt_ARPerformanceDetail_Team_Trader_Match_Bettype] 
		@FromDate			DATE
	,	@ToDate				DATE
	,	@CustId				INT
	,	@MatchId			INT
	,	@IsExcludeLeagues	BIT = 1
	,	@Market				SMALLINT = 1
AS
/* 
	Created:	20190304@John
	Task :		New AR Performance Details (Juice & Leftover) Report - Team - Trader - Match - Bettype
	DB:			DBTGRS.bodb_TGRS
	Original:  
	 
	Revisions:
		- 20190304@John: Create new [Redmine ID: #108920]	
		- 20190919@John.Ngo:	Support Nonlive Data [Redmine ID: 118959]
		- 20191023@John.Ngo:	Enhance performance [Redmine ID: 121268]

	Param's Explanation (filtered by):
		- @Market:	-1 All; 0 Nonlive; 1 Live
			
	Exam:		
		exec TGRS_Rpt_ARPerformanceDetail_Team_Trader_Match_Bettype @FromDate='2019-02-15 00:00:00', @ToDate='2019-03-05 00:00:00', @CustId=14228019,@MatchId=16922489	
  
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
		,IsLive BIT
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
		,IsLive
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
		,tp.IsLive
	FROM dbo.TraderPerformance AS tp WITH (NOLOCK)
		INNER JOIN dbo.Trader AS t WITH (NOLOCK) ON t.CustId = tp.CustId
		LEFT JOIN dbo.TargetedMargin AS tm WITH (NOLOCK) ON tm.BetType = tp.BetType
			AND tm.WorkShift = tp.WorkShift
		LEFT JOIN dbo.Benchmark_SpecialSetting AS s WITH (NOLOCK) ON s.Spread = tp.Spread
			AND s.Rate = tm.Rate
		LEFT JOIN dbo.BetType TN WITH (NOLOCK) ON TN.BetType = tp.BetType
		LEFT JOIN dbo.LeagueExclusion le WITH(NOLOCK) ON tp.LeagueId = le.LeagueId
	WHERE tp.CustId = @CustId
		AND tp.MatchId = @MatchId
		AND tp.EventDate BETWEEN @FromDate
			AND @ToDate
		AND TN.MainDBBetType IN (1,3,7,8)
		AND TN.[Disabled] = 0
		AND (@Market = -1 OR tp.IsLive = @Market)
		AND (@IsExcludeLeagues = 0 OR le.LeagueId IS NULL)
	GROUP BY tp.BetType
		,TN.TypeName
		,tp.IsLive;

	SELECT bd.BetType
		,bd.TypeName
		,bd.Turnover
		,bd.TurnoverJuice
		,bd.Juice
		,bd.WinLoss
		,bd.BetCount
		,CASE 
			WHEN bd.SumCategory = 0
				THEN NULL
			ELSE bd.WinLossScore * 100 / bd.SumCategory
			END AS Score
		,bd.IsLive
	FROM #BettypeDetail AS bd;

	DROP TABLE #BettypeDetail;
END

GO
/*<info serverAlias="DBTGRS-bodb_TGRS" executers="bodbTGRSNet" isFunction="0" isNested="0"></info>*/