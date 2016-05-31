USE [bodb_TGRS]
GO

ALTER PROCEDURE [dbo].[TGRS_Rpt_TraderLeaguePerformance]
	@TraderId	INT,
	@FromDate	DATETIME,
	@ToDate		DATETIME,
	@PageSize	INT = 100,
	@PageIndex	INT = 1
AS
/*
	Creator: Percy
	Date: 2016-05-17
	Task: Trader Report - League Performance
	DB: DBTGRS.bodb_TGRS

	Revisions:
		- 20160531@Percy: Return rownumber, betcount [RedmineID: #58484]

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
			COUNT(DISTINCT t.MatchId) AS MatchCount,
			l.leagueid, l.leaguename,
			ISNULL(SUM(Stake),0) AS Turnover, 
			ISNULL(SUM(WinLost),0) -  ISNULL(SUM(Comm),0) AS WinLost,
			ISNULL(SUM(BetCount),0) AS BetCount,
			CASE WHEN  ISNULL(SUM(Stake), 0) <> 0 THEN (ISNULL(SUM(WinLost), 0) - ISNULL(SUM(Comm),0)) * 100/SUM(Stake) ELSE NULL END AS Margin 
		FROM
			dbo.TraderPerformance t (NOLOCK)
			INNER JOIN bodb02.dbo.league l (NOLOCK) ON t.LeagueId = l.leagueid
		WHERE
			CustId = @TraderId
			AND EventDate BETWEEN @FromDate AND @ToDate
		GROUP BY l.leagueid, l.leaguename
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

GRANT EXECUTE ON [dbo].[TGRS_Rpt_TraderLeaguePerformance] TO [bodbTGRSNet]
GO