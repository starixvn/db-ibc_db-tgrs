ALTER PROCEDURE dbo.TGRS_Rpt_PerformanceDetail_League_Trader_Match  	
		@FromDate			DATE
	,	@ToDate				DATE
	,	@LeagueId			INT
	,	@CustId				INT
	,	@Bettypes			VARCHAR(2000) =  '0'
	,	@IsExcludeLeagues	BIT = 1
	,	@Market				SMALLINT = 1
	,   @VRSettings         VARCHAR(100) = 'ALL' -- Comma-separated: "VR_PLUS", "NO_VR", "VR_MINUS", "ALL"
	,   @MatchGroup         VARCHAR(100) = 'ALL' -- Comma-separated: "NORMAL", "EXTRA_TIME", "PENALTY", "HEDGE", "ALL"
	,	@Sites				NVARCHAR(MAX) = ''
AS    
/*  
	Created:	20160229@Aaron
	Task:		Detail report League Performance - Detail Match
	DB:			DBTGRS.bodb_TGRS
	Original:      
	  			
	Revision: 
		- 20171205@Simon:		get only Live data & Bettypes are not disabled
		- 20180912@Simon:		add league exclusion
		- 20190919@Long.Luu:	Support Nonlive Data [Redmine ID: 118959]
		- 20191023@John.Ngo:	Enhance performance [Redmine ID: 121268]
		- 20210825@Adam.Tran: 	Sports - Performance Real Figures [Redmine: #158981]
		- 20250524@Jaden.Tang:	Support new filter VR Settings and Match Group [Redmine: #227903]
		- 20250707@Jaden.Tang:	Add Site (company) filter [Redmine: #235099]
	Param's Explanation:  	
		- @Market: -1 All; 0 Nonlive; 1 Live 
	
	Example: 
		EXEC [TGRS_Rpt_PerformanceDetail_League_Trader_Match] @FromDate = '2014-01-01', @ToDate= '2014-12-30', @LeagueId = 6394, @Bettypes = '0', @CustID = 1530768  
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

	DECLARE @SitesList AS TABLE (SiteId INT PRIMARY KEY CLUSTERED);
	IF @Sites <> ''
	BEGIN
		INSERT INTO @SitesList
		SELECT SiteId 
		FROM bodb02.dbo.site WITH (NOLOCK)
		WHERE [site] IN (SELECT DISTINCT [value] FROM string_split(@Sites,','));
	END;

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

    DECLARE @BettypeList TABLE (BetType SMALLINT);
				
    IF @Bettypes <> '0'
	   INSERT INTO @BettypeList (BetType)
	   SELECT ssk.val
	   FROM	dbo.strSplit_Key(@Bettypes, ',') ssk;
    ELSE 
	    INSERT INTO @BettypeList (BetType)
	    SELECT bt.BetType 
		FROM	dbo.BetType AS bt WITH (NOLOCK);
	   
    SELECT 	P.MatchId
		, 	P.HomeId
		, 	P.AwayId
		, 	P.EventDate
		, 	P.IsLive
		,	ISNULL(SUM(P.Stake), 0) 							AS Turnover
		, 	ISNULL(SUM(P.WinLost), 0) - ISNULL(SUM(P.Comm), 0) 	AS WinLoss		
		,	CASE WHEN ISNULL(SUM(P.Stake), 0) <> 0 THEN (ISNULL(SUM(P.WinLost), 0)- ISNULL(SUM(P.Comm), 0)) * 100/ISNULL(SUM(P.Stake), 0) ELSE NULL END AS Margin
		,	ISNULL(SUM(P.Stake_Real),0) 						AS TurnoverReal
		,	ISNULL(SUM(CASE WHEN P.Is8RM = 0 THEN P.WinLost_Real ELSE 0 END),0) 	AS WinLossReal
		,	CASE WHEN ISNULL(SUM(P.Stake_Real),0) <> 0 THEN ISNULL(SUM(CASE WHEN P.Is8RM = 0 THEN P.WinLost_Real ELSE 0 END),0) * 100/ISNULL(SUM(P.Stake_Real),0) ELSE NULL END								AS MarginReal
		, 	ISNULL(SUM(P.BetCount), 0) 							 AS BetCount
	 FROM	dbo.TraderPerformance AS P WITH (NOLOCK)
		LEFT JOIN dbo.LeagueExclusion le WITH(NOLOCK) ON P.LeagueId = le.LeagueId
		INNER JOIN #AllMatches AM ON P.MatchId = AM.matchid		 
	 WHERE	P.EventDate BETWEEN @FromDate AND @ToDate
			AND P.LeagueId = @LeagueId
			AND P.CustId = @CustId
			AND P.BetType IN (SELECT Bettype FROM @BettypeList)
			AND (@Market = -1 OR P.IsLive = @Market)
			AND (@IsExcludeLeagues = 0 OR le.LeagueId IS NULL)
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
	GROUP BY P.MatchId, P.HomeId, P.AwayId, P.EventDate, P.IsLive
	ORDER BY Margin DESC, P.EventDate ASC;

    DROP TABLE IF EXISTS #AllMatches;
    DROP TABLE IF EXISTS #TempVRSettings;
    DROP TABLE IF EXISTS #TempMatchGroup;
END;

GO
/*<info serverAlias="DBTGRS-bodb_TGRS" executers="wsv_tgrs" isFunction="0" isNested="0"></info>*/
