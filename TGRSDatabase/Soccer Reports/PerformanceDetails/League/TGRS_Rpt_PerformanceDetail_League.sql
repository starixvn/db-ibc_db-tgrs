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
	,   @VRSettings         VARCHAR(100) = 'ALL' -- Comma-separated: "VR_PLUS", "NO_VR", "VR_MINUS", "ALL"
	,   @MatchGroup         VARCHAR(100) = 'ALL' -- Comma-separated: "NORMAL", "EXTRA_TIME", "PENALTY", "HEDGE", "ALL"
	,	@Sites				NVARCHAR(MAX) = ''
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
		- 20220307@John.Ngo: 	Update Separate League Group for Virtual [Redmine: #161859]
		- 20250312@AI.Assistant:  Return League Group name instead of League Group ID [Redmine: #213765]
		- 20250524@Jaden.Tang:	Support new filter VR Settings, Match Group and remove MONEY params [Redmine: #227903]
		- 20250707@Jaden.Tang:	Add Site (company) filter [Redmine: #235099]

	 Param's Explanation:  
		- @Market: -1 All; 0 Nonlive; 1 Live	

	 Exam: 
	  	EXEC  TGRS_Rpt_PerformanceDetail_League @FromDate = '2014-01-01', @ToDate= '2014-05-30'   
*/  
 
BEGIN 
	SET NOCOUNT ON;
	
	DECLARE @OtherGroupsId SMALLINT = 12;

	IF	OBJECT_ID('tempdb..#tmpLeaguePerformance') IS NOT NULL
	BEGIN
		DROP TABLE	#tmpLeaguePerformance;
	END;

	CREATE TABLE #tmpLeaguePerformance (
			LeagueId			INT
		,	LeagueName			NVARCHAR(500)	
		,	LeagueGroupID		SMALLINT
		,	LeagueGroupName		NVARCHAR(500)
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

	DECLARE @SitesList AS TABLE (SiteId INT PRIMARY KEY CLUSTERED);
	IF @Sites <> ''
	BEGIN
		INSERT INTO @SitesList
		SELECT SiteId 
		FROM bodb02.dbo.site WITH (NOLOCK)
		WHERE [site] IN (SELECT DISTINCT [value] FROM string_split(@Sites,','));
	END;

    -- It seems like web is calling TGRS_LeagueGroupSoccer_Get to pass TargetLeagueGroupIds to SP, 
    -- NOT the actual group ids, then SP must call TGRS_LeagueGroupSoccer_Get again to get original LeagueGroupIDs back
    CREATE TABLE #TempLeagueGroupIDs (ID SMALLINT PRIMARY KEY, LeagueGroupName NVARCHAR(255), TargetLeagueGroupId INT);
    INSERT INTO #TempLeagueGroupIDs (ID, LeagueGroupName, TargetLeagueGroupId)
    EXEC TGRS_LeagueGroupSoccer_Get @LeagueGroupIds;

	DECLARE @BettypeList AS TABLE (bettype SMALLINT);

	IF @Bettypes <> '0'
		INSERT INTO @BettypeList
		SELECT val 
		FROM dbo.strSplit_Key(@Bettypes,',');
	ELSE 
		INSERT INTO @BettypeList
		SELECT Bettype 
		FROM dbo.Bettype WITH (NOLOCK);
	
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
    WHERE M.eventdate BETWEEN CAST(@FromDate AS DATETIME) AND CAST(@ToDate AS DATETIME)
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
    WHERE M14.eventdate BETWEEN CAST(@FromDate AS DATETIME) AND CAST(@ToDate AS DATETIME)
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
    WHERE MBK.eventdate BETWEEN CAST(@FromDate AS DATETIME) AND CAST(@ToDate AS DATETIME)
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
	
	IF (@LeagueName IS NULL OR @LeagueName = '')
		BEGIN		
			INSERT INTO #tmpLeaguePerformance (
					LeagueId
				,	LeagueName
				,	LeagueGroupID
				,	LeagueGroupName
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
				,   lg.TargetLeagueGroupID
				,   lg.LeagueGroupName
				,	P.IsLive
				,	ISNULL(COUNT(DISTINCT P.CustId), 0) AS TraderCount
				,	ISNULL(COUNT(DISTINCT P.MatchID), 0) AS MatchCount
				,	ISNULL(SUM(P.Stake), 0) AS Turnover
				,	ISNULL(SUM(P.WinLost), 0) - ISNULL(SUM (P.Comm), 0) AS WinLoss
				,	CASE WHEN ISNULL(SUM(P.Stake), 0) <> 0 THEN (ISNULL(SUM(P.WinLost), 0) - ISNULL(SUM (P.Comm), 0)) * 100/ISNULL(SUM(P.Stake), 0) ELSE NULL END AS Margin
				,	ISNULL(SUM(P.Stake_Real),0) AS TurnoverReal
				,	ISNULL(SUM(CASE WHEN P.Is8RM = 0 THEN P.WinLost_Real ELSE 0 END),0) AS WinLossReal
				,	CASE WHEN ISNULL(SUM(P.Stake_Real),0) <> 0 THEN ISNULL(SUM(CASE WHEN P.Is8RM = 0 THEN P.WinLost_Real ELSE 0 END),0) * 100/ISNULL(SUM(P.Stake_Real),0) ELSE NULL END AS MarginReal
				,	ISNULL(SUM (BetCount), 0) AS BetCount
			FROM dbo.TraderPerformance AS P WITH (NOLOCK)
				INNER JOIN bodb02.dbo.League AS L WITH (NOLOCK) ON P.LeagueId = L.LeagueId
				LEFT JOIN #TempLeagueGroupIDs AS lg ON L.LeagueGroupId = lg.ID
				LEFT JOIN dbo.LeagueExclusion le WITH(NOLOCK) ON P.LeagueId = le.LeagueId
				INNER JOIN #AllMatches AM ON P.MatchId = AM.matchid
				LEFT JOIN #RootMatches RM ON P.MatchId = RM.ChildMatchID
			WHERE P.EventDate BETWEEN @FromDate AND @ToDate
				AND P.Bettype IN (SELECT Bettype FROM @BettypeList)
				AND (@Market = -1 OR P.IsLive = @Market)
				AND (@IsExcludeLeagues = 0 OR le.LeagueId IS NULL)
				AND (@LeagueGroupIds = '' OR lg.ID IS NOT NULL)
				AND (
					@ApplyVRFilter = 0 OR
					EXISTS (
						SELECT 1 FROM #TempVRSettings vrs
						WHERE (vrs.Setting = 'VR_PLUS' AND P.VarianceVR > 0)
						   OR (vrs.Setting = 'NO_VR' AND (P.VarianceVR IS NULL OR P.VarianceVR = 0))
						   OR (vrs.Setting = 'VR_MINUS' AND P.VarianceVR < 0)
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
				AND EXISTS (SELECT 1 FROM @SitesList sl WHERE sl.SiteId = P.SiteId)
			GROUP BY P.LeagueId 
				, 	L.LeagueName
				,   lg.TargetLeagueGroupID
				,   lg.LeagueGroupName
				, 	P.IsLive;
		
		END;
	ELSE
		BEGIN			
			INSERT INTO #tmpLeaguePerformance (
					LeagueId
				,	LeagueName
				,	LeagueGroupID
				,	LeagueGroupName
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
				,   lg.TargetLeagueGroupID
				,   lg.LeagueGroupName
				,	P.IsLive
				,	ISNULL(COUNT(DISTINCT P.CustId), 0) AS TraderCount
				,	ISNULL(COUNT(DISTINCT P.MatchID), 0) AS MatchCount
				,	ISNULL(SUM(P.Stake), 0) AS Turnover
				,	ISNULL(SUM(P.WinLost), 0) - ISNULL(SUM (P.Comm), 0) AS WinLoss
				,	CASE WHEN ISNULL(SUM(P.Stake), 0) <> 0 THEN (ISNULL(SUM(P.WinLost), 0) - ISNULL(SUM (P.Comm), 0)) * 100/ISNULL(SUM(P.Stake), 0) ELSE NULL END AS Margin
				,	ISNULL(SUM(P.Stake_Real),0) AS TurnoverReal
				,	ISNULL(SUM(CASE WHEN P.Is8RM = 0 THEN P.WinLost_Real ELSE 0 END),0) AS WinLossReal
				,	CASE WHEN ISNULL(SUM(P.Stake_Real),0) <> 0 THEN ISNULL(SUM(CASE WHEN P.Is8RM = 0 THEN P.WinLost_Real ELSE 0 END),0) * 100/ISNULL(SUM(P.Stake_Real),0) ELSE NULL END AS MarginReal
				,	ISNULL(SUM (BetCount), 0) AS BetCount
			FROM dbo.TraderPerformance AS P WITH (NOLOCK)
				INNER JOIN bodb02.dbo.League AS L WITH (NOLOCK) ON P.LeagueId = L.LeagueId
				LEFT JOIN #TempLeagueGroupIDs AS lg ON L.LeagueGroupId = lg.ID
				LEFT JOIN dbo.LeagueExclusion le WITH(NOLOCK) ON P.LeagueId = le.LeagueId
				INNER JOIN #AllMatches AM ON P.MatchId = AM.matchid
				LEFT JOIN #RootMatches RM ON P.MatchId = RM.ChildMatchID
			WHERE P.EventDate BETWEEN @FromDate AND @ToDate
				AND P.Bettype IN (SELECT Bettype FROM @BettypeList)
				AND L.LeagueName LIKE '%' + @LeagueName + '%'
				AND (@Market = -1 OR P.IsLive = @Market)
				AND (@IsExcludeLeagues = 0 OR le.LeagueId IS NULL)
				AND (@LeagueGroupIds = '' OR lg.ID IS NOT NULL)
				AND (
					@ApplyVRFilter = 0 OR
					EXISTS (
						SELECT 1 FROM #TempVRSettings vrs
						WHERE (vrs.Setting = 'VR_PLUS' AND P.VarianceVR > 0)
						   OR (vrs.Setting = 'NO_VR' AND (P.VarianceVR IS NULL OR P.VarianceVR = 0))
						   OR (vrs.Setting = 'VR_MINUS' AND P.VarianceVR < 0)
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
			GROUP BY P.LeagueId
				, 	L.LeagueName
				,   lg.TargetLeagueGroupId
				,   lg.LeagueGroupName
				, 	P.IsLive;
		END;
		
		SELECT	m.LeagueId
		,	m.LeagueName
		,	m.LeagueGroupID
		,	m.LeagueGroupName
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
	ORDER BY m.Margin, m.LeagueName ASC;
		
	DROP TABLE #tmpLeaguePerformance;
    DROP TABLE IF EXISTS #AllMatches;
    DROP TABLE IF EXISTS #RootMatches;
    DROP TABLE IF EXISTS #TempVRSettings;
    DROP TABLE IF EXISTS #TempMatchGroup;
END;

GO

/*<info serverAlias="DBTGRS-bodb_TGRS" executers="wsv_tgrs" isFunction="0" isNested="0"></info>*/