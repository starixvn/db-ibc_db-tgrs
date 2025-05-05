CREATE PROCEDURE [dbo].[TGRS_Basketball_Rpt_PerformanceDetail_Bettype_BetChoice_Quarter_League]  	
		@FromDate			DATE
	,	@ToDate				DATE
	,	@LeagueName			NVARCHAR(500)= ''
	,	@LeagueGroupIds		VARCHAR(2000) =  ''
	,	@Bettype			SMALLINT
	,	@BetChoice			NVARCHAR(50)
	,   @hdp 				SMALLMONEY = NULL
	,	@BetId				BIGINT	
	,	@LiveType			SMALLINT = 1
AS    
/*  
	Created:	20211123@Adam.Tran
	Task :		Basketball - View report to Set X Game Y - [Redmine: #164165]
	DB:			DBTGRS.bodb_TGRS
	Original:  
  
	Revisions: 	
   		- 20211123@Adam.Tran: Basketball - View report to Set X Game Y [Redmine: #164165]
		- 20250411@Jaden.Tang: Added HDP for when drilling down from TGRS_Basketball_Rpt_PerformanceDetail_Bettype_BetChoice_HDP [Redmine: #170019]

	Param's Explanation:  	
		- @LiveType: -1 All; 0 Nonlive; 1 Live

	 Exam: 
		EXEC  TGRS_Basketball_Rpt_PerformanceDetail_Bettype_BetChoice_Quarter_League @FromDate = '2020-01-01', @ToDate= '2020-12-30', @Bettype = 20
*/  
 
BEGIN 
	SET NOCOUNT ON;
	
	DECLARE @LeagueGroups AS TABLE (LeagueGroupId SMALLINT PRIMARY KEY CLUSTERED, LeagueGroupName NVARCHAR(200))
	IF @LeagueGroupIds <> ''
		BEGIN
			INSERT INTO @LeagueGroups(LeagueGroupId)
			SELECT val 
			FROM dbo.strSplit_Key(@LeagueGroupIds,',');
		END
	ELSE 
		BEGIN
			INSERT INTO @LeagueGroups(LeagueGroupId, LeagueGroupName)
			EXECUTE dbo.TGRS_LeagueGroup_GetBySportId @SportId = 2;
		END;

	IF (@LeagueName IS NULL OR @LeagueName = '')
		BEGIN
		   SELECT P.LeagueId,  
				  L.LeagueName,
				  L.LeagueGroupID,
				  P.IsLive,  
				  ISNULL(COUNT(DISTINCT P.TraderId), 0) AS TraderCount,  
				  ISNULL(COUNT(DISTINCT P.MatchId), 0) AS MatchCount,
				  ISNULL(SUM(P.Turnover), 0) AS Turnover,   
				  ISNULL(SUM(P.WinLoss), 0) - ISNULL(SUM (P.Comm), 0) AS WinLoss,   
				  ISNULL(SUM(P.BetCount), 0) AS BetCount,  
				  CASE WHEN ISNULL(SUM(P.Turnover), 0) <> 0 THEN (ISNULL(SUM(P.WinLoss), 0) - ISNULL(SUM(P.Comm), 0)) * 100/SUM(P.Turnover) ELSE NULL END AS Margin    
			FROM dbo.OSDataTGRS_BetChoice AS P WITH (NOLOCK)    
				INNER JOIN bodb02.dbo.League AS L WITH (NOLOCK) ON P.LeagueId = L.LeagueId
				LEFT JOIN @LeagueGroups AS lg ON L.LeagueGroupId = lg.LeagueGroupId
				LEFT JOIN dbo.LeagueExclusion le WITH(NOLOCK) ON P.LeagueId = le.LeagueId
			WHERE P.EventDate BETWEEN @FromDate AND @ToDate
				AND P.SportId = 2
				AND P.BettypeId = @Bettype and P.BetChoice = @BetChoice
				AND P.betid = @BetId
				AND (@LiveType = -1 OR P.IsLive = @LiveType)
				AND (@LeagueGroupIds = '' OR lg.LeagueGroupId IS NOT NULL)
				AND (@hdp IS NULL OR P.hdp = @hdp)
			GROUP BY P.LeagueId, L.LeagueName, L.LeagueGroupID, P.IsLive    
			ORDER BY Margin DESC, LeagueName ASC;
		END;
	ELSE
		BEGIN
			SELECT P.LeagueId,  
				  L.LeagueName,
				  L.LeagueGroupID,
				  P.IsLive,  
				 ISNULL(COUNT(DISTINCT P.TraderId), 0) AS TraderCount,  
				  ISNULL(COUNT(DISTINCT P.MatchId), 0) AS MatchCount,
				  ISNULL(SUM(P.Turnover), 0) AS Turnover,   
				  ISNULL(SUM(P.WinLoss), 0) - ISNULL(SUM (P.Comm), 0) AS WinLoss,   
				  ISNULL(SUM(P.BetCount), 0) AS BetCount,  
				  CASE WHEN ISNULL(SUM(P.Turnover), 0) <> 0 THEN (ISNULL(SUM(P.WinLoss), 0) - ISNULL(SUM(P.Comm), 0)) * 100/SUM(P.Turnover) ELSE NULL END AS Margin    
			FROM dbo.OSDataTGRS_BetChoice AS P WITH (NOLOCK)
				INNER JOIN bodb02.dbo.League AS L WITH (NOLOCK) ON P.LeagueId = L.LeagueId
				LEFT JOIN @LeagueGroups AS lg ON L.LeagueGroupId = lg.LeagueGroupId
			WHERE P.EventDate BETWEEN @FromDate AND @ToDate
				AND P.SportId = 2
				AND P.BettypeId = @Bettype and P.BetChoice = @BetChoice
				AND P.betid = @BetId
				AND L.LeagueName LIKE '%' + @LeagueName + '%'
				AND (@LiveType = -1 OR P.IsLive = @LiveType)
				AND (@LeagueGroupIds = '' OR lg.LeagueGroupId IS NOT NULL)
				AND (@hdp IS NULL OR P.hdp = @hdp)
			GROUP BY P.LeagueId, L.LeagueName, L.LeagueGroupID, P.IsLive    
			ORDER BY Margin DESC, LeagueName ASC;
		END;
END;

GO
/*<info serverAlias="DBTGRS-bodb_TGRS" executers="wsv_tgrs" isFunction="0" isNested="0"></info>*/