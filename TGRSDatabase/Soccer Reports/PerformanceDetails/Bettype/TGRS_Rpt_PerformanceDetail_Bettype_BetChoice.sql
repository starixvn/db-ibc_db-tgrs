ALTER PROCEDURE [dbo].[TGRS_Rpt_PerformanceDetail_Bettype_BetChoice]  	
		@FromDate			DATE
	,	@ToDate				DATE
	,	@LeagueName			NVARCHAR(500)= ''
	,	@LeagueGroupIds		VARCHAR(2000) =  ''
	,	@BetType			SMALLINT
	,	@IsExcludeLeagues	BIT = 1
	,	@Market				SMALLINT = -1
	,   @VRSettings         VARCHAR(100) = 'ALL' -- Comma-separated: "VR_PLUS", "NO_VR", "VR_MINUS", "ALL"
	,   @MatchGroup         VARCHAR(100) = 'ALL' -- Comma-separated: "NORMAL", "EXTRA_TIME", "PENALTY", "HEDGE", "ALL"
	,	@Sites				NVARCHAR(MAX) = ''
AS    
/*  
	 Created:	20171212@Aaron
	 Task :		Detail report - Bet choice detail from Bet Type
	 DB:		DB06.bodb_TGRS_UAT & DB061.bodb_TGRS
	 Original:  
 
	 Revisions:
		- 20180912@Simon:		add league exclusion
		- 20190919@Long.Luu:	Support Nonlive Data [Redmine ID: 118959]
		- 20191022@Long.Luu:	Showing betteam in case of betchoices are not mapped [Redmine ID: 121268]
		- 20191023@John.Ngo:	Enhance performance [Redmine ID: 121268]
		- 20200709@John.Ngo:	Performance Detail - Support filter by league group & Fix issue 'show betteam' [Redmine ID: 137276]
		- 20200909@John.Ngo:	Performance Detail - Bettype - Support filter by LeagueName [Redmine ID: 141294]
		- 20210809@Adam.Tran: 	Sports - Performance Real Figures [Redmine: #158981]
		- 20210915@Adam.Tran: 	Add Fast Market Bettype - [Redmine: #157999]
		- 20220117@John.Ngo: 	Support view down for Total Goal, Time Machine and Corner bettype [Redmine: #166679]
		- 20220222@John.Ngo:	Separate League Group for Virtual and SABA PinGoal [Redmine: #161859]
		- 20250523@Jaden.Tang:	Support new filter VR Settings and Match Group [Redmine: #227903]
		- 20250707@Jaden.Tang:	Add Site (company) filter [Redmine: #213812]
	 Param's Explanation:  	
		- @Market: -1 All; 0 Nonlive; 1 Live
		- @Sites: List of site names delimited by comma

	 Exam: 
		EXEC  TGRS_Rpt_PerformanceDetail_Bettype_BetChoice @FromDate = '2021-11-01', @ToDate= '2021-12-30', @Bettype = 227, @Market = 1
*/  
 
BEGIN 
	SET NOCOUNT ON;
	
	DECLARE @SitesList AS TABLE (SiteId INT PRIMARY KEY CLUSTERED);
	IF @Sites <> ''
	BEGIN
		INSERT INTO @SitesList
		SELECT SiteId 
		FROM bodb02.dbo.site WITH (NOLOCK)
		WHERE [site] IN (SELECT DISTINCT [value] FROM string_split(@Sites,','));
	END;

	IF @LeagueGroupIds IS NULL OR @LeagueGroupIds = '' OR @LeagueGroupIds = 'ALL'
	BEGIN
		SET @LeagueGroupIds = '' -- Keep consistent with original logic that treats empty string for no filter
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
	
	DECLARE @IsFMBetType BIT, @IsBetChoiceDetail BIT;
	
	SET @IsFMBetType = CASE WHEN EXISTS (SELECT (1) FROM dbo.BetChoice_FastMarketMapping AS b
										 WHERE b.BetType = @BetType) THEN 1 ELSE 0 END;
	
	SET @IsBetChoiceDetail = (CASE WHEN EXISTS (SELECT (1) FROM [dbo].[BetType] AS b WITH (NOLOCK)
												WHERE b.BetType = @BetType AND b.IsBetChoiceDetail = 1) 
												THEN 1 ELSE 0 END);

	IF (@LeagueName IS NULL OR @LeagueName = '')		
		BEGIN
			IF @IsFMBetType = 1
				BEGIN
					SELECT P.betteam											AS BetTeam
						,	FM.BetOption										AS BetOption
						,	P.hdp2												AS hdp2
						,	(CASE WHEN @BetType IN(221,222) THEN P.oddsspread ELSE -1 END)	AS OddsSpread
						,	P.IsLive											AS IsLive
						,	ISNULL(COUNT(DISTINCT P.LeagueId), 0)				AS LeagueCount
						,	ISNULL(COUNT(DISTINCT P.MatchID), 0)			AS MatchCount
						,	ISNULL(SUM(P.Stake), 0)								AS Turnover 
						,	ISNULL(SUM(P.WinLost), 0) - ISNULL(SUM (P.Comm), 0)	AS WinLoss
						,	ISNULL(SUM(P.Stake_Real),0) 						AS TurnoverReal				
						,	ISNULL(SUM(CASE WHEN P.Is8RM = 0 THEN P.WinLost_Real ELSE 0 END),0) AS WinLossReal
						,	ISNULL(SUM(P.BetCount), 0)							AS BetCount
					FROM dbo.TraderPerformance_BetChoice_Detail AS P WITH (NOLOCK)
						INNER JOIN bodb02.dbo.League AS L WITH (NOLOCK) ON P.LeagueId = L.LeagueId
						INNER JOIN dbo.BetChoice_FastMarketMapping AS FM WITH (NOLOCK) ON FM.BetType = P.BetType AND FM.betteam = P.betteam AND FM.hdp2 = P.hdp2
						LEFT JOIN @LeagueGroups AS lg ON L.LeagueGroupId = lg.LeagueGroupId
						LEFT JOIN dbo.LeagueExclusion le WITH(NOLOCK) ON P.LeagueId = le.LeagueId						
						INNER JOIN #AllMatches AS M ON P.MatchId = M.matchid
						LEFT JOIN #RootMatches RM ON P.MatchId = RM.ChildMatchID
					WHERE	P.BetType = @BetType
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
									WHERE (mgf.Setting = 'NORMAL' AND M.IsPenaltyMatch = 0 AND M.IsExtraTimeMatch = 0 AND M.IsHedgeMatch = 0)
									   OR (mgf.Setting = 'PENALTY' AND M.IsPenaltyMatch = 1)
									   OR (mgf.Setting = 'EXTRA_TIME' AND M.IsExtraTimeMatch = 1)
									   OR (mgf.Setting = 'HEDGE' AND M.IsHedgeMatch = 1)
								)
							)
						AND (@Sites = '' OR EXISTS (SELECT 1 FROM @SitesList sl WHERE sl.SiteId = P.SiteID))
					GROUP BY P.betteam, FM.BetOption, P.oddsspread, P.IsLive, P.hdp2;
				END;
			ELSE
				BEGIN
					SELECT ISNULL(bcm.TGRSBetChoice, P.BetChoice)				AS BetChoice
						,	P.IsLive											AS IsLive
						,	ISNULL(COUNT(DISTINCT P.LeagueId), 0)				AS LeagueCount
						,	ISNULL(COUNT(DISTINCT P.MatchID), 0)			AS MatchCount
						,	ISNULL(SUM(P.Stake), 0)								AS Turnover 
						,	ISNULL(SUM(P.WinLost), 0) - ISNULL(SUM (P.Comm), 0)	AS WinLoss
						,	ISNULL(SUM(P.Stake_Real),0) 						AS TurnoverReal				
						,	ISNULL(SUM(CASE WHEN P.Is8RM = 0 THEN P.WinLost_Real ELSE 0 END),0) AS WinLossReal
						,	ISNULL(SUM(P.BetCount), 0)							AS BetCount
					FROM dbo.TraderPerformance_BetChoice AS P WITH (NOLOCK)
						INNER JOIN bodb02.dbo.League AS L WITH (NOLOCK) ON P.LeagueId = L.LeagueId
						LEFT JOIN @LeagueGroups AS lg ON L.LeagueGroupId = lg.LeagueGroupId
						LEFT JOIN dbo.BetChoiceMapping AS bcm WITH (NOLOCK) ON bcm.BetType = P.BetType
						LEFT JOIN dbo.LeagueExclusion le WITH(NOLOCK) ON P.LeagueId = le.LeagueId
						INNER JOIN #AllMatches AS M ON P.MatchId = M.matchid
						LEFT JOIN #RootMatches RM ON P.MatchId = RM.ChildMatchID
					WHERE	P.BetType = @BetType
						AND P.EventDate BETWEEN @FromDate AND @ToDate
						AND (@Market = -1 OR P.IsLive = @Market)
						AND (P.BetChoice = bcm.BetChoice OR bcm.BetChoice IS NULL)
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
						AND (@Sites = '' OR EXISTS (SELECT 1 FROM @SitesList sl WHERE sl.SiteId = P.SiteID))
					GROUP BY ISNULL(bcm.TGRSBetChoice, P.BetChoice), P.IsLive;
				END;			
		END;
	ELSE
		BEGIN
			IF @IsFMBetType = 1
				BEGIN
					SELECT P.betteam										AS BetTeam
					,	FM.BetOption										AS BetOption
					,	P.hdp2												AS hdp2
					,	(CASE WHEN @BetType IN(221,222) THEN P.oddsspread ELSE -1 END)	AS OddsSpread
					,	P.IsLive											AS IsLive
					,	ISNULL(COUNT(DISTINCT P.LeagueId), 0)				AS LeagueCount
					,	ISNULL(COUNT(DISTINCT P.MatchId), 0)				AS MatchCount
					,	ISNULL(COUNT(DISTINCT P.MatchID), 0)			AS MatchCount
					,	ISNULL(SUM(P.Stake), 0)								AS Turnover 
					,	ISNULL(SUM(P.WinLost), 0) - ISNULL(SUM (P.Comm), 0)	AS WinLoss
					,	ISNULL(SUM(P.Stake_Real),0) 						AS TurnoverReal
					,	ISNULL(SUM(P.WinLost_Real),0) 						AS WinLossReal
					,	ISNULL(SUM(CASE WHEN P.Is8RM = 0 THEN P.WinLost_Real ELSE 0 END),0) AS WinLossReal
					,	ISNULL(SUM(P.BetCount), 0)							AS BetCount				
					FROM dbo.TraderPerformance_BetChoice_Detail AS P WITH (NOLOCK)
						INNER JOIN bodb02.dbo.League AS L WITH (NOLOCK) ON P.LeagueId = L.LeagueId
						INNER JOIN dbo.BetChoice_FastMarketMapping AS FM WITH (NOLOCK) ON FM.BetType = P.BetType AND FM.betteam = P.betteam AND FM.hdp2 = P.hdp2
						LEFT JOIN @LeagueGroups AS lg ON L.LeagueGroupId = lg.LeagueGroupId
						LEFT JOIN dbo.LeagueExclusion le WITH(NOLOCK) ON P.LeagueId = le.LeagueId						
						INNER JOIN #AllMatches AS M ON P.MatchId = M.matchid
						LEFT JOIN #RootMatches RM ON P.MatchId = RM.ChildMatchID
					WHERE	P.BetType = @BetType
						AND P.EventDate BETWEEN @FromDate AND @ToDate
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
						AND (@Sites = '' OR EXISTS (SELECT 1 FROM @SitesList sl WHERE sl.SiteId = P.SiteID))
					GROUP BY P.betteam, FM.BetOption, P.oddsspread, P.IsLive, P.hdp2;
				END;
			ELSE -- @IsBetChoiceDetail = 0 or 1
				BEGIN
					SELECT ISNULL(bcm.TGRSBetChoice, P.BetChoice)			AS BetChoice
					,	P.IsLive											AS IsLive
					,	ISNULL(COUNT(DISTINCT P.LeagueId), 0)				AS LeagueCount
					,	ISNULL(COUNT(DISTINCT P.MatchID), 0)			AS MatchCount
					,	ISNULL(SUM(P.Stake), 0)								AS Turnover 
					,	ISNULL(SUM(P.WinLost), 0) - ISNULL(SUM (P.Comm), 0)	AS WinLoss
					,	ISNULL(SUM(P.Stake_Real),0) 						AS TurnoverReal
					,	ISNULL(SUM(P.WinLost_Real),0) 						AS WinLossReal
					,	ISNULL(SUM(CASE WHEN P.Is8RM = 0 THEN P.WinLost_Real ELSE 0 END),0) AS WinLossReal
					,	ISNULL(SUM(P.BetCount), 0)							AS BetCount				
					FROM dbo.TraderPerformance_BetChoice AS P WITH (NOLOCK)
						INNER JOIN bodb02.dbo.League AS L WITH (NOLOCK) ON P.LeagueId = L.LeagueId
						LEFT JOIN @LeagueGroups AS lg ON L.LeagueGroupId = lg.LeagueGroupId
						LEFT JOIN dbo.BetChoiceMapping AS bcm WITH (NOLOCK) ON bcm.BetType = P.BetType
						LEFT JOIN dbo.LeagueExclusion le WITH(NOLOCK) ON P.LeagueId = le.LeagueId
						INNER JOIN #AllMatches AS M ON P.MatchId = M.matchid
						LEFT JOIN #RootMatches RM ON P.MatchId = RM.ChildMatchID
					WHERE	P.BetType = @BetType
						AND P.EventDate BETWEEN @FromDate AND @ToDate
						AND L.LeagueName LIKE '%' + @LeagueName + '%'
						AND (@Market = -1 OR P.IsLive = @Market)
						AND (P.BetChoice = bcm.BetChoice OR bcm.BetChoice IS NULL)
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
						AND (@Sites = '' OR EXISTS (SELECT 1 FROM @SitesList sl WHERE sl.SiteId = P.SiteID))
					GROUP BY ISNULL(bcm.TGRSBetChoice, P.BetChoice), P.IsLive;
				END;
		END;
		
		SELECT @IsFMBetType AS IsFMBetType, @IsBetChoiceDetail AS IsBetChoiceDetail;

    DROP TABLE IF EXISTS #AllMatches;
    DROP TABLE IF EXISTS #RootMatches;
    DROP TABLE IF EXISTS #TempVRSettings;
    DROP TABLE IF EXISTS #TempMatchGroup;
END;

GO

/*<info serverAlias="DBTGRS-bodb_TGRS" executers="wsv_tgrs" isFunction="0" isNested="0"></info>*/
