CREATE PROCEDURE [dbo].[TGRS_Basketball_Rpt_PerformanceDetail_Bettype_BetChoice_HDP]  	
		@FromDate			DATE
	,	@ToDate				DATE
	,	@LeagueName			NVARCHAR(500)= ''
	,	@LeagueGroupIds		VARCHAR(2000) =  ''
	,	@Bettype			SMALLINT
	,	@BetChoice			NVARCHAR(50)
	,	@LiveType			SMALLINT = 1
AS    
/*  
	Created:	20250411@Jaden.Tang
	Task :		Basketball - View by HDP [Redmine: #170019]
	DB:			DBTGRS.bodb_TGRS
	Original:  
  
	Revisions: 	
   		- 20250411@Jaden.Tang: Basketball - View by HDP [Redmine: #170019]

	Param's Explanation:  	
		- @LiveType: -1 All; 0 Nonlive; 1 Live

	Remarks:
		Currently only called when @Bettype IN (401, 402, 403, 404) - (Web will show the hyperlink)
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
		   SELECT P.hdp												AS HDP,				  
				  P.IsLive											AS IsLive,
				  ISNULL(COUNT(DISTINCT P.LeagueId), 0)				AS LeagueCount,
				  ISNULL(COUNT(DISTINCT P.MatchId), 0) 				AS MatchCount,
				  ISNULL(SUM(P.Turnover), 0) 						AS Turnover,   
				  ISNULL(SUM(P.WinLoss), 0) - ISNULL(SUM (P.Comm), 0) AS WinLoss,   
				  ISNULL(SUM(P.BetCount), 0) 						AS BetCount,  
				  CASE WHEN ISNULL(SUM(P.Turnover), 0) <> 0 THEN (ISNULL(SUM(P.WinLoss), 0) - ISNULL(SUM(P.Comm), 0)) * 100/SUM(P.Turnover) ELSE NULL END AS Margin    
			FROM dbo.OSDataTGRS_BetChoice AS P WITH (NOLOCK) 
				INNER JOIN bodb02.dbo.League AS L WITH (NOLOCK) ON P.LeagueId = L.LeagueId
				LEFT JOIN @LeagueGroups AS lg ON L.LeagueGroupId = lg.LeagueGroupId
				LEFT JOIN dbo.LeagueExclusion le WITH(NOLOCK) ON P.LeagueId = le.LeagueId
			WHERE P.EventDate BETWEEN @FromDate AND @ToDate
				AND P.SportId = 2
				AND P.BettypeId = @Bettype and P.BetChoice = @BetChoice
				AND (@LiveType = -1 OR P.IsLive = @LiveType)
				AND (@LeagueGroupIds = '' OR lg.LeagueGroupId IS NOT NULL)
			GROUP BY P.hdp, P.IsLive
			ORDER BY Margin DESC;
		END;
	ELSE
		BEGIN
			SELECT 	P.hdp											AS HDP,					
					P.IsLive										AS IsLive,  
					ISNULL(COUNT(DISTINCT P.LeagueId), 0)		    AS LeagueCount,
					ISNULL(COUNT(DISTINCT P.MatchId), 0) 			AS MatchCount,
					ISNULL(SUM(P.Turnover), 0) 						AS Turnover,   
					ISNULL(SUM(P.WinLoss), 0) - ISNULL(SUM (P.Comm), 0) AS WinLoss,   
					ISNULL(SUM(P.BetCount), 0) 						AS BetCount,  
					CASE WHEN ISNULL(SUM(P.Turnover), 0) <> 0 THEN (ISNULL(SUM(P.WinLoss), 0) - ISNULL(SUM(P.Comm), 0)) * 100/SUM(P.Turnover) ELSE NULL END AS Margin    
			FROM dbo.OSDataTGRS_BetChoice AS P WITH (NOLOCK)				
				INNER JOIN bodb02.dbo.League AS L WITH (NOLOCK) ON P.LeagueId = L.LeagueId
				LEFT JOIN @LeagueGroups AS lg ON L.LeagueGroupId = lg.LeagueGroupId
			WHERE P.EventDate BETWEEN @FromDate AND @ToDate
				AND P.SportId = 2
				AND P.BettypeId = @Bettype and P.BetChoice = @BetChoice
				AND L.LeagueName LIKE '%' + @LeagueName + '%'
				AND (@LiveType = -1 OR P.IsLive = @LiveType)
				AND (@LeagueGroupIds = '' OR lg.LeagueGroupId IS NOT NULL)
			GROUP BY P.hdp, P.IsLive
			ORDER BY Margin DESC;
		END;
END;

GO
/*<info serverAlias="DBTGRS-bodb_TGRS" executers="wsv_tgrs" isFunction="0" isNested="0"></info>*/