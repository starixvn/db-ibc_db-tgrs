ALTER PROCEDURE [dbo].[TGRS_Rpt_TraderWinlossTurnover]
		@TraderId 			INT
	,	@ReportType 		TINYINT = 2
	,	@FromDate 			DATETIME
	,	@ToDate 			DATETIME
	,	@ViewPermission		SMALLINT
	,	@IsExcludeLeagues	BIT		= 1
	,	@Market				SMALLINT = 1
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
		- 20190116@John:  Daily chart does not display on Trader Report [Redmine ID: 108008]
		- 20190129@John:  Fix bug for League Exclusion [Redmine ID: 107809]
		- 20190919@John.Ngo:	Support Nonlive Data [Redmine ID: 118959]

	Param's Explanation (filtered by):
		- @Market:	-1 All; 0 Nonlive; 1 Live
		- @ReportType:
			1: by date
			2: by month
			
		- @ViewPermission = 0: all bet types
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

		SELECT d.WLDate,
			ISNULL(SUM(t.Stake), 0) AS Turnover,
			ISNULL(SUM(t.WinLost), 0) - ISNULL(SUM(t.Comm), 0) AS WinLost,
			t.IsLive
		FROM dbo.TraderPerformance t (NOLOCK)
			RIGHT JOIN @Date d ON t.EventDate = d.WLDate AND CustId = @TraderId
			INNER JOIN Bettype bt WITH(NOLOCK) ON t.Bettype = bt.Bettype
		WHERE (@ViewPermission = 0 OR bt.BettypeGroup = @ViewPermission)
			AND (@Market = -1 OR t.IsLive = @Market)
			AND bt.[Disabled] = 0
			AND (@IsExcludeLeagues = 0 OR (t.LeagueId NOT IN (SELECT le.LeagueId FROM LeagueExclusion le WITH(NOLOCK))))
		GROUP BY d.WLDate, t.IsLive;
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
			SELECT d.WLDate,
				ISNULL(SUM(s.Stake), 0) AS Turnover,
				ISNULL(SUM(s.WinLost), 0) - ISNULL(SUM(s.Comm), 0) AS WinLost,
				s.IsLive
			FROM dbo.SummaryByTrader_Monthly s (NOLOCK)
				RIGHT JOIN @Date d ON s.Eventdate = d.WLDate AND CustId = @TraderId
			WHERE (@ViewPermission = 0 OR s.BettypeGroup = @ViewPermission)
				AND (@Market = -1 OR s.IsLive = @Market)
				AND (@IsExcludeLeagues = 0 OR (s.LeagueId NOT IN (SELECT le.LeagueId FROM dbo.LeagueExclusion le WITH(NOLOCK))))
			GROUP BY d.WLDate, s.IsLive;
		END
		ELSE -- Report by date - month
		BEGIN
			SELECT d.WLDate,
				ISNULL(SUM(s.Turnover), 0) AS Turnover,
				ISNULL(SUM(s.WinLost), 0) AS WinLost,
				s.IsLive
			FROM
				(
					SELECT
						DATEADD(MONTH, DATEDIFF(MONTH, 0, p.EventDate), 0) AS EventDate,
						ISNULL(SUM(p.Stake), 0) AS Turnover,
						ISNULL(SUM(p.WinLost), 0) - ISNULL(SUM(p.Comm), 0) AS WinLost,
						p.IsLive
					FROM dbo.TraderPerformance p WITH(NOLOCK)
						 INNER JOIN Bettype bt WITH(NOLOCK) ON p.Bettype = bt.Bettype
					WHERE p.CustId = @TraderId
						AND p.EventDate BETWEEN @FromDate AND @ToDate
						AND (
								@ViewPermission = 0
								OR bt.BettypeGroup = @ViewPermission
							)
						AND (@Market = -1 OR p.IsLive = @Market)
						AND bt.[Disabled] = 0
						AND (@IsExcludeLeagues = 0 OR (p.LeagueId NOT IN (SELECT le.LeagueId FROM dbo.LeagueExclusion le WITH(NOLOCK))))
					GROUP BY DATEADD(MONTH, DATEDIFF(MONTH, 0, p.EventDate), 0), p.IsLive
				) AS s
				RIGHT JOIN @Date d ON s.EventDate = d.WLDate
			GROUP BY d.WLDate, s.IsLive
		END
	END
END

GO
/*<info serverAlias="DBTGRS-bodb_TGRS" executers="bodbTGRSNet" isFunction="0" isNested="0"></info>*/