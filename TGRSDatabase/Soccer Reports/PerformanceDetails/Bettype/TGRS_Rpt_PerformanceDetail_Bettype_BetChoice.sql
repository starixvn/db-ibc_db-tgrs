
ALTER PROCEDURE [dbo].[TGRS_Rpt_PerformanceDetail_Bettype_BetChoice]  	
	@FromDate			DATE,
	@ToDate				DATE,		
	@Bettype			SMALLINT,
	@IsExcludeLeagues	BIT = 1,
	@Market				SMALLINT = 1
AS    
/*  
	 Created:	20171212@Aaron
	 Task :		Detail report - Bet choice detail from Bet Type
	 DB:		DBTGRS.bodb_TGRS
	 Original:  
 
	 Revisions:
		- 20180912@Simon:		add league exclusion
		- 20190919@Long.Luu:	Support Nonlive Data [Redmine ID: 118959]

	 Param's Explanation:  	
		- @Market: -1 All; 0 Nonlive; 1 Live

	 Exam: 
		EXEC  TGRS_Rpt_PerformanceDetail_Bettype_BetChoice @FromDate = '2017-11-01', @ToDate= '2018-05-30', @Bettype = 15
  
*/  
 
BEGIN 
	SET NOCOUNT ON;
	
	SELECT bcm.TGRSBetChoice								AS BetChoice,
		P.IsLive											AS IsLive,
		ISNULL(COUNT(DISTINCT P.LeagueId), 0)				AS LeagueCount, 
		ISNULL(COUNT(DISTINCT P.MatchId), 0)				AS MatchCount, 
		ISNULL(SUM(P.Stake), 0)								AS Turnover, 
		ISNULL(SUM(P.WinLost), 0) - ISNULL(SUM (P.Comm), 0)	AS WinLoss, 
		ISNULL(SUM(P.BetCount), 0)							AS BetCount
	FROM dbo.TraderPerformance_BetChoice AS P WITH (NOLOCK)	 
		INNER JOIN dbo.BetChoiceMapping AS bcm WITH (NOLOCK) ON bcm.BetType = @Bettype
	WHERE	P.Bettype = @Bettype
		AND P.EventDate BETWEEN @FromDate AND @ToDate
		AND (@Market = -1 OR P.IsLive = @Market)
		AND P.BetChoice = bcm.BetChoice
		AND (@IsExcludeLeagues = 0 OR (P.LeagueId NOT IN (SELECT le.LeagueId FROM dbo.LeagueExclusion AS le WITH(NOLOCK))))
	GROUP BY bcm.TGRSBetChoice, P.IsLive;
END;

GO
/*<info serverAlias="DBTGRS-bodb_TGRS" executers="bodbTGRSNet" isFunction="0" isNested="0"></info>*/