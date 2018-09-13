USE [bodb_TGRS]
GO

ALTER PROCEDURE [dbo].[TGRS_Rpt_TraderGeneralInfo]
	@TraderId 			INT,
	@ReportType 		TINYINT = 2,
	@FromDate 			DATETIME,
	@ToDate 			DATETIME,
	@ViewPermission		SMALLINT,
	@IsExcludeLeagues	BIT = 1
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

	Param's Explanation:
		@ReportType:
			1: by date
			2: by month
			
		@ViewPermission = 0: all bet types
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
			ISNULL(COUNT(DISTINCT P.MatchID), 0) AS MatchCount
		FROM 
			dbo.TraderPerformance P WITH(NOLOCK)
			INNER JOIN Bettype bt WITH(NOLOCK) ON P.Bettype = bt.Bettype
		WHERE
			CustId = @TraderId
			AND EventDate BETWEEN @FromDate AND @ToDate
			AND (
					@ViewPermission = 0
					OR bt.BettypeGroup = @ViewPermission
				)
			AND P.IsLive = 1
			AND bt.[Disabled] = 0
			AND (@IsExcludeLeagues = 0 OR (P.LeagueId NOT IN (SELECT le.LeagueId FROM dbo.LeagueExclusion le WHERE le.LeagueId = P.LeagueId)))
	END
	ELSE -- by month
	BEGIN
		SELECT
			ISNULL(SUM(Stake), 0) AS Turnover,
			ISNULL(SUM(WinLost), 0) - ISNULL(SUM(Comm), 0) AS WinLost,
			CASE WHEN ISNULL(SUM(Stake), 0) <> 0 THEN (ISNULL(SUM(WinLost), 0) - ISNULL(SUM(Comm), 0))* 100/SUM(Stake) ELSE NULL END AS Margin,
			ISNULL(SUM(MatchCount), 0) AS MatchCount
		FROM dbo.SummaryByTrader_Monthly (NOLOCK)
		WHERE
			CustId = @TraderId
			AND EventDate BETWEEN @FromDate AND @ToDate
			AND (
					@ViewPermission = 0
					OR BettypeGroup = @ViewPermission
				)
			AND (@IsExcludeLeagues = 0 OR (LeagueId NOT IN (SELECT le.LeagueId FROM dbo.LeagueExclusion le WHERE le.LeagueId = LeagueId)))
	END
END;
GO

GRANT EXECUTE ON [dbo].[TGRS_Rpt_TraderGeneralInfo] TO [bodbTGRSNet]
GO
/*<info serverAlias="DBTGRS - bodb_TGRS" executers="bodbTGRSNet" isFunction="0" isNested="0"></info>*/