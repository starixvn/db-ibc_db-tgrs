ALTER PROCEDURE [dbo].[TGRS_Rpt_NewPerformanceDetail_Trader_Match_Bettype] 
		@FromDate			DATE
	,	@ToDate				DATE
	,	@CustId				INT
	,	@MatchId			INT
	,	@Bettypes			VARCHAR(200) = '1,3,7,8'
	,	@IsExcludeLeagues	BIT = 1
	,	@Market				SMALLINT = 1
AS
/*  
	Created:    20170106@Long.Luu
	Task:       New Performance Detail Report - Trader - Match - Bettype
	DB:			DBTGRS.bodb_TGRS
	Original:  

	Revisions:       
		- 20170316@Long.Luu:	apply TO's Leftover
		- 20171205@Simon:		get only Live data & Bettypes are not disabled
		- 20180912@Simon:		add league exclusion
		- 20190919@Long.Luu:	Support Nonlive Data [Redmine ID: 118959]
		  				
	Param's Explanation:  
		- @Market: -1 All; 0 Nonlive; 1 Live	

	Exam:				
		EXECUTE [TGRS_Rpt_PerformanceDetail_Trader_Match_Bettype] 
			@FromDate='2016-02-29 00:00:00',
			@ToDate='2016-02-29 00:00:00',
			@CustId=14228019,
			@MatchId=16990574,
			@Bettypes='1,3,7,8';
*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @BettypeList AS TABLE (bettype SMALLINT);

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

	CREATE TABLE #BettypeDetail (
			BetType				SMALLINT
		,	TypeName			NVARCHAR(100)
		,	Turnover			MONEY
		,	TurnoverJuice		MONEY
		,	Juice				MONEY
		,	WinLoss				MONEY
		,	WinLossScore		MONEY
		,	BetCount			INT
		,	SumCategory			MONEY
		,	IsLive				BIT
	);

	INSERT INTO #BettypeDetail (
			BetType
		,	TypeName
		,	IsLive
		,	Turnover
		,	TurnoverJuice
		,	Juice
		,	WinLoss
		,	WinLossScore
		,	BetCount
		,	SumCategory
	)
	SELECT	tp.BetType
		,	bt.TypeName
		,	tp.IsLive
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
	FROM dbo.TraderPerformance AS tp WITH (NOLOCK)
		INNER JOIN dbo.Trader AS t WITH (NOLOCK) ON t.CustId = tp.CustId
		LEFT JOIN dbo.TargetedMargin AS tm WITH (NOLOCK) ON tm.BetType = tp.BetType AND tm.WorkShift = tp.WorkShift
		LEFT JOIN dbo.Benchmark_SpecialSetting AS s WITH (NOLOCK) ON s.Spread = tp.Spread AND s.Rate = tm.Rate
		LEFT JOIN dbo.BetType AS bt WITH (NOLOCK) ON bt.BetType = tp.BetType
	WHERE tp.CustId = @CustId
		AND tp.MatchId = @MatchId
		AND tp.EventDate BETWEEN @FromDate AND @ToDate
		AND tp.BetType IN (SELECT bettype FROM @BettypeList)
		AND (@Market = -1 OR tp.IsLive = @Market)
		AND bt.[Disabled] = 0
		AND (@IsExcludeLeagues = 0 OR (tp.LeagueId NOT IN (SELECT le.LeagueId FROM dbo.LeagueExclusion AS le WITH(NOLOCK))))
	GROUP BY tp.BetType
		,	bt.TypeName
		,	tp.IsLive;

	SELECT	bd.BetType
		,	bd.TypeName
		,	bd.IsLive
		,	bd.Turnover
		,	bd.TurnoverJuice
		,	bd.Juice
		,	bd.WinLoss
		,	bd.BetCount
		,	CASE 
				WHEN bd.SumCategory = 0
					THEN NULL
				ELSE bd.WinLossScore * 100 / bd.SumCategory
				END AS Score
	FROM #BettypeDetail AS bd WITH(NOLOCK);

	DROP TABLE #BettypeDetail;
END;

GO
/*<info serverAlias="DBTGRS-bodb_TGRS" executers="bodbTGRSNet" isFunction="0" isNested="0"></info>*/