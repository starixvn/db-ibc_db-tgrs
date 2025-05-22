/*<info serverAlias="DBTGRS-bodb_TGRS" executers="wsv_tgrs" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[TGRS_OS_Rpt_NewSportPerformance_Region]
		@ReportType		TINYINT = 1
	,	@FromDate		DATE
	,	@ToDate			DATE
	,	@SportId		INT
	,	@LiveType		SMALLINT = -1
AS
/*
	Created: 20170403@Aaron
	Task : Get new OS Region Performance
	DB:  DBTGRS.bodb_TGRS
	Original:

	Revisions:
		- 20181030@Long: Adding Betcount column to OS's reports [Redmine ID: #101741]
		- 20200914@John.Ngo: Support Live/Nonlive for OSDataTGRS [Redmine ID: #140875]
		- 20250514@Della: Fix default param @LiveType (#225204)

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
			,	SUM(tp.StakeMYRJuice) AS JuiceTurnover
			,	SUM(tp.Juice) AS JuiceWinloss
			,	SUM(tp.BetCount) AS BetCount
		FROM dbo.OSSummaryByTrader_Daily tp WITH (NOLOCK)
			LEFT JOIN dbo.OSLeagueRegion lr WITH (NOLOCK) ON tp.LeagueId = lr.LeagueId
			LEFT JOIN dbo.OSRegion r WITH (NOLOCK) ON r.RegionId = lr.RegionId
		WHERE tp.EventDate BETWEEN @FromDate AND @ToDate
			 AND tp.SportId = @SportId
			 AND tp.BettypeId IN(1,2,3,7,8,12)
			 AND (@LiveType = -1 OR tp.IsLive = @LiveType)
		GROUP BY r.RegionName;
	END
	ELSE IF @ReportType = 2
	BEGIN
		SELECT	r.RegionName
			,	SUM(tp.Turnover) AS Turnover
			,	SUM(tp.Winloss - tp.Comm) AS Winloss
			,	SUM(tp.MatchCount) AS EventProductCount
			,	SUM(tp.StakeMYRJuice) AS JuiceTurnover
			,	SUM(tp.Juice) AS JuiceWinloss
			,	SUM(tp.BetCount) AS BetCount
		FROM dbo.OSSummaryByTrader_Monthly tp WITH (NOLOCK)
			LEFT JOIN dbo.OSLeagueRegion lr WITH (NOLOCK) ON tp.LeagueId = lr.LeagueId
			LEFT JOIN dbo.OSRegion r WITH (NOLOCK) ON r.RegionId = lr.RegionId
		WHERE tp.EventDate BETWEEN @FromDate AND @ToDate
			 AND tp.SportId = @SportId
			 AND tp.BettypeId IN (1,2,3,7,8,12)
			 AND (@LiveType = -1 OR tp.IsLive = @LiveType)
		GROUP BY r.RegionName;
	END;
END;

GO
/*<info serverAlias="DBTGRS-bodb_TGRS" executers="bodbTGRSNet" isFunction="0" isNested="0"></info>*/