ALTER PROCEDURE [dbo].[TGRS_Rpt_Detail_GradeHistory]  
	@CustId		 INT,
	@FromDate	 DATE,
	@ToDate		 DATE,
	@LeagueId	 INT = 0, 
	@Bettypes    VARCHAR(200) = '0'  
AS    
/*  
 Created:	20140523@Sophia
 Task :		Detail of grade History
 DB:		DBTGRS.bodb_TGRS
 Original:  
  
 Revisions:      
   			
 Param's Explanation:  
	 
 Exam: 

	 
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
		

	SELECT	H.Grade, H.BeginDate AS EffectiveDate
	FROM	dbo.TraderGrade_History H WITH (NOLOCK)			
 	WHERE	H.CustId = @CustId
	ORDER BY H.BeginDate


	SELECT  P.CustId, P.Grade, COUNT(MatchID) AS MatchCount, SUM(Betcount) as Betcount,
			SUM(Stake) AS Turnover, SUM(WinLost)-SUM(Comm) AS WinLost, CASE WHEN SUM(P.Stake) <> 0 THEN (SUM(P.WinLost)-SUM(P.Comm))/SUM(P.Stake) ELSE NULL END AS Margin
	FROM	dbo.TraderPerformance P WITH (NOLOCK) 
	WHERE	P.CustId = @CustId	
			AND P.EventDate BETWEEN @FromDate AND @ToDate
			AND P.LeagueId = CASE WHEN @LeagueId <> 0 THEN @LeagueId ELSE P.LeagueId END
			AND P.Bettype IN (SELECT Bettype FROM @BettypeList)							 						 					 							
	GROUP BY P.CustId, P.Grade 
	ORDER BY P.Grade

	 
END 
GO
GRANT EXECUTE ON [dbo].[TGRS_Rpt_Detail_GradeHistory] TO [bodbTGRSNet]
GO
 
