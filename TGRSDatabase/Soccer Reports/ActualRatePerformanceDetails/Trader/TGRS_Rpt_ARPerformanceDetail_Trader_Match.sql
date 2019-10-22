ALTER PROCEDURE [dbo].[TGRS_Rpt_ARPerformanceDetail_Trader_Match] 
		@FromDate			DATE
	,	@ToDate				DATE
	,	@CustId				INT
	,	@Bettypes			VARCHAR(200) = '1,3,7,8'
	,	@IsExcludeLeagues	BIT = 1
	,	@Market				SMALLINT = 1
AS
/*  
	Created:	20190304@John
	Task :		New AR Performance Details (Juice & Leftover) Report - Trader - Match
	DB:			DBTGRS.bodb_TGRS
	Original:  
	 
	Revisions:
		- 20190304@John: Create new [Redmine ID: #108920]
		- 20190919@John.Ngo:	Support Nonlive Data [Redmine ID: 118959]

	Param's Explanation (filtered by):
		- @Market:	-1 All; 0 Nonlive; 1 Live
		    
    Example: EXECUTE [TGRS_Rpt_ARPerformanceDetail_Trader_Match] @FromDate = '2019-02-01', @ToDate= '2019-03-05', @CustID = 1530768  
*/

BEGIN
	SET NOCOUNT ON;

	DECLARE @BettypeList AS TABLE (bettype SMALLINT);

	IF @Bettypes <> '0'
		INSERT INTO @BettypeList (bettype)
		SELECT bt.BetType
		FROM dbo.strSplit_Key(@Bettypes, ',') ssk			
			INNER JOIN dbo.BetType bt WITH (NOLOCK) ON bt.MainDBBetType = ssk.val;
	ELSE
		INSERT INTO @BettypeList (bettype)
		SELECT bt.BetType
		FROM dbo.BetType AS bt WITH (NOLOCK)
		WHERE bt.MainDBBetType IN (1,3,7,8);

	SELECT tp.MatchId
		,tp.LeagueId
		,tp.HomeId
		,tp.AwayId
		,tp.EventDate
		,ISNULL(SUM(tp.StakeMYR_AR), 0) AS Turnover
		,ISNULL(SUM(tp.StakeMYRJuice_AR), 0) AS TurnoverJuice
		,ISNULL(SUM(tp.Juice_AR), 0) AS Juice
		,ISNULL(SUM(tp.WinLost_AR), 0) - ISNULL(SUM(tp.Comm_AR), 0) AS WinLoss
		,ISNULL(SUM(BetCount), 0) AS BetCount
		,tp.IsLive
	FROM dbo.TraderPerformance tp WITH (NOLOCK)
	WHERE tp.EventDate BETWEEN @FromDate
			AND @ToDate
		AND tp.CustId = @CustId
		AND tp.Bettype IN (
			SELECT bettype
			FROM @BettypeList
			)
		AND (@Market = -1 OR tp.IsLive = @Market)
		AND (@IsExcludeLeagues = 0 OR (tp.LeagueId NOT IN (SELECT le.LeagueId FROM dbo.LeagueExclusion le WITH(NOLOCK))))
	GROUP BY tp.MatchId
		,tp.LeagueId
		,tp.HomeId
		,tp.AwayId
		,tp.EventDate
		,tp.IsLive;
END

GO
/*<info serverAlias="DBTGRS-bodb_TGRS" executers="bodbTGRSNet" isFunction="0" isNested="0"></info>*/