ALTER PROCEDURE [dbo].[TGRS_Rpt_DetailGrade_Trader]  	
	@FromDate				DATE,
	@ToDate					DATE,
	@Grade					TINYINT,
	@Bettypes				VARCHAR(2000) =  '0',
	@IsExcludeLeagues		BIT = 1
AS    
/*  
 Created:	20140523@Sophia
 Task :		Detail report Grade Performance - Detail Trader 
 DB:		DBTGRS.bodb_TGRS
 Original:  
  
 Revisions:      
   	 - 20141208@Sophia: Calculate the Score   
	- 20180911@Long:	Support excluding Leagues from report [Redmine ID: #100322]
	 	
 Param's Explanation:  	

 Exam: 
	EXEC TGRS_Rpt_DetailGrade_Trader @FromDate = '2014-01-01', @ToDate= '2014-05-31', @Grade = 1, @Bettypes = '0'  
*/   
BEGIN 
	 SET NOCOUNT ON;

	 DECLARE @Trader AS TABLE (CustId INT, Username VARCHAR(30), TeamId SMALLINT, TeamName NVARCHAR(50), LeagueCount INT, MatchCount INT, Turnover MONEY, WinLost MONEY, BetCount INT, Margin MONEY,
							   NoOfTeamChanged INT,  NoOfGradeChanged INT, Score MONEY);
	 DECLARE @AVGScore AS TABLE (CustId INT, Score MONEY);	

	 DECLARE @BettypeList AS TABLE (bettype SMALLINT)
	 IF @Bettypes <> '0'
		 INSERT INTO @BettypeList
		 SELECT val FROM dbo.strSplit_Key(@Bettypes,',')
	 ELSE 
		 INSERT INTO @BettypeList
		 SELECT Bettype FROM dbo.Bettype WITH (NOLOCK)
	
	IF @IsExcludeLeagues = 0
	BEGIN
		INSERT INTO @Trader (CustId, Username, TeamId, LeagueCount, MatchCount, Turnover, WinLost, BetCount, Margin)
		SELECT P.CustId, TR.Username,TR.TeamId,
			ISNULL(COUNT(DISTINCT P.LeagueId),0) AS LeagueCount,  
			ISNULL(COUNT(DISTINCT P.MatchId),0) AS MatchCount, 
			ISNULL(SUM(P.Stake),0) AS Turnover, 
			ISNULL(SUM(P.WinLost),0) - ISNULL(SUM (P.Comm),0) AS WinLost, 
			ISNULL(SUM (BetCount),0) as BetCount,
			CASE WHEN ISNULL(SUM(P.Stake),0) <> 0 THEN (ISNULL(SUM(P.WinLost),0) - ISNULL(SUM(P.Comm),0)) * 100/ISNULL(SUM(P.Stake),0)  ELSE NULL END AS Margin					
		FROM	dbo.TraderPerformance P WITH (NOLOCK)	
		INNER JOIN dbo.Trader TR WITH (NOLOCK) 
				ON TR.CustId= P.CustId	
		WHERE	P.EventDate BETWEEN @FromDate AND @ToDate
			AND P.Grade = @Grade
			AND P.Bettype IN (SELECT Bettype FROM @BettypeList)
		GROUP BY P.CustId, TR.Username, TR.TeamId;
	END
	ELSE
	BEGIN
		INSERT INTO @Trader (CustId, Username, TeamId, LeagueCount, MatchCount, Turnover, WinLost, BetCount, Margin)
		SELECT P.CustId, TR.Username,TR.TeamId,
			ISNULL(COUNT(DISTINCT P.LeagueId),0) AS LeagueCount,  
			ISNULL(COUNT(DISTINCT P.MatchId),0) AS MatchCount, 
			ISNULL(SUM(P.Stake),0) AS Turnover, 
			ISNULL(SUM(P.WinLost),0) - ISNULL(SUM (P.Comm),0) AS WinLost, 
			ISNULL(SUM (BetCount),0) as BetCount,
			CASE WHEN ISNULL(SUM(P.Stake),0) <> 0 THEN (ISNULL(SUM(P.WinLost),0) - ISNULL(SUM(P.Comm),0)) * 100/ISNULL(SUM(P.Stake),0)  ELSE NULL END AS Margin					
		FROM	dbo.TraderPerformance P WITH (NOLOCK)	
		INNER JOIN dbo.Trader TR WITH (NOLOCK) 
				ON TR.CustId= P.CustId	
		LEFT JOIN dbo.LeagueExclusion AS le WITH(NOLOCK) ON P.LeagueId = le.LeagueId
		WHERE	P.EventDate BETWEEN @FromDate AND @ToDate
			AND le.LeagueId IS NULL
			AND P.Grade = @Grade
			AND P.Bettype IN (SELECT Bettype FROM @BettypeList)
		GROUP BY P.CustId, TR.Username, TR.TeamId;
	END;

	---------------------------
	UPDATE  T
	SET		TeamName = TE.TeamName
	FROM	@Trader T
	INNER JOIN dbo.Team TE WITH (NOLOCK) 
			ON T.TeamId = TE.TeamId;		 

	UPDATE  T
	SET		NoOfTeamChanged = ISNULL(TH.NoOfTeamChanged,0),
			NoOfGradeChanged = ISNULL(GH.NoOfGradeChanged,0)	
	FROM	@Trader T
	LEFT JOIN ( SELECT  T.CustId, COUNT(DISTINCT TH.TeamId) AS NoOfTeamChanged
				FROM	@Trader T 
				INNER JOIN dbo.TraderTeam_History TH WITH (NOLOCK) 
						ON T.CustId = TH.CustId					
					    AND (@FromDate BETWEEN ISNULL(TH.BeginDate, '1900-01-01') AND ISNULL(TH.EndDate,'9999-12-31')
							OR @ToDate BETWEEN ISNULL(TH.BeginDate, '1900-01-01') AND ISNULL(TH.EndDate,'9999-12-31')
							)
				GROUP BY T.CustId
				) TH 
			ON TH.CustId = T.CustId
	LEFT JOIN (	SELECT  T.CustId, COUNT(DISTINCT GH.Grade) AS NoOfGradeChanged
				FROM	@Trader T 
				INNER JOIN dbo.TraderGrade_History GH WITH (NOLOCK) 
					ON GH.CustId = T.CustId
					    AND (@FromDate BETWEEN ISNULL(GH.BeginDate, '1900-01-01') AND ISNULL(GH.EndDate,'9999-12-31')
							OR @ToDate BETWEEN ISNULL(GH.BeginDate, '1900-01-01') AND ISNULL(GH.EndDate,'9999-12-31')
							)
					GROUP BY T.CustId
				) GH
			ON GH.CustId = T.CustId;
	
	 ------------------------------
	---Calculate Score 
	IF @IsExcludeLeagues = 0
	BEGIN
		INSERT INTO @AVGScore (CustId, Score)
		SELECT S.CustId , AVG (S.Score) as Score
		FROM (
				SELECT  P.CustId, P.LeagueId, P.BetType, P.WorkShift, 
						(CASE WHEN ISNULL(SUM(P.Stake),0) <> 0 AND ISNULL(B.Benchmark, 0) <> 0 THEN ((ISNULL(SUM(P.WinLost),0) - ISNULL(SUM(P.Comm),0)) * 50 / ISNULL(SUM(P.Stake),0) )/ ISNULL(B.Benchmark, 0) ELSE NULL END) AS Score
				FROM	dbo.TraderPerformance P WITH (NOLOCK)		
				INNER JOIN Benchmark_BetType B WITH (NOLOCK)		    
					ON	P.LeagueId = B.LeagueId
					AND P.Bettype = B.Bettype
					AND P.WorkShift = B.WorkShift
				WHERE	P.EventDate BETWEEN @FromDate AND @ToDate			
					AND P.Bettype IN (SELECT Bettype FROM @BettypeList)		
					AND P.Grade = @Grade		
					AND ISNULL(B.Benchmark,0) <> 0
				GROUP BY P.CustId, P.LeagueId, P.BetType, P.WorkShift, B.Benchmark 
			) S
		GROUP BY S.CustId;
	END
	ELSE
	BEGIN
		INSERT INTO @AVGScore (CustId, Score)
		SELECT S.CustId , AVG (S.Score) as Score
		FROM (
				SELECT  P.CustId, P.LeagueId, P.BetType, P.WorkShift, 
						(CASE WHEN ISNULL(SUM(P.Stake),0) <> 0 AND ISNULL(B.Benchmark, 0) <> 0 THEN ((ISNULL(SUM(P.WinLost),0) - ISNULL(SUM(P.Comm),0)) * 50 / ISNULL(SUM(P.Stake),0) )/ ISNULL(B.Benchmark, 0) ELSE NULL END) AS Score
				FROM	dbo.TraderPerformance P WITH (NOLOCK)		
				INNER JOIN Benchmark_BetType B WITH (NOLOCK)		    
					ON	P.LeagueId = B.LeagueId
					AND P.Bettype = B.Bettype
					AND P.WorkShift = B.WorkShift
				LEFT JOIN dbo.LeagueExclusion AS le WITH(NOLOCK) ON P.LeagueId = le.LeagueId
				WHERE	P.EventDate BETWEEN @FromDate AND @ToDate		
					AND le.LeagueId IS NULL	
					AND P.Bettype IN (SELECT Bettype FROM @BettypeList)		
					AND P.Grade = @Grade		
					AND ISNULL(B.Benchmark,0) <> 0
				GROUP BY P.CustId, P.LeagueId, P.BetType, P.WorkShift, B.Benchmark 
			) S
		GROUP BY S.CustId;
	END;

	UPDATE  T 
	SET		T.Score = S.Score
	FROM	@Trader T 
	INNER JOIN @AVGScore S ON S.CustId = T.CustId;

	 ---------------Get Data-------------------
	 SELECT * 
	 FROM @Trader
	 ORDER BY Margin DESC, Username ASC;
END;

GO
GRANT EXECUTE ON [dbo].[TGRS_Rpt_DetailGrade_Trader] TO [bodbTGRSNet]
GO

