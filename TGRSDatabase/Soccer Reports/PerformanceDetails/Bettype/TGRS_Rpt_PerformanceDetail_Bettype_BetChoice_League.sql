ALTER PROCEDURE [dbo].[TGRS_Rpt_PerformanceDetail_Bettype_BetChoice_League]  	
		@FromDate			DATE
	,	@ToDate				DATE
	,	@LeagueName			NVARCHAR(500)= ''
	,	@LeagueGroupIds		VARCHAR(2000) =  ''
	,	@Bettype			SMALLINT
	,	@BetChoice			NVARCHAR(50)
	,	@IsExcludeLeagues	BIT = 1
	,	@Market				SMALLINT = 1
AS    
/*  
	 Created:	20200731@John.Ngo
	 Task :		Detail report - Bet choice detail from Bet Type - Bet Choice - League
	 DB:		DBTGRS.bodb_TGRS
	 Original:  
 
	 Revisions:
		- 20200731@John.Ngo:	View down bet choice from League performance [Redmine ID: 137278]
		- 20200909@John.Ngo:	Performance Detail - Bettype - Support filter by LeagueName [Redmine ID: 141294]
		- 20210419@John.Ngo:	Wrong data Bettype betchoice league detail [Redmine ID: 153628]
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
			LeagueId			INT		
		,	IsLive				BIT
		,	TurnoverReal		MONEY
		,	WinLossReal			MONEY
		,	MarginReal			MONEY
		,	PRIMARY KEY CLUSTERED (
				LeagueId		ASC
			,	IsLive			ASC
		)
	);	
	
	IF	OBJECT_ID('tempdb..#tmpTraderPerformanceBetChoice') IS NOT NULL
	BEGIN
		DROP TABLE	#tmpTraderPerformanceBetChoice;
	END;

	CREATE TABLE #tmpTraderPerformanceBetChoice (
			LeagueId			INT
		,	LeagueName			NVARCHAR(500)
		,	LeagueGroupID		INT
		,	IsLive				BIT	
		,	TraderCount			INT		
		,	MatchCount			INT
		,	Turnover			MONEY
		,	WinLoss				MONEY
		,	Margin				MONEY
		,	TurnoverReal		MONEY
		,	WinLossReal			MONEY	
		,	MarginReal			MONEY
		,	BetCount			INT		
	);
 
	DECLARE @LeagueGroups AS TABLE (LeagueGroupId SMALLINT PRIMARY KEY CLUSTERED)
	IF @LeagueGroupIds <> ''
	BEGIN
		INSERT INTO @LeagueGroups(LeagueGroupId)
		SELECT val 
		FROM dbo.strSplit_Key(@LeagueGroupIds,',');

		IF CHARINDEX('12', @LeagueGroupIds) > 0
		BEGIN
			DELETE FROM @LeagueGroups
			WHERE LeagueGroupId = 12;

			INSERT INTO @LeagueGroups(LeagueGroupId)
			SELECT DISTINCT l.LeagueGroupID
			FROM bodb02.dbo.league AS l WITH(NOLOCK)
			WHERE l.LeagueGroupID NOT IN (1,2,3,4,5,6,7,8,9,10,11);
		END;
	END;
  
	IF (@LeagueName IS NULL OR @LeagueName = '')
		BEGIN
			INSERT INTO #tmp8RMPerformanceBetChoice(LeagueId
				,	IsLive
				,	TurnoverReal
				,	WinLossReal
				,	MarginReal)
			SELECT 	P.LeagueId		
				,	P.IsLive 
				,	ISNULL(SUM(P.Stake_Real),0) AS TurnoverReal
				,	ISNULL(SUM(P.WinLost_Real),0) -  ISNULL(SUM(P.Comm),0) - ISNULL(SUM(P.Comm_VAR),0) AS WinLossReal
				,	CASE WHEN ISNULL(SUM(P.Stake_Real), 0) <> 0 THEN (ISNULL(SUM(P.WinLost_Real), 0) - ISNULL(SUM(P.Comm),0) - ISNULL(SUM(P.Comm_VAR),0)) * 100/SUM(P.Stake_Real) ELSE NULL END AS MarginReal
			FROM dbo.TraderPerformance_BetChoice AS P WITH (NOLOCK) 
				INNER JOIN bodb02.dbo.League AS L WITH (NOLOCK) ON P.LeagueId = L.LeagueId
				LEFT JOIN @LeagueGroups AS lg ON L.LeagueGroupId = lg.LeagueGroupId
				LEFT JOIN dbo.BetChoiceMapping AS bcm WITH (NOLOCK) ON bcm.BetType = @Bettype AND bcm.BetChoice = p.BetChoice
				LEFT JOIN dbo.LeagueExclusion le WITH(NOLOCK) ON P.LeagueId = le.LeagueId
			WHERE 	 P.Is8RM = 1
				AND	 P.EventDate BETWEEN @FromDate AND @ToDate			
				AND  P.Bettype = @Bettype AND ISNULL(bcm.TGRSBetChoice,P.BetChoice) = @BetChoice
				AND (@Market = -1 OR P.IsLive = @Market)
				AND (@IsExcludeLeagues = 0 OR le.LeagueId IS NULL) 
				AND (@LeagueGroupIds = '' OR lg.LeagueGroupId IS NOT NULL)
			GROUP BY P.LeagueId, P.IsLive;
			
			INSERT INTO #tmpTraderPerformanceBetChoice(LeagueId
				,	LeagueName
				,	LeagueGroupID
				,	IsLive
				,	TraderCount
				,	MatchCount
				,	Turnover
				,	WinLoss
				,	BetCount
				,	Margin
				,	TurnoverReal
				,	WinLossReal
				,	MarginReal)
			SELECT 	P.LeagueId
				,	L.LeagueName
				,	L.LeagueGroupID
				,	P.IsLive
				,	ISNULL(COUNT(DISTINCT P.CustId), 0) AS TraderCount  
				,	ISNULL(COUNT(DISTINCT P.MatchId), 0) AS MatchCount
				,	ISNULL(SUM(P.Stake), 0) AS Turnover 
				,	ISNULL(SUM(P.WinLost), 0) - ISNULL(SUM (P.Comm), 0) AS WinLoss  
				,	ISNULL(SUM(P.BetCount), 0) AS BetCount  
				,	CASE WHEN ISNULL(SUM(P.Stake), 0) <> 0 THEN (ISNULL(SUM(P.WinLost), 0) - ISNULL(SUM(P.Comm), 0)) * 100/SUM(P.Stake) ELSE NULL END AS Margin
				,	ISNULL(SUM(P.Stake_Real),0) AS TurnoverReal
				,	ISNULL(SUM(P.WinLost_Real),0) -  ISNULL(SUM(P.Comm),0) - ISNULL(SUM(P.Comm_VAR),0) AS WinLossReal
				,	CASE WHEN ISNULL(SUM(P.Stake_Real), 0) <> 0 THEN (ISNULL(SUM(P.WinLost_Real), 0) - ISNULL(SUM(P.Comm),0) - ISNULL(SUM(P.Comm_VAR),0)) * 100/SUM(P.Stake_Real) ELSE NULL END AS MarginReal
			FROM dbo.TraderPerformance_BetChoice AS P WITH (NOLOCK)    
				INNER JOIN bodb02.dbo.League AS L WITH (NOLOCK) ON P.LeagueId = L.LeagueId
				LEFT JOIN @LeagueGroups AS lg ON L.LeagueGroupId = lg.LeagueGroupId
				LEFT JOIN dbo.BetChoiceMapping AS bcm WITH (NOLOCK) ON bcm.BetType = @Bettype AND bcm.BetChoice = p.BetChoice
				LEFT JOIN dbo.LeagueExclusion le WITH(NOLOCK) ON P.LeagueId = le.LeagueId
			WHERE P.EventDate BETWEEN @FromDate AND @ToDate
				AND  P.Bettype = @Bettype AND ISNULL(bcm.TGRSBetChoice,P.BetChoice) = @BetChoice
				AND (@Market = -1 OR P.IsLive = @Market)
				AND (@IsExcludeLeagues = 0 OR le.LeagueId IS NULL) 
				AND (@LeagueGroupIds = '' OR lg.LeagueGroupId IS NOT NULL)
			GROUP BY P.LeagueId, L.LeagueName, L.LeagueGroupID, P.IsLive
			ORDER BY Margin DESC, LeagueName ASC;
		END;
	ELSE
		BEGIN
			INSERT INTO #tmp8RMPerformanceBetChoice(LeagueId
				,	IsLive
				,	TurnoverReal
				,	WinLossReal
				,	MarginReal)
			SELECT 	P.LeagueId					
				,	P.IsLive
				,	ISNULL(SUM(P.Stake_Real),0) AS TurnoverReal
				,	ISNULL(SUM(P.WinLost_Real),0) -  ISNULL(SUM(P.Comm),0) - ISNULL(SUM(P.Comm_VAR),0) AS WinLossReal
				,	CASE WHEN ISNULL(SUM(P.Stake_Real), 0) <> 0 THEN (ISNULL(SUM(P.WinLost_Real), 0) - ISNULL(SUM(P.Comm),0) - ISNULL(SUM(P.Comm_VAR),0)) * 100/SUM(P.Stake_Real) ELSE NULL END AS MarginReal
			FROM dbo.TraderPerformance_BetChoice AS P WITH (NOLOCK) 
				INNER JOIN bodb02.dbo.League AS L WITH (NOLOCK) ON P.LeagueId = L.LeagueId
				LEFT JOIN @LeagueGroups AS lg ON L.LeagueGroupId = lg.LeagueGroupId
				LEFT JOIN dbo.BetChoiceMapping AS bcm WITH (NOLOCK) ON bcm.BetType = @Bettype AND bcm.BetChoice = p.BetChoice
				LEFT JOIN dbo.LeagueExclusion le WITH(NOLOCK) ON P.LeagueId = le.LeagueId
			WHERE 	P.Is8RM = 1
				AND	P.EventDate BETWEEN @FromDate AND @ToDate
				AND P.Bettype = @Bettype AND ISNULL(bcm.TGRSBetChoice,P.BetChoice) = @BetChoice
				AND L.LeagueName LIKE '%' + @LeagueName + '%'
				AND (@Market = -1 OR P.IsLive = @Market)
				AND (@IsExcludeLeagues = 0 OR le.LeagueId IS NULL) 
				AND (@LeagueGroupIds = '' OR lg.LeagueGroupId IS NOT NULL)
			GROUP BY P.LeagueId, P.IsLive;			
			
			INSERT INTO #tmpTraderPerformanceBetChoice(LeagueId
				,	LeagueName
				,	LeagueGroupID
				,	IsLive
				,	TraderCount
				,	MatchCount
				,	Turnover
				,	WinLoss
				,	BetCount
				,	Margin
				,	TurnoverReal
				,	WinLossReal
				,	MarginReal)
			SELECT 	P.LeagueId
				,	L.LeagueName
				,	L.LeagueGroupID
				,	P.IsLive
				,	ISNULL(COUNT(DISTINCT P.CustId), 0) AS TraderCount  
				,	ISNULL(COUNT(DISTINCT P.MatchId), 0) AS MatchCount
				,	ISNULL(SUM(P.Stake), 0) AS Turnover  
				,	ISNULL(SUM(P.WinLost), 0) - ISNULL(SUM (P.Comm), 0) AS WinLoss  
				,	ISNULL(SUM(P.BetCount), 0) AS BetCount  
				,	CASE WHEN ISNULL(SUM(P.Stake), 0) <> 0 THEN (ISNULL(SUM(P.WinLost), 0) - ISNULL(SUM(P.Comm), 0)) * 100/SUM(P.Stake) ELSE NULL END AS Margin
				,	ISNULL(SUM(P.Stake_Real),0) AS TurnoverReal
				,	ISNULL(SUM(P.WinLost_Real),0) -  ISNULL(SUM(P.Comm),0) - ISNULL(SUM(P.Comm_VAR),0) AS WinLossReal
				,	CASE WHEN ISNULL(SUM(P.Stake_Real), 0) <> 0 THEN (ISNULL(SUM(P.WinLost_Real), 0) - ISNULL(SUM(P.Comm),0) - ISNULL(SUM(P.Comm_VAR),0)) * 100/SUM(P.Stake_Real) ELSE NULL END AS MarginReal
			FROM dbo.TraderPerformance_BetChoice AS P WITH (NOLOCK)    
				INNER JOIN bodb02.dbo.League AS L WITH (NOLOCK) ON P.LeagueId = L.LeagueId
				LEFT JOIN @LeagueGroups AS lg ON L.LeagueGroupId = lg.LeagueGroupId
				LEFT JOIN dbo.BetChoiceMapping AS bcm WITH (NOLOCK) ON bcm.BetType = @Bettype AND bcm.BetChoice = p.BetChoice
				LEFT JOIN dbo.LeagueExclusion le WITH(NOLOCK) ON P.LeagueId = le.LeagueId
			WHERE P.EventDate BETWEEN @FromDate AND @ToDate
				AND  P.Bettype = @Bettype AND ISNULL(bcm.TGRSBetChoice,P.BetChoice) = @BetChoice
				AND L.LeagueName LIKE '%' + @LeagueName + '%'
				AND (@Market = -1 OR P.IsLive = @Market)
				AND (@IsExcludeLeagues = 0 OR le.LeagueId IS NULL) 
				AND (@LeagueGroupIds = '' OR lg.LeagueGroupId IS NOT NULL)
			GROUP BY P.LeagueId, L.LeagueName, L.LeagueGroupID, P.IsLive    
			ORDER BY Margin DESC, LeagueName ASC;     
		END;
		
	SELECT	b.LeagueId	
		,	b.LeagueName
		,	b.LeagueGroupID
		,	b.IsLive 
		,	b.TraderCount
		,	b.MatchCount
		,	b.BetCount
		,	b.Turnover
		,	b.WinLoss
		,	b.Margin
		,	b.TurnoverReal + r.TurnoverReal AS TurnoverReal
		,	b.WinLossReal - r.WinLossReal AS WinLossReal
		,	b.MarginReal		
	FROM 	#tmpTraderPerformanceBetChoice AS b WITH (NOLOCK)
	LEFT JOIN #tmp8RMPerformanceBetChoice AS r WITH(NOLOCK) ON b.LeagueId = r.LeagueId 
			AND b.IsLive = r.IsLive;
	
	DROP TABLE #tmp8RMPerformanceBetChoice;
	DROP TABLE #tmpTraderPerformanceBetChoice;	
END;

GO
/*<info serverAlias="DBTGRS-bodb_TGRS" executers="bodbTGRSNet" isFunction="0" isNested="0"></info>*/