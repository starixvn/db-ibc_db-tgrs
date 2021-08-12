ALTER PROCEDURE [dbo].[TGRS_Rpt_PerformanceDetail_Bettype_Trader]  	
			@FromDate			DATE
		,	@ToDate				DATE
		,	@LeagueName			NVARCHAR(500)= ''
		,	@LeagueGroupIds		VARCHAR(2000) = ''
		,	@Bettype			SMALLINT
		,	@IsExcludeLeagues	BIT = 1
		,	@Market				SMALLINT = 1
AS    
/*  
	Created:	20160329@Thai.Tran
	Task :		Detail report - Trader detail from Bet Type
	DB:		DBTGRS.bodb_TGRS
	Original:  
 
	Revisions:      	
		- 20171205@Simon:		get only Live data & Bettypes are not disabled
		- 20180912@Simon:		add league exclusion
		- 20190919@Long.Luu:	Support Nonlive Data [Redmine ID: 118959]
		- 20191023@John.Ngo:	Enhance performance [Redmine ID: 121268]
		- 20200710@John.Ngo:	Performance Detail - Support filter by league group [Redmine ID: 137276]
		- 20200909@John.Ngo:	Performance Detail - Bettype - Support filter by LeagueName [Redmine ID: 141294]
		- 202100809@Adam.Tran: 	Sports - Performance Real Figures [Redmine: #158981]
	Param's Explanation:  
		- @Market: -1 All; 0 Nonlive; 1 Live 	

	Exam: 
		exec [TGRS_Rpt_PerformanceDetail_Bettype_Trader] @Bettype=3,@FromDate='2016-03-02 00:00:00',@ToDate='2016-03-16 00:00:00'
*/  
 
BEGIN 
	SET NOCOUNT ON;

	IF	OBJECT_ID('tempdb..#tmp8RMPerformance') IS NOT NULL
	BEGIN
		DROP TABLE	#tmp8RMPerformance;
	END;
	
	CREATE TABLE	#tmp8RMPerformance (
			CustID				INT	
		,	IsLive				BIT
		,	TurnoverReal		MONEY
		,	WinLossReal			MONEY
		,	MarginReal			MONEY
		,	PRIMARY KEY CLUSTERED (
				CustID			ASC
			,	IsLive			ASC
		)
	);
	
	DECLARE @LeagueGroups AS TABLE (LeagueGroupId SMALLINT PRIMARY KEY CLUSTERED)
	IF @LeagueGroupIds <> ''
	BEGIN
		INSERT INTO @LeagueGroups(LeagueGroupId)
		SELECT val 
		FROM dbo.strSplit_Key(@LeagueGroupIds,',');

		IF CHARINDEX('12', @LeagueGroupIds) > 0
		BEGIN
			DELETE FROM @LeagueGroups
			WHERE LeagueGroupId = 12;

			INSERT INTO @LeagueGroups(LeagueGroupId)
			SELECT DISTINCT l.LeagueGroupID
			FROM bodb02.dbo.league AS l WITH(NOLOCK)
			WHERE l.LeagueGroupID NOT IN (1,2,3,4,5,6,7,8,9,10,11);
		END;
	END;

	IF	OBJECT_ID('tempdb..#tmpTraderDetail') IS NOT NULL
	BEGIN
		DROP TABLE	#tmpTraderDetail;
	END;

	CREATE TABLE #tmpTraderDetail (
			CustID				INT
		,	TeamId				INT
		,	LeagueCount			INT				
		,	MatchCount			INT
		,	Turnover			MONEY
		,	WinLoss				MONEY
		,	WinLossScore		MONEY
		,	BetCount			INT
		,	Margin				MONEY
		,	TurnoverReal		MONEY
		,	WinLossReal			MONEY
		,	MarginReal			MONEY
		,	SumCategory			MONEY
		,	IsLive				BIT
	);	
	
	CREATE CLUSTERED INDEX #CIX_TraderDetailIdx ON #tmpTraderDetail (
			CustID			ASC
	); 

	IF (@LeagueName IS NULL OR @LeagueName = '')
		BEGIN
			INSERT INTO #tmp8RMPerformance(CustID
				,	IsLive
				,	TurnoverReal
				,	WinLossReal
				,	MarginReal)
			SELECT 	tp.CustId
				,	tp.IsLive
				,	ISNULL(SUM(tp.Stake_Real),0) 		AS TurnoverReal
				,	ISNULL(SUM(tp.WinLost_Real),0)		AS WinLossReal
				,	CASE WHEN ISNULL(SUM(tp.Stake_Real), 0) <> 0 THEN (ISNULL(SUM(tp.WinLost_Real), 0)) * 100/SUM(tp.Stake_Real) ELSE NULL END AS MarginReal
			FROM dbo.TraderPerformance AS tp WITH (NOLOCK)
				INNER JOIN bodb02.dbo.League AS L WITH (NOLOCK) ON tp.LeagueId = L.LeagueId
				LEFT JOIN @LeagueGroups AS lg ON L.LeagueGroupId = lg.LeagueGroupId
				LEFT JOIN dbo.TargetedMargin AS tm WITH (NOLOCK) ON	tm.BetType = tp.BetType	AND	tm.WorkShift = tp.WorkShift
				LEFT JOIN dbo.Benchmark_SpecialSetting AS s WITH (NOLOCK) ON s.Spread = tp.Spread AND s.Rate = tm.Rate
				LEFT JOIN dbo.LeagueExclusion le WITH(NOLOCK) ON tp.LeagueId = le.LeagueId
			WHERE	tp.Is8RM = 1
				AND	tp.EventDate BETWEEN @FromDate AND @ToDate		
				AND (@Market = -1 OR tp.IsLive = @Market)
				AND (@IsExcludeLeagues = 0 OR le.LeagueId IS NULL)
				AND (@LeagueGroupIds = '' OR lg.LeagueGroupId IS NOT NULL)
			GROUP BY tp.CustId, tp.IsLive;
		
			INSERT INTO #tmpTraderDetail (
					CustID
				,	IsLive
				,	LeagueCount
				,	MatchCount
				,	Turnover
				,	WinLoss
				,	WinLossScore
				,	BetCount
				,	Margin
				,	TurnoverReal
				,	WinLossReal
				,	MarginReal
				,	SumCategory
			)
			SELECT	tp.CustId																			AS CustId
				,	tp.IsLive																			AS IsLive
				,	COUNT(DISTINCT tp.LeagueId)															AS LeagueCount
				,	COUNT(DISTINCT tp.MatchId)															AS MatchCount
				,	ISNULL(SUM(tp.Stake), 0)															AS Turnover
				,	ISNULL(SUM(tp.WinLost), 0) - ISNULL(SUM(tp.Comm), 0)							    AS WinLoss		
				,	SUM( (tp.WinLost - tp.Comm) * CASE WHEN tp.Spread * tm.Rate IS NULL THEN 0 ELSE 1 END) 	AS WinLossScore	
				,	ISNULL(SUM(tp.BetCount), 0)															AS BetCount
				,	CASE   WHEN SUM(tp.Stake) = 0 THEN NULL
							ELSE (SUM(tp.WinLost) - SUM(tp.Comm)) * 100 / SUM(tp.Stake) END				AS Margin	
				,	ISNULL(SUM(tp.Stake_Real),0) 														AS TurnoverReal
				,	ISNULL(SUM(tp.WinLost_Real),0)														AS WinLossReal
				,	CASE WHEN ISNULL(SUM(tp.Stake_Real), 0) <> 0 THEN (ISNULL(SUM(tp.WinLost_Real), 0)) * 100/SUM(tp.Stake_Real) ELSE NULL END AS MarginReal
				,	ISNULL(SUM(tp.Stake * ISNULL(s.BenchMark, tp.Spread * tm.Rate)), 0) AS SumCategory
			FROM	dbo.TraderPerformance AS tp WITH (NOLOCK)
				INNER JOIN bodb02.dbo.League AS L WITH (NOLOCK) ON tp.LeagueId = L.LeagueId
				LEFT JOIN @LeagueGroups AS lg ON L.LeagueGroupId = lg.LeagueGroupId
				LEFT JOIN dbo.TargetedMargin AS tm WITH (NOLOCK) ON	tm.BetType = tp.BetType	AND	tm.WorkShift = tp.WorkShift
				LEFT JOIN dbo.Benchmark_SpecialSetting AS s WITH (NOLOCK) ON s.Spread = tp.Spread AND s.Rate = tm.Rate
				LEFT JOIN dbo.LeagueExclusion le WITH(NOLOCK) ON tp.LeagueId = le.LeagueId
			WHERE	tp.BetType = @Bettype
				AND	 tp.EventDate BETWEEN @FromDate AND @ToDate		
				AND (@Market = -1 OR tp.IsLive = @Market)
				AND (@IsExcludeLeagues = 0 OR le.LeagueId IS NULL)
				AND (@LeagueGroupIds = '' OR lg.LeagueGroupId IS NOT NULL)
			GROUP BY tp.CustId, tp.IsLive;
		END;
	ELSE
		BEGIN
			INSERT INTO #tmp8RMPerformance(CustID
				,	IsLive
				,	TurnoverReal
				,	WinLossReal
				,	MarginReal)
			SELECT 	tp.CustId
				,	tp.IsLive
				,	ISNULL(SUM(tp.Stake_Real),0) 		AS TurnoverReal
				,	ISNULL(SUM(tp.WinLost_Real),0)		AS WinLossReal
				,	CASE WHEN ISNULL(SUM(tp.Stake_Real), 0) <> 0 THEN (ISNULL(SUM(tp.WinLost_Real), 0)) * 100/SUM(tp.Stake_Real) ELSE NULL END AS MarginReal
			FROM dbo.TraderPerformance AS tp WITH (NOLOCK)
				INNER JOIN bodb02.dbo.League AS L WITH (NOLOCK) ON tp.LeagueId = L.LeagueId
				LEFT JOIN @LeagueGroups AS lg ON L.LeagueGroupId = lg.LeagueGroupId
				LEFT JOIN dbo.TargetedMargin AS tm WITH (NOLOCK) ON	tm.BetType = tp.BetType	AND	tm.WorkShift = tp.WorkShift
				LEFT JOIN dbo.Benchmark_SpecialSetting AS s WITH (NOLOCK) ON s.Spread = tp.Spread AND s.Rate = tm.Rate
				LEFT JOIN dbo.LeagueExclusion le WITH(NOLOCK) ON tp.LeagueId = le.LeagueId
			WHERE	tp.Is8RM = 1
				AND	tp.BetType = @Bettype
				AND	tp.EventDate BETWEEN @FromDate AND @ToDate
				AND L.LeagueName LIKE '%' + @LeagueName + '%'
				AND (@Market = -1 OR tp.IsLive = @Market)
				AND (@IsExcludeLeagues = 0 OR le.LeagueId IS NULL)
				AND (@LeagueGroupIds = '' OR lg.LeagueGroupId IS NOT NULL)
			GROUP BY tp.CustId, tp.IsLive;
			
			INSERT INTO #tmpTraderDetail (
					CustID
				,	IsLive
				,	LeagueCount
				,	MatchCount
				,	Turnover
				,	WinLoss
				,	WinLossScore
				,	BetCount
				,	Margin
				,	TurnoverReal
				,	WinLossReal
				,	MarginReal
				,	SumCategory
			)
			SELECT	tp.CustId																			AS CustId
				,	tp.IsLive																			AS IsLive
				,	COUNT(DISTINCT tp.LeagueId)															AS LeagueCount
				,	COUNT(DISTINCT tp.MatchId)															AS MatchCount
				,	ISNULL(SUM(tp.Stake), 0)															AS Turnover
				,	ISNULL(SUM(tp.WinLost), 0) - ISNULL(SUM(tp.Comm), 0)							    AS WinLoss		
				,	SUM( (tp.WinLost - tp.Comm) * CASE WHEN tp.Spread * tm.Rate IS NULL THEN 0 ELSE 1 END) 	AS WinLossScore	
				,	ISNULL(SUM(tp.BetCount), 0)															AS BetCount
				,	CASE   WHEN SUM(tp.Stake) = 0 THEN NULL
							ELSE (SUM(tp.WinLost) - SUM(tp.Comm)) * 100 / SUM(tp.Stake) END				AS Margin
				,	ISNULL(SUM(tp.Stake_Real),0) 														AS TurnoverReal
				,	ISNULL(SUM(tp.WinLost_Real),0) 														AS WinLossReal
				,	CASE WHEN ISNULL(SUM(tp.Stake_Real), 0) <> 0 THEN (ISNULL(SUM(tp.WinLost_Real), 0)) * 100/SUM(tp.Stake_Real) ELSE NULL END AS MarginReal							
				,	ISNULL(SUM(tp.Stake * ISNULL(s.BenchMark, tp.Spread * tm.Rate)), 0) AS SumCategory
			FROM	dbo.TraderPerformance AS tp WITH (NOLOCK)
				INNER JOIN bodb02.dbo.League AS L WITH (NOLOCK) ON tp.LeagueId = L.LeagueId
				LEFT JOIN @LeagueGroups AS lg ON L.LeagueGroupId = lg.LeagueGroupId
				LEFT JOIN dbo.TargetedMargin AS tm WITH (NOLOCK) ON	tm.BetType = tp.BetType	AND	tm.WorkShift = tp.WorkShift
				LEFT JOIN dbo.Benchmark_SpecialSetting AS s WITH (NOLOCK) ON s.Spread = tp.Spread AND s.Rate = tm.Rate
				LEFT JOIN dbo.LeagueExclusion le WITH(NOLOCK) ON tp.LeagueId = le.LeagueId
			WHERE	tp.BetType = @Bettype
					AND	 tp.EventDate BETWEEN @FromDate AND @ToDate
					AND L.LeagueName LIKE '%' + @LeagueName + '%'
					AND (@Market = -1 OR tp.IsLive = @Market)
					AND (@IsExcludeLeagues = 0 OR le.LeagueId IS NULL)
					AND (@LeagueGroupIds = '' OR lg.LeagueGroupId IS NOT NULL)
			GROUP BY tp.CustId, tp.IsLive;
		END;
	
	UPDATE P
	SET   P.TurnoverReal 	= P.TurnoverReal + r.TurnoverReal
		, P.WinLossReal 	= P.WinLossReal - r.WinLossReal	
		, P.MarginReal		= CASE WHEN ISNULL(P.TurnoverReal + r.TurnoverReal, 0) <> 0 THEN (ISNULL(P.WinLossReal - r.WinLossReal, 0)) * 100/(P.TurnoverReal + r.TurnoverReal) ELSE NULL END
	FROM #tmpTraderDetail AS P WITH(NOLOCK)
	INNER JOIN #tmp8RMPerformance AS r WITH(NOLOCK) ON  r.CustID = P.CustID
		AND r.IsLive = P.IsLive;
	
	SELECT	td.CustID
		,	t.Username
		,	t.Grade
		,	t.TeamId
		,	tm.TeamName
		,	td.LeagueCount
		,	td.MatchCount
		,	td.Turnover
		,	td.WinLoss
		,	td.BetCount
		,	td.Margin
		,	td.TurnoverReal
		,	td.WinLossReal
		,	td.MarginReal
		,	CASE WHEN td.SumCategory = 0 THEN NULL ELSE td.WinLossScore * 100 / td.SumCategory END AS Score
		,	td.IsLive
	FROM	#tmpTraderDetail AS td WITH (NOLOCK)
		INNER JOIN	dbo.Trader AS t WITH (NOLOCK) ON t.CustId = td.CustID
		INNER JOIN	dbo.Team AS tm WITH (NOLOCK) ON	t.TeamId = tm.TeamId		
	ORDER BY td.Margin DESC, t.Username ASC;
	
	DROP TABLE #tmpTraderDetail;
	DROP TABLE #tmp8RMPerformance;
END;

GO
/*<info serverAlias="DBTGRS-bodb_TGRS" executers="bodbTGRSNet" isFunction="0" isNested="0"></info>*/