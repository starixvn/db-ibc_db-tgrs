ALTER PROCEDURE [dbo].[TGRS_OS_Rpt_SummarySportPerformance] 
		@FromDate		DATE
	,	@ToDate			DATE
	,	@SportIds		VARCHAR(2000) =  ''
	,	@ReportType		TINYINT  = 1
	,	@LiveType		SMALLINT = 1
AS    
/*  
 Created:	20201109@John.Ngo
 Task :		Summary OtherSports Sport Performance Report
 DB:		DBTGRS.bodb_TGRS
 Original:  
  
 Revisions:      
		- 20201109@John.Ngo: Summary OtherSports Trader Performance Report [Redmine ID: 139739]

 Param's Explanation (filtered by):
		- @ReportType = 1: By Date
					  = 2: By Month
		- @LiveType: -1 All; 0 Nonlive; 1 Live

 Exam: 
	EXEC TGRS_OS_Rpt_SummarySportPerformance @FromDate = '2020-05-01', @ToDate = '2020-07-31'
  
*/ 

BEGIN
	SET NOCOUNT ON;

	IF @SportIds <> ''
	BEGIN
		DECLARE @Sports AS TABLE (SportId SMALLINT PRIMARY KEY CLUSTERED);
		INSERT INTO @Sports(SportId)
		SELECT val FROM dbo.strSplit_Key(@SportIds,',');
	END;

	IF @ReportType	= 1  -- By Date 
	BEGIN
		SELECT s.SportType AS SportId
			,	s.SportName AS SportName
			,	ISNULL(SUM(os.Turnover), 0) AS Turnover
			,	ISNULL(SUM(os.WinLoss), 0) - ISNULL(SUM(os.Comm), 0) AS WinLoss
			,	CASE WHEN ISNULL(SUM(os.Turnover),0) <> 0
					THEN (ISNULL(SUM(os.WinLoss),0) - ISNULL(SUM(os.Comm),0)) * 100/ISNULL(SUM(os.Turnover),0)
				ELSE NULL END AS Margin
		FROM dbo.OSDataTGRS os WITH (NOLOCK)
			INNER JOIN bodb02.dbo.Sports s WITH(NOLOCK) ON os.SportId = s.SportType
			LEFT JOIN @Sports AS sp ON sp.SportId = s.SportType
		WHERE os.EventDate BETWEEN @FromDate AND @ToDate
			AND (sp.SportId IS NOT NULL)
			AND (@LiveType = -1 OR os.IsLive = @LiveType)
		GROUP BY s.SportType, s.SportName
		ORDER BY 
			CASE WHEN ISNULL(SUM(os.Turnover), 0) <> 0
				THEN (ISNULL(SUM(os.WinLoss), 0) - ISNULL(SUM(os.Comm), 0)) / ISNULL(SUM(os.Turnover), 0)
			ELSE NULL END ASC;
	END;

	IF @ReportType	= 2  -- By Month 
	BEGIN
		-- First of Month
		SET @FromDate = DATEADD(m, DATEDIFF(m, 0, @FromDate), 0);
		SET @ToDate = DATEADD(m, DATEDIFF(m, 0, @ToDate), 0);

		SELECT s.SportType AS SportId
			,	s.SportName AS SportName
			,	ISNULL(SUM(sm.Turnover), 0) AS Turnover
			,	ISNULL(SUM(sm.WinLoss), 0) - ISNULL(SUM(sm.Comm), 0) AS WinLoss
			,	CASE WHEN ISNULL(SUM(sm.Turnover),0) <> 0 
					THEN (ISNULL(SUM(sm.WinLoss),0) - ISNULL(SUM(sm.Comm),0)) * 100/ISNULL(SUM(sm.Turnover),0) 
				ELSE NULL END AS Margin
		FROM dbo.OSSummaryByTrader_Monthly sm WITH (NOLOCK)
			INNER JOIN bodb02.dbo.Sports s WITH(NOLOCK) ON sm.SportId = s.SportType
			LEFT JOIN @Sports AS sp ON sp.SportId = s.SportType
		WHERE sm.EventDate BETWEEN @FromDate AND @ToDate
			AND ( sp.SportId IS NOT NULL)
			AND (@LiveType = -1 OR sm.IsLive = @LiveType)
		GROUP BY s.SportType, s.SportName
		ORDER BY 			
			CASE WHEN ISNULL(SUM(sm.Turnover), 0) <> 0
				THEN (ISNULL(SUM(sm.WinLoss), 0) - ISNULL(SUM(sm.Comm), 0)) / ISNULL(SUM(sm.Turnover), 0)
			ELSE NULL END ASC;
	END;
END;

GO
/*<info serverAlias="DBTGRS-bodb_TGRS" executers="bodbTGRSNet" isFunction="0" isNested="0"></info>*/