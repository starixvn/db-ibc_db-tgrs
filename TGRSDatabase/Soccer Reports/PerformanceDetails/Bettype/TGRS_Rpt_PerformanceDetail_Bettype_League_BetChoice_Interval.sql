ALTER PROCEDURE [dbo].[TGRS_Rpt_PerformanceDetail_Bettype_League_BetChoice_Interval]  	
		@FromDate			DATE
	,	@ToDate				DATE	
	,	@LeagueId			INT
	,	@BetType			SMALLINT
	,	@BetTeam			NVARCHAR(50)
	,	@Oddsspread			MONEY = NULL
	,	@IsExcludeLeagues	BIT = 1
	,	@Market				SMALLINT = 1
AS    
/*  
	 Created:	20210915@Adam.Tran
	 Task :		Add Fast Market Bettype
	 DB:		DB06.bodb_TGRS_UAT & DB061.bodb_TGRS
	 Original:  
 
	 Revisions:
		- 20210915@Adam.Tran:	Add Fast Market Bettype - [Redmine: #157999]
		
	 Param's Explanation:
*/ 
 
BEGIN 
	SET NOCOUNT ON;
	
	SELECT 	IG.Interval											AS Interval
		,	ISNULL(COUNT(DISTINCT P.LeagueId), 0)				AS LeagueCount		
		,	ISNULL(COUNT(DISTINCT P.MatchId), 0)				AS MatchCount
		,	ISNULL(SUM(P.BetCount), 0)							AS BetCount
		,	ISNULL(SUM(P.Stake), 0)								AS Turnover
		,	ISNULL(SUM(P.WinLost), 0) - ISNULL(SUM (P.Comm), 0)	AS WinLoss
		,	CASE WHEN ISNULL(SUM(P.Stake), 0) <> 0 THEN (ISNULL(SUM(P.WinLost), 0) - ISNULL(SUM(P.Comm), 0)) * 100/SUM(P.Stake) ELSE NULL END AS Margin
		,	ISNULL(SUM(P.Stake_Real),0) 						AS TurnoverReal		
		,	ISNULL(SUM(CASE WHEN P.Is8RM = 0 THEN P.WinLost_Real ELSE 0 END),0) AS WinLossReal
		,	CASE WHEN ISNULL(SUM(P.Stake_Real),0) <> 0 THEN ISNULL(SUM(CASE WHEN P.Is8RM = 0 THEN P.WinLost_Real ELSE 0 END),0) * 100/ISNULL(SUM(P.Stake_Real),0) ELSE NULL END AS MarginReal
	FROM dbo.TraderPerformance_FastMarketBetChoice AS P WITH (NOLOCK)	
		INNER JOIN dbo.BetChoice_FastMarketMapping AS FM WITH (NOLOCK) ON FM.BetType = P.BetType AND FM.betteam = P.betteam
		INNER JOIN dbo.FastMarket_IntervalGroup AS IG WITH (NOLOCK) ON IG.IntervalGroupId = FM.IntervalGroupId AND IG.hdp1 = P.hdp1
		LEFT JOIN dbo.LeagueExclusion le WITH(NOLOCK) ON P.LeagueId = le.LeagueId
	WHERE P.EventDate BETWEEN @FromDate AND @ToDate
		AND	P.BetType = @Bettype 
		AND P.LeagueId = @LeagueId
		AND P.betteam = @BetTeam
		AND	(@Oddsspread = -1 OR P.Oddsspread = @Oddsspread)
		AND (@Market = -1 OR P.IsLive = @Market)	
		AND (@IsExcludeLeagues = 0 OR le.LeagueId IS NULL)
	GROUP BY IG.Interval
	ORDER BY IG.Interval;
END;

GO
