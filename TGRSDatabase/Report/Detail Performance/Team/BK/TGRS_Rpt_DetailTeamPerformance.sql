ALTER PROCEDURE [dbo].[TGRS_Rpt_DetailTeamPerformance]  
	@FromDate				DATE,
	@ToDate					DATE,
	@TeamIds				VARCHAR(200) =  '0',
	@TeamBMFrom				MONEY = NULL,
	@TeamBMTo				MONEY = NULL,
	@Turnover				MONEY = NULL,
	@WinLost				MONEY = NULL,
	@MarginFrom				MONEY = NULL,
	@MarginTo				MONEY = NULL,  
	@Bettypes				VARCHAR(200) =  '0',
	@IsExcludeLeagues		BIT = 1
AS    
/*  
 Created:	20140523@Sophia
 Task :		Detail report Team Performance
 DB:		DBTGRS.bodb_TGRS
 Original:  
	
 Revisions:      
   	  	- 20140728@Sophia: Change Benchmark to percentage instead of decimal number				
		- 20141205@Sophia: Calculate the Score 	
		- 20180911@Long:	Support excluding Leagues from report [Redmine ID: #100322]

 Param's Explanation: 	
	@TeamIds = '0' : All 			
	@Bettypes = '0': All

 Exam: 
	EXEC TGRS_Rpt_DetailTeamPerformance @FromDate = '2013-01-01', @ToDate= '2014-05-31',  @Bettypes = '0', @TeamIds = '18,13'

*/  
 
BEGIN 
	 SET NOCOUNT ON;
	 
	 DECLARE @BettypeList AS TABLE (bettype SMALLINT);

	 IF @Bettypes <> '0'
		 INSERT INTO @BettypeList
		 SELECT val FROM dbo.strSplit_Key(@Bettypes,',')
	 ELSE 
		 INSERT INTO @BettypeList
		 SELECT Bettype FROM dbo.Bettype WITH (NOLOCK)

	 DECLARE @TeamList AS TABLE (TeamId SMALLINT)
	 IF @TeamIds <> '0'
		 INSERT INTO @TeamList
		 SELECT val FROM dbo.strSplit_Key(@TeamIds,',')
	 ELSE 
		 INSERT INTO @TeamList
		 SELECT TeamId FROM dbo.Team WITH (NOLOCK) 
	
	DECLARE @Rpt TABLE (TeamId SMALLINT, TeamName NVARCHAR(50), TeamBenchmark MONEY, TraderCount INT, LeagueCount INT, MatchCount INT, Turnover MONEY, WinLost MONEY, BetCount INT, Margin MONEY, Score MONEY)
	DECLARE @AVGScore AS TABLE (TeamId SMALLINT, Score MONEY)
		
	INSERT INTO @Rpt (TeamId, TeamName, TeamBenchmark, TraderCount, LeagueCount, MatchCount, Turnover, WinLost, BetCount, Margin)	 	
	SELECT	P.TeamId, T.TeamName,
			ISNULL(BT.Benchmark,0) * 100 AS TeamBenchmark,
			ISNULL(COUNT(DISTINCT P.CustId),0) AS TraderCount, 
			ISNULL(COUNT(DISTINCT P.LeagueId),0) AS LeagueCount, 
			ISNULL(COUNT(DISTINCT P.MatchId),0) AS MatchCount, 
			ISNULL(SUM(P.Stake),0) AS Turnover, 
			ISNULL(SUM(P.WinLost),0) - ISNULL(SUM (P.Comm),0) AS WinLost, 
			ISNULL(SUM (BetCount),0) AS BetCount,
			CASE WHEN ISNULL(SUM(P.Stake),0) <> 0 THEN (ISNULL(SUM(P.WinLost),0) - ISNULL(SUM(P.Comm),0)) * 100/ISNULL(SUM(P.Stake),0) ELSE NULL END AS Margin				
	FROM	dbo.TraderPerformance P WITH (NOLOCK)
	INNER JOIN dbo.Team T WITH (NOLOCK) 
			 ON T.TeamId = P.TeamId
	LEFT JOIN dbo.Benchmark_Team BT WITH (NOLOCK)
			 ON BT.TeamId = P.TeamId
	WHERE	P.EventDate BETWEEN @FromDate AND @ToDate			
			AND ISNULL(BT.Benchmark,0) * 100 >= CASE WHEN @TeamBMFrom IS NULL THEN ISNULL(BT.Benchmark,0) * 100 ELSE @TeamBMFrom END 
			AND ISNULL(BT.Benchmark,0) * 100 <= CASE WHEN @TeamBMTo IS NULL THEN ISNULL(BT.Benchmark,0) * 100 ELSE @TeamBMTo END 
			AND P.Bettype IN (SELECT Bettype FROM @BettypeList)
			AND P.TeamId IN (SELECT TeamId FROM @TeamList)	
			AND (@IsExcludeLeagues = 0 OR (P.LeagueId NOT IN (SELECT le.LeagueId FROM dbo.LeagueExclusion le WITH(NOLOCK))))		
	GROUP BY P.TeamId, ISNULL(BT.Benchmark,0), T.TeamName
	HAVING	(@Turnover IS NULL OR ISNULL(SUM(P.Stake),0) >= ISNULL(@Turnover,0))
			AND (@WinLost IS NULL OR ISNULL(SUM(P.WinLost),0) - ISNULL(SUM(P.Comm),0) >= ISNULL(@WinLost,0))
			AND CASE WHEN ISNULL(SUM(P.Stake),0) <> 0 
					 THEN (ISNULL(SUM(P.WinLost),0)- ISNULL(SUM(P.Comm),0))* 100 /ISNULL(SUM(P.Stake),0) 
					 ELSE 0 END 
				>= CASE WHEN @MarginFrom IS NULL 
						THEN CASE WHEN ISNULL(SUM(P.Stake),0) <> 0	
								  THEN (ISNULL(SUM(P.WinLost),0) - ISNULL(SUM(P.Comm),0)) * 100 /ISNULL(SUM(P.Stake),0)
								  ELSE 0 END 
						ELSE @MarginFrom END 
			AND CASE WHEN ISNULL(SUM(P.Stake),0) <> 0 
					 THEN (ISNULL(SUM(P.WinLost),0) - ISNULL(SUM(P.Comm),0)) * 100/ISNULL(SUM(P.Stake),0)
					 ELSE 0 END 
				<= CASE WHEN @MarginTo IS NULL 
						THEN CASE WHEN ISNULL(SUM(P.Stake),0) <> 0 
								  THEN (ISNULL(SUM(P.WinLost),0) - ISNULL(SUM(P.Comm),0)) * 100 /ISNULL(SUM(P.Stake),0)
								  ELSE 0 END 
						ELSE @MarginTo END;
	

	------------------------------
	---Calculate Score 
	INSERT INTO @AVGScore (TeamId, Score)
	SELECT S.TeamId , AVG (S.Score) as Score
	FROM (
			SELECT  P.TeamId, P.LeagueId, P.BetType, P.WorkShift, 
					(CASE WHEN ISNULL(SUM(P.Stake),0) <> 0 AND ISNULL(B.Benchmark, 0) <> 0 THEN ((ISNULL(SUM(P.WinLost),0) - ISNULL(SUM(P.Comm),0)) * 50 / ISNULL(SUM(P.Stake),0) )/ ISNULL(B.Benchmark, 0) ELSE NULL END) AS Score
			FROM	dbo.TraderPerformance P WITH (NOLOCK)		
			INNER JOIN Benchmark_BetType B WITH (NOLOCK)		    
				ON	P.LeagueId = B.LeagueId
				AND P.Bettype = B.Bettype
				AND P.WorkShift = B.WorkShift
			WHERE	P.EventDate BETWEEN @FromDate AND @ToDate			
				AND P.Bettype IN (SELECT Bettype FROM @BettypeList)
				AND P.TeamId IN (SELECT TeamId FROM @TeamList)	
				AND ISNULL(B.Benchmark,0) <> 0
				AND (@IsExcludeLeagues = 0 OR (P.LeagueId NOT IN (SELECT le.LeagueId FROM dbo.LeagueExclusion le WITH(NOLOCK) WHERE le.LeagueId = P.LeagueId)))
			GROUP BY P.TeamId, P.LeagueId, P.BetType, P.WorkShift, B.Benchmark 
		) S
	GROUP BY S.TeamId;

	UPDATE  T 
	SET		T.Score = S.Score
	FROM	@Rpt T 
	INNER JOIN @AVGScore S 
		ON S.TeamId = T.TeamId;

	------------------------------------------------------------
	SELECT * FROM @Rpt 
	ORDER BY Margin DESC, TeamName ASC;
END;

GO
GRANT EXECUTE ON [dbo].[TGRS_Rpt_DetailTeamPerformance] TO [bodbTGRSNet]
GO

 

GO
/*<info serverAlias="DBTGRS-bodb_TGRS" executers="bodbTGRSNet" isFunction="0" isNested="0"></info>*/