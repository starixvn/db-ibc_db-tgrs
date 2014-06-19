ALTER PROCEDURE [dbo].[TGRS_Rpt_DetailTeamPerformance]  
	@FromDate	DATE,
	@ToDate		DATE,
	@TeamIds	VARCHAR(200) =  '0',
	@TeamBMFrom MONEY = NULL,
	@TeamBMTo	MONEY = NULL,
	@Turnover	MONEY = NULL,
	@WinLost	MONEY = NULL,
	@MarginFrom	MONEY = NULL,
	@MarginTo   MONEY = NULL,  
	@Bettypes	VARCHAR(200) =  '0'
AS    
/*  
 Created:	20140523@Sophia
 Task :		Detail report Team Performance
 DB:		DBTGRS.bodb_TGRS
 Original:  
  
 Revisions:      
   			
 Param's Explanation: 	
	@TeamIds = '0' : All 			
	@Bettypes = '0': All

 Exam: 
	EXEC TGRS_Rpt_DetailTeamPerformance @FromDate = '2013-01-01', @ToDate= '2014-05-31',  @Bettypes = '0', @TeamIds = '18,13'

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

	 DECLARE @TeamList AS TABLE (TeamId SMALLINT)
	 IF @TeamIds <> '0'
		 INSERT INTO @TeamList
		 SELECT val FROM dbo.strSplit_Key(@TeamIds,',')
	 ELSE 
		 INSERT INTO @TeamList
		 SELECT TeamId FROM dbo.Team WITH (NOLOCK) 
	
		 	
	 SELECT	P.TeamId, T.TeamName,
			ISNULL(BT.Benchmark,0) AS TeamBenchmark,
			ISNULL(COUNT(DISTINCT P.CustId),0) AS TraderCount, 
			ISNULL(COUNT(DISTINCT P.LeagueId),0) AS LeagueCount, 
			ISNULL(COUNT(DISTINCT P.MatchId),0) AS MatchCount, 
			ISNULL(SUM(P.Stake),0) AS Turnover, 
			ISNULL(SUM(P.WinLost),0) - ISNULL(SUM (P.Comm),0) AS WinLost, 
			ISNULL(SUM (BetCount),0) AS BetCount,
			CASE WHEN ISNULL(SUM(P.Stake),0) <> 0 THEN (ISNULL(SUM(P.WinLost),0) - ISNULL(SUM(P.Comm),0)) * 100/ISNULL(SUM(P.Stake),0) ELSE NULL END AS Margin	
	 FROM	dbo.TraderPerformance P WITH (NOLOCK)
	 INNER JOIN dbo.Team T WITH (NOLOCK) 
			 ON T.TeamId = P.TeamId
	 LEFT JOIN dbo.Benchmark_Team BT WITH (NOLOCK)
			 ON BT.TeamId = P.TeamId
	 WHERE	P.EventDate BETWEEN @FromDate AND @ToDate			
			AND ISNULL(BT.Benchmark,0) >= CASE WHEN @TeamBMFrom IS NULL THEN ISNULL(BT.Benchmark,0) ELSE @TeamBMFrom END 
			AND ISNULL(BT.Benchmark,0) <= CASE WHEN @TeamBMTo IS NULL THEN ISNULL(BT.Benchmark,0) ELSE @TeamBMTo END 
			AND P.Bettype IN (SELECT Bettype FROM @BettypeList)
			AND P.TeamId IN (SELECT TeamId FROM @TeamList)			
	GROUP BY P.TeamId, ISNULL(BT.Benchmark,0), T.TeamName
	HAVING	(@Turnover IS NULL OR ISNULL(SUM(P.Stake),0) >= ISNULL(@Turnover,0))
			AND (@WinLost IS NULL OR ISNULL(SUM(P.WinLost),0) - ISNULL(SUM(P.Comm),0) >= ISNULL(@WinLost,0))
			AND CASE WHEN ISNULL(SUM(P.Stake),0) <> 0 
					 THEN (ISNULL(SUM(P.WinLost),0)- ISNULL(SUM(P.Comm),0))* 100 /ISNULL(SUM(P.Stake),0) 
					 ELSE 0 END 
				>= CASE WHEN @MarginFrom IS NULL 
						THEN CASE WHEN ISNULL(SUM(P.Stake),0) <> 0	
								  THEN (ISNULL(SUM(P.WinLost),0) - ISNULL(SUM(P.Comm),0)) * 100 /ISNULL(SUM(P.Stake),0)
								  ELSE 0 END 
						ELSE @MarginFrom END 
			AND CASE WHEN ISNULL(SUM(P.Stake),0) <> 0 
					 THEN (ISNULL(SUM(P.WinLost),0) - ISNULL(SUM(P.Comm),0)) * 100/ISNULL(SUM(P.Stake),0)
					 ELSE 0 END 
				<= CASE WHEN @MarginTo IS NULL 
						THEN CASE WHEN ISNULL(SUM(P.Stake),0) <> 0 
								  THEN (ISNULL(SUM(P.WinLost),0) - ISNULL(SUM(P.Comm),0)) * 100 /ISNULL(SUM(P.Stake),0)
								  ELSE 0 END 
						ELSE @MarginTo END 
	ORDER BY Margin DESC, TeamName ASC
	 
 

END 
GO
GRANT EXECUTE ON [dbo].[TGRS_Rpt_DetailTeamPerformance] TO [bodbTGRSNet]
GO

 