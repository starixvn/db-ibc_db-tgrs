
/****** Object:  Stored Procedure dbo.TGRS_Rpt_NewPerformanceDetail_BetType    Script Date: 1/17/2017 11:20:00 AM ******/

/****** Object:  Stored Procedure dbo.TGRS_Rpt_PerformanceDetail_BetType    Script Date: 2/24/2016 2:51:26 PM ******/
CREATE PROCEDURE [dbo].[TGRS_Rpt_NewPerformanceDetail_BetType] 
	 @FromDate DATE
	,@ToDate DATE
AS
/*  
 Created:	20170110@Aaron
 Task :		New Detail report - BetType Performance
 DB:		DBTGRS.bodb_TGRS
 Original:  
  
 Revisions: 	
		- 20170316@Long: apply TO's Leftover
		- 20171205@Simon: get only Live data & Bettypes are not disabled
   			
 Param's Explanation:  	

 Exam: 
	  	 EXEC  [TGRS_Rpt_NewPerformanceDetail_BetType] @FromDate = '2014-01-01', @ToDate= '2015-12-30' 
  
*/
BEGIN
	SET NOCOUNT ON;

	SELECT P.BetType
		,ISNULL(COUNT(DISTINCT P.CustId), 0) AS TraderCount
		,ISNULL(COUNT(DISTINCT P.LeagueId), 0) AS LeagueCount
		,ISNULL(COUNT(DISTINCT P.MatchId), 0) AS MatchCount
		,ISNULL(SUM(P.StakeMYR), 0) AS Turnover
		,ISNULL(SUM(P.StakeMYRJuice), 0) AS TurnoverJuice
		,ISNULL(SUM(P.Juice), 0) AS Juice
		,ISNULL(SUM(P.WinLost), 0) - ISNULL(SUM(P.Comm), 0) AS WinLoss
		,ISNULL(SUM(P.BetCount), 0) AS BetCount
	INTO #TraderPerformanceTemp
	FROM dbo.TraderPerformance P WITH (NOLOCK)
	WHERE P.EventDate BETWEEN @FromDate AND @ToDate
		AND P.IsLive = 1
	GROUP BY P.BetType;

	SELECT P.BetType
		,TN.TypeName
		,P.TraderCount
		,P.LeagueCount
		,P.MatchCount
		,P.Turnover
		,P.WinLoss
		,P.TurnoverJuice
		,P.Juice
		,P.BetCount
	FROM #TraderPerformanceTemp P
		LEFT JOIN dbo.BetType TN WITH (NOLOCK) ON TN.BetType = P.BetType
	WHERE TN.MainDBBetType IN (1,3,7,8)
		AND TN.[Disabled] = 0;

	DROP TABLE #TraderPerformanceTemp;
END

/*
GO
GRANT EXECUTE ON [dbo].[TGRS_Rpt_NewPerformanceDetail_BetType] TO [bodbTGRSNet]
GO
GRANT VIEW DEFINITION ON [dbo].[TGRS_Rpt_NewPerformanceDetail_BetType] TO [bodbTGRSNet ]
GO
*/