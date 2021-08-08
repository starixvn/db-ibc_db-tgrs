ALTER PROCEDURE [dbo].[TGRS_Rpt_PerformanceDetail_Bettype_BetChoice]  	
		@FromDate			DATE
	,	@ToDate				DATE
	,	@LeagueName			NVARCHAR(500)= ''
	,	@LeagueGroupIds		VARCHAR(2000) =  ''
	,	@Bettype			SMALLINT
	,	@IsExcludeLeagues	BIT = 1
	,	@Market				SMALLINT = 1
AS    
/*  
	 Created:	20171212@Aaron
	 Task :		Detail report - Bet choice detail from Bet Type
	 DB:		DBTGRS.bodb_TGRS
	 Original:  
 
	 Revisions:
		- 20180912@Simon:		add league exclusion
		- 20190919@Long.Luu:	Support Nonlive Data [Redmine ID: 118959]
		- 20191022@Long.Luu:	Showing betteam in case of betchoices are not mapped [Redmine ID: 121268]
		- 20191023@John.Ngo:	Enhance performance [Redmine ID: 121268]
		- 20200709@John.Ngo:	Performance Detail - Support filter by league group & Fix issue 'show betteam' [Redmine ID: 137276]
		- 20200909@John.Ngo:	Performance Detail - Bettype - Support filter by LeagueName [Redmine ID: 141294]
		- 202100809@Adam.Tran: 	Sports - Performance Real Figures [Redmine: #158981]
	 Param's Explanation:  	
		- @Market: -1 All; 0 Nonlive; 1 Live

	 Exam: 
		EXEC  TGRS_Rpt_PerformanceDetail_Bettype_BetChoice @FromDate = '2017-11-01', @ToDate= '2018-05-30', @Bettype = 15
*/  
 
BEGIN 
	SET NOCOUNT ON;
	
	IF	OBJECT_ID('tempdb..#tmp8RMPerformanceBetChoice') IS NOT NULL
	BEGIN
		DROP TABLE	#tmp8RMPerformanceBetChoice;
	END;
	
	CREATE TABLE	#tmp8RMPerformanceBetChoice (
			BetChoice			NVARCHAR(10)
		,	IsLive				BIT
		,	TurnoverReal		MONEY
		,	WinLossReal			MONEY
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
			BetChoice			NVARCHAR(10)
		,	IsLive				BIT				
		,	LeagueCount			INT
		,	MatchCount			INT
		,	Turnover			MONEY
		,	WinLoss				MONEY			
		,	TurnoverReal		MONEY
		,	WinLossReal			MONEY		
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
			INSERT INTO #tmp8RMPerformanceBetChoice(BetChoice
				,	IsLive
				,	TurnoverReal
				,	WinLossReal)
			SELECT	ISNULL(bcm.TGRSBetChoice, P.BetChoice)			AS BetChoice
				,	P.IsLive
				,	ISNULL(SUM(P.Stake_Real),0) AS TurnoverReal
				,	ISNULL(SUM(P.WinLost_Real),0) -  ISNULL(SUM(P.Comm),0) - ISNULL(SUM(P.Comm_VAR),0) AS WinLossReal
			FROM dbo.TraderPerformance_BetChoice AS P WITH (NOLOCK)
				INNER JOIN bodb02.dbo.League AS L WITH (NOLOCK) ON P.LeagueId = L.LeagueId
				LEFT JOIN @LeagueGroups AS lg ON L.LeagueGroupId = lg.LeagueGroupId
				LEFT JOIN dbo.BetChoiceMapping AS bcm WITH (NOLOCK) ON bcm.BetType = @Bettype
				LEFT JOIN dbo.LeagueExclusion le WITH(NOLOCK) ON P.LeagueId = le.LeagueId			
			WHERE	P.Is8RM = 1 
				AND	P.Bettype = @Bettype
				AND P.EventDate BETWEEN @FromDate AND @ToDate
				AND (@Market = -1 OR P.IsLive = @Market)
				AND (P.BetChoice = bcm.BetChoice OR bcm.BetChoice IS NULL)
				AND (@IsExcludeLeagues = 0 OR le.LeagueId IS NULL)
				AND (@LeagueGroupIds = '' OR lg.LeagueGroupId IS NOT NULL)
			GROUP BY ISNULL(bcm.TGRSBetChoice, P.BetChoice), P.IsLive;
				
			INSERT INTO #tmpTraderPerformanceBetChoice (
					BetChoice
				,	IsLive				
				,	LeagueCount
				,	MatchCount
				,	Turnover
				,	WinLoss				
				,	TurnoverReal
				,	WinLossReal
				,	BetCount)
			SELECT ISNULL(bcm.TGRSBetChoice, P.BetChoice)			AS BetChoice
				,	P.IsLive											AS IsLive
				,	ISNULL(COUNT(DISTINCT P.LeagueId), 0)				AS LeagueCount
				,	ISNULL(COUNT(DISTINCT P.MatchId), 0)				AS MatchCount
				,	ISNULL(SUM(P.Stake), 0)								AS Turnover 
				,	ISNULL(SUM(P.WinLost), 0) - ISNULL(SUM (P.Comm), 0)	AS WinLoss
				,	ISNULL(SUM(P.Stake_Real),0) AS TurnoverReal
				,	ISNULL(SUM(P.WinLost_Real),0) -  ISNULL(SUM(P.Comm),0) - ISNULL(SUM(P.Comm_VAR),0) AS WinLossReal
				,	ISNULL(SUM(P.BetCount), 0)							AS BetCount
			FROM dbo.TraderPerformance_BetChoice AS P WITH (NOLOCK)
				INNER JOIN bodb02.dbo.League AS L WITH (NOLOCK) ON P.LeagueId = L.LeagueId
				LEFT JOIN @LeagueGroups AS lg ON L.LeagueGroupId = lg.LeagueGroupId
				LEFT JOIN dbo.BetChoiceMapping AS bcm WITH (NOLOCK) ON bcm.BetType = @Bettype
				LEFT JOIN dbo.LeagueExclusion le WITH(NOLOCK) ON P.LeagueId = le.LeagueId
			WHERE	P.Bettype = @Bettype
				AND P.EventDate BETWEEN @FromDate AND @ToDate
				AND (@Market = -1 OR P.IsLive = @Market)
				AND (P.BetChoice = bcm.BetChoice OR bcm.BetChoice IS NULL)
				AND (@IsExcludeLeagues = 0 OR le.LeagueId IS NULL)
				AND (@LeagueGroupIds = '' OR lg.LeagueGroupId IS NOT NULL)
			GROUP BY ISNULL(bcm.TGRSBetChoice, P.BetChoice), P.IsLive;
		END;
	ELSE
		BEGIN
			INSERT INTO #tmp8RMPerformanceBetChoice(BetChoice
				,	IsLive
				,	TurnoverReal
				,	WinLossReal)
			SELECT	ISNULL(bcm.TGRSBetChoice, P.BetChoice)			AS BetChoice
				,	P.IsLive
				,	ISNULL(SUM(P.Stake_Real),0) AS TurnoverReal
				,	ISNULL(SUM(P.WinLost_Real),0) -  ISNULL(SUM(P.Comm),0) - ISNULL(SUM(P.Comm_VAR),0) AS WinLossReal
			FROM dbo.TraderPerformance_BetChoice AS P WITH (NOLOCK)
				INNER JOIN bodb02.dbo.League AS L WITH (NOLOCK) ON P.LeagueId = L.LeagueId
				LEFT JOIN @LeagueGroups AS lg ON L.LeagueGroupId = lg.LeagueGroupId
				LEFT JOIN dbo.BetChoiceMapping AS bcm WITH (NOLOCK) ON bcm.BetType = @Bettype
				LEFT JOIN dbo.LeagueExclusion le WITH(NOLOCK) ON P.LeagueId = le.LeagueId		
			WHERE	P.Is8RM = 1 
				AND	P.Bettype = @Bettype
				AND P.EventDate BETWEEN @FromDate AND @ToDate
				AND L.LeagueName LIKE '%' + @LeagueName + '%'
				AND (@Market = -1 OR P.IsLive = @Market)
				AND (P.BetChoice = bcm.BetChoice OR bcm.BetChoice IS NULL)
				AND (@IsExcludeLeagues = 0 OR le.LeagueId IS NULL)
				AND (@LeagueGroupIds = '' OR lg.LeagueGroupId IS NOT NULL)
			GROUP BY ISNULL(bcm.TGRSBetChoice, P.BetChoice), P.IsLive;
				
			INSERT INTO #tmpTraderPerformanceBetChoice (
					BetChoice
				,	IsLive				
				,	LeagueCount
				,	MatchCount
				,	Turnover
				,	WinLoss				
				,	TurnoverReal
				,	WinLossReal
				,	BetCount)
			SELECT ISNULL(bcm.TGRSBetChoice, P.BetChoice)			AS BetChoice
				,	P.IsLive											AS IsLive
				,	ISNULL(COUNT(DISTINCT P.LeagueId), 0)				AS LeagueCount
				,	ISNULL(COUNT(DISTINCT P.MatchId), 0)				AS MatchCount
				,	ISNULL(SUM(P.Stake), 0)								AS Turnover 
				,	ISNULL(SUM(P.WinLost), 0) - ISNULL(SUM (P.Comm), 0)	AS WinLoss
				,	ISNULL(SUM(P.Stake_Real),0) AS TurnoverReal
				,	ISNULL(SUM(P.WinLost_Real),0) -  ISNULL(SUM(P.Comm),0) - ISNULL(SUM(P.Comm_VAR),0) AS WinLossReal
				,	ISNULL(SUM(P.BetCount), 0)							AS BetCount				
			FROM dbo.TraderPerformance_BetChoice AS P WITH (NOLOCK)
				INNER JOIN bodb02.dbo.League AS L WITH (NOLOCK) ON P.LeagueId = L.LeagueId
				LEFT JOIN @LeagueGroups AS lg ON L.LeagueGroupId = lg.LeagueGroupId
				LEFT JOIN dbo.BetChoiceMapping AS bcm WITH (NOLOCK) ON bcm.BetType = @Bettype
				LEFT JOIN dbo.LeagueExclusion le WITH(NOLOCK) ON P.LeagueId = le.LeagueId
			WHERE	P.Bettype = @Bettype
				AND P.EventDate BETWEEN @FromDate AND @ToDate
				AND L.LeagueName LIKE '%' + @LeagueName + '%'
				AND (@Market = -1 OR P.IsLive = @Market)
				AND (P.BetChoice = bcm.BetChoice OR bcm.BetChoice IS NULL)
				AND (@IsExcludeLeagues = 0 OR le.LeagueId IS NULL)
				AND (@LeagueGroupIds = '' OR lg.LeagueGroupId IS NOT NULL)
			GROUP BY ISNULL(bcm.TGRSBetChoice, P.BetChoice), P.IsLive;
		END;	
	
	SELECT	b.BetChoice		
		,	b.IsLive 
		,	b.LeagueCount
		,	b.MatchCount
		,	b.Turnover
		,	b.WinLoss		
		,	b.TurnoverReal + r.TurnoverReal AS TurnoverReal
		,	b.WinLossReal - r.WinLossReal AS WinLossReal
	FROM 	#tmpTraderPerformanceBetChoice AS b WITH (NOLOCK)
	LEFT JOIN #tmp8RMPerformanceBetChoice AS r WITH(NOLOCK) ON b.BetChoice = r.BetChoice 
			AND b.IsLive = r.IsLive;
	
	DROP TABLE #tmp8RMPerformanceBetChoice;
	DROP TABLE #tmpTraderPerformanceBetChoice;	
END;

GO
/*<info serverAlias="DBTGRS-bodb_TGRS" executers="bodbTGRSNet" isFunction="0" isNested="0"></info>*/