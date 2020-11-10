ALTER PROCEDURE [dbo].[TGRS_OS_Rpt_SummaryLeaguePerformance] 
		@FromDate		DATE
	,	@ToDate			DATE
	,	@SportIds		VARCHAR(2000) =  ''
	,	@ReportType		TINYINT  = 1
	,	@LiveType		SMALLINT = 1
AS    
/*  
 Created:	20201109@John.Ngo
 Task :		Summary League Performance Report
 DB:		DBTGRS.bodb_TGRS
 Original:  
  
 Revisions:      
		- 20201109@John.Ngo: Summary League Performance Report [Redmine ID: 139739]

 Param's Explanation (filtered by):
		- @ReportType = 1: By Date
					  = 2: By Month
		- @LiveType: -1 All; 0 Nonlive; 1 Live

 Exam: 
	EXEC TGRS_OS_Rpt_SummaryLeaguePerformance @FromDate = '2020-05-01', @ToDate = '2020-07-31'
  
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
		SELECT  L.LeagueId
			,	L.LeagueName
			,	ISNULL(SUM(os.Turnover),0) AS Turnover
			,	ISNULL(SUM(os.Winloss),0) - ISNULL(SUM(os.Comm),0) AS WinLoss
			,	CASE WHEN ISNULL(SUM(os.Turnover),0) <> 0
					THEN (ISNULL(SUM(os.Winloss),0) - ISNULL(SUM(os.Comm),0))*100 /ISNULL(SUM(os.Turnover),0)
				ELSE NULL END AS Margin
		FROM	dbo.OSDataTGRS os WITH (NOLOCK)
			INNER JOIN	bodb02.dbo.League L WITH (NOLOCK) ON os.LeagueId = L.LeagueId
			LEFT JOIN @Sports AS sp ON sp.SportId = os.SportId
		WHERE os.EventDate BETWEEN @FromDate AND @ToDate
			AND (sp.SportId IS NOT NULL)
			AND (@LiveType = -1 OR os.IsLive = @LiveType)
		GROUP BY L.LeagueId, L.LeagueName
		ORDER BY Margin ASC

	END;

	IF @ReportType	= 2  -- By Month 
	BEGIN
		-- First of Month
		SET @FromDate = DATEADD(m, DATEDIFF(m, 0, @FromDate), 0);
		SET @ToDate = DATEADD(m, DATEDIFF(m, 0, @ToDate), 0);

		SELECT  L.LeagueId
			,	L.LeagueName
			,	ISNULL(SUM(sm.Turnover),0) AS Turnover
			,	ISNULL(SUM(sm.Winloss),0) - ISNULL(SUM(sm.Comm),0) AS WinLoss
			,	CASE WHEN ISNULL(SUM(sm.Turnover),0) <> 0
					THEN (ISNULL(SUM(sm.Winloss),0) - ISNULL(SUM(sm.Comm),0))*100 /ISNULL(SUM(sm.Turnover),0)
				ELSE NULL END AS Margin
		FROM	dbo.OSSummaryByLeague_Monthly sm WITH (NOLOCK)
			INNER JOIN	bodb02.dbo.League L WITH (NOLOCK) ON sm.LeagueId = L.LeagueId
			LEFT JOIN @Sports AS sp ON sp.SportId = sm.SportId
		WHERE sm.EventDate BETWEEN @FromDate AND @ToDate
			AND (sp.SportId IS NOT NULL)
			AND (@LiveType = -1 OR sm.IsLive = @LiveType)
		GROUP BY L.LeagueId, L.LeagueName
		ORDER BY Margin ASC

	END;
END;

GO
/*<info serverAlias="DBTGRS-bodb_TGRS" executers="bodbTGRSNet" isFunction="0" isNested="0"></info>*/