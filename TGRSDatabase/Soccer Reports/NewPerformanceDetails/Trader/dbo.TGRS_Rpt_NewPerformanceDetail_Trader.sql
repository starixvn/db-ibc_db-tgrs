ALTER PROCEDURE [dbo].[TGRS_Rpt_NewPerformanceDetail_Trader] 
		@Username			VARCHAR(30) = ''
	,	@FromDate			DATE
	,	@ToDate				DATE
	,	@Bettypes			VARCHAR(200) = '1,3,7,8'
	,	@IsExcludeLeagues	BIT = 1
	,	@Market				SMALLINT = 1
AS
/*  
	Created:	20170106@Long.Luu
	Task :		New Performance Detail Report - Trader
	DB:			DBTGRS.bodb_TGRS
	Original:  
	 
	Revisions:
		- 20170316@Long.Luu:	apply TO's Leftover
		- 20171205@Simon:		get only Live data & Bettypes are not disabled
		- 20180912@Simon:		add league exclusion
		- 20190919@Long.Luu:	Support Nonlive Data [Redmine ID: 118959]
		- 20191023@John.Ngo:	Enhance performance [Redmine ID: 121268]
		- 20250916@Jaden.Tang: Use new table TraderJuicePerformance [Redmine ID: 237899]

	Param's Explanation:  
		- @Market: -1 All; 0 Nonlive; 1 Live	
	
	Example: 	
		EXECUTE	[TGRS_Rpt_NewPerformanceDetail_Trader] 
			@FromDate = '2013-01-01',	
			@ToDate= '2014-05-31',
			@Bettypes = '1,3,7,8',
			@@Username ='A';
*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @BettypeList TABLE (bettype SMALLINT);

	CREATE TABLE #TraderDetail (
			CustID				INT
		,	LeagueCount			INT
		,	MatchCount			INT
		,	Turnover			MONEY
		,	TurnoverJuice		MONEY
		,	Juice				MONEY
		,	WinLoss				MONEY
		,	WinLossScore		MONEY
		,	BetCount			INT
		,	SumCategory			MONEY
		,	IsLive				BIT
	);
	
	IF @Bettypes <> '0'
		INSERT INTO @BettypeList (bettype)
		SELECT bt.BetType
		FROM dbo.strSplit_Key(@Bettypes, ',') ssk			
			INNER JOIN dbo.BetType bt WITH (NOLOCK) ON bt.MainDBBetType = ssk.val;
	ELSE
		INSERT INTO @BettypeList (bettype)
		SELECT bt.BetType
		FROM dbo.BetType AS bt WITH (NOLOCK)
		WHERE bt.MainDBBetType IN (1, 3, 7, 8);

	INSERT INTO #TraderDetail (
			CustID
		,	IsLive
		,	LeagueCount
		,	MatchCount
		,	Turnover
		,	TurnoverJuice
		,	Juice
		,	WinLoss
		,	WinLossScore
		,	BetCount
		,	SumCategory
	)
	SELECT	tp.CustId
		,	tp.IsLive
		,	COUNT(DISTINCT tp.LeagueId) AS LeagueCount
		,	COUNT(DISTINCT tp.MatchId) AS MatchCount
		,	ISNULL(SUM(tp.StakeMYR), 0) AS Turnover
		,	ISNULL(SUM(tp.StakeMYRJuice), 0) AS TurnoverJuice
		,	ISNULL(SUM(tp.Juice), 0) AS Juice
		,	ISNULL(SUM(tp.WinLost), 0) - ISNULL(SUM(tp.Comm), 0) AS WinLoss
		,	SUM((tp.WinLost - tp.Comm) * CASE 
				WHEN tp.Spread * tm.Rate IS NULL
					THEN 0
				ELSE 1
				END) AS WinLossScore
		,	ISNULL(SUM(tp.BetCount), 0) AS BetCount
		,	ISNULL(SUM(tp.StakeMYR * ISNULL(s.BenchMark, tp.Spread * tm.Rate)), 0) AS SumCategory
	FROM dbo.TraderJuicePerformance AS tp WITH (NOLOCK)
		INNER JOIN dbo.Trader AS t WITH (NOLOCK) ON t.CustId = tp.CustId
		LEFT JOIN dbo.TargetedMargin AS tm WITH (NOLOCK) ON tm.BetType = tp.BetType
			AND tm.WorkShift = tp.WorkShift
		LEFT JOIN dbo.Benchmark_SpecialSetting AS s WITH (NOLOCK) ON s.Spread = tp.Spread
			AND s.Rate = tm.Rate
		LEFT JOIN dbo.LeagueExclusion le WITH(NOLOCK) ON tp.LeagueId = le.LeagueId
	WHERE tp.EventDate BETWEEN @FromDate AND @ToDate
		AND tp.BetType IN (SELECT bl.bettype FROM @BettypeList AS bl)
		AND (@Username IS NULL OR t.Username LIKE '%' + @Username + '%')
		AND (@Market = -1 OR tp.IsLive = @Market)
		AND (@IsExcludeLeagues = 0 OR le.LeagueId IS NULL)
	GROUP BY tp.CustId
		,	tp.IsLive;

	SELECT	td.CustId
		,	t.Username
		,	td.IsLive
		,	t.Grade
		,	t.TeamId
		,	tm.TeamName
		,	td.LeagueCount
		,	td.MatchCount
		,	td.Turnover
		,	td.TurnoverJuice
		,	td.Juice
		,	td.WinLoss
		,	td.BetCount
		,	CASE 
				WHEN td.SumCategory = 0
					THEN NULL
				ELSE td.WinLossScore * 100 / td.SumCategory
				END AS Score
	FROM #TraderDetail AS td WITH (NOLOCK)
		INNER JOIN dbo.Trader AS t WITH (NOLOCK) ON t.CustId = td.CustId
		INNER JOIN dbo.Team AS tm WITH (NOLOCK) ON t.TeamId = tm.TeamId;

	DROP TABLE #TraderDetail;
END;

GO
/*<info serverAlias="DBTGRS-bodb_TGRS" executers="wsv_tgrs" isFunction="0" isNested="0"></info>*/