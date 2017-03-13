
SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

/****** Object:  Stored Procedure dbo.TGRS_OS_Rpt_TraderPerformance    Script Date: 3/7/2017 3:10:48 PM ******/

CREATE PROCEDURE [dbo].[TGRS_OS_Rpt_TraderPerformance]
	 @ReportType TINYINT = 1
	,@TraderName NVARCHAR(50) = NULL
	,@FromDate DATE = '2016-01-01'
	,@ToDate DATE = '2017-12-31'

/*
Created: 20160810@Aaron
Task : Get OS Trader Performance
DB:  DBTGRS.bodb_TGRS

Revisions:
			- 20170307@Aaron: Added @ReportType and calculate the score by league

*/
AS
BEGIN
	SET NOCOUNT ON

	DECLARE @IncrementTimes DECIMAL(18, 2)
		,@IncrementValue DECIMAL(18, 2)
		,@FloorMark DECIMAL(18, 2)

	SELECT @IncrementTimes = ParamValue
	FROM [bodb_TGRS].[dbo].[OSParameter] WITH (NOLOCK)
	WHERE ParamId = 3

	SELECT @IncrementValue = ParamValue
	FROM [bodb_TGRS].[dbo].[OSParameter] WITH (NOLOCK)
	WHERE ParamId = 5

	SELECT @FloorMark = ParamValue
	FROM [bodb_TGRS].[dbo].[OSParameter] WITH (NOLOCK)
	WHERE ParamId = 7

	IF OBJECT_ID('tempdb..#TraderPerformanceDetail') IS NOT NULL
	BEGIN
		DROP TABLE #TraderPerformanceDetail
	END

	CREATE TABLE #TraderPerformanceDetail (
		TraderId INT
		,SportId INT
		,LeagueId INT
		,BettypeId INT
		,Turnover MONEY
		,WinLoss MONEY
		,EventProductCount INT
		,Target DECIMAL(18,4)
		)
		
	IF OBJECT_ID('tempdb..#TraderPerformanceDetailByBettype') IS NOT NULL
	BEGIN
		DROP TABLE #TraderPerformanceDetailByBettype
	END

	CREATE TABLE #TraderPerformanceDetailByBettype (
		TraderId INT
		,SportId INT
		,BettypeId INT
		,Turnover MONEY
		,WinLoss MONEY
		,Point MONEY
		,EventProductCount INT
		)		

	IF OBJECT_ID('tempdb..#TraderPerformanceDetailBySport') IS NOT NULL
	BEGIN
		DROP TABLE #TraderPerformanceDetailBySport
	END

	CREATE TABLE #TraderPerformanceDetailBySport (
		TraderId INT
		,SportId INT
		,Turnover MONEY
		,WinLoss MONEY
		,Point MONEY
		,EventProductCount INT
		)
	
	IF @ReportType = 1
	BEGIN
		INSERT INTO #TraderPerformanceDetail (
			TraderId
			,SportId
			,LeagueId
			,BettypeId
			,Turnover
			,WinLoss
			,EventProductCount
			,Target
			)
		SELECT tp.TraderId
			,tp.SportId
			,tp.LeagueId
			,tp.BettypeId
			,SUM(tp.Turnover) AS Turnover
			,SUM(tp.Winloss - tp.Comm) AS Winloss
			,SUM(tp.MatchCount) AS EventProductCount
			,tp.Target
		FROM dbo.OSSummaryByTrader_Daily tp WITH (NOLOCK)
		JOIN dbo.OSTrader t WITH (NOLOCK) ON t.TraderId = tp.TraderId
		WHERE (
				ISNULL(@TraderName, '') = ''
				OR t.TraderName LIKE '%' + @TraderName + '%'
				)
			AND tp.EventDate BETWEEN @FromDate AND @ToDate
		GROUP BY tp.TraderId
			,tp.SportId
			,tp.LeagueId
			,tp.BettypeId
			,tp.Target
	END
	ELSE IF @ReportType = 2
	BEGIN
		INSERT INTO #TraderPerformanceDetail (
			TraderId
			,SportId
			,LeagueId
			,BettypeId
			,Turnover
			,WinLoss
			,EventProductCount
			,Target
			)
		SELECT tp.TraderId
			,tp.SportId
			,tp.LeagueId
			,tp.BettypeId
			,SUM(tp.Turnover) AS Turnover
			,SUM(tp.Winloss - tp.Comm) AS Winloss
			,SUM(tp.MatchCount) AS EventProductCount
			,tp.Target
		FROM dbo.OSSummaryByTrader_Monthly tp WITH (NOLOCK)
		JOIN dbo.OSTrader t WITH (NOLOCK) ON t.TraderId = tp.TraderId
		WHERE (
				ISNULL(@TraderName, '') = ''
				OR t.TraderName LIKE '%' + @TraderName + '%'
				)
			AND tp.EventDate BETWEEN @FromDate AND @ToDate
		GROUP BY tp.TraderId
			,tp.SportId
			,tp.LeagueId
			,tp.BettypeId
			,tp.Target
	END
	
	INSERT INTO #TraderPerformanceDetailByBettype (
		TraderId
		,SportId
		,BettypeId
		,Turnover
		,WinLoss
		,Point
		,EventProductCount
		)
	SELECT tp.TraderId
		,tp.SportId
		,tp.BettypeId
		,tp.Turnover
		,tp.Winloss AS Winloss
		,tp.Turnover * 100 / SUM(tp.Turnover) OVER (
			PARTITION BY tp.TraderId
			,tp.SportId
			) * (
			@FloorMark / 100 + (
				(
					CASE 
						WHEN FLOOR(((tp.Winloss * 100 / tp.Turnover) - tp.Target) / @IncrementValue) >= @IncrementTimes
							THEN @IncrementTimes
						WHEN FLOOR(((tp.Winloss * 100 / tp.Turnover) - tp.Target) / @IncrementValue) <= - @IncrementTimes
							THEN - @IncrementTimes
						ELSE FLOOR(((tp.Winloss * 100 / tp.Turnover) - tp.Target) / @IncrementValue)
						END
					) + 1
				) / @IncrementTimes
			) AS Point
		,tp.EventProductCount
	FROM #TraderPerformanceDetail tp WITH (NOLOCK);
	
	INSERT INTO #TraderPerformanceDetailBySport (
		TraderId
		,SportId
		,Turnover
		,WinLoss
		,Point
		,EventProductCount
		)
	SELECT tp.TraderId
		,tp.SportId
		,SUM(tp.Turnover)
		,SUM(tp.Winloss) AS Winloss
		,SUM(tp.Point) * SUM(tp.Turnover) OVER (PARTITION BY tp.TraderId,tp.SportId) / SUM(tp.Turnover) OVER (PARTITION BY tp.TraderId) AS Point
		,SUM(tp.EventProductCount) AS EventProductCount
	FROM #TraderPerformanceDetailByBettype tp WITH (NOLOCK)
	GROUP BY tp.TraderId
		,SportId
		,Turnover
		,WinLoss

	CREATE TABLE #TraderPointDeduction (
		TraderId INT
		,PointDeduction MONEY
		)

	INSERT INTO #TraderPointDeduction (
		TraderId
		,PointDeduction
		)
	SELECT d.TraderId
		,SUM(COALESCE(d.DeductionValue, 0)) AS PointDeduction
	FROM dbo.OSTraderPointDeduction d WITH (NOLOCK)
	WHERE d.TraderId IN (
			SELECT DISTINCT TraderId
			FROM #TraderPerformanceDetailByBettype
			)
		AND (
			d.DeductionDate IS NULL
			OR d.DeductionDate BETWEEN @FromDate AND @ToDate
			)
	GROUP BY d.TraderId

	SELECT td.TraderId
		,tr.TraderName
		,te.TeamName AS TeamName
		,gr.GradeName AS GradeName
		,CASE 
			WHEN SUM(td.Point) > 100
				THEN 100
			ELSE SUM(td.Point)
			END - COALESCE(d.PointDeduction, 0) AS TotalPoint
		,d.PointDeduction
		,(SUM(td.WinLoss) * 100 / SUM(td.Turnover)) AS Margin
		,SUM(td.Turnover) AS Turnover
		,SUM(td.WinLoss) AS WinLoss
		,COUNT(DISTINCT td.SportId) AS SportCount
		,SUM(td.EventProductCount) AS EventProductCount
	FROM #TraderPerformanceDetailBySport td WITH (NOLOCK)
	INNER JOIN dbo.OSTrader tr ON tr.TraderId = td.TraderId
	LEFT JOIN dbo.OSTeam te ON te.TeamId = tr.TeamId
	LEFT JOIN dbo.OSGrade gr ON gr.GradeId = tr.GradeId
	LEFT JOIN #TraderPointDeduction d ON d.TraderId = td.TraderId
	GROUP BY td.TraderId
		,tr.TraderName
		,te.TeamName
		,gr.GradeName
		,d.PointDeduction
	ORDER BY tr.TraderName ASC

	DROP TABLE #TraderPointDeduction
	DROP TABLE #TraderPerformanceDetailByBettype
	DROP TABLE #TraderPerformanceDetailBySport
	DROP TABLE #TraderPerformanceDetail
END
/* 
GO
GRANT EXECUTE ON [dbo].[TGRS_OS_Rpt_TraderPerformance] TO [bodbTGRSNet]
GO
GRANT VIEW DEFINITION ON [dbo].[TGRS_OS_Rpt_TraderPerformance] TO [bodbTGRSNet]
GO
*/
GO

SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO


GO 
 GRANT EXECUTE ON [dbo].[TGRS_OS_Rpt_TraderPerformance] TO [bodbTGRSNet]
GO 
 GRANT VIEW DEFINITION ON [dbo].[TGRS_OS_Rpt_TraderPerformance] TO [bodbTGRSNet]
GO 
