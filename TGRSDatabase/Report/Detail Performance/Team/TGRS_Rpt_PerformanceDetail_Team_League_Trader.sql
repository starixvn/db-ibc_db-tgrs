/****** Object:  Stored Procedure dbo.TGRS_Rpt_PerformanceDetail_Team_League_Trader    Script Date: 4/1/2016 8:22:16 AM ******/
ALTER PROCEDURE [dbo].[TGRS_Rpt_PerformanceDetail_Team_League_Trader]
  @FromDate		DATE,
  @ToDate		DATE,
  @TeamId		SMALLINT,
  @LeagueId		INT,
  @Bettypes		VARCHAR(MAX) = '0',
  @IsExcludeLeagues	BIT = 1
AS
/*
 Created:	20162903@Simon
 Task :		Detail report - League detail from Team
 DB:		DBTGRS.bodb_TGRS
 Original:

 Revisions:
	- 20171205@Simon: get only Live data & Bettypes are not disabled
	- 20180912@Simon: add league exclusion

 Param's Explanation:

 Exam:
	  EXEC  TGRS_Rpt_PerformanceDetail_Team_League_Trader @FromDate = '2016/03/14', @ToDate= '2016/3/28', @TeamId = 5,@Bettypes = '5,1,3',@LeagueId = 1085

*/

BEGIN
	SET NOCOUNT ON;

	DECLARE @BettypeList TABLE(BetType SMALLINT);

	CREATE TABLE #TraderDetail (
			CustID			INT
		,	TeamId			INT
		,	MatchCount		INT
		,	Turnover		MONEY
		,	WinLoss			MONEY
		,	WinLossScore	MONEY
		,	BetCount		INT
		,	Margin			MONEY
		,	SumCategory		MONEY
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
		,	MatchCount
		,	Turnover
		,	WinLoss
		,	WinLossScore
		,	BetCount
		,	Margin
		,	SumCategory
	)
	SELECT
		tp.CustId                                                           AS CustId,
		COUNT(DISTINCT tp.MatchId)                                          AS MatchCount,
		ISNULL(SUM(tp.Stake), 0)                                            AS Turnover,
		ISNULL(SUM(tp.WinLost), 0) - ISNULL(SUM(tp.Comm), 0)                AS WinLoss,
		SUM((tp.WinLost - tp.Comm) * CASE WHEN tp.Spread * tm.Rate IS NULL
		THEN 0
									ELSE 1 END)                            AS WinLossScore,
		ISNULL(SUM(tp.BetCount), 0)                                         AS BetCount,
		CASE WHEN SUM(tp.Stake) = 0
		THEN NULL
		ELSE (SUM(tp.WinLost) - SUM(tp.Comm)) * 100 / SUM(tp.Stake) END     AS Margin,
		ISNULL(SUM(tp.Stake * ISNULL(s.BenchMark, tp.Spread * tm.Rate)), 0) AS SumCategory
	FROM dbo.TraderPerformance AS tp WITH ( NOLOCK )
		LEFT JOIN dbo.TargetedMargin AS tm WITH ( NOLOCK )
		ON tm.BetType = tp.BetType
			AND tm.WorkShift = tp.WorkShift
		LEFT JOIN dbo.Benchmark_SpecialSetting AS s WITH ( NOLOCK )
		ON s.Spread = tp.Spread
			AND s.Rate = tm.Rate
		INNER JOIN Trader T WITH ( NOLOCK ) ON T.CustId = tp.CustId
	WHERE tp.EventDate BETWEEN @FromDate AND @ToDate
		AND tp.BetType IN (SELECT bl.BetType
							FROM @BettypeList AS bl)
		AND tp.LeagueId = @LeagueId
		AND T.TeamId = @TeamId
		AND tp.IsLive  = 1
		AND (@IsExcludeLeagues = 0 OR (tp.LeagueId NOT IN (SELECT le.LeagueId FROM dbo.LeagueExclusion le WITH(NOLOCK) WHERE le.LeagueId = tp.LeagueId)))
	GROUP BY tp.CustId;

	SELECT
		td.CustID,
		t.Username,
		t.Grade,
		td.MatchCount,
		td.Turnover,
		td.WinLoss,
		td.BetCount,
		td.Margin,
		CASE WHEN td.SumCategory = 0
			THEN NULL
		ELSE td.WinLossScore * 100 / td.SumCategory END AS Score
	FROM #TraderDetail AS td
		INNER JOIN dbo.Trader AS t WITH ( NOLOCK )
			ON t.CustId = td.CustID
		INNER JOIN dbo.Team AS tm WITH ( NOLOCK )
			ON t.TeamId = tm.TeamId
	ORDER BY td.Margin DESC, t.Username ASC;

	DROP TABLE #TraderDetail;
END;

/*<info serverAlias="DBTGRS-bodb_TGRS" executers="bodbTGRSNet" isFunction="0" isNested="0"></info>*/