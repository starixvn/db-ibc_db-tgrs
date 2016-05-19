USE [bodb_TGRS]
GO

ALTER PROCEDURE [dbo].[TGRS_Rpt_TraderWinlossTurnover]
	@TraderId INT,
	@ReportType TINYINT = 2,
	@FromDate DATETIME,
	@ToDate DATETIME
AS
/*
	Creator: Percy
	Date: 2016-05-17
	Task: Trader Report - Winloss/Turnover
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

	DECLARE @Date TABLE (WLDate DATETIME)
	DECLARE @FDate DATETIME

	IF @ReportType = 1 -- by date
	BEGIN
		SELECT @FDate = @FromDate

		WHILE @FDate <= @ToDate
		BEGIN
			INSERT INTO @Date (WLDate)
			VALUES (@FDate)
			
			SELECT @FDate = DATEADD(DAY, 1, @FDate)
		END

		SELECT
			d.WLDate,
			ISNULL(SUM(Stake), 0) AS Turnover,
			ISNULL(SUM(WinLost), 0) - ISNULL(SUM(Comm), 0) AS WinLost
		FROM
			dbo.TraderPerformance t (NOLOCK)
			RIGHT JOIN @Date d ON t.EventDate = d.WLDate
		WHERE CustId = @TraderId
		GROUP BY d.WLDate
	END
	ELSE -- by month
	BEGIN
		SELECT @FDate = DATEADD(MONTH, DATEDIFF(MONTH, 0, @FromDate), 0)

		WHILE @FDate <= @ToDate
		BEGIN
			INSERT INTO @Date (WLDate)
			VALUES (@FDate)
			
			SELECT @FDate = DATEADD(MONTH, 1, @FDate)
		END
		SELECT
			d.WLDate,
			ISNULL(SUM(Stake), 0) AS Turnover,
			ISNULL(SUM(WinLost), 0) - ISNULL(SUM(Comm), 0) AS WinLost
		FROM
			dbo.SummaryByTrader_Monthly s (NOLOCK)
			RIGHT JOIN @Date d ON s.EventDate = d.WLDate
		WHERE CustId = @TraderId
		GROUP BY d.WLDate
	END
END
GO

GRANT EXECUTE ON [dbo].[TGRS_Rpt_TraderWinlossTurnover] TO [bodbTGRSNet]
GO