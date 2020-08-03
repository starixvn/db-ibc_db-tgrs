ALTER PROCEDURE [dbo].[TGRS_Rpt_PerformanceDetail_Bettype_League_BetChoice]  	
		@FromDate			DATE
	,	@ToDate				DATE
	,	@LeagueId			INT
	,	@Bettype			SMALLINT
	,	@IsExcludeLeagues	BIT = 1
	,	@Market				SMALLINT = 1
AS    
/*  
	 Created:	20200731@John.Ngo
	 Task :		Detail report - Bet choice detail from Bet Type - League - BetChoice
	 DB:		DBTGRS.bodb_TGRS
	 Original:  
 
	 Revisions:
		- 20200731@John.Ngo:	View down bet choice from League performance [Redmine ID: 137278]

	 Param's Explanation:  	
		- @Market: -1 All; 0 Nonlive; 1 Live

*/ 
 
BEGIN 
	SET NOCOUNT ON;
	
	SELECT ISNULL(bcm.TGRSBetChoice, P.BetChoice)				AS BetChoice,  
		  P.IsLive												AS IsLive,
		  ISNULL(COUNT(DISTINCT P.MatchId), 0)					AS MatchCount,   
		  ISNULL(SUM(P.Stake), 0)								AS Turnover,   
		  ISNULL(SUM(P.WinLost), 0) - ISNULL(SUM (P.Comm), 0)	AS WinLoss,   
		  ISNULL(SUM(P.BetCount), 0)							AS BetCount,
		  CASE WHEN ISNULL(SUM(P.Stake), 0) <> 0 THEN (ISNULL(SUM(P.WinLost), 0) - ISNULL(SUM(P.Comm), 0)) * 100/SUM(P.Stake) ELSE NULL END AS Margin
	FROM dbo.TraderPerformance_BetChoice AS P WITH (NOLOCK)    
		LEFT JOIN dbo.BetChoiceMapping AS bcm WITH (NOLOCK) ON bcm.BetType = @Bettype  
		LEFT JOIN dbo.LeagueExclusion le WITH(NOLOCK) ON P.LeagueId = le.LeagueId  
	WHERE	P.EventDate BETWEEN @FromDate AND @ToDate
		AND	P.Bettype = @Bettype AND P.LeagueId = @LeagueId
		AND (@Market = -1 OR P.IsLive = @Market)
		AND (P.BetChoice = bcm.BetChoice OR bcm.BetChoice IS NULL)
		AND (@IsExcludeLeagues = 0 OR le.LeagueId IS NULL)
	GROUP BY ISNULL(bcm.TGRSBetChoice, P.BetChoice),
			P.IsLive;
			 		
END;

GO
/*<info serverAlias="DBTGRS-bodb_TGRS" executers="bodbTGRSNet" isFunction="0" isNested="0"></info>*/