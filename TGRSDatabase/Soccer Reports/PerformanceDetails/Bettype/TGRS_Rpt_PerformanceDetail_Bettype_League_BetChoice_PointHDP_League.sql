ALTER PROCEDURE [dbo].[TGRS_Rpt_PerformanceDetail_Bettype_League_BetChoice_League]  	
		@FromDate			DATE
	,	@ToDate				DATE
	,	@LeagueId			INT
	,	@BetType			SMALLINT
	,	@BetTeam			NVARCHAR(50)
	,	@PointHDP			MONEY = NULL
	,	@IsExcludeLeagues	BIT = 1
	,	@Market				SMALLINT = -1
	,	@VRSettings         VARCHAR(100) = 'ALL' -- Comma-separated: "VR_PLUS", "NO_VR", "VR_MINUS", "ALL"
	,	@MatchGroup         VARCHAR(100) = 'ALL' -- Comma-separated: "NORMAL", "EXTRA_TIME", "PENALTY", "HEDGE", "ALL"
AS    
/*  
	 Created:	20220117@John.Ngo
	 Task :		Support drilldown BetChoiceDetail
	 DB:		DB06.bodb_TGRS_UAT & DB061.bodb_TGRS
	 Original:  
 
	 Revisions:
		- 20220117@John.Ngo: 	Support view down for Total Goal, Time Machine and Corner bettype [Redmine: #166679]
		- 20250524@Jaden.Tang:	Support new filter VR Settings and Match Group [Redmine: #227903]
		
	 Param's Explanation:  	
		- @Market: -1 All; 0 Nonlive; 1 Live

 Example:
	EXEC TGRS_Rpt_PerformanceDetail_Bettype_League_BetChoice_League @FromDate = '2023-01-01', @ToDate = '2023-01-31', @LeagueId = 1234, @BetType = 1, @BetTeam = 'HOME', @PointHDP = 0.5, @Market = -1, @VRSettings = 'ALL', @MatchGroup = 'ALL'

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
        matchid INT PRIMARY KEY,
        parentid INT NULL,
        IsPenaltyMatch BIT,
        IsExtraTimeMatch BIT,
		IsHedgeMatch BIT
    );

    INSERT INTO #AllMatches (matchid, parentid, IsPenaltyMatch, IsExtraTimeMatch, IsHedgeMatch)
    SELECT 
        M.matchid, M.parentid,
        CASE WHEN HT.teamname LIKE N'%(PEN)%' THEN 1 ELSE 0 END AS IsPenaltyMatch,
        CASE WHEN HT.teamname LIKE N'%(ET)%' THEN 1 ELSE 0 END AS IsExtraTimeMatch,
		CASE WHEN M.MatchCode LIKE N'%hedge%' THEN 1 ELSE 0 END AS IsHedgeMatch
    FROM bodb02.dbo.Match M WITH (NOLOCK)
    LEFT JOIN bodb02.dbo.Team HT WITH (NOLOCK) ON M.homeid = HT.teamid AND HT.SportType = M.sporttype
    WHERE M.eventdate BETWEEN CAST(@FromDate AS DATETIME) AND CAST(@ToDate AS DATETIME)
      AND M.sporttype = 1
    OPTION (RECOMPILE);

    INSERT INTO #AllMatches (matchid, parentid, IsPenaltyMatch, IsExtraTimeMatch, IsHedgeMatch)
    SELECT 
        M14.matchid, M14.parentid,
        CASE WHEN HT.teamname LIKE N'%(PEN)%' THEN 1 ELSE 0 END AS IsPenaltyMatch,
        CASE WHEN HT.teamname LIKE N'%(ET)%' THEN 1 ELSE 0 END AS IsExtraTimeMatch,
		CASE WHEN M14.MatchCode LIKE N'%hedge%' THEN 1 ELSE 0 END AS IsHedgeMatch
    FROM bodb02.dbo.Match14 M14 WITH (NOLOCK)
    LEFT JOIN bodb02.dbo.Team HT WITH (NOLOCK) ON M14.homeid = HT.teamid AND HT.SportType = M14.sporttype
    WHERE M14.eventdate BETWEEN CAST(@FromDate AS DATETIME) AND CAST(@ToDate AS DATETIME)
      AND M14.sporttype = 1
      AND NOT EXISTS (SELECT 1 FROM #AllMatches am WHERE am.matchid = M14.matchid)
    OPTION (RECOMPILE);

    INSERT INTO #AllMatches (matchid, parentid, IsPenaltyMatch, IsExtraTimeMatch, IsHedgeMatch)
    SELECT 
        MBK.matchid, MBK.parentid,
        CASE WHEN HT.teamname LIKE N'%(PEN)%' THEN 1 ELSE 0 END AS IsPenaltyMatch,
        CASE WHEN HT.teamname LIKE N'%(ET)%' THEN 1 ELSE 0 END AS IsExtraTimeMatch,
		CASE WHEN MBK.MatchCode LIKE N'%hedge%' THEN 1 ELSE 0 END AS IsHedgeMatch
    FROM bodb_archive.dbo.Match_bk MBK WITH (NOLOCK)
    LEFT JOIN bodb02.dbo.Team HT WITH (NOLOCK) ON MBK.homeid = HT.teamid AND HT.SportType = MBK.sporttype
    WHERE MBK.eventdate BETWEEN CAST(@FromDate AS DATETIME) AND CAST(@ToDate AS DATETIME)
      AND MBK.sporttype = 1
      AND NOT EXISTS (SELECT 1 FROM #AllMatches am WHERE am.matchid = MBK.matchid)
    OPTION (RECOMPILE);

	SELECT 	P.LeagueId
		,	L.LeagueName
		,	L.LeagueGroupID
		,	P.IsLive
		,	ISNULL(COUNT(DISTINCT P.MatchId), 0)				AS MatchCount
		,	ISNULL(SUM(P.BetCount), 0)							AS BetCount
		,	ISNULL(SUM(P.Stake), 0)								AS Turnover
		,	ISNULL(SUM(P.WinLost), 0) - ISNULL(SUM (P.Comm), 0)	AS WinLoss
		,	CASE WHEN ISNULL(SUM(P.Stake), 0) <> 0 THEN (ISNULL(SUM(P.WinLost), 0) - ISNULL(SUM(P.Comm), 0)) * 100/SUM(P.Stake) ELSE NULL END AS Margin
		,	ISNULL(SUM(P.Stake_Real),0) 						AS TurnoverReal		
		,	ISNULL(SUM(CASE WHEN P.Is8RM = 0 THEN P.WinLost_Real ELSE 0 END),0) AS WinLossReal
		,	CASE WHEN ISNULL(SUM(P.Stake_Real),0) <> 0 THEN ISNULL(SUM(CASE WHEN P.Is8RM = 0 THEN P.WinLost_Real ELSE 0 END),0) * 100/ISNULL(SUM(P.Stake_Real),0) ELSE NULL END AS MarginReal
	FROM dbo.TraderPerformance_BetChoice_Detail AS P WITH (NOLOCK)   
		INNER JOIN bodb02.dbo.League AS L WITH (NOLOCK) ON P.LeagueId = L.LeagueId	
		INNER JOIN #AllMatches AM ON P.MatchId = AM.matchid	
		LEFT JOIN dbo.BetChoiceMapping AS bcm WITH (NOLOCK) ON bcm.BetType = P.BetType AND bcm.BetChoice = P.betteam
		LEFT JOIN dbo.LeagueExclusion le WITH(NOLOCK) ON P.LeagueId = le.LeagueId  
	WHERE	P.EventDate BETWEEN @FromDate AND @ToDate
		AND	P.BetType = @BetType 
		AND P.LeagueId = @LeagueId
		AND ISNULL(bcm.TGRSBetChoice,P.betteam) = @BetTeam
		AND (CASE WHEN @BetType IN (228,229) THEN P.oddsspread
				  WHEN @BetType IN (28,453)  THEN (P.hdp1-P.hdp2)
				   ELSE P.hdp1 END) = @PointHDP
		AND (@Market = -1 OR P.IsLive = @Market)
		AND (@IsExcludeLeagues = 0 OR le.LeagueId IS NULL)
		AND (@ApplyVRFilter = 0 OR EXISTS (SELECT 1 FROM #TempVRSettings vrs WHERE (vrs.Setting = 'VR_PLUS' AND P.VarianceVR > 0) OR (vrs.Setting = 'NO_VR' AND (P.VarianceVR IS NULL OR P.VarianceVR = 0)) OR (vrs.Setting = 'VR_MINUS' AND P.VarianceVR < 0)))
		AND (@ApplyMatchGroupFilter = 0 OR EXISTS (SELECT 1 FROM #TempMatchGroup mgf WHERE (mgf.Setting = 'NORMAL' AND am.IsPenaltyMatch = 0 AND am.IsExtraTimeMatch = 0 AND am.IsHedgeMatch = 0) OR (mgf.Setting = 'PENALTY' AND AM.IsPenaltyMatch = 1) OR (mgf.Setting = 'EXTRA_TIME' AND AM.IsExtraTimeMatch = 1) OR (mgf.Setting = 'HEDGE' AND am.IsHedgeMatch = 1)))
	GROUP BY P.LeagueId, L.LeagueName, L.LeagueGroupID, P.IsLive
	ORDER BY Margin DESC, LeagueName ASC;
	
    DROP TABLE IF EXISTS #AllMatches;
    DROP TABLE IF EXISTS #TempVRSettings;
    DROP TABLE IF EXISTS #TempMatchGroup;

END;

GO

/*<info serverAlias="DBTGRS-bodb_TGRS" executers="wsv_tgrs" isFunction="0" isNested="0"></info>*/