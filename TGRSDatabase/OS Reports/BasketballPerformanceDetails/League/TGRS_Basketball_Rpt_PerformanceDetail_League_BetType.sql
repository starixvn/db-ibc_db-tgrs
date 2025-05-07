ALTER PROCEDURE [dbo].[TGRS_Basketball_Rpt_PerformanceDetail_League_BetType]  	
		@FromDate			DATE
	,	@ToDate				DATE
	,	@LeagueId			INT
	,	@MatchId			INT = NULL
	,	@LiveType			SMALLINT = -1
	,   @Bettypes   VARCHAR(2000) = '0'
AS    
/*  
	Task :		Basketball Performance Detail - League - BetType
	DB:			DBTGRS.bodb_TGRS
	Original:  
  
	Revisions: 	
   		- 20250414@Jaden: Basketball Performance Detail - League - BetType dimension
		- 20250507@Della: Add new param @Bettypes

	Param's Explanation:  	
		- @LiveType: -1 All; 0 Nonlive; 1 Live
		- @MatchId: NULL for all matches, specific ID to filter by match
		
	Exam: 
		EXEC TGRS_Basketball_Rpt_PerformanceDetail_League_BetType @FromDate = '2024-01-01', @ToDate= '2024-12-30', @LeagueId = 78368, @LiveType = 0
		EXEC TGRS_Basketball_Rpt_PerformanceDetail_League_BetType @FromDate = '2024-01-01', @ToDate= '2024-12-30', @LeagueId = 78368, @MatchId = 12345, @LiveType = 0
*/  
 
BEGIN 
	SET NOCOUNT ON;

	DECLARE @BettypeList AS TABLE (BettypeId SMALLINT)  
	IF @Bettypes <> '0'  
	 BEGIN  
	  INSERT INTO @BettypeList(BettypeId)  
      SELECT value
      FROM STRING_SPLIT(@Bettypes, ',');  
     END;  
    ELSE  
     BEGIN  
      INSERT INTO @BettypeList  
      SELECT b.typeid 
      FROM bodb02.dbo.bettype b WITH(NOLOCK)  
      WHERE b.typeid IN (SELECT bettype FROM bodb02.dbo.SportBettypeMatrix WITH (NOLOCK) WHERE SportType = 2);  
    END; 
	
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
	LEFT JOIN @BettypeList bl ON p.BettypeId = bl.BettypeId
	WHERE P.EventDate BETWEEN @FromDate AND @ToDate
		AND P.SportId = 2
		AND P.LeagueId = @LeagueId
		AND (@Bettypes = '0' OR bl.BettypeId IS NOT NULL) 
		AND (@MatchId IS NULL OR P.MatchId = @MatchId)
		AND (@LiveType = -1 OR P.IsLive = @LiveType)
	GROUP BY P.BettypeId, BT.typenamee
	ORDER BY Margin DESC, BT.typenamee ASC;
			 		
END;

GO
/*<info serverAlias="DBTGRS-bodb_TGRS" executers="wsv_tgrs" isFunction="0" isNested="0"></info>*/