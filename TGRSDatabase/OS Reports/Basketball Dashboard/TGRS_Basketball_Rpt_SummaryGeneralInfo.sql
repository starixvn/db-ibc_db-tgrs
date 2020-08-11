ALTER PROCEDURE [dbo].[TGRS_Basketball_Rpt_SummaryGeneralInfo]  
		@FromDate			DATE
	,	@ToDate				DATE
	,	@ReportType			TINYINT = 1
AS    
/*  
 Created:	20200803@John.Ngo
 Task :		General Info of Basketball Summary Report
 DB:		DBTGRS.bodb_TGRS
 Original:  
  
 Revisions:      
		- 20200803@John.Ngo: Support Basketball Summary Data [Redmine ID: 138645]

 Param's Explanation (filtered by):
		- @ReportType = 1: By Date
					  = 2: By Month

 Exam: 
	EXEC TGRS_Basketball_Rpt_SummaryGeneralInfo @FromDate = '2020-05-01', @ToDate = '2020-07-31'
  
*/  
 
BEGIN 
	SET NOCOUNT ON

DECLARE @PrevFromDate		DATE
	,	@PrevToDate			DATE
	,	@Avg				INT

	SET @PrevFromDate = DATEADD(YYYY, -1, @FromDate);
	SET @PrevToDate   = DATEADD(YYYY, -1, @ToDate);

	IF	OBJECT_ID('tempdb..#MatchCountByDate') IS NOT NULL
	BEGIN;
		DROP TABLE #MatchCountByDate;
	END;

	CREATE TABLE #MatchCountByDate (
			EventDate		DATE
		,	MatchCount		INT
	);

	CREATE CLUSTERED INDEX	#CIX_MatchCountByDateIdx ON #MatchCountByDate (
								EventDate	ASC
							);
	
	IF	OBJECT_ID('tempdb..#SummaryGeneralInfo') IS NOT NULL
	BEGIN;
		DROP TABLE #SummaryGeneralInfo;
	END;

	CREATE TABLE #SummaryGeneralInfo (
			EventDate		DATE
		,	Turnover		MONEY
		,	WinLoss			MONEY
		,	MatchCount		INT
		,	BetCount		INT
		,	Margin			MONEY
	);

	CREATE CLUSTERED INDEX	#CIX_SummaryGeneralInfoIdx ON #SummaryGeneralInfo (
								EventDate	ASC
							);
	IF @ReportType	= 1  -- By Date 
	BEGIN
		SELECT @Avg = DATEDIFF(day, @FromDate, @ToDate) + 1;

		TRUNCATE TABLE #MatchCountByDate;
		INSERT INTO #MatchCountByDate(EventDate, MatchCount)
		SELECT  os.EventDate
			,	COUNT(DISTINCT os.MatchId) AS MatchCount
		FROM dbo.OSDataTGRS os WITH(NOLOCK)
		WHERE os.EventDate BETWEEN @FromDate AND @ToDate
			OR os.EventDate BETWEEN @PrevFromDate AND @PrevToDate
			AND os.SportId = 2
		GROUP BY os.EventDate;

		INSERT INTO #SummaryGeneralInfo (
				EventDate
			,	Turnover
			,	WinLoss
			,	MatchCount
			,	BetCount
			,	Margin)
		SELECT  os.EventDate
			,	ISNULL(SUM(os.Turnover),0) AS Turnover
			,	ISNULL(SUM(os.WinLoss),0) - ISNULL(SUM(os.Comm),0) AS WinLoss
			,	m.MatchCount AS MatchCount
			,	ISNULL(SUM(os.BetCount), 0) AS BetCount
			,	CASE WHEN ISNULL(SUM(os.Turnover),0) <> 0
					THEN (ISNULL(SUM(os.WinLoss),0) - ISNULL(SUM(os.Comm),0)) * 100/ISNULL(SUM(os.Turnover),0)
				ELSE NULL END AS Margin
		FROM	dbo.OSDataTGRS os WITH (NOLOCK)
			INNER JOIN #MatchCountByDate m ON os.EventDate = m.EventDate	
		WHERE os.EventDate BETWEEN @FromDate AND @ToDate
			AND os.SportId = 2
		GROUP BY os.EventDate, m.MatchCount;

		INSERT INTO #SummaryGeneralInfo (
				EventDate
			,	Turnover
			,	WinLoss
			,	MatchCount
			,	BetCount
			,	Margin)
		SELECT  os.EventDate
			,	ISNULL(SUM(os.Turnover),0) AS Turnover
			,	ISNULL(SUM(os.WinLoss),0) - ISNULL(SUM(os.Comm),0) AS WinLoss
			,	m.MatchCount AS MatchCount
			,	ISNULL(SUM(os.BetCount), 0) AS BetCount
			,	CASE WHEN ISNULL(SUM(os.Turnover),0) <> 0
					THEN (ISNULL(SUM(os.WinLoss),0) - ISNULL(SUM(os.Comm),0)) * 100/ISNULL(SUM(os.Turnover),0)
				ELSE NULL END AS Margin
		FROM	dbo.OSDataTGRS os WITH (NOLOCK)
			INNER JOIN #MatchCountByDate m ON os.EventDate = m.EventDate	
		WHERE os.EventDate BETWEEN @PrevFromDate AND @PrevToDate
			AND os.SportId = 2
		GROUP BY os.EventDate, m.MatchCount;

		SELECT 	sm.EventDate
			,	sm.Turnover
			,	sm.WinLoss
			,	sm.MatchCount
			,	sm.BetCount
			,	sm.Margin
		FROM  #SummaryGeneralInfo sm WITH (NOLOCK)
		ORDER BY sm.EventDate ASC;

		SELECT 	@FromDate AS FromDate 
			,	@ToDate AS ToDate
			,	ISNULL(SUM(sm.Turnover),0)/@Avg AS AvgTurnover
			,	ISNULL(SUM(sm.WinLoss),0)/@Avg AS AvgWinLoss
			,	ISNULL(SUM(sm.MatchCount),0)/@Avg AS AvgMatchCount
			,	ISNULL(SUM(sm.BetCount),0)/@Avg AS AvgBetCount
			,	CASE WHEN ISNULL(SUM(sm.Turnover),0) <> 0
					THEN (ISNULL(SUM(sm.WinLoss),0)) * 100/ISNULL(SUM(sm.Turnover),0)
				ELSE NULL END  AS AvgMargin
		FROM  #SummaryGeneralInfo sm WITH (NOLOCK)
		WHERE	sm.EventDate BETWEEN @FromDate AND @ToDate
		UNION 
		SELECT 	@PrevFromDate AS FromDate 
			,	@PrevToDate AS ToDate
			,	ISNULL(SUM(sm.Turnover),0)/@Avg AS AvgTurnover
			,	ISNULL(SUM(sm.WinLoss),0)/@Avg AS AvgWinLoss
			,	ISNULL(SUM(sm.MatchCount),0)/@Avg AS AvgMatchCount
			,	ISNULL(SUM(sm.BetCount),0)/@Avg AS AvgBetCount
			,	CASE WHEN ISNULL(SUM(sm.Turnover),0) <> 0
					THEN (ISNULL(SUM(sm.WinLoss),0)) * 100/ISNULL(SUM(sm.Turnover),0)
				ELSE NULL END  AS AvgMargin
		FROM  #SummaryGeneralInfo sm WITH (NOLOCK)
		WHERE sm.EventDate BETWEEN @PrevFromDate AND @PrevToDate
	END;

	IF @ReportType	= 2  -- By Month 
	BEGIN
		-- First of Month
		SET @FromDate = DATEADD(M, DATEDIFF(M, 0, @FromDate), 0);
		SET @ToDate = DATEADD(M, DATEDIFF(M, 0, @ToDate), 0);
		SET @PrevFromDate = DATEADD(M, DATEDIFF(M, 0, @PrevFromDate), 0);
		SET @PrevToDate = DATEADD(M, DATEDIFF(M, 0, @PrevToDate), 0);

		SELECT @Avg = DATEDIFF(MONTH, @FromDate, @ToDate) + 1;

		INSERT INTO #SummaryGeneralInfo (
				EventDate
			,	Turnover
			,	WinLoss
			,	MatchCount
			,	BetCount
			,	Margin)
		SELECT  sl.EventDate
			,	ISNULL(SUM(sl.Turnover), 0) AS Turnover
			,	ISNULL(SUM(sl.WinLoss), 0) - ISNULL(SUM(sl.Comm), 0) AS WinLoss
			,	ISNULL(SUM(sl.MatchCount), 0) AS MatchCount
			,	ISNULL(SUM(sl.BetCount), 0) AS BetCount
			,	CASE WHEN ISNULL(SUM(sl.Turnover),0) <> 0
					THEN (ISNULL(SUM(sl.WinLoss),0) - ISNULL(SUM(sl.Comm),0)) * 100/ISNULL(SUM(sl.Turnover),0)
				ELSE NULL END AS Margin	
		FROM dbo.OSSummaryByLeague_Monthly sl WITH (NOLOCK)
		WHERE sl.EventDate BETWEEN @FromDate AND @ToDate
			AND sl.SportId = 2
		GROUP BY sl.EventDate;

		INSERT INTO #SummaryGeneralInfo (
				EventDate
			,	Turnover
			,	WinLoss
			,	MatchCount
			,	BetCount
			,	Margin)
		SELECT  sl.EventDate
			,	ISNULL(SUM(sl.Turnover), 0) AS Turnover
			,	ISNULL(SUM(sl.WinLoss), 0) - ISNULL(SUM(sl.Comm), 0) AS WinLoss
			,	ISNULL(SUM(sl.MatchCount), 0) AS MatchCount
			,	ISNULL(SUM(sl.BetCount), 0) AS BetCount
			,	CASE WHEN ISNULL(SUM(sl.Turnover),0) <> 0
					THEN (ISNULL(SUM(sl.WinLoss),0) - ISNULL(SUM(sl.Comm),0)) * 100/ISNULL(SUM(sl.Turnover),0)
				ELSE NULL END AS Margin	
		FROM dbo.OSSummaryByLeague_Monthly sl WITH (NOLOCK)
		WHERE sl.EventDate BETWEEN @PrevFromDate AND @PrevToDate
			AND sl.SportId = 2
		GROUP BY sl.EventDate;
		SELECT 	EventDate
			,	Turnover
			,	WinLoss
			,	MatchCount
			,	BetCount
			,	Margin
		FROM  #SummaryGeneralInfo WITH (NOLOCK)
		ORDER BY EventDate ASC;

		SELECT 	@FromDate AS FromDate 
			,	@ToDate AS ToDate
			,	ISNULL(SUM(sm.Turnover),0)/@Avg AS AvgTurnover
			,	ISNULL(SUM(sm.WinLoss),0)/@Avg AS AvgWinLoss
			,	ISNULL(SUM(sm.MatchCount),0)/@Avg AS AvgMatchCount
			,	ISNULL(SUM(sm.BetCount),0)/@Avg AS AvgBetCount
			,	CASE WHEN ISNULL(SUM(sm.Turnover),0) <> 0
					THEN (ISNULL(SUM(sm.WinLoss),0)) * 100/ISNULL(SUM(sm.Turnover),0)
				ELSE NULL END  AS AvgMargin
		FROM  #SummaryGeneralInfo sm WITH (NOLOCK)
		WHERE sm.EventDate BETWEEN @FromDate AND @ToDate
		UNION 
		SELECT 	@PrevFromDate AS FromDate 
			,	@PrevToDate AS ToDate
			,	ISNULL(SUM(sm.Turnover),0)/@Avg AS AvgTurnover
			,	ISNULL(SUM(sm.WinLoss),0)/@Avg AS AvgWinLoss
			,	ISNULL(SUM(sm.MatchCount),0)/@Avg AS AvgMatchCount
			,	ISNULL(SUM(sm.BetCount),0)/@Avg AS AvgBetCount
			,	CASE WHEN ISNULL(SUM(sm.Turnover),0) <> 0
					THEN (ISNULL(SUM(sm.WinLoss),0)) * 100/ISNULL(SUM(sm.Turnover),0)
				ELSE NULL END  AS AvgMargin
		FROM  #SummaryGeneralInfo sm WITH (NOLOCK)
		WHERE sm.EventDate BETWEEN @PrevFromDate AND @PrevToDate

	END;
END;

GO
/*<info serverAlias="DBTGRS-bodb_TGRS" executers="bodbTGRSNet" isFunction="0" isNested="0"></info>*/