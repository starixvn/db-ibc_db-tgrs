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
	@Bettype		SMALLINT
AS    
/*  
 Created:	20160315@Thai.Tran
 Task :		Detail report - League detail from Bet Type
 DB:		DBTGRS.bodb_TGRS
 Original:  
 
 Revisions:      	
 
 Param's Explanation:  	

 Exam: 
	  EXEC  TGRS_Rpt_PerformanceDetail_Bettype_League @FromDate = '2014-01-01', @ToDate= '2014-05-30', @Bettype = 1
  
*/  
 
BEGIN 
	 SET NOCOUNT ON  
	
	SELECT P.LeagueId,
			L.LeagueName,
			ISNULL(COUNT(DISTINCT P.CustId),0) AS TraderCount, 
			ISNULL(COUNT(DISTINCT P.LeagueId),0) AS LeagueCount, 
			ISNULL(COUNT(DISTINCT P.MatchId),0) AS MatchCount, 
			ISNULL(SUM(P.Stake),0) AS Turnover, 
			ISNULL(SUM(P.WinLost),0) - ISNULL(SUM (P.Comm),0) AS WinLoss, 
			ISNULL(SUM(P.BetCount),0) AS BetCount,
			CASE WHEN ISNULL(SUM(P.Stake),0) <> 0 THEN (ISNULL(SUM(P.WinLost),0) - ISNULL(SUM(P.Comm),0)) * 100/SUM(P.Stake) ELSE NULL END AS Margin		
	FROM dbo.TraderPerformance P WITH (NOLOCK)	 
	INNER JOIN bodb02.dbo.League L WITH (NOLOCK) ON P.LeagueId = L.LeagueId
	WHERE	P.Bettype = @Bettype
			AND P.EventDate BETWEEN @FromDate AND @ToDate						
	GROUP BY P.LeagueId, L.LeagueName 	
	ORDER BY Margin DESC, LeagueName ASC
				 		
END 

--GRANT EXECUTE ON [dbo].[TGRS_Rpt_PerformanceDetail_Bettype_League] TO [bodbTGRSNet]
--GRANT VIEW DEFINITION ON [dbo].[TGRS_Rpt_PerformanceDetail_Bettype_League] TO [bodbTGRSNet ]

