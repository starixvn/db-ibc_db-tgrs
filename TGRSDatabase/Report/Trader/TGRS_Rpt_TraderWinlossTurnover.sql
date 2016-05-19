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
			RIGHT JOIN @Date d ON t.EventDate = d.WLDate AND CustId = @TraderId
		GROUP BY d.WLDate
	END
	ELSE -- by month
	BEGIN
		DECLARE @Result TABLE (WLDate DATETIME, Turnover MONEY, WinLost MONEY)
		DECLARE @SDate DATETIME, @EDate DATETIME
		SELECT  @SDate = DATEADD(MONTH, DATEDIFF(MONTH, 0, @FromDate), 0)
		SELECT  @EDate = DATEADD(MONTH, DATEDIFF(MONTH, 0, @ToDate), 0)

		IF @SDate = @EDate
		BEGIN
			SELECT
				@SDate AS WLDate,
				ISNULL(SUM(Stake), 0) AS Turnover,
				ISNULL(SUM(WinLost), 0) - ISNULL(SUM(Comm), 0) AS WinLost
			FROM dbo.TraderPerformance (NOLOCK)
			WHERE CustId = @TraderId AND EventDate BETWEEN @FromDate AND @ToDate

			RETURN
		END
		
		SELECT @FDate = DATEADD(MONTH, DATEDIFF(MONTH, 0, @FromDate), 0)
		SELECT @TDate = DATEADD(DAY, -1, DATEADD(MONTH, DATEDIFF(MONTH, 0, @FromDate) + 1, 0))
		IF @FDate <> @FromDate
		BEGIN
			SELECT @SDate = DATEADD(MONTH, 1, @SDate)
			INSERT INTO @Result (WLDate, Turnover, WinLost)
			SELECT
				@FDate AS WLDate,
				ISNULL(SUM(Stake), 0) AS Turnover,
				ISNULL(SUM(WinLost), 0) - ISNULL(SUM(Comm), 0) AS WinLost
			FROM dbo.TraderPerformance (NOLOCK)
			WHERE CustId = @TraderId AND EventDate BETWEEN @FromDate AND @TDate
		END

		SELECT @FDate = DATEADD(MONTH, DATEDIFF(MONTH, 0, @ToDate), 0)
		SELECT @TDate = DATEADD(DAY, -1, DATEADD(MONTH, DATEDIFF(MONTH, 0, @ToDate) + 1, 0))
		IF @TDate <> @ToDate
		BEGIN
			SELECT @EDate = DATEADD(MONTH, -1, @EDate)
			INSERT INTO @Result (WLDate, Turnover, WinLost)
			SELECT
				@FDate AS WLDate,
				ISNULL(SUM(Stake), 0) AS Turnover,
				ISNULL(SUM(WinLost), 0) - ISNULL(SUM(Comm), 0) AS WinLost
			FROM dbo.TraderPerformance (NOLOCK)
			WHERE CustId = @TraderId AND EventDate BETWEEN @FDate AND @ToDate
		END

		WHILE @SDate <= @EDate
		BEGIN
			INSERT INTO @Date (WLDate)
			VALUES (@SDate)
			
			SELECT @SDate = DATEADD(MONTH, 1, @SDate)
		END
		INSERT INTO @Result (WLDate, Turnover, WinLost)
		SELECT
			d.WLDate,
			ISNULL(SUM(Stake), 0) AS Turnover,
			ISNULL(SUM(WinLost), 0) - ISNULL(SUM(Comm), 0) AS WinLost
		FROM
			dbo.SummaryByTrader_Monthly s (NOLOCK)
			RIGHT JOIN @Date d ON s.Eventdate = d.WLDate AND CustId = @TraderId
		GROUP BY d.WLDate

		SELECT * FROM @Result
		ORDER BY WLDate
	END
END
GO

GRANT EXECUTE ON [dbo].[TGRS_Rpt_TraderWinlossTurnover] TO [bodbTGRSNet]
GO