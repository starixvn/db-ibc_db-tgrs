ALTER PROCEDURE [dbo].[TGRS_Rpt_SummaryTopTrader]  
		@Top				TINYINT = 10
	,	@IsBottom			BIT = 0
	,	@ReportType			TINYINT = 1
	,	@FromDate			DATE
	,	@ToDate				DATE
	,	@ViewPermission		SMALLINT
	,	@IsExcludeLeagues	BIT = 1
	,	@Market				SMALLINT = 1
AS    
/*  
	 Created:	20140520@Sophia
	 Task :		Summary report - Top Trader performace
	 DB:		DBTGRS.bodb_TGRS
	 Original:  
  
	 Revisions:      
   		- 20171024@Simon: Add ViewPermission param		
		- 20171025@Long: Change the way to get MatchCount
		- 20171205@Simon: get only Live data & Bettypes are not disabled
		- 20180912@Simon: add league exclusion
		- 20190116@John: Fix excluding Leagues from report [Redmine ID: #108008]
		- 20190919@John.Ngo:	Support Nonlive Data [Redmine ID: 118959]
		- 20191023@John.Ngo:	Enhance performance [Redmine ID: 121268]

	Param's Explanation (filtered by):
		- @Market:	-1 All; 0 Nonlive; 1 Live
		- @ReportType = 1: by Date
				 = 2: By Month
				 = 3: By Year

		- @Top	= XX:  Rows to display
				= 0: All

		- @IsBottom = 0: List top traders
				  = 1: List bottom traders

		- @ViewPermission = 0: all bet types
				 = 1: major bet types
				 = 2: PHAIO bet types
	 Exam: 
		EXEC TGRS_Rpt_SummaryTopTrader @Top = 0, @IsBottom = 0, @ReportType = 1, @FromDate = '2014-01-01', @ToDate = '2014-05-31'
*/  
 
BEGIN 
	SET NOCOUNT ON 
	
	IF	OBJECT_ID('tempdb..#Trader') IS NOT NULL
	BEGIN;
		DROP TABLE #Trader;
	END;

	CREATE TABLE #Trader(
		  CustId				INT
		, Username				VARCHAR(30)
		, TeamName				NVARCHAR(50)
		, TeamId				SMALLINT
		, Grade					TINYINT
		, MatchCount			BIGINT
		, BetCount				INT
		, Turnover				MONEY
		, WinLost				MONEY
		, Margin				MONEY
		, NoOfTeamChanged		INT
		, NoOfGradeChanged		INT
		, IsLive				BIT
	);	 

	CREATE CLUSTERED INDEX	#CIX_TraderIdx ON #Trader (
								CustId	ASC
							);
	
	IF	OBJECT_ID('tempdb..#MatchCountByCustId') IS NOT NULL
	BEGIN;
		DROP TABLE #MatchCountByCustId;
	END;

	CREATE TABLE #MatchCountByCustId (
		CustId			INT, 
		MatchCount		BIGINT,
		IsLive			BIT
	);

	CREATE CLUSTERED INDEX	#CIX_MatchCountByCustIdIdx ON #MatchCountByCustId (
								CustId	ASC
							);

	INSERT INTO #MatchCountByCustId(
			CustId
		,	MatchCount
		,	IsLive
	)
	SELECT tp.CustId
		,  COUNT_BIG(DISTINCT tp.MatchId) AS MatchCount
		,  tp.IsLive
	FROM dbo.TraderPerformance tp WITH(NOLOCK)
		INNER JOIN dbo.BetType bt WITH(NOLOCK) on tp.BetType = bt.BetType
		LEFT JOIN dbo.LeagueExclusion le WITH(NOLOCK) ON tp.LeagueId = le.LeagueId
	WHERE tp.EventDate BETWEEN @FromDate AND @ToDate
		AND (
				@ViewPermission = 0
				OR bt.BettypeGroup = @ViewPermission
			)
		AND (@Market = -1 OR tp.IsLive = @Market)
		AND bt.[Disabled] = 0
		AND (@IsExcludeLeagues = 0 OR le.LeagueId IS NULL)
	GROUP BY tp.CustId, tp.IsLive;

	IF @ReportType	= 1 --- by date
	BEGIN 
		INSERT INTO #Trader (CustId, Username, TeamId, Grade, MatchCount, BetCount, Turnover, WinLost, Margin, IsLive)
		SELECT  P.CustId, TR.Username, TR.TeamId, TR.Grade, 
				ISNULL(COUNT_BIG(DISTINCT P.MatchID),0) AS MatchCount, 
				ISNULL(SUM(P.BetCount),0) AS BetCount,
				ISNULL(SUM(P.Stake),0) AS Turnover, 
				ISNULL(SUM(P.WinLost),0) - ISNULL(SUM(P.Comm),0) AS WinLost, 
				CASE WHEN ISNULL(SUM(P.Stake),0) <> 0 THEN (ISNULL(SUM(P.WinLost),0) - ISNULL(SUM(P.Comm),0))* 100/ ISNULL(SUM(P.Stake),0) ELSE NULL END AS Margin,
				P.IsLive				
		FROM	dbo.TraderPerformance P WITH (NOLOCK)			
			INNER JOIN dbo.Trader TR WITH (NOLOCK) ON TR.CustID = P.CustId
			INNER JOIN dbo.Bettype bt WITH (NOLOCK) ON P.Bettype = bt.Bettype
			LEFT JOIN dbo.LeagueExclusion le WITH(NOLOCK) ON P.LeagueId = le.LeagueId
		WHERE P.EventDate BETWEEN @FromDate AND @ToDate
			AND (
					@ViewPermission = 0
					OR bt.BettypeGroup = @ViewPermission
				)
			AND (@Market = -1 OR P.IsLive = @Market)
			AND bt.[Disabled] = 0
			AND (@IsExcludeLeagues = 0 OR le.LeagueId IS NULL)
		GROUP BY P.CustId, TR.Username, TR.TeamId, TR.Grade, P.IsLive;
	END
	ELSE  --- by month-year
	BEGIN 
		INSERT INTO #Trader (CustId, Username, TeamId, Grade, MatchCount, BetCount, Turnover, WinLost, Margin, IsLive)
		SELECT  SM.CustId, TR.Username, TR.TeamId, TR.Grade, 
				m.MatchCount AS MatchCount, 
				ISNULL(SUM(SM.BetCount),0) AS BetCount,
				ISNULL(SUM(SM.Stake),0) AS Turnover, 
				ISNULL(SUM(SM.WinLost),0) - ISNULL(SUM(SM.Comm),0) AS WinLost, 
				CASE WHEN ISNULL(SUM(SM.Stake),0) <> 0 THEN (ISNULL(SUM(SM.WinLost),0) - ISNULL(SUM(SM.Comm),0))* 100/ ISNULL(SUM(SM.Stake),0) ELSE NULL END AS Margin,
				SM.IsLive		
		FROM	dbo.SummaryByTrader_Monthly SM WITH (NOLOCK)	
			INNER JOIN dbo.Trader TR WITH (NOLOCK) ON TR.CustID = SM.CustId		
			INNER JOIN #MatchCountByCustId m ON SM.CustId = m.CustId AND m.IsLive = sm.IsLive
			LEFT JOIN dbo.LeagueExclusion le WITH(NOLOCK) ON SM.LeagueId = le.LeagueId
		WHERE SM.EventDate BETWEEN @FromDate AND @ToDate
			AND (@Market = -1 OR SM.IsLive = @Market)
			AND (
					@ViewPermission = 0
					OR SM.BettypeGroup = @ViewPermission
				)
			AND (@IsExcludeLeagues = 0 OR le.LeagueId IS NULL)
		GROUP BY SM.CustId, TR.Username, TR.TeamId, TR.Grade, m.MatchCount, SM.IsLive;	
	END

	-------------------------------------------------	
	UPDATE  T
	SET		TeamName = TE.TeamName
	FROM	#Trader T
	INNER JOIN dbo.Team TE WITH (NOLOCK) 
			ON T.TeamId = TE.TeamId; 

	UPDATE  T
	SET		NoOfTeamChanged = ISNULL(TH.NoOfTeamChanged,0),
			NoOfGradeChanged = ISNULL(GH.NoOfGradeChanged,0)	
	FROM	#Trader T
	LEFT JOIN ( SELECT  T.CustId, COUNT(DISTINCT TH.TeamId) AS NoOfTeamChanged
				FROM	#Trader T 
				INNER JOIN dbo.TraderTeam_History TH WITH (NOLOCK) 
						ON T.CustId = TH.CustId					
					    AND (@FromDate BETWEEN ISNULL(TH.BeginDate, '1900-01-01') AND ISNULL(TH.EndDate,'9999-12-31')
							OR @ToDate BETWEEN ISNULL(TH.BeginDate, '1900-01-01') AND ISNULL(TH.EndDate,'9999-12-31')
							)
				GROUP BY T.CustId
				) TH 
			ON TH.CustId = T.CustId
	LEFT JOIN (	SELECT  T.CustId, COUNT(DISTINCT GH.Grade) AS NoOfGradeChanged
				FROM	#Trader T 
				INNER JOIN dbo.TraderGrade_History GH WITH (NOLOCK) 
					ON GH.CustId = T.CustId
					    AND (@FromDate BETWEEN ISNULL(GH.BeginDate, '1900-01-01') AND ISNULL(GH.EndDate,'9999-12-31')
							OR @ToDate BETWEEN ISNULL(GH.BeginDate, '1900-01-01') AND ISNULL(GH.EndDate,'9999-12-31')
							)
					GROUP BY T.CustId
				) GH
			ON GH.CustId = T.CustId;
	
	-----------------------------------------------	 
	 IF @Top <> 0  ----Top
	 BEGIN 
			IF @IsBottom = 0  
			BEGIN 
				SELECT TOP (@Top) * 
				FROM #Trader T
				ORDER BY T.Margin DESC, T.WinLost DESC, T.Turnover DESC

			END 
			ELSE
			BEGIN 
				SELECT TOP (@Top) * 
				FROM #Trader T
				ORDER BY T.Margin ASC, T.WinLost ASC, T.Turnover ASC
			END
	 END 
	 ELSE 
	 BEGIN 
		 IF @IsBottom = 0  
			BEGIN 
				SELECT * 
				FROM #Trader T
				ORDER BY T.Margin DESC, T.WinLost DESC, T.Turnover DESC
			END 
			ELSE
			BEGIN 
				SELECT * 
				FROM #Trader T
				ORDER BY T.Margin ASC, T.WinLost ASC, T.Turnover ASC
			END
	 END 
END;

GO
/*<info serverAlias="DBTGRS-bodb_TGRS" executers="bodbTGRSNet" isFunction="0" isNested="0"></info>*/