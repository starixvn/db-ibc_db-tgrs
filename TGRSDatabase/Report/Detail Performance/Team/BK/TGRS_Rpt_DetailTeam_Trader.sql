ALTER PROCEDURE [dbo].[TGRS_Rpt_DetailTeam_Trader]  	
	@FromDate				DATE,
	@ToDate					DATE,
	@TeamId					SMALLINT,
	@Bettypes				VARCHAR(200) =  '0',
	@IsExcludeLeagues		BIT = 1
AS    
/*  
 Created:	20140523@Sophia
 Task :		Detail report Team Performance - Detail Trader 
 DB:		DBTGRS.bodb_TGRS
 Original:  
  
 Revisions:      
   	 - 20141208@Sophia: Calculate the Score	
 Param's Explanation:  	

 Exam: 
	EXEC TGRS_Rpt_DetailTeam_Trader @FromDate = '2014-01-01', @ToDate= '2014-05-31', @TeamId = 13, @Bettypes = '0'
*/  
 
BEGIN 
	 SET NOCOUNT ON;

	 DECLARE @Trader AS TABLE (CustId INT, Username VARCHAR(30), Grade TINYINT, LeagueCount INT, MatchCount INT, 
							   Turnover MONEY, WinLost MONEY, BetCount INT, Margin MONEY,
							   NoOfGradeChanged INT, Score MONEY);
	 DECLARE @AVGScore AS TABLE (CustId INT, Score MONEY);
	 DECLARE @BettypeList AS TABLE (bettype SMALLINT);

	 IF @Bettypes <> '0'
		 INSERT INTO @BettypeList
		 SELECT val FROM dbo.strSplit_Key(@Bettypes,',')
	 ELSE 
		 INSERT INTO @BettypeList
		 SELECT Bettype FROM dbo.Bettype WITH (NOLOCK)
			 
	 INSERT INTO @Trader (CustId, Username, Grade, LeagueCount, MatchCount, Turnover, WinLost, BetCount, Margin)
	 SELECT P.CustId, TR.Username,TR.Grade, 
			ISNULL(COUNT(DISTINCT P.LeagueId),0) AS LeagueCount,  
			ISNULL(COUNT(DISTINCT P.MatchId),0) AS MatchCount, 
			ISNULL(SUM(P.Stake),0) AS Turnover, 
			ISNULL(SUM(P.WinLost),0) - ISNULL(SUM (P.Comm),0) AS WinLost, 
			ISNULL(SUM (BetCount),0) as BetCount,
			CASE WHEN ISNULL(SUM(P.Stake),0) <> 0 THEN (ISNULL(SUM(P.WinLost),0) - ISNULL(SUM(P.Comm),0)) * 100/ISNULL(SUM(P.Stake),0) ELSE NULL END AS Margin	
	 FROM	dbo.TraderPerformance P WITH (NOLOCK)	
		INNER JOIN dbo.Trader TR WITH (NOLOCK) 
				ON TR.CustId= P.CustId	
	 WHERE	P.EventDate BETWEEN @FromDate AND @ToDate
			AND P.TeamId = @TeamId
			AND P.Bettype IN (SELECT Bettype FROM @BettypeList)
			AND (@IsExcludeLeagues = 0 OR (P.LeagueId NOT IN (SELECT le.LeagueId FROM dbo.LeagueExclusion le WHERE le.LeagueId = P.LeagueId)))
	GROUP BY P.CustId, TR.Username, TR.Grade;
	
	--------------------------- 
	UPDATE  T
	SET		NoOfGradeChanged = ISNULL(GH.NoOfGradeChanged,0) 
	FROM	@Trader T
	LEFT JOIN ( SELECT  T.CustId, COUNT(DISTINCT GH.Grade) AS NoOfGradeChanged
				FROM	@Trader T 
				INNER JOIN dbo.TraderGrade_History GH WITH (NOLOCK) 
						ON T.CustId = GH.CustId					
					    AND (@FromDate BETWEEN ISNULL(GH.BeginDate, '1900-01-01') AND ISNULL(GH.EndDate,'9999-12-31')
							OR @ToDate BETWEEN ISNULL(GH.BeginDate, '1900-01-01') AND ISNULL(GH.EndDate,'9999-12-31')
							)
				GROUP BY T.CustId
				) GH 
			ON GH.CustId = T.CustId;	 
	
	 ------------------------------
	---Calculate Score 
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
				AND P.TeamId = @TeamId
				AND ISNULL(B.Benchmark,0) <> 0
				AND (@IsExcludeLeagues = 0 OR (P.LeagueId NOT IN (SELECT le.LeagueId FROM dbo.LeagueExclusion le WHERE le.LeagueId = P.LeagueId)))
			GROUP BY P.CustId, P.LeagueId, P.BetType, P.WorkShift, B.Benchmark 
		) S
	GROUP BY S.CustId;

	UPDATE  T 
	SET		T.Score = S.Score
	FROM	@Trader T 
	INNER JOIN @AVGScore S 
		ON S.CustId = T.CustId;
	 
	 ---------------Get Data-------------------
	 SELECT * 
	 FROM @Trader
	 ORDER BY Margin DESC, Username ASC;
END;

GO
GRANT EXECUTE ON [dbo].[TGRS_Rpt_DetailTeam_Trader] TO [bodbTGRSNet]
GO

