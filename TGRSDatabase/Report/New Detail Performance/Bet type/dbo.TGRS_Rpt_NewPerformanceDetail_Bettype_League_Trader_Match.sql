
/****** Object:  Stored Procedure dbo.TGRS_Rpt_NewPerformanceDetail_Bettype_League_Trader_Match    Script Date: 1/17/2017 11:20:00 AM ******/

/****** Object:  Stored Procedure dbo.TGRS_Rpt_PerformanceDetail_Bettype_League_Trader_Match    Script Date: 3/23/2016 11:22:34 PM ******/
/****** Object:  Stored Procedure dbo.TGRS_Rpt_PerformanceDetail_Bettype_League_Trader_Match    Script Date: 3/22/2016 12:48:53 PM ******/
CREATE PROCEDURE [dbo].[TGRS_Rpt_NewPerformanceDetail_Bettype_League_Trader_Match] 
	 @FromDate DATE
	,@ToDate DATE
	,@LeagueId INT
	,@CustId INT
	,@Bettype SMALLINT
AS
/*  
	Created:	20170110@Aaron
	Task:		New Detail report - View Match detail from Bet Type, League and Trader
	DB:			DBTGRS.bodb_TGRS
	Original:
	  			
	Revision:
		- 20171205@Simon: get only Live data & Bettypes are not disabled

	Param's Explanation:  	
	
	Example: 
		exec TGRS_Rpt_NewPerformanceDetail_Bettype_League_Trader_Match @Bettype=3,@LeagueId=3162,@FromDate='2016-03-02 00:00:00',@ToDate='2016-03-16 00:00:00',@CustId=2438
  
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
		,ISNULL(SUM(tp.StakeMYR), 0) AS Turnover
		,ISNULL(SUM(tp.WinLost), 0) - ISNULL(SUM(tp.Comm), 0) AS WinLoss
		,SUM((tp.WinLost - tp.Comm) * CASE 
				WHEN tp.Spread * tm.Rate IS NULL
					THEN 0
				ELSE 1
				END) AS WinLossScore
		,ISNULL(SUM(tp.BetCount), 0) AS BetCount
		,ISNULL(SUM(tp.StakeMYRJuice), 0) AS TurnoverJuice
		,ISNULL(SUM(tp.Juice), 0) AS Juice
		,ISNULL(SUM(tp.StakeMYR * ISNULL(s.BenchMark, tp.Spread * tm.Rate)), 0) AS SumCategory
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

/*
GO
GRANT EXECUTE ON [dbo].[TGRS_Rpt_NewPerformanceDetail_Bettype_League_Trader_Match] TO [bodbTGRSNet]
GO
GRANT VIEW DEFINITION ON [dbo].[TGRS_Rpt_NewPerformanceDetail_Bettype_League_Trader_Match] TO [bodbTGRSNet ]
GO
*/