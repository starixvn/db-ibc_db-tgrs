ALTER PROCEDURE [dbo].[TGRS_Rpt_DetailLeague_Trader]  	
	@FromDate	DATE,
	@ToDate		DATE,
	@LeagueId	INT,
	@Bettypes	VARCHAR(200) =  '0'
AS    
/*  
 Created:	20140523@Sophia
 Task :		Detail report League Performance - Detail Trader of List
 DB:		DBTGRS.bodb_TGRS
 Original:  
  
 Revisions:      
   			
 Param's Explanation:  	

 Exam: 
	EXEC TGRS_Rpt_DailyLeague_Trader @FromDate = '2014-01-01', @ToDate= '2014-05-31', @LeagueId = 6394, @Bettypes = '0'
	 
  
*/  
 
BEGIN 
	 SET NOCOUNT ON  

	 DECLARE @Trader AS TABLE (CustId INT, Username VARCHAR(30), Grade TINYINT, TeamId SMALLINT, TeamName NVARCHAR(50), MatchCount INT, Turnover MONEY, WinLost MONEY, BetCount INT, Margin MONEY,
							   FromTeamBeginDate DATE NULL, ToTeamBeginDate DATE NULL, FromGradeBeginDate DATE NULL, ToGradeBeginDate DATE NULL)	 

	 DECLARE @BettypeList AS TABLE (bettype SMALLINT)
	 IF @Bettypes <> '0'
		 INSERT INTO @BettypeList
		 SELECT val FROM dbo.strSplit_Key(@Bettypes,',')
	 ELSE 
		 INSERT INTO @BettypeList
		 SELECT Bettype FROM dbo.Bettype WITH (NOLOCK)
	
		 
	 INSERT INTO @Trader (CustId, Username, Grade, TeamId, TeamName, MatchCount, Turnover, WinLost, BetCount, Margin)
	 SELECT P.CustId, TR.Username, TR.Grade, TR.TeamId, T.TeamName, 
			COUNT(DISTINCT P.MatchId) AS MatchCount, 
			SUM(P.Stake) AS Turnover, 
			SUM(P.WinLost) - SUM (P.Comm) AS WinLost, 
			SUM (BetCount) as BetCount,
			CASE WHEN SUM(P.Stake) <> 0 THEN (SUM(P.WinLost)-SUM(P.Comm))/SUM(P.Stake) ELSE NULL END AS Margin	
	 FROM	dbo.TraderPerformance P WITH (NOLOCK)	
		INNER JOIN dbo.Trader TR WITH (NOLOCK) 
				ON TR.CustId= P.CustId
		INNER JOIN dbo.Team T WITH (NOLOCK) 
				ON T.TeamId = TR.TeamId
	 WHERE	P.EventDate BETWEEN @FromDate AND @ToDate
			AND P.LeagueId = @LeagueId
			AND P.Bettype IN (SELECT Bettype FROM @BettypeList)
	GROUP BY P.CustId, TR.Username, TR.Grade, TR.TeamId, T.TeamName



---------------

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

-----------------
		SELECT	T.CustId, T.Username, T.TeamName, T.Grade, T.MatchCount, T.BetCount, T.Turnover, T.WinLost, T.Margin, 
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
		ORDER BY T.Username 

END 
GO
GRANT EXECUTE ON [dbo].[TGRS_Rpt_DetailLeague_Trader] TO [bodbTGRSNet]
GO

