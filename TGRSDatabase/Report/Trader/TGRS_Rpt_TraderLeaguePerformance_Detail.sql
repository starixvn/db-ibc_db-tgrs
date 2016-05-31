USE [bodb_TGRS]
GO

ALTER PROCEDURE [dbo].[TGRS_Rpt_TraderLeaguePerformance_Detail]
	@TraderId	INT,
	@LeagueId	INT,
	@FromDate	DATETIME,
	@ToDate		DATETIME,
	@PageSize	INT = 100,
	@PageIndex	INT = 1
AS
/*
	Creator: Percy
	Date: 2016-05-31
	Task: Trader Report - League Performance - Detail
	DB: DBTGRS.bodb_TGRS

	Revisions:

	Param's Explanation:

	Exam:
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @RowStart INT, @RowEnd INT
	SELECT  @PageIndex	= @PageIndex - 1,
			@RowStart	= @PageSize * @PageIndex + 1,
			@RowEnd		= @RowStart + @PageSize - 1
	
	;WITH CTE AS
	(
		SELECT
			MatchId, HomeId, AwayId, EventDate,
			ISNULL(SUM(Stake),0) AS Turnover, 
			ISNULL(SUM(WinLost),0) -  ISNULL(SUM(Comm),0) AS WinLost,
			ISNULL(SUM(BetCount),0) AS BetCount,
			CASE WHEN ISNULL(SUM(Stake), 0) <> 0 THEN (ISNULL(SUM(WinLost), 0) - ISNULL(SUM(Comm),0)) * 100/SUM(Stake) ELSE NULL END AS Margin 
		FROM dbo.TraderPerformance (NOLOCK)
		WHERE
			CustId = @TraderId
			AND LeagueId = @LeagueId
			AND EventDate BETWEEN @FromDate AND @ToDate
		GROUP BY MatchId, HomeId, AwayId, EventDate
	)
	SELECT
		*
	FROM (
		SELECT
			ROW_NUMBER() OVER(ORDER BY Margin DESC) AS OrderId,
			*
		FROM CTE
	) AS A
	WHERE OrderId BETWEEN @RowStart AND @RowEnd
	ORDER BY OrderId
END
GO

GRANT EXECUTE ON [dbo].[TGRS_Rpt_TraderLeaguePerformance_Detail] TO [bodbTGRSNet]
GO