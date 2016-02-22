ALTER PROCEDURE [dbo].[TGRS_Rpt_PerformanceDetail_Trader]  	
	@Username   VARCHAR(30) = '',
	@FromDate	DATE,
	@ToDate		DATE,
	@Turnover	MONEY = NULL,
	@WinLost	MONEY = NULL,
	@MarginFrom	MONEY = NULL,
	@MarginTo   MONEY = NULL,  
	@Bettypes	VARCHAR(200) =  '0'
AS    
/*  
	Created:	20160217@Billy
	Task :		Performance Detail Report - Trader
	DB:			DBTGRS.bodb_TGRS
	Original:  
	 
	Revisions:

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
							,	WinLost				MONEY
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
				,	WinLost
				,	BetCount
				,	Margin
				,	SumCategory
				)
	SELECT	tp.CustId
		,	COUNT(DISTINCT tp.LeagueId)								AS LeagueCount
		,	COUNT(DISTINCT tp.MatchId)								AS MatchCount
		,	ISNULL(SUM(tp.Stake), 0)								AS Turnover
		,	ISNULL(SUM(tp.WinLost), 0) - ISNULL(SUM(tp.Comm), 0)	AS WinLost
		,	ISNULL(SUM(tp.BetCount), 0)								AS BetCount
		,	CASE	WHEN SUM(tp.Stake) = 0
					THEN NULL
					ELSE (SUM(tp.WinLost) - SUM(tp.Comm)) * 100 / SUM(tp.Stake)
			END														AS Margin
		,	SUM(tp.Stake * s.Spread * tm.Rate)						AS SumCategory
	FROM		dbo.TraderPerformance AS tp WITH (NOLOCK)
	INNER JOIN	dbo.Trader AS t WITH (NOLOCK)
			ON	t.CustId = tp.CustId
	LEFT JOIN	dbo.Spread AS s WITH (NOLOCK)
			ON	s.LeagueId = tp.LeagueId
			AND	s.BetType = tp.BetType
	LEFT JOIN	dbo.TargetedMargin AS tm WITH (NOLOCK)
			ON	tm.BetType = tp.BetType
	WHERE	tp.EventDate BETWEEN @FromDate AND @ToDate
		AND	tp.BetType IN (SELECT bl.bettype FROM @BettypeList AS bl)
		AND	t.Username LIKE '%' + @Username + '%'
	GROUP BY	tp.CustId

	SELECT	td.CustId
		,	t.Username
		,	t.Grade
		,	t.TeamId
		,	tm.TeamName
		,	td.LeagueCount
		,	td.MatchCount
		,	td.Turnover
		,	td.WinLost
		,	td.BetCount
		,	td.Margin
		,	CASE WHEN td.SumCategory = 0 THEN NULL ELSE td.WinLost * 100 / td.SumCategory END AS Score
	FROM		#TraderDetail AS td
	INNER JOIN	dbo.Trader AS t WITH (NOLOCK)
			ON	t.CustId = td.CustId
	INNER JOIN	dbo.Team AS tm WITH (NOLOCK) 
			ON	t.TeamId = tm.TeamId
	WHERE	(@Turnover IS NULL OR td.Turnover >= @Turnover)
		AND	(@WinLost IS NULL OR td.WinLost >= @WinLost)
		AND	(@MarginFrom IS NULL OR td.Margin >= @MarginFrom)
		AND	(@MarginTo IS NULL OR td.Margin <= @MarginTo)
	ORDER BY	td.Margin DESC
			,	t.Username ASC
END 
GO
GRANT EXECUTE ON [dbo].[TGRS_Rpt_PerformanceDetail_Trader] TO [bodbTGRSNet]
GO

