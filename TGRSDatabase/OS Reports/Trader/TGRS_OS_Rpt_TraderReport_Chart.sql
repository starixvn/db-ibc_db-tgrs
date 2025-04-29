ALTER PROCEDURE [dbo].[TGRS_OS_Rpt_TraderReport_Chart]
		@TraderId 		INT
	,	@ReportType 		TINYINT  = 1
	,	@FromDate 		DATETIME
	,	@ToDate 		DATETIME
	,	@ViewPermission		SMALLINT
	,	@LiveType		SMALLINT = -1
AS
/*
	Creator: Long
	Date: 2018-07-19
	Task: Trader's Report for Other Sports
	DB: DBTGRS.bodb_TGRS

	Revisions:
		- 20181030@Long: Adding Betcount column to OS's reports [Redmine ID: #101741]
		- 20200914@John.Ngo: Support Live/Nonlive for OSDataTGRS [Redmine ID: #140875]

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
		,	@TDate			DATETIME;

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

	-- START
	IF @ReportType = 1
	BEGIN		
		SELECT	[WLDate]	= t.EventDate
			,	[Turnover]	= ISNULL(SUM(t.Turnover), 0)
			,	[WinLost]	= ISNULL(SUM(t.Winloss), 0) - ISNULL(SUM(t.Comm), 0)
			,	[BetCount]	= ISNULL(SUM(t.BetCount), 0)
		FROM dbo.OSSummaryByTrader_Daily AS t WITH(NOLOCK)
		WHERE t.TraderId = @TraderId
			AND t.EventDate BETWEEN @FromDate AND @ToDate 
			AND (@LiveType = -1 OR t.IsLive = @LiveType)
		GROUP BY t.EventDate;
	END  
	ELSE
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
				,	[Turnover]	= ISNULL(SUM(s.Turnover), 0)
				,	[WinLost]	= ISNULL(SUM(s.Winloss), 0) - ISNULL(SUM(s.Comm), 0)
				,	[BetCount]	= ISNULL(SUM(s.BetCount), 0)
			FROM dbo.OSSummaryByTrader_Monthly AS s WITH(NOLOCK)  
				RIGHT JOIN #tmpWinlossDate AS d WITH(NOLOCK) ON s.Eventdate = d.WLDate
			WHERE s.TraderId = @TraderId
				AND (@LiveType = -1 OR s.IsLive = @LiveType)
			GROUP BY d.WLDate;
		END  
		ELSE -- Report by date - month  
		BEGIN  
			SELECT	[WLDate]	= d.WLDate
				,	[Turnover]	= ISNULL(SUM(Turnover), 0)  
				,	[WinLost]	= ISNULL(SUM(WinLost), 0)
				,	[BetCount]	= ISNULL(SUM(BetCount), 0)
			FROM  
				(  
					SELECT	[EventDate]	= DATEADD(MONTH, DATEDIFF(MONTH, 0, t.EventDate), 0)
						,	[Turnover]	= ISNULL(SUM(t.Turnover), 0)
						,	[WinLost]	= ISNULL(SUM(t.Winloss), 0) - ISNULL(SUM(Comm), 0)
						,	[BetCount]	= ISNULL(SUM(t.BetCount), 0)
					FROM dbo.OSSummaryByTrader_Daily AS t WITH(NOLOCK) 
					WHERE t.TraderId = @TraderId  
						AND t.EventDate BETWEEN @FromDate AND @ToDate
						AND (@LiveType = -1 OR t.IsLive = @LiveType)
					GROUP BY DATEADD(MONTH, DATEDIFF(MONTH, 0, t.EventDate), 0)  
				) AS s  
				RIGHT JOIN #tmpWinlossDate AS d WITH(NOLOCK) ON s.EventDate = d.WLDate  
			GROUP BY d.WLDate;
		END;
	END;
END;

GO
/*<info serverAlias="DBTGRS-bodb_TGRS" executers="wsv_nap" isFunction="0" isNested="0"></info>*/