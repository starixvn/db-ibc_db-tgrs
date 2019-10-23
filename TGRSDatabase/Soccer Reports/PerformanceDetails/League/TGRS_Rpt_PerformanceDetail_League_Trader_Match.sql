ALTER PROCEDURE dbo.TGRS_Rpt_PerformanceDetail_League_Trader_Match  	
		@FromDate			DATE
	,	@ToDate				DATE
	,	@LeagueId			INT
	,	@CustId				INT
	,	@Bettypes			VARCHAR(2000) =  '0'
	,	@IsExcludeLeagues	BIT = 1
	,	@Market				SMALLINT = 1
AS    
/*  
	Created:	20160229@Aaron
	Task:		Detail report League Performance - Detail Match
	DB:			DBTGRS.bodb_TGRS
	Original:      
	  			
	Revision: 
		- 20171205@Simon:		get only Live data & Bettypes are not disabled
		- 20180912@Simon:		add league exclusion
		- 20190919@Long.Luu:	Support Nonlive Data [Redmine ID: 118959]
		- 20191023@John.Ngo:	Enhance performance [Redmine ID: 121268]

	Param's Explanation:  	
		- @Market: -1 All; 0 Nonlive; 1 Live 
	
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
	   
    SELECT P.MatchId, P.HomeId, P.AwayId, P.EventDate, P.IsLive,
			ISNULL(SUM(P.Stake), 0) AS Turnover, 
			ISNULL(SUM(P.WinLost), 0) - ISNULL(SUM(P.Comm), 0) AS WinLoss, 
			ISNULL(SUM(P.BetCount), 0) as BetCount,
			CASE WHEN ISNULL(SUM(P.Stake), 0) <> 0 THEN (ISNULL(SUM(P.WinLost), 0)- ISNULL(SUM(P.Comm), 0)) * 100/ISNULL(SUM(P.Stake), 0) ELSE NULL END AS Margin	
	 FROM	dbo.TraderPerformance AS P WITH (NOLOCK)
		LEFT JOIN dbo.LeagueExclusion le WITH(NOLOCK) ON P.LeagueId = le.LeagueId		 
	 WHERE	P.EventDate BETWEEN @FromDate AND @ToDate
			AND P.LeagueId = @LeagueId
			AND P.CustId = @CustId
			AND P.BetType IN (SELECT Bettype FROM @BettypeList)
			AND (@Market = -1 OR P.IsLive = @Market)
			AND (@IsExcludeLeagues = 0 OR le.LeagueId IS NULL)
	GROUP BY P.MatchId, P.HomeId, P.AwayId, P.EventDate, P.IsLive
	ORDER BY Margin DESC, P.EventDate ASC;
END;

GO
/*<info serverAlias="DBTGRS-bodb_TGRS" executers="bodbTGRSNet" isFunction="0" isNested="0"></info>*/