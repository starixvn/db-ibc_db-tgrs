ALTER PROCEDURE [dbo].[TGRS_Rpt_PerformanceDetail_Bettype_League_Trader_Match]  	
	@FromDate			DATE,
	@ToDate				DATE,
	@LeagueId			INT,
	@CustId				INT,
	@Bettype			SMALLINT,
	@IsExcludeLeagues	BIT = 1,
	@Market				SMALLINT = 1
AS    
/*  
	Created:	20160315@Thai.Tran
	Task:		Detail report - View Match detail from Bet Type, League and Trader
	DB:			DBTGRS.bodb_TGRS
	Original:      
	  			
	Revision:
		- 20171205@Simon:		get only Live data & Bettypes are not disabled
		- 20180912@Simon:		add league exclusion
		- 20190919@Long.Luu:	Support Nonlive Data [Redmine ID: 118959]

	Param's Explanation:  	
		- @Market: -1 All; 0 Nonlive; 1 Live  
	
	Example: 
		exec TGRS_Rpt_PerformanceDetail_Bettype_League_Trader_Match @Bettype=3,@LeagueId=3162,@FromDate='2016-03-02 00:00:00',@ToDate='2016-03-16 00:00:00',@CustId=2438
  
*/  
 
BEGIN 
	SET NOCOUNT ON;				   
	   
	SELECT P.MatchId, P.HomeId, P.AwayId, P.EventDate, P.IsLive,
			ISNULL(SUM(P.Stake), 0) AS Turnover, 
			ISNULL(SUM(P.WinLost), 0) - ISNULL(SUM(P.Comm), 0) AS WinLoss, 
			ISNULL(SUM(P.BetCount), 0) as BetCount,
			CASE WHEN ISNULL(SUM(P.Stake), 0) <> 0 THEN (ISNULL(SUM(P.WinLost), 0)- ISNULL(SUM(P.Comm), 0)) * 100/ISNULL(SUM(P.Stake), 0) ELSE NULL END AS Margin	
		FROM	dbo.TraderPerformance AS P WITH (NOLOCK)		 
		WHERE	P.LeagueId = @LeagueId
			AND P.CustId = @CustId
			AND P.BetType = @Bettype
			AND P.EventDate BETWEEN @FromDate AND @ToDate
			AND (@Market = -1 OR P.IsLive = @Market)
			AND (@IsExcludeLeagues = 0 OR (P.LeagueId NOT IN (SELECT le.LeagueId FROM dbo.LeagueExclusion AS le WITH(NOLOCK))))
	GROUP BY P.MatchId, P.HomeId, P.AwayId, P.EventDate, P.IsLive
	ORDER BY Margin DESC, P.EventDate ASC;
END;

GO
/*<info serverAlias="DBTGRS-bodb_TGRS" executers="bodbTGRSNet" isFunction="0" isNested="0"></info>*/