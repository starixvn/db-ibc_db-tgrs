CREATE PROCEDURE [dbo].[TGRS_OS_Rpt_SummaryMarket]  
		@FromDate			DATE
	,	@ToDate				DATE
	,	@SportIds			VARCHAR(2000) =  ''
	,	@ReportType			TINYINT  = 1
	,	@LiveType			SMALLINT = 1
AS    
/*  
 Created:	20201202@John.Ngo
 Task :		OS Summary Market Report
 DB:		DBTGRS.bodb_TGRS
 Original:  
  
 Revisions:      
		- 20201202@John.Ngo: Support Summary Data for Market Count Report [Redmine ID: 145990]

 Param's Explanation (filtered by):
		- @ReportType = 1: By Date
					  = 2: By Month
		- @LiveType: -1 All; 0 Nonlive; 1 Live

 Exam: 
	EXEC TGRS_OS_Rpt_SummaryMarket @FromDate = '2020-05-01', @ToDate = '2020-12-31'
  
*/  
 
BEGIN 
	SET NOCOUNT ON

DECLARE @PrevFromDate		DATE
	,	@PrevToDate			DATE
	,	@Avg				INT

	SET @PrevFromDate = DATEADD(YYYY, -1, @FromDate);
	SET @PrevToDate   = DATEADD(YYYY, -1, @ToDate);

	IF	OBJECT_ID('tempdb..#OSSummaryMarket') IS NOT NULL
	BEGIN;
		DROP TABLE #OSSummaryMarket;
	END;

	CREATE TABLE #OSSummaryMarket (
			EventDate			DATE
		,	SportId				INT
		,	MatchId				INT
		,	MarketCount			INT
	);
	
	CREATE CLUSTERED INDEX #CIX_OSSummaryMarketIdx ON #OSSummaryMarket (
			EventDate			ASC
	); 
	
	IF @SportIds <> ''
	BEGIN
		DECLARE @Sports AS TABLE (SportId SMALLINT PRIMARY KEY CLUSTERED);
		INSERT INTO @Sports(SportId)
		SELECT val FROM dbo.strSplit_Key(@SportIds,',');
	END;

	IF @ReportType	= 1
	BEGIN
		SELECT @Avg = DATEDIFF(DAY, @FromDate, @ToDate) + 1;

		INSERT INTO #OSSummaryMarket (EventDate, SportId, MatchId, MarketCount)
		SELECT	ossm.EventDate
			,	ossm.SportId
			,	ossm.MatchId
			,	COUNT(DISTINCT ossm.MarketId) AS MarketCount
		FROM  dbo.[OSSummaryMarket] ossm WITH (NOLOCK)
			LEFT JOIN @Sports AS sp ON sp.SportId = ossm.SportId
		WHERE ossm.EventDate BETWEEN @FromDate AND @ToDate
			AND (sp.SportId IS NOT NULL)
			AND (@LiveType = -1 OR ossm.IsLive = @LiveType)
		GROUP BY ossm.EventDate
			,	ossm.SportId
			,	ossm.MatchId;

		INSERT INTO #OSSummaryMarket (EventDate, SportId, MatchId, MarketCount)
		SELECT	ossm.EventDate
			,	ossm.SportId
			,	ossm.MatchId
			,	COUNT(DISTINCT ossm.MarketId) AS MarketCount
		FROM  dbo.[OSSummaryMarket] ossm WITH (NOLOCK)
			LEFT JOIN @Sports AS sp ON sp.SportId = ossm.SportId
		WHERE ossm.EventDate BETWEEN @PrevFromDate AND @PrevToDate
			AND (sp.SportId IS NOT NULL)
			AND (@LiveType = -1 OR ossm.IsLive = @LiveType)
		GROUP BY ossm.EventDate
			,	ossm.SportId
			,	ossm.MatchId;

		SELECT 	ossm.EventDate
			,	SUM(ossm.MarketCount) AS MarketCount
		FROM  #OSSummaryMarket ossm WITH (NOLOCK)
		GROUP BY ossm.EventDate
		ORDER BY ossm.EventDate ASC;

		SELECT 	@FromDate AS FromDate 
			,	@ToDate AS ToDate
			,	CAST(ISNULL(SUM(ossm.MarketCount),0) AS MONEY)/@Avg AS AvgMarketCount
		FROM	#OSSummaryMarket ossm WITH (NOLOCK)
		WHERE	ossm.EventDate BETWEEN @FromDate AND @ToDate
		UNION 
		SELECT 	@PrevFromDate AS FromDate 
			,	@PrevToDate AS ToDate
			,	CAST(ISNULL(SUM(ossm.MarketCount),0) AS MONEY)/@Avg AS AvgMarketCount
		FROM	#OSSummaryMarket ossm WITH (NOLOCK)
		WHERE ossm.EventDate BETWEEN @PrevFromDate AND @PrevToDate
	END;

	IF (@ReportType = 2)
	BEGIN
		DECLARE @StartFromDate		DATE
			,	@StartToDate		DATE
			,	@EndToDate			DATE
			,	@PrevStartFromDate	DATE
			,	@PrevStartToDate	DATE
			,	@PrevEndToDate		DATE
			,	@StartDate			DATE
			,	@EndDate			DATE
			,	@PrevStartDate		DATE
			,	@PrevEndDate		DATE
			,	@WinlostDate		DATE

		SELECT @StartFromDate		= DATEADD(DD, -DAY(@FromDate) + 1, @FromDate);
		SELECT @StartToDate			= DATEADD(DD, -DAY(@ToDate) + 1, @ToDate);
		SELECT @EndToDate			= DATEADD(DAY,-(DAY(@ToDate)),DATEADD(MONTH,1,@ToDate));
		
		SELECT @PrevStartFromDate   = DATEADD(YYYY, -1, @StartFromDate);		
		SELECT @PrevEndToDate		= DATEADD(YYYY, -1, @EndToDate);
		SELECT @PrevStartToDate		= DATEADD(DD, -DAY(@PrevEndToDate) + 1, @PrevEndToDate);

		SELECT @Avg = DATEDIFF(DAY, @StartFromDate, @EndToDate) + 1;
		
		IF	OBJECT_ID('tempdb..#tmpWinlostDate') IS NOT NULL
		BEGIN;
			DROP TABLE	#tmpWinlostDate;
		END;

		CREATE TABLE	#tmpWinlostDate (
			winlostdate			DATE
		);

		INSERT INTO	#tmpWinlostDate (winlostdate)
		SELECT	tally.EventDate
		FROM	(
			SELECT	[NoMonths] = DATEDIFF(MONTH, @FromDate, @ToDate) + 1
		) cnt
		CROSS APPLY	(
			SELECT	TOP(cnt.NoMonths)
					[EventDate] = DATEADD(MONTH, ROW_NUMBER() OVER(ORDER BY (SELECT NULL)) - 1, @FromDate)
			FROM		(VALUES (0), (0), (0), (0), (0), (0), (0), (0), (0), (0)) x10(n)
			CROSS APPLY	(VALUES (0), (0), (0), (0), (0), (0), (0), (0), (0), (0)) x100(n)
			CROSS APPLY	(VALUES (0), (0), (0), (0), (0), (0), (0), (0), (0), (0)) x1000(n)
		) tally;
		
		WHILE	EXISTS (SELECT 1 FROM #tmpWinlostDate)
		BEGIN;
			SELECT	TOP(1)
					@WinLostDate = d.winlostdate
			FROM	#tmpWinlostDate AS d;

			SELECT @StartDate		= DATEADD(DD, -DAY(@WinLostDate) + 1, @WinLostDate);
			SELECT @EndDate			= DATEADD(DD, -1 , DATEADD(MM, 1, @StartDate));
			SELECT @PrevStartDate   = DATEADD(YYYY, -1, @StartDate);
			SELECT @PrevEndDate     = DATEADD(YYYY, -1, @EndDate);

			INSERT INTO #OSSummaryMarket (EventDate, SportId, MatchId, MarketCount)
			SELECT	@StartDate
				,	ossm.SportId
				,	ossm.MatchId
				,	COUNT(DISTINCT ossm.MarketId) AS MarketCount
			FROM  dbo.[OSSummaryMarket] ossm WITH (NOLOCK)
				LEFT JOIN @Sports AS sp ON sp.SportId = ossm.SportId
			WHERE ossm.EventDate BETWEEN @StartDate AND @EndDate
				AND (sp.SportId IS NOT NULL)
				AND (@LiveType = -1 OR ossm.IsLive = @LiveType)
			GROUP BY ossm.EventDate
				,	ossm.SportId
				,	ossm.MatchId;

			INSERT INTO #OSSummaryMarket (EventDate, SportId, MatchId, MarketCount)
			SELECT	@PrevStartDate
				,	ossm.SportId
				,	ossm.MatchId
				,	COUNT(DISTINCT ossm.MarketId) AS MarketCount
			FROM  dbo.[OSSummaryMarket] ossm WITH (NOLOCK)
				LEFT JOIN @Sports AS sp ON sp.SportId = ossm.SportId
			WHERE ossm.EventDate BETWEEN @PrevStartDate AND @PrevEndDate
				AND (sp.SportId IS NOT NULL)
				AND (@LiveType = -1 OR ossm.IsLive = @LiveType)
			GROUP BY ossm.EventDate
				,	ossm.SportId
				,	ossm.MatchId;

			DELETE	d
			FROM	#tmpWinlostDate AS d
			WHERE	d.winlostdate = @WinlostDate;
		END;
		
		SELECT 	ossm.EventDate
			,	SUM(ossm.MarketCount) AS MarketCount
		FROM  #OSSummaryMarket ossm WITH (NOLOCK)
		GROUP BY ossm.EventDate
		ORDER BY ossm.EventDate ASC;

		SELECT 	@StartFromDate AS FromDate 
			,	@StartToDate AS ToDate
			,	CAST(ISNULL(SUM(ossm.MarketCount),0) AS MONEY)/@Avg AS AvgMarketCount
		FROM	#OSSummaryMarket ossm WITH (NOLOCK)
		WHERE	ossm.EventDate BETWEEN @StartFromDate AND @EndToDate
		UNION 
		SELECT 	@PrevStartFromDate AS FromDate 
			,	@PrevStartToDate AS ToDate
			,	CAST(ISNULL(SUM(ossm.MarketCount),0) AS MONEY)/@Avg AS AvgMarketCount
		FROM	#OSSummaryMarket ossm WITH (NOLOCK)
		WHERE ossm.EventDate BETWEEN @PrevStartFromDate AND @PrevEndToDate

	END;

END;

GO
/*<info serverAlias="DBTGRS-bodb_TGRS" executers="bodbTGRSNet" isFunction="0" isNested="0"></info>*/