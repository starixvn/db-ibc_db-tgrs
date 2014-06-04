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
   EXEC TGRS_Rpt_Detail_TeamHistory @CustId = 772205, @FromDate='2013-07-14', @Todate= '2015-07-14'
	 
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

  
	SELECT  P.CustId, P.TeamId, T.TeamName, 
			TH.BeginDate AS TeamEffectiveDate, 
			ISNULL(COUNT(MatchID),0) AS MatchCount, 
			ISNULL(SUM(Betcount),0) as Betcount,
			ISNULL(SUM(Stake),0) AS Turnover, 
			ISNULL(SUM(WinLost),0) - ISNULL(SUM(Comm),0) AS WinLost,
			 CASE WHEN ISNULL(SUM(P.Stake),0) <> 0 THEN (ISNULL(SUM(P.WinLost),0) - ISNULL(SUM(P.Comm),0))/ISNULL(SUM(P.Stake),0) ELSE NULL END AS Margin
	FROM	TraderPerformance P WITH (NOLOCK) 
	LEFT JOIN dbo.TraderTeam_History TH WITH (NOLOCK)
			ON  P.EventDate BETWEEN ISNULL(TH.BeginDate,'1900-01-01') AND ISNULL(TH.EndDate,'9999-12-31')
				AND P.TeamId = TH.TeamId
				AND P.CustId = TH.CustId
	INNER JOIN Team T WITH (NOLOCK)
			ON T.TeamId = P.TeamId
	WHERE	P.CustId = @CustId	
			AND P.EventDate BETWEEN @FromDate AND @ToDate	
			AND P.LeagueId = CASE WHEN @LeagueId <> 0 THEN @LeagueId ELSE P.LeagueId END
			AND P.Bettype IN (SELECT Bettype FROM @BettypeList)							 						 					 							
	GROUP BY P.CustId, P.TeamId, T.TeamName, TH.BeginDate
	ORDER BY TH.BeginDate

	 
END 
GO
GRANT EXECUTE ON [dbo].[TGRS_Rpt_Detail_TeamHistory] TO [bodbTGRSNet]
GO

 