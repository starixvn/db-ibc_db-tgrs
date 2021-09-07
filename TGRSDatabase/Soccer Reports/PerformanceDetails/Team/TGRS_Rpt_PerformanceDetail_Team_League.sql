ALTER PROCEDURE [dbo].[TGRS_Rpt_PerformanceDetail_Team_League]
		@FromDate			DATE
	,	@ToDate				DATE
	,	@LeagueGroupIds		VARCHAR(2000) = ''
	,	@TeamId				SMALLINT
	,	@Bettypes			VARCHAR(2000) = '0'
	,	@IsExcludeLeagues	BIT = 1
	,	@Market				SMALLINT = 1
AS
/*
	 Created:	20162903@Simon
	 Task :		Detail report - League detail from Team
	 DB:		DBTGRS.bodb_TGRS
	 Original:

	 Revisions:
		- 20171205@Simon:		get only Live data & Bettypes are not disabled
		- 20180912@Simon:		add league exclusion
		- 20190919@Long.Luu:	Support Nonlive Data [Redmine ID: 118959]
		- 20191023@John.Ngo:	Enhance performance [Redmine ID: 121268]
		- 20200713@John.Ngo:	Performance Detail - Support filter by league group [Redmine ID: 137276]
		- 20210827@Adam.Tran: 	Sports - Performance Real Figures [Redmine: #158981]
		
	 Param's Explanation:
		- @Market: -1 All; 0 Nonlive; 1 Live

	 Exam:
		  EXEC  TGRS_Rpt_PerformanceDetail_Team_League @FromDate = '2016/03/23', @ToDate= '2016/3/28', @TeamId = 11,@Bettypes = '5,1,3'
*/

BEGIN
	SET NOCOUNT ON;

	DECLARE @LeagueGroups AS TABLE (LeagueGroupId SMALLINT PRIMARY KEY CLUSTERED)
	IF @LeagueGroupIds <> ''
	BEGIN
		INSERT INTO @LeagueGroups(LeagueGroupId)
		SELECT val 
		FROM dbo.strSplit_Key(@LeagueGroupIds,',');

		IF CHARINDEX('12', @LeagueGroupIds) > 0
		BEGIN
			DELETE FROM @LeagueGroups
			WHERE LeagueGroupId = 12;

			INSERT INTO @LeagueGroups(LeagueGroupId)
			SELECT DISTINCT l.LeagueGroupID
			FROM bodb02.dbo.league AS l WITH(NOLOCK)
			WHERE l.LeagueGroupID NOT IN (1,2,3,4,5,6,7,8,9,10,11);
		END;
	END;

	SELECT	P.LeagueId
		, 	L.LeagueName
		, 	L.LeagueGroupID
		, 	P.IsLive
		,	ISNULL(COUNT(DISTINCT P.CustId), 0)                AS TraderCount
		,	ISNULL(COUNT(DISTINCT P.MatchId), 0)               AS MatchCount
		,	ISNULL(SUM(P.Stake), 0)                            AS Turnover
		,	ISNULL(SUM(P.WinLost), 0) - ISNULL(SUM(P.Comm), 0) AS WinLoss
		,	CASE WHEN ISNULL(SUM(P.Stake), 0) <> 0 THEN (ISNULL(SUM(P.WinLost), 0) - ISNULL(SUM(P.Comm), 0)) * 100 / SUM(P.Stake) ELSE NULL END AS Margin
		,	ISNULL(SUM(P.Stake_Real),0) 					   AS TurnoverReal
		,	ISNULL(SUM(CASE WHEN P.Is8RM = 0 THEN P.WinLost_Real ELSE 0 END),0) 	AS WinLossReal
		,	CASE WHEN ISNULL(SUM(P.Stake_Real),0) <> 0 THEN ISNULL(SUM(CASE WHEN P.Is8RM = 0 THEN P.WinLost_Real ELSE 0 END),0) * 100/ISNULL(SUM(P.Stake_Real),0) ELSE NULL END 						  			AS MarginReal
		,	ISNULL(SUM(P.BetCount), 0)                         AS BetCount
	FROM dbo.TraderPerformance AS P WITH ( NOLOCK )
		INNER JOIN bodb02.dbo.League AS L WITH ( NOLOCK ) ON P.LeagueId = L.LeagueId
		INNER JOIN dbo.Trader AS T WITH ( NOLOCK ) ON T.CustId = P.CustId
		LEFT JOIN @LeagueGroups AS lg ON L.LeagueGroupId = lg.LeagueGroupId
		LEFT JOIN dbo.LeagueExclusion le WITH(NOLOCK) ON P.LeagueId = le.LeagueId
	WHERE (@Bettypes = '0' OR P.BetType IN (SELECT val FROM strSplit_Key(@Bettypes, ',')))
		AND P.EventDate BETWEEN @FromDate AND @ToDate
		AND T.TeamId = @TeamId
		AND (@Market = -1 OR P.IsLive = @Market)
		AND (@IsExcludeLeagues = 0 OR le.LeagueId IS NULL)
		AND (@LeagueGroupIds = '' OR lg.LeagueGroupId IS NOT NULL)
	GROUP BY P.LeagueId, L.LeagueName, L.LeagueGroupID, P.IsLive
	ORDER BY Margin DESC, LeagueName ASC;
END;

GO
