USE [bodb_TGRS]
GO
/****** Object:  StoredProcedure [dbo].[TGRS_Rpt_DetailBetType_League]    Script Date: 6/18/2014 2:49:19 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[TGRS_Rpt_DetailBetType_MatchByTraderLeague]
	@FromDate	DATE,
	@ToDate		DATE,
	@BetTypeBMFrom MONEY = NULL,
	@BetTypeBMTo MONEY = NULL,
	@Turnover	MONEY = NULL,
	@WinLost	MONEY = NULL,
	@MarginFrom	MONEY = NULL,
	@MarginTo   MONEY = NULL,
	@Bettype	SMALLINT,
	@LeagueId	INT,
	@CustID	INT
AS    
/*  
 Created:	20140619@Tom.Vo
 Task :		Detail report League Performance - Match by Trader control League
 DB:		DBTGRS.bodb_TGRS
 Original:  
  
 Revisions:      
   			
 Param's Explanation:  	
	
EXEC [TGRS_Rpt_DetailBetType_MatchByTraderLeague]  @FromDate='2014-06-03 00:00:00'
	,@WinLost=NULL,@Turnover=NULL,@BetTypeBMTo=NULL,@MarginTo=NULL
	,@Bettype=-5,@MarginFrom=NULL,@BetTypeBMFrom=NULL,@ToDate='2014-06-17 00:00:00'
	,@leagueID =39160
	,@CustID = 3143982

 Exam: 
	  
*/  
 
BEGIN 
	 SET NOCOUNT ON  
	
	SELECT P.MatchId, P.LeagueId, P.HomeId, P.AwayId, P.EventDate,
			ISNULL(SUM(P.Stake),0) AS Turnover, 
			ISNULL(SUM(P.WinLost),0) - ISNULL(SUM(P.Comm),0) AS WinLost, 
			ISNULL(SUM(BetCount),0) as BetCount,
			CASE WHEN ISNULL(SUM(P.Stake),0) <> 0 THEN (ISNULL(SUM(P.WinLost),0)- ISNULL(SUM(P.Comm),0))/ISNULL(SUM(P.Stake),0) * 100 ELSE NULL END AS Margin	
	
	 FROM	dbo.TraderPerformance P WITH (NOLOCK)	
		LEFT JOIN dbo.Benchmark_BetType BT WITH (NOLOCK)
			 ON BT.LeagueId = P.LeagueId
				AND BT.BetType = P.BetType
		INNER JOIN dbo.Trader TR WITH (NOLOCK) 
				ON TR.CustId= P.CustId	
	 WHERE	P.EventDate BETWEEN @FromDate AND @ToDate			
			AND P.Bettype = @Bettype
			AND P.LeagueId = @LeagueId
			AND P.CustId = @CustId
			AND ISNULL(BT.Benchmark,0) >= CASE WHEN @BetTypeBMFrom IS NULL THEN ISNULL(BT.Benchmark,0) ELSE @BetTypeBMFrom END 
			AND ISNULL(BT.Benchmark,0) <= CASE WHEN @BetTypeBMTo IS NULL THEN ISNULL(BT.Benchmark,0) ELSE @BetTypeBMTo END 			
	GROUP BY P.MatchId, P.LeagueId, P.HomeId, P.AwayId, P.EventDate 
	HAVING	(@Turnover IS NULL OR ISNULL(SUM(P.Stake),0) >= ISNULL(@Turnover,0))
			AND (@WinLost IS NULL OR ISNULL(SUM(P.WinLost),0) - ISNULL(SUM(P.Comm),0) >= ISNULL(@WinLost,0))
			AND CASE WHEN ISNULL(SUM(P.Stake),0) <> 0 
					 THEN (ISNULL(SUM(P.WinLost),0)- ISNULL(SUM(P.Comm),0))/ISNULL(SUM(P.Stake),0) * 100 
					 ELSE 0 END 
				>= CASE WHEN @MarginFrom IS NULL 
						THEN CASE WHEN ISNULL(SUM(P.Stake),0) <> 0 
							 THEN (ISNULL(SUM(P.WinLost),0) - ISNULL(SUM(P.Comm),0))/ISNULL(SUM(P.Stake),0) * 100 
							 ELSE 0 END 
						ELSE @MarginFrom END 
			AND CASE WHEN ISNULL(SUM(P.Stake),0) <> 0 
					 THEN (ISNULL(SUM(P.WinLost),0) - ISNULL(SUM(P.Comm),0))/ISNULL(SUM(P.Stake),0) * 100
					 ELSE 0 END 
				<= CASE WHEN @MarginTo IS NULL 
						THEN CASE WHEN ISNULL(SUM(P.Stake),0) <> 0 
								  THEN (ISNULL(SUM(P.WinLost),0) - ISNULL(SUM(P.Comm),0))/ISNULL(SUM(P.Stake),0) * 100 
								  ELSE 0 END 
						ELSE @MarginTo END END 



GO
GRANT EXECUTE ON [dbo].[TGRS_Rpt_DetailBetType_MatchByTraderLeague] TO [bodbTGRSNet]