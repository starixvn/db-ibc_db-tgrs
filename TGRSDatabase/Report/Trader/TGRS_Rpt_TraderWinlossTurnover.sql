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
	DECLARE @FDate DATETIME, @TDate DATETIME

	IF @ReportType = 1 -- Report by date - date, month - date
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
			RIGHT JOIN @Date d ON t.EventDate = d.WLDate AND CustId = @TraderId
		GROUP BY d.WLDate
	END
	ELSE -- Report by date - month, month - month
	BEGIN
		SELECT @FDate = DATEADD(MONTH, DATEDIFF(MONTH, 0, @FromDate), 0) -- get first day of month

		WHILE @FDate <= @ToDate
		BEGIN
			INSERT INTO @Date (WLDate)
			VALUES (@FDate)
			
			SELECT @FDate = DATEADD(MONTH, 1, @FDate)
		END

		SELECT @FDate = DATEADD(MONTH, DATEDIFF(MONTH, 0, @FromDate), 0) -- get first day of month
		SELECT @TDate = DATEADD(DAY, -1, DATEADD(MONTH, DATEDIFF(MONTH, 0, @ToDate) + 1, 0)) -- get last day of month
		
		IF (@FDate = @FromDate AND @TDate = @ToDate) -- Report by month - month
		BEGIN
			SELECT
				d.WLDate,
				ISNULL(SUM(Stake), 0) AS Turnover,
				ISNULL(SUM(WinLost), 0) - ISNULL(SUM(Comm), 0) AS WinLost
			FROM
				dbo.SummaryByTrader_Monthly s (NOLOCK)
				RIGHT JOIN @Date d ON s.Eventdate = d.WLDate AND CustId = @TraderId
			GROUP BY d.WLDate
		END
		ELSE -- Report by date - month
		BEGIN
			SELECT
				d.WLDate,
				ISNULL(SUM(Turnover), 0) AS Turnover,
				ISNULL(SUM(WinLost), 0) AS WinLost
			FROM
				(
					SELECT
						DATEADD(MONTH, DATEDIFF(MONTH, 0, EventDate), 0) AS EventDate,
						ISNULL(SUM(Stake), 0) AS Turnover,
						ISNULL(SUM(WinLost), 0) - ISNULL(SUM(Comm), 0) AS WinLost
					FROM dbo.TraderPerformance (NOLOCK)
					WHERE
						CustId = @TraderId
						AND EventDate BETWEEN @FromDate AND @ToDate
					GROUP BY DATEADD(MONTH, DATEDIFF(MONTH, 0, EventDate), 0)
				) AS s
				RIGHT JOIN @Date d ON s.EventDate = d.WLDate
			GROUP BY d.WLDate
		END
	END
END
GO

GRANT EXECUTE ON [dbo].[TGRS_Rpt_TraderWinlossTurnover] TO [bodbTGRSNet]
GO