ALTER PROCEDURE [dbo].[TGRS_Rpt_TraderLeaguePerformance]
		@TraderId			INT
	,	@FromDate			DATETIME
	,	@ToDate				DATETIME
	,	@ViewPermission		SMALLINT
	,	@IsExcludeLeagues	BIT		= 1
	,	@Market				SMALLINT = 1
AS
/*
	Creator: Percy
	Date: 2016-05-17
	Task: Trader Report - League Performance
	DB: DBTGRS.bodb_TGRS

	Revisions:
		- 20160531@Percy: Return new field matchcount, betcount [RedmineID: #58484]
		- 20171024@Simon: Add ViewPermission param
		- 20171205@Simon: get only Live data & Bettypes are not disabled
		- 20180912@Simon: add league exclusion
		- 20190919@John.Ngo:	Support Nonlive Data [Redmine ID: 118959]
		- 20191023@John.Ngo:	Enhance performance [Redmine ID: 121268]
		- 20210901@Adam.Tran: 	Sports - Performance Real Figures [Redmine: #158981]

	Param's Explanation (filtered by):
		- @Market:	-1 All; 0 Nonlive; 1 Live
		- @ViewPermission = 0: all bet types
				 = 1: major bet types
				 = 2: PHAIO bet types
	Exam:
*/
BEGIN
	SET NOCOUNT ON;

	SELECT	COUNT(DISTINCT t.MatchId) 							AS MatchCount
		,	l.leagueid
		, 	l.leaguename
		,	ISNULL(SUM(t.Stake),0) 								AS Turnover
		, 	ISNULL(SUM(t.WinLost),0) -  ISNULL(SUM(t.Comm),0) 	AS WinLoss
		,	CASE WHEN  ISNULL(SUM(t.Stake), 0) <> 0 THEN (ISNULL(SUM(t.WinLost), 0) - ISNULL(SUM(t.Comm),0)) * 100/SUM(t.Stake) ELSE NULL END AS Margin
		,	ISNULL(SUM(t.Stake_Real),0) 						AS TurnoverReal
		,	ISNULL(SUM(CASE WHEN t.Is8RM = 0 THEN t.WinLost_Real ELSE 0 END),0) 	AS WinLossReal
		,	CASE WHEN ISNULL(SUM(t.Stake_Real),0) <> 0 THEN ISNULL(SUM(CASE WHEN t.Is8RM = 0 THEN t.WinLost_Real ELSE 0 END),0) * 100/ISNULL(SUM(t.Stake_Real),0) ELSE NULL END 							   		 AS MarginReal
		,	ISNULL(SUM(t.BetCount),0) 							AS BetCount
		,	t.IsLive
	FROM
		dbo.TraderPerformance t (NOLOCK)
		INNER JOIN bodb02.dbo.league l (NOLOCK) ON t.LeagueId = l.leagueid
		INNER JOIN dbo.Bettype bt WITH(NOLOCK) ON bt.Bettype = t.Bettype
		LEFT JOIN dbo.LeagueExclusion le WITH(NOLOCK) ON t.LeagueId = le.LeagueId
	WHERE
		t.CustId = @TraderId
		AND t.EventDate BETWEEN @FromDate AND @ToDate
		AND (
				@ViewPermission = 0
				OR bt.BettypeGroup = @ViewPermission
			)
		AND (@Market = -1 OR t.IsLive = @Market)
		AND bt.[Disabled] = 0
		AND (@IsExcludeLeagues = 0 OR le.LeagueId IS NULL)
	GROUP BY l.leagueid, l.leaguename, t.IsLive
	ORDER BY Margin DESC;
END;

GO
/*<info serverAlias="DBTGRS-bodb_TGRS" executers="bodbTGRSNet" isFunction="0" isNested="0"></info>*/