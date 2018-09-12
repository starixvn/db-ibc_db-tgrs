/****** Object:  Stored Procedure dbo.TGRS_Rpt_PerformanceDetail_Bettype_League    Script Date: 3/22/2016 12:48:53 PM ******/
ALTER PROCEDURE [dbo].[TGRS_Rpt_PerformanceDetail_Bettype_BetChoice]  	
	@FromDate		DATE,
	@ToDate			DATE,		
	@Bettype		SMALLINT,
	@IsExcludeLeagues	BIT = 1
AS    
/*  
 Created:	20171212@Aaron
 Task :		Detail report - Bet choice detail from Bet Type
 DB:		DBTGRS.bodb_TGRS
 Original:  
 
 Revisions:
	- 20180912@Simon: add league exclusion

 Param's Explanation:  	

 Exam: 
	EXEC  TGRS_Rpt_PerformanceDetail_Bettype_BetChoice @FromDate = '2017-11-01', @ToDate= '2018-05-30', @Bettype = 15
  
*/  
 
BEGIN 
	SET NOCOUNT ON  
	
	--DECLARE @mainDBBettype SMALLINT

	--SELECT @mainDBBettype = ISNULL(bt.MainDBBetType, @Bettype)
	--FROM dbo.BetType bt WITH(NOLOCK)
	--WHERE bt.BetType = @Bettype
	
	SELECT 
		bcm.TGRSBetChoice AS BetChoice,
		ISNULL(COUNT(DISTINCT P.LeagueId),0) AS LeagueCount, 
		ISNULL(COUNT(DISTINCT P.MatchId),0) AS MatchCount, 
		ISNULL(SUM(P.Stake),0) AS Turnover, 
		ISNULL(SUM(P.WinLost),0) - ISNULL(SUM (P.Comm),0) AS WinLoss, 
		ISNULL(SUM(P.BetCount),0) AS BetCount
	FROM dbo.TraderPerformance_BetChoice P WITH (NOLOCK)	 
	INNER JOIN dbo.BetChoiceMapping bcm WITH (NOLOCK) ON bcm.BetType = @Bettype
	WHERE	P.Bettype = @Bettype
		AND P.EventDate BETWEEN @FromDate AND @ToDate
		AND P.IsLive = 1
		AND P.BetChoice = bcm.BetChoice
		AND (@IsExcludeLeagues = 0 OR (P.LeagueId NOT IN (SELECT le.LeagueId FROM dbo.LeagueExclusion le WHERE le.LeagueId = P.LeagueId)))
	GROUP BY bcm.TGRSBetChoice
END;

/*
GO
GRANT EXECUTE ON [dbo].[TGRS_Rpt_PerformanceDetail_Bettype_BetChoice] TO [bodbTGRSNet]
GO
GRANT VIEW DEFINITION ON [dbo].[TGRS_Rpt_PerformanceDetail_Bettype_BetChoice] TO [bodbTGRSNet ]
GO
*/