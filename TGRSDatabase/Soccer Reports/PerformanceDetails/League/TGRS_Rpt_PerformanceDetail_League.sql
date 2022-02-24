ALTER PROCEDURE [dbo].[TGRS_Rpt_PerformanceDetail_League]  	
		@FromDate			DATE
	,	@ToDate				DATE
	,	@LeagueName			NVARCHAR(100)= ''
	,	@LeagueGroupIds		VARCHAR(2000) =  ''
	,	@Turnover			MONEY = NULL
	,	@WinLoss			MONEY = NULL
	,	@MarginFrom			MONEY = NULL
	,	@MarginTo			MONEY = NULL
	,	@TurnoverReal		MONEY = NULL
	,	@WinLossReal		MONEY = NULL
	,	@MarginFromReal		MONEY = NULL
	,	@MarginToReal		MONEY = NULL
	,	@Bettypes			VARCHAR(2000) =  '0'
	,	@IsExcludeLeagues	BIT = 1
	,	@Market				SMALLINT = 1
AS    
/*  
	 Created:	20160216@Long.Luu
	 Task :		Detail report - League Performance
	 DB:		DBTGRS.bodb_TGRS
	 Original:  
 
	 Revisions:      	
 		- 20171019@Simon:		Change VARCHAR(200) to VARCHAR(2000)
		- 20171205@Simon:		get only Live data & Bettypes are not disabled
		- 20180912@Simon:		add league exclusion
		- 20190919@Long.Luu:	Support Nonlive Data [Redmine ID: 118959]
		- 20191023@John.Ngo:	Enhance performance [Redmine ID: 121268]
		- 20200709@John.Ngo:	Performance Detail - Support filter by league group [Redmine ID: 137276]
		- 20210825@Adam.Tran: 	Sports - Performance Real Figures [Redmine: #158981]
		- 20220222@John.Ngo:	Separate League Group for Virtual and SABA PinGoal [Redmine: #161859]

	 Param's Explanation:  
		- @Market: -1 All; 0 Nonlive; 1 Live	

	 Exam: 
	  	EXEC  TGRS_Rpt_PerformanceDetail_League @FromDate = '2014-01-01', @ToDate= '2014-05-30'   
*/  
 
BEGIN 
	SET NOCOUNT ON;

	IF	OBJECT_ID('tempdb..#tmpLeaguePerformance') IS NOT NULL
	BEGIN
		DROP TABLE	#tmpLeaguePerformance;
	END;

	CREATE TABLE #tmpLeaguePerformance (
			LeagueId			INT
		,	LeagueName			NVARCHAR(500)	
		,	LeagueGroupID		SMALLINT
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

	DECLARE @LeagueGroups AS TABLE (LeagueGroupId SMALLINT PRIMARY KEY CLUSTERED, LeagueGroupName VARCHAR(200), TargetLeagueGroupId SMALLINT)
	INSERT INTO @LeagueGroups(LeagueGroupId, LeagueGroupName, TargetLeagueGroupId)
	EXECUTE dbo.[TGRS_LeagueGroupSoccer_Get] @LeagueGroupIds = @LeagueGroupIds;

	DECLARE @BettypeList AS TABLE (bettype SMALLINT);

	IF @Bettypes <> '0'
		INSERT INTO @BettypeList
		SELECT val 
		FROM dbo.strSplit_Key(@Bettypes,',');
	ELSE 
		INSERT INTO @BettypeList
		SELECT Bettype 
		FROM dbo.Bettype WITH (NOLOCK);
	
	IF (@LeagueName IS NULL OR @LeagueName = '')
		BEGIN		
			INSERT INTO #tmpLeaguePerformance (
					LeagueId
				,	LeagueName
				,	LeagueGroupID
				,	IsLive
				,	TraderCount
				,	MatchCount
				,	Turnover
				,	WinLoss	
				, 	Margin
				,	TurnoverReal
				,	WinLossReal
				,	MarginReal
				,	BetCount)
			SELECT 	P.LeagueId
				,	L.LeagueName
				,   CASE WHEN lg.TargetLeagueGroupId = L.LeagueGroupID THEN lg.TargetLeagueGroupId ELSE 12 END AS LeagueGroupID
				,	P.IsLive
				,	ISNULL(COUNT(DISTINCT P.CustId), 0) AS TraderCount
				,	ISNULL(COUNT(DISTINCT P.MatchId), 0) AS MatchCount
				,	ISNULL(SUM(P.Stake), 0) AS Turnover
				,	ISNULL(SUM(P.WinLost), 0) - ISNULL(SUM (P.Comm), 0) AS WinLoss
				,	CASE WHEN ISNULL(SUM(P.Stake), 0) <> 0 THEN (ISNULL(SUM(P.WinLost), 0) - ISNULL(SUM (P.Comm), 0)) * 100/ISNULL(SUM(P.Stake), 0) ELSE NULL END AS Margin
				,	ISNULL(SUM(P.Stake_Real),0) AS TurnoverReal
				,	ISNULL(SUM(CASE WHEN P.Is8RM = 0 THEN P.WinLost_Real ELSE 0 END),0) AS WinLossReal
				,	CASE WHEN ISNULL(SUM(P.Stake_Real),0) <> 0 THEN ISNULL(SUM(CASE WHEN P.Is8RM = 0 THEN P.WinLost_Real ELSE 0 END),0) * 100/ISNULL(SUM(P.Stake_Real),0) ELSE NULL END AS MarginReal
				,	ISNULL(SUM (BetCount), 0) AS BetCount
			FROM dbo.TraderPerformance AS P WITH (NOLOCK)
				INNER JOIN bodb02.dbo.League AS L WITH (NOLOCK) ON P.LeagueId = L.LeagueId
				LEFT JOIN @LeagueGroups AS lg ON L.LeagueGroupId = lg.LeagueGroupId
				LEFT JOIN dbo.LeagueExclusion le WITH(NOLOCK) ON P.LeagueId = le.LeagueId
			WHERE P.EventDate BETWEEN @FromDate AND @ToDate
				AND P.Bettype IN (SELECT Bettype FROM @BettypeList)
				AND (@Market = -1 OR P.IsLive = @Market)
				AND (@IsExcludeLeagues = 0 OR le.LeagueId IS NULL)
				AND (@LeagueGroupIds = '' OR lg.LeagueGroupId IS NOT NULL)
			GROUP BY P.LeagueId 
				, 	L.LeagueName
				,   CASE WHEN lg.TargetLeagueGroupId = L.LeagueGroupID THEN lg.TargetLeagueGroupId ELSE 12 END
				, 	P.IsLive;
		
		END;
	ELSE
		BEGIN			
			INSERT INTO #tmpLeaguePerformance (
					LeagueId
				,	LeagueName
				,	LeagueGroupID
				,	IsLive
				,	TraderCount
				,	MatchCount
				,	Turnover
				,	WinLoss	
				, 	Margin
				,	TurnoverReal
				,	WinLossReal
				,	MarginReal
				,	BetCount)
			SELECT 	P.LeagueId
				,	L.LeagueName
				,   CASE WHEN lg.TargetLeagueGroupId = L.LeagueGroupID THEN lg.TargetLeagueGroupId ELSE 12 END AS LeagueGroupID
				,	P.IsLive
				,	ISNULL(COUNT(DISTINCT P.CustId), 0) AS TraderCount
				,	ISNULL(COUNT(DISTINCT P.MatchId), 0) AS MatchCount
				,	ISNULL(SUM(P.Stake), 0) AS Turnover
				,	ISNULL(SUM(P.WinLost), 0) - ISNULL(SUM (P.Comm), 0) AS WinLoss
				,	CASE WHEN ISNULL(SUM(P.Stake), 0) <> 0 THEN (ISNULL(SUM(P.WinLost), 0) - ISNULL(SUM (P.Comm), 0)) * 100/ISNULL(SUM(P.Stake), 0) ELSE NULL END AS Margin
				,	ISNULL(SUM(P.Stake_Real),0) AS TurnoverReal
				,	ISNULL(SUM(CASE WHEN P.Is8RM = 0 THEN P.WinLost_Real ELSE 0 END),0) AS WinLossReal
				,	CASE WHEN ISNULL(SUM(P.Stake_Real),0) <> 0 THEN ISNULL(SUM(CASE WHEN P.Is8RM = 0 THEN P.WinLost_Real ELSE 0 END),0) * 100/ISNULL(SUM(P.Stake_Real),0) ELSE NULL END AS MarginReal
				,	ISNULL(SUM (BetCount), 0) AS BetCount
			FROM dbo.TraderPerformance AS P WITH (NOLOCK)
				INNER JOIN bodb02.dbo.League AS L WITH (NOLOCK) ON P.LeagueId = L.LeagueId
				LEFT JOIN @LeagueGroups AS lg ON L.LeagueGroupId = lg.LeagueGroupId
				LEFT JOIN dbo.LeagueExclusion le WITH(NOLOCK) ON P.LeagueId = le.LeagueId
			WHERE P.EventDate BETWEEN @FromDate AND @ToDate
				AND P.Bettype IN (SELECT Bettype FROM @BettypeList)
				AND L.LeagueName LIKE '%' + @LeagueName + '%'
				AND (@Market = -1 OR P.IsLive = @Market)
				AND (@IsExcludeLeagues = 0 OR le.LeagueId IS NULL)
				AND (@LeagueGroupIds = '' OR lg.LeagueGroupId IS NOT NULL)
			GROUP BY P.LeagueId
				, 	L.LeagueName
				,   CASE WHEN lg.TargetLeagueGroupId = L.LeagueGroupID THEN lg.TargetLeagueGroupId ELSE 12 END
				, 	P.IsLive;
		END;
		
		SELECT	m.LeagueId
		,	m.LeagueName
		,	m.LeagueGroupID
		,	m.IsLive 
		,	m.TraderCount		
		,	m.MatchCount
		,	m.Turnover
		,	m.WinLoss
		,	m.Margin
		,	m.TurnoverReal
		,	m.WinLossReal
		,	m.MarginReal
		,	m.BetCount
	FROM 	#tmpLeaguePerformance AS m WITH (NOLOCK)	
	WHERE	(@Turnover IS NULL OR m.Turnover >= @Turnover)
		AND (@WinLoss IS NULL  OR m.WinLoss >= @WinLoss)
		AND (@MarginFrom IS NULL  OR m.Margin >= @MarginFrom)
		AND (@MarginTo IS NULL OR m.Margin <= @MarginTo)			
		AND (@TurnoverReal IS NULL OR m.TurnoverReal >= @TurnoverReal)
		AND (@WinLossReal IS NULL  OR m.WinLossReal >= @WinLossReal)
		AND (@MarginFromReal IS NULL  OR m.MarginReal >= @MarginFromReal)
		AND (@MarginToReal IS NULL OR m.MarginReal <= @MarginToReal)					
	ORDER BY m.Margin, m.LeagueName ASC;
		
	DROP TABLE #tmpLeaguePerformance;
END;

GO

/*<info serverAlias="DBTGRS-bodb_TGRS" executers="bodbTGRSNet" isFunction="0" isNested="0"></info>*/