USE [bodb_TGRS]
GO

ALTER PROCEDURE [dbo].[TGRS_Rpt_TraderBettypePerformance]
	@TraderId	INT,
	@FromDate	DATETIME,
	@ToDate		DATETIME
AS
/*
	Creator: Percy
	Date: 2016-05-17
	Task: Trader Report - Bettype Performance
	DB: DBTGRS.bodb_TGRS

	Revisions:
		- 20160531@Percy: Return new field betcount [RedmineID: #58484]

	Param's Explanation:

	Exam:
*/
BEGIN
	SET NOCOUNT ON

	SELECT
		b.BetType, b.TypeName, 
		ISNULL(SUM(Stake),0) AS Turnover, 
		ISNULL(SUM(WinLost),0) -  ISNULL(SUM(Comm),0) AS WinLost,
		ISNULL(SUM(BetCount),0) AS BetCount,
		CASE WHEN ISNULL(SUM(Stake), 0) <> 0 THEN (ISNULL(SUM(WinLost), 0) - ISNULL(SUM(Comm),0)) * 100/SUM(Stake) ELSE NULL END AS Margin 
	FROM
		dbo.TraderPerformance t (NOLOCK)
		INNER JOIN dbo.BetType b (NOLOCK) ON t.BetType = b.BetType
	WHERE
		CustId = @TraderId
		AND EventDate BETWEEN @FromDate AND @ToDate
	GROUP BY b.BetType, b.TypeName, b.OrderId
	ORDER BY Margin DESC, b.OrderId
END
GO

GRANT EXECUTE ON [dbo].[TGRS_Rpt_TraderBettypePerformance] TO [bodbTGRSNet]
GO