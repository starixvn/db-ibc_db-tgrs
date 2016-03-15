USE [bodb_TGRS]
GO
/****** Object:  StoredProcedure [dbo].[TGRS_Rpt_PerformanceDetail_League]    Script Date: 3/15/2016 1:48:52 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[TGRS_Rpt_PerformanceDetail_Bettype_League_Trader]  	
	@FromDate		DATE,
	@ToDate			DATE,	
	@Turnover		MONEY = NULL,
	@WinLoss		MONEY = NULL,
	@MarginFrom		MONEY = NULL,
	@MarginTo		MONEY = NULL,
	@LeagueId		INT,
	@Bettypes		VARCHAR(200) =  '0'
AS    
/*  
 Created:	20160315@Thai.Tran
 Task :		Detail report - Trader detail from Bet Type and League
 DB:		DBTGRS.bodb_TGRS
 Original:  
 
 Revisions:      	
 
 Param's Explanation:  	

 Exam: 
	  EXEC  [TGRS_Rpt_PerformanceDetail_Bettype_League_Trader] @FromDate = '2014-01-01', @ToDate= '2014-05-30' , @LeagueId = 6394, @Bettypes = '0'
  
*/  
 
BEGIN 
	 SET NOCOUNT ON;

   DECLARE @BettypeList TABLE (BetType SMALLINT);

   CREATE TABLE	#TraderDetail (
					CustID				INT
				,	TeamId				INT
				,	MatchCount			INT
				,	Turnover			MONEY
				,	WinLoss				MONEY
				,	WinLostScore		MONEY
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
			 ,WinLostScore
			 ,BetCount
			 ,Margin
			 ,SumCategory)
	SELECT	tp.CustId																			AS CustId
		,	COUNT(DISTINCT tp.MatchId)															AS MatchCount
		,	ISNULL(SUM(tp.Stake), 0)															AS Turnover
		,	ISNULL(SUM(tp.WinLost), 0) - ISNULL(SUM(tp.Comm), 0)							    AS WinLoss		
		,	SUM( (tp.WinLost - tp.Comm) * CASE WHEN tp.Spread * tm.Rate IS NULL THEN 0 ELSE 1 END) 	AS WinLostScore	
		,	ISNULL(SUM(tp.BetCount), 0)															AS BetCount
		,	CASE   WHEN SUM(tp.Stake) = 0 THEN NULL
				   ELSE (SUM(tp.WinLost) - SUM(tp.Comm)) * 100 / SUM(tp.Stake) END				AS Margin		
		,	ISNULL(SUM(tp.Stake * ISNULL(s.BenchMark, tp.Spread * tm.Rate)), 0) AS SumCategory
	FROM		dbo.TraderPerformance AS tp WITH (NOLOCK)
	LEFT JOIN	dbo.TargetedMargin AS tm WITH (NOLOCK)
			ON	tm.BetType = tp.BetType
			AND	tm.WorkShift = tp.WorkShift
	LEFT JOIN dbo.Benchmark_SpecialSetting AS s WITH (NOLOCK)
			ON	s.Spread = tp.Spread
			AND	s.Rate = tm.Rate
	WHERE	tp.LeagueId = @LeagueId
			AND	 tp.EventDate BETWEEN @FromDate AND @ToDate
			AND	tp.BetType IN (SELECT bl.BetType FROM @BettypeList AS bl)		
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
			 ,CASE WHEN td.SumCategory = 0 THEN NULL ELSE td.WinLostScore * 100 / td.SumCategory END AS Score
	FROM		#TraderDetail AS td
	INNER JOIN	dbo.Trader AS t WITH (NOLOCK)
			ON	t.CustId = td.CustID
	INNER JOIN	dbo.Team AS tm WITH (NOLOCK) 
			ON	t.TeamId = tm.TeamId
	ORDER BY	td.Margin DESC, t.Username ASC;
	
	DROP TABLE #TraderDetail;
END 

--GRANT EXECUTE ON [dbo].[TGRS_Rpt_PerformanceDetail_Bettype_League_Trader] TO [bodbTGRSNet]
--GRANT VIEW DEFINITION ON [dbo].[TGRS_Rpt_PerformanceDetail_Bettype_League_Trader] TO [bodbTGRSNet ]