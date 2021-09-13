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
	 DB:		DB06.bodb_TGRS_UAT & DB061.bodb_TGRS
	 Original:  
 
	 Revisions:
		- 20200731@John.Ngo:	View down bet choice from League performance [Redmine ID: 137278]
		- 20210809@Adam.Tran: 	Sports - Performance Real Figures [Redmine: #158981]
		
	 Param's Explanation:  	
		- @Market: -1 All; 0 Nonlive; 1 Live

*/ 
 
BEGIN 
	SET NOCOUNT ON;
	
	DECLARE @IsFMBetType 	BIT;
	
	SET @IsFMBetType = 
		CASE 
			WHEN EXISTS (
				SELECT b.BetType
				FROM dbo.BetChoice_FastMarketMapping AS b
				WHERE b.BetType = @Bettype) THEN 1
			ELSE 0
		END;	
	
	IF @IsFMBetType = 1
		BEGIN
			SELECT 	ISNULL(fm.BetOption, P.BetChoice)					AS BetChoice							
				,	P.IsLive											AS IsLive
				,	ISNULL(COUNT(DISTINCT P.MatchId), 0)				AS MatchCount
				,	ISNULL(SUM(P.BetCount), 0)							AS BetCount
				,	ISNULL(SUM(P.Stake), 0)								AS Turnover
				,	ISNULL(SUM(P.WinLost), 0) - ISNULL(SUM (P.Comm), 0)	AS WinLoss
				,	CASE WHEN ISNULL(SUM(P.Stake), 0) <> 0 THEN (ISNULL(SUM(P.WinLost), 0) - ISNULL(SUM(P.Comm), 0)) * 100/SUM(P.Stake) ELSE NULL END AS Margin
				,	ISNULL(SUM(P.Stake_Real),0) 						AS TurnoverReal		
				,	ISNULL(SUM(CASE WHEN P.Is8RM = 0 THEN P.WinLost_Real ELSE 0 END),0) AS WinLossReal
				,	CASE WHEN ISNULL(SUM(P.Stake_Real),0) <> 0 THEN ISNULL(SUM(CASE WHEN P.Is8RM = 0 THEN P.WinLost_Real ELSE 0 END),0) * 100/ISNULL(SUM(P.Stake_Real),0) ELSE NULL END AS MarginReal
			FROM dbo.TraderPerformance_BetChoice AS P WITH (NOLOCK)    
				LEFT JOIN dbo.BetChoice_FastMarketMapping AS fm WITH (NOLOCK) ON fm.BetType = @Bettype AND fm.BetTeam = P.BetChoice
				LEFT JOIN dbo.LeagueExclusion le WITH(NOLOCK) ON P.LeagueId = le.LeagueId  
			WHERE	P.EventDate BETWEEN @FromDate AND @ToDate
				AND	P.Bettype = @Bettype AND P.LeagueId = @LeagueId
				AND (@Market = -1 OR P.IsLive = @Market)
				AND (P.BetChoice = fm.BetTeam)
				AND (@IsExcludeLeagues = 0 OR le.LeagueId IS NULL)
			GROUP BY ISNULL(fm.BetOption, P.BetChoice), P.IsLive;				
		END;
	ELSE
		BEGIN
			SELECT ISNULL(bcm.TGRSBetChoice, P.BetChoice)				AS BetChoice		
				,	P.IsLive											AS IsLive
				,	ISNULL(COUNT(DISTINCT P.MatchId), 0)				AS MatchCount
				,	ISNULL(SUM(P.BetCount), 0)							AS BetCount
				,	ISNULL(SUM(P.Stake), 0)								AS Turnover
				,	ISNULL(SUM(P.WinLost), 0) - ISNULL(SUM (P.Comm), 0)	AS WinLoss
				,	CASE WHEN ISNULL(SUM(P.Stake), 0) <> 0 THEN (ISNULL(SUM(P.WinLost), 0) - ISNULL(SUM(P.Comm), 0)) * 100/SUM(P.Stake) ELSE NULL END AS Margin
				,	ISNULL(SUM(P.Stake_Real),0) 						AS TurnoverReal		
				,	ISNULL(SUM(CASE WHEN P.Is8RM = 0 THEN P.WinLost_Real ELSE 0 END),0) AS WinLossReal
				,	CASE WHEN ISNULL(SUM(P.Stake_Real),0) <> 0 THEN ISNULL(SUM(CASE WHEN P.Is8RM = 0 THEN P.WinLost_Real ELSE 0 END),0) * 100/ISNULL(SUM(P.Stake_Real),0) ELSE NULL END AS MarginReal
			FROM dbo.TraderPerformance_BetChoice AS P WITH (NOLOCK)    
				LEFT JOIN dbo.BetChoiceMapping AS bcm WITH (NOLOCK) ON bcm.BetType = @Bettype  
				LEFT JOIN dbo.LeagueExclusion le WITH(NOLOCK) ON P.LeagueId = le.LeagueId  
			WHERE	P.EventDate BETWEEN @FromDate AND @ToDate
				AND	P.Bettype = @Bettype AND P.LeagueId = @LeagueId
				AND (@Market = -1 OR P.IsLive = @Market)
				AND (P.BetChoice = bcm.BetChoice OR bcm.BetChoice IS NULL)
				AND (@IsExcludeLeagues = 0 OR le.LeagueId IS NULL)
			GROUP BY ISNULL(bcm.TGRSBetChoice, P.BetChoice), P.IsLive;				
		END;

	SELECT @IsFMBetType AS IsFMBetType;
END;
GO
