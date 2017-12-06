
/****** Object:  Stored Procedure dbo.TGRS_Rpt_NewPerformanceDetail_Grade_League_Trader_Match    Script Date: 1/17/2017 11:20:00 AM ******/

/****** Object:  Stored Procedure dbo.TGRS_Rpt_PerformanceDetail_League_Trader_Match    Script Date: 3/14/2016 3:58:14 AM ******/
/****** Object:  Stored Procedure dbo.TGRS_Rpt_PerformanceDetail_League_Trader_Match    Script Date: 3/8/2016 2:46:20 PM ******/
CREATE PROCEDURE [dbo].[TGRS_Rpt_NewPerformanceDetail_Grade_League_Trader_Match] 
	 @FromDate DATE
	,@ToDate DATE
	,@LeagueId INT
	,@CustId INT
AS
/*  
	Created:	20160229@Aaron
	Task:		New Detail report League Performance - Detail Match
	DB:			DBTGRS.bodb_TGRS
	Original:      
	  		
	Revisions:
		- 20170316@Long: apply TO's Leftover
		- 20171205@Simon: get only Live data & Bettypes are not disabled
			
	Param's Explanation:  	
	
	Example: 
		EXEC [TGRS_Rpt_NewPerformanceDetail_Grade_League_Trader_Match] @FromDate = '2014-01-01', @ToDate= '2014-12-30', @LeagueId = 6394, @CustID = 1530768
  
*/
BEGIN
	SET NOCOUNT ON;

	SELECT P.MatchId
		,P.HomeId
		,P.AwayId
		,P.EventDate
		,SUM(ISNULL(P.StakeMYR, 0)) AS Turnover
		,ISNULL(SUM(P.StakeMYRJuice), 0) AS TurnoverJuice
		,ISNULL(SUM(P.Juice), 0) AS Juice
		,SUM(ISNULL(P.WinLost, 0)) - SUM(ISNULL(P.Comm, 0)) AS WinLoss
		,SUM(ISNULL(P.BetCount, 0)) AS BetCount
	FROM dbo.TraderPerformance P WITH (NOLOCK)
	LEFT JOIN dbo.BetType TN WITH (NOLOCK) ON TN.BetType = P.BetType
	WHERE P.EventDate BETWEEN @FromDate AND @ToDate
		AND P.LeagueId = @LeagueId
		AND P.CustId = @CustId
		AND TN.MainDBBetType IN (1,3,7,8)
		AND TN.[Disabled] = 0
		AND P.IsLive = 1
	GROUP BY P.MatchId
		,P.HomeId
		,P.AwayId
		,P.EventDate;
END;

/*
GO
GRANT EXECUTE ON [dbo].[TGRS_Rpt_NewPerformanceDetail_Grade_League_Trader_Match] TO [bodbTGRSNet]
GO
GRANT VIEW DEFINITION ON [dbo].[TGRS_Rpt_NewPerformanceDetail_Grade_League_Trader_Match] TO [bodbTGRSNet ]
GO
*/