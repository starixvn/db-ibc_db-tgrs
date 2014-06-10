ALTER PROCEDURE [dbo].[TGRS_Rpt_DetailGrade_Match]  	
	@FromDate	DATE,
	@ToDate		DATE,
	@Grade		TINYINT,
	@CustId		INT,
	@Bettypes	VARCHAR(200) =  '0'
AS    
/*  
 Created:	20140523@Sophia
 Task :		Detail report Grade Performance - Detail Match 
 DB:		DBTGRS.bodb_TGRS
 Original:  
  
 Revisions:      
   			
 Param's Explanation:  	

 Exam: 
	EXEC TGRS_Rpt_DetailGrade_Match @FromDate = '2014-01-01', @ToDate= '2014-05-30', @Grade = 1 , @Bettypes = '0', @CustID =9286068
	 
  
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
		 
		 	
	 SELECT P.MatchId, P.LeagueId, P.HomeId, P.AwayId, P.EventDate,
			ISNULL(SUM(P.Stake),0) AS Turnover, 
			ISNULL(SUM(P.WinLost),0) - ISNULL(SUM(P.Comm),0) AS WinLost, 
			ISNULL(SUM(BetCount),0) as BetCount,
			CASE WHEN ISNULL(SUM(P.Stake),0) <> 0 THEN (ISNULL(SUM(P.WinLost),0)- ISNULL(SUM(P.Comm),0))/ISNULL(SUM(P.Stake),0) ELSE NULL END AS Margin	
	 FROM	dbo.TraderPerformance P WITH (NOLOCK)		 
	 WHERE	P.EventDate BETWEEN @FromDate AND @ToDate
			AND P.Grade = @Grade
			AND P.CustId = @CustId
			AND P.Bettype IN (SELECT Bettype FROM @BettypeList)
	GROUP BY P.MatchId, P.LeagueId,  P.HomeId, P.AwayId, P.EventDate
	ORDER BY LeagueId ASC, Margin DESC, P.EventDate ASC 
	

END 
GO
GRANT EXECUTE ON [dbo].[TGRS_Rpt_DetailGrade_Match] TO [bodbTGRSNet]
GO

