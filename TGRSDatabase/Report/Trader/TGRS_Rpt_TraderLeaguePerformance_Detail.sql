
ALTER PROCEDURE [dbo].[TGRS_Rpt_TraderLeaguePerformance_Detail]
	@TraderId	INT,
	@LeagueId	INT,
	@FromDate	DATETIME,
	@ToDate		DATETIME,
	@IsExcludeLeagues	BIT = 1
AS
/*
	Creator: Percy
	Date: 2016-05-31
	Task: Trader Report - League Performance - Detail
	DB: DBTGRS.bodb_TGRS

	Revisions:
		- 20171205@Simon: get only Live data & Bettypes are not disabled
		- 20180912@Simon: add league exclusion

	Param's Explanation:

	Exam:
*/
BEGIN
	SET NOCOUNT ON;
	
	SELECT
		MatchId, HomeId, AwayId, EventDate,
		ISNULL(SUM(Stake),0) AS Turnover, 
		ISNULL(SUM(WinLost),0) -  ISNULL(SUM(Comm),0) AS WinLost,
		ISNULL(SUM(BetCount),0) AS BetCount,
		CASE WHEN ISNULL(SUM(Stake), 0) <> 0 THEN (ISNULL(SUM(WinLost), 0) - ISNULL(SUM(Comm),0)) * 100/SUM(Stake) ELSE NULL END AS Margin 
	FROM dbo.TraderPerformance (NOLOCK)
	WHERE
		CustId = @TraderId
		AND LeagueId = @LeagueId
		AND EventDate BETWEEN @FromDate AND @ToDate
		AND IsLive = 1
		AND (@IsExcludeLeagues = 0 OR (LeagueId NOT IN (SELECT le.LeagueId FROM dbo.LeagueExclusion le WITH(NOLOCK))))
	GROUP BY MatchId, HomeId, AwayId, EventDate
	ORDER BY Margin DESC;
END;

GO
/*<info serverAlias="DBTGRS-bodb_TGRS" executers="bodbTGRSNet" isFunction="0" isNested="0"></info>*/