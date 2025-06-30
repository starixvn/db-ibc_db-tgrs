ALTER PROCEDURE [dbo].[TGRS_Rpt_PerformanceDetail_Trader_Match_Bettype]  	
		@FromDate			DATE
	,	@ToDate				DATE
	,	@LeagueGroupIds		VARCHAR(2000) = ''
	,	@CustId				INT
	,	@MatchId			INT
	,	@Bettypes			VARCHAR(2000) =  '0'
	,	@IsExcludeLeagues	BIT = 1
	,	@Market				SMALLINT = 1
	,   @VRSettings         VARCHAR(100) = 'ALL' -- Comma-separated: "VR_PLUS", "NO_VR", "VR_MINUS", "ALL"
	,   @MatchGroup         VARCHAR(100) = 'ALL' -- Comma-separated: "NORMAL", "EXTRA_TIME", "PENALTY", "HEDGE", "ALL"
AS    
/*  
 Created:	20161503@Aaron
 Task :		Detail report Trader Performance - Detail Bettype based on Trader and Match
 DB:		DBTGRS.bodb_TGRS
 Original:  
  
 Revisions:      
		- 20162103@Simon:		restore orgirinal temp table code
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

 Exam: 				
		EXEC [TGRS_Rpt_PerformanceDetail_Trader_Match_Bettype] @FromDate='2016-02-29 00:00:00',@ToDate='2016-02-29 00:00:00',@CustId=14228019,@MatchId=16990574,@Bettypes='0' 
*/  
 
BEGIN 
	SET NOCOUNT ON;

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
    
    -- Assuming that @MatchId is the only match we are interested in for this specific SP.
    -- We populate #AllMatches only with this @MatchId to apply the MatchGroup filter correctly.
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
    WHERE M.matchid = @MatchId AND M.sporttype = 1
	AND M.EventDate >= CAST(@FromDate AS DATETIME) AND M.EventDate <= CAST(@ToDate AS DATETIME)
    OPTION (RECOMPILE);

    IF NOT EXISTS (SELECT 1 FROM #AllMatches WHERE matchid = @MatchId)
    BEGIN
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
        WHERE M14.matchid = @MatchId AND M14.sporttype = 1
			AND M14.EventDate >= CAST(@FromDate AS DATETIME) AND M14.EventDate <= CAST(@ToDate AS DATETIME)
        OPTION (RECOMPILE);
    END

    IF NOT EXISTS (SELECT 1 FROM #AllMatches WHERE matchid = @MatchId)
    BEGIN
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
        WHERE MBK.matchid = @MatchId AND MBK.sporttype = 1
		AND MBK.EventDate >= CAST(@FromDate AS DATETIME) AND MBK.EventDate <= CAST(@ToDate AS DATETIME)
        OPTION (RECOMPILE);
    END

	DECLARE @BettypeList AS TABLE (bettype SMALLINT);

	IF @Bettypes <> '0'
		INSERT INTO @BettypeList
		SELECT val 
		FROM dbo.strSplit_Key(@Bettypes,',');
	ELSE 
		INSERT INTO @BettypeList
		SELECT Bettype 
		FROM dbo.Bettype WITH (NOLOCK);

	IF	OBJECT_ID('tempdb..#BettypeDetail') IS NOT NULL
	BEGIN
		DROP TABLE	#BettypeDetail;
	END;
		 		 
	CREATE TABLE #BettypeDetail (
			BetType				SMALLINT
		,	TypeName			NVARCHAR(100)
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
	
	INSERT INTO	#BettypeDetail (
			BetType
		,	TypeName	
		,	IsLive			
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
	SELECT	tp.BetType
		,	TN.TypeName	
		,	tp.IsLive	
		,	ISNULL(SUM(tp.Stake), 0)								AS Turnover
		,	ISNULL(SUM(tp.WinLost), 0) - ISNULL(SUM(tp.Comm), 0)	AS WinLoss		
		,	SUM( (tp.WinLost - tp.Comm) * CASE WHEN tp.Spread * tm.Rate IS NULL THEN 0 ELSE 1 END) 	AS WinLossScore
		,	CASE WHEN SUM(tp.Stake) = 0 THEN NULL ELSE (SUM(tp.WinLost) - SUM(tp.Comm)) * 100 / SUM(tp.Stake) END	AS Margin
		,	ISNULL(SUM(tp.Stake_Real),0) 	AS TurnoverReal
		,	ISNULL(SUM(CASE WHEN tp.Is8RM = 0 THEN tp.WinLost_Real ELSE 0 END),0) 	AS WinLossReal
		,	CASE WHEN ISNULL(SUM(tp.Stake_Real),0) <> 0 THEN ISNULL(SUM(CASE WHEN tp.Is8RM = 0 THEN tp.WinLost_Real ELSE 0 END),0) * 100/ISNULL(SUM(tp.Stake_Real),0) ELSE NULL END 		AS MarginReal
		,	ISNULL(SUM(tp.BetCount), 0)		 AS BetCount
		,   ISNULL(SUM(tp.Stake * ISNULL(s.BenchMark, tp.Spread * tm.Rate)), 0) AS SumCategory
	FROM	dbo.TraderPerformance AS tp WITH (NOLOCK)
		INNER JOIN	dbo.Trader AS t WITH (NOLOCK) ON t.CustId = tp.CustId
		INNER JOIN bodb02.dbo.League AS L WITH ( NOLOCK ) ON tp.LeagueId = L.LeagueId
		LEFT JOIN @LeagueGroups AS lg ON L.LeagueGroupId = lg.LeagueGroupId
		LEFT JOIN dbo.TargetedMargin AS tm WITH (NOLOCK) ON tm.BetType = tp.BetType AND tm.WorkShift = tp.WorkShift	
		LEFT JOIN dbo.Benchmark_SpecialSetting AS s WITH (NOLOCK) ON s.Spread = tp.Spread AND s.Rate = tm.Rate
		LEFT JOIN dbo.BetType AS TN WITH (NOLOCK) ON TN.BetType = tp.BetType
		LEFT JOIN dbo.LeagueExclusion le WITH(NOLOCK) ON tp.LeagueId = le.LeagueId
		INNER JOIN #AllMatches am WITH (NOLOCK) ON tp.MatchId = am.matchid
	WHERE	tp.CustId = @CustId	
		AND tp.MatchId = @MatchId			
		AND tp.EventDate BETWEEN @FromDate AND @ToDate
		AND tp.BetType IN (SELECT bettype FROM @BettypeList)
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
					   OR (mgf.Setting = 'PENALTY' AND am.IsPenaltyMatch = 1)
					   OR (mgf.Setting = 'EXTRA_TIME' AND am.IsExtraTimeMatch = 1)
					   OR (mgf.Setting = 'HEDGE' AND am.IsHedgeMatch = 1)
				)
			)
	GROUP BY tp.BetType, TN.TypeName, tp.IsLive;

	SELECT	bd.BetType
		,	bd.TypeName		
		,	bd.Turnover
		,	bd.WinLoss
		,	bd.Margin
		,	bd.TurnoverReal
		,	bd.WinLossReal
		,	bd.MarginReal
		,	bd.BetCount
		,	CASE WHEN bd.SumCategory = 0 THEN NULL ELSE bd.WinLossScore * 100 / bd.SumCategory END AS Score
		,	bd.IsLive
	FROM	#BettypeDetail AS bd WITH (NOLOCK)		
	ORDER BY bd.Margin DESC;

	DROP TABLE #BettypeDetail;
    DROP TABLE IF EXISTS #AllMatches;
    DROP TABLE IF EXISTS #TempVRSettings;
    DROP TABLE IF EXISTS #TempMatchGroup;
END;

GO

/*<info serverAlias="DBTGRS-bodb_TGRS" executers="wsv_tgrs" isFunction="0" isNested="0"></info>*/
