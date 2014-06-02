ALTER PROCEDURE [dbo].[TGRS_Rpt_Detail_TeamHistory]  
	@CustId		 INT,
	@FromDate	 DATE,
	@ToDate		 DATE,
	@LeagueId	 INT = 0, 
	@Bettypes    VARCHAR(200) = '0'    
AS    
/*  
 Created:	20140523@Sophia
 Task :		Detail of Team History
 DB:		DBTGRS.bodb_TGRS
 Original:  
  
 Revisions:      
   			
 Param's Explanation:  
	
 Exam: 
   EXEC TGRS_Rpt_Detail_TeamHistory @CustId = 772205, @FromDate='2013-07-14', @Todate= '2013-07-14'
	 
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


	SELECT	H.TeamId, T.TeamName, H.BeginDate AS EffectiveDate
	FROM	TraderTeam_History H WITH (NOLOCK)
	INNER JOIN Team T WITH (NOLOCK) 
	 		ON T.TeamId = H.TeamId			
 	WHERE	H.CustId = @CustId
	ORDER BY H.BeginDate


	SELECT  P.CustId, P.TeamId, T.TeamName, COUNT(MatchID) AS MatchCount, SUM(Betcount) as Betcount,
			SUM(Stake) AS Turnover, SUM(WinLost)-SUM(Comm) AS WinLost, CASE WHEN SUM(P.Stake) <> 0 THEN (SUM(P.WinLost)-SUM(P.Comm))/SUM(P.Stake) ELSE NULL END AS Margin
	FROM	TraderPerformance P WITH (NOLOCK) 
	INNER JOIn Team T WITH (NOLOCK)
			ON T.TeamId = P.TeamId
	WHERE	P.CustId = @CustId	
			AND P.EventDate BETWEEN @FromDate AND @ToDate	
			AND P.LeagueId = CASE WHEN @LeagueId <> 0 THEN @LeagueId ELSE P.LeagueId END
			AND P.Bettype IN (SELECT Bettype FROM @BettypeList)							 						 					 							
	GROUP BY P.CustId, P.TeamId, T.TeamName
	ORDER BY T.TeamName

	 
END 
GO
GRANT EXECUTE ON [dbo].[TGRS_Rpt_Detail_TeamHistory] TO [bodbTGRSNet]
GO

 