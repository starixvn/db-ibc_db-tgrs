
ALTER PROCEDURE [dbo].[TGRS_Rpt_TraderReport]
		@TraderName 		NVARCHAR(50)
	,	@ReportType 		TINYINT = 1
	,	@FromDate 			DATETIME
	,	@ToDate 			DATETIME
	,	@ViewPermission		SMALLINT
	,	@IsExcludeLeagues		BIT = 1
AS
/*
	Creator: Long
	Date: 2018-07-19
	Task: Trader's Report
	DB: DBTGRS.bodb_TGRS

	Revisions:
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

	-- INIT	 
	DECLARE @FDate			DATETIME
		,	@TDate			DATETIME
		,	@TraderId		INT;  

	IF	OBJECT_ID('tempdb..#tmpWinlossDate') IS NOT NULL
	BEGIN;
		DROP TABLE #tmpWinlossDate;
	END;

	CREATE TABLE	#tmpWinlossDate (
			WLDate		DATETIME
	);

	CREATE CLUSTERED INDEX	#CIX_tmpWinlossDateIdx ON #tmpWinlossDate (
			WLDate		ASC
	);

	SELECT @TraderId = t.CustId
	FROM dbo.Trader AS t WITH(NOLOCK)
	WHERE t.Username = @TraderName;

	-- START
	-- General info
	SELECT	[Turnover]		= ISNULL(SUM(t.Stake), 0)
		,	[WinLost]		= ISNULL(SUM(t.WinLost), 0) - ISNULL(SUM(t.Comm), 0)
		,	[Margin]		= CASE WHEN ISNULL(SUM(t.Stake), 0) <> 0 THEN (ISNULL(SUM(t.WinLost), 0) - ISNULL(SUM(t.Comm), 0))* 100/SUM(t.Stake) ELSE NULL END
		,	[SportCount]	= ISNULL(COUNT(DISTINCT t.SportType), 0)
	FROM dbo.TraderPerformance AS t WITH(NOLOCK)
		INNER JOIN dbo.Bettype AS bt WITH(NOLOCK) ON t.Bettype = bt.Bettype
	WHERE t.CustId = @TraderId
		AND t.EventDate BETWEEN @FromDate AND @ToDate
		AND (
				@ViewPermission = 0
				OR bt.BettypeGroup = @ViewPermission
			)
		AND t.IsLive = 1
		AND bt.[Disabled] = 0
		AND (@IsExcludeLeagues = 0 OR (t.LeagueId NOT IN (SELECT le.LeagueId FROM dbo.LeagueExclusion le WITH(NOLOCK) WHERE le.LeagueId = t.LeagueId)));
  
	-- Chart info
	IF @ReportType = 1 -- Report by date - date, month - date  
	BEGIN  
		SELECT @FDate = @FromDate;  
  
		WHILE @FDate <= @ToDate  
		BEGIN  
			INSERT INTO #tmpWinlossDate(WLDate)  
			VALUES (@FDate);
     
			SELECT @FDate = DATEADD(DAY, 1, @FDate);
		END;  
  
		SELECT	[WLDate]	= d.WLDate
			,	[Turnover]	= ISNULL(SUM(t.Stake), 0)
			,	[WinLost]	= ISNULL(SUM(t.WinLost), 0) - ISNULL(SUM(t.Comm), 0)
		FROM dbo.TraderPerformance AS t WITH(NOLOCK)  
			RIGHT JOIN #tmpWinlossDate AS d WITH(NOLOCK) ON t.EventDate = d.WLDate  
			INNER JOIN dbo.Bettype AS bt WITH(NOLOCK) ON t.Bettype = bt.Bettype  
		WHERE t.CustId = @TraderId
			AND (@ViewPermission = 0 OR bt.BettypeGroup = @ViewPermission)  
			AND t.IsLive = 1  
			AND bt.[Disabled] = 0
			AND (@IsExcludeLeagues = 0 OR (t.LeagueId NOT IN (SELECT le.LeagueId FROM dbo.LeagueExclusion le WITH(NOLOCK) WHERE le.LeagueId = t.LeagueId)))
		GROUP BY d.WLDate;
	END  
	ELSE -- Report by date - month, month - month  
	BEGIN  
		SELECT @FDate = DATEADD(MONTH, DATEDIFF(MONTH, 0, @FromDate), 0); -- get first day of month  
  
		WHILE @FDate <= @ToDate  
		BEGIN  
			INSERT INTO #tmpWinlossDate (WLDate)  
			VALUES (@FDate);
     
			SELECT @FDate = DATEADD(MONTH, 1, @FDate);
		END;
  
		SELECT @FDate = DATEADD(MONTH, DATEDIFF(MONTH, 0, @FromDate), 0); -- get first day of month  
		SELECT @TDate = DATEADD(DAY, -1, DATEADD(MONTH, DATEDIFF(MONTH, 0, @ToDate) + 1, 0)); -- get last day of month  
    
		IF (@FDate = @FromDate AND @TDate = @ToDate) -- Report by month - month  
		BEGIN  
			SELECT	[WLDate]	= d.WLDate
				,	[Turnover]	= ISNULL(SUM(s.Stake), 0)
				,	[WinLost]	= ISNULL(SUM(s.WinLost), 0) - ISNULL(SUM(s.Comm), 0)
			FROM dbo.SummaryByTrader_Monthly AS s WITH(NOLOCK)  
				RIGHT JOIN #tmpWinlossDate AS d WITH(NOLOCK) ON s.Eventdate = d.WLDate
			WHERE s.CustId = @TraderId  
				AND (@ViewPermission = 0 OR BettypeGroup = @ViewPermission)
				AND (@IsExcludeLeagues = 0 OR (s.LeagueId NOT IN (SELECT le.LeagueId FROM dbo.LeagueExclusion le WITH(NOLOCK) WHERE le.LeagueId = s.LeagueId)))
			GROUP BY d.WLDate;
		END  
		ELSE -- Report by date - month  
		BEGIN  
			SELECT	[WLDate]	= d.WLDate
				,	[Turnover]	= ISNULL(SUM(Turnover), 0)  
				,	[WinLost]	= ISNULL(SUM(WinLost), 0)
			FROM  
				(  
					SELECT	[EventDate]	= DATEADD(MONTH, DATEDIFF(MONTH, 0, t.EventDate), 0)
						,	[Turnover]	= ISNULL(SUM(t.Stake), 0)
						,	[WinLost]	= ISNULL(SUM(t.WinLost), 0) - ISNULL(SUM(Comm), 0)
					FROM dbo.TraderPerformance AS t WITH(NOLOCK)  
						INNER JOIN dbo.Bettype AS bt WITH(NOLOCK) ON t.Bettype = bt.Bettype  
					WHERE t.CustId = @TraderId  
						AND t.EventDate BETWEEN @FromDate AND @ToDate  
						AND (  
							@ViewPermission = 0  
							OR bt.BettypeGroup = @ViewPermission  
						)  
						AND t.IsLive = 1  
						AND bt.[Disabled] = 0  
						AND (@IsExcludeLeagues = 0 OR (t.LeagueId NOT IN (SELECT le.LeagueId FROM dbo.LeagueExclusion le WITH(NOLOCK) WHERE le.LeagueId = t.LeagueId)))
					GROUP BY DATEADD(MONTH, DATEDIFF(MONTH, 0, t.EventDate), 0)  
				) AS s  
				RIGHT JOIN #tmpWinlossDate AS d WITH(NOLOCK) ON s.EventDate = d.WLDate  
			GROUP BY d.WLDate;
		END;
	END;
END;

/*<info serverAlias="DBTGRS-bodb_TGRS" executers="bodbTGRSNet" isFunction="0" isNested="0"></info>*/