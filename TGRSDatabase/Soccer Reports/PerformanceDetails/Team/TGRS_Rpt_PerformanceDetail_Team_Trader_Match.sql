ALTER PROCEDURE [dbo].[TGRS_Rpt_PerformanceDetail_Team_Trader_Match]
		@FROMDate				DATE
	,	@ToDate					DATE
	,	@TeamId					SMALLINT
	,	@CustId					INT
	,	@Bettypes				VARCHAR(2000) = '0'
	,	@IsExcludeLeagues		BIT = 1
	,	@Market					SMALLINT = 1
AS
/*
	  Created:	20160330@Simon
	  TASk:		Detail report Trader Performance - Detail Match
	  DB:		DBTGRS.bodb_TGRS
	  Original:

	  Revision:
		- 20171205@Simon:		get only Live data & Bettypes are not disabled
		- 20180912@Simon:		add league exclusion
		- 20190919@Long.Luu:	Support Nonlive Data [Redmine ID: 118959]
		- 20191023@John.Ngo:	Enhance performance [Redmine ID: 121268]

	  Param's Explanation:
		- @Market: -1 All; 0 Nonlive; 1 Live

	  Example:
		EXEC [TGRS_Rpt_PerformanceDetail_Team_Trader_Match] @FROMDate = '2014-01-01', @ToDate= '2014-12-30', @Bettypes = '0',@TeamId = 5, @CustID = 1530768

*/

BEGIN
	SET NOCOUNT ON;

	DECLARE @BettypeList AS TABLE(bettype SMALLINT);

	IF @Bettypes <> '0'
	INSERT INTO @BettypeList
		SELECT val
		FROM dbo.strSplit_Key(@Bettypes, ',');
	ELSE
	INSERT INTO @BettypeList
		SELECT Bettype
		FROM dbo.Bettype WITH (NOLOCK);

	SELECT
		P.MatchId,
		P.LeagueId,
		P.HomeId,
		P.AwayId,
		P.EventDate,
		P.IsLive,
		ISNULL(SUM(P.Stake), 0)                            AS Turnover,
		ISNULL(SUM(P.WinLost), 0) - ISNULL(SUM(P.Comm), 0) AS WinLoss,
		ISNULL(SUM(BetCount), 0)                           AS BetCount,
		CASE WHEN ISNULL(SUM(P.Stake), 0) <> 0
			THEN (ISNULL(SUM(P.WinLost), 0) - ISNULL(SUM(P.Comm), 0)) * 100 / ISNULL(SUM(P.Stake), 0)
		ELSE NULL END                                      AS Margin
	FROM dbo.TraderPerformance AS P WITH (NOLOCK)
		INNER JOIN dbo.Trader AS T WITH (NOLOCK) ON T.CustId = P.CustId
		LEFT JOIN dbo.LeagueExclusion le WITH(NOLOCK) ON P.LeagueId = le.LeagueId
	WHERE P.EventDate BETWEEN @FROMDate AND @ToDate
		AND P.CustId = @CustId
		AND T.TeamId = @TeamId
		AND P.Bettype IN (SELECT bettype FROM @BettypeList)
		AND (@Market = -1 OR P.IsLive = @Market)
		AND (@IsExcludeLeagues = 0 OR le.LeagueId IS NULL)
	GROUP BY P.MatchId, P.LeagueId, P.HomeId, P.AwayId, P.EventDate, P.IsLive
	ORDER BY P.LeagueId ASC, Margin DESC, P.EventDate ASC;
END;

GO
/*<info serverAlias="DBTGRS-bodb_TGRS" executers="bodbTGRSNet" isFunction="0" isNested="0"></info>*/