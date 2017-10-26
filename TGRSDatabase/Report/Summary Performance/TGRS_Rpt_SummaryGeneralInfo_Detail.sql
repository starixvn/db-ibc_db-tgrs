ALTER PROCEDURE [dbo].[TGRS_Rpt_SummaryGeneralInfo_Detail]  
	@ReportType			TINYINT = 2,
	@FromDate			DATE,
	@ToDate				DATE,
	@ViewPermission		SMALLINT
AS    
/*  
 Created:	20141211@Sophia
 Task :		General Info of Summary report detail by Month/ Date
 DB:		DBTGRS/bodb_TGRS
 Original:  
  
 Revisions:      
	- 20171024@Simon: Add ViewPermission param 
	- 20171025@Long: change the way to get MatchCount
   			
 Param's Explanation:  
	@ReportType = 1: by Date
			 = 2: By Month
			 = 3: By Year
			 
	@ViewPermission = 0: all bet types
			 = 1: major bet types
			 = 2: PHAIO bet types

 Exam: 
	EXEC TGRS_Rpt_SummaryGeneralInfo_Detail @FromDate = '2014-05-01', @ToDate = '2014-12-01',  @ReportType = 2
	
	EXEC TGRS_Rpt_SummaryGeneralInfo_Detail @FromDate = '2014-05-01', @ToDate = '2014-12-01',  @ReportType = 1

*/  
 
BEGIN 
	SET NOCOUNT ON  

	IF	OBJECT_ID('tempdb..#MatchCountByDate') IS NOT NULL
	BEGIN;
		DROP TABLE #MatchCountByDate;
	END;

	CREATE TABLE #MatchCountByDate (
		EventDate		DATE, 
		MatchCount		BIGINT
	);

	CREATE CLUSTERED INDEX	#CIX_MatchCountByDateIdx ON #MatchCountByDate (
								EventDate	ASC
							);

	INSERT INTO #MatchCountByDate(
			EventDate
		,	MatchCount
	)
	SELECT bm.EventDate
		,	COUNT_BIG(bm.MatchCount) AS MatchCount
	FROM dbo.SummaryByBetType_Monthly bm WITH(NOLOCK)
		INNER JOIN dbo.BetType bt WITH(NOLOCK) on bm.BetType = bt.BetType
	WHERE bm.EventDate BETWEEN @FromDate AND @ToDate
		AND (
				@ViewPermission = 0
				OR bt.BettypeGroup = @ViewPermission
			)
	GROUP BY bm.EventDate


	IF @ReportType = 2
	BEGIN 
		SELECT  S.EventDate,
				ISNULL(SUM(Stake),0) AS Turnover,  
				ISNULL(SUM(WinLost),0) - ISNULL(SUM(Comm),0) AS WinLost,  
				CASE WHEN ISNULL(SUM(Stake),0) <> 0 THEN (ISNULL(SUM(WinLost),0) - ISNULL(SUM(Comm),0)) * 100/ISNULL(SUM(Stake),0) ELSE NULL END AS Margin, 
				m.MatchCount AS MatchCount
		FROM	dbo.SummaryByLeague_Monthly S WITH (NOLOCK)	
			INNER JOIN #MatchCountByDate m ON S.EventDate = m.EventDate		
		WHERE	
			S.EventDate BETWEEN @FromDate AND @ToDate	
			AND (
					@ViewPermission = 0
					OR BettypeGroup = @ViewPermission
				)
		GROUP BY S.EventDate
	END	
	ELSE 
	BEGIN 
		SELECT  S.EventDate,
				ISNULL(SUM(Stake),0) AS Turnover,  
				ISNULL(SUM(WinLost),0) - ISNULL(SUM(Comm),0) AS WinLost,  
				CASE WHEN ISNULL(SUM(Stake),0) <> 0 THEN (ISNULL(SUM(WinLost),0) - ISNULL(SUM(Comm),0)) * 100/ISNULL(SUM(Stake),0) ELSE NULL END AS Margin, 
				m.MatchCount AS MatchCount
		FROM	dbo.SummaryByLeague_Daily S WITH (NOLOCK)	
			INNER JOIN #MatchCountByDate m ON S.EventDate = m.EventDate	
		WHERE	S.EventDate BETWEEN @FromDate AND @ToDate	
			AND (
					@ViewPermission = 0
					OR BettypeGroup = @ViewPermission
				)
		GROUP BY S.EventDate, m.MatchCount
	END 

END 
GO
GRANT EXECUTE ON [dbo].[TGRS_Rpt_SummaryGeneralInfo_Detail] TO [bodbTGRSNet]
GO

