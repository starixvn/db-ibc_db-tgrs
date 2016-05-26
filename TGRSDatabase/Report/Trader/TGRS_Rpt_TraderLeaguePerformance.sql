USE [bodb_TGRS]
GO

ALTER PROCEDURE [dbo].[TGRS_Rpt_TraderLeaguePerformance]
	@TraderId INT,
	@FromDate DATETIME,
	@ToDate DATETIME
AS
/*
	Creator: Percy
	Date: 2016-05-17
	Task: Trader Report - League Performance
	DB: DBTGRS.bodb_TGRS

	Revisions:

	Param's Explanation:

	Exam:
*/
BEGIN
	SET NOCOUNT ON
	BEGIN
		SELECT  l.leagueid, l.leaguename,
				ISNULL(SUM(Stake),0) AS Turnover, 
				ISNULL(SUM(WinLost),0) -  ISNULL(SUM(Comm),0) AS WinLost, 
				CASE WHEN  ISNULL(SUM(Stake), 0) <> 0 THEN (ISNULL(SUM(WinLost), 0) - ISNULL(SUM(Comm),0)) * 100/SUM(Stake) ELSE NULL END AS Margin 
		FROM
			dbo.TraderPerformance t (NOLOCK)
			INNER JOIN bodb02.dbo.league l (NOLOCK) ON t.LeagueId = l.leagueid
		WHERE
			CustId = @TraderId
			AND EventDate BETWEEN @FromDate AND @ToDate
		GROUP BY l.leagueid, l.leaguename
		ORDER BY Margin DESC
	END
END
GO

GRANT EXECUTE ON [dbo].[TGRS_Rpt_TraderLeaguePerformance] TO [bodbTGRSNet]
GO