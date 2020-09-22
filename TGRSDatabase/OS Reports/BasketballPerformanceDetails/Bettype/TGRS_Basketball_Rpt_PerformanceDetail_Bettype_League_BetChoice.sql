CREATE PROCEDURE [dbo].[TGRS_Basketball_Rpt_PerformanceDetail_Bettype_League_BetChoice]  	
		@FromDate			DATE
	,	@ToDate				DATE
	,	@LeagueId			INT
	,	@Bettype			SMALLINT
	,	@LiveType			SMALLINT = 1
AS    
/*  
	Created:	20200918@John.Ngo
	Task :		Basketball Performance Detail - Bettype - League - BetChoice
	DB:			DBTGRS.bodb_TGRS
	Original:  
  
	Revisions: 	
   		- 20200918@John.Ngo:	Basketball Performance Detail - Bettype - League - BetChoice [Redmine ID: 140875]

	Param's Explanation:  	
		- @LiveType: -1 All; 0 Nonlive; 1 Live

*/ 
 
BEGIN 
	SET NOCOUNT ON;
	
	SELECT  P.BetChoice											AS BetChoice 
		,	P.IsLive											AS IsLive
		,	ISNULL(COUNT(DISTINCT P.MatchId), 0)				AS MatchCount
		,	ISNULL(SUM(P.Turnover), 0)							AS Turnover
		,	ISNULL(SUM(P.WinLoss), 0) - ISNULL(SUM (P.Comm), 0)	AS WinLoss
		,	ISNULL(SUM(P.BetCount), 0)							AS BetCount
		,	CASE WHEN ISNULL(SUM(P.Turnover), 0) <> 0 THEN (ISNULL(SUM(P.WinLoss), 0) - ISNULL(SUM(P.Comm), 0)) * 100/SUM(P.Turnover) ELSE NULL END AS Margin
	FROM dbo.OSDataTGRS_BetChoice AS P WITH (NOLOCK)
	WHERE P.EventDate BETWEEN @FromDate AND @ToDate
		AND P.SportId = 2
		AND	P.BettypeId = @Bettype AND P.LeagueId = @LeagueId
		AND (@LiveType = -1 OR P.IsLive = @LiveType)
	GROUP BY P.BetChoice
		,	 P.IsLive;
			 		
END;

GO
/*<info serverAlias="DBTGRS-bodb_TGRS" executers="bodbTGRSNet" isFunction="0" isNested="0"></info>*/