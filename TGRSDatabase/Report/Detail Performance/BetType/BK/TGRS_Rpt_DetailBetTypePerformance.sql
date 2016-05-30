ALTER PROCEDURE [dbo].[TGRS_Rpt_DetailBetTypePerformance]
	@FromDate	 DATE,
	@ToDate		 DATE,
	@BetTypeBMFrom MONEY = NULL,
	@BetTypeBMTo MONEY = NULL,
	@Turnover	MONEY = NULL,
	@WinLost	MONEY = NULL,
	@MarginFrom	MONEY = NULL,
	@MarginTo   MONEY = NULL,
	@Bettypes	VARCHAR(200) =  '0'
AS    
/*  
 Created:	20140523@Sophia
 Task :		Detail report - BetType Performance
 DB:		DBTGRS.bodb_TGRS
 Original:  
  
 Revisions: 
	- 20140728@Sophia: Change Benchmark to percentage instead of decimal number		     
   			
 Param's Explanation:  	

 Exam: 
	  EXEC  TGRS_Rpt_DetailBetTypePerformance @FromDate = '2014-01-01', @ToDate= '2014-05-30' 
  
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
		 
		 	
	 SELECT	P.BetType, 
			TN.TypeName,
			ISNULL(COUNT(DISTINCT P.CustId),0) AS TraderCount, 
			ISNULL(COUNT(DISTINCT P.LeagueId),0) AS LeagueCount, 
			ISNULL(COUNT(DISTINCT P.MatchId),0) AS MatchCount, 
			ISNULL(SUM(P.Stake),0) AS Turnover, 
			ISNULL(SUM(P.WinLost),0) - ISNULL(SUM (P.Comm),0) AS WinLost, 
			ISNULL(SUM(P.BetCount),0) AS BetCount,
			CASE WHEN ISNULL(SUM(P.Stake),0) <> 0 THEN (ISNULL(SUM(P.WinLost),0) - ISNULL(SUM(P.Comm),0)) * 100/ISNULL(SUM(P.Stake),0) ELSE NULL END AS Margin	
	 FROM	dbo.TraderPerformance P WITH (NOLOCK)
	 LEFT JOIN dbo.Benchmark_BetType BT WITH (NOLOCK)
			 ON BT.LeagueId = P.LeagueId
				AND BT.BetType = P.BetType
				AND BT.WorkShift = P.WorkShift
	 LEFT JOIN dbo.BetType TN WITH (NOLOCK) ON
			  TN.BetType = P.BetType
	 WHERE	P.EventDate BETWEEN @FromDate AND @ToDate
			AND ISNULL(BT.Benchmark,0) * 100 >= CASE WHEN @BetTypeBMFrom IS NULL THEN ISNULL(BT.Benchmark,0) * 100 ELSE @BetTypeBMFrom END 
			AND ISNULL(BT.Benchmark,0) * 100 <= CASE WHEN @BetTypeBMTo IS NULL THEN ISNULL(BT.Benchmark,0) * 100 ELSE @BetTypeBMTo END 
			AND P.Bettype IN (SELECT Bettype FROM @BettypeList)
	GROUP BY P.BetType,TN.TypeName
	HAVING	(@Turnover IS NULL OR ISNULL(SUM(P.Stake),0) >= ISNULL(@Turnover,0))
			AND (@WinLost IS NULL OR ISNULL(SUM(P.WinLost),0) - ISNULL(SUM(P.Comm),0) >= ISNULL(@WinLost,0))
			AND CASE WHEN ISNULL(SUM(P.Stake),0) <> 0 
					 THEN (ISNULL(SUM(P.WinLost),0)- ISNULL(SUM(P.Comm),0)) *100 /ISNULL(SUM(P.Stake),0)
					 ELSE 0 END 
				>= CASE WHEN @MarginFrom IS NULL 
						THEN CASE WHEN ISNULL(SUM(P.Stake),0) <> 0 
							 THEN (ISNULL(SUM(P.WinLost),0) - ISNULL(SUM(P.Comm),0)) *100 /ISNULL(SUM(P.Stake),0)
							 ELSE 0 END 
						ELSE @MarginFrom END 
			AND CASE WHEN ISNULL(SUM(P.Stake),0) <> 0 
					 THEN (ISNULL(SUM(P.WinLost),0) - ISNULL(SUM(P.Comm),0)) *100 /ISNULL(SUM(P.Stake),0)
					 ELSE 0 END 
				<= CASE WHEN @MarginTo IS NULL 
						THEN CASE WHEN ISNULL(SUM(P.Stake),0) <> 0 
								  THEN (ISNULL(SUM(P.WinLost),0) - ISNULL(SUM(P.Comm),0)) *100 /ISNULL(SUM(P.Stake),0) 
								  ELSE 0 END 
						ELSE @MarginTo END 
	ORDER BY Margin DESC, P.Bettype ASC 

END 

GO
GRANT EXECUTE ON [dbo].[TGRS_Rpt_DetailBetTypePerformance] TO [bodbTGRSNet]
GO

