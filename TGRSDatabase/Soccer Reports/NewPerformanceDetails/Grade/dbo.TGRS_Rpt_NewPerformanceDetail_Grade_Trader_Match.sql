ALTER PROCEDURE [dbo].[TGRS_Rpt_NewPerformanceDetail_Grade_Trader_Match] 
		@FromDate				DATE
	,	@ToDate					DATE
	,	@CustId					INT
	,	@IsExcludeLeagues		BIT = 1
	,	@Market					SMALLINT = 1
AS
/*  
	Created:	20170109@Aaron
	Task:		New Detail report Grade Performance - Detail Match
	DB:			DBTGRS.bodb_TGRS
	Original:      
	  			
	Revisions:
		- 20170316@Long.Luu:	apply TO's Leftover
		- 20171205@Simon:		get only Live data & Bettypes are not disabled
		- 20180911@Long.Luu:	Support excluding Leagues from report [Redmine ID: #100322] 
		- 20190919@Long.Luu:	Support Nonlive Data [Redmine ID: 118959] 
		- 20191023@John.Ngo:	Enhance performance [Redmine ID: 121268]
		- 20250916@Jaden.Tang: Use new table TraderJuicePerformance [Redmine ID: 237899]
		
	Param's Explanation:  
		- @Market: -1 All; 0 Nonlive; 1 Live	
	
	Example: 
		EXEC [TGRS_Rpt_NewPerformanceDetail_Grade_Trader_Match] @FromDate = '2016-03-01', @ToDate= '2016-12-30', @CustID = 2457
  
*/
BEGIN
	SET NOCOUNT ON;

	SELECT	P.MatchId
		,	P.LeagueId
		,	P.HomeId
		,	P.AwayId
		,	P.EventDate
		,	P.IsLive
		,	ISNULL(SUM(P.StakeMYR), 0) AS Turnover
		,	ISNULL(SUM(P.StakeMYRJuice), 0) AS TurnoverJuice
		,	ISNULL(SUM(P.Juice), 0) AS Juice
		,	ISNULL(SUM(P.WinLost), 0) - ISNULL(SUM(P.Comm), 0) AS WinLoss
		,	ISNULL(SUM(P.BetCount), 0) AS BetCount
	FROM dbo.TraderJuicePerformance AS P WITH (NOLOCK)
		LEFT JOIN dbo.BetType AS TN WITH (NOLOCK) ON TN.BetType = P.BetType
		LEFT JOIN dbo.LeagueExclusion le WITH(NOLOCK) ON P.LeagueId = le.LeagueId
	WHERE P.EventDate BETWEEN @FromDate AND @ToDate
		AND P.CustId = @CustId
		AND TN.MainDBBetType IN (1,3,7,8)
		AND TN.[Disabled] = 0
		AND (@Market = -1 OR P.IsLive = @Market)
		AND (@IsExcludeLeagues = 0 OR le.LeagueId IS NULL)
	GROUP BY P.MatchId
		,	P.LeagueId
		,	P.HomeId
		,	P.AwayId
		,	P.EventDate
		,	P.IsLive;
END;

GO
/*<info serverAlias="DBTGRS-bodb_TGRS" executers="wsv_tgrs" isFunction="0" isNested="0"></info>*/