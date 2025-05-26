ALTER PROCEDURE [dbo].[TGRS_Rpt_PerformanceDetail_Team_League_Trader]
	@FromDate			DATE,
	@ToDate				DATE,
	@TeamId				SMALLINT,
	@LeagueId			INT,
	@Bettypes			VARCHAR(MAX) = '0',
	@IsExcludeLeagues	BIT = 1,
	@Market				SMALLINT = 1,
	@VRSettings			VARCHAR(100) = 'ALL', -- Comma-separated: "VR_PLUS", "NO_VR", "VR_MINUS", "ALL"
	@MatchGroup			VARCHAR(100) = 'ALL'  -- Comma-separated: "NORMAL", "EXTRA_TIME", "PENALTY", "ALL"
AS
/*
	 Created:	20162903@Simon
	 Task :		Detail report - League detail from Team
	 DB:		DBTGRS.bodb_TGRS
	 Original:

	 Revisions:
		- 20171205@Simon: get only Live data & Bettypes are not disabled
		- 20180912@Simon: add league exclusion
		- 20190919@Long.Luu:	Support Nonlive Data [Redmine ID: 118959]
		- 20191023@John.Ngo:	Enhance performance [Redmine ID: 121268]
		- 20210827@Adam.Tran: 	Sports - Performance Real Figures [Redmine: #158981]
		- 20250524@Jaden.Tang:	Support new filter VR Settings and Match Group [Redmine: #227903]

	 Param's Explanation:
		- @Market: -1 All; 0 Nonlive; 1 Live

	 Exam:
		  EXEC  TGRS_Rpt_PerformanceDetail_Team_League_Trader @FromDate = '2016/03/14', @ToDate= '2016/3/28', @TeamId = 5,@Bettypes = '5,1,3',@LeagueId = 1085

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
        PRIMARY KEY (matchid)
    );

    INSERT INTO #AllMatches (matchid, parentid, IsPenaltyMatch, IsExtraTimeMatch)
    SELECT 
        M.matchid, M.parentid,
        CASE 
            WHEN HT.teamname LIKE N'%(PEN)%' THEN 1
            ELSE 0 
        END AS IsPenaltyMatch,
        CASE 
            WHEN HT.teamname LIKE N'%(ET)%' THEN 1
            ELSE 0 
        END AS IsExtraTimeMatch
    FROM bodb02.dbo.Match M WITH (NOLOCK)
    LEFT JOIN bodb02.dbo.Team HT WITH (NOLOCK) ON M.homeid = HT.teamid AND HT.SportType = M.sporttype
    WHERE M.eventdate BETWEEN @FromDate AND @ToDate
      AND M.sporttype = 1
    OPTION (RECOMPILE);

    INSERT INTO #AllMatches (matchid, parentid, IsPenaltyMatch, IsExtraTimeMatch)
    SELECT 
        M14.matchid, M14.parentid,
        CASE 
            WHEN HT.teamname LIKE N'%(PEN)%' THEN 1
            ELSE 0 
        END AS IsPenaltyMatch,
        CASE 
            WHEN HT.teamname LIKE N'%(ET)%' THEN 1
            ELSE 0 
        END AS IsExtraTimeMatch
    FROM bodb02.dbo.Match14 M14 WITH (NOLOCK)
    LEFT JOIN bodb02.dbo.Team HT WITH (NOLOCK) ON M14.homeid = HT.teamid AND HT.SportType = M14.sporttype
    WHERE M14.eventdate BETWEEN @FromDate AND @ToDate
      AND NOT EXISTS (SELECT 1 FROM #AllMatches am WHERE am.matchid = M14.matchid)
      AND M14.sporttype = 1
    OPTION (RECOMPILE);

    INSERT INTO #AllMatches (matchid, parentid, IsPenaltyMatch, IsExtraTimeMatch)
    SELECT 
        MBK.matchid, MBK.parentid,
        CASE 
            WHEN HT.teamname LIKE N'%(PEN)%' THEN 1
            ELSE 0 
        END AS IsPenaltyMatch,
        CASE 
            WHEN HT.teamname LIKE N'%(ET)%' THEN 1
            ELSE 0 
        END AS IsExtraTimeMatch
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

	DECLARE @BettypeList TABLE(BetType SMALLINT);

	CREATE TABLE #TraderDetail (
			CustID			INT
		,	TeamId			INT
		,	MatchCount		INT
		,	Turnover		MONEY
		,	WinLoss			MONEY
		,	WinLossScore	MONEY		
		,	Margin			MONEY
		,	TurnoverReal	MONEY
		,	WinLossReal		MONEY	
		,	MarginReal		MONEY
		,	BetCount		INT
		,	SumCategory		MONEY
		,	IsLive			BIT
	);

	IF @Bettypes <> '0'
	INSERT INTO @BettypeList (BetType)
		SELECT ssk.val
		FROM dbo.strSplit_Key(@Bettypes, ',') ssk;
	ELSE
	INSERT INTO @BettypeList (BetType)
		SELECT bt.BetType
		FROM dbo.BetType AS bt WITH ( NOLOCK );

	INSERT INTO #TraderDetail (
			CustID
		,	IsLive
		,	MatchCount
		,	Turnover
		,	WinLoss
		,	WinLossScore		
		,	Margin
		,	TurnoverReal
		,	WinLossReal		
		,	MarginReal
		,	BetCount
		,	SumCategory
	)
	SELECT	tp.CustId                                                           AS CustId
		,	tp.IsLive															AS IsLive
		,	COUNT(DISTINCT RM.RootMatchID)                                      AS MatchCount
		,	ISNULL(SUM(tp.Stake), 0)                                            AS Turnover
		,	ISNULL(SUM(tp.WinLost), 0) - ISNULL(SUM(tp.Comm), 0)                AS WinLoss
		,	SUM((tp.WinLost - tp.Comm) * CASE WHEN tp.Spread * tm.Rate IS NULL THEN 0 ELSE 1 END)	AS WinLossScore		
		,	CASE WHEN SUM(tp.Stake) = 0 THEN NULL ELSE (SUM(tp.WinLost) - SUM(tp.Comm)) * 100 / SUM(tp.Stake) END     AS Margin
		,	ISNULL(SUM(tp.Stake_Real),0) 										AS TurnoverReal
		,	ISNULL(SUM(CASE WHEN tp.Is8RM = 0 THEN tp.WinLost_Real ELSE 0 END),0) 	AS WinLossReal
		,	CASE WHEN ISNULL(SUM(tp.Stake_Real),0) <> 0 THEN ISNULL(SUM(CASE WHEN tp.Is8RM = 0 THEN tp.WinLost_Real ELSE 0 END),0) * 100/ISNULL(SUM(tp.Stake_Real),0) ELSE NULL END 							   			   AS MarginReal
		,	ISNULL(SUM(tp.BetCount), 0)                                         AS BetCount
		,	ISNULL(SUM(tp.Stake * ISNULL(s.BenchMark, tp.Spread * tm.Rate)), 0) AS SumCategory
	FROM dbo.TraderPerformance AS tp WITH ( NOLOCK )
		LEFT JOIN dbo.TargetedMargin AS tm WITH (NOLOCK)
			ON tm.BetType = tp.BetType AND tm.WorkShift = tp.WorkShift
		LEFT JOIN dbo.Benchmark_SpecialSetting AS s WITH (NOLOCK)
			ON s.Spread = tp.Spread AND s.Rate = tm.Rate
		INNER JOIN dbo.Trader AS T WITH (NOLOCK) ON T.CustId = tp.CustId
		LEFT JOIN dbo.LeagueExclusion le WITH(NOLOCK) ON tp.LeagueId = le.LeagueId
		INNER JOIN #AllMatches M ON tp.MatchId = M.matchid
        LEFT JOIN #RootMatches RM ON tp.MatchId = RM.ChildMatchID
	WHERE tp.EventDate BETWEEN @FromDate AND @ToDate
		AND tp.BetType IN (SELECT bl.BetType FROM @BettypeList AS bl)
		AND tp.LeagueId = @LeagueId
		AND T.TeamId = @TeamId
		AND (@Market = -1 OR tp.IsLive = @Market)
		AND (@IsExcludeLeagues = 0 OR le.LeagueId IS NULL)
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
                WHERE (mgf.Setting = 'NORMAL' AND M.IsPenaltyMatch = 0 AND M.IsExtraTimeMatch = 0)
                   OR (mgf.Setting = 'PENALTY' AND M.IsPenaltyMatch = 1)
                   OR (mgf.Setting = 'EXTRA_TIME' AND M.IsExtraTimeMatch = 1)
            )
        )
	GROUP BY tp.CustId, tp.IsLive;

	SELECT	td.CustID
		,	t.Username
		,	t.Grade
		,	td.MatchCount
		,	td.Turnover
		,	td.WinLoss		
		,	td.Margin
		,	td.TurnoverReal
		,	td.WinLossReal
		,	td.MarginReal
		,	td.BetCount
		,	CASE WHEN td.SumCategory = 0 THEN NULL ELSE td.WinLossScore * 100 / td.SumCategory END AS Score
		,	td.IsLive
	FROM #TraderDetail AS td WITH (NOLOCK)
		INNER JOIN dbo.Trader AS t WITH (NOLOCK)
			ON t.CustId = td.CustID
		INNER JOIN dbo.Team AS tm WITH (NOLOCK)
			ON t.TeamId = tm.TeamId
	ORDER BY td.Margin DESC, t.Username ASC;

	DROP TABLE #TraderDetail;
    DROP TABLE IF EXISTS #AllMatches;
    DROP TABLE IF EXISTS #RootMatches;
    DROP TABLE IF EXISTS #TempVRSettings;
    DROP TABLE IF EXISTS #TempMatchGroup;
END;

GO
