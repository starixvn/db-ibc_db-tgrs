/****** Object:  Stored Procedure dbo.TGRS_Rpt_PerformanceDetail_Team_League    Script Date: 4/1/2016 8:22:16 AM ******/
ALTER PROCEDURE [dbo].[TGRS_Rpt_PerformanceDetail_Team_League]
	@FromDate	DATE,
	@ToDate		DATE,
	@TeamId		SMALLINT,
	@Bettypes	VARCHAR(2000) = '0',
	@IsExcludeLeagues	BIT = 1
AS
/*
 Created:	20162903@Simon
 Task :		Detail report - League detail from Team
 DB:		DBTGRS.bodb_TGRS
 Original:

 Revisions:
	- 20171205@Simon: get only Live data & Bettypes are not disabled
	- 20180912@Simon: add league exclusion

 Param's Explanation:

 Exam:
	  EXEC  TGRS_Rpt_PerformanceDetail_Team_League @FromDate = '2016/03/23', @ToDate= '2016/3/28', @TeamId = 11,@Bettypes = '5,1,3'

*/

BEGIN
	SET NOCOUNT ON;

	SELECT
		P.LeagueId,
		L.LeagueName,
		ISNULL(COUNT(DISTINCT P.CustId), 0)                AS TraderCount,
		ISNULL(COUNT(DISTINCT P.MatchId), 0)               AS MatchCount,
		ISNULL(SUM(P.Stake), 0)                            AS Turnover,
		ISNULL(SUM(P.WinLost), 0) - ISNULL(SUM(P.Comm), 0) AS WinLoss,
		ISNULL(SUM(P.BetCount), 0)                         AS BetCount,
		CASE WHEN ISNULL(SUM(P.Stake), 0) <> 0
			THEN (ISNULL(SUM(P.WinLost), 0) - ISNULL(SUM(P.Comm), 0)) * 100 / SUM(P.Stake)
		ELSE NULL END                                      AS Margin
	FROM dbo.TraderPerformance P WITH ( NOLOCK )
		INNER JOIN bodb02.dbo.League L WITH ( NOLOCK ) ON P.LeagueId = L.LeagueId
		INNER JOIN Trader T WITH ( NOLOCK ) ON T.CustId = P.CustId
	WHERE (@Bettypes = '0' OR P.BetType IN (SELECT val FROM strSplit_Key(@Bettypes, ',')))
		AND P.EventDate BETWEEN @FromDate AND @ToDate
		AND T.TeamId = @TeamId
		AND P.IsLive = 1
		AND (@IsExcludeLeagues = 0 OR (P.LeagueId NOT IN (SELECT le.LeagueId FROM dbo.LeagueExclusion le WITH(NOLOCK) WHERE le.LeagueId = P.LeagueId)))
	GROUP BY P.LeagueId, L.LeagueName
	ORDER BY Margin DESC, LeagueName ASC;
END;

/*<info serverAlias="DBTGRS-bodb_TGRS" executers="bodbTGRSNet" isFunction="0" isNested="0"></info>*/