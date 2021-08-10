ALTER PROCEDURE [dbo].[TGRS_Rpt_PerformanceDetail_BetType]
		@FromDate			DATE
	,	@ToDate				DATE
	,	@LeagueName			NVARCHAR(500)= ''
	,	@LeagueGroupIds		VARCHAR(2000) = ''
	,	@Turnover			MONEY = NULL
	,	@WinLoss			MONEY = NULL
	,	@MarginFrom			MONEY = NULL
	,	@MarginTo			MONEY = NULL
	,	@IsReal				BIT = 0
	,	@TurnoverReal		MONEY = NULL
	,	@WinLossReal		MONEY = NULL
	,	@MarginFromReal		MONEY = NULL
	,	@MarginToReal		MONEY = NULL
	,	@Bettypes			VARCHAR(2000) = '0'
	,	@IsExcludeLeagues	BIT = 1
	,	@Market				SMALLINT = 1
AS
/*  
	Created:	20160216@Thai
	Task :		Detail report - BetType Performance
	DB:			DBTGRS.bodb_TGRS
	Original:  
  
	Revisions: 	
   		- 20171019@Simon:		Change VARCHAR(200) to VARCHAR(2000)
		- 20171205@Simon:		get only Live data & Bettypes are not disabled
		- 20180912@Simon:		add league exclusion
		- 20190919@Long.Luu:	Support Nonlive Data [Redmine ID: 118959]
		- 20191023@John.Ngo:	Enhance performance [Redmine ID: 121268]
		- 20200710@John.Ngo:	Performance Detail - Support filter by league group [Redmine ID: 137276]
		- 20200909@John.Ngo:	Performance Detail - Bettype - Support filter by LeagueName [Redmine ID: 141294]
		- 202100805@Adam.Tran: 	Sports - Performance Real Figures [Redmine: #158981]
		
	Param's Explanation:  	
		- @Market: -1 All; 0 Nonlive; 1 Live

	Exam: EXEC [TGRS_Rpt_PerformanceDetail_BetType] @FromDate = '2014-01-01', @ToDate= '2015-12-30' 
  
*/  
 
BEGIN 
	SET NOCOUNT ON;
	
	IF	OBJECT_ID('tempdb..#tmpTraderPerformance') IS NOT NULL
	BEGIN
		DROP TABLE	#tmpTraderPerformance;
	END;

	CREATE TABLE #tmpTraderPerformance (
			BetType				SMALLINT
		,	IsLive				BIT		
		,	TraderCount			INT
		,	LeagueCount			INT
		,	MatchCount			INT
		,	Turnover			MONEY
		,	WinLoss				MONEY			
		,	TurnoverReal		MONEY
		,	WinLossReal			MONEY		
		,	BetCount			INT
	);
	
	CREATE CLUSTERED INDEX #CIX_tmpTraderPerformanceIdx ON #tmpTraderPerformance (
			BetType			ASC
	); 
	
	IF	OBJECT_ID('tempdb..#tmpTraderPerformanceMeasure') IS NOT NULL
	BEGIN
		DROP TABLE	#tmpTraderPerformanceMeasure;
	END;

	CREATE TABLE #tmpTraderPerformanceMeasure (
			BetType				SMALLINT
		,	TypeName			NVARCHAR(500)
		,	IsLive				BIT		
		,	TraderCount			INT
		,	LeagueCount			INT
		,	MatchCount			INT
		,	Turnover			MONEY
		,	WinLoss				MONEY
		,	Margin				MONEY		
		,	TurnoverReal		MONEY
		,	WinLossReal			MONEY	
		,	MarginReal			MONEY
		,	BetCount			INT
	);
	
	CREATE CLUSTERED INDEX #CIX_tmpTraderPerformanceMeasureIdx ON #tmpTraderPerformanceMeasure (
			BetType			ASC
	); 
	
	IF	OBJECT_ID('tempdb..#tmp8RMPerformance') IS NOT NULL
	BEGIN
		DROP TABLE	#tmp8RMPerformance;
	END;
	
	CREATE TABLE	#tmp8RMPerformance (
			BetType				SMALLINT	
		,	IsLive				BIT			
		,	TurnoverReal		MONEY
		,	WinLossReal			MONEY		
		,	PRIMARY KEY CLUSTERED (
					BetType		ASC		
				,	IsLive			ASC
		)
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

	DECLARE @BettypeList AS TABLE (bettype SMALLINT)
	IF @Bettypes <> '0'
		BEGIN
			INSERT INTO @BettypeList
			SELECT val 
			FROM dbo.strSplit_Key(@Bettypes,',');
		END;
	ELSE
		BEGIN
			INSERT INTO @BettypeList
			SELECT Bettype 
			FROM dbo.Bettype WITH (NOLOCK);
		END;	

	INSERT INTO #tmp8RMPerformance(BetType, IsLive, TurnoverReal, WinLossReal)
	SELECT	P.BetType	
		,	P.IsLive
		,	ISNULL(SUM(P.Stake_Real),0) AS TurnoverReal
		,	ISNULL(SUM(P.WinLost_Real),0) -  ISNULL(SUM(P.Comm),0) - ISNULL(SUM(P.Comm_VAR),0) AS WinLossReal			
	FROM dbo.TraderPerformance AS P WITH (NOLOCK)
		INNER JOIN bodb02.dbo.League AS L WITH (NOLOCK) ON P.LeagueId = L.LeagueId
		LEFT JOIN @LeagueGroups AS lg ON L.LeagueGroupId = lg.LeagueGroupId
		LEFT JOIN dbo.LeagueExclusion le WITH(NOLOCK) ON P.LeagueId = le.LeagueId
		LEFT JOIN @BettypeList bl ON p.bettype = bl.bettype
	WHERE	P.Is8RM = 1
		AND P.EventDate BETWEEN @FromDate AND @ToDate			
		AND (@Bettypes = '0' OR bl.bettype IS NOT NULL)
		AND (@Market = -1 OR P.IsLive = @Market)
		AND (@IsExcludeLeagues = 0 OR le.LeagueId IS NULL)
		AND (@LeagueGroupIds = '' OR lg.LeagueGroupId IS NOT NULL)		
	GROUP BY P.BetType, P.IsLive;

	IF (@LeagueName IS NULL OR @LeagueName = '')
		BEGIN
			INSERT INTO #tmpTraderPerformance (
					BetType
				,	IsLive
				,	TraderCount
				,	LeagueCount
				,	MatchCount
				,	Turnover
				,	WinLoss				
				,	TurnoverReal
				,	WinLossReal
				,	BetCount)
			SELECT 	P.BetType
				,	P.IsLive
				,	ISNULL(COUNT(DISTINCT P.CustId), 0) AS TraderCount
				,	ISNULL(COUNT(DISTINCT P.LeagueId), 0) AS LeagueCount
				,	ISNULL(COUNT(DISTINCT P.MatchId), 0) AS MatchCount 
				,	ISNULL(SUM(P.Stake), 0) AS Turnover
				,	ISNULL(SUM(P.WinLost), 0) - ISNULL(SUM (P.Comm), 0) AS WinLoss					
				,	ISNULL(SUM(P.Stake_Real),0) AS TurnoverReal
				,	ISNULL(SUM(P.WinLost_Real),0) -  ISNULL(SUM(P.Comm),0) - ISNULL(SUM(P.Comm_VAR),0) AS WinLossReal				
				,	ISNULL(SUM(P.BetCount), 0) AS BetCount				
			FROM dbo.TraderPerformance AS P WITH (NOLOCK)
				INNER JOIN bodb02.dbo.League AS L WITH (NOLOCK) ON P.LeagueId = L.LeagueId
				LEFT JOIN @LeagueGroups AS lg ON L.LeagueGroupId = lg.LeagueGroupId
				LEFT JOIN dbo.LeagueExclusion le WITH(NOLOCK) ON P.LeagueId = le.LeagueId
				LEFT JOIN @BettypeList bl ON p.bettype = bl.bettype
			WHERE	P.EventDate BETWEEN @FromDate AND @ToDate			
				AND (@Bettypes = '0' OR bl.bettype IS NOT NULL)
				AND (@Market = -1 OR P.IsLive = @Market)
				AND (@IsExcludeLeagues = 0 OR le.LeagueId IS NULL)
				AND (@LeagueGroupIds = '' OR lg.LeagueGroupId IS NOT NULL)
			GROUP BY P.BetType, P.IsLive;
		END;
	ELSE
		BEGIN
			INSERT INTO #tmpTraderPerformance (
					BetType
				,	IsLive
				,	TraderCount
				,	LeagueCount
				,	MatchCount
				,	Turnover
				,	WinLoss
				,	TurnoverReal
				,	WinLossReal
				,	BetCount
				)
			SELECT 	P.BetType
				,	P.IsLive				
				,	ISNULL(COUNT(DISTINCT P.CustId), 0) AS TraderCount
				,	ISNULL(COUNT(DISTINCT P.LeagueId), 0) AS LeagueCount
				,	ISNULL(COUNT(DISTINCT P.MatchId), 0) AS MatchCount
				,	ISNULL(SUM(P.Stake), 0) AS Turnover
				,	ISNULL(SUM(P.WinLost), 0) - ISNULL(SUM (P.Comm), 0) AS WinLoss				
				,	ISNULL(SUM(P.Stake_Real),0) AS TurnoverReal		
				,	ISNULL(SUM(P.WinLost_Real),0) -  ISNULL(SUM(P.Comm),0) - ISNULL(SUM(P.Comm_VAR),0) AS WinLossReal				
				,	ISNULL(SUM(P.BetCount), 0) AS BetCount
			FROM dbo.TraderPerformance AS P WITH (NOLOCK)
				INNER JOIN bodb02.dbo.League AS L WITH (NOLOCK) ON P.LeagueId = L.LeagueId
				LEFT JOIN @LeagueGroups AS lg ON L.LeagueGroupId = lg.LeagueGroupId
				LEFT JOIN dbo.LeagueExclusion le WITH(NOLOCK) ON P.LeagueId = le.LeagueId
				LEFT JOIN @BettypeList bl ON p.bettype = bl.bettype
			WHERE	P.EventDate BETWEEN @FromDate AND @ToDate			
				AND (@Bettypes = '0' OR bl.bettype IS NOT NULL)
				AND L.LeagueName LIKE '%' + @LeagueName + '%'
				AND (@Market = -1 OR P.IsLive = @Market)
				AND (@IsExcludeLeagues = 0 OR le.LeagueId IS NULL)
				AND (@LeagueGroupIds = '' OR lg.LeagueGroupId IS NOT NULL)
			GROUP BY P.BetType, P.IsLive;
		END;
			
	INSERT INTO #tmpTraderPerformanceMeasure (
			BetType
		,	TypeName
		,	IsLive 
		,	TraderCount
		,	LeagueCount
		,	MatchCount
		,	Turnover
		,	WinLoss
		,	Margin
		,	TurnoverReal
		,	WinLossReal
		,	MarginReal
		,	BetCount
		)
	 SELECT	P.BetType
		,	TN.TypeName
		,	P.IsLive 
		,	P.TraderCount
		,	P.LeagueCount
		,	P.MatchCount
		,	P.Turnover
		,	P.WinLoss		
		,	CASE WHEN ISNULL(P.Turnover, 0) <> 0 THEN P.WinLoss * 100/P.Turnover ELSE NULL END AS Margin
		,	P.TurnoverReal + r.TurnoverReal AS TurnoverReal
		,	P.WinLossReal - r.WinLossReal AS WinLossReal		
		,	CASE WHEN ISNULL((P.TurnoverReal + r.TurnoverReal), 0) <> 0 THEN (ISNULL((P.WinLossReal - r.WinLossReal), 0)) * 100/(P.TurnoverReal + r.TurnoverReal) ELSE NULL END AS MarginReal
		,	P.BetCount		
	 FROM	#tmpTraderPerformance AS P WITH (NOLOCK)
		LEFT JOIN dbo.BetType AS TN WITH (NOLOCK) ON TN.BetType = P.BetType
		LEFT JOIN #tmp8RMPerformance AS r WITH(NOLOCK) ON  r.BetType = P.BetType
			AND r.IsLive = P.IsLive
	
	SELECT	m.BetType
		,	m.TypeName
		,	m.IsLive 
		,	m.TraderCount
		,	m.LeagueCount
		,	m.MatchCount
		,	m.Turnover
		,	m.WinLoss
		,	m.Margin
		,	m.TurnoverReal
		,	m.WinLossReal
		,	m.MarginReal
	FROM 	#tmpTraderPerformanceMeasure AS m WITH (NOLOCK)
	WHERE	(@Turnover IS NULL OR m.Turnover >= @Turnover)
		AND (@WinLoss IS NULL  OR m.WinLoss >= @WinLoss)
		AND (@MarginFrom IS NULL  OR m.Margin >= @MarginFrom)
		AND (@MarginTo IS NULL OR m.Margin <= @MarginTo)	
		AND (@IsReal=0 
			OR (@IsReal=1 
				AND (@TurnoverReal IS NULL OR m.TurnoverReal >= @TurnoverReal)
				AND (@WinLossReal IS NULL  OR m.WinLossReal >= @WinLossReal)
				AND (@MarginFromReal IS NULL  OR m.MarginReal >= @MarginFromReal)
				AND (@MarginToReal IS NULL OR m.MarginReal <= @MarginToReal)
			))
	ORDER BY m.Margin, m.Bettype ASC;
	
	DROP TABLE #tmp8RMPerformance;
	DROP TABLE #tmpTraderPerformance;
	DROP TABLE #tmpTraderPerformanceMeasure;

END;

GO
/*<info serverAlias="DBTGRS-bodb_TGRS" executers="bodbTGRSNet" isFunction="0" isNested="0"></info>*/