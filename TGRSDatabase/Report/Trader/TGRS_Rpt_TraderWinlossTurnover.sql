ALTER PROCEDURE [dbo].[TGRS_Rpt_TraderWinlossTurnover]
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
	Task: Trader Report - Winloss/Turnover
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

	DECLARE @Date TABLE (WLDate DATETIME);
	DECLARE @FDate DATETIME, @TDate DATETIME;

	IF @ReportType = 1 -- Report by date - date, month - date
	BEGIN
		SELECT @FDate = @FromDate;

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
			INNER JOIN Bettype bt WITH(NOLOCK) ON t.Bettype = bt.Bettype
		WHERE
			(@ViewPermission = 0 OR bt.BettypeGroup = @ViewPermission)
			AND t.IsLive = 1
			AND bt.[Disabled] = 0
			AND (@IsExcludeLeagues = 0 OR (t.LeagueId IN (SELECT le.LeagueId FROM LeagueExclusion le WHERE le.LeagueId = t.LeagueId)))
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
			WHERE
				@ViewPermission = 0
				OR BettypeGroup = @ViewPermission
				AND (@IsExcludeLeagues = 0 OR (s.LeagueId NOT IN (SELECT le.LeagueId FROM dbo.LeagueExclusion le WHERE le.LeagueId = s.LeagueId)))
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
					FROM dbo.TraderPerformance p WITH(NOLOCK)
						 INNER JOIN Bettype bt WITH(NOLOCK) ON p.Bettype = bt.Bettype
					WHERE
						CustId = @TraderId
						AND EventDate BETWEEN @FromDate AND @ToDate
						AND (
								@ViewPermission = 0
								OR bt.BettypeGroup = @ViewPermission
							)
						AND p.IsLive = 1
						AND bt.[Disabled] = 0
						AND (@IsExcludeLeagues = 0 OR (p.LeagueId NOT IN (SELECT le.LeagueId FROM dbo.LeagueExclusion le WHERE le.LeagueId = p.LeagueId)))
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