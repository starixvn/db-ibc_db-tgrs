ALTER PROCEDURE [dbo].[TGRS_Basketball_Rpt_SummaryLeagueGroupPerformance] 
		@FromDate		DATE
	,	@ToDate			DATE
	,	@ReportType		TINYINT = 1
AS    
/*  
 Created:	20200805@John.Ngo
 Task :		Summary LeagueGroup Performance Report
 DB:		DBTGRS.bodb_TGRS
 Original:  
  
 Revisions:      
		- 20200803@John.Ngo: Summary LeagueGroup Performance Report [Redmine ID: 138645]

 Param's Explanation (filtered by):
		- @ReportType = 1: By Date
					  = 2: By Month

 Exam: 
	EXEC TGRS_Basketball_Rpt_SummaryLeagueGroupPerformance @FromDate = '2020-05-01', @ToDate = '2020-07-31'
  
*/
BEGIN
	SET NOCOUNT ON;
	
	IF	OBJECT_ID('tempdb..#SummaryByLeagueGroup') IS NOT NULL
	BEGIN;
		DROP TABLE #SummaryByLeagueGroup;
	END;

	CREATE TABLE #SummaryByLeagueGroup (
			LeagueGroupId	INT
		,	Turnover		MONEY
		,	WinLoss			MONEY
		,	Margin			MONEY
	);

	CREATE CLUSTERED INDEX	#CIX_SummaryByLeagueGroupIdx ON #SummaryByLeagueGroup (
								LeagueGroupId	ASC
							);
		
	IF @ReportType	= 1  -- By Date 
	BEGIN
		INSERT INTO #SummaryByLeagueGroup (LeagueGroupId, Turnover,	WinLoss, Margin)
		SELECT  L.LeagueGroupId
			,	ISNULL(SUM(os.Turnover),0) AS Turnover
			,	ISNULL(SUM(os.Winloss),0) - ISNULL(SUM(os.Comm),0) AS WinLoss
			,	CASE WHEN ISNULL(SUM(os.Turnover),0) <> 0
					THEN (ISNULL(SUM(os.Winloss),0) - ISNULL(SUM(os.Comm),0))*100 /ISNULL(SUM(os.Turnover),0)
				ELSE NULL END AS Margin
		FROM	dbo.OSDataTGRS os WITH (NOLOCK)
			INNER JOIN	bodb02.dbo.League L WITH (NOLOCK) ON os.LeagueId = L.LeagueId
		WHERE os.EventDate BETWEEN @FromDate AND @ToDate
			AND os.SportId = 2
		GROUP BY L.LeagueGroupId
		
		SELECT  lg.GroupID
			,	lg.GroupName
			,	ml.Turnover
			,	ml.WinLoss
			,	ml.Margin
		FROM	#SummaryByLeagueGroup ml WITH (NOLOCK)
			INNER JOIN	bodb02.dbo.LeagueGroup lg WITH (NOLOCK) ON ml.LeagueGroupId = lg.GroupID
		ORDER BY Margin ASC
	END;

	IF @ReportType	= 2  -- By Month 
	BEGIN
		-- First of Month
		SET @FromDate = DATEADD(m, DATEDIFF(m, 0, @FromDate), 0);
		SET @ToDate = DATEADD(m, DATEDIFF(m, 0, @ToDate), 0);

		INSERT INTO #SummaryByLeagueGroup (LeagueGroupId, Turnover,	WinLoss, Margin)
		SELECT  L.LeagueGroupId
			,	ISNULL(SUM(sm.Turnover),0) AS Turnover
			,	ISNULL(SUM(sm.Winloss),0) - ISNULL(SUM(sm.Comm),0) AS WinLoss
			,	CASE WHEN ISNULL(SUM(sm.Turnover),0) <> 0
					THEN (ISNULL(SUM(sm.Winloss),0) - ISNULL(SUM(sm.Comm),0))*100 /ISNULL(SUM(sm.Turnover),0)
				ELSE NULL END AS Margin
		FROM	dbo.OSSummaryByLeague_Monthly sm WITH (NOLOCK)
			INNER JOIN	bodb02.dbo.League L WITH (NOLOCK) ON sm.LeagueId = L.LeagueId
		WHERE sm.EventDate BETWEEN @FromDate AND @ToDate
			AND sm.SportId = 2
		GROUP BY L.LeagueGroupId

		SELECT  lg.GroupID
			,	lg.GroupName
			,	ml.Turnover
			,	ml.WinLoss
			,	ml.Margin
		FROM	#SummaryByLeagueGroup ml WITH (NOLOCK)
			INNER JOIN	bodb02.dbo.LeagueGroup lg WITH (NOLOCK) ON ml.LeagueGroupId = lg.GroupID
		ORDER BY Margin ASC
	END;
END;

GO
/*<info serverAlias="DBTGRS-bodb_TGRS" executers="bodbTGRSNet" isFunction="0" isNested="0"></info>*/