USE [bodb_TGRS]
GO

ALTER PROCEDURE [dbo].[TGRS_Rpt_TraderGeneralInfo]
	@TraderId INT,
	@ReportType TINYINT = 2,
	@FromDate DATETIME,
	@ToDate DATETIME
AS
/*
	Creator: Percy
	Date: 2016-05-17
	Task: Trader Report - General Info
	DB: DBTGRS.bodb_TGRS

	Revisions:

	Param's Explanation:
		@ReportType:
			1: by date
			2: by month

	Exam:
*/
BEGIN
	SET NOCOUNT ON
	IF @ReportType = 1 -- by date
	BEGIN
		SELECT
			ISNULL(SUM(Stake), 0) AS Turnover,
			ISNULL(SUM(WinLost), 0) - ISNULL(SUM(Comm), 0) AS WinLost,
			CASE WHEN ISNULL(SUM(Stake), 0) <> 0 THEN (ISNULL(SUM(WinLost), 0) - ISNULL(SUM(Comm), 0))* 100/SUM(Stake) ELSE NULL END AS Margin,
			ISNULL(COUNT(DISTINCT MatchID), 0) AS MatchCount
		FROM dbo.TraderPerformance (NOLOCK)
		WHERE
			CustId = @TraderId
			AND EventDate BETWEEN @FromDate AND @ToDate
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
	END
END
GO

GRANT EXECUTE ON [dbo].[TGRS_Rpt_TraderGeneralInfo] TO [bodbTGRSNet]
GO