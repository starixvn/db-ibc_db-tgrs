ALTER PROCEDURE [dbo].[TGRS_Rpt_DetailGradePerformance]  
	@FromDate	DATE,
	@ToDate		DATE,
	@Turnover	MONEY = NULL,
	@WinLost	MONEY = NULL,
	@MarginFrom	MONEY = NULL,
	@MarginTo   MONEY = NULL,  
	@Bettypes	VARCHAR(200) =  '0'
AS    
/*  
 Created:	20140523@Sophia
 Task :		Detail report Grade Performance
 DB:		DBTGRS.bodb_TGRS
 Original:  
  
 Revisions:      
   			
 Param's Explanation:  	

 Exam: 
	EXEC TGRS_Rpt_DetailGradePerformance @FromDate = '2013-01-01', @ToDate= '2014-05-31',  @Bettypes = '0'

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
	 
	
	 SELECT P.Grade,
			ISNULL(COUNT(DISTINCT P.CustId),0) AS TraderCount, 
			ISNULL(COUNT(DISTINCT P.LeagueId),0) AS LeagueCount,  
			ISNULL(COUNT(DISTINCT P.MatchId),0) AS MatchCount, 
			ISNULL(SUM(P.Stake),0) AS Turnover, 
			ISNULL(SUM(P.WinLost),0) - ISNULL(SUM (P.Comm),0) AS WinLost, 
			ISNULL(SUM(P.BetCount),0) as BetCount,
			CASE WHEN ISNULL(SUM(P.Stake),0) <> 0 THEN (ISNULL(SUM(P.WinLost),0) - ISNULL(SUM(P.Comm),0))/ISNULL(SUM(P.Stake),0) ELSE NULL END AS Margin	
	 FROM	dbo.TraderPerformance P WITH (NOLOCK)					    
	 WHERE	P.EventDate BETWEEN @FromDate AND @ToDate			
			AND P.Bettype IN (SELECT Bettype FROM @BettypeList)
	GROUP BY P.Grade
	HAVING  ISNULL(SUM(P.Stake),0) >= ISNULL(@Turnover,0)
			AND ISNULL(SUM(P.WinLost),0) - ISNULL(SUM (P.Comm),0) >= ISNULL(@WinLost,0)
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
	ORDER BY Margin DESC, Grade ASC
	 
 

END 
GO
GRANT EXECUTE ON [dbo].[TGRS_Rpt_DetailGradePerformance] TO [bodbTGRSNet]
GO

 