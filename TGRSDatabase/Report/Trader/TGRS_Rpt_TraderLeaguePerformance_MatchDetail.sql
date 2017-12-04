
CREATE PROCEDURE [dbo].[TGRS_Rpt_TraderLeaguePerformance_MatchDetail]
	@TraderId	INT,
	@MatchId	INT,
	@EventDate	DATETIME
AS
/*
	Creator: Percy
	Date: 2016-05-31
	Task: Trader Report - League Performance - Match Detail
	DB: DBTGRS.bodb_TGRS

	Revisions:
		20171204@Simon: Add is live + active filter
	Param's Explanation:

	Exam:
*/
BEGIN
	SET NOCOUNT ON
	
	SELECT
		b.Bettype, b.TypeName,
		ISNULL(SUM(Stake),0) AS Turnover, 
		ISNULL(SUM(WinLost),0) -  ISNULL(SUM(Comm),0) AS WinLost,
		ISNULL(SUM(BetCount),0) AS BetCount,
		CASE WHEN ISNULL(SUM(Stake), 0) <> 0 THEN (ISNULL(SUM(WinLost), 0) - ISNULL(SUM(Comm),0)) * 100/SUM(Stake) ELSE NULL END AS Margin 
	FROM
		dbo.TraderPerformance t (NOLOCK)
		INNER JOIN dbo.BetType b (NOLOCK) ON t.BetType = b.BetType
	WHERE
		CustId = @TraderId
		AND MatchId = @MatchId
		AND EventDate = @EventDate
		AND t.IsLive = 1
		AND b.[Disabled] = 0
	GROUP BY b.Bettype, b.TypeName
	ORDER BY Margin DESC
END