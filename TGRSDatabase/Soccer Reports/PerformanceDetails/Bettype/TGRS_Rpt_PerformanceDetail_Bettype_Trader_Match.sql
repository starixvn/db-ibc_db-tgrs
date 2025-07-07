ALTER PROCEDURE [dbo].[TGRS_Rpt_PerformanceDetail_Bettype_Trader_Match]  	
		@FromDate			DATE
	,	@ToDate				DATE
	,	@LeagueName			NVARCHAR(500)= ''
	,	@LeagueGroupIds		VARCHAR(2000) = ''
	,	@CustId				INT
	,	@Bettype			SMALLINT
	,	@IsExcludeLeagues	BIT = 1
	,	@Market				SMALLINT = -1
	,	@VRSettings         VARCHAR(100) = 'ALL' -- Comma-separated: "VR_PLUS", "NO_VR", "VR_MINUS", "ALL"
	,	@MatchGroup         VARCHAR(100) = 'ALL' -- Comma-separated: "NORMAL", "EXTRA_TIME", "PENALTY", "HEDGE", "ALL"
	,	@Sites				NVARCHAR(MAX) = ''
AS    
/*  
	Created:	20160315@Thai.Tran
	Task:		Detail report - View Match detail from Bet Type, League and Trader
	DB:			DB06.bodb_TGRS_UAT & DB061.bodb_TGRS
	Original:      
	  			
	Revision:
		- 20171205@Simon:		get only Live data & Bettypes are not disabled
		- 20180912@Simon:		add league exclusion
		- 20190919@Long.Luu:	Support Nonlive Data [Redmine ID: 118959]
		- 20191023@John.Ngo:	Enhance performance [Redmine ID: 121268]
		- 20200710@John.Ngo:	Performance Detail - Support filter by league group [Redmine ID: 137276]
		- 20200909@John.Ngo:	Performance Detail - Bettype - Support filter by LeagueName [Redmine ID: 141294]
		- 20210809@Adam.Tran: 	Sports - Performance Real Figures [Redmine: #158981]
		- 20220222@John.Ngo:	Separate League Group for Virtual and SABA PinGoal [Redmine: #161859]
		- 20220307@John.Ngo: 	Update Separate League Group for Virtual [Redmine: #161859]
		- 20250523@Jaden.Tang:	Support new filter VR Settings and Match Group (excluding RootMatch logic) [Redmine: #227903]
		- 20250707@Jaden.Tang:	Add Site (company) filter [Redmine: #213812]

	Param's Explanation:  
		- @Market: -1 All; 0 Nonlive; 1 Live 	
		- @Sites: List of site names delimited by comma
	Example: 
		exec [TGRS_Rpt_PerformanceDetail_Bettype_Trader_Match] @Bettype=3,@FromDate='2016-03-02 00:00:00',@ToDate='2016-03-16 00:00:00',@CustId=2438 
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

	DECLARE @OtherGroupsId SMALLINT = 12;
	
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
        IsPenaltyMatch BIT,
        IsExtraTimeMatch BIT,
        IsHedgeMatch BIT,
        PRIMARY KEY (matchid)
    );

    INSERT INTO #AllMatches (matchid, IsPenaltyMatch, IsExtraTimeMatch, IsHedgeMatch)
    SELECT 
        M.matchid, 
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
    WHERE M.sporttype = 1
      AND M.EventDate >= CAST(@FromDate AS DATETIME) AND M.EventDate <= CAST(@ToDate AS DATETIME)
    OPTION (RECOMPILE);

    INSERT INTO #AllMatches (matchid, IsPenaltyMatch, IsExtraTimeMatch, IsHedgeMatch)
    SELECT 
        M14.matchid, 
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
    WHERE NOT EXISTS (SELECT 1 FROM #AllMatches am WHERE am.matchid = M14.matchid)
      AND M14.sporttype = 1
      AND M14.EventDate >= CAST(@FromDate AS DATETIME) AND M14.EventDate <= CAST(@ToDate AS DATETIME)
    OPTION (RECOMPILE);

    INSERT INTO #AllMatches (matchid, IsPenaltyMatch, IsExtraTimeMatch, IsHedgeMatch)
    SELECT 
        MBK.matchid, 
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
    WHERE NOT EXISTS (SELECT 1 FROM #AllMatches am WHERE am.matchid = MBK.matchid)
      AND MBK.sporttype = 1
      AND MBK.EventDate >= CAST(@FromDate AS DATETIME) AND MBK.EventDate <= CAST(@ToDate AS DATETIME)
    OPTION (RECOMPILE);

	IF (@LeagueName IS NULL OR @LeagueName = '')
		BEGIN
			SELECT 	P.MatchId
				, 	P.LeagueId
				,   lg.TargetLeagueGroupId AS LeagueGroupID
				, 	P.HomeId
				, 	P.AwayId
				, 	P.EventDate
				, 	P.IsLive
				,	ISNULL(SUM(P.BetCount), 0) AS BetCount
				,	ISNULL(SUM(P.Stake), 0) AS Turnover
				,	ISNULL(SUM(P.WinLost), 0) - ISNULL(SUM(P.Comm), 0) AS WinLoss				
				,	CASE WHEN ISNULL(SUM(P.Stake), 0) <> 0 THEN (ISNULL(SUM(P.WinLost), 0)- ISNULL(SUM(P.Comm), 0)) * 100/ISNULL(SUM(P.Stake), 0) ELSE NULL END AS Margin
				,	ISNULL(SUM(P.Stake_Real),0) 		AS TurnoverReal
				,	ISNULL(SUM(CASE WHEN P.Is8RM = 0 THEN P.WinLost_Real ELSE 0 END),0) AS WinLossReal
				,	CASE WHEN ISNULL(SUM(P.Stake_Real),0) <> 0 THEN ISNULL(SUM(CASE WHEN P.Is8RM = 0 THEN P.WinLost_Real ELSE 0 END),0) * 100/ISNULL(SUM(P.Stake_Real),0) ELSE NULL END AS MarginReal
			 FROM	dbo.TraderPerformance AS P WITH (NOLOCK)
	 			INNER JOIN bodb02.dbo.League AS L WITH (NOLOCK) ON P.LeagueId = L.LeagueId
				LEFT JOIN @LeagueGroups AS lg ON L.LeagueGroupId = lg.LeagueGroupId
				LEFT JOIN dbo.LeagueExclusion le WITH(NOLOCK) ON P.LeagueId = le.LeagueId
				INNER JOIN #AllMatches am WITH (NOLOCK) ON P.MatchId = am.matchid
			 WHERE	P.CustId = @CustId
				AND P.BetType = @Bettype
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
							   OR (mgf.Setting = 'PENALTY' AND am.IsPenaltyMatch = 1)
							   OR (mgf.Setting = 'EXTRA_TIME' AND am.IsExtraTimeMatch = 1)
							   OR (mgf.Setting = 'HEDGE' AND am.IsHedgeMatch = 1)
						)
					)
				AND (@Sites = '' OR EXISTS (SELECT 1 FROM @SitesList sl WHERE sl.SiteId = P.SiteID))
			GROUP BY P.MatchId, P.LeagueId
				,   lg.TargetLeagueGroupId
				,	P.HomeId, P.AwayId, P.EventDate, P.IsLive
			ORDER BY Margin DESC, P.EventDate ASC;
		END;
	ELSE
		BEGIN			
			SELECT 	P.MatchId
				, 	P.LeagueId
				,   lg.TargetLeagueGroupId AS LeagueGroupID
				, 	P.HomeId
				, 	P.AwayId
				, 	P.EventDate
				, 	P.IsLive
				,	ISNULL(SUM(P.BetCount), 0) AS BetCount
				,	ISNULL(SUM(P.Stake), 0) AS Turnover
				,	ISNULL(SUM(P.WinLost), 0) - ISNULL(SUM(P.Comm), 0) AS WinLoss				
				,	CASE WHEN ISNULL(SUM(P.Stake), 0) <> 0 THEN (ISNULL(SUM(P.WinLost), 0)- ISNULL(SUM(P.Comm), 0)) * 100/ISNULL(SUM(P.Stake), 0) ELSE NULL END AS Margin
				,	ISNULL(SUM(P.Stake_Real),0) 	AS TurnoverReal
				,	ISNULL(SUM(CASE WHEN P.Is8RM = 0 THEN P.WinLost_Real ELSE 0 END),0) AS WinLossReal
				,	CASE WHEN ISNULL(SUM(P.Stake_Real),0) <> 0 THEN ISNULL(SUM(CASE WHEN P.Is8RM = 0 THEN P.WinLost_Real ELSE 0 END),0) * 100/ISNULL(SUM(P.Stake_Real),0) ELSE NULL END AS MarginReal
			 FROM	dbo.TraderPerformance AS P WITH (NOLOCK)
	 			INNER JOIN bodb02.dbo.League AS L WITH (NOLOCK) ON P.LeagueId = L.LeagueId
				LEFT JOIN @LeagueGroups AS lg ON L.LeagueGroupId = lg.LeagueGroupId
				LEFT JOIN dbo.LeagueExclusion le WITH(NOLOCK) ON P.LeagueId = le.LeagueId
				INNER JOIN #AllMatches am WITH (NOLOCK) ON P.MatchId = am.matchid
			 WHERE	P.CustId = @CustId
				AND P.BetType = @Bettype
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
							WHERE (mgf.Setting = 'NORMAL' AND am.IsPenaltyMatch = 0 AND am.IsExtraTimeMatch = 0 AND am.IsHedgeMatch = 0)
							   OR (mgf.Setting = 'PENALTY' AND am.IsPenaltyMatch = 1)
							   OR (mgf.Setting = 'EXTRA_TIME' AND am.IsExtraTimeMatch = 1)
							   OR (mgf.Setting = 'HEDGE' AND am.IsHedgeMatch = 1)
						)
					)
			GROUP BY P.MatchId, P.LeagueId
				,   lg.TargetLeagueGroupId
				,	P.HomeId, P.AwayId, P.EventDate, P.IsLive
			ORDER BY Margin DESC, P.EventDate ASC;
		END;
			
    DROP TABLE IF EXISTS #AllMatches;
    DROP TABLE IF EXISTS #TempVRSettings;
    DROP TABLE IF EXISTS #TempMatchGroup;
END;

GO

/*<info serverAlias="DBTGRS-bodb_TGRS" executers="wsv_tgrs" isFunction="0" isNested="0"></info>*/