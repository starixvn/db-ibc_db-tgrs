ALTER PROCEDURE [dbo].[TGRS_Rpt_TraderGeneralInfo]
		@TraderId 			INT
	,	@ReportType 		TINYINT = 2
	,	@FromDate 			DATETIME
	,	@ToDate 			DATETIME
	,	@ViewPermission		SMALLINT
	,	@IsExcludeLeagues	BIT		= 1
	,	@Market				SMALLINT = 1
AS
/*
	Creator: Percy
	Date: 2016-05-17
	Task: Trader Report - General Info
	DB: DBTGRS.bodb_TGRS

	Revisions:
		- 20171024@Simon: Add ViewPermission param
		- 20171205@Simon: get only Live data & Bettypes are not disabled
		- 20180912@Simon: add league exclusion
		- 20190129@John:  Fix bug for League Exclusion [Redmine ID: 107809]
		- 20190919@John.Ngo:	Support Nonlive Data [Redmine ID: 118959]
		- 20191023@John.Ngo:	Enhance performance [Redmine ID: 121268]

	Param's Explanation (filtered by):
		- @Market:	-1 All; 0 Nonlive; 1 Live
		- @ReportType:
			1: by date
			2: by month
			
		- @ViewPermission = 0: all bet types
				 = 1: major bet types
				 = 2: PHAIO bet types
	Exam:
*/
BEGIN
	SET NOCOUNT ON;
	IF @ReportType = 1 -- by date
	BEGIN
		SELECT
			ISNULL(SUM(P.Stake), 0) AS Turnover,
			ISNULL(SUM(P.WinLost), 0) - ISNULL(SUM(P.Comm), 0) AS WinLost,
			CASE WHEN ISNULL(SUM(P.Stake), 0) <> 0 THEN (ISNULL(SUM(P.WinLost), 0) - ISNULL(SUM(P.Comm), 0))* 100/SUM(P.Stake) ELSE NULL END AS Margin,
			ISNULL(COUNT(DISTINCT P.MatchID), 0) AS MatchCount,
			P.IsLive
		FROM 
			dbo.TraderPerformance P WITH(NOLOCK)
			INNER JOIN Bettype bt WITH(NOLOCK) ON P.Bettype = bt.Bettype
			LEFT JOIN dbo.LeagueExclusion le WITH(NOLOCK) ON P.LeagueId = le.LeagueId
		WHERE
			P.CustId = @TraderId
			AND P.EventDate BETWEEN @FromDate AND @ToDate
			AND (
					@ViewPermission = 0
					OR bt.BettypeGroup = @ViewPermission
				)
			AND (@Market = -1 OR P.IsLive = @Market)
			AND bt.[Disabled] = 0
			AND (@IsExcludeLeagues = 0 OR le.LeagueId IS NULL)
		GROUP BY P.IsLive;
	END
	ELSE -- by month
	BEGIN
		SELECT
			ISNULL(SUM(sm.Stake), 0) AS Turnover,
			ISNULL(SUM(sm.WinLost), 0) - ISNULL(SUM(sm.Comm), 0) AS WinLost,
			CASE WHEN ISNULL(SUM(sm.Stake), 0) <> 0 THEN (ISNULL(SUM(sm.WinLost), 0) - ISNULL(SUM(sm.Comm), 0))* 100/SUM(sm.Stake) ELSE NULL END AS Margin,
			ISNULL(SUM(sm.MatchCount), 0) AS MatchCount,
			sm.IsLive
		FROM dbo.SummaryByTrader_Monthly sm (NOLOCK)
		LEFT JOIN dbo.LeagueExclusion le WITH(NOLOCK) ON sm.LeagueId = le.LeagueId
		WHERE
			sm.CustId = @TraderId
			AND sm.EventDate BETWEEN @FromDate AND @ToDate
			AND (@Market = -1 OR IsLive = @Market)
			AND (
					@ViewPermission = 0
					OR BettypeGroup = @ViewPermission
				)
			AND (@IsExcludeLeagues = 0 OR le.LeagueId IS NULL)
		GROUP BY sm.IsLive;
	END
END;

GO
/*<info serverAlias="DBTGRS-bodb_TGRS" executers="bodbTGRSNet" isFunction="0" isNested="0"></info>*/