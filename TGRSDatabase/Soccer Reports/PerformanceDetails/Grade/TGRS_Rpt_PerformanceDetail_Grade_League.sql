ALTER PROCEDURE [dbo].[TGRS_Rpt_PerformanceDetail_Grade_League]  	
		@FromDate			DATE
	,	@ToDate				DATE
	,	@LeagueGroupIds		VARCHAR(2000) = ''
	,	@Grade				INT
	,	@Bettypes			VARCHAR(2000) =  '0'
	,	@IsExcludeLeagues	BIT = 1
	,	@Market				SMALLINT = 1
	,   @VRSettings         VARCHAR(100) = 'ALL' -- Comma-separated: "VR_PLUS", "NO_VR", "VR_MINUS", "ALL"
	,   @MatchGroup         VARCHAR(100) = 'ALL' -- Comma-separated: "NORMAL", "EXTRA_TIME", "PENALTY", "HEDGE", "ALL"
AS    
/*  
 Created:	20160328@Aaron.Cao
 Task :		Detail report - Grade -> League Performance
 DB:		DBTGRS.bodb_TGRS
 Original:  
 
 Revisions:      	
	- 20171019@Simon:		Change VARCHAR(200) to VARCHAR(2000)
	- 20171205@Simon:		get only Live data & Bettypes are not disabled
	- 20180912@Simon:		add league exclusion
	- 20190822@Long.Luu:	grade brokendown for details performance [Redmine ID: 117030]
	- 20190919@Long.Luu:	Support Nonlive Data [Redmine ID: 118959]
	- 20191023@John.Ngo:	Enhance performance [Redmine ID: 121268]
	- 20200713@John.Ngo:	Performance Detail - Support filter by league group [Redmine ID: 137276]
	- 20210827@Adam.Tran: 	Sports - Performance Real Figures [Redmine: #158981]
	- 20220222@John.Ngo:	Separate League Group for Virtual and SABA PinGoal [Redmine: #161859]
	- 20220307@John.Ngo: 	Update Separate League Group for Virtual [Redmine: #161859]
	- 20250524@Jaden.Tang:	Support new filter VR Settings and Match Group [Redmine: #227903]

 Param's Explanation:  	
	- @Market: -1 All; 0 Nonlive; 1 Live

 Exam: 
	  EXEC  TGRS_Rpt_PerformanceDetail_Grade_League @FromDate = '2016-03-13', @ToDate= '2016-03-27', @Grade = 1
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

	DECLARE @OtherGroupsId SMALLINT = 12;
	
	DECLARE @LeagueGroups AS TABLE (LeagueGroupId SMALLINT PRIMARY KEY CLUSTERED, LeagueGroupName VARCHAR(200), TargetLeagueGroupId SMALLINT)
	INSERT INTO @LeagueGroups(LeagueGroupId, LeagueGroupName, TargetLeagueGroupId)
	EXECUTE dbo.[TGRS_LeagueGroupSoccer_Get] @LeagueGroupIds = @LeagueGroupIds;
	
	DECLARE @BettypeList AS TABLE (Bettype SMALLINT);
	IF @Bettypes <> '0'
		INSERT INTO @BettypeList
		SELECT val 
		FROM dbo.strSplit_Key(@Bettypes,',');
	ELSE 
		INSERT INTO @BettypeList
		SELECT Bettype 
		FROM dbo.Bettype WITH (NOLOCK);
	
	SELECT P.LeagueId
		,	L.LeagueName
		,   lg.TargetLeagueGroupId AS LeagueGroupID
		,	P.IsLive
		,	ISNULL(COUNT(DISTINCT P.CustId), 0) 					AS TraderCount
		,	ISNULL(COUNT(DISTINCT RM.RootMatchID), 0) 					AS MatchCount
		,	ISNULL(SUM(P.Stake), 0) 								AS Turnover
		,	ISNULL(SUM(P.WinLost), 0) - ISNULL(SUM (P.Comm),0) 		AS WinLoss
		,	CASE WHEN ISNULL(SUM(P.Stake), 0) <> 0 THEN (ISNULL(SUM(P.WinLost), 0) - ISNULL(SUM(P.Comm), 0)) * 100/SUM(P.Stake) ELSE NULL END AS Margin
		,	ISNULL(SUM(P.Stake_Real),0) 							AS TurnoverReal
		,	ISNULL(SUM(CASE WHEN P.Is8RM = 0 THEN P.WinLost_Real ELSE 0 END),0) 	AS WinLossReal
		,	CASE WHEN ISNULL(SUM(P.Stake_Real),0) <> 0 THEN ISNULL(SUM(CASE WHEN P.Is8RM = 0 THEN P.WinLost_Real ELSE 0 END),0) * 100/ISNULL(SUM(P.Stake_Real),0) ELSE NULL END 							   AS MarginReal
		,	ISNULL(SUM(P.BetCount), 0) AS BetCount
	FROM dbo.TraderPerformance AS P WITH (NOLOCK)
		INNER JOIN bodb02.dbo.League AS L WITH (NOLOCK) ON P.LeagueId = L.LeagueId
		LEFT JOIN @LeagueGroups AS lg ON L.LeagueGroupId = lg.LeagueGroupId
		LEFT JOIN dbo.LeagueExclusion le WITH(NOLOCK) ON P.LeagueId = le.LeagueId
		INNER JOIN #AllMatches AM ON P.MatchId = AM.matchid
		LEFT JOIN #RootMatches RM ON P.MatchId = RM.ChildMatchID
	WHERE	P.Bettype IN (SELECT bettype FROM @BettypeList)
		AND P.Grade = @Grade
		AND P.EventDate BETWEEN @FromDate AND @ToDate	
		AND (@Market = -1 OR P.IsLive = @Market)
		AND (@IsExcludeLeagues = 0 OR le.LeagueId IS NULL)
		AND (@LeagueGroupIds = '' OR lg.LeagueGroupId IS NOT NULL)
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
	GROUP BY P.LeagueId, L.LeagueName, L.LeagueGroupID
		,   lg.TargetLeagueGroupId
		,	P.IsLive	
	ORDER BY Margin DESC, LeagueName ASC;

    DROP TABLE IF EXISTS #AllMatches;
    DROP TABLE IF EXISTS #RootMatches;
    DROP TABLE IF EXISTS #TempVRSettings;
    DROP TABLE IF EXISTS #TempMatchGroup;
END;

GO

/*<info serverAlias="DBTGRS-bodb_TGRS" executers="wsv_tgrs" isFunction="0" isNested="0"></info>*/
