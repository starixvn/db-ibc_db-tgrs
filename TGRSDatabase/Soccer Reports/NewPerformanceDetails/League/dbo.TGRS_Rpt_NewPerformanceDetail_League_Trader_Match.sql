ALTER PROCEDURE [dbo].[TGRS_Rpt_NewPerformanceDetail_League_Trader_Match] 
		@FromDate			DATE
	,	@ToDate				DATE
	,	@LeagueId			INT
	,	@CustId				INT
	,	@IsExcludeLeagues	BIT = 1
	,	@Market				SMALLINT = 1
AS
/*  
	Created:	20160229@Aaron
	Task:		New Detail report League Performance - Detail Match
	DB:			DBTGRS.bodb_TGRS
	Original:      
	  			
	Revision:
		- 20171205@Simon:		get only Live data & Bettypes are not disabled
		- 20180912@Simon:		add league exclusion
		- 20190919@Long.Luu:	Support Nonlive Data [Redmine ID: 118959]
		- 20191023@John.Ngo:	Enhance performance [Redmine ID: 121268]

	Param's Explanation:  	
		- @Market: -1 All; 0 Nonlive; 1 Live
	
	Example: 
		EXEC [TGRS_Rpt_PerformanceDetail_League_Trader_Match] @FromDate = '2014-01-01', @ToDate= '2014-12-30', @LeagueId = 6394, @Bettypes = '0', @CustID = 1530768
  
*/
BEGIN
	SET NOCOUNT ON;

	SELECT	P.MatchId
		,	P.HomeId
		,	P.AwayId
		,	P.EventDate
		,	P.IsLive
		,	SUM(ISNULL(P.StakeMYR, 0)) AS Turnover		
		,	ISNULL(SUM(P.StakeMYRJuice), 0) AS TurnoverJuice
		,	ISNULL(SUM(P.Juice), 0) AS Juice
		,	SUM(ISNULL(P.WinLost, 0)) - SUM(ISNULL(P.Comm, 0)) AS WinLoss
		,	SUM(ISNULL(P.BetCount, 0)) AS BetCount
	FROM dbo.TraderPerformance AS P WITH (NOLOCK)
		LEFT JOIN dbo.BetType AS TN WITH (NOLOCK) ON TN.BetType = P.BetType
		LEFT JOIN dbo.LeagueExclusion le WITH(NOLOCK) ON P.LeagueId = le.LeagueId
	WHERE P.EventDate BETWEEN @FromDate AND @ToDate
		AND P.LeagueId = @LeagueId
		AND P.CustId = @CustId
		AND TN.MainDBBetType IN (1, 3, 7, 8)
		AND TN.[Disabled] = 0
		AND (@Market = -1 OR P.IsLive = @Market)
		AND (@IsExcludeLeagues = 0 OR le.LeagueId IS NULL)
	GROUP BY P.MatchId
		,	P.HomeId
		,	P.AwayId
		,	P.EventDate
		,	P.IsLive;
END;

GO
/*<info serverAlias="DBTGRS-bodb_TGRS" executers="bodbTGRSNet" isFunction="0" isNested="0"></info>*/