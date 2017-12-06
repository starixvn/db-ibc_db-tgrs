
CREATE PROCEDURE [dbo].[TGRS_Rpt_TraderLeaguePerformance_Detail]
	@TraderId	INT,
	@LeagueId	INT,
	@FromDate	DATETIME,
	@ToDate		DATETIME
AS
/*
	Creator: Percy
	Date: 2016-05-31
	Task: Trader Report - League Performance - Detail
	DB: DBTGRS.bodb_TGRS

	Revisions:
		- 20171205@Simon: get only Live data & Bettypes are not disabled

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
	GROUP BY MatchId, HomeId, AwayId, EventDate
	ORDER BY Margin DESC;
END;