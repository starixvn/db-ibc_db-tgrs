/*<info serverAlias="DBTGRS-bodb_TGRS" executers="wsv_tgrs" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[TGRS_OS_Rpt_SportPerformance_Region]
		@ReportType			TINYINT = 1
	,	@SportId			INT
	,	@TraderId			INT
	,	@FromDate			DATE
	,	@ToDate				DATE
	,	@LiveType			SMALLINT = -1
AS	
/*
	Created: 20180720@Long
	Task : Get OS Region Performance
	DB:  DBTGRS.bodb_TGRS
	Original:

	Revisions:
		- 20181030@Long: Adding Betcount column to OS's reports [Redmine ID: #101741]
		- 20200914@John.Ngo: Support Live/Nonlive for OSDataTGRS [Redmine ID: #140875]
		- 20250513@Della: Fix default param @LiveType (#225204)

	Param's Explanation (filtered by):
		- @LiveType: -1 All; 0 Nonlive; 1 Live

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
			,	SUM(tp.BetCount) AS BetCount
		FROM dbo.OSSummaryByTrader_Daily AS tp WITH (NOLOCK)
			LEFT JOIN dbo.OSLeagueRegion AS lr WITH (NOLOCK) ON tp.LeagueId = lr.LeagueId
			LEFT JOIN dbo.OSRegion AS r WITH (NOLOCK) ON r.RegionId = lr.RegionId
		WHERE tp.EventDate BETWEEN @FromDate AND @ToDate
			AND (@TraderId = -1 OR tp.TraderId = @TraderId)
			AND tp.SportId = @SportId
			AND (@LiveType = -1 OR tp.IsLive = @LiveType)
		GROUP BY r.RegionName;
	END;
	ELSE IF @ReportType = 2
	BEGIN
		SELECT	r.RegionName
			,	SUM(tp.Turnover) AS Turnover
			,	SUM(tp.Winloss - tp.Comm) AS Winloss
			,	SUM(tp.MatchCount) AS EventProductCount
			,	(SUM(tp.Winloss - tp.Comm) * 100 / SUM(tp.Turnover)) AS Margin
			,	SUM(tp.BetCount) AS BetCount
		FROM dbo.OSSummaryByTrader_Monthly AS tp WITH (NOLOCK)
			LEFT JOIN dbo.OSLeagueRegion AS lr WITH (NOLOCK) ON tp.LeagueId = lr.LeagueId
			LEFT JOIN dbo.OSRegion AS r WITH (NOLOCK) ON r.RegionId = lr.RegionId
		WHERE tp.EventDate BETWEEN @FromDate AND @ToDate
			AND (@TraderId = -1 OR tp.TraderId = @TraderId)
			AND tp.SportId = @SportId
			AND (@LiveType = -1 OR tp.IsLive = @LiveType)
		GROUP BY r.RegionName;
	END;
END;

GO
/*<info serverAlias="DBTGRS-bodb_TGRS" executers="bodbTGRSNet" isFunction="0" isNested="0"></info>*/