
ALTER PROCEDURE [dbo].[TGRS_Rpt_PerformanceDetail_Grade_Trader_Match]  	
		@FromDate			DATE
	,	@ToDate				DATE
	,	@CustId				INT
	,	@Bettypes			VARCHAR(2000) =  '0'
	,	@IsExcludeLeagues	BIT = 1
	,	@Market				SMALLINT = 1
AS    
/*  
	Created:	20160328@Aaron
	Task:		Detail report Grade Performance - Detail Match
	DB:			DBTGRS.bodb_TGRS
	Original:      
	  			
	Revision:
		- 20171205@Simon:		get only Live data & Bettypes are not disabled
		- 20180912@Simon:		add league exclusion
		- 20190919@Long.Luu:	Support Nonlive Data [Redmine ID: 118959]

	Param's Explanation: 
		- @Market: -1 All; 0 Nonlive; 1 Live   	
	
	Example: 
		EXEC [TGRS_Rpt_PerformanceDetail_Grade_Trader_Match] @FromDate = '2016-03-01', @ToDate= '2016-03-30', @Bettypes = '0', @CustID = 2457, @Grade = 1
  
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
	   
	SELECT P.MatchId, P.LeagueId, P.HomeId, P.AwayId, P.EventDate, P.IsLive,
		ISNULL(SUM(P.Stake), 0) AS Turnover, 
		ISNULL(SUM(P.WinLost), 0) - ISNULL(SUM(P.Comm), 0) AS WinLoss, 
		ISNULL(SUM(P.BetCount), 0) as BetCount,
		CASE WHEN ISNULL(SUM(P.Stake), 0) <> 0 THEN (ISNULL(SUM(P.WinLost), 0)- ISNULL(SUM(P.Comm), 0)) * 100/ISNULL(SUM(P.Stake), 0) ELSE NULL END AS Margin
	FROM	dbo.TraderPerformance AS P WITH (NOLOCK)	 
	WHERE	P.EventDate BETWEEN @FromDate AND @ToDate
		AND P.CustId = @CustId
		AND P.BetType IN (SELECT Bettype FROM @BettypeList)
		AND (@Market = -1 OR P.IsLive = @Market)
		AND (@IsExcludeLeagues = 0 OR (P.LeagueId NOT IN (SELECT le.LeagueId FROM dbo.LeagueExclusion AS le WITH(NOLOCK))))
	GROUP BY P.MatchId, P.LeagueId, P.HomeId, P.AwayId, P.EventDate, P.IsLive		
	ORDER BY P.LeagueId ASC, Margin DESC, P.EventDate ASC;
END;

GO
/*<info serverAlias="DBTGRS-bodb_TGRS" executers="bodbTGRSNet" isFunction="0" isNested="0"></info>*/