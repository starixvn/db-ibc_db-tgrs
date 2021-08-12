ALTER PROCEDURE [dbo].[TGRS_Rpt_PerformanceDetail_Bettype_Trader_Match]  	
		@FromDate			DATE
	,	@ToDate				DATE
	,	@LeagueName			NVARCHAR(500)= ''
	,	@LeagueGroupIds		VARCHAR(2000) = ''
	,	@CustId				INT
	,	@Bettype			SMALLINT
	,	@IsExcludeLeagues	BIT = 1
	,	@Market				SMALLINT = 1
AS    
/*  
	Created:	20160315@Thai.Tran
	Task:		Detail report - View Match detail from Bet Type, League and Trader
	DB:			DBTGRS.bodb_TGRS
	Original:      
	  			
	Revision:
		- 20171205@Simon:		get only Live data & Bettypes are not disabled
		- 20180912@Simon:		add league exclusion
		- 20190919@Long.Luu:	Support Nonlive Data [Redmine ID: 118959]
		- 20191023@John.Ngo:	Enhance performance [Redmine ID: 121268]
		- 20200710@John.Ngo:	Performance Detail - Support filter by league group [Redmine ID: 137276]
		- 20200909@John.Ngo:	Performance Detail - Bettype - Support filter by LeagueName [Redmine ID: 141294]
		- 202100809@Adam.Tran: 	Sports - Performance Real Figures [Redmine: #158981]

	Param's Explanation:  
		- @Market: -1 All; 0 Nonlive; 1 Live 	
	
	Example: 
		exec [TGRS_Rpt_PerformanceDetail_Bettype_Trader_Match] @Bettype=3,@FromDate='2016-03-02 00:00:00',@ToDate='2016-03-16 00:00:00',@CustId=2438 
*/  
 
BEGIN 
    SET NOCOUNT ON;			   
	
	IF	OBJECT_ID('tempdb..#tmp8RMPerformance') IS NOT NULL
	BEGIN
		DROP TABLE	#tmp8RMPerformance;
	END;
	
	CREATE TABLE	#tmp8RMPerformance (
			MatchId				INT	
		,	IsLive				BIT
		,	TurnoverReal		MONEY
		,	WinLossReal			MONEY
		,	MarginReal			MONEY
		,	PRIMARY KEY CLUSTERED (
				MatchId			ASC
			,	IsLive			ASC
		)
	);
	
	IF	OBJECT_ID('tempdb..#tmpTraderDetail') IS NOT NULL
	BEGIN
		DROP TABLE	#tmpTraderDetail;
	END;

	CREATE TABLE #tmpTraderDetail (
			MatchId				INT
		,	LeagueId			INT
		,	LeagueGroupId		INT
		,	HomeId				INT
		,	AwayId				INT
		,	EventDate			DATE
		,	IsLive				BIT
		,	BetCount			INT		
		,	Turnover			MONEY
		,	WinLoss				MONEY		
		,	Margin				MONEY
		,	TurnoverReal		MONEY
		,	WinLossReal			MONEY
		,	MarginReal			MONEY		
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
			INSERT INTO #tmp8RMPerformance(MatchId
				,	IsLive
				,	TurnoverReal
				,	WinLossReal)
			SELECT	P.MatchId
				,	P.IsLive
				,	ISNULL(SUM(P.Stake_Real),0) 		AS TurnoverReal
				,	ISNULL(SUM(P.WinLost_Real),0)		AS WinLossReal
			FROM dbo.TraderPerformance AS P WITH (NOLOCK)
				INNER JOIN bodb02.dbo.League AS L WITH (NOLOCK) ON P.LeagueId = L.LeagueId
				LEFT JOIN @LeagueGroups AS lg ON L.LeagueGroupId = lg.LeagueGroupId
				LEFT JOIN dbo.LeagueExclusion le WITH(NOLOCK) ON P.LeagueId = le.LeagueId
			WHERE	P.Is8RM = 1 
				AND P.CustId = @CustId
				AND P.BetType = @Bettype
				AND P.EventDate BETWEEN @FromDate AND @ToDate
				AND (@Market = -1 OR P.IsLive = @Market)
				AND (@IsExcludeLeagues = 0 OR le.LeagueId IS NULL)
				AND (@LeagueGroupIds = '' OR lg.LeagueGroupId IS NOT NULL)
			GROUP BY P.MatchId, P.IsLive;
			
			INSERT INTO #tmpTraderDetail (MatchId
				,	LeagueId
				,	LeagueGroupId
				,	HomeId
				,	AwayId
				,	EventDate
				,	IsLive
				,	BetCount
				,	Turnover
				,	WinLoss						
				,	Margin
				,	TurnoverReal
				,	WinLossReal
				,	MarginReal)
			SELECT 	P.MatchId
				, 	P.LeagueId
				, 	L.LeagueGroupID
				, 	P.HomeId
				, 	P.AwayId
				, 	P.EventDate
				, 	P.IsLive
				,	ISNULL(SUM(P.BetCount), 0) as BetCount
				,	ISNULL(SUM(P.Stake), 0) AS Turnover
				,	ISNULL(SUM(P.WinLost), 0) - ISNULL(SUM(P.Comm), 0) AS WinLoss				
				,	CASE WHEN ISNULL(SUM(P.Stake), 0) <> 0 THEN (ISNULL(SUM(P.WinLost), 0)- ISNULL(SUM(P.Comm), 0)) * 100/ISNULL(SUM(P.Stake), 0) ELSE NULL END AS Margin
				,	ISNULL(SUM(P.Stake_Real),0) 		AS TurnoverReal
				,	ISNULL(SUM(P.WinLost_Real),0)		AS WinLossReal
				,	CASE WHEN ISNULL(SUM(P.Stake_Real), 0) <> 0 THEN (ISNULL(SUM(P.WinLost_Real), 0)) * 100/SUM(P.Stake_Real) ELSE NULL END AS MarginReal
			 FROM	dbo.TraderPerformance AS P WITH (NOLOCK)
	 			INNER JOIN bodb02.dbo.League AS L WITH (NOLOCK) ON P.LeagueId = L.LeagueId
				LEFT JOIN @LeagueGroups AS lg ON L.LeagueGroupId = lg.LeagueGroupId
				LEFT JOIN dbo.LeagueExclusion le WITH(NOLOCK) ON P.LeagueId = le.LeagueId
			 WHERE	P.CustId = @CustId
				AND P.BetType = @Bettype
				AND P.EventDate BETWEEN @FromDate AND @ToDate
				AND (@Market = -1 OR P.IsLive = @Market)
				AND (@IsExcludeLeagues = 0 OR le.LeagueId IS NULL)
				AND (@LeagueGroupIds = '' OR lg.LeagueGroupId IS NOT NULL)
			GROUP BY P.MatchId, P.LeagueId, L.LeagueGroupID, P.HomeId, P.AwayId, P.EventDate, P.IsLive
			ORDER BY Margin DESC, P.EventDate ASC;
		END;
	ELSE
		BEGIN
			INSERT INTO #tmp8RMPerformance(MatchId
				,	IsLive
				,	TurnoverReal
				,	WinLossReal)
			SELECT	P.MatchId
				,	P.IsLive
				,	ISNULL(SUM(P.Stake_Real),0) 		AS TurnoverReal
				,	ISNULL(SUM(P.WinLost_Real),0)		AS WinLossReal
			FROM dbo.TraderPerformance AS P WITH (NOLOCK)
				INNER JOIN bodb02.dbo.League AS L WITH (NOLOCK) ON P.LeagueId = L.LeagueId
				LEFT JOIN @LeagueGroups AS lg ON L.LeagueGroupId = lg.LeagueGroupId
				LEFT JOIN dbo.LeagueExclusion le WITH(NOLOCK) ON P.LeagueId = le.LeagueId
			WHERE	P.Is8RM = 1 
				AND	P.CustId = @CustId
				AND P.BetType = @Bettype
				AND P.EventDate BETWEEN @FromDate AND @ToDate
				AND L.LeagueName LIKE '%' + @LeagueName + '%'
				AND (@Market = -1 OR P.IsLive = @Market)
				AND (@IsExcludeLeagues = 0 OR le.LeagueId IS NULL)
				AND (@LeagueGroupIds = '' OR lg.LeagueGroupId IS NOT NULL)
			GROUP BY P.MatchId, P.IsLive;
			
			INSERT INTO #tmpTraderDetail (MatchId
					,	LeagueId
					,	LeagueGroupId
					,	HomeId
					,	AwayId
					,	EventDate
					,	IsLive
					,	BetCount
					,	Turnover
					,	WinLoss								
					,	Margin
					,	TurnoverReal
					,	WinLossReal
					,	MarginReal)
			SELECT 	P.MatchId
				, 	P.LeagueId
				, 	L.LeagueGroupID
				, 	P.HomeId
				, 	P.AwayId
				, 	P.EventDate
				, 	P.IsLive
				,	ISNULL(SUM(P.BetCount), 0) as BetCount
				,	ISNULL(SUM(P.Stake), 0) AS Turnover
				,	ISNULL(SUM(P.WinLost), 0) - ISNULL(SUM(P.Comm), 0) AS WinLoss				
				,	CASE WHEN ISNULL(SUM(P.Stake), 0) <> 0 THEN (ISNULL(SUM(P.WinLost), 0)- ISNULL(SUM(P.Comm), 0)) * 100/ISNULL(SUM(P.Stake), 0) ELSE NULL END AS Margin
				,	ISNULL(SUM(P.Stake_Real),0) 	AS TurnoverReal
				,	ISNULL(SUM(P.WinLost_Real),0)	AS WinLossReal
				,	CASE WHEN ISNULL(SUM(P.Stake_Real), 0) <> 0 THEN (ISNULL(SUM(P.WinLost_Real), 0)) * 100/SUM(P.Stake_Real) ELSE NULL END AS MarginReal
			 FROM	dbo.TraderPerformance AS P WITH (NOLOCK)
	 			INNER JOIN bodb02.dbo.League AS L WITH (NOLOCK) ON P.LeagueId = L.LeagueId
				LEFT JOIN @LeagueGroups AS lg ON L.LeagueGroupId = lg.LeagueGroupId
				LEFT JOIN dbo.LeagueExclusion le WITH(NOLOCK) ON P.LeagueId = le.LeagueId		 
			 WHERE	P.CustId = @CustId
				AND P.BetType = @Bettype
				AND P.EventDate BETWEEN @FromDate AND @ToDate
				AND L.LeagueName LIKE '%' + @LeagueName + '%'
				AND (@Market = -1 OR P.IsLive = @Market)
				AND (@IsExcludeLeagues = 0 OR le.LeagueId IS NULL)
				AND (@LeagueGroupIds = '' OR lg.LeagueGroupId IS NOT NULL)
			GROUP BY P.MatchId, P.LeagueId, L.LeagueGroupID, P.HomeId, P.AwayId, P.EventDate, P.IsLive
			ORDER BY Margin DESC, P.EventDate ASC;
		END;

	UPDATE P
	SET   P.TurnoverReal = P.TurnoverReal + r.TurnoverReal
		, P.WinLossReal = P.WinLossReal - r.WinLossReal
		, P.MarginReal		= CASE WHEN ISNULL(P.TurnoverReal + r.TurnoverReal, 0) <> 0 THEN (ISNULL(P.WinLossReal - r.WinLossReal, 0)) * 100/(P.TurnoverReal + r.TurnoverReal) ELSE NULL END
	FROM #tmpTraderDetail AS P WITH(NOLOCK)
	INNER JOIN #tmp8RMPerformance AS r WITH(NOLOCK) ON  r.MatchId = P.MatchId
		AND r.IsLive = P.IsLive;

	SELECT	b.MatchId
		,	b.LeagueId
		,	b.LeagueGroupId
		,	b.HomeId
		,	b.AwayId
		,	b.EventDate
		,	b.IsLive
		,	b.BetCount
		,	b.Turnover
		,	b.WinLoss		
		,	b.Margin
		,	b.TurnoverReal
		,	b.WinLossReal
		,	b.MarginReal		
	FROM 	#tmpTraderDetail AS b WITH (NOLOCK)
	LEFT JOIN #tmp8RMPerformance AS r WITH(NOLOCK) ON b.MatchId = r.MatchId 
		AND b.IsLive = r.IsLive;
	
	DROP TABLE #tmpTraderDetail;
	DROP TABLE #tmp8RMPerformance;
	
END;

GO
/*<info serverAlias="DBTGRS-bodb_TGRS" executers="bodbTGRSNet" isFunction="0" isNested="0"></info>*/