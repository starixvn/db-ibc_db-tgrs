ALTER PROCEDURE [dbo].[TGRS_Rpt_PerformanceDetail_Team]  
		@FromDate			DATE
	,	@ToDate				DATE
	,	@LeagueGroupIds		VARCHAR(2000) = ''
	,	@TeamIds			VARCHAR(200) =  '0'
	,	@Bettypes			VARCHAR(2000) =  '0'
	,	@IsExcludeLeagues	BIT = 1
	,	@Market				SMALLINT = 1
	,   @VRSettings         VARCHAR(100) = 'ALL' -- Comma-separated: "VR_PLUS", "NO_VR", "VR_MINUS", "ALL"
	,   @MatchGroup         VARCHAR(100) = 'ALL' -- Comma-separated: "NORMAL", "EXTRA_TIME", "PENALTY", "HEDGE", "ALL"
AS    
/*  
	Created:	20160218@Billy
	Task :		Performance Detail Report - Team
	DB:			DBTGRS.bodb_TGRS
	Original:  
	 
	Revisions:
		- 20160301@Billy:		US011 - Modify Trader's Score - [Redmine: #53084]
		- 20160315@Thai:		US018 - Modify Trader's Score - [Redmine: #53987]
		- 20171019@Simon:		Change VARCHAR(200) to VARCHAR(2000)
		- 20171205@Simon:		get only Live data & Bettypes are not disabled
		- 20180912@Simon:		add league exclusion
		- 20190919@Long.Luu:	Support Nonlive Data [Redmine ID: 118959]
		- 20191023@John.Ngo:	Enhance performance [Redmine ID: 121268]
		- 20200713@John.Ngo:	Performance Detail - Support filter by league group [Redmine ID: 137276]
		- 20210827@Adam.Tran: 	Sports - Performance Real Figures [Redmine: #158981]
		- 20220222@John.Ngo:	Separate League Group for Virtual and SABA PinGoal [Redmine: #161859]
		- 20250524@Jaden.Tang:	Support new filter VR Settings and Match Group [Redmine: #227903]

	Param's Explanation:  
		- @Market: -1 All; 0 Nonlive; 1 Live	
	
	Example: 	
		EXECUTE	TGRS_Rpt_PerformanceDetail_Team @FromDate = '2016-02-22', @ToDate = '2016-03-14', @Bettypes = '1,3,5', @TeamIds = '0'
*/  
 
BEGIN 
	 
	SET NOCOUNT ON;  

	IF @VRSettings IS NULL OR @VRSettings = 'ALL'
	BEGIN
		SET @VRSettings = NULL
	END

    CREATE TABLE #TempVRSettings (Setting VARCHAR(20) PRIMARY KEY);
    IF @VRSettings IS NOT NULL
    BEGIN
        INSERT INTO #TempVRSettings (Setting)
        SELECT DISTINCT UPPER(value) FROM STRING_SPLIT(@VRSettings, ',');
    END

	IF @MatchGroup IS NULL OR @MatchGroup = 'ALL'
	BEGIN
		SET @MatchGroup = NULL
	END
    
    CREATE TABLE #TempMatchGroup (Setting VARCHAR(20) PRIMARY KEY);
    IF @MatchGroup IS NOT NULL AND @MatchGroup <> ''
    BEGIN
        INSERT INTO #TempMatchGroup (Setting)
        SELECT DISTINCT UPPER(value) FROM STRING_SPLIT(@MatchGroup, ',');
    END
    
    DECLARE @ApplyVRFilter BIT = 1;
    IF NOT EXISTS (SELECT 1 FROM #TempVRSettings) SET @ApplyVRFilter = 0;
    
    DECLARE @ApplyMatchGroupFilter BIT = 1;
    IF NOT EXISTS (SELECT 1 FROM #TempMatchGroup) SET @ApplyMatchGroupFilter = 0;

    CREATE TABLE #AllMatches (
        matchid INT,
        parentid INT NULL,
        IsPenaltyMatch BIT,
        IsExtraTimeMatch BIT,
        IsHedgeMatch BIT,
        PRIMARY KEY (matchid)
    );
    
    DECLARE @TeamListForMatchFilter TABLE (TeamId SMALLINT);
	IF	@TeamIds <> '0'
		 INSERT INTO @TeamListForMatchFilter (TeamId) SELECT val FROM dbo.strSplit_Key(@TeamIds, ',');
	ELSE 
		 INSERT INTO @TeamListForMatchFilter (TeamId) SELECT t.TeamId FROM dbo.Team AS t WITH (NOLOCK);

    INSERT INTO #AllMatches (matchid, parentid, IsPenaltyMatch, IsExtraTimeMatch, IsHedgeMatch)
    SELECT 
        M.matchid, M.parentid,
        CASE 
            WHEN HT.teamname LIKE N'%(PEN)%' THEN 1
            ELSE 0 
        END AS IsPenaltyMatch,
        CASE 
            WHEN HT.teamname LIKE N'%(ET)%' THEN 1
            ELSE 0 
        END AS IsExtraTimeMatch,
        CASE 
            WHEN M.MatchCode LIKE N'%hedge%' THEN 1
            ELSE 0 
        END AS IsHedgeMatch
    FROM bodb02.dbo.Match M WITH (NOLOCK)
    LEFT JOIN bodb02.dbo.Team HT WITH (NOLOCK) ON M.homeid = HT.teamid AND HT.SportType = M.sporttype
    WHERE M.eventdate BETWEEN @FromDate AND @ToDate
      AND M.sporttype = 1
    OPTION (RECOMPILE);

    INSERT INTO #AllMatches (matchid, parentid, IsPenaltyMatch, IsExtraTimeMatch, IsHedgeMatch)
    SELECT 
        M14.matchid, M14.parentid,
        CASE 
            WHEN HT.teamname LIKE N'%(PEN)%' THEN 1
            ELSE 0 
        END AS IsPenaltyMatch,
        CASE 
            WHEN HT.teamname LIKE N'%(ET)%' THEN 1
            ELSE 0 
        END AS IsExtraTimeMatch,
        CASE 
            WHEN M14.MatchCode LIKE N'%hedge%' THEN 1
            ELSE 0 
        END AS IsHedgeMatch
    FROM bodb02.dbo.Match14 M14 WITH (NOLOCK)
    LEFT JOIN bodb02.dbo.Team HT WITH (NOLOCK) ON M14.homeid = HT.teamid AND HT.SportType = M14.sporttype
    WHERE M14.eventdate BETWEEN @FromDate AND @ToDate
      AND NOT EXISTS (SELECT 1 FROM #AllMatches am WHERE am.matchid = M14.matchid)
      AND M14.sporttype = 1
    OPTION (RECOMPILE);

    INSERT INTO #AllMatches (matchid, parentid, IsPenaltyMatch, IsExtraTimeMatch, IsHedgeMatch)
    SELECT 
        MBK.matchid, MBK.parentid,
        CASE 
            WHEN HT.teamname LIKE N'%(PEN)%' THEN 1
            ELSE 0 
        END AS IsPenaltyMatch,
        CASE 
            WHEN HT.teamname LIKE N'%(ET)%' THEN 1
            ELSE 0 
        END AS IsExtraTimeMatch,
        CASE 
            WHEN MBK.MatchCode LIKE N'%hedge%' THEN 1
            ELSE 0 
        END AS IsHedgeMatch
    FROM bodb_archive.dbo.Match_bk MBK WITH (NOLOCK)
    LEFT JOIN bodb02.dbo.Team HT WITH (NOLOCK) ON MBK.homeid = HT.teamid AND HT.SportType = MBK.sporttype
    WHERE MBK.eventdate BETWEEN @FromDate AND @ToDate
      AND NOT EXISTS (SELECT 1 FROM #AllMatches am WHERE am.matchid = MBK.matchid)
      AND MBK.sporttype = 1
    OPTION (RECOMPILE);

    CREATE TABLE #RootMatches (
        ChildMatchID INT PRIMARY KEY,
        RootMatchID INT
    );

    WITH MatchHierarchy_CTE AS (
        SELECT 
            am.matchid AS ChildMatchID,
            am.matchid AS RootMatchID,
            am.parentid,
            0 AS Level
        FROM #AllMatches am
        WHERE am.parentid IS NULL OR NOT EXISTS (SELECT 1 FROM #AllMatches p_am WHERE p_am.matchid = am.parentid)

        UNION ALL

        SELECT 
            am_child.matchid AS ChildMatchID,
            mh.RootMatchID,
            am_child.parentid,
            mh.Level + 1
        FROM #AllMatches am_child
        INNER JOIN MatchHierarchy_CTE mh ON am_child.parentid = mh.ChildMatchID
        WHERE am_child.matchid <> mh.RootMatchID
    )
    INSERT INTO #RootMatches (ChildMatchID, RootMatchID)
    SELECT ChildMatchID, RootMatchID 
    FROM MatchHierarchy_CTE
    OPTION (RECOMPILE);

	DECLARE @LeagueGroups AS TABLE (LeagueGroupId SMALLINT PRIMARY KEY CLUSTERED, LeagueGroupName VARCHAR(200), TargetLeagueGroupId SMALLINT)
	INSERT INTO @LeagueGroups(LeagueGroupId, LeagueGroupName, TargetLeagueGroupId)
	EXECUTE dbo.[TGRS_LeagueGroupSoccer_Get] @LeagueGroupIds = @LeagueGroupIds;
	
	CREATE TABLE #ScoreDetail (
			CustID			INT
		,	IsLive			BIT
		,	WinLoss			MONEY
		,	SumCategory		MONEY
	);

	DECLARE	@BettypeList TABLE (
			BetType			SMALLINT
	);
	DECLARE	@TeamList TABLE (
			TeamId			SMALLINT
	);
	DECLARE	@Team TABLE (
			TeamId			SMALLINT
		,	TeamName		NVARCHAR(50)
		,	TraderCount		INT
		,	LeagueCount		INT
		,	MatchCount		INT
		,	Turnover		MONEY
		,	WinLoss			MONEY		
		,	Margin			MONEY
		,	TurnoverReal	MONEY
		,	WinLossReal		MONEY		
		,	MarginReal		MONEY
		,	BetCount		INT
		,	Score			MONEY
		,	IsLive			BIT
	);

	IF	@Bettypes <> '0'
		 INSERT INTO @BettypeList
		 	(	bettype)
		 SELECT ssk.val
		 FROM	dbo.strSplit_Key(@Bettypes, ',') ssk;
	ELSE 
		 INSERT INTO @BettypeList
		 	(	bettype)
		 SELECT bt.BetType 
		 FROM	dbo.BetType AS bt WITH (NOLOCK);

	IF	@TeamIds <> '0'
		 INSERT INTO @TeamList
		 	(	TeamId)
		 SELECT ssk.val
		 FROM	dbo.strSplit_Key(@TeamIds, ',') ssk;
	ELSE 
		 INSERT INTO @TeamList
		 	(	TeamId)
		 SELECT	t.TeamId
		 FROM	dbo.Team AS t WITH (NOLOCK);

	INSERT INTO	#ScoreDetail (
			CustID
		,	IsLive
		,	WinLoss
		,	SumCategory
	)
	SELECT	tp.CustId
		,	tp.IsLive
		,	ISNULL(SUM(tp.WinLost), 0) - ISNULL(SUM(tp.Comm), 0)	AS WinLoss				
		,	ISNULL(SUM(tp.Stake * ISNULL(s.BenchMark, tp.Spread * tm.Rate)), 0) AS SumCategory
	FROM	dbo.TraderPerformance AS tp WITH (NOLOCK)
		INNER JOIN bodb02.dbo.League AS L WITH (NOLOCK) ON tp.LeagueId = L.LeagueId
		INNER JOIN	dbo.TargetedMargin AS tm WITH (NOLOCK) ON tm.BetType = tp.BetType AND tm.WorkShift = tp.WorkShift
		LEFT JOIN @LeagueGroups AS lg ON L.LeagueGroupId = lg.LeagueGroupId
		LEFT JOIN dbo.Benchmark_SpecialSetting AS s WITH (NOLOCK) ON s.Spread = tp.Spread AND s.Rate = tm.Rate
		LEFT JOIN dbo.LeagueExclusion le WITH(NOLOCK) ON tp.LeagueId = le.LeagueId
	WHERE	tp.EventDate BETWEEN @FromDate AND @ToDate
		AND	tp.BetType IN (SELECT bl.bettype FROM @BettypeList AS bl)
		AND (@Market = -1 OR tp.IsLive = @Market)
		AND (@IsExcludeLeagues = 0 OR le.LeagueId IS NULL)
		AND (@LeagueGroupIds = '' OR lg.LeagueGroupId IS NOT NULL)
	GROUP BY tp.CustId, tp.IsLive;

	WITH TeamDetail AS (
		SELECT	t.TeamId
			,	tp.IsLive
			,	COUNT(DISTINCT tp.CustId)								AS TraderCount
			,	COUNT(DISTINCT tp.LeagueId)								AS LeagueCount
			,	COUNT(DISTINCT RM.RootMatchID)								AS MatchCount
			,	ISNULL(SUM(tp.Stake), 0)								AS Turnover
			,	ISNULL(SUM(tp.WinLost), 0) - ISNULL(SUM(tp.Comm), 0)	AS WinLoss			
			,	CASE WHEN ISNULL(SUM(tp.Stake), 0) = 0 THEN NULL ELSE (ISNULL(SUM(tp.WinLost), 0) - ISNULL(SUM(tp.Comm), 0)) * 100 / ISNULL(SUM(tp.Stake), 0)   END														 AS Margin
			,	ISNULL(SUM(tp.Stake_Real),0) 							AS TurnoverReal
			,	ISNULL(SUM(CASE WHEN tp.Is8RM = 0 THEN tp.WinLost_Real ELSE 0 END),0) 	AS WinLossReal
			,	CASE WHEN ISNULL(SUM(tp.Stake_Real),0) <> 0 THEN ISNULL(SUM(CASE WHEN tp.Is8RM = 0 THEN tp.WinLost_Real ELSE 0 END),0) * 100/ISNULL(SUM(tp.Stake_Real),0) ELSE NULL END 							   AS MarginReal
			,	ISNULL(SUM(tp.BetCount), 0)								AS BetCount
		FROM	dbo.TraderPerformance AS tp WITH (NOLOCK)
			INNER JOIN bodb02.dbo.League AS L WITH (NOLOCK) ON tp.LeagueId = L.LeagueId
			INNER JOIN	dbo.Trader AS t WITH (NOLOCK) ON	t.CustId = tp.CustId
			LEFT JOIN @LeagueGroups AS lg ON L.LeagueGroupId = lg.LeagueGroupId
			LEFT JOIN dbo.LeagueExclusion le WITH(NOLOCK) ON tp.LeagueId = le.LeagueId
			INNER JOIN #AllMatches AM ON tp.MatchId = AM.matchid
			LEFT JOIN #RootMatches RM ON tp.MatchId = RM.ChildMatchID
		WHERE	tp.EventDate BETWEEN @FromDate AND @ToDate
			AND	tp.BetType IN (SELECT bl.bettype FROM @BettypeList AS bl)
			AND	t.TeamId IN (SELECT tl.TeamId FROM @TeamList AS tl)
			AND (@Market = -1 OR tp.IsLive = @Market)
			AND (@IsExcludeLeagues = 0 OR le.LeagueId IS NULL)
			AND (@LeagueGroupIds = '' OR lg.LeagueGroupId IS NOT NULL)
			AND (
				@ApplyVRFilter = 0 OR
				EXISTS (
					SELECT 1 FROM #TempVRSettings vrs
					WHERE (vrs.Setting = 'VR_PLUS' AND tp.VarianceVR > 0)
					   OR (vrs.Setting = 'NO_VR' AND (tp.VarianceVR IS NULL OR tp.VarianceVR = 0))
					   OR (vrs.Setting = 'VR_MINUS' AND tp.VarianceVR < 0)
				)
			)
			AND (
				@ApplyMatchGroupFilter = 0 OR
				EXISTS (
					SELECT 1 FROM #TempMatchGroup mgf
					WHERE (mgf.Setting = 'NORMAL' AND am.IsPenaltyMatch = 0 AND am.IsExtraTimeMatch = 0 AND am.IsHedgeMatch = 0)
					   OR (mgf.Setting = 'PENALTY' AND AM.IsPenaltyMatch = 1)
					   OR (mgf.Setting = 'EXTRA_TIME' AND AM.IsExtraTimeMatch = 1)
					   OR (mgf.Setting = 'HEDGE' AND AM.IsHedgeMatch = 1)
				)
			)
		GROUP BY t.TeamId, tp.IsLive
	)
	INSERT INTO @Team (TeamId
		, 	TeamName
		, 	TraderCount
		, 	LeagueCount
		, 	MatchCount
		, 	Turnover
		, 	WinLoss		
		, 	Margin
		, 	TurnoverReal
		, 	WinLossReal
		, 	MarginReal
		, 	BetCount
		, 	IsLive)
	SELECT	td.TeamId
		, 	t.TeamName
		, 	td.TraderCount
		, 	td.LeagueCount
		, 	td.MatchCount
		, 	td.Turnover
		, 	td.WinLoss
		, 	td.Margin
		, 	td.TurnoverReal
		, 	td.WinLossReal
		, 	td.MarginReal
		, 	td.BetCount
		, 	td.IsLive
	FROM	TeamDetail td
		INNER JOIN	dbo.Team AS t WITH (NOLOCK) ON t.TeamId = td.TeamId;

	WITH score AS (
		SELECT	t.TeamId
			,	sd.IsLive
			,	AVG(CASE WHEN sd.SumCategory = 0 THEN NULL ELSE sd.WinLoss * 100 / sd.SumCategory END) AS Score
		FROM	#ScoreDetail AS sd WITH (NOLOCK)
		INNER JOIN	dbo.Trader AS t WITH (NOLOCK) ON t.CustId = sd.CustID
		GROUP BY t.TeamId, sd.IsLive
	)
	UPDATE  t
	SET		t.Score = s.Score
	FROM		@Team AS t
	INNER JOIN	Score AS s
			ON	s.TeamId = t.TeamId AND t.IsLive = s.IsLive;

	SELECT	t.TeamId
		,	t.TeamName
		,	t.TraderCount
		,	t.LeagueCount
		,	t.MatchCount
		,	t.Turnover
		,	t.WinLoss		
		,	t.Margin
		,	t.TurnoverReal
		,	t.WinLossReal		
		,	t.MarginReal
		,	t.BetCount
		,	t.Score 
		,	t.IsLive
	FROM	@Team AS t
	ORDER BY	Margin DESC 
			,	TeamName ASC;
	
	DROP TABLE #ScoreDetail;
    DROP TABLE IF EXISTS #AllMatches;
    DROP TABLE IF EXISTS #RootMatches;
    DROP TABLE IF EXISTS #TempVRSettings;
    DROP TABLE IF EXISTS #TempMatchGroup;
END;

GO

/*<info serverAlias="DBTGRS-bodb_TGRS" executers="wsv_tgrs" isFunction="0" isNested="0"></info>*/
