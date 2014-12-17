ALTER PROCEDURE [dbo].[TGRS_Rpt_DetailTeam_Bettype]  	
	@FromDate	DATE,
	@ToDate		DATE,
	@TeamId		SMALLINT,
	@CustId		INT,
	@MatchId    INT,
	@Bettypes	VARCHAR(200) =  '0'
AS    
/*  
 Created:	20140725@Sophia
 Task :		Detail report Team Performance - Detail Bettype 
 DB:		DBTGRS.bodb_TGRS
 Original:  
  
 Revisions:      
	- 20141209@Sophia: Calculate Score
   			
 Param's Explanation:  	

 Exam: 
	EXEC TGRS_Rpt_DetailTeam_Bettype @FromDate = '2014-01-01', @ToDate= '2014-05-30', @TeamId = 13 , @Bettypes = '0', @CustID =870512, @MatchId = 8994834
	 
  
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
		 
		 	
	 SELECT P.BetType, TN.TypeName,
			ISNULL(SUM(P.Stake),0) AS Turnover, 
			ISNULL(SUM(P.WinLost),0) - ISNULL(SUM(P.Comm),0) AS WinLost, 
			ISNULL(SUM(BetCount),0) as BetCount,
			CASE WHEN ISNULL(SUM(P.Stake),0) <> 0 THEN (ISNULL(SUM(P.WinLost),0)- ISNULL(SUM(P.Comm),0)) * 100/ISNULL(SUM(P.Stake),0) ELSE NULL END AS Margin,
			ISNULL(B.Benchmark, 0) * 100 AS Benchmark,
			(CASE WHEN ISNULL(SUM(P.Stake),0) <> 0 AND ISNULL(B.Benchmark, 0) <> 0 THEN ((ISNULL(SUM(P.WinLost),0) - ISNULL(SUM(P.Comm),0)) * 100 * 50 / ISNULL(SUM(P.Stake),0) )/ ISNULL(B.Benchmark, 0) ELSE NULL END) AS Score
	 FROM	dbo.TraderPerformance P WITH (NOLOCK)	
		LEFT JOIN dbo.Benchmark_BetType B WITH (NOLOCK)
				ON B.BetType = P.BetType
				   AND B.LeagueId = P.LeagueId
				   AND B.WorkShift = P.WorkShift					
	    LEFT JOIN dbo.BetType TN WITH (NOLOCK) 
				ON TN.BetType = P.BetType		 	 
	 WHERE	P.EventDate BETWEEN @FromDate AND @ToDate
			AND P.TeamId = @TeamId
			AND P.CustId = @CustId
			AND P.MatchId = @MatchId	
			AND P.Bettype IN (SELECT Bettype FROM @BettypeList)			
	GROUP BY P.BetType, TN.TypeName,P.WorkShift, ISNULL(B.Benchmark, 0)
	ORDER BY Margin DESC
	

	
END 
GO
GRANT EXECUTE ON [dbo].[TGRS_Rpt_DetailTeam_Bettype] TO [bodbTGRSNet]
GO

