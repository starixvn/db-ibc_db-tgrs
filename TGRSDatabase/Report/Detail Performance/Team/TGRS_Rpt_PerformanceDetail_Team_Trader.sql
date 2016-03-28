ALTER PROCEDURE [dbo].[TGRS_Rpt_PerformanceDetail_Team_Trader]
    @FromDate DATE,
    @ToDate   DATE,
    @TeamId   SMALLINT,
    @Bettypes VARCHAR(200) = '0'
AS
  /*
    Created:	20162803@Simon
    Task :		Performance Detail Report - Trader
    DB:			DBTGRS.bodb_TGRS
    Original:

    Revisions:

    Param's Explanation:

    Example:
      EXECUTE	TGRS_Rpt_PerformanceDetail_Trader
              @FromDate = '2013-01-01'
            ,	@ToDate= '2014-05-31'
            ,	@@TeamId = '0'
            ,	@Bettypes ='1'
  */
  BEGIN

    SET NOCOUNT ON;

    DECLARE @BettypeList TABLE(
    bettype SMALLINT
    );

    CREATE TABLE #TraderDetail (
      CustID       INT
      ,
      LeagueCount  INT
      ,
      MatchCount   INT
      ,
      Turnover     MONEY
      ,
      WinLoss      MONEY
      ,
      WinLossScore MONEY
      ,
      BetCount     INT
      ,
      Margin       MONEY
      ,
      SumCategory  MONEY
    );

    IF @Bettypes <> '0'
      INSERT INTO @BettypeList
      (bettype)
        SELECT ssk.val
        FROM dbo.strSplit_Key(@Bettypes, ',') ssk;
    ELSE
      INSERT INTO @BettypeList
      (bettype)
        SELECT bt.BetType
        FROM dbo.BetType AS bt WITH ( NOLOCK );

    INSERT INTO #TraderDetail (
      CustID
      , LeagueCount
      , MatchCount
      , Turnover
      , WinLoss
      , WinLossScore
      , BetCount
      , Margin
      , SumCategory
    )
      SELECT
        tp.CustId,
        COUNT(DISTINCT tp.LeagueId)                                         AS LeagueCount,
        COUNT(DISTINCT tp.MatchId)                                          AS MatchCount,
        ISNULL(SUM(tp.Stake), 0)                                            AS Turnover,
        ISNULL(SUM(tp.WinLost), 0) - ISNULL(SUM(tp.Comm), 0)                AS WinLoss,
        SUM((tp.WinLost - tp.Comm) * CASE WHEN tp.Spread * tm.Rate IS NULL
          THEN 0
                                     ELSE 1 END)                            AS WinLossScore,
        ISNULL(SUM(tp.BetCount), 0)                                         AS BetCount,
        CASE WHEN SUM(tp.Stake) = 0
          THEN NULL
        ELSE (SUM(tp.WinLost) - SUM(tp.Comm)) * 100 / SUM(tp.Stake)
        END                                                                 AS Margin,
        ISNULL(SUM(tp.Stake * ISNULL(s.BenchMark, tp.Spread * tm.Rate)), 0) AS SumCategory
      FROM dbo.TraderPerformance AS tp WITH ( NOLOCK )
        INNER JOIN dbo.Trader AS t WITH ( NOLOCK )
          ON t.CustId = tp.CustId
        LEFT JOIN dbo.TargetedMargin AS tm WITH ( NOLOCK )
          ON tm.BetType = tp.BetType
             AND tm.WorkShift = tp.WorkShift
        LEFT JOIN dbo.Benchmark_SpecialSetting AS s WITH ( NOLOCK )
          ON s.Spread = tp.Spread
             AND s.Rate = tm.Rate
      WHERE tp.EventDate BETWEEN @FromDate AND @ToDate
            AND tp.BetType IN (SELECT bl.bettype
                               FROM @BettypeList AS bl)
            AND tp.TeamId = @TeamId
      GROUP BY tp.CustId;

    SELECT
      td.CustId,
      t.Username,
      t.Grade,
      td.LeagueCount,
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
        ON t.CustId = td.CustId
      INNER JOIN dbo.Team AS tm WITH ( NOLOCK )
        ON t.TeamId = tm.TeamId
    ORDER BY td.Margin DESC
      , t.Username ASC;

    DROP TABLE #TraderDetail;
  END;
GO