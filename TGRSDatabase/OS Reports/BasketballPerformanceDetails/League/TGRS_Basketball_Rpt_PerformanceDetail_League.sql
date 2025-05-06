ALTER PROCEDURE [dbo].[TGRS_Basketball_Rpt_PerformanceDetail_League]
		@FromDate			DATE
	,	@ToDate				DATE
	,	@LeagueName			NVARCHAR(500)= ''
	,	@LeagueGroupIds		VARCHAR(2000) = ''
	,	@Bettypes			VARCHAR(2000) = '0'
	,	@LiveType			SMALLINT = -1
AS    
/*  
	Task :		Basketball Performance Detail - League
	DB:			DBTGRS.bodb_TGRS
	Original:  
  
	Revisions: 	
   		- 20250414@Jaden: Basketball Performance Detail - League dimension
   		- 20250414@Jaden: Added real metrics (using actual rate)
   		- 20250414@Jaden: Changed from dbo.OSBetType to bodb02.dbo.bettype

	Param's Explanation:  	
		- @LiveType: -1 All; 0 Nonlive; 1 Live

	Exam: EXEC [TGRS_Basketball_Rpt_PerformanceDetail_League] @FromDate = '2024-01-01', @ToDate= '2024-12-30' 
  
*/  
  
BEGIN 
	SET NOCOUNT ON;
	
	DECLARE @LeagueGroups AS TABLE (LeagueGroupId SMALLINT PRIMARY KEY CLUSTERED, LeagueGroupName NVARCHAR(200))
	IF @LeagueGroupIds <> ''
		BEGIN
			INSERT INTO @LeagueGroups(LeagueGroupId)
			SELECT value
			FROM STRING_SPLIT(@LeagueGroupIds, ',');
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
			SELECT value
			FROM STRING_SPLIT(@Bettypes, ',');
		END;
	ELSE
		BEGIN
			INSERT INTO @BettypeList
			SELECT b.typeid
			FROM bodb02.dbo.bettype b WITH(NOLOCK)
			WHERE b.typeid IN (SELECT bettype FROM bodb02.dbo.SportBettypeMatrix WITH (NOLOCK) WHERE SportType = 2);
		END;

	IF	OBJECT_ID('tempdb..#tmpOSDataTGRS') IS NOT NULL
	BEGIN
		DROP TABLE	#tmpOSDataTGRS;
	END;

	CREATE TABLE #tmpOSDataTGRS (
			LeagueId			INT
		,	LeagueName			NVARCHAR(200)
		,	LeagueGroupId		SMALLINT
		,	LeagueGroupName		NVARCHAR(200)
		,	TraderCount			INT
		,	NoOfBetTypes		INT
		,	MatchCount			INT
		,	Turnover			MONEY
		,	WinLoss				MONEY
		,	BetCount			INT
		,	Margin				MONEY
		,	Turnover_AR			MONEY
		,	WinLoss_AR			MONEY
		,	Margin_AR			MONEY
		,	IsLive				BIT
	);
	
	CREATE CLUSTERED INDEX #CIX_tmpOSDataTGRSIdx ON #tmpOSDataTGRS (
			LeagueId			ASC
	); 

	IF (@LeagueName IS NULL OR @LeagueName = '')
		BEGIN
			INSERT INTO #tmpOSDataTGRS (
					LeagueId
				,	LeagueName
				,	LeagueGroupId
				,	LeagueGroupName
				,	TraderCount
				,	NoOfBetTypes
				,	MatchCount
				,	Turnover
				,	WinLoss
				,	BetCount
				,	Margin
				,	Turnover_AR
				,	WinLoss_AR
				,	Margin_AR
				,	IsLive	)
			SELECT 
				P.LeagueId, 
				L.LeagueName,
				L.LeagueGroupId,
				LG.GroupName AS LeagueGroupName,	
				ISNULL(COUNT(DISTINCT P.TraderId), 0) AS TraderCount,
				ISNULL(COUNT(DISTINCT P.BettypeId), 0) AS NoOfBetTypes,
				ISNULL(COUNT(DISTINCT P.MatchId), 0) AS MatchCount, 
				ISNULL(SUM(P.Turnover), 0) AS Turnover, 
				ISNULL(SUM(P.Winloss), 0) - ISNULL(SUM(P.Comm), 0) AS WinLoss, 
				ISNULL(SUM(P.BetCount), 0) AS BetCount,
				CASE WHEN ISNULL(SUM(P.Turnover), 0) <> 0 THEN (ISNULL(SUM(P.Winloss), 0) - ISNULL(SUM(P.Comm), 0)) * 100/SUM(P.Turnover) ELSE NULL END AS Margin,
				ISNULL(SUM(P.Turnover_AR), 0) AS Turnover_AR,
				ISNULL(SUM(P.Winloss_AR), 0) - ISNULL(SUM(P.Comm_AR), 0) AS WinLoss_AR, 
				CASE WHEN ISNULL(SUM(P.Turnover_AR), 0) <> 0 THEN (ISNULL(SUM(P.Winloss_AR), 0) - ISNULL(SUM(P.Comm_AR), 0)) * 100/SUM(P.Turnover_AR) ELSE NULL END AS Margin_AR,
				P.IsLive
			FROM dbo.OSDataTGRS AS P WITH (NOLOCK)
				INNER JOIN bodb02.dbo.League AS L WITH (NOLOCK) ON P.LeagueId = L.LeagueId
				INNER JOIN bodb02.dbo.LeagueGroup AS LG WITH (NOLOCK) ON L.LeagueGroupId = LG.GroupID
				LEFT JOIN @LeagueGroups AS lg_filter ON L.LeagueGroupId = lg_filter.LeagueGroupId
				LEFT JOIN @BettypeList bl ON p.BettypeId = bl.BettypeId
			WHERE	P.EventDate BETWEEN @FromDate AND @ToDate
				AND P.SportId = 2
				AND (@Bettypes = '0' OR bl.BettypeId IS NOT NULL)
				AND (@LiveType = -1 OR P.IsLive = @LiveType)
				AND (@LeagueGroupIds = '' OR lg_filter.LeagueGroupId IS NOT NULL)
			GROUP BY P.LeagueId, L.LeagueName, L.LeagueGroupId, LG.GroupName, P.IsLive;
		END;
	ELSE
		BEGIN
			INSERT INTO #tmpOSDataTGRS (
					LeagueId
				,	LeagueName
				,	LeagueGroupId
				,	LeagueGroupName
				,	TraderCount
				,	NoOfBetTypes
				,	MatchCount
				,	Turnover
				,	WinLoss
				,	BetCount
				,	Margin
				,	Turnover_AR
				,	WinLoss_AR
				,	Margin_AR
				,	IsLive	)
			SELECT 
				P.LeagueId, 
				L.LeagueName,
				L.LeagueGroupId,
				LG.GroupName AS LeagueGroupName,
				ISNULL(COUNT(DISTINCT P.TraderId), 0) AS TraderCount,
				ISNULL(COUNT(DISTINCT P.BettypeId), 0) AS NoOfBetTypes,
				ISNULL(COUNT(DISTINCT P.MatchId), 0) AS MatchCount, 
				ISNULL(SUM(P.Turnover), 0) AS Turnover, 
				ISNULL(SUM(P.Winloss), 0) - ISNULL(SUM(P.Comm), 0) AS WinLoss, 
				ISNULL(SUM(P.BetCount), 0) AS BetCount,
				CASE WHEN ISNULL(SUM(P.Turnover), 0) <> 0 THEN (ISNULL(SUM(P.Winloss), 0) - ISNULL(SUM(P.Comm), 0)) * 100/SUM(P.Turnover) ELSE NULL END AS Margin,
				ISNULL(SUM(P.Turnover_AR), 0) AS Turnover_AR,
				ISNULL(SUM(P.Winloss_AR), 0) - ISNULL(SUM(P.Comm_AR), 0) AS WinLoss_AR, 
				CASE WHEN ISNULL(SUM(P.Turnover_AR), 0) <> 0 THEN (ISNULL(SUM(P.Winloss_AR), 0) - ISNULL(SUM(P.Comm_AR), 0)) * 100/SUM(P.Turnover_AR) ELSE NULL END AS Margin_AR,
				P.IsLive
			FROM dbo.OSDataTGRS AS P WITH (NOLOCK)
				INNER JOIN bodb02.dbo.League AS L WITH (NOLOCK) ON P.LeagueId = L.LeagueId
				INNER JOIN bodb02.dbo.LeagueGroup AS LG WITH (NOLOCK) ON L.LeagueGroupId = LG.GroupID
				LEFT JOIN @LeagueGroups AS lg_filter ON L.LeagueGroupId = lg_filter.LeagueGroupId
				LEFT JOIN @BettypeList bl ON p.BettypeId = bl.BettypeId
			WHERE	P.EventDate BETWEEN @FromDate AND @ToDate
				AND P.SportId = 2
				AND (@Bettypes = '0' OR bl.BettypeId IS NOT NULL)
				AND L.LeagueName LIKE '%' + @LeagueName + '%'
				AND (@LiveType = -1 OR P.IsLive = @LiveType)
				AND (@LeagueGroupIds = '' OR lg_filter.LeagueGroupId IS NOT NULL)
			GROUP BY P.LeagueId, L.LeagueName, L.LeagueGroupId, LG.GroupName, P.IsLive;
		END;
				 	
	SELECT
		P.LeagueId,
		P.LeagueName,
		P.LeagueGroupId,
		P.LeagueGroupName,
		P.TraderCount, 
		P.NoOfBetTypes,
		P.MatchCount,
		P.Turnover, 
		P.WinLoss, 
		P.BetCount,
		P.Margin,
		P.Turnover_AR,
		P.WinLoss_AR,
		P.Margin_AR,
		P.IsLive 
	FROM #tmpOSDataTGRS AS P WITH (NOLOCK)
	ORDER BY P.Margin DESC, P.LeagueName ASC;

END;

GO
/*<info serverAlias="DBTGRS-bodb_TGRS" executers="wsv_tgrs" isFunction="0" isNested="0"></info>*/