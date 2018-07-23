
SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

ALTER PROCEDURE [dbo].[TGRS_OS_Rpt_SportPerformance_Region]
		@ReportType			TINYINT = 1
	,	@SportId			INT
	,	@TraderId			INT
	,	@FromDate			DATE
	,	@ToDate				DATE
AS	
/*
	Created: 20180720@Long
	Task : Get OS Region Performance
	DB:  DBTGRS.bodb_TGRS

	Revisions:

*/

BEGIN
	SET NOCOUNT ON;

	IF @ReportType = 1
	BEGIN
		SELECT	r.RegionName
			,	SUM(tp.Turnover) AS Turnover
			,	SUM(tp.Winloss - tp.Comm) AS Winloss
			,	SUM(tp.MatchCount) AS EventProductCount
			,	(SUM(tp.Winloss - tp.Comm) * 100 / SUM(tp.Turnover)) AS Margin
		FROM dbo.OSSummaryByTrader_Daily AS tp WITH (NOLOCK)
			LEFT JOIN dbo.OSLeagueRegion AS lr WITH (NOLOCK) ON tp.LeagueId = lr.LeagueId
			LEFT JOIN dbo.OSRegion AS r WITH (NOLOCK) ON r.RegionId = lr.RegionId
		WHERE tp.EventDate BETWEEN @FromDate AND @ToDate
			AND (@TraderId = -1 OR tp.TraderId = @TraderId)
			AND tp.SportId = @SportId	
		GROUP BY r.RegionName;
	END
	ELSE IF @ReportType = 2
	BEGIN
		SELECT	r.RegionName
			,	SUM(tp.Turnover) AS Turnover
			,	SUM(tp.Winloss - tp.Comm) AS Winloss
			,	SUM(tp.MatchCount) AS EventProductCount
			,	(SUM(tp.Winloss - tp.Comm) * 100 / SUM(tp.Turnover)) AS Margin
		FROM dbo.OSSummaryByTrader_Monthly AS tp WITH (NOLOCK)
			LEFT JOIN dbo.OSLeagueRegion AS lr WITH (NOLOCK) ON tp.LeagueId = lr.LeagueId
			LEFT JOIN dbo.OSRegion AS r WITH (NOLOCK) ON r.RegionId = lr.RegionId
		WHERE tp.EventDate BETWEEN @FromDate AND @ToDate
			AND (@TraderId = -1 OR tp.TraderId = @TraderId)
			AND tp.SportId = @SportId
		GROUP BY r.RegionName;
	END;
END;

/* 
GO
GRANT EXECUTE ON [dbo].[TGRS_OS_Rpt_SportPerformance_Region] TO [bodbTGRSNet]
GO
GRANT VIEW DEFINITION ON [dbo].[TGRS_OS_Rpt_SportPerformance_Region] TO [bodbTGRSNet]
GO
*/
