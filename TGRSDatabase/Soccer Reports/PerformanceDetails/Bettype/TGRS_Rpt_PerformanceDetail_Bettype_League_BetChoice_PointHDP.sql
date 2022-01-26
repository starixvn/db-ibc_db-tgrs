ALTER PROCEDURE [dbo].[TGRS_Rpt_PerformanceDetail_Bettype_League_BetChoice_PointHDP]  	
		@FromDate			DATE
	,	@ToDate				DATE
	,	@LeagueId			INT
	,	@BetType			SMALLINT
	,	@BetTeam			NVARCHAR(50)
	,	@IsExcludeLeagues	BIT = 1
	,	@Market				SMALLINT = 1
AS    
/*  
	 Created:	20220117@John.Ngo
	 Task :		Support drilldown BetChoiceDetail
	 DB:		DB06.bodb_TGRS_UAT & DB061.bodb_TGRS
	 Original:  
 
	 Revisions:
		- 20220117@John.Ngo: 	Support view down for Total Goal, Time Machine and Corner bettype [Redmine: #166679]
		
	 Param's Explanation:  	
		- @Market: -1 All; 0 Nonlive; 1 Live

*/ 
 
BEGIN 
	SET NOCOUNT ON;

	SELECT (CASE WHEN @BetType IN (228,229) THEN P.oddsspread 
				  WHEN @BetType IN (28,453)  THEN (P.hdp1-P.hdp2)
				  ELSE P.hdp1 END)								AS PointHDP		
		,	P.IsLive											AS IsLive
		,	ISNULL(COUNT(DISTINCT P.MatchId), 0)				AS MatchCount
		,	ISNULL(SUM(P.BetCount), 0)							AS BetCount
		,	ISNULL(SUM(P.Stake), 0)								AS Turnover
		,	ISNULL(SUM(P.WinLost), 0) - ISNULL(SUM (P.Comm), 0)	AS WinLoss
		,	CASE WHEN ISNULL(SUM(P.Stake), 0) <> 0 THEN (ISNULL(SUM(P.WinLost), 0) - ISNULL(SUM(P.Comm), 0)) * 100/SUM(P.Stake) ELSE NULL END AS Margin
		,	ISNULL(SUM(P.Stake_Real),0) 						AS TurnoverReal		
		,	ISNULL(SUM(CASE WHEN P.Is8RM = 0 THEN P.WinLost_Real ELSE 0 END),0) AS WinLossReal
		,	CASE WHEN ISNULL(SUM(P.Stake_Real),0) <> 0 THEN ISNULL(SUM(CASE WHEN P.Is8RM = 0 THEN P.WinLost_Real ELSE 0 END),0) * 100/ISNULL(SUM(P.Stake_Real),0) ELSE NULL END AS MarginReal
	FROM dbo.TraderPerformance_BetChoice_Detail AS P WITH (NOLOCK)    
		LEFT JOIN dbo.BetChoiceMapping AS bcm WITH (NOLOCK) ON bcm.BetType = P.BetType AND bcm.BetChoice = P.betteam
		LEFT JOIN dbo.LeagueExclusion le WITH(NOLOCK) ON P.LeagueId = le.LeagueId  
	WHERE	P.EventDate BETWEEN @FromDate AND @ToDate
		AND	P.BetType = @BetType 
		AND P.LeagueId = @LeagueId
		AND ISNULL(bcm.TGRSBetChoice,P.betteam) = @BetTeam
		AND (@Market = -1 OR P.IsLive = @Market)
		AND (@IsExcludeLeagues = 0 OR le.LeagueId IS NULL)
	GROUP BY (CASE WHEN @BetType IN (228,229) THEN P.oddsspread 
				   WHEN @BetType IN (28,453)  THEN (P.hdp1-P.hdp2)
				   ELSE P.hdp1 END), P.IsLive
	ORDER BY (CASE WHEN @BetType IN (228,229) THEN P.oddsspread 
				   WHEN @BetType IN (28,453)  THEN (P.hdp1-P.hdp2)
				   ELSE P.hdp1 END);
	
END;

GO

/*<info serverAlias="DBTGRS-bodb_TGRS" executers="bodbTGRSNet" isFunction="0" isNested="0"></info>*/