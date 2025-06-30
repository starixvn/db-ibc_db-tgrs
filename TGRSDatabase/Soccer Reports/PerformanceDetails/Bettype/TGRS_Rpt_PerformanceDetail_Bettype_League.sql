ALTER PROCEDURE [dbo].[TGRS_Rpt_PerformanceDetail_Bettype_League]  	
		@FromDate			DATE
	,	@ToDate				DATE
	,	@LeagueName			NVARCHAR(500)= ''
	,	@LeagueGroupIds		VARCHAR(2000) =  ''
	,	@Bettype			SMALLINT
	,	@IsExcludeLeagues	BIT = 1
	,	@Market				SMALLINT = -1
	,   @VRSettings         VARCHAR(100) = 'ALL' -- Comma-separated: "VR_PLUS", "NO_VR", "VR_MINUS", "ALL"
	,   @MatchGroup         VARCHAR(100) = 'ALL' -- Comma-separated: "NORMAL", "EXTRA_TIME", "PENALTY", "HEDGE", "ALL"
AS    
/*  
	 Created:	20160315@Thai.Tran
	 Task :		Detail report - League detail from Bet Type
	 DB:		DB06.bodb_TGRS_UAT & DB061.bodb_TGRS
	 Original:  
 
	 Revisions:      	
		- 20171205@Simon:		get only Live data & Bettypes are not disabled
		- 20180912@Simon:		add league exclusion
		- 20190919@Long.Luu:	Support Nonlive Data [Redmine ID: 118959]
		- 20191023@John.Ngo:	Enhance performance [Redmine ID: 121268]
		- 20200709@John.Ngo:	Performance Detail - Support filter by league group [Redmine ID: 137276]
		- 20200731@John.Ngo:	View down bet choice from League performance [Redmine ID: 137278]
		- 20200909@John.Ngo:	Performance Detail - Bettype - Support filter by LeagueName [Redmine ID: 141294]
		- 20210809@Adam.Tran: 	Sports - Performance Real Figures [Redmine: #158981]
		- 20220222@John.Ngo:	Separate League Group for Virtual and SABA PinGoal [Redmine: #161859]
		- 20220307@John.Ngo: 	Update Separate League Group for Virtual [Redmine: #161859]
		- 20250312@Jaden.Tang:  Return League Group name instead of League Group ID [Redmine: #213765]
		- 20250523@Jaden.Tang:	Support new filter VR Settings and Match Group [Redmine: #227903]
		
	 Param's Explanation:  	
		- @Market: -1 All; 0 Nonlive; 1 Live  

	 Exam: EXEC  TGRS_Rpt_PerformanceDetail_Bettype_League @FromDate = '2014-01-01', @ToDate= '2014-05-30', @Bettype = 1
  
*/  
 
BEGIN 
	SET NOCOUNT ON;
	
	DECLARE @OtherGroupsId SMALLINT = 12;
	
	IF @LeagueGroupIds IS NULL OR @LeagueGroupIds = '' OR @LeagueGroupIds = 'ALL'
	BEGIN
		SET @LeagueGroupIds = '' -- Keep consistent with original logic
	END
	
	DECLARE @LeagueGroups AS TABLE (LeagueGroupId SMALLINT PRIMARY KEY CLUSTERED, LeagueGroupName VARCHAR(200), TargetLeagueGroupId SMALLINT)
	INSERT INTO @LeagueGroups(LeagueGroupId, LeagueGroupName, TargetLeagueGroupId)
	EXECUTE dbo.[TGRS_LeagueGroupSoccer_Get] @LeagueGroupIds = @LeagueGroupIds;

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
			SELECT P.LeagueId
				,	L.LeagueName
				,   lg.TargetLeagueGroupId AS LeagueGroupID
				,   lg.LeagueGroupName
				,	P.IsLive
				,	ISNULL(COUNT(DISTINCT P.CustId), 0) 	AS TraderCount
				,	ISNULL(COUNT(DISTINCT P.MatchID), 0) 	AS MatchCount
				,	ISNULL(COUNT(DISTINCT P.BetChoice), 0) 	AS BetChoiceCount
				,	ISNULL(SUM(P.BetCount), 0) 				AS BetCount
				,	ISNULL(SUM(P.Stake), 0) 				AS Turnover
				,	ISNULL(SUM(P.WinLost), 0) - ISNULL(SUM (P.Comm), 0) AS WinLoss
				,	CASE WHEN ISNULL(SUM(P.Stake), 0) <> 0 THEN (ISNULL(SUM(P.WinLost), 0) - ISNULL(SUM(P.Comm), 0)) * 100/SUM(P.Stake) ELSE NULL END AS Margin
				,	ISNULL(SUM(P.Stake_Real),0) 			AS TurnoverReal
				,	ISNULL(SUM(CASE WHEN P.Is8RM = 0 THEN P.WinLost_Real ELSE 0 END),0) AS WinLossReal
				,	CASE WHEN ISNULL(SUM(P.Stake_Real),0) <> 0 THEN ISNULL(SUM(CASE WHEN P.Is8RM = 0 THEN P.WinLost_Real ELSE 0 END),0) * 100/ISNULL(SUM(P.Stake_Real),0) ELSE NULL END AS MarginReal
			FROM dbo.TraderPerformance_BetChoice AS P WITH (NOLOCK)	 
				INNER JOIN bodb02.dbo.League AS L WITH (NOLOCK) ON P.LeagueId = L.LeagueId
				LEFT JOIN @LeagueGroups AS lg ON L.LeagueGroupId = lg.LeagueGroupId
				LEFT JOIN dbo.LeagueExclusion le WITH(NOLOCK) ON P.LeagueId = le.LeagueId
				INNER JOIN #AllMatches AS M ON P.MatchId = M.matchid
				LEFT JOIN #RootMatches RM ON P.MatchId = RM.ChildMatchID
			WHERE	 P.EventDate BETWEEN @FromDate AND @ToDate
				AND  P.Bettype = @Bettype
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
							WHERE (mgf.Setting = 'NORMAL' AND M.IsPenaltyMatch = 0 AND M.IsExtraTimeMatch = 0 AND M.IsHedgeMatch = 0)
							   OR (mgf.Setting = 'PENALTY' AND M.IsPenaltyMatch = 1)
							   OR (mgf.Setting = 'EXTRA_TIME' AND M.IsExtraTimeMatch = 1)
							   OR (mgf.Setting = 'HEDGE' AND M.IsHedgeMatch = 1)
						)
					)
			GROUP BY P.LeagueId, L.LeagueName
				,   lg.TargetLeagueGroupId
				,   lg.LeagueGroupName
				,	P.IsLive 	
			ORDER BY Margin DESC, LeagueName ASC;
		END;
	ELSE
		BEGIN			
			SELECT  P.LeagueId
				,	L.LeagueName
				,   lg.TargetLeagueGroupId AS LeagueGroupID
				,   lg.LeagueGroupName
				,	P.IsLive
				,	ISNULL(COUNT(DISTINCT P.CustId), 0) 	AS TraderCount
				,	ISNULL(COUNT(DISTINCT P.MatchID), 0) 	AS MatchCount
				,	ISNULL(COUNT(DISTINCT P.BetChoice), 0) 	AS BetChoiceCount
				,	ISNULL(SUM(P.BetCount), 0) 				AS BetCount
				,	ISNULL(SUM(P.Stake), 0) 				AS Turnover
				,	ISNULL(SUM(P.WinLost), 0) - ISNULL(SUM (P.Comm), 0) AS WinLoss
				,	CASE WHEN ISNULL(SUM(P.Stake), 0) <> 0 THEN (ISNULL(SUM(P.WinLost), 0) - ISNULL(SUM(P.Comm), 0)) * 100/SUM(P.Stake) ELSE NULL END AS Margin
				,	ISNULL(SUM(P.Stake_Real),0) 			AS TurnoverReal
				,	ISNULL(SUM(CASE WHEN P.Is8RM = 0 THEN P.WinLost_Real ELSE 0 END),0) AS WinLossReal
				,	CASE WHEN ISNULL(SUM(P.Stake_Real),0) <> 0 THEN ISNULL(SUM(CASE WHEN P.Is8RM = 0 THEN P.WinLost_Real ELSE 0 END),0) * 100/ISNULL(SUM(P.Stake_Real),0) ELSE NULL END AS MarginReal				
			FROM dbo.TraderPerformance_BetChoice AS P WITH (NOLOCK)	 
				INNER JOIN bodb02.dbo.League AS L WITH (NOLOCK) ON P.LeagueId = L.LeagueId
				LEFT JOIN @LeagueGroups AS lg ON L.LeagueGroupId = lg.LeagueGroupId
				LEFT JOIN dbo.LeagueExclusion le WITH(NOLOCK) ON P.LeagueId = le.LeagueId
				INNER JOIN #AllMatches AS M ON P.MatchId = M.matchid
				LEFT JOIN #RootMatches RM ON P.MatchId = RM.ChildMatchID
			WHERE	 P.EventDate BETWEEN @FromDate AND @ToDate
				AND  P.Bettype = @Bettype
				AND L.LeagueName LIKE '%' + @LeagueName + '%'
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
							WHERE (mgf.Setting = 'NORMAL' AND M.IsPenaltyMatch = 0 AND M.IsExtraTimeMatch = 0 AND M.IsHedgeMatch = 0)
							   OR (mgf.Setting = 'PENALTY' AND M.IsPenaltyMatch = 1)
							   OR (mgf.Setting = 'EXTRA_TIME' AND M.IsExtraTimeMatch = 1)
							   OR (mgf.Setting = 'HEDGE' AND M.IsHedgeMatch = 1)
						)
					)
			GROUP BY P.LeagueId, L.LeagueName
				,   lg.TargetLeagueGroupId
				,   lg.LeagueGroupName
				,	P.IsLive 	
			ORDER BY Margin DESC, LeagueName ASC;
		END;
		
    DROP TABLE IF EXISTS #AllMatches;
    DROP TABLE IF EXISTS #RootMatches;
    DROP TABLE IF EXISTS #TempVRSettings;
    DROP TABLE IF EXISTS #TempMatchGroup;
END;

GO

/*<info serverAlias="DBTGRS-bodb_TGRS" executers="wsv_tgrs" isFunction="0" isNested="0"></info>*/
