USE [bodb_TGRS]
GO
/****** Object:  StoredProcedure [dbo].[TGRS_Rpt_DetailBetType_League]    Script Date: 6/18/2014 2:49:19 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[TGRS_Rpt_DetailBetType_MatchByTraderLeague]
	@FromDate				DATE,
	@ToDate					DATE,
	@BetTypeBMFrom			MONEY = NULL,
	@BetTypeBMTo			MONEY = NULL,
	@Bettype				SMALLINT,
	@LeagueId				INT,
	@CustID					INT,
	@IsExcludeLeagues		BIT = 1
AS    
/*  
 Created:	20140619@Tom.Vo
 Task :		Detail report League Performance - Match by Trader control League
 DB:		DBTGRS.bodb_TGRS
 Original:  
  
 Revisions:      
   	- 20140728@Sophia:	Change Benchmark to percentage instead of decimal number	
	- 20141210@Sophia:	Add condition Workshift
	- 20180911@Long:	Support excluding Leagues from report [Redmine ID: #100322]

 Param's Explanation:  	
	
EXEC [TGRS_Rpt_DetailBetType_MatchByTraderLeague]  
	@FromDate='2014-06-03 00:00:00'
	,@ToDate='2014-06-03 00:00:00'
	,@Bettype=-5
	,@leagueID =39160
	,@CustID = 3143982

 Exam: 
	  
*/  
 
BEGIN 
	SET NOCOUNT ON;
	
	IF @IsExcludeLeagues = 0
	SELECT P.MatchId, P.LeagueId, P.HomeId, P.AwayId, P.EventDate,
			ISNULL(SUM(P.Stake),0) AS Turnover, 
			ISNULL(SUM(P.WinLost),0) - ISNULL(SUM(P.Comm),0) AS WinLost, 
			ISNULL(SUM(BetCount),0) as BetCount,
			CASE WHEN ISNULL(SUM(P.Stake),0) <> 0 THEN (ISNULL(SUM(P.WinLost),0)- ISNULL(SUM(P.Comm),0)) * 100 /ISNULL(SUM(P.Stake),0)ELSE NULL END AS Margin		
	FROM	dbo.TraderPerformance P WITH (NOLOCK)	
		LEFT JOIN dbo.Benchmark_BetType BT WITH (NOLOCK)
				ON BT.LeagueId = P.LeagueId
				AND BT.BetType = P.BetType
				AND BT.WorkShift = P.WorkShift
		INNER JOIN dbo.Trader TR WITH (NOLOCK) 
				ON TR.CustId= P.CustId	
	WHERE	P.EventDate BETWEEN @FromDate AND @ToDate			
			AND P.Bettype = @Bettype
			AND P.LeagueId = @LeagueId
			AND P.CustId = @CustId
			AND ISNULL(BT.Benchmark,0) * 100 >= CASE WHEN @BetTypeBMFrom IS NULL THEN ISNULL(BT.Benchmark,0) * 100 ELSE @BetTypeBMFrom END 
			AND ISNULL(BT.Benchmark,0) * 100 <= CASE WHEN @BetTypeBMTo IS NULL THEN ISNULL(BT.Benchmark,0) * 100 ELSE @BetTypeBMTo END 
			AND (@IsExcludeLeagues = 0 OR (P.LeagueId NOT IN (SELECT le.LeagueId FROM dbo.LeagueExclusion le)))
	GROUP BY P.MatchId, P.LeagueId, P.HomeId, P.AwayId, P.EventDate;
END;


GO
GRANT EXECUTE ON [dbo].[TGRS_Rpt_DetailBetType_MatchByTraderLeague] TO [bodbTGRSNet]

GO
/*<info serverAlias="DBTGRS-bodb_TGRS" executers="bodbTGRSNet" isFunction="0" isNested="0"></info>*/