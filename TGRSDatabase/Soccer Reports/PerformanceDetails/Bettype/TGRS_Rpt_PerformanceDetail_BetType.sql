ALTER PROCEDURE [dbo].[TGRS_Rpt_PerformanceDetail_BetType]
	@FromDate			DATE,
	@ToDate				DATE,
	@Turnover			MONEY = NULL,
	@WinLoss			MONEY = NULL,
	@MarginFrom			MONEY = NULL,
	@MarginTo			MONEY = NULL,
	@Bettypes			VARCHAR(2000) =  '0',
	@IsExcludeLeagues	BIT = 1,
	@Market				SMALLINT = 1
AS    
/*  
	Created:	20160216@Thai
	Task :		Detail report - BetType Performance
	DB:		DBTGRS.bodb_TGRS
	Original:  
  
	Revisions: 	
   		- 20171019@Simon:		Change VARCHAR(200) to VARCHAR(2000)
		- 20171205@Simon:		get only Live data & Bettypes are not disabled
		- 20180912@Simon:		add league exclusion
		- 20190919@Long.Luu:	Support Nonlive Data [Redmine ID: 118959]

	Param's Explanation:  	
		- @Market: -1 All; 0 Nonlive; 1 Live

	Exam: 
			EXEC  [TGRS_Rpt_PerformanceDetail_BetType] @FromDate = '2014-01-01', @ToDate= '2015-12-30' 
  
*/  
 
BEGIN 
	 SET NOCOUNT ON;

	 DECLARE @BettypeList AS TABLE (bettype SMALLINT)
	 IF @Bettypes <> '0'
		 INSERT INTO @BettypeList
		 SELECT val 
		 FROM dbo.strSplit_Key(@Bettypes,',');
	 ELSE 
		 INSERT INTO @BettypeList
		 SELECT Bettype 
		 FROM dbo.Bettype WITH (NOLOCK);

	SELECT P.BetType, 	
		P.IsLive,					
		ISNULL(COUNT(DISTINCT P.CustId), 0) AS TraderCount, 
		ISNULL(COUNT(DISTINCT P.LeagueId), 0) AS LeagueCount, 
		ISNULL(COUNT(DISTINCT P.MatchId), 0) AS MatchCount, 
		ISNULL(SUM(P.Stake), 0) AS Turnover, 
		ISNULL(SUM(P.WinLost), 0) - ISNULL(SUM (P.Comm), 0) AS WinLoss, 
		ISNULL(SUM(P.BetCount), 0) AS BetCount,
		CASE WHEN ISNULL(SUM(P.Stake), 0) <> 0 THEN (ISNULL(SUM(P.WinLost), 0) - ISNULL(SUM(P.Comm), 0)) * 100/SUM(P.Stake) ELSE NULL END AS Margin	
	INTO #TraderPerformanceTemp
	FROM dbo.TraderPerformance AS P WITH (NOLOCK)	 
	WHERE	P.EventDate BETWEEN @FromDate AND @ToDate			
		AND P.Bettype IN (SELECT Bettype FROM @BettypeList)
		AND (@Market = -1 OR P.IsLive = @Market)
		AND (@IsExcludeLeagues = 0 OR (P.LeagueId NOT IN (SELECT le.LeagueId FROM dbo.LeagueExclusion AS le WITH(NOLOCK))))
	GROUP BY P.BetType, P.IsLive;
				 	
	 SELECT	P.BetType, 
		TN.TypeName,
		P.TraderCount, 
		P.LeagueCount,
		P.MatchCount,
		P.Turnover, 
		P.WinLoss, 
		P.BetCount,
		P.Margin,
		P.IsLive 
	 FROM	#TraderPerformanceTemp AS P WITH (NOLOCK)
		LEFT JOIN dbo.BetType AS TN WITH (NOLOCK) ON TN.BetType = P.BetType	 	 
	 WHERE	(@Turnover IS NULL OR P.Turnover >= @Turnover)
		AND (@WinLoss IS NULL  OR P.WinLoss >= @WinLoss)
		AND ( @MarginFrom IS NULL  OR P.Margin >= @MarginFrom)
		AND ( @MarginTo IS NULL OR P.Margin <= @MarginTo)
		AND TN.[Disabled] = 0
	ORDER BY P.Margin DESC, P.Bettype ASC;

	DROP TABLE #TraderPerformanceTemp;
END;

GO
/*<info serverAlias="DBTGRS-bodb_TGRS" executers="bodbTGRSNet" isFunction="0" isNested="0"></info>*/