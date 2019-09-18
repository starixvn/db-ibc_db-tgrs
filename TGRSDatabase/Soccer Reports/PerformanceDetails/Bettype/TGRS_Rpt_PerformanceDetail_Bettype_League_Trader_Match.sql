/****** Object:  Stored Procedure dbo.TGRS_Rpt_PerformanceDetail_Bettype_League_Trader_Match    Script Date: 3/22/2016 12:48:53 PM ******/

ALTER PROCEDURE [dbo].[TGRS_Rpt_PerformanceDetail_Bettype_League_Trader_Match]  	
		@FromDate	DATE,
		@ToDate		DATE,
		@LeagueId	INT,
		@CustId		INT,
		@Bettype	SMALLINT,
		@IsExcludeLeagues	BIT = 1
AS    
/*  
	Created:	20160315@Thai.Tran
	Task:		Detail report - View Match detail from Bet Type, League and Trader
	DB:			DBTGRS.bodb_TGRS
	Original:      
	  			
	Revision:
		- 20171205@Simon: get only Live data & Bettypes are not disabled
		- 20180912@Simon: add league exclusion

	Param's Explanation:  	
	
	Example: 
		exec TGRS_Rpt_PerformanceDetail_Bettype_League_Trader_Match @Bettype=3,@LeagueId=3162,@FromDate='2016-03-02 00:00:00',@ToDate='2016-03-16 00:00:00',@CustId=2438
  
*/  
 
BEGIN 
	SET NOCOUNT ON;

	DECLARE @BettypeList TABLE (BetType SMALLINT);				   
	   
	SELECT P.MatchId, P.HomeId, P.AwayId, P.EventDate,
			ISNULL(SUM(P.Stake),0) AS Turnover, 
			ISNULL(SUM(P.WinLost),0) - ISNULL(SUM(P.Comm),0) AS WinLoss, 
			ISNULL(SUM(P.BetCount),0) as BetCount,
			CASE WHEN ISNULL(SUM(P.Stake),0) <> 0 THEN (ISNULL(SUM(P.WinLost),0)- ISNULL(SUM(P.Comm),0)) * 100/ISNULL(SUM(P.Stake),0) ELSE NULL END AS Margin	
		FROM	dbo.TraderPerformance P WITH (NOLOCK)		 
		WHERE	P.LeagueId = @LeagueId
			AND P.CustId = @CustId
			AND P.BetType = @Bettype
			AND P.EventDate BETWEEN @FromDate AND @ToDate
			AND P.IsLive = 1
			AND (@IsExcludeLeagues = 0 OR (P.LeagueId NOT IN (SELECT le.LeagueId FROM dbo.LeagueExclusion le WITH(NOLOCK))))
	GROUP BY P.MatchId, P.HomeId, P.AwayId, P.EventDate
	ORDER BY Margin DESC, P.EventDate ASC;
END;

/*

GRANT EXECUTE ON [dbo].[TGRS_Rpt_PerformanceDetail_Bettype_League_Trader_Match] TO [bodbTGRSNet]
GRANT VIEW DEFINITION ON [dbo].[TGRS_Rpt_PerformanceDetail_Bettype_League_Trader_Match] TO [bodbTGRSNet ]

*/

GO
/*<info serverAlias="DBTGRS-bodb_TGRS" executers="bodbTGRSNet" isFunction="0" isNested="0"></info>*/