ALTER PROCEDURE [dbo].[TGRS_Rpt_PerformanceDetail_Team_Trader]
			@FromDate			DATE
		,	@ToDate				DATE
		,	@LeagueGroupIds		VARCHAR(2000) = ''
		,	@TeamId				SMALLINT
		,	@Bettypes			VARCHAR(2000) = '0'
		,	@IsExcludeLeagues	BIT = 1
		,	@Market				SMALLINT = 1
AS
/*
	Created:	20162803@Simon
	Task :		Performance Detail Report - Trader
	DB:			DBTGRS.bodb_TGRS
	Original:

	Revisions:
		- 20171019@Simon:		Change VARCHAR(200) to VARCHAR(2000)
		- 20171205@Simon:		get only Live data & Bettypes are not disabled
		- 20180912@Simon:		add league exclusion
		- 20190919@Long.Luu:	Support Nonlive Data [Redmine ID: 118959]
		- 20191023@John.Ngo:	Enhance performance [Redmine ID: 121268]
		- 20200714@John.Ngo:	Performance Detail - Support filter by league group [Redmine ID: 137276]
		- 20210827@Adam.Tran: 	Sports - Performance Real Figures [Redmine: #158981]
		- 20220222@John.Ngo:	Separate League Group for Virtual and SABA PinGoal [Redmine: #161859]
		
	Param's Explanation:
		- @Market: -1 All; 0 Nonlive; 1 Live

	Example:
		EXECUTE	TGRS_Rpt_PerformanceDetail_Trader @FromDate = '2013-01-01',	@ToDate= '2014-05-31',	@@TeamId = '0',	@Bettypes ='1'
		
*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @LeagueGroups AS TABLE (LeagueGroupId SMALLINT PRIMARY KEY CLUSTERED, LeagueGroupName VARCHAR(200), TargetLeagueGroupId SMALLINT)
	INSERT INTO @LeagueGroups(LeagueGroupId, LeagueGroupName, TargetLeagueGroupId)
	EXECUTE dbo.[TGRS_LeagueGroupSoccer_Get] @LeagueGroupIds = @LeagueGroupIds;

	DECLARE @BettypeList TABLE(
			bettype			SMALLINT
	);

	IF	OBJECT_ID('tempdb..#TraderDetail') IS NOT NULL
	BEGIN
		DROP TABLE	#TraderDetail;
	END;

	CREATE TABLE #TraderDetail (
			CustID			INT
		,	LeagueCount		INT
		,	MatchCount		INT
		,	Turnover		MONEY
		,	WinLoss			MONEY
		,	WinLossScore	MONEY		
		,	Margin			MONEY
		,	TurnoverReal	MONEY
		,	WinLossReal		MONEY		
		,	MarginReal		MONEY
		,	BetCount		INT
		,	SumCategory		MONEY
		,	IsLive			BIT
	);

	IF @Bettypes <> '0'
	INSERT INTO @BettypeList (bettype)
		SELECT ssk.val
		FROM dbo.strSplit_Key(@Bettypes, ',') ssk;
	ELSE
	INSERT INTO @BettypeList (bettype)
		SELECT bt.BetType
		FROM dbo.BetType AS bt WITH (NOLOCK);

	INSERT INTO #TraderDetail (
			CustID
		,	IsLive
		,	LeagueCount
		,	MatchCount
		,	Turnover
		,	WinLoss
		,	WinLossScore		
		,	Margin
		,	TurnoverReal
		,	WinLossReal	
		,	MarginReal
		,	BetCount
		,	SumCategory
	)
	SELECT	tp.CustId
		,	tp.IsLive
		,	COUNT(DISTINCT tp.LeagueId)                                         AS LeagueCount
		,	COUNT(DISTINCT tp.MatchId)                                          AS MatchCount
		,	ISNULL(SUM(tp.Stake), 0)                                            AS Turnover
		,	ISNULL(SUM(tp.WinLost), 0) - ISNULL(SUM(tp.Comm), 0)                AS WinLoss
		,	SUM((tp.WinLost - tp.Comm) * CASE WHEN tp.Spread * tm.Rate IS NULL THEN 0 ELSE 1 END)	AS WinLossScore		
		,	CASE WHEN SUM(tp.Stake) = 0 THEN NULL ELSE (SUM(tp.WinLost) - SUM(tp.Comm)) * 100 / SUM(tp.Stake) END	AS Margin
		,	ISNULL(SUM(tp.Stake_Real),0) 										AS TurnoverReal
		,	ISNULL(SUM(CASE WHEN tp.Is8RM = 0 THEN tp.WinLost_Real ELSE 0 END),0) 	AS WinLossReal
		,	CASE WHEN ISNULL(SUM(tp.Stake_Real),0) <> 0 THEN ISNULL(SUM(CASE WHEN tp.Is8RM = 0 THEN tp.WinLost_Real ELSE 0 END),0) * 100/ISNULL(SUM(tp.Stake_Real),0) ELSE NULL END 							   			   AS MarginReal
		,	ISNULL(SUM(tp.BetCount), 0)                                         AS BetCount
		,	ISNULL(SUM(tp.Stake * ISNULL(s.BenchMark, tp.Spread * tm.Rate)), 0) AS SumCategory
	FROM dbo.TraderPerformance AS tp WITH (NOLOCK)
		INNER JOIN dbo.Trader AS t WITH (NOLOCK) ON t.CustId = tp.CustId
		INNER JOIN bodb02.dbo.League AS L WITH ( NOLOCK ) ON tp.LeagueId = L.LeagueId
		LEFT JOIN dbo.TargetedMargin AS tm WITH (NOLOCK) ON tm.BetType = tp.BetType AND tm.WorkShift = tp.WorkShift
		LEFT JOIN dbo.Benchmark_SpecialSetting AS s WITH (NOLOCK) ON s.Spread = tp.Spread AND s.Rate = tm.Rate
		LEFT JOIN @LeagueGroups AS lg ON L.LeagueGroupId = lg.LeagueGroupId
		LEFT JOIN dbo.LeagueExclusion le WITH(NOLOCK) ON tp.LeagueId = le.LeagueId
	WHERE tp.EventDate BETWEEN @FromDate AND @ToDate
		AND tp.BetType IN (SELECT bl.bettype FROM @BettypeList AS bl)
		AND t.TeamId = @TeamId
		AND (@Market = -1 OR tp.IsLive = @Market)
		AND (@IsExcludeLeagues = 0 OR le.LeagueId IS NULL)
		AND (@LeagueGroupIds = '' OR lg.LeagueGroupId IS NOT NULL)
	GROUP BY tp.CustId, tp.IsLive;

	SELECT	td.CustId
		,	t.Username
		,	t.Grade
		,	td.LeagueCount
		,	td.MatchCount
		,	td.Turnover
		,	td.WinLoss
		,	td.Margin
		,	td.TurnoverReal
		,	td.WinLossReal
		,	td.MarginReal
		,	CASE WHEN td.SumCategory = 0 THEN NULL ELSE td.WinLossScore * 100 / td.SumCategory END AS Score
		,	td.BetCount
		,	td.IsLive
	FROM #TraderDetail AS td WITH (NOLOCK)
		INNER JOIN dbo.Trader AS t WITH (NOLOCK) ON t.CustId = td.CustId
		INNER JOIN dbo.Team AS tm WITH (NOLOCK) ON t.TeamId = tm.TeamId
	ORDER BY td.Margin DESC
		, t.Username ASC;

	DROP TABLE #TraderDetail;
END;

GO

/*<info serverAlias="DBTGRS-bodb_TGRS" executers="bodbTGRSNet" isFunction="0" isNested="0"></info>*/
