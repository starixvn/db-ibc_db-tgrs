ALTER PROCEDURE [dbo].[TGRS_Rpt_DetailLeague_Trader]  	
	@FromDate	DATE,
	@ToDate		DATE,
	@LeagueId	INT = 0,
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
	EXEC [TGRS_Rpt_DetailLeague_Trader] @FromDate = '2014-01-01', @ToDate= '2014-05-31', @LeagueId = 6394, @Bettypes = '0'
	EXEC [TGRS_Rpt_DetailLeague_Trader_Xtest] @FromDate = '2014-01-01', @ToDate= '2014-05-31', @LeagueId = 6394, @Bettypes = '0' 
  
*/  
 
BEGIN 
	 SET NOCOUNT ON  

	 --DECLARE @Trader AS TABLE (CustId INT, Username VARCHAR(30), Grade TINYINT, TeamId SMALLINT, TeamName NVARCHAR(50), MatchCount INT, Turnover MONEY, WinLost MONEY, BetCount INT, Margin MONEY,
		--					   NoOfTeamChange INT,  NoOfGradeChange INT)

	 DECLARE @BettypeList AS TABLE (bettype SMALLINT)
	 IF @Bettypes <> '0'
		 INSERT INTO @BettypeList
		 SELECT val FROM dbo.strSplit_Key(@Bettypes,',')
	 ELSE 
		 INSERT INTO @BettypeList
		 SELECT Bettype FROM dbo.Bettype WITH (NOLOCK)
	
		 
	-- INSERT INTO @Trader (CustId, Username, Grade, TeamId, TeamName, MatchCount, Turnover, WinLost, BetCount, Margin, NoOfTeamChange,NoOfGradeChange)
	 SELECT P.CustId, TR.Username, TR.Grade, TR.TeamId, T.TeamName, 
			ISNULL(COUNT(DISTINCT P.MatchId),0) AS MatchCount, 
			ISNULL(SUM(P.Stake),0) AS Turnover, 
			ISNULL(SUM(P.WinLost),0) - ISNULL(SUM (P.Comm),0) AS WinLost, 
			ISNULL(SUM (BetCount),0) as BetCount,
			CASE WHEN ISNULL(SUM(P.Stake),0) <> 0 THEN (ISNULL(SUM(P.WinLost),0) - ISNULL(SUM(P.Comm),0))/ISNULL(SUM(P.Stake),0) ELSE NULL END AS Margin,
			ISNULL(COUNT(DISTINCT TH.TeamId),0) AS NoOfTeamChange, 
			ISNULL(COUNT(DISTINCT GH.Grade),0) AS NoOfGradeChange	
	 FROM	dbo.TraderPerformance P WITH (NOLOCK)
		LEFT JOIN dbo.TraderTeam_History TH WITH (NOLOCK) 
				ON TH.CustId = P.CustId
				    AND (@FromDate BETWEEN ISNULL(TH.BeginDate, '1900-01-01') AND ISNULL(TH.EndDate,'9999-12-31')
						OR @ToDate BETWEEN ISNULL(TH.BeginDate, '1900-01-01') AND ISNULL(TH.EndDate,'9999-12-31')
						)
		LEFT JOIN dbo.TraderGrade_History GH WITH (NOLOCK) 
				ON GH.CustId = P.CustId
				    AND (@FromDate BETWEEN ISNULL(GH.BeginDate, '1900-01-01') AND ISNULL(GH.EndDate,'9999-12-31')
						OR @ToDate BETWEEN ISNULL(GH.BeginDate, '1900-01-01') AND ISNULL(GH.EndDate,'9999-12-31')
						)	
		INNER JOIN dbo.Trader TR WITH (NOLOCK) 
				ON TR.CustId= P.CustId
		INNER JOIN dbo.Team T WITH (NOLOCK) 
				ON T.TeamId = TR.TeamId
	 WHERE	P.EventDate BETWEEN @FromDate AND @ToDate
			AND P.LeagueId = @LeagueId
			AND P.Bettype IN (SELECT Bettype FROM @BettypeList)
	GROUP BY P.CustId, TR.Username, TR.Grade, TR.TeamId, T.TeamName
	ORDER BY Margin DESC
	 
 
---- 

END 
GO
GRANT EXECUTE ON [dbo].[TGRS_Rpt_DetailLeague_Trader] TO [bodbTGRSNet]
GO

