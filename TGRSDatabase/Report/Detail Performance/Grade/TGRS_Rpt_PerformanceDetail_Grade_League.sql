
CREATE PROCEDURE [dbo].[TGRS_Rpt_PerformanceDetail_Grade_League]  	
	@FromDate		DATE,
	@ToDate			DATE,
	@Grade			INT,
	@Bettypes		VARCHAR(2000) =  '0'
AS    
/*  
 Created:	20160328@Aaron.Cao
 Task :		Detail report - Grade -> League Performance
 DB:		DBTGRS.bodb_TGRS
 Original:  
 
 Revisions:      	
	20171019@Simon: Change VARCHAR(200) to VARCHAR(2000)
 Param's Explanation:  	

 Exam: 
	  EXEC  TGRS_Rpt_PerformanceDetail_Grade_League @FromDate = '2016-03-13', @ToDate= '2016-03-27', @Grade = 1
  
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
	
	SELECT P.LeagueId,
			L.LeagueName,
			ISNULL(COUNT(DISTINCT P.CustId),0) AS TraderCount, 
			ISNULL(COUNT(DISTINCT P.MatchId),0) AS MatchCount, 
			ISNULL(SUM(P.Stake),0) AS Turnover, 
			ISNULL(SUM(P.WinLost),0) - ISNULL(SUM (P.Comm),0) AS WinLoss, 
			ISNULL(SUM(P.BetCount),0) AS BetCount,
			CASE WHEN ISNULL(SUM(P.Stake),0) <> 0 THEN (ISNULL(SUM(P.WinLost),0) - ISNULL(SUM(P.Comm),0)) * 100/SUM(P.Stake) ELSE NULL END AS Margin		
	FROM dbo.TraderPerformance P WITH (NOLOCK)	 
	INNER JOIN bodb02.dbo.League L WITH (NOLOCK) ON P.LeagueId = L.LeagueId
	INNER JOIN dbo.Trader t WITH (NOLOCK) ON P.CustId = t.CustId
	WHERE	P.Bettype IN (SELECT bettype FROM @BettypeList)
			AND t.Grade = @Grade
			AND P.EventDate BETWEEN @FromDate AND @ToDate	
			AND P.IsLive = 1
	GROUP BY P.LeagueId, L.LeagueName 	
	ORDER BY Margin DESC, LeagueName ASC
END 

/*
GRANT EXECUTE ON [dbo].[TGRS_Rpt_PerformanceDetail_Grade_League] TO [bodbTGRSNet]
GRANT VIEW DEFINITION ON [dbo].[TGRS_Rpt_PerformanceDetail_Grade_League] TO [bodbTGRSNet ]
*/