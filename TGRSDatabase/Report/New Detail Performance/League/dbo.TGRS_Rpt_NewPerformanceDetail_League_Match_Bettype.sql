
/****** Object:  Stored Procedure dbo.TGRS_Rpt_NewPerformanceDetail_League_Match_Bettype    Script Date: 1/17/2017 11:20:01 AM ******/

/****** Object:  Stored Procedure dbo.TGRS_Rpt_PerformanceDetail_League_Trader_Match_Bettype    Script Date: 3/23/2016 11:22:31 PM ******/
/****** Object:  Stored Procedure dbo.TGRS_Rpt_PerformanceDetail_League_Trader_Match_Bettype    Script Date: 3/22/2016 12:48:52 PM ******/
CREATE PROCEDURE [dbo].[TGRS_Rpt_NewPerformanceDetail_League_Match_Bettype] 
	 @FromDate DATE
	,@ToDate DATE
	,@LeagueId INT
	,@MatchId INT
AS
/*  
 Created:	20170106@Aaron
 Task :		New Detail report League Performance - Detail Bettype based on League and Match
 DB:		DBTGRS.bodb_TGRS
 Original:  
  
 Revisions:         				
	- 20160315@Thai: US018 - Modify Trader's Score - [Redmine: #53987]
 Param's Explanation:  	
	
 Exam: 
				
		exec TGRS_Rpt_NewPerformanceDetail_League_Match_Bettype @FromDate='2016-02-15 00:00:00',@LeagueId=30730,@Bettypes='5,1,3',@CustId=14228019,@MatchId=16922489,@ToDate='2016-02-29 00:00:00'	
  
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
		,ISNULL(SUM(tp.StakeMYR), 0) AS Turnover
		,ISNULL(SUM(tp.StakeMYRJuice), 0) AS TurnoverJuice
		,ISNULL(SUM(tp.Juice), 0) AS Juice
		,ISNULL(SUM(tp.WinLost), 0) - ISNULL(SUM(tp.Comm), 0) AS WinLoss
		,SUM((tp.WinLost - tp.Comm) * CASE 
				WHEN tp.Spread * tm.Rate IS NULL
					THEN 0
				ELSE 1
				END) AS WinLossScore
		,ISNULL(SUM(tp.BetCount), 0) AS BetCount
		,ISNULL(SUM(tp.Stake * ISNULL(s.BenchMark, tp.Spread * tm.Rate)), 0) AS SumCategory
	FROM dbo.TraderPerformance AS tp WITH (NOLOCK)
	INNER JOIN dbo.Trader AS t WITH (NOLOCK) ON t.CustId = tp.CustId
	LEFT JOIN dbo.TargetedMargin AS tm WITH (NOLOCK) ON tm.BetType = tp.BetType
		AND tm.WorkShift = tp.WorkShift
	LEFT JOIN dbo.Benchmark_SpecialSetting AS s WITH (NOLOCK) ON s.Spread = tp.Spread
		AND s.Rate = tm.Rate
	LEFT JOIN dbo.BetType TN WITH (NOLOCK) ON TN.BetType = tp.BetType
	WHERE tp.LeagueId = @LeagueId
		AND tp.MatchId = @MatchId
		AND tp.EventDate BETWEEN @FromDate AND @ToDate
		AND TN.MainDBBetType IN (1,3,7,8)
		AND TN.[Disabled] = 0
		AND tp.IsLive = 1
	GROUP BY tp.BetType
		,TN.TypeName

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
	FROM #BettypeDetail AS bd

	DROP TABLE #BettypeDetail;
END
/*
GO
GRANT EXECUTE ON [dbo].[TGRS_Rpt_NewPerformanceDetail_League_Match_Bettype] TO [bodbTGRSNet]
GO
GRANT VIEW DEFINITION ON [dbo].[TGRS_Rpt_NewPerformanceDetail_League_Match_Bettype] TO [bodbTGRSNet ]
GO
*/