/****** Object:  Stored Procedure dbo.TGRS_Rpt_PerformanceDetail_League_Trader_Match    Script Date: 3/14/2016 3:58:14 AM ******/
/****** Object:  Stored Procedure dbo.TGRS_Rpt_PerformanceDetail_League_Trader_Match    Script Date: 3/8/2016 2:46:20 PM ******/

ALTER PROCEDURE dbo.TGRS_Rpt_PerformanceDetail_League_Trader_Match  	
		@FromDate	DATE
	,	@ToDate		DATE
	,	@LeagueId	INT
	,	@CustId		INT
	,	@Bettypes	VARCHAR(2000) =  '0'
	,	@IsExcludeLeagues	BIT = 1
AS    
/*  
	Created:	20160229@Aaron
	Task:		Detail report League Performance - Detail Match
	DB:			DBTGRS.bodb_TGRS
	Original:      
	  			
	Revision: 
		- 20171205@Simon: get only Live data & Bettypes are not disabled
		- 20180912@Simon: add league exclusion

	Param's Explanation:  	
	
	Example: 
		EXEC [TGRS_Rpt_PerformanceDetail_League_Trader_Match] @FromDate = '2014-01-01', @ToDate= '2014-12-30', @LeagueId = 6394, @Bettypes = '0', @CustID = 1530768  
*/  
 
BEGIN 
    SET NOCOUNT ON;

    DECLARE @BettypeList TABLE (BetType SMALLINT);
				
    IF @Bettypes <> '0'
	   INSERT INTO @BettypeList (BetType)
	   SELECT ssk.val
	   FROM	dbo.strSplit_Key(@Bettypes, ',') ssk;
    ELSE 
	    INSERT INTO @BettypeList (BetType)
	    SELECT bt.BetType 
		FROM	dbo.BetType AS bt WITH (NOLOCK);
	   
    SELECT P.MatchId, P.HomeId, P.AwayId, P.EventDate,
			ISNULL(SUM(P.Stake),0) AS Turnover, 
			ISNULL(SUM(P.WinLost),0) - ISNULL(SUM(P.Comm),0) AS WinLoss, 
			ISNULL(SUM(P.BetCount),0) as BetCount,
			CASE WHEN ISNULL(SUM(P.Stake),0) <> 0 THEN (ISNULL(SUM(P.WinLost),0)- ISNULL(SUM(P.Comm),0)) * 100/ISNULL(SUM(P.Stake),0) ELSE NULL END AS Margin	
	 FROM	dbo.TraderPerformance P WITH (NOLOCK)		 
	 WHERE	P.EventDate BETWEEN @FromDate AND @ToDate
			AND P.LeagueId = @LeagueId
			AND P.CustId = @CustId
			AND P.BetType IN (SELECT Bettype FROM @BettypeList)
			AND P.IsLive = 1
			AND (@IsExcludeLeagues = 0 OR (P.LeagueId NOT IN (SELECT le.LeagueId FROM dbo.LeagueExclusion le WHERE le.LeagueId = P.LeagueId)))
	GROUP BY P.MatchId, P.HomeId, P.AwayId, P.EventDate
	ORDER BY Margin DESC, P.EventDate ASC;
END;
/*<info serverAlias="DBTGRS - bodb_TGRS" executers="bodbTGRSNet" isFunction="0" isNested="0"></info>*/