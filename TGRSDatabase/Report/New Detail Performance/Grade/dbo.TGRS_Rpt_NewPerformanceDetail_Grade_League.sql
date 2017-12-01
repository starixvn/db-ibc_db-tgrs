
/****** Object:  Stored Procedure dbo.TGRS_Rpt_NewPerformanceDetail_Grade_League    Script Date: 1/17/2017 11:20:00 AM ******/
/****** Object:  Stored Procedure dbo.TGRS_Rpt_PerformanceDetail_Grade_League    Script Date: 4/1/2016 8:22:16 AM ******/
CREATE PROCEDURE [dbo].[TGRS_Rpt_NewPerformanceDetail_Grade_League]  	
	@FromDate		DATE,
	@ToDate			DATE,
	@Grade			INT
AS    
/*  
 Created:	20160328@Aaron.Cao
 Task :		New Detail report - Grade -> League Performance
 DB:		DBTGRS.bodb_TGRS
 Original:  
 
 Revisions:      	
		- 20170316@Long: apply TO's Leftover
 
 Param's Explanation:  	

 Exam: 
	  EXEC  TGRS_Rpt_NewPerformanceDetail_Grade_League @FromDate = '2016-03-13', @ToDate= '2016-03-27', @Grade = 1
  
*/  
BEGIN
	SET NOCOUNT ON;

	SELECT P.LeagueId
		,L.LeagueName
		,ISNULL(COUNT(DISTINCT P.CustId), 0) AS TraderCount
		,ISNULL(COUNT(DISTINCT P.MatchId), 0) AS MatchCount
		,ISNULL(SUM(P.StakeMYR), 0) AS Turnover
		,ISNULL(SUM(P.StakeMYRJuice), 0) AS TurnoverJuice
		,ISNULL(SUM(P.Juice), 0) AS Juice
		,ISNULL(SUM(P.WinLost), 0) - ISNULL(SUM(P.Comm), 0) AS WinLoss
		,ISNULL(SUM(P.BetCount), 0) AS BetCount
	FROM dbo.TraderPerformance P WITH (NOLOCK)
	INNER JOIN bodb02.dbo.League L WITH (NOLOCK) ON P.LeagueId = L.LeagueId
	INNER JOIN dbo.Trader t WITH (NOLOCK) ON P.CustId = t.CustId
	LEFT JOIN dbo.BetType TN WITH (NOLOCK) ON TN.BetType = P.BetType
	WHERE t.Grade = @Grade
		AND P.EventDate BETWEEN @FromDate AND @ToDate
		AND TN.MainDBBetType IN (1,3,7,8)
		AND TN.[Disabled] = 0
		AND P.IsLive = 1
	GROUP BY P.LeagueId
		,L.LeagueName
END 

/*
GO
GRANT EXECUTE ON [dbo].[TGRS_Rpt_NewPerformanceDetail_Grade_League] TO [bodbTGRSNet]
GO
GRANT VIEW DEFINITION ON [dbo].[TGRS_Rpt_NewPerformanceDetail_Grade_League] TO [bodbTGRSNet ]
GO
*/