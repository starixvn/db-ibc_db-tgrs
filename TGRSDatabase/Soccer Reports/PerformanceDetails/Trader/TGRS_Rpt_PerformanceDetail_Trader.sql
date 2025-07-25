ALTER PROCEDURE [dbo].[TGRS_Rpt_PerformanceDetail_Trader]  	
		@Username			VARCHAR(30) = ''
	,	@FromDate			DATE
	,	@ToDate				DATE
	,	@LeagueGroupIds		VARCHAR(2000) = ''
	,	@Bettypes			VARCHAR(2000) =  '0'
	,	@IsExcludeLeagues	BIT = 1
	,	@Market				SMALLINT = 1
	,   @VRSettings         VARCHAR(100) = 'ALL' -- Comma-separated: "VR_PLUS", "NO_VR", "VR_MINUS", "ALL"
	,   @MatchGroup         VARCHAR(100) = 'ALL' -- Comma-separated: "NORMAL", "EXTRA_TIME", "PENALTY", "HEDGE", "ALL"
AS    
/*  
	Created:	20160217@Billy
	Task :		Performance Detail Report - Trader
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
		- 20200714@John.Ngo:	Performance Detail - Support filter by league group [Redmine ID: 137276]
		- 20210824@Adam.Tran: 	Sports - Performance Real Figures [Redmine: #158981]
		- 20220222@John.Ngo:	Separate League Group for Virtual and SABA PinGoal [Redmine: #161859]
		- 20250523@Jaden.Tang:	Support new filter VR Settings and Match Group [Redmine: #227903]
		
	Param's Explanation:  
		- @Market: -1 All; 0 Nonlive; 1 Live	
	
	Example: 	
		EXECUTE	TGRS_Rpt_PerformanceDetail_Trader @FromDate = '2013-01-01',	@ToDate= '2014-05-31', @Bettypes = '0',	@username ='A'
*/ 
BEGIN 
	
	SET NOCOUNT ON;  
	
	CREATE TABLE #TempLeagueGroupIDs (ID SMALLINT PRIMARY KEY);
    IF @LeagueGroupIds IS NOT NULL
    BEGIN
        INSERT INTO #TempLeagueGroupIDs (ID)
        SELECT DISTINCT TRY_CAST(value AS SMALLINT)
        FROM STRING_SPLIT(@LeagueGroupIds, ',')
        WHERE TRY_CAST(value AS SMALLINT) IS NOT NULL;	
    END

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
    WHERE M.eventdate BETWEEN CAST(@FromDate AS DATETIME) AND CAST(@ToDate AS DATETIME)
      AND M.sporttype = 1
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
    WHERE M14.eventdate BETWEEN CAST(@FromDate AS DATETIME) AND CAST(@ToDate AS DATETIME)
      AND NOT EXISTS (SELECT 1 FROM #AllMatches am WHERE am.matchid = M14.matchid)
      AND M14.sporttype = 1
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
    WHERE MBK.eventdate BETWEEN CAST(@FromDate AS DATETIME) AND CAST(@ToDate AS DATETIME)
      AND NOT EXISTS (SELECT 1 FROM #AllMatches am WHERE am.matchid = MBK.matchid)
      AND MBK.sporttype = 1
    OPTION (RECOMPILE);

	DECLARE	@BettypeList	TABLE (
			bettype				SMALLINT
	);

	IF	OBJECT_ID('tempdb..#TraderDetail') IS NOT NULL
	BEGIN
		DROP TABLE	#TraderDetail;
	END;

	CREATE TABLE #TraderDetail (
			CustID				INT
		,	LeagueCount			INT
		,	MatchCount			INT
		,	Turnover			MONEY
		,	WinLoss				MONEY
		,	WinLossScore		MONEY
		,	Margin				MONEY
		,	TurnoverReal		MONEY
		,	WinLossReal			MONEY	
		,	MarginReal			MONEY
		,	BetCount			INT		
		,	SumCategory			MONEY
		,	IsLive				BIT
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
	
	INSERT INTO	#TraderDetail (
			CustID
		,	IsLive
		,	LeagueCount
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
	SELECT	tp.CustId
		,	tp.IsLive
		,	COUNT(DISTINCT tp.LeagueId)								AS LeagueCount
		,	COUNT(DISTINCT tp.MatchId)								AS MatchCount
		,	ISNULL(SUM(tp.Stake), 0)								AS Turnover
		,	ISNULL(SUM(tp.WinLost), 0) - ISNULL(SUM(tp.Comm), 0)	AS WinLoss		
		,	SUM( (tp.WinLost - tp.Comm) * CASE WHEN tp.Spread * tm.Rate IS NULL THEN 0 ELSE 1 END) 	AS WinLossScore			
		,	CASE	WHEN SUM(tp.Stake) = 0 THEN NULL ELSE (SUM(tp.WinLost) - SUM(tp.Comm)) * 100 / SUM(tp.Stake) END		AS Margin
		,	ISNULL(SUM(tp.Stake_Real),0) 							AS TurnoverReal
		,	ISNULL(SUM(CASE WHEN tp.Is8RM = 0 THEN tp.WinLost_Real ELSE 0 END),0) 	AS WinLossReal
		,	CASE WHEN ISNULL(SUM(tp.Stake_Real),0) <> 0 THEN ISNULL(SUM(CASE WHEN tp.Is8RM = 0 THEN tp.WinLost_Real ELSE 0 END),0) * 100/ISNULL(SUM(tp.Stake_Real),0) ELSE NULL END 	AS MarginReal
		,	ISNULL(SUM(tp.BetCount), 0)												AS BetCount
		,	ISNULL(SUM(tp.Stake * ISNULL(s.BenchMark, tp.Spread * tm.Rate)), 0) 	AS SumCategory
	FROM	dbo.TraderPerformance AS tp WITH (NOLOCK)
		INNER JOIN	dbo.Trader AS t WITH (NOLOCK) ON t.CustId = tp.CustId
		INNER JOIN bodb02.dbo.League AS L WITH ( NOLOCK ) ON tp.LeagueId = L.LeagueId
		LEFT JOIN	dbo.TargetedMargin AS tm WITH (NOLOCK) ON tm.BetType = tp.BetType AND tm.WorkShift = tp.WorkShift
		LEFT JOIN dbo.Benchmark_SpecialSetting AS s WITH (NOLOCK) ON s.Spread = tp.Spread AND s.Rate = tm.Rate
		LEFT JOIN dbo.LeagueExclusion le WITH(NOLOCK) ON tp.LeagueId = le.LeagueId
		INNER JOIN #AllMatches am WITH (NOLOCK) ON tp.MatchId = am.matchid
	WHERE	tp.EventDate BETWEEN @FromDate AND @ToDate
		AND	tp.BetType IN (SELECT bl.bettype FROM @BettypeList AS bl)
		AND	t.Username LIKE '%' + @Username + '%'
		AND (@Market = -1 OR tp.IsLive = @Market)
		AND (@IsExcludeLeagues = 0 OR le.LeagueId IS NULL)
		AND (@LeagueGroupIds = '' OR L.LeagueGroupId IN (SELECT ID FROM #TempLeagueGroupIDs))
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
					   OR (mgf.Setting = 'PENALTY' AND am.IsPenaltyMatch = 1)
					   OR (mgf.Setting = 'EXTRA_TIME' AND am.IsExtraTimeMatch = 1)
					   OR (mgf.Setting = 'HEDGE' AND am.IsHedgeMatch = 1)
				)
			)
	GROUP BY tp.CustId, tp.IsLive;

	SELECT	td.CustId
		,	t.Username
		,	t.Grade
		,	t.TeamId
		,	tm.TeamName
		,	td.LeagueCount
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
	FROM		#TraderDetail AS td WITH (NOLOCK)
		INNER JOIN	dbo.Trader AS t WITH (NOLOCK) ON t.CustId = td.CustId
		INNER JOIN	dbo.Team AS tm WITH (NOLOCK) ON	t.TeamId = tm.TeamId
	ORDER BY td.Margin DESC
		,	t.Username ASC;

	DROP TABLE #TraderDetail;
    DROP TABLE IF EXISTS #AllMatches;
    DROP TABLE IF EXISTS #TempVRSettings;
    DROP TABLE IF EXISTS #TempMatchGroup;
END;

GO

/*<info serverAlias="DBTGRS-bodb_TGRS" executers="wsv_tgrs" isFunction="0" isNested="0"></info>*/
