SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[TGRS_OS_Rpt_TraderReport_Chart]
		@TraderName 		NVARCHAR(50)
	,	@ReportType 		TINYINT = 1
	,	@FromDate 			DATETIME
	,	@ToDate 			DATETIME
	,	@ViewPermission		SMALLINT
AS
/*
	Creator: Long
	Date: 2018-07-19
	Task: Trader's Report for Other Sports
	DB: DBTGRS.bodb_TGRS

	Revisions:

	Param's Explanation:
		@ReportType:
			1: by date
			2: by month
			
		@ViewPermission = 0: all bet types
				 = 1: major bet types
				 = 2: PHAIO bet types
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
		SELECT	[WLDate]	= t.EventDate
			,	[Turnover]	= ISNULL(SUM(t.Turnover), 0)
			,	[WinLost]	= ISNULL(SUM(t.Winloss), 0) - ISNULL(SUM(t.Comm), 0)
		FROM dbo.OSSummaryByTrader_Daily AS t WITH(NOLOCK)
		WHERE t.TraderId = @TraderId
			AND t.EventDate BETWEEN @FromDate AND @ToDate 
		GROUP BY t.EventDate;
	END  
	ELSE
	BEGIN  
		SELECT	[WLDate]	= t.EventDate
			,	[Turnover]	= ISNULL(SUM(t.Turnover), 0)
			,	[WinLost]	= ISNULL(SUM(t.Winloss), 0) - ISNULL(SUM(t.Comm), 0)
		FROM dbo.OSSummaryByTrader_Monthly AS t WITH(NOLOCK)
		WHERE t.TraderId = @TraderId
			AND t.EventDate BETWEEN @FromDate AND @ToDate 
		GROUP BY t.EventDate;
	END;
END;

/* 
GO
GRANT EXECUTE ON [dbo].[TGRS_OS_Rpt_TraderReport_Chart] TO [bodbTGRSNet]
GO
GRANT VIEW DEFINITION ON [dbo].[TGRS_OS_Rpt_TraderReport_Chart] TO [bodbTGRSNet]
GO
*/