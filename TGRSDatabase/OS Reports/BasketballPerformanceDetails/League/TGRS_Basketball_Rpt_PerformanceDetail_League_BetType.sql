ALTER PROCEDURE [dbo].[TGRS_Basketball_Rpt_PerformanceDetail_League_BetType]  	
		@FromDate			DATE
	,	@ToDate				DATE
	,	@LeagueId			INT
	,	@MatchId			INT = NULL
	,	@LiveType			SMALLINT = -1
AS    
/*  
	Task :		Basketball Performance Detail - League - BetType
	DB:			DBTGRS.bodb_TGRS
	Original:  
  
	Revisions: 	
   		- 20250414@Jaden: Basketball Performance Detail - League - BetType dimension

	Param's Explanation:  	
		- @LiveType: -1 All; 0 Nonlive; 1 Live
		- @MatchId: NULL for all matches, specific ID to filter by match
		
	Exam: 
		EXEC TGRS_Basketball_Rpt_PerformanceDetail_League_BetType @FromDate = '2024-01-01', @ToDate= '2024-12-30', @LeagueId = 78368, @LiveType = 0
		EXEC TGRS_Basketball_Rpt_PerformanceDetail_League_BetType @FromDate = '2024-01-01', @ToDate= '2024-12-30', @LeagueId = 78368, @MatchId = 12345, @LiveType = 0
*/  
 
BEGIN 
	SET NOCOUNT ON;
	
	SELECT 
		P.BettypeId,
		BT.typenamee AS BettypeName,
		ISNULL(SUM(P.BetCount), 0) AS BetCount,
		ISNULL(SUM(P.Turnover), 0) AS Turnover,
		ISNULL(SUM(P.Winloss), 0) - ISNULL(SUM(P.Comm), 0) AS WinLoss,
		CASE WHEN ISNULL(SUM(P.Turnover), 0) <> 0
			THEN (ISNULL(SUM(P.Winloss), 0) - ISNULL(SUM(P.Comm), 0)) * 100/SUM(P.Turnover)
			ELSE NULL
		END AS Margin,
		ISNULL(SUM(P.Turnover_AR), 0) AS Turnover_AR,
		ISNULL(SUM(P.Winloss_AR), 0) - ISNULL(SUM(P.Comm_AR), 0) AS WinLoss_AR,
		CASE WHEN ISNULL(SUM(P.Turnover_AR), 0) <> 0
			THEN (ISNULL(SUM(P.Winloss_AR), 0) - ISNULL(SUM(P.Comm_AR), 0)) * 100/SUM(P.Turnover_AR)
			ELSE NULL
		END AS Margin_AR
	FROM dbo.OSDataTGRS AS P WITH (NOLOCK)
		INNER JOIN bodb02.dbo.bettype AS BT WITH (NOLOCK) ON P.BettypeId = BT.typeid
	WHERE P.EventDate BETWEEN @FromDate AND @ToDate
		AND P.SportId = 2
		AND P.LeagueId = @LeagueId
		AND (@MatchId IS NULL OR P.MatchId = @MatchId)
		AND (@LiveType = -1 OR P.IsLive = @LiveType)
	GROUP BY P.BettypeId, BT.typenamee
	ORDER BY Margin DESC, BT.typenamee ASC;
			 		
END;

GO
/*<info serverAlias="DBTGRS-bodb_TGRS" executers="wsv_tgrs" isFunction="0" isNested="0"></info>*/