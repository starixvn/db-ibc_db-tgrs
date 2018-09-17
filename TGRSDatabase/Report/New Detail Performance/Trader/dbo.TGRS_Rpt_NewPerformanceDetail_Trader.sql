
/****** Object:  Stored Procedure dbo.TGRS_Rpt_NewPerformanceDetail_Trader    Script Date: 1/17/2017 11:20:01 AM ******/

/****** Object:  StoredProcedure [dbo].[TGRS_Rpt_NewPerformanceDetail_Trader]    Script Date: 01/06/2017 10:49:20 ******/
ALTER PROCEDURE [dbo].[TGRS_Rpt_NewPerformanceDetail_Trader] 
	@Username VARCHAR(30) = ''
	,@FromDate DATE
	,@ToDate DATE
	,@Bettypes VARCHAR(200) = '1,3,7,8'
	,@IsExcludeLeagues	BIT = 1
AS
/*  
	Created:	20170106@Long.Luu
	Task :		New Performance Detail Report - Trader
	DB:			DBTGRS.bodb_TGRS
	Original:  
	 
	Revisions:
		- 20170316@Long: apply TO's Leftover
		- 20171205@Simon: get only Live data & Bettypes are not disabled
		- 20180912@Simon: add league exclusion

	Param's Explanation:  	
	
	Example: 	
				EXECUTE	[TGRS_Rpt_NewPerformanceDetail_Trader] 
					@FromDate = '2013-01-01',	
					@ToDate= '2014-05-31',
					@Bettypes = '1,3,7,8',
					@@Username ='A'
*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @BettypeList TABLE (bettype SMALLINT);

	CREATE TABLE #TraderDetail (
		CustID				INT
		,LeagueCount		INT
		,MatchCount			INT
		,Turnover			MONEY
		,TurnoverJuice		MONEY
		,Juice				MONEY
		,WinLoss			MONEY
		,WinLossScore		MONEY
		,BetCount			INT
		,SumCategory		MONEY
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
		WHERE bt.MainDBBetType IN (1,3,7,8);

	INSERT INTO #TraderDetail (
		CustID
		,LeagueCount
		,MatchCount
		,Turnover
		,TurnoverJuice
		,Juice
		,WinLoss
		,WinLossScore
		,BetCount
		,SumCategory
	)
	SELECT tp.CustId
		,COUNT(DISTINCT tp.LeagueId) AS LeagueCount
		,COUNT(DISTINCT tp.MatchId) AS MatchCount
		,ISNULL(SUM(tp.StakeMYR), 0) AS Turnover
		,ISNULL(SUM(tp.StakeMYRJuice), 0) AS TurnoverJuice
		,ISNULL(SUM(tp.Juice), 0) AS Juice
		,ISNULL(SUM(tp.WinLost), 0) - ISNULL(SUM(tp.Comm), 0) AS WinLoss
		,SUM((tp.WinLost - tp.Comm) * CASE 
				WHEN tp.Spread * tm.Rate IS NULL
					THEN 0
				ELSE 1
				END) AS WinLossScore
		,ISNULL(SUM(tp.BetCount), 0) AS BetCount
		,ISNULL(SUM(tp.StakeMYR * ISNULL(s.BenchMark, tp.Spread * tm.Rate)), 0) AS SumCategory
	FROM dbo.TraderPerformance AS tp WITH (NOLOCK)
		INNER JOIN dbo.Trader AS t WITH (NOLOCK) ON t.CustId = tp.CustId
		LEFT JOIN dbo.TargetedMargin AS tm WITH (NOLOCK) ON tm.BetType = tp.BetType
			AND tm.WorkShift = tp.WorkShift
		LEFT JOIN dbo.Benchmark_SpecialSetting AS s WITH (NOLOCK) ON s.Spread = tp.Spread
			AND s.Rate = tm.Rate
	WHERE tp.EventDate BETWEEN @FromDate
			AND @ToDate
		AND tp.BetType IN (
			SELECT bl.bettype
			FROM @BettypeList AS bl
			)
		AND (@Username IS NULL OR t.Username LIKE '%' + @Username + '%')
		AND tp.IsLive = 1
		AND (@IsExcludeLeagues = 0 OR (tp.LeagueId NOT IN (SELECT le.LeagueId FROM dbo.LeagueExclusion le WITH(NOLOCK))))
	GROUP BY tp.CustId;

	SELECT td.CustId
		,t.Username
		,t.Grade
		,t.TeamId
		,tm.TeamName
		,td.LeagueCount
		,td.MatchCount
		,td.Turnover
		,td.TurnoverJuice
		,td.Juice
		,td.WinLoss
		,td.BetCount
		,CASE 
			WHEN td.SumCategory = 0
				THEN NULL
			ELSE td.WinLossScore * 100 / td.SumCategory
			END AS Score
	FROM #TraderDetail AS td
		INNER JOIN dbo.Trader AS t WITH (NOLOCK) ON t.CustId = td.CustId
		INNER JOIN dbo.Team AS tm WITH (NOLOCK) ON t.TeamId = tm.TeamId;

	DROP TABLE #TraderDetail;
END;
	/*
GO
GRANT EXECUTE ON [dbo].[TGRS_Rpt_NewPerformanceDetail_Trader] TO [bodbTGRSNet]
GO
GRANT VIEW DEFINITION ON [dbo].[TGRS_Rpt_NewPerformanceDetail_Trader] TO [bodbTGRSNet]
GO
*/

/*<info serverAlias="DBTGRS-bodb_TGRS" executers="bodbTGRSNet" isFunction="0" isNested="0"></info>*/