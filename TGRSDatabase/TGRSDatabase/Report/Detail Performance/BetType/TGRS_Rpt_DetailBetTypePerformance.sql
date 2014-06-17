ALTER PROCEDURE [dbo].[TGRS_Rpt_DetailBetTypePerformance]  	
	@FromDate	 DATE,
	@ToDate		 DATE,
	---@LeagueName  NVARCHAR(100)= '',
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
		 
		 	
	 SELECT	----P.LeagueId , L.LeagueName, 
			P.BetType, 
			ISNULL(BT.Benchmark,0) AS BetTypeBenchmark,
			ISNULL(COUNT(DISTINCT P.CustId),0) AS TraderCount, 
			ISNULL(COUNT(DISTINCT P.LeagueId),0) AS LeagueCount, 
			ISNULL(COUNT(DISTINCT P.MatchId),0) AS MatchCount, 
			ISNULL(SUM(P.Stake),0) AS Turnover, 
			ISNULL(SUM(P.WinLost),0) - ISNULL(SUM (P.Comm),0) AS WinLost, 
			ISNULL(SUM (BetCount),0) AS BetCount,
			CASE WHEN ISNULL(SUM(P.Stake),0) <> 0 THEN (ISNULL(SUM(P.WinLost),0) - ISNULL(SUM(P.Comm),0))/ISNULL(SUM(P.Stake),0) * 100 ELSE NULL END AS Margin	
	 FROM	dbo.TraderPerformance P WITH (NOLOCK)
	 --INNER JOIN bodb02.dbo.League L WITH (NOLOCK) 
		--	 ON P.LeagueId = L.LeagueId
	 LEFT JOIN dbo.Benchmark_BetType BT WITH (NOLOCK)
			 ON BT.LeagueId = P.LeagueId
				AND BT.BetType = P.BetType
	 WHERE	P.EventDate BETWEEN @FromDate AND @ToDate
			---AND L.LeagueName LIKE '%'+@LeagueName+'%'
			AND ISNULL(BT.Benchmark,0) >= CASE WHEN @BetTypeBMFrom IS NULL THEN ISNULL(BT.Benchmark,0) ELSE @BetTypeBMFrom END 
			AND ISNULL(BT.Benchmark,0) <= CASE WHEN @BetTypeBMTo IS NULL THEN ISNULL(BT.Benchmark,0) ELSE @BetTypeBMTo END 
			AND P.Bettype IN (SELECT Bettype FROM @BettypeList)
	---GROUP BY P.LeagueId , L.LeagueName, ISNULL(BT.Benchmark,0), P.BetType
	GROUP BY ISNULL(BT.Benchmark,0), P.BetType
	HAVING	ISNULL(SUM(P.Stake),0) >= ISNULL(@Turnover,0)
			AND ISNULL(SUM(P.WinLost),0) - ISNULL(SUM(P.Comm),0) >= ISNULL(@WinLost,0)
			AND CASE WHEN ISNULL(SUM(P.Stake),0) <> 0 
					 THEN (ISNULL(SUM(P.WinLost),0)- ISNULL(SUM(P.Comm),0))/ISNULL(SUM(P.Stake),0) * 100 
					 ELSE 0 END 
				>= CASE WHEN @MarginFrom IS NULL 
						THEN CASE WHEN ISNULL(SUM(P.Stake),0) <> 0 
							 THEN (ISNULL(SUM(P.WinLost),0) - ISNULL(SUM(P.Comm),0))/ISNULL(SUM(P.Stake),0) * 100 
							 ELSE 0 END 
						ELSE @MarginFrom END 
			AND CASE WHEN ISNULL(SUM(P.Stake),0) <> 0 
					 THEN (ISNULL(SUM(P.WinLost),0) - ISNULL(SUM(P.Comm),0))/ISNULL(SUM(P.Stake),0) * 100
					 ELSE 0 END 
				<= CASE WHEN @MarginTo IS NULL 
						THEN CASE WHEN ISNULL(SUM(P.Stake),0) <> 0 
								  THEN (ISNULL(SUM(P.WinLost),0) - ISNULL(SUM(P.Comm),0))/ISNULL(SUM(P.Stake),0) * 100 
								  ELSE 0 END 
						ELSE @MarginTo END 
	---ORDER BY Margin DESC,L.LeagueName ASC, P.Bettype ASC 
	ORDER BY Margin DESC, P.Bettype ASC 

END 

GO
GRANT EXECUTE ON [dbo].[TGRS_Rpt_DetailBetTypePerformance] TO [bodbTGRSNet]
GO

