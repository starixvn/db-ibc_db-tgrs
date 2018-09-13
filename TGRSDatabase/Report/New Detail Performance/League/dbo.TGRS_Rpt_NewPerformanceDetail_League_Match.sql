
/****** Object:  Stored Procedure dbo.TGRS_Rpt_NewPerformanceDetail_League_Match    Script Date: 1/17/2017 11:20:01 AM ******/

/****** Object:  Stored Procedure dbo.TGRS_Rpt_PerformanceDetail_League_Match    Script Date: 4/1/2016 8:22:17 AM ******/
ALTER PROCEDURE [dbo].[TGRS_Rpt_NewPerformanceDetail_League_Match] 
	 @FromDate DATE
	,@ToDate DATE
	,@LeagueId INT
	,@IsExcludeLeagues	BIT = 1
AS
/*  
	Created:	20170106@Aaron
	TASk:		New Detail report League Performance - Detail Match
	DB:			DBTGRS.bodb_TGRS
	Original:      
				
	Revisions:         	
		- 20170316@Long: apply TO's Leftover
		- 20171205@Simon: get only Live data & Bettypes are not disabled
		- 20180912@Simon: add league exclusion
		
	Param's ExplanatiON:  	
	
	Example: 
		EXEC [TGRS_Rpt_PerformanceDetail_League_Match] @FROMDate = '2014-01-01', @ToDate= '2014-12-30', @Bettypes = '0', @LeagueId = 364
  
*/
BEGIN
	SET NOCOUNT ON;

	SELECT P.MatchId
		,P.HomeId
		,P.AwayId
		,P.EventDate
		,ISNULL(SUM(P.StakeMYR), 0) AS Turnover
		,ISNULL(SUM(P.StakeMYRJuice), 0) AS TurnoverJuice
		,ISNULL(SUM(P.Juice), 0) AS Juice
		,ISNULL(SUM(P.WinLost), 0) - ISNULL(SUM(P.Comm), 0) AS WinLoss
		,ISNULL(SUM(P.BetCount), 0) AS BetCount
	FROM dbo.TraderPerformance P WITH (NOLOCK)
	LEFT JOIN dbo.BetType TN WITH (NOLOCK) ON TN.BetType = P.BetType
	WHERE P.EventDate BETWEEN @FromDate AND @ToDate
		AND P.LeagueId = @LeagueId
		AND TN.MainDBBetType IN (1,3,7,8)
		AND TN.[Disabled] = 0
		AND P.IsLive = 1
		AND (@IsExcludeLeagues = 0 OR (P.LeagueId NOT IN (SELECT le.LeagueId FROM dbo.LeagueExclusion le WHERE le.LeagueId = P.LeagueId)))
	GROUP BY P.MatchId
		,P.HomeId
		,P.AwayId
		,P.EventDate
END

/*
GO
GRANT EXECUTE ON [dbo].[TGRS_Rpt_NewPerformanceDetail_League_Match] TO [bodbTGRSNet]
GO
GRANT VIEW DEFINITION ON [dbo].[TGRS_Rpt_NewPerformanceDetail_League_Match] TO [bodbTGRSNet ]
GO
*/
/*<info serverAlias="DBTGRS - bodb_TGRS" executers="bodbTGRSNet" isFunction="0" isNested="0"></info>*/