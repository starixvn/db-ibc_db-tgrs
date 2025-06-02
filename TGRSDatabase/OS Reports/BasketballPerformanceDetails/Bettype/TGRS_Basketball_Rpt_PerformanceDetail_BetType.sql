CREATE PROCEDURE [dbo].[TGRS_Basketball_Rpt_PerformanceDetail_BetType]
		@FromDate			DATE
	,	@ToDate				DATE
	,	@LeagueName			NVARCHAR(500)= ''
	,	@LeagueGroupIds		VARCHAR(2000) = ''
	,	@Bettypes			VARCHAR(2000) = '0'
	,	@LiveType			SMALLINT = -1
AS    
/*  
	Created:	20200918@John.Ngo
	Task :		Basketball Performance Detail - Bettype
	DB:			DBTGRS.bodb_TGRS
	Original:  
  
	Revisions: 	
   		- 20200918@John.Ngo:	Basketball Performance Detail - Bettype [Redmine ID: 140875]
		- 20250530@Della: [TGR OS] Automatically add the new bet types to Basketball Performance report (#197594)

	Param's Explanation:  	
		- @LiveType: -1 All; 0 Nonlive; 1 Live

	Exam: EXEC [TGRS_Basketball_Rpt_PerformanceDetail_BetType] @FromDate = '2020-01-01', @ToDate= '2020-12-30' 
  
*/  
 
BEGIN 
	SET NOCOUNT ON;
	
	DECLARE @LeagueGroups AS TABLE (LeagueGroupId SMALLINT PRIMARY KEY CLUSTERED, LeagueGroupName NVARCHAR(200))
	IF @LeagueGroupIds <> ''
		BEGIN
			INSERT INTO @LeagueGroups(LeagueGroupId)
			SELECT val 
			FROM dbo.strSplit_Key(@LeagueGroupIds,',');
		END
	ELSE 
		BEGIN
			INSERT INTO @LeagueGroups(LeagueGroupId, LeagueGroupName)
			EXECUTE dbo.TGRS_LeagueGroup_GetBySportId @SportId = 2;
		END;

	DECLARE @BettypeList AS TABLE (BettypeId SMALLINT)
	IF @Bettypes <> '0'
		BEGIN
			INSERT INTO @BettypeList
			SELECT val 
			FROM dbo.strSplit_Key(@Bettypes,',');
		END;
	ELSE
		BEGIN
			INSERT INTO @BettypeList
			SELECT b.BettypeId
			FROM dbo.OSBetType b WITH(NOLOCK)
			WHERE b.GroupBettypeId IN (1,2);
		END;

	IF	OBJECT_ID('tempdb..#tmpOSDataTGRS') IS NOT NULL
	BEGIN
		DROP TABLE	#tmpOSDataTGRS;
	END;

	CREATE TABLE #tmpOSDataTGRS (
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
	
	CREATE CLUSTERED INDEX #CIX_tmpOSDataTGRSIdx ON #tmpOSDataTGRS (
			BetType			ASC
	); 

	IF (@LeagueName IS NULL OR @LeagueName = '')
		BEGIN
			INSERT INTO #tmpOSDataTGRS (
					BetType
				,	IsLive
				,	TraderCount
				,	LeagueCount
				,	MatchCount
				,	Turnover
				,	WinLoss
				,	BetCount
				,	Margin	)
			SELECT P.BettypeId, 	
				P.IsLive,					
				ISNULL(COUNT(DISTINCT P.TraderId), 0) AS TraderCount, 
				ISNULL(COUNT(DISTINCT P.LeagueId), 0) AS LeagueCount, 
				ISNULL(COUNT(DISTINCT P.MatchId), 0) AS MatchCount, 
				ISNULL(SUM(P.Turnover), 0) AS Turnover, 
				ISNULL(SUM(P.Winloss), 0) - ISNULL(SUM (P.Comm), 0) AS WinLoss, 
				ISNULL(SUM(P.BetCount), 0) AS BetCount,
				CASE WHEN ISNULL(SUM(P.Turnover), 0) <> 0 THEN (ISNULL(SUM(P.WinLoss), 0) - ISNULL(SUM(P.Comm), 0)) * 100/SUM(P.Turnover) ELSE NULL END AS Margin
			FROM dbo.OSDataTGRS AS P WITH (NOLOCK)
				INNER JOIN bodb02.dbo.League AS L WITH (NOLOCK) ON P.LeagueId = L.LeagueId
				LEFT JOIN @LeagueGroups AS lg ON L.LeagueGroupId = lg.LeagueGroupId
				LEFT JOIN @BettypeList bl ON p.BettypeId = bl.BettypeId
			WHERE	P.EventDate BETWEEN @FromDate AND @ToDate
				AND P.SportId = 2
				AND (@Bettypes = '0' OR bl.BettypeId IS NOT NULL)
				AND (@LiveType = -1 OR P.IsLive = @LiveType)
				AND (@LeagueGroupIds = '' OR lg.LeagueGroupId IS NOT NULL)
			GROUP BY P.BettypeId, P.IsLive;
		END;
	ELSE
		BEGIN
			INSERT INTO #tmpOSDataTGRS (
					BetType
				,	IsLive
				,	TraderCount
				,	LeagueCount
				,	MatchCount
				,	Turnover
				,	WinLoss
				,	BetCount
				,	Margin	)
			SELECT P.BettypeId, 	
				P.IsLive,					
				ISNULL(COUNT(DISTINCT P.TraderId), 0) AS TraderCount, 
				ISNULL(COUNT(DISTINCT P.LeagueId), 0) AS LeagueCount, 
				ISNULL(COUNT(DISTINCT P.MatchId), 0) AS MatchCount, 
				ISNULL(SUM(P.Turnover), 0) AS Turnover, 
				ISNULL(SUM(P.Winloss), 0) - ISNULL(SUM (P.Comm), 0) AS WinLoss, 
				ISNULL(SUM(P.BetCount), 0) AS BetCount,
				CASE WHEN ISNULL(SUM(P.Turnover), 0) <> 0 THEN (ISNULL(SUM(P.WinLoss), 0) - ISNULL(SUM(P.Comm), 0)) * 100/SUM(P.Turnover) ELSE NULL END AS Margin
			FROM dbo.OSDataTGRS AS P WITH (NOLOCK)
				INNER JOIN bodb02.dbo.League AS L WITH (NOLOCK) ON P.LeagueId = L.LeagueId
				LEFT JOIN @LeagueGroups AS lg ON L.LeagueGroupId = lg.LeagueGroupId
				LEFT JOIN @BettypeList bl ON p.BettypeId = bl.BettypeId
			WHERE	P.EventDate BETWEEN @FromDate AND @ToDate
				AND P.SportId = 2
				AND (@Bettypes = '0' OR bl.BettypeId IS NOT NULL)
				AND L.LeagueName LIKE '%' + @LeagueName + '%'
				AND (@LiveType = -1 OR P.IsLive = @LiveType)
				AND (@LeagueGroupIds = '' OR lg.LeagueGroupId IS NOT NULL)
			GROUP BY P.BettypeId, P.IsLive;
		END;
				 	
	 SELECT	P.BetType, 
		ISNULL(TN.bettypename,BT.typenamee) AS BettypeName ,
		P.TraderCount, 
		P.LeagueCount,
		P.MatchCount,
		P.Turnover, 
		P.WinLoss, 
		P.BetCount,
		P.Margin,
		P.IsLive 
	 FROM	#tmpOSDataTGRS AS P WITH (NOLOCK)
		LEFT JOIN dbo.OSBetType AS TN WITH (NOLOCK) ON TN.BettypeId = P.BetType
		LEFT JOIN bodb02.dbo.bettype AS BT WITH (NOLOCK) ON BT.typeid = P.BetType
	ORDER BY P.Margin DESC, P.Bettype ASC;

END;

GO
/*<info serverAlias="DBTGRS-bodb_TGRS" executers="bodbTGRSNet" isFunction="0" isNested="0"></info>*/