ALTER PROCEDURE [dbo].[TGRS_Rpt_DetailLeaguePerformance]  	
	@FromDate	 DATE,
	@ToDate		 DATE,
	@LeagueName  NVARCHAR(100)= '',
	@LeagueBMFrom MONEY = NULL,
	@LeagueBMTo MONEY = NULL,
	@Turnover	MONEY = NULL,
	@WinLost	MONEY = NULL,
	@MarginFrom	MONEY = NULL,
	@MarginTo   MONEY = NULL,
	@Bettypes	VARCHAR(200) =  '0'
AS    
/*  
 Created:	20140523@Sophia
 Task :		Detail report - League Performance
 DB:		DBTGRS.bodb_TGRS
 Original:  
  
 Revisions:      
   			
 Param's Explanation:  	

 Exam: 
	  EXEC  TGRS_Rpt_DetailLeaguePerformance @FromDate = '2014-01-01', @ToDate= '2014-05-30' 
  
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
		 
		 	
	 SELECT	P.LeagueId , L.LeagueName, 
			ISNULL(BL.Benchmark,0) AS LeagueBenchmark,
			ISNULL(COUNT(DISTINCT P.CustId),0) AS TraderCount, 
			ISNULL(COUNT(DISTINCT P.MatchId),0) AS MatchCount, 
			ISNULL(SUM(P.Stake),0) AS Turnover, 
			ISNULL(SUM(P.WinLost),0) - ISNULL(SUM (P.Comm),0) AS WinLost, 
			ISNULL(SUM (BetCount),0) AS BetCount,
			CASE WHEN ISNULL(SUM(P.Stake),0) <> 0 THEN (ISNULL(SUM(P.WinLost),0) - ISNULL(SUM(P.Comm),0))/ISNULL(SUM(P.Stake),0) ELSE NULL END AS Margin	
	 FROM	dbo.TraderPerformance P WITH (NOLOCK)
	 INNER JOIN bodb02.dbo.League L WITH (NOLOCK) 
			 ON P.LeagueId = L.LeagueId
	 LEFT JOIN dbo.Benchmark_League BL WITH (NOLOCK)
			 ON BL.LeagueId = P.LeagueId
	 WHERE	P.EventDate BETWEEN @FromDate AND @ToDate
			AND L.LeagueName LIKE '%'+@LeagueName+'%'
			AND ISNULL(BL.Benchmark,0) >= CASE WHEN @LeagueBMFrom IS NULL THEN ISNULL(BL.Benchmark,0) ELSE @LeagueBMFrom END 
			AND ISNULL(BL.Benchmark,0) <= CASE WHEN @LeagueBMTo IS NULL THEN ISNULL(BL.Benchmark,0) ELSE @LeagueBMTo END 
			AND P.Bettype IN (SELECT Bettype FROM @BettypeList)
	GROUP BY P.LeagueId , L.LeagueName, ISNULL(BL.Benchmark,0)
	HAVING	ISNULL(SUM(P.Stake),0) >= ISNULL(@Turnover,0)
			AND ISNULL(SUM(P.WinLost),0) - ISNULL(SUM(P.Comm),0) >= ISNULL(@WinLost,0)
			AND CASE WHEN ISNULL(SUM(P.Stake),0) <> 0 
					 THEN (ISNULL(SUM(P.WinLost),0)- ISNULL(SUM(P.Comm),0))/ISNULL(SUM(P.Stake),0) 
					 ELSE 0 END >=  CASE WHEN @MarginFrom IS NULL 
										 THEN CASE WHEN ISNULL(SUM(P.Stake),0) <> 0 THEN (ISNULL(SUM(P.WinLost),0) - ISNULL(SUM(P.Comm),0))/ISNULL(SUM(P.Stake),0) ELSE 0 END 
										 ELSE @MarginFrom END 
			AND CASE WHEN ISNULL(SUM(P.Stake),0) <> 0 
					 THEN (ISNULL(SUM(P.WinLost),0) - ISNULL(SUM(P.Comm),0))/ISNULL(SUM(P.Stake),0)
					 ELSE 0 END <=  CASE WHEN @MarginTo IS NULL 
									THEN CASE WHEN ISNULL(SUM(P.Stake),0) <> 0 THEN (ISNULL(SUM(P.WinLost),0) - ISNULL(SUM(P.Comm),0))/ISNULL(SUM(P.Stake),0) ELSE 0 END 
									ELSE @MarginTo END 
	ORDER BY L.LeagueName

END 

GO
GRANT EXECUTE ON [dbo].[TGRS_Rpt_DetailLeaguePerformance] TO [bodbTGRSNet]
GO

