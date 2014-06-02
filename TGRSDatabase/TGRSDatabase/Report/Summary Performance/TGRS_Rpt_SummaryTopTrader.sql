ALTER PROCEDURE [dbo].[TGRS_Rpt_SummaryTopTrader]  
	@Top		 TINYINT = 10,
	@IsBottom	 BIT = 0,
	@ReportType	 TINYINT = 1,
	@FromDate	 DATE,
	@ToDate		 DATE  
AS    
/*  
 Created:	20140520@Sophia
 Task :		Summary report - Top Trader performace
 DB:		DBTGRS.bodb_TGRS
 Original:  
  
 Revisions:      
   			
 Param's Explanation:  
	@ReportType = 1: by Date
			 = 2: By Month
			 = 3: By Year

	@Top	= XX:  Rows to display
			= 0: All

	@IsBottom = 0: List top traders
			  = 1: List bottom traders

 Exam: 
	EXEC TGRS_Rpt_SummaryTopTrader @Top = 10, @IsBottom = 0, @ReportType = 1, @FromDate = '2014-05-01', @ToDate = '2014-05-25'
	EXEC TGRS_Rpt_SummaryTopTrader @Top = 10, @IsBottom = 0, @ReportType = 2, @FromDate = '2014-02-01', @ToDate = '2014-04-30'
	EXEC TGRS_Rpt_SummaryTopTrader @Top = 10, @IsBottom = 0, @ReportType = 3, @FromDate = '2012-01-01', @ToDate = '2013-12-31'
  
*/  
 
BEGIN 
	SET NOCOUNT ON 
	
	DECLARE @Trader AS TABLE (CustId INT, Username VARCHAR(30), TeamName NVARCHAR(50), TeamId SMALLINT, Grade TINYINT, MatchCount INT, BetCount INT, Turnover MONEY, WinLost MONEY, Margin MONEY, 
						  FromTeamBeginDate DATE NULL, ToTeamBeginDate DATE NULL, FromGradeBeginDate DATE NULL, ToGradeBeginDate DATE NULL)	 
	
	IF @ReportType	= 1 --- by date
	BEGIN 
		INSERT INTO @Trader (CustId, Username, TeamId, Grade, MatchCount, BetCount, Turnover, WinLost, Margin)
		SELECT  P.CustId, TR.Username, TR.TeamId, TR.Grade, COUNT(DISTINCT MatchID) AS MatchCount, SUM (BetCount) AS BetCount,
				SUM(Stake) AS Turnover, SUM(WinLost)-SUM(Comm) AS WinLost, CASE WHEN SUM(Stake) <> 0 THEN (SUM(WinLost)-SUM(Comm))/SUM(Stake) ELSE NULL END AS Margin
		FROM	dbo.TraderPerformance P WITH (NOLOCK)	
			INNER JOIN dbo.Trader TR WITH (NOLOCK) ON TR.CustID = P.CustId	 				
		WHERE	P.EventDate BETWEEN @FromDate AND @ToDate
		GROUP BY P.CustId, TR.Username, TR.TeamId, TR.Grade	
	END
	ELSE  --- by month-year
	BEGIN 
		INSERT INTO @Trader (CustId, Username, TeamId, Grade, MatchCount, BetCount, Turnover, WinLost, Margin)
		SELECT  P.CustId, TR.Username, TR.TeamId, TR.Grade, SUM(MatchCount) AS MatchCount, SUM (BetCount) AS BetCount,
				SUM(Stake) AS Turnover, SUM(WinLost) - SUM(Comm) AS WinLost, CASE WHEN SUM(Stake) <> 0 THEN (SUM(WinLost)-SUM(Comm))/SUM(Stake) ELSE NULL END AS Margin
		FROM	dbo.SummaryByTrader_Monthly P WITH (NOLOCK)	
			INNER JOIN dbo.Trader TR WITH (NOLOCK) ON TR.CustID = P.CustId			
		WHERE	P.EventDate BETWEEN @FromDate AND @ToDate
		GROUP BY P.CustId, TR.Username, TR.TeamId, TR.Grade				
	END
	 
	---------------------------------------------

	UPDATE  T
	SET		TeamName = TE.TeamName
	FROM	@Trader T
	INNER JOIN dbo.Team TE WITH (NOLOCK) 
			ON T.TeamId = TE.TeamId		 

	UPDATE  T
	SET		FromTeamBeginDate = H.BeginDate
	FROM	@Trader T
	INNER JOIN TraderTeam_History H WITH (NOLOCK)
			ON	H.CustId = T.CustId
	WHERE	 @FromDate BETWEEN BeginDate AND ISNULL(EndDate,'9999-12-31')
			 
	UPDATE  T
	SET		ToTeamBeginDate = H.BeginDate
	FROM	@Trader T
	INNER JOIN TraderTeam_History H WITH (NOLOCK)
			ON	H.CustId = T.CustId
	WHERE	 @ToDate BETWEEN BeginDate AND ISNULL(EndDate,'9999-12-31')

	UPDATE  T
	SET		FromGradeBeginDate = H.BeginDate
	FROM	@Trader T
	INNER JOIN TraderGrade_History H WITH (NOLOCK)
			ON	H.CustId = T.CustId
	WHERE	 @FromDate BETWEEN BeginDate AND ISNULL(EndDate,'9999-12-31')
			 
	UPDATE  T
	SET		ToGradeBeginDate = H.BeginDate
	FROM	@Trader T
	INNER JOIN TraderGrade_History H WITH (NOLOCK)
			ON	H.CustId = T.CustId
	WHERE	 @ToDate BETWEEN BeginDate AND ISNULL(EndDate,'9999-12-31')		


	---------------------------------------------
	---Get Data 	
	IF @Top <> 0  ----Top
	BEGIN 
			IF @IsBottom = 0  
			BEGIN 
				SELECT  TOP (@Top) 
						T.CustId, T.Username, T.TeamName, T.Grade, T.MatchCount, T.BetCount, T.Turnover, T.WinLost, T.Margin, 
						ISNULL(TH.NoOfTeamChange,0) AS NoOfTeamChange,    -----( if NoOfTeamChange > 1 : had been changed team)
						ISNULL(GH.NoOfGradeChange,0) AS NoOfGradeChange 
				FROM	@Trader T
				LEFT JOIN (     SELECT H.CustId, COUNT(DISTINCT H.TeamId) AS NoOfTeamChange
								FROM	@Trader T 
								INNER JOIN dbo.TraderTeam_History H WITH (NOLOCK) 
										ON T.CustId = H.CustId
								WHERE  H.BeginDate >= ISNULL(T.FromTeamBeginDate, '1900-01-01')
									AND H.BeginDate <= ISNULL(T.ToTeamBeginDate, '1900-01-01')											 						 					 							
								GROUP BY H.CustId
							) TH
						ON TH.CustId = T.CustId
				LEFT JOIN (     SELECT H.CustId, COUNT(DISTINCT H.Grade) AS NoOfGradeChange
								FROM	@Trader T 
								INNER JOIN dbo.TraderGrade_History H WITH (NOLOCK) 
										ON T.CustId = H.CustId
								WHERE  H.BeginDate >= ISNULL(T.FromGradeBeginDate, '1900-01-01')
									AND H.BeginDate <= ISNULL(T.ToGradeBeginDate, '1900-01-01')											 						 					 							
								GROUP BY H.CustId
							) GH
						ON GH.CustID = T.CustID
				ORDER BY T.Margin DESC, T.WinLost DESC, T.Turnover DESC
			END 
			ELSE
			BEGIN 
				SELECT  TOP (@Top) 
						T.CustId, T.Username, T.TeamName, T.Grade, T.MatchCount, T.BetCount, T.Turnover, T.WinLost, T.Margin, 
						ISNULL(TH.NoOfTeamChange,0) AS NoOfTeamChange,    -----( if NoOfTeamChange > 1 : had been changed team)
						ISNULL(GH.NoOfGradeChange,0) AS NoOfGradeChange 
				FROM	@Trader T
				LEFT JOIN (     SELECT H.CustId, COUNT(DISTINCT H.TeamId) AS NoOfTeamChange
								FROM	@Trader T 
								INNER JOIN dbo.TraderTeam_History H WITH (NOLOCK) 
										ON T.CustId = H.CustId
								WHERE  H.BeginDate >= ISNULL(T.FromTeamBeginDate, '1900-01-01')
									AND H.BeginDate <= ISNULL(T.ToTeamBeginDate, '1900-01-01')											 						 					 							
								GROUP BY H.CustId
							) TH
						ON TH.CustId = T.CustId
				LEFT JOIN (     SELECT H.CustId, COUNT(DISTINCT H.Grade) AS NoOfGradeChange
								FROM	@Trader T 
								INNER JOIN dbo.TraderGrade_History H WITH (NOLOCK) 
										ON T.CustId = H.CustId
								WHERE  H.BeginDate >= ISNULL(T.FromTeamBeginDate, '1900-01-01')
									AND H.BeginDate <= ISNULL(T.ToTeamBeginDate, '1900-01-01')											 						 					 							
								GROUP BY H.CustId
							) GH
						ON GH.CustID = T.CustID
				ORDER BY T.Margin ASC, T.WinLost ASC, T.Turnover ASC

			END 
	END
	ELSE  --- GEt All data
	BEGIN 
			IF @IsBottom = 0  
			BEGIN 
				SELECT  
						T.CustId, T.Username, T.TeamName, T.Grade, T.MatchCount, T.BetCount, T.Turnover, T.WinLost, T.Margin, 
						ISNULL(TH.NoOfTeamChange,0) AS NoOfTeamChange,    -----( if NoOfTeamChange > 1 : had been changed team)
						ISNULL(GH.NoOfGradeChange,0) AS NoOfGradeChange 
				FROM	@Trader T
				LEFT JOIN (     SELECT H.CustId, COUNT(DISTINCT H.TeamId) AS NoOfTeamChange
								FROM	@Trader T 
								INNER JOIN dbo.TraderTeam_History H WITH (NOLOCK) 
										ON T.CustId = H.CustId
								WHERE  H.BeginDate >= ISNULL(T.FromTeamBeginDate, '1900-01-01')
									AND H.BeginDate <= ISNULL(T.ToTeamBeginDate, '1900-01-01')											 						 					 							
								GROUP BY H.CustId
							) TH
						ON TH.CustId = T.CustId
				LEFT JOIN (     SELECT H.CustId, COUNT(DISTINCT H.Grade) AS NoOfGradeChange
								FROM	@Trader T 
								INNER JOIN dbo.TraderGrade_History H WITH (NOLOCK) 
										ON T.CustId = H.CustId
								WHERE  H.BeginDate >= ISNULL(T.FromGradeBeginDate, '1900-01-01')
									AND H.BeginDate <= ISNULL(T.ToGradeBeginDate, '1900-01-01')											 						 					 							
								GROUP BY H.CustId
							) GH
						ON GH.CustID = T.CustID
				ORDER BY T.Margin DESC, T.WinLost DESC, T.Turnover DESC
			END 
			ELSE
			BEGIN 
				SELECT 
						T.CustId, T.Username, T.TeamName, T.Grade, T.MatchCount, T.BetCount, T.Turnover, T.WinLost, T.Margin, 
						ISNULL(TH.NoOfTeamChange,0) AS NoOfTeamChange,    -----( if NoOfTeamChange > 1 : had been changed team)
						ISNULL(GH.NoOfGradeChange,0) AS NoOfGradeChange 
				FROM	@Trader T
				LEFT JOIN (     SELECT H.CustId, COUNT(DISTINCT H.TeamId) AS NoOfTeamChange
								FROM	@Trader T 
								INNER JOIN dbo.TraderTeam_History H WITH (NOLOCK) 
										ON T.CustId = H.CustId
								WHERE  H.BeginDate >= ISNULL(T.FromTeamBeginDate, '1900-01-01')
									AND H.BeginDate <= ISNULL(T.ToTeamBeginDate, '1900-01-01')											 						 					 							
								GROUP BY H.CustId
							) TH
						ON TH.CustId = T.CustId
				LEFT JOIN (     SELECT H.CustId, COUNT(DISTINCT H.Grade) AS NoOfGradeChange
								FROM	@Trader T 
								INNER JOIN dbo.TraderGrade_History H WITH (NOLOCK) 
										ON T.CustId = H.CustId
								WHERE  H.BeginDate >= ISNULL(T.FromTeamBeginDate, '1900-01-01')
									AND H.BeginDate <= ISNULL(T.ToTeamBeginDate, '1900-01-01')											 						 					 							
								GROUP BY H.CustId
							) GH
						ON GH.CustID = T.CustID
				ORDER BY T.Margin ASC, T.WinLost ASC, T.Turnover ASC

			END 

	END


END 
GO
GRANT EXECUTE ON [dbo].[TGRS_Rpt_SummaryTopTrader] TO [bodbTGRSNet]
GO

 