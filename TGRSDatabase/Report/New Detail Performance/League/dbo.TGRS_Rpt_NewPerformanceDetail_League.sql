
/****** Object:  Stored Procedure dbo.TGRS_Rpt_NewPerformanceDetail_League    Script Date: 1/17/2017 11:20:01 AM ******/

/****** Object:  Stored Procedure dbo.TGRS_Rpt_PerformanceDetail_League    Script Date: 2/24/2016 2:51:26 PM ******/
ALTER PROCEDURE [dbo].[TGRS_Rpt_NewPerformanceDetail_League] 
	 @FromDate DATE
	,@ToDate DATE
	,@LeagueName NVARCHAR(100) = ''
	,@IsExcludeLeagues	BIT = 1
AS
/*  
 Created:	20170105@Aaron
 Task :		Detail report - New League Performance
 DB:		DBTGRS.bodb_TGRS
 Original:  
 
 Revisions:      	
	- 20170316@Long: apply TO's Leftover
	- 20171205@Simon: get only Live data & Bettypes are not disabled
	- 20180912@Simon: add league exclusion
	
 Param's Explanation:  	

 Exam: 
	  	  EXEC  TGRS_Rpt_NewPerformanceDetail_League @FromDate = '2014-01-01', @ToDate= '2016-05-30' 
  
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
		,ISNULL(SUM(BetCount), 0) AS BetCount
	FROM dbo.TraderPerformance P WITH (NOLOCK)
	INNER JOIN bodb02.dbo.League L WITH (NOLOCK) ON P.LeagueId = L.LeagueId
	LEFT JOIN dbo.BetType TN WITH (NOLOCK) ON TN.BetType = P.BetType
	WHERE P.EventDate BETWEEN @FromDate AND @ToDate
		AND (ISNULL(@LeagueName, '') = '' OR L.LeagueName LIKE '%' + @LeagueName + '%')
		AND TN.MainDBBetType IN (1,3,7,8)
		AND P.IsLive = 1
		AND TN.[Disabled] = 0
		AND (@IsExcludeLeagues = 0 OR (P.LeagueId NOT IN (SELECT le.LeagueId FROM dbo.LeagueExclusion le WITH(NOLOCK))))
	GROUP BY P.LeagueId ,L.LeagueName
END

/*
GO
GRANT EXECUTE ON [dbo].[TGRS_Rpt_NewPerformanceDetail_League] TO [bodbTGRSNet]
GO
GRANT VIEW DEFINITION ON [dbo].[TGRS_Rpt_NewPerformanceDetail_League] TO [bodbTGRSNet ]
GO
*/

GO
/*<info serverAlias="DBTGRS-bodb_TGRS" executers="bodbTGRSNet" isFunction="0" isNested="0"></info>*/