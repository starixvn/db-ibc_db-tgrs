USE [bodb_TGRS]
GO
/****** Object:  StoredProcedure [dbo].[TGRS_Rpt_PerformanceDetail_League]    Script Date: 3/15/2016 1:48:52 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[TGRS_Rpt_PerformanceDetail_Bettype_League]  	
	@FromDate		DATE,
	@ToDate			DATE,	
	@Turnover		MONEY = NULL,
	@WinLoss		MONEY = NULL,
	@MarginFrom		MONEY = NULL,
	@MarginTo		MONEY = NULL,
	@Bettypes		VARCHAR(200) =  '0'
AS    
/*  
 Created:	20160315@Thai.Tran
 Task :		Detail report - League detail from Bet Type
 DB:		DBTGRS.bodb_TGRS
 Original:  
 
 Revisions:      	
 
 Param's Explanation:  	

 Exam: 
	  EXEC  TGRS_Rpt_PerformanceDetail_Bettype_League @FromDate = '2014-01-01', @ToDate= '2014-05-30' 
  
*/  
 
BEGIN 
	 SET NOCOUNT ON  

	 DECLARE @BettypeList AS TABLE (bettype SMALLINT)
	 IF @Bettypes <> '0'
		 INSERT INTO @BettypeList
		 SELECT val FROM dbo.strSplit_Key(@Bettypes,',')
	 ELSE 
		 INSERT INTO @BettypeList
		 SELECT Bettype FROM dbo.Bettype WITH (NOLOCK)

	SELECT P.LeagueId,
			L.leaguename,
			ISNULL(COUNT(DISTINCT P.CustId),0) AS TraderCount, 
			ISNULL(COUNT(DISTINCT P.LeagueId),0) AS LeagueCount, 
			ISNULL(COUNT(DISTINCT P.MatchId),0) AS MatchCount, 
			ISNULL(SUM(P.Stake),0) AS Turnover, 
			ISNULL(SUM(P.WinLost),0) - ISNULL(SUM (P.Comm),0) AS WinLoss, 
			ISNULL(SUM(P.BetCount),0) AS BetCount,
			CASE WHEN ISNULL(SUM(P.Stake),0) <> 0 THEN (ISNULL(SUM(P.WinLost),0) - ISNULL(SUM(P.Comm),0)) * 100/SUM(P.Stake) ELSE NULL END AS Margin	
	INTO #TraderPerformanceTemp
	FROM dbo.TraderPerformance P WITH (NOLOCK)	 
	INNER JOIN bodb02.dbo.League L WITH (NOLOCK) ON P.LeagueId = L.LeagueId
	WHERE	P.EventDate BETWEEN @FromDate AND @ToDate			
			AND P.Bettype IN (SELECT Bettype FROM @BettypeList)
	GROUP BY P.LeagueId , L.LeagueName 
				 	
	 SELECT	P.LeagueId, 
			P.leaguename,
			P.TraderCount, 
			P.LeagueCount,
			P.MatchCount,
			P.Turnover, 
			P.WinLoss, 
			P.BetCount,
			P.Margin		 
	 FROM	#TraderPerformanceTemp P	 	 	 
	 WHERE	(@Turnover IS NULL OR P.Turnover >= @Turnover)
			AND (@WinLoss IS NULL  OR P.WinLoss >= @WinLoss)
			AND ( @MarginFrom IS NULL  OR P.Margin >= @MarginFrom)
			AND ( @MarginTo IS NULL OR P.Margin <= @MarginTo)
			
	ORDER BY P.Margin DESC, P.LeagueName ASC

	DROP TABLE #TraderPerformanceTemp
END 

--GRANT EXECUTE ON [dbo].[TGRS_Rpt_PerformanceDetail_Bettype_League] TO [bodbTGRSNet]
--GRANT VIEW DEFINITION ON [dbo].[TGRS_Rpt_PerformanceDetail_Bettype_League] TO [bodbTGRSNet ]