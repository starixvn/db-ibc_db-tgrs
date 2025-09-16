ALTER PROCEDURE [dbo].[TGRS_Rpt_NewPerformanceDetail_LeagueAllMatch] 
		@FromDate			DATE
	,	@ToDate				DATE
	,	@LeagueName			NVARCHAR(100) = ''
	,	@IsExcludeLeagues	BIT = 1
	,	@Market				SMALLINT = 1

AS
/*  
	Created:	20190607@John.Ngo
	Task :		Get all matches in Performance Details (Juice & LO) - League [Redmine ID: 114879]
	DB:			DBTGRS.bodb_TGRS
 
	Revisions:      	
		- 20190607@John.Ngo:	Get all matches in Performance Details (Juice & LO) - League [Redmine ID: 114879]
		- 20190919@Long.Luu:	Support Nonlive Data [Redmine ID: 118959]
		- 20191023@John.Ngo:	Enhance performance [Redmine ID: 121268]
		- 20250916@Jaden.Tang: Use new table TraderJuicePerformance [Redmine ID: 237899]
	
	Param's Explanation:
		- @Market: -1 All; 0 Nonlive; 1 Live

	Exam: 
	  		EXEC TGRS_Rpt_NewPerformanceDetail_LeagueAllMatch @FromDate = '2019-05-01', @ToDate= '2019-06-01', @LeagueName = '', @IsExcludeLeagues = 0

*/
BEGIN
	SET NOCOUNT ON;

	SELECT  P.LeagueId
		,	L.LeagueName 
		,	P.MatchId
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
		INNER JOIN bodb02.dbo.League AS L WITH (NOLOCK) ON P.LeagueId = L.LeagueId
		LEFT JOIN dbo.BetType AS TN WITH (NOLOCK) ON TN.BetType = P.BetType
		LEFT JOIN dbo.LeagueExclusion le WITH(NOLOCK) ON P.LeagueId = le.LeagueId
	WHERE P.EventDate BETWEEN @FromDate AND @ToDate
		AND (ISNULL(@LeagueName, '') = '' OR L.LeagueName LIKE '%' + @LeagueName + '%')
		AND TN.MainDBBetType IN (1, 3, 7, 8)
		AND TN.[Disabled] = 0
		AND (@Market = -1 OR P.IsLive = @Market)
		AND (@IsExcludeLeagues = 0 OR le.LeagueId IS NULL)
	GROUP BY P.LeagueId 
		,	L.LeagueName
		,	P.MatchId
		,	P.HomeId
		,	P.AwayId
		,	P.EventDate
		,	P.IsLive
	ORDER BY P.EventDate ASC, P.LeagueId ASC;
END

GO
/*<info serverAlias="DBTGRS-bodb_TGRS" executers="wsv_tgrs" isFunction="0" isNested="0"></info>*/