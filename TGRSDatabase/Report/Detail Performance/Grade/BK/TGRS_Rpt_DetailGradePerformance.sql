ALTER PROCEDURE [dbo].[TGRS_Rpt_DetailGradePerformance]  
	@FromDate				DATE,
	@ToDate					DATE,
	@Turnover				MONEY = NULL,
	@WinLost				MONEY = NULL,
	@MarginFrom				MONEY = NULL,
	@MarginTo				MONEY = NULL,  
	@Bettypes				VARCHAR(2000) =  '0',
	@IsExcludeLeagues		BIT = 1
AS    
/*  
 Created:	20140523@Sophia
 Task :		Detail report Grade Performance
 DB:		DBTGRS.bodb_TGRS
 Original:  
  
 Revisions:      
   	- 20141205@Sophia: Calculate the Score 	
	- 20180911@Long:	Support excluding Leagues from report [Redmine ID: #100322]

 Param's Explanation:  	

 Exam: 	
	EXEC TGRS_Rpt_DetailGradePerformance_xtest  @FromDate='2014-11-19 00:00:00',@WinLost=NULL,@Turnover=NULL,@MarginTo=NULL,@MarginFrom=NULL,@Bettypes='0',@ToDate='2014-12-03 00:00:00'
*/   
BEGIN 
	 SET NOCOUNT ON;

	DECLARE @Grade TABLE (Grade TINYINT, TraderCount INT, LeagueCount INT, MatchCount INT, Turnover MONEY, WinLost MONEY, BetCount INT, Margin MONEY, Score MONEY);
	DECLARE @AVGScore AS TABLE (Grade TINYINT, Score MONEY);	 
	DECLARE @BettypeList AS TABLE (bettype SMALLINT);
	
	IF @Bettypes <> '0'
		INSERT INTO @BettypeList
		SELECT val FROM dbo.strSplit_Key(@Bettypes,',')
	ELSE 
		INSERT INTO @BettypeList
		SELECT Bettype FROM dbo.Bettype WITH (NOLOCK);

	IF @IsExcludeLeagues = 0
	BEGIN
		INSERT INTO @Grade (Grade, TraderCount, LeagueCount, MatchCount, Turnover, WinLost, BetCount, Margin) 	
		SELECT	P.Grade,
				ISNULL(COUNT(DISTINCT P.CustId),0) AS TraderCount, 
				ISNULL(COUNT(DISTINCT P.LeagueId),0) AS LeagueCount,  
				ISNULL(COUNT(DISTINCT P.MatchId),0) AS MatchCount, 
				ISNULL(SUM(P.Stake),0) AS Turnover, 
				ISNULL(SUM(P.WinLost),0) - ISNULL(SUM (P.Comm),0) AS WinLost, 
				ISNULL(SUM(P.BetCount),0) as BetCount,
				CASE WHEN ISNULL(SUM(P.Stake),0) <> 0 THEN (ISNULL(SUM(P.WinLost),0) - ISNULL(SUM(P.Comm),0)) * 100/ISNULL(SUM(P.Stake),0) ELSE NULL END AS Margin			 
		FROM	dbo.TraderPerformance P WITH (NOLOCK)			     
		WHERE	P.EventDate BETWEEN @FromDate AND @ToDate			
				AND P.Bettype IN (SELECT Bettype FROM @BettypeList)
		GROUP BY P.Grade
		HAVING  (@Turnover IS NULL OR ISNULL(SUM(P.Stake),0) >= ISNULL(@Turnover,0))
				AND (@WinLost IS NULL OR ISNULL(SUM(P.WinLost),0) - ISNULL(SUM(P.Comm),0) >= ISNULL(@WinLost,0))
				AND CASE WHEN ISNULL(SUM(P.Stake),0) <> 0 
						 THEN (ISNULL(SUM(P.WinLost),0)- ISNULL(SUM(P.Comm),0)) *100 /ISNULL(SUM(P.Stake),0)
						 ELSE 0 END 
					>= CASE WHEN @MarginFrom IS NULL 
							THEN CASE WHEN ISNULL(SUM(P.Stake),0) <> 0 
									  THEN (ISNULL(SUM(P.WinLost),0) - ISNULL(SUM(P.Comm),0)) *100 /ISNULL(SUM(P.Stake),0)
									  ELSE 0 END 
							ELSE @MarginFrom END 
				AND CASE WHEN ISNULL(SUM(P.Stake),0) <> 0 
						 THEN (ISNULL(SUM(P.WinLost),0) - ISNULL(SUM(P.Comm),0)) *100 /ISNULL(SUM(P.Stake),0)
						 ELSE 0 END 
					<= CASE WHEN @MarginTo IS NULL 
							THEN CASE WHEN ISNULL(SUM(P.Stake),0) <> 0 
									  THEN (ISNULL(SUM(P.WinLost),0) - ISNULL(SUM(P.Comm),0)) *100 /ISNULL(SUM(P.Stake),0)
									  ELSE 0 END 
							ELSE @MarginTo END;	

		INSERT INTO @AVGScore (Grade, Score)
		SELECT S.Grade , AVG (S.Score) as Score
		FROM (
		SELECT P.Grade, P.LeagueId, P.BetType, P.WorkShift, 
			(CASE WHEN ISNULL(SUM(P.Stake),0) <> 0 AND ISNULL(B.Benchmark, 0) <> 0 THEN ((ISNULL(SUM(P.WinLost),0) - ISNULL(SUM(P.Comm),0)) * 50 / ISNULL(SUM(P.Stake),0) )/ ISNULL(B.Benchmark, 0) ELSE NULL END) AS Score
		FROM	dbo.TraderPerformance P WITH (NOLOCK)		
		INNER JOIN Benchmark_BetType B WITH (NOLOCK)		    
			ON	P.LeagueId = B.LeagueId
			AND P.Bettype = B.Bettype
			AND P.WorkShift = B.WorkShift
		WHERE	P.EventDate BETWEEN @FromDate AND @ToDate			
			AND P.Bettype IN (SELECT Bettype FROM @BettypeList)
			AND ISNULL(B.Benchmark,0) <> 0
		GROUP BY P.Grade, P.LeagueId, P.BetType, P.WorkShift, B.Benchmark 
		) S
		GROUP BY S.Grade;
	END
	ELSE
	BEGIN
		INSERT INTO @Grade (Grade, TraderCount, LeagueCount, MatchCount, Turnover, WinLost, BetCount, Margin) 	
		SELECT	P.Grade,
				ISNULL(COUNT(DISTINCT P.CustId),0) AS TraderCount, 
				ISNULL(COUNT(DISTINCT P.LeagueId),0) AS LeagueCount,  
				ISNULL(COUNT(DISTINCT P.MatchId),0) AS MatchCount, 
				ISNULL(SUM(P.Stake),0) AS Turnover, 
				ISNULL(SUM(P.WinLost),0) - ISNULL(SUM (P.Comm),0) AS WinLost, 
				ISNULL(SUM(P.BetCount),0) as BetCount,
				CASE WHEN ISNULL(SUM(P.Stake),0) <> 0 THEN (ISNULL(SUM(P.WinLost),0) - ISNULL(SUM(P.Comm),0)) * 100/ISNULL(SUM(P.Stake),0) ELSE NULL END AS Margin			 
		FROM	dbo.TraderPerformance P WITH (NOLOCK)
		LEFT JOIN dbo.LeagueExclusion AS le WITH(NOLOCK) ON P.LeagueId = le.LeagueId			     
		WHERE	P.EventDate BETWEEN @FromDate AND @ToDate		
				AND le.LeagueId IS NULL	
				AND P.Bettype IN (SELECT Bettype FROM @BettypeList)
		GROUP BY P.Grade
		HAVING  (@Turnover IS NULL OR ISNULL(SUM(P.Stake),0) >= ISNULL(@Turnover,0))
				AND (@WinLost IS NULL OR ISNULL(SUM(P.WinLost),0) - ISNULL(SUM(P.Comm),0) >= ISNULL(@WinLost,0))
				AND CASE WHEN ISNULL(SUM(P.Stake),0) <> 0 
						 THEN (ISNULL(SUM(P.WinLost),0)- ISNULL(SUM(P.Comm),0)) *100 /ISNULL(SUM(P.Stake),0)
						 ELSE 0 END 
					>= CASE WHEN @MarginFrom IS NULL 
							THEN CASE WHEN ISNULL(SUM(P.Stake),0) <> 0 
									  THEN (ISNULL(SUM(P.WinLost),0) - ISNULL(SUM(P.Comm),0)) *100 /ISNULL(SUM(P.Stake),0)
									  ELSE 0 END 
							ELSE @MarginFrom END 
				AND CASE WHEN ISNULL(SUM(P.Stake),0) <> 0 
						 THEN (ISNULL(SUM(P.WinLost),0) - ISNULL(SUM(P.Comm),0)) *100 /ISNULL(SUM(P.Stake),0)
						 ELSE 0 END 
					<= CASE WHEN @MarginTo IS NULL 
							THEN CASE WHEN ISNULL(SUM(P.Stake),0) <> 0 
									  THEN (ISNULL(SUM(P.WinLost),0) - ISNULL(SUM(P.Comm),0)) *100 /ISNULL(SUM(P.Stake),0)
									  ELSE 0 END 
							ELSE @MarginTo END;	

		INSERT INTO @AVGScore (Grade, Score)
		SELECT S.Grade , AVG (S.Score) as Score
		FROM (
		SELECT P.Grade, P.LeagueId, P.BetType, P.WorkShift, 
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
			AND ISNULL(B.Benchmark,0) <> 0
		GROUP BY P.Grade, P.LeagueId, P.BetType, P.WorkShift, B.Benchmark 
		) S
		GROUP BY S.Grade;
	END;

	UPDATE  G 
	SET		G.Score = S.Score
	FROM	@Grade G 
	INNER JOIN @AVGScore S ON S.Grade = G.Grade;

	SELECT * FROM @Grade
	ORDER BY Margin DESC, Grade ASC;
END;

GO
GRANT EXECUTE ON [dbo].[TGRS_Rpt_DetailGradePerformance] TO [bodbTGRSNet]
GO

 
/*<info serverAlias="DBTGRS - bodb_TGRS" executers="bodbTGRSNet" isFunction="0" isNested="0"></info>*/