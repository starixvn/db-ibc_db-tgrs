USE [bodb_TGRS]
GO

/****** Object:  StoredProcedure [dbo].[TGRS_Rpt_PerformanceDetail_Grade_Trader_Match_Bettype]    Script Date: 03/28/2016 16:22:36 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[TGRS_Rpt_PerformanceDetail_Grade_Trader_Match_Bettype]  	
	@FromDate	DATE,
	@ToDate		DATE,
	@CustId		INT,
	@MatchId	INT,
	@Bettypes	VARCHAR(200) =  '0'
AS    
/*  
 Created:	20160328@Aaron
 Task :		Detail report Grade Performance - Detail Bettype based on Trader and Match
 DB:		DBTGRS.bodb_TGRS
 Original:  
  
 Revisions:         				
 Param's Explanation:  	
	
 Exam: 
				
	exec [TGRS_Rpt_PerformanceDetail_Trader_Match_Bettype] @FromDate='2016-02-29 00:00:00',@ToDate='2016-02-29 00:00:00',@CustId=14228019,@MatchId=16990574,@Bettypes='0' 
*/  
 
BEGIN 
	 SET NOCOUNT ON
	   
	 DECLARE @BettypeList AS TABLE (bettype SMALLINT)
		IF @Bettypes <> '0'
		 INSERT INTO @BettypeList
		 SELECT val FROM dbo.strSplit_Key(@Bettypes,',')
		ELSE 
		 INSERT INTO @BettypeList
		 SELECT Bettype FROM dbo.Bettype WITH (NOLOCK)
		 		 
	CREATE TABLE #BettypeDetail (
					BetType				SMALLINT
				,	TypeName			NVARCHAR(100)
				,	Turnover			MONEY
				,	WinLoss				MONEY
				,	WinLossScore		MONEY
				,	BetCount			INT
				,	Margin				MONEY
				,	SumCategory			MONEY
				);

	
	INSERT INTO	#BettypeDetail (
					BetType
				,	TypeName				
				,	Turnover
				,	WinLoss
				,	WinLossScore
				,	BetCount
				,	Margin
				,	SumCategory
				)		 
	
	 SELECT	tp.BetType
		,	TN.TypeName		
		,	ISNULL(SUM(tp.Stake), 0)								AS Turnover
		,	ISNULL(SUM(tp.WinLost), 0) - ISNULL(SUM(tp.Comm), 0)	AS WinLoss		
		,	SUM( (tp.WinLost - tp.Comm) * CASE WHEN tp.Spread * tm.Rate IS NULL THEN 0 ELSE 1 END) 	AS WinLossScore	
		,	ISNULL(SUM(tp.BetCount), 0)								AS BetCount
		,	CASE	WHEN SUM(tp.Stake) = 0
					THEN NULL
					ELSE (SUM(tp.WinLost) - SUM(tp.Comm)) * 100 / SUM(tp.Stake)
			END														AS Margin		
		,   ISNULL(SUM(tp.Stake * ISNULL(s.BenchMark, tp.Spread * tm.Rate)), 0) AS SumCategory

	FROM		dbo.TraderPerformance AS tp WITH (NOLOCK)
	INNER JOIN	dbo.Trader AS t WITH (NOLOCK)
			ON	t.CustId = tp.CustId
	LEFT JOIN	dbo.TargetedMargin AS tm WITH (NOLOCK)
			ON	tm.BetType = tp.BetType
			AND	tm.WorkShift = tp.WorkShift	
	LEFT JOIN dbo.Benchmark_SpecialSetting AS s WITH (NOLOCK)
			ON	s.Spread = tp.Spread
			AND	s.Rate = tm.Rate
	LEFT JOIN dbo.BetType TN WITH (NOLOCK) ON TN.BetType = tp.BetType
	WHERE	tp.CustId = @CustId		
			AND tp.MatchId = @MatchId			
			AND tp.EventDate BETWEEN @FromDate AND @ToDate
			AND tp.BetType IN (SELECT bettype FROM @BettypeList)
	GROUP BY	tp.BetType, TN.TypeName		

	SELECT	bd.BetType
		,	bd.TypeName		
		,	bd.Turnover
		,	bd.WinLoss
		,	bd.BetCount
		,	bd.Margin
		,	CASE WHEN bd.SumCategory = 0 THEN NULL ELSE bd.WinLossScore * 100 / bd.SumCategory END AS Score
	FROM		#BettypeDetail AS bd		
	ORDER BY	bd.Margin DESC

	DROP TABLE #BettypeDetail;
END

/*
GO
GRANT EXECUTE ON [dbo].[TGRS_Rpt_PerformanceDetail_Grade_Trader_Match_Bettype] TO [bodbTGRSNet]
GO
GRANT VIEW DEFINITION ON [dbo].[TGRS_Rpt_PerformanceDetail_Grade_Trader_Match_Bettype] TO [bodbTGRSNet ]
GO
*/

GO

