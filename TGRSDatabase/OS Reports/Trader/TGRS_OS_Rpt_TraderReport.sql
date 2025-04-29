ALTER PROCEDURE [dbo].[TGRS_OS_Rpt_TraderReport]
		@TraderName 		NVARCHAR(50)
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
		- @ReportType = 1: Daily; 2: Monthly
		- @ViewPermission = 0: all bet types
				 = 1: major bet types
				 = 2: PHAIO bet types
		- @LiveType: -1 All; 0 Nonlive; 1 Live
	Exam:
*/
BEGIN
	SET NOCOUNT ON;

	-- INIT	 
	DECLARE @TraderId		INT;

	SELECT @TraderId = t.TraderId
	FROM dbo.OSTrader AS t WITH(NOLOCK)
	WHERE t.TraderName = @TraderName;

	-- START
	IF @ReportType = 1
	BEGIN
		SELECT	[TraderId]		= @TraderId
			,	[Turnover]		= ISNULL(SUM(t.Turnover), 0)
			,	[WinLost]		= ISNULL(SUM(t.Winloss), 0) - ISNULL(SUM(t.Comm), 0)
			,	[Margin]		= CASE WHEN ISNULL(SUM(t.Turnover), 0) <> 0 THEN (ISNULL(SUM(t.Winloss), 0) - ISNULL(SUM(t.Comm), 0))* 100/SUM(t.Turnover) ELSE NULL END
			,	[SportCount]	= ISNULL(COUNT(DISTINCT t.SportId), 0)
			,	[BetCount]		= SUM(t.BetCount)
		FROM dbo.OSSummaryByTrader_Daily AS t WITH(NOLOCK)
		WHERE t.EventDate BETWEEN @FromDate AND @ToDate
			AND t.TraderId = @TraderId
			AND (@LiveType = -1 OR t.IsLive = @LiveType)
	END;
	ELSE
	BEGIN
		SELECT	[TraderId]		= @TraderId
			,	[Turnover]		= ISNULL(SUM(t.Turnover), 0)
			,	[WinLost]		= ISNULL(SUM(t.Winloss), 0) - ISNULL(SUM(t.Comm), 0)
			,	[Margin]		= CASE WHEN ISNULL(SUM(t.Turnover), 0) <> 0 THEN (ISNULL(SUM(t.Winloss), 0) - ISNULL(SUM(t.Comm), 0))* 100/SUM(t.Turnover) ELSE NULL END
			,	[SportCount]	= ISNULL(COUNT(DISTINCT t.SportId), 0)
			,	[BetCount]		= SUM(t.BetCount)
		FROM dbo.OSSummaryByTrader_Monthly AS t WITH(NOLOCK)
		WHERE t.EventDate BETWEEN @FromDate AND @ToDate
			AND t.TraderId = @TraderId
			AND (@LiveType = -1 OR t.IsLive = @LiveType)
	END;
END;

GO
/*<info serverAlias="DBTGRS-bodb_TGRS" executers="wsv_tgrs" isFunction="0" isNested="0"></info>*/