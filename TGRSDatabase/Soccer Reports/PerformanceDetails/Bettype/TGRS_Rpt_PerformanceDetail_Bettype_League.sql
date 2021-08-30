ALTER PROCEDURE [dbo].[TGRS_Rpt_PerformanceDetail_Bettype_League]  	
		@FromDate			DATE
	,	@ToDate				DATE
	,	@LeagueName			NVARCHAR(500)= ''
	,	@LeagueGroupIds		VARCHAR(2000) =  ''
	,	@Bettype			SMALLINT
	,	@IsExcludeLeagues	BIT = 1
	,	@Market				SMALLINT = 1
AS    
/*  
	 Created:	20160315@Thai.Tran
	 Task :		Detail report - League detail from Bet Type
	 DB:		DB06.bodb_TGRS_UAT & DB061.bodb_TGRS
	 Original:  
 
	 Revisions:      	
		- 20171205@Simon:		get only Live data & Bettypes are not disabled
		- 20180912@Simon:		add league exclusion
		- 20190919@Long.Luu:	Support Nonlive Data [Redmine ID: 118959]
		- 20191023@John.Ngo:	Enhance performance [Redmine ID: 121268]
		- 20200709@John.Ngo:	Performance Detail - Support filter by league group [Redmine ID: 137276]
		- 20200731@John.Ngo:	View down bet choice from League performance [Redmine ID: 137278]
		- 20200909@John.Ngo:	Performance Detail - Bettype - Support filter by LeagueName [Redmine ID: 141294]
		- 20210809@Adam.Tran: 	Sports - Performance Real Figures [Redmine: #158981]
	 Param's Explanation:  	
		- @Market: -1 All; 0 Nonlive; 1 Live  

	 Exam: EXEC  TGRS_Rpt_PerformanceDetail_Bettype_League @FromDate = '2014-01-01', @ToDate= '2014-05-30', @Bettype = 1
  
*/  
 
BEGIN 
	SET NOCOUNT ON;
	
	DECLARE @LeagueGroups AS TABLE (LeagueGroupId SMALLINT PRIMARY KEY CLUSTERED)
	IF @LeagueGroupIds <> ''
	BEGIN
		INSERT INTO @LeagueGroups(LeagueGroupId)
		SELECT val 
		FROM dbo.strSplit_Key(@LeagueGroupIds,',');

		IF CHARINDEX('12', @LeagueGroupIds) > 0
		BEGIN
			DELETE FROM @LeagueGroups
			WHERE LeagueGroupId = 12;

			INSERT INTO @LeagueGroups(LeagueGroupId)
			SELECT DISTINCT l.LeagueGroupID
			FROM bodb02.dbo.league AS l WITH(NOLOCK)
			WHERE l.LeagueGroupID NOT IN (1,2,3,4,5,6,7,8,9,10,11);
		END;
	END;
	
	IF (@LeagueName IS NULL OR @LeagueName = '')
		BEGIN
			SELECT P.LeagueId,
				L.LeagueName,
				L.LeagueGroupID,
				P.IsLive,
				ISNULL(COUNT(DISTINCT P.CustId), 0) 	AS TraderCount, 
				ISNULL(COUNT(DISTINCT P.MatchId), 0) 	AS MatchCount,
				ISNULL(COUNT(DISTINCT P.BetChoice), 0) 	AS BetChoiceCount,
				ISNULL(SUM(P.BetCount), 0) 				AS BetCount,
				ISNULL(SUM(P.Stake), 0) 				AS Turnover, 
				ISNULL(SUM(P.WinLost), 0) - ISNULL(SUM (P.Comm), 0) AS WinLoss, 				
				CASE WHEN ISNULL(SUM(P.Stake), 0) <> 0 THEN (ISNULL(SUM(P.WinLost), 0) - ISNULL(SUM(P.Comm), 0)) * 100/SUM(P.Stake) ELSE NULL END AS Margin,
				ISNULL(SUM(P.Stake_Real),0) 			AS TurnoverReal,				
				ISNULL(SUM(CASE WHEN P.Is8RM = 0 THEN P.WinLost_Real ELSE 0 END),0) AS WinLossReal,
				CASE WHEN ISNULL(SUM(P.Stake_Real),0) <> 0 THEN ISNULL(SUM(CASE WHEN P.Is8RM = 0 THEN P.WinLost_Real ELSE 0 END),0) * 100/ISNULL(SUM(P.Stake_Real),0) ELSE NULL END AS MarginReal
			FROM dbo.TraderPerformance_BetChoice AS P WITH (NOLOCK)	 
				INNER JOIN bodb02.dbo.League AS L WITH (NOLOCK) ON P.LeagueId = L.LeagueId
				LEFT JOIN @LeagueGroups AS lg ON L.LeagueGroupId = lg.LeagueGroupId
				LEFT JOIN dbo.LeagueExclusion le WITH(NOLOCK) ON P.LeagueId = le.LeagueId
			WHERE	 P.EventDate BETWEEN @FromDate AND @ToDate
				AND  P.Bettype = @Bettype
				AND (@Market = -1 OR P.IsLive = @Market)
				AND (@IsExcludeLeagues = 0 OR le.LeagueId IS NULL)
				AND (@LeagueGroupIds = '' OR lg.LeagueGroupId IS NOT NULL)
			GROUP BY P.LeagueId, L.LeagueName, L.LeagueGroupID, P.IsLive 	
			ORDER BY Margin DESC, LeagueName ASC;
		END;
	ELSE
		BEGIN			
			SELECT P.LeagueId,
				L.LeagueName,
				L.LeagueGroupID,
				P.IsLive,
				ISNULL(COUNT(DISTINCT P.CustId), 0) 	AS TraderCount, 
				ISNULL(COUNT(DISTINCT P.MatchId), 0) 	AS MatchCount,
				ISNULL(COUNT(DISTINCT P.BetChoice), 0) 	AS BetChoiceCount,
				ISNULL(SUM(P.BetCount), 0) 				AS BetCount,
				ISNULL(SUM(P.Stake), 0) 				AS Turnover, 
				ISNULL(SUM(P.WinLost), 0) - ISNULL(SUM (P.Comm), 0) AS WinLoss,				
				CASE WHEN ISNULL(SUM(P.Stake), 0) <> 0 THEN (ISNULL(SUM(P.WinLost), 0) - ISNULL(SUM(P.Comm), 0)) * 100/SUM(P.Stake) ELSE NULL END AS Margin,
				ISNULL(SUM(P.Stake_Real),0) 			AS TurnoverReal,
				ISNULL(SUM(CASE WHEN P.Is8RM = 0 THEN P.WinLost_Real ELSE 0 END),0) AS WinLossReal,
				CASE WHEN ISNULL(SUM(P.Stake_Real),0) <> 0 THEN ISNULL(SUM(CASE WHEN P.Is8RM = 0 THEN P.WinLost_Real ELSE 0 END),0) * 100/ISNULL(SUM(P.Stake_Real),0) ELSE NULL END AS MarginReal				
			FROM dbo.TraderPerformance_BetChoice AS P WITH (NOLOCK)	 
				INNER JOIN bodb02.dbo.League AS L WITH (NOLOCK) ON P.LeagueId = L.LeagueId
				LEFT JOIN @LeagueGroups AS lg ON L.LeagueGroupId = lg.LeagueGroupId
				LEFT JOIN dbo.LeagueExclusion le WITH(NOLOCK) ON P.LeagueId = le.LeagueId
			WHERE	 P.EventDate BETWEEN @FromDate AND @ToDate
				AND  P.Bettype = @Bettype
				AND L.LeagueName LIKE '%' + @LeagueName + '%'
				AND (@Market = -1 OR P.IsLive = @Market)
				AND (@IsExcludeLeagues = 0 OR le.LeagueId IS NULL)
				AND (@LeagueGroupIds = '' OR lg.LeagueGroupId IS NOT NULL)
			GROUP BY P.LeagueId, L.LeagueName, L.LeagueGroupID, P.IsLive 	
			ORDER BY Margin DESC, LeagueName ASC;
		END;
		
END;

GO

