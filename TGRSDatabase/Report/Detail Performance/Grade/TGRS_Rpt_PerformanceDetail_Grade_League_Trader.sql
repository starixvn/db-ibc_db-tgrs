USE [bodb_TGRS]
GO

/****** Object:  StoredProcedure [dbo].[TGRS_Rpt_PerformanceDetail_Grade_League_Trader]    Script Date: 03/28/2016 17:39:31 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[TGRS_Rpt_PerformanceDetail_Grade_League_Trader]
	@FromDate		DATE,
	@ToDate			DATE,
	@Grade			INT,
	@LeagueId		INT,
	@Bettypes		VARCHAR(2000) =  '0'
AS    
/*  
	Created:	20160328@Aaron
	Task:		Detail report Grade Performance - Detail Trader by League
	DB:			DBTGRS.bodb_TGRS
	Original:  
	 
	Revisions:
	  	20171019@Simon: Change VARCHAR(200) to VARCHAR(2000)		
	Param's Explanation:  	
	
	Example: 
		EXEC [TGRS_Rpt_PerformanceDetail_Grade_League_Trader] @FromDate = '2016-03-13', @ToDate= '2016-03-27', @Grade = 1, @LeagueId = 1085
  
*/  
 
BEGIN 
   SET NOCOUNT ON;

   DECLARE @BettypeList TABLE (BetType SMALLINT);

   CREATE TABLE	#TraderDetail (
					CustID				INT
				,	TeamId				INT
				,	LeagueCount			INT
				,	MatchCount			INT
				,	Turnover			MONEY
				,	WinLoss				MONEY
				,	WinLossScore		MONEY
				,	BetCount			INT
				,	Margin				MONEY
				,	SumCategory			MONEY
				);
				
    IF @Bettypes <> '0'
	   INSERT INTO @BettypeList (BetType)
	   SELECT ssk.val
	   FROM	dbo.strSplit_Key(@Bettypes, ',') ssk;
    ELSE 
	   INSERT INTO @BettypeList (BetType)
	   SELECT bt.BetType 
	   FROM	dbo.BetType AS bt WITH (NOLOCK);
	   
    INSERT INTO #TraderDetail (
			 CustID
			 ,MatchCount
			 ,Turnover
			 ,WinLoss
			 ,WinLossScore
			 ,BetCount
			 ,Margin
			 ,SumCategory)
	SELECT	tp.CustId																			AS CustId
		,	COUNT(DISTINCT tp.MatchId)															AS MatchCount
		,	ISNULL(SUM(tp.Stake), 0)															AS Turnover
		,	ISNULL(SUM(tp.WinLost), 0) - ISNULL(SUM(tp.Comm), 0)							    AS WinLoss		
		,	SUM( (tp.WinLost - tp.Comm) * CASE WHEN tp.Spread * tm.Rate IS NULL THEN 0 ELSE 1 END) 	AS WinLossScore	
		,	ISNULL(SUM(tp.BetCount), 0)															AS BetCount
		,	CASE   WHEN SUM(tp.Stake) = 0 THEN NULL
				   ELSE (SUM(tp.WinLost) - SUM(tp.Comm)) * 100 / SUM(tp.Stake) END				AS Margin		
		,	ISNULL(SUM(tp.Stake * ISNULL(s.BenchMark, tp.Spread * tm.Rate)), 0) AS SumCategory
	FROM		dbo.TraderPerformance AS tp WITH (NOLOCK)
	INNER JOIN dbo.Trader AS t WITH (NOLOCK) ON tp.CustId = t.CustId
	LEFT JOIN	dbo.TargetedMargin AS tm WITH (NOLOCK)
			ON	tm.BetType = tp.BetType
			AND	tm.WorkShift = tp.WorkShift
	LEFT JOIN dbo.Benchmark_SpecialSetting AS s WITH (NOLOCK)
			ON	s.Spread = tp.Spread
			AND	s.Rate = tm.Rate
	WHERE	tp.EventDate BETWEEN @FromDate AND @ToDate
		AND	tp.BetType IN (SELECT bl.BetType FROM @BettypeList AS bl)
		AND t.Grade = @Grade
		AND tp.LeagueId = @LeagueId
	GROUP BY	tp.CustId;
	
	SELECT	  td.CustID
			 ,t.Username
			 ,t.Grade
			 ,t.TeamId
			 ,tm.TeamName
			 ,td.MatchCount
			 ,td.Turnover
			 ,td.WinLoss
			 ,td.BetCount
			 ,td.Margin
			 ,CASE WHEN td.SumCategory = 0 THEN NULL ELSE td.WinLossScore * 100 / td.SumCategory END AS Score
	FROM		#TraderDetail AS td
	INNER JOIN	dbo.Trader AS t WITH (NOLOCK)
			ON	t.CustId = td.CustID
	INNER JOIN	dbo.Team AS tm WITH (NOLOCK) 
			ON	t.TeamId = tm.TeamId
	ORDER BY	td.Margin DESC, t.Username ASC;
	
	DROP TABLE #TraderDetail;
END;

/*
GO
GRANT EXECUTE ON [dbo].[TGRS_Rpt_PerformanceDetail_Grade_League_Trader] TO [bodbTGRSNet]
GO
GRANT VIEW DEFINITION ON [dbo].[TGRS_Rpt_PerformanceDetail_Grade_League_Trader] TO [bodbTGRSNet ]
GO
*/


GO

