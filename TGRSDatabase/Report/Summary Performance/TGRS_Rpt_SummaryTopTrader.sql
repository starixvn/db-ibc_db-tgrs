ALTER PROCEDURE [dbo].[TGRS_Rpt_SummaryTopTrader]  
	@Top		 TINYINT = 10,
	@IsBottom	 BIT = 0,
	@ReportType	 TINYINT = 1,
	@FromDate	 DATE,
	@ToDate		 DATE,
	@ViewPermission SMALLINT
AS    
/*  
 Created:	20140520@Sophia
 Task :		Summary report - Top Trader performace
 DB:		DBTGRS.bodb_TGRS
 Original:  
  
 Revisions:      
   	- 20171024@Simon: Add ViewPermission param		
	- 20171025@Long: Change the way to get MatchCount

 Param's Explanation:  
	@ReportType = 1: by Date
			 = 2: By Month
			 = 3: By Year

	@Top	= XX:  Rows to display
			= 0: All

	@IsBottom = 0: List top traders
			  = 1: List bottom traders

	@ViewPermission = 0: all bet types
			 = 1: major bet types
			 = 2: PHAIO bet types
 Exam: 
	EXEC TGRS_Rpt_SummaryTopTrader @Top = 0, @IsBottom = 0, @ReportType = 1, @FromDate = '2014-01-01', @ToDate = '2014-05-31'
	EXEC TGRS_Rpt_SummaryTopTrader_Xtest @Top = 0, @IsBottom = 0, @ReportType = 1, @FromDate = '2014-01-01', @ToDate = '2014-05-31'
	EXEC TGRS_Rpt_SummaryTopTrader @Top = 10, @IsBottom = 0, @ReportType = 3, @FromDate = '2012-01-01', @ToDate = '2013-12-31'
  
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
		MatchCount		BIGINT
	);

	CREATE CLUSTERED INDEX	#CIX_MatchCountByCustIdIdx ON #MatchCountByCustId (
								CustId	ASC
							);

	INSERT INTO #MatchCountByCustId(
			CustId
		,	MatchCount
	)
	SELECT tp.CustId
		,	COUNT_BIG(DISTINCT tp.MatchId) AS MatchCount
	FROM dbo.TraderPerformance tp WITH(NOLOCK)
		INNER JOIN dbo.BetType bt WITH(NOLOCK) on tp.BetType = bt.BetType
	WHERE tp.EventDate BETWEEN @FromDate AND @ToDate
		AND (
				@ViewPermission = 0
				OR bt.BettypeGroup = @ViewPermission
			)
	GROUP BY tp.CustId

	IF @ReportType	= 1 --- by date
	BEGIN 
		INSERT INTO #Trader (CustId, Username, TeamId, Grade, MatchCount, BetCount, Turnover, WinLost, Margin)
		SELECT  P.CustId, TR.Username, TR.TeamId, TR.Grade, 
				ISNULL(COUNT_BIG(DISTINCT MatchID),0) AS MatchCount, 
				ISNULL(SUM(BetCount),0) AS BetCount,
				ISNULL(SUM(Stake),0) AS Turnover, 
				ISNULL(SUM(WinLost),0) - ISNULL(SUM(Comm),0) AS WinLost, 
				CASE WHEN ISNULL(SUM(Stake),0) <> 0 THEN (ISNULL(SUM(WinLost),0) - ISNULL(SUM(Comm),0))* 100/ ISNULL(SUM(Stake),0) ELSE NULL END AS Margin				
		FROM	dbo.TraderPerformance P WITH (NOLOCK)			
			INNER JOIN dbo.Trader TR WITH (NOLOCK) ON TR.CustID = P.CustId
			INNER JOIN dbo.Bettype bt WITH (NOLOCK) ON P.Bettype = bt.Bettype
		WHERE	
			P.EventDate BETWEEN @FromDate AND @ToDate
			AND (
					@ViewPermission = 0
					OR bt.BettypeGroup = @ViewPermission
				)
		GROUP BY P.CustId, TR.Username, TR.TeamId, TR.Grade	
	END
	ELSE  --- by month-year
	BEGIN 
		INSERT INTO #Trader (CustId, Username, TeamId, Grade, MatchCount, BetCount, Turnover, WinLost, Margin)
		SELECT  P.CustId, TR.Username, TR.TeamId, TR.Grade, 
				m.MatchCount AS MatchCount, 
				ISNULL(SUM (BetCount),0) AS BetCount,
				ISNULL(SUM(Stake),0) AS Turnover, 
				ISNULL(SUM(WinLost),0) - ISNULL(SUM(Comm),0) AS WinLost, 
				CASE WHEN ISNULL(SUM(Stake),0) <> 0 THEN (ISNULL(SUM(WinLost),0) - ISNULL(SUM(Comm),0))* 100/ ISNULL(SUM(Stake),0) ELSE NULL END AS Margin		
		FROM	dbo.SummaryByTrader_Monthly P WITH (NOLOCK)	
			INNER JOIN dbo.Trader TR WITH (NOLOCK) ON TR.CustID = P.CustId		
			INNER JOIN #MatchCountByCustId m ON P.CustId = m.CustId		
		WHERE	
			P.EventDate BETWEEN @FromDate AND @ToDate
			AND (
					@ViewPermission = 0
					OR P.BettypeGroup = @ViewPermission
				)
		GROUP BY P.CustId, TR.Username, TR.TeamId, TR.Grade, m.MatchCount			
	END

	-------------------------------------------------	
	UPDATE  T
	SET		TeamName = TE.TeamName
	FROM	#Trader T
	INNER JOIN dbo.Team TE WITH (NOLOCK) 
			ON T.TeamId = TE.TeamId		 

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
			ON GH.CustId = T.CustId
	
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

END 
GO
GRANT EXECUTE ON [dbo].[TGRS_Rpt_SummaryTopTrader] TO [bodbTGRSNet]
GO

 