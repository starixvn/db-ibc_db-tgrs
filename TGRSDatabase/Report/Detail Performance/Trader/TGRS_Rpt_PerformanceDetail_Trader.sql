ALTER PROCEDURE [dbo].[TGRS_Rpt_PerformanceDetail_Trader]  	
	@Username   VARCHAR(30) = '',
	@FromDate	DATE,
	@ToDate		DATE,
	@Turnover	MONEY = NULL,
	@WinLoss	MONEY = NULL,
	@MarginFrom	MONEY = NULL,
	@MarginTo   MONEY = NULL,  
	@Bettypes	VARCHAR(2000) =  '0',
	@IsExcludeLeagues	BIT = 1
AS    
/*  
	Created:	20160217@Billy
	Task :		Performance Detail Report - Trader
	DB:			DBTGRS.bodb_TGRS
	Original:  
	 
	Revisions:
		- 20160301@Billy: US011 - Modify Trader's Score - [Redmine: #53084]
		- 20160315@Thai: US018 - Modify Trader's Score - [Redmine: #53987]
		- 20171019@Simon: Change VARCHAR(200) to VARCHAR(2000)
		- 20171205@Simon: get only Live data & Bettypes are not disabled
		- 20180912@Simon: add league exclusion

	Param's Explanation:  	
	
	Example: 	
		EXECUTE	TGRS_Rpt_PerformanceDetail_Trader 
						@FromDate = '2013-01-01'
					,	@ToDate= '2014-05-31'
					,	@Bettypes = '0'
					,	@username ='A'
*/ 
BEGIN 
	
	SET NOCOUNT ON;  
	 
	DECLARE	@BettypeList	TABLE (
								bettype				SMALLINT
							);

	CREATE TABLE #TraderDetail (
								CustID				INT
							,	LeagueCount			INT
							,	MatchCount			INT
							,	Turnover			MONEY
							,	WinLoss				MONEY
							,	WinLossScore		MONEY
							,	BetCount			INT
							,	Margin				MONEY
							,	SumCategory			MONEY
							);

	IF	@Bettypes <> '0'
		 INSERT INTO @BettypeList
		 	(	bettype)
		 SELECT ssk.val
		 FROM	dbo.strSplit_Key(@Bettypes, ',') ssk;
	ELSE 
		 INSERT INTO @BettypeList
		 	(	bettype)
		 SELECT bt.BetType 
		 FROM	dbo.BetType AS bt WITH (NOLOCK);
	
	INSERT INTO	#TraderDetail (
			CustID
		,	LeagueCount
		,	MatchCount
		,	Turnover
		,	WinLoss
		,	WinLossScore
		,	BetCount
		,	Margin
		,	SumCategory
	)
	SELECT	tp.CustId
		,	COUNT(DISTINCT tp.LeagueId)								AS LeagueCount
		,	COUNT(DISTINCT tp.MatchId)								AS MatchCount
		,	ISNULL(SUM(tp.Stake), 0)								AS Turnover
		,	ISNULL(SUM(tp.WinLost), 0) - ISNULL(SUM(tp.Comm), 0)	AS WinLoss		
		,	SUM( (tp.WinLost - tp.Comm) * CASE WHEN tp.Spread * tm.Rate IS NULL THEN 0 ELSE 1 END) 	AS WinLossScore	
		,	ISNULL(SUM(tp.BetCount), 0)								AS BetCount
		,	CASE	WHEN SUM(tp.Stake) = 0
					THEN NULL
					ELSE (SUM(tp.WinLost) - SUM(tp.Comm)) * 100 / SUM(tp.Stake)
			END														AS Margin				
		,	ISNULL(SUM(tp.Stake * ISNULL(s.BenchMark, tp.Spread * tm.Rate)), 0) AS SumCategory
	FROM		dbo.TraderPerformance AS tp WITH (NOLOCK)
		INNER JOIN	dbo.Trader AS t WITH (NOLOCK)
				ON	t.CustId = tp.CustId
		LEFT JOIN	dbo.TargetedMargin AS tm WITH (NOLOCK)
				ON	tm.BetType = tp.BetType
				AND	tm.WorkShift = tp.WorkShift
		LEFT JOIN dbo.Benchmark_SpecialSetting AS s WITH (NOLOCK)
				ON	s.Spread = tp.Spread
				AND	s.Rate = tm.Rate
	WHERE	tp.EventDate BETWEEN @FromDate AND @ToDate
		AND	tp.BetType IN (SELECT bl.bettype FROM @BettypeList AS bl)
		AND	t.Username LIKE '%' + @Username + '%'
		AND tp.IsLive = 1
		AND (@IsExcludeLeagues = 0 OR (tp.LeagueId NOT IN (SELECT le.LeagueId FROM dbo.LeagueExclusion le WITH(NOLOCK))))
	GROUP BY	tp.CustId;

	SELECT	td.CustId
		,	t.Username
		,	t.Grade
		,	t.TeamId
		,	tm.TeamName
		,	td.LeagueCount
		,	td.MatchCount
		,	td.Turnover
		,	td.WinLoss
		,	td.BetCount
		,	td.Margin
		,	CASE WHEN td.SumCategory = 0 THEN NULL ELSE td.WinLossScore * 100 / td.SumCategory END AS Score
	FROM		#TraderDetail AS td
		INNER JOIN	dbo.Trader AS t WITH (NOLOCK)
				ON	t.CustId = td.CustId
		INNER JOIN	dbo.Team AS tm WITH (NOLOCK) 
				ON	t.TeamId = tm.TeamId
	WHERE	(@Turnover IS NULL OR td.Turnover >= @Turnover)
		AND	(@WinLoss IS NULL OR td.WinLoss >= @WinLoss)
		AND	(@MarginFrom IS NULL OR td.Margin >= @MarginFrom)
		AND	(@MarginTo IS NULL OR td.Margin <= @MarginTo)
	ORDER BY	td.Margin DESC
		,	t.Username ASC;

	DROP TABLE #TraderDetail;
END;

GO
/*<info serverAlias="DBTGRS-bodb_TGRS" executers="bodbTGRSNet" isFunction="0" isNested="0"></info>*/