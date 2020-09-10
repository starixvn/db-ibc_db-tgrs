ALTER PROCEDURE [dbo].[TGRS_Rpt_PerformanceDetail_BetType]
		@FromDate			DATE
	,	@ToDate				DATE
	,	@LeagueName			NVARCHAR(500)= ''
	,	@LeagueGroupIds		VARCHAR(2000) = ''
	,	@Turnover			MONEY = NULL
	,	@WinLoss			MONEY = NULL
	,	@MarginFrom			MONEY = NULL
	,	@MarginTo			MONEY = NULL
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

	Param's Explanation:  	
		- @Market: -1 All; 0 Nonlive; 1 Live

	Exam: EXEC [TGRS_Rpt_PerformanceDetail_BetType] @FromDate = '2014-01-01', @ToDate= '2015-12-30' 
  
*/  
 
BEGIN 
	SET NOCOUNT ON;
	
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
		,	BetCount			INT
		,	Margin				MONEY
	);
	
	CREATE CLUSTERED INDEX #CIX_tmpTraderPerformanceIdx ON #tmpTraderPerformance (
			BetType			ASC
	); 

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
				,	BetCount
				,	Margin	)
			SELECT P.BetType, 	
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
				,	BetCount
				,	Margin	)
			SELECT P.BetType, 	
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
				 	
	 SELECT	P.BetType, 
		TN.TypeName,
		P.TraderCount, 
		P.LeagueCount,
		P.MatchCount,
		P.Turnover, 
		P.WinLoss, 
		P.BetCount,
		P.Margin,
		P.IsLive 
	 FROM	#tmpTraderPerformance AS P WITH (NOLOCK)
		LEFT JOIN dbo.BetType AS TN WITH (NOLOCK) ON TN.BetType = P.BetType	 	 
	 WHERE	(@Turnover IS NULL OR P.Turnover >= @Turnover)
		AND (@WinLoss IS NULL  OR P.WinLoss >= @WinLoss)
		AND ( @MarginFrom IS NULL  OR P.Margin >= @MarginFrom)
		AND ( @MarginTo IS NULL OR P.Margin <= @MarginTo)
	ORDER BY P.Margin DESC, P.Bettype ASC;

END;

GO
/*<info serverAlias="DBTGRS-bodb_TGRS" executers="bodbTGRSNet" isFunction="0" isNested="0"></info>*/