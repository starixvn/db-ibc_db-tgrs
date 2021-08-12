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
		- 202100809@Adam.Tran: 	Sports - Performance Real Figures [Redmine: #158981]
		
	 Param's Explanation:  	
		- @Market: -1 All; 0 Nonlive; 1 Live

*/ 
 
BEGIN 
	SET NOCOUNT ON;
	
	IF	OBJECT_ID('tempdb..#tmp8RMPerformanceBetChoice') IS NOT NULL
	BEGIN
		DROP TABLE	#tmp8RMPerformanceBetChoice;
	END;
	
	CREATE TABLE	#tmp8RMPerformanceBetChoice (
			BetChoice			NVARCHAR(100)		
		,	IsLive				BIT
		,	TurnoverReal		MONEY
		,	WinLossReal			MONEY
		,	MarginReal			MONEY
		,	PRIMARY KEY CLUSTERED (
				BetChoice		ASC
			,	IsLive			ASC
		)
	);	
	
	IF	OBJECT_ID('tempdb..#tmpTraderPerformanceBetChoice') IS NOT NULL
	BEGIN
		DROP TABLE	#tmpTraderPerformanceBetChoice;
	END;

	CREATE TABLE #tmpTraderPerformanceBetChoice (
			BetChoice			NVARCHAR(100)					
		,	IsLive				BIT			
		,	MatchCount			INT
		,	BetCount			INT		
		,	Turnover			MONEY
		,	WinLoss				MONEY
		,	Margin				MONEY
		,	TurnoverReal		MONEY
		,	WinLossReal			MONEY	
		,	MarginReal			MONEY		
	);
	
	INSERT INTO #tmp8RMPerformanceBetChoice(BetChoice
		,	IsLive
		,	TurnoverReal
		,	WinLossReal
		,	MarginReal)
	SELECT 	ISNULL(bcm.TGRSBetChoice, P.BetChoice)				AS BetChoice
		,	P.IsLive
		,	ISNULL(SUM(P.Stake_Real),0) 		AS TurnoverReal
		,	ISNULL(SUM(P.WinLost_Real),0)		AS WinLossReal
		,	CASE WHEN ISNULL(SUM(P.Stake_Real), 0) <> 0 THEN (ISNULL(SUM(P.WinLost_Real), 0)) * 100/SUM(P.Stake_Real) ELSE NULL END AS MarginReal
	FROM dbo.TraderPerformance_BetChoice AS P WITH (NOLOCK)
		LEFT JOIN dbo.BetChoiceMapping AS bcm WITH (NOLOCK) ON bcm.BetType = @Bettype  
		LEFT JOIN dbo.LeagueExclusion le WITH(NOLOCK) ON P.LeagueId = le.LeagueId 
	WHERE	P.Is8RM = 1
		AND P.EventDate BETWEEN @FromDate AND @ToDate
		AND	P.Bettype = @Bettype AND P.LeagueId = @LeagueId
		AND (@Market = -1 OR P.IsLive = @Market)
		AND (P.BetChoice = bcm.BetChoice OR bcm.BetChoice IS NULL)
		AND (@IsExcludeLeagues = 0 OR le.LeagueId IS NULL)	
	GROUP BY ISNULL(bcm.TGRSBetChoice, P.BetChoice), P.IsLive;	
	
	INSERT INTO #tmpTraderPerformanceBetChoice(BetChoice				
				,	IsLive				
				,	MatchCount
				,	BetCount
				,	Turnover
				,	WinLoss				
				,	Margin
				,	TurnoverReal
				,	WinLossReal
				,	MarginReal)
	SELECT ISNULL(bcm.TGRSBetChoice, P.BetChoice)				AS BetChoice
		,	P.IsLive											AS IsLive
		,	ISNULL(COUNT(DISTINCT P.MatchId), 0)				AS MatchCount
		,	ISNULL(SUM(P.BetCount), 0)							AS BetCount
		,	ISNULL(SUM(P.Stake), 0)								AS Turnover   
		,	ISNULL(SUM(P.WinLost), 0) - ISNULL(SUM (P.Comm), 0)	AS WinLoss   			
		,	CASE WHEN ISNULL(SUM(P.Stake), 0) <> 0 THEN (ISNULL(SUM(P.WinLost), 0) - ISNULL(SUM(P.Comm), 0)) * 100/SUM(P.Stake) ELSE NULL END AS Margin
		,	ISNULL(SUM(P.Stake_Real),0) 						AS TurnoverReal
		,	ISNULL(SUM(P.WinLost_Real),0)						AS WinLossReal
		,	CASE WHEN ISNULL(SUM(P.Stake_Real), 0) <> 0 THEN (ISNULL(SUM(P.WinLost_Real), 0)) * 100/SUM(P.Stake_Real) ELSE NULL END AS MarginReal
	FROM dbo.TraderPerformance_BetChoice AS P WITH (NOLOCK)    
		LEFT JOIN dbo.BetChoiceMapping AS bcm WITH (NOLOCK) ON bcm.BetType = @Bettype  
		LEFT JOIN dbo.LeagueExclusion le WITH(NOLOCK) ON P.LeagueId = le.LeagueId  
	WHERE	P.EventDate BETWEEN @FromDate AND @ToDate
		AND	P.Bettype = @Bettype AND P.LeagueId = @LeagueId
		AND (@Market = -1 OR P.IsLive = @Market)
		AND (P.BetChoice = bcm.BetChoice OR bcm.BetChoice IS NULL)
		AND (@IsExcludeLeagues = 0 OR le.LeagueId IS NULL)
	GROUP BY ISNULL(bcm.TGRSBetChoice, P.BetChoice), P.IsLive;
	
	UPDATE P
	SET   P.TurnoverReal 	= P.TurnoverReal + r.TurnoverReal
		, P.WinLossReal 	= P.WinLossReal - r.WinLossReal		
		, P.MarginReal		= CASE WHEN ISNULL(P.TurnoverReal + r.TurnoverReal, 0) <> 0 THEN (ISNULL(P.WinLossReal - r.WinLossReal, 0)) * 100/(P.TurnoverReal + r.TurnoverReal) ELSE NULL END
	FROM #tmpTraderPerformanceBetChoice AS P WITH(NOLOCK)
	INNER JOIN #tmp8RMPerformanceBetChoice AS r WITH(NOLOCK) ON  r.BetChoice = P.BetChoice
		AND r.IsLive = P.IsLive;
	
	SELECT	b.BetChoice			
		,	b.IsLive 		
		,	b.MatchCount
		,	b.BetCount
		,	b.Turnover
		,	b.WinLoss
		,	b.Margin
		,	b.TurnoverReal
		,	b.WinLossReal
		,	b.MarginReal		
	FROM 	#tmpTraderPerformanceBetChoice AS b WITH (NOLOCK);
	
	DROP TABLE #tmp8RMPerformanceBetChoice;
	DROP TABLE #tmpTraderPerformanceBetChoice;
END;

GO
/*<info serverAlias="DBTGRS-bodb_TGRS" executers="bodbTGRSNet" isFunction="0" isNested="0"></info>*/