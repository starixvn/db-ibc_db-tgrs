ALTER PROCEDURE [dbo].[TGRS_Rpt_PerformanceDetail_Team_Trader_Match]
		@FROMDate				DATE
	,	@ToDate					DATE
	,	@LeagueGroupIds		VARCHAR(2000) = ''
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
		- 20200713@John.Ngo:	Performance Detail - Support filter by league group [Redmine ID: 137276]
		- 20210827@Adam.Tran: 	Sports - Performance Real Figures [Redmine: #158981]
		- 20220222@John.Ngo:	Separate League Group for Virtual and SABA PinGoal [Redmine: #161859]

	  Param's Explanation:
		- @Market: -1 All; 0 Nonlive; 1 Live

	  Example:
		EXEC [TGRS_Rpt_PerformanceDetail_Team_Trader_Match] @FROMDate = '2014-01-01', @ToDate= '2014-12-30', @Bettypes = '0',@TeamId = 5, @CustID = 1530768

*/

BEGIN
	SET NOCOUNT ON;

	DECLARE @OtherGroupsId SMALLINT = 12;

	DECLARE @LeagueGroups AS TABLE (LeagueGroupId SMALLINT PRIMARY KEY CLUSTERED, LeagueGroupName VARCHAR(200), TargetLeagueGroupId SMALLINT)
	INSERT INTO @LeagueGroups(LeagueGroupId, LeagueGroupName, TargetLeagueGroupId)
	EXECUTE dbo.[TGRS_LeagueGroupSoccer_Get] @LeagueGroupIds = @LeagueGroupIds;

	DECLARE @BettypeList AS TABLE(bettype SMALLINT);

	IF @Bettypes <> '0'
	INSERT INTO @BettypeList
		SELECT val
		FROM dbo.strSplit_Key(@Bettypes, ',');
	ELSE
	INSERT INTO @BettypeList
		SELECT Bettype
		FROM dbo.Bettype WITH (NOLOCK);

	SELECT	P.MatchId
		,	P.LeagueId
		,   CASE WHEN lg.TargetLeagueGroupId = L.LeagueGroupID THEN lg.TargetLeagueGroupId ELSE @OtherGroupsId END AS LeagueGroupID
		,	P.HomeId
		,	P.AwayId
		,	P.EventDate
		,	P.IsLive
		,	ISNULL(SUM(P.Stake), 0)                            AS Turnover
		,	ISNULL(SUM(P.WinLost), 0) - ISNULL(SUM(P.Comm), 0) AS WinLoss		
		,	CASE WHEN ISNULL(SUM(P.Stake), 0) <> 0 THEN (ISNULL(SUM(P.WinLost), 0) - ISNULL(SUM(P.Comm), 0)) * 100 / ISNULL(SUM(P.Stake), 0) 
				ELSE NULL END AS Margin
		,	ISNULL(SUM(P.Stake_Real),0) 					   AS TurnoverReal
		,	ISNULL(SUM(CASE WHEN P.Is8RM = 0 THEN P.WinLost_Real ELSE 0 END),0) 	AS WinLossReal
		,	CASE WHEN ISNULL(SUM(P.Stake_Real),0) <> 0 THEN ISNULL(SUM(CASE WHEN P.Is8RM = 0 THEN P.WinLost_Real ELSE 0 END),0) * 100/ISNULL(SUM(P.Stake_Real),0) ELSE NULL END 							   		AS MarginReal
		,	ISNULL(SUM(BetCount), 0)                           AS BetCount
	FROM dbo.TraderPerformance AS P WITH (NOLOCK)
		INNER JOIN dbo.Trader AS T WITH (NOLOCK) ON T.CustId = P.CustId
		INNER JOIN bodb02.dbo.League AS L WITH ( NOLOCK ) ON P.LeagueId = L.LeagueId
		LEFT JOIN @LeagueGroups AS lg ON L.LeagueGroupId = lg.LeagueGroupId
		LEFT JOIN dbo.LeagueExclusion le WITH(NOLOCK) ON P.LeagueId = le.LeagueId
	WHERE P.EventDate BETWEEN @FROMDate AND @ToDate
		AND P.CustId = @CustId
		AND T.TeamId = @TeamId
		AND P.Bettype IN (SELECT bettype FROM @BettypeList)
		AND (@Market = -1 OR P.IsLive = @Market)
		AND (@IsExcludeLeagues = 0 OR le.LeagueId IS NULL)
		AND (@LeagueGroupIds = '' OR lg.LeagueGroupId IS NOT NULL)
	GROUP BY P.MatchId, P.LeagueId, L.LeagueGroupID, P.HomeId, P.AwayId, P.EventDate 
		,   CASE WHEN lg.TargetLeagueGroupId = L.LeagueGroupID THEN lg.TargetLeagueGroupId ELSE @OtherGroupsId END
		,	P.IsLive
	ORDER BY P.LeagueId ASC, Margin DESC, P.EventDate ASC;
END;

GO

/*<info serverAlias="DBTGRS-bodb_TGRS" executers="bodbTGRSNet" isFunction="0" isNested="0"></info>*/