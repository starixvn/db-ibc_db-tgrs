ALTER PROCEDURE [dbo].[TGRS_Rpt_PerformanceDetail_Trader_Match_Bettype]  	
		@FromDate			DATE
	,	@ToDate				DATE
	,	@LeagueGroupIds		VARCHAR(2000) = ''
	,	@CustId				INT
	,	@MatchId			INT
	,	@Bettypes			VARCHAR(2000) =  '0'
	,	@IsExcludeLeagues	BIT = 1
	,	@Market				SMALLINT = 1
AS    
/*  
 Created:	20161503@Aaron
 Task :		Detail report Trader Performance - Detail Bettype based on Trader and Match
 DB:		DBTGRS.bodb_TGRS
 Original:  
  
 Revisions:      
		- 20162103@Simon:		restore orgirinal temp table code
		- 20171019@Simon:		Change VARCHAR(200) to VARCHAR(2000)
		- 20171205@Simon:		get only Live data & Bettypes are not disabled
		- 20180912@Simon:		add league exclusion
		- 20190919@Long.Luu:	Support Nonlive Data [Redmine ID: 118959]
		- 20191023@John.Ngo:	Enhance performance [Redmine ID: 121268]
		- 20200714@John.Ngo:	Performance Detail - Support filter by league group [Redmine ID: 137276]
		- 20210824@Adam.Tran: 	Sports - Performance Real Figures [Redmine: #158981]
		- 20220222@John.Ngo:	Separate League Group for Virtual and SABA PinGoal [Redmine: #161859]

 Param's Explanation:  	
		- @Market: -1 All; 0 Nonlive; 1 Live

 Exam: 				
		EXEC [TGRS_Rpt_PerformanceDetail_Trader_Match_Bettype] @FromDate='2016-02-29 00:00:00',@ToDate='2016-02-29 00:00:00',@CustId=14228019,@MatchId=16990574,@Bettypes='0' 
*/  
 
BEGIN 
	SET NOCOUNT ON;

	DECLARE @LeagueGroups AS TABLE (LeagueGroupId SMALLINT PRIMARY KEY CLUSTERED, LeagueGroupName VARCHAR(200), TargetLeagueGroupId SMALLINT)
	INSERT INTO @LeagueGroups(LeagueGroupId, LeagueGroupName, TargetLeagueGroupId)
	EXECUTE dbo.[TGRS_LeagueGroupSoccer_Get] @LeagueGroupIds = @LeagueGroupIds;
	
	DECLARE @BettypeList AS TABLE (bettype SMALLINT);

	IF @Bettypes <> '0'
		INSERT INTO @BettypeList
		SELECT val 
		FROM dbo.strSplit_Key(@Bettypes,',');
	ELSE 
		INSERT INTO @BettypeList
		SELECT Bettype 
		FROM dbo.Bettype WITH (NOLOCK);

	IF	OBJECT_ID('tempdb..#BettypeDetail') IS NOT NULL
	BEGIN
		DROP TABLE	#BettypeDetail;
	END;
		 		 
	CREATE TABLE #BettypeDetail (
			BetType				SMALLINT
		,	TypeName			NVARCHAR(100)
		,	Turnover			MONEY
		,	WinLoss				MONEY
		,	WinLossScore		MONEY
		,	Margin				MONEY
		,	TurnoverReal		MONEY
		,	WinLossReal			MONEY		
		,	MarginReal			MONEY
		,	BetCount			INT		
		,	SumCategory			MONEY
		,	IsLive				BIT
	);
	
	INSERT INTO	#BettypeDetail (
			BetType
		,	TypeName	
		,	IsLive			
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
	SELECT	tp.BetType
		,	TN.TypeName	
		,	tp.IsLive	
		,	ISNULL(SUM(tp.Stake), 0)								AS Turnover
		,	ISNULL(SUM(tp.WinLost), 0) - ISNULL(SUM(tp.Comm), 0)	AS WinLoss		
		,	SUM( (tp.WinLost - tp.Comm) * CASE WHEN tp.Spread * tm.Rate IS NULL THEN 0 ELSE 1 END) 	AS WinLossScore
		,	CASE WHEN SUM(tp.Stake) = 0 THEN NULL ELSE (SUM(tp.WinLost) - SUM(tp.Comm)) * 100 / SUM(tp.Stake) END	AS Margin
		,	ISNULL(SUM(tp.Stake_Real),0) 	AS TurnoverReal
		,	ISNULL(SUM(CASE WHEN tp.Is8RM = 0 THEN tp.WinLost_Real ELSE 0 END),0) 	AS WinLossReal
		,	CASE WHEN ISNULL(SUM(tp.Stake_Real),0) <> 0 THEN ISNULL(SUM(CASE WHEN tp.Is8RM = 0 THEN tp.WinLost_Real ELSE 0 END),0) * 100/ISNULL(SUM(tp.Stake_Real),0) ELSE NULL END 		AS MarginReal
		,	ISNULL(SUM(tp.BetCount), 0)		 AS BetCount
		,   ISNULL(SUM(tp.Stake * ISNULL(s.BenchMark, tp.Spread * tm.Rate)), 0) AS SumCategory
	FROM	dbo.TraderPerformance AS tp WITH (NOLOCK)
		INNER JOIN	dbo.Trader AS t WITH (NOLOCK) ON t.CustId = tp.CustId
		INNER JOIN bodb02.dbo.League AS L WITH ( NOLOCK ) ON tp.LeagueId = L.LeagueId
		LEFT JOIN @LeagueGroups AS lg ON L.LeagueGroupId = lg.LeagueGroupId
		LEFT JOIN dbo.TargetedMargin AS tm WITH (NOLOCK) ON tm.BetType = tp.BetType AND tm.WorkShift = tp.WorkShift	
		LEFT JOIN dbo.Benchmark_SpecialSetting AS s WITH (NOLOCK) ON s.Spread = tp.Spread AND s.Rate = tm.Rate
		LEFT JOIN dbo.BetType AS TN WITH (NOLOCK) ON TN.BetType = tp.BetType
		LEFT JOIN dbo.LeagueExclusion le WITH(NOLOCK) ON tp.LeagueId = le.LeagueId
	WHERE	tp.CustId = @CustId	
		AND tp.MatchId = @MatchId			
		AND tp.EventDate BETWEEN @FromDate AND @ToDate
		AND tp.BetType IN (SELECT bettype FROM @BettypeList)
		AND (@Market = -1 OR tp.IsLive = @Market)
		AND (@IsExcludeLeagues = 0 OR le.LeagueId IS NULL)
		AND (@LeagueGroupIds = '' OR lg.LeagueGroupId IS NOT NULL)
	GROUP BY tp.BetType, TN.TypeName, tp.IsLive;

	SELECT	bd.BetType
		,	bd.TypeName		
		,	bd.Turnover
		,	bd.WinLoss
		,	bd.Margin
		,	bd.TurnoverReal
		,	bd.WinLossReal
		,	bd.MarginReal
		,	bd.BetCount
		,	CASE WHEN bd.SumCategory = 0 THEN NULL ELSE bd.WinLossScore * 100 / bd.SumCategory END AS Score
		,	bd.IsLive
	FROM	#BettypeDetail AS bd WITH (NOLOCK)		
	ORDER BY bd.Margin DESC;

	DROP TABLE #BettypeDetail;
END;

GO

/*<info serverAlias="DBTGRS-bodb_TGRS" executers="bodbTGRSNet" isFunction="0" isNested="0"></info>*/
