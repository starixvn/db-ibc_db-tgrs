ALTER PROCEDURE [dbo].[TGRS_Rpt_PerformanceDetail_Bettype_League]  	
	@FromDate			DATE,
	@ToDate				DATE,		
	@Bettype			SMALLINT,
	@IsExcludeLeagues	BIT = 1,
	@Market				SMALLINT = 1
AS    
/*  
	 Created:	20160315@Thai.Tran
	 Task :		Detail report - League detail from Bet Type
	 DB:		DBTGRS.bodb_TGRS
	 Original:  
 
	 Revisions:      	
		- 20171205@Simon:		get only Live data & Bettypes are not disabled
		- 20180912@Simon:		add league exclusion
		- 20190919@Long.Luu:	Support Nonlive Data [Redmine ID: 118959]

	 Param's Explanation:  	
		- @Market: -1 All; 0 Nonlive; 1 Live  

	 Exam: 
		EXEC  TGRS_Rpt_PerformanceDetail_Bettype_League @FromDate = '2014-01-01', @ToDate= '2014-05-30', @Bettype = 1
  
*/  
 
BEGIN 
	SET NOCOUNT ON;
	
	SELECT P.LeagueId,
		L.LeagueName,
		P.IsLive,
		ISNULL(COUNT(DISTINCT P.CustId), 0) AS TraderCount, 
		ISNULL(COUNT(DISTINCT P.LeagueId), 0) AS LeagueCount, 
		ISNULL(COUNT(DISTINCT P.MatchId), 0) AS MatchCount, 
		ISNULL(SUM(P.Stake), 0) AS Turnover, 
		ISNULL(SUM(P.WinLost), 0) - ISNULL(SUM (P.Comm), 0) AS WinLoss, 
		ISNULL(SUM(P.BetCount), 0) AS BetCount,
		CASE WHEN ISNULL(SUM(P.Stake), 0) <> 0 THEN (ISNULL(SUM(P.WinLost), 0) - ISNULL(SUM(P.Comm), 0)) * 100/SUM(P.Stake) ELSE NULL END AS Margin		
	FROM dbo.TraderPerformance AS P WITH (NOLOCK)	 
	INNER JOIN bodb02.dbo.League AS L WITH (NOLOCK) ON P.LeagueId = L.LeagueId
	WHERE	P.Bettype = @Bettype
		AND P.EventDate BETWEEN @FromDate AND @ToDate					
		AND (@Market = -1 OR P.IsLive = @Market)
		AND (@IsExcludeLeagues = 0 OR (L.LeagueId NOT IN (SELECT le.LeagueId FROM dbo.LeagueExclusion AS le WITH(NOLOCK))))
	GROUP BY P.LeagueId, L.LeagueName, P.IsLive 	
	ORDER BY Margin DESC, LeagueName ASC;				 		
END;

GO
/*<info serverAlias="DBTGRS-bodb_TGRS" executers="bodbTGRSNet" isFunction="0" isNested="0"></info>*/