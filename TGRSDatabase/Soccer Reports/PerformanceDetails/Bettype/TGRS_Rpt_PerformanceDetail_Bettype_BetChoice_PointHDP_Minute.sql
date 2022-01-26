ALTER PROCEDURE [dbo].[TGRS_Rpt_PerformanceDetail_Bettype_BetChoice_PointHDP_Minute]  	
		@FromDate			DATE
	,	@ToDate				DATE
	,	@LeagueName			NVARCHAR(500)= ''
	,	@LeagueGroupIds		VARCHAR(2000) =  ''
	,	@BetType			SMALLINT
	,	@BetTeam			NVARCHAR(50)
	,	@PointHDP			MONEY = NULL
	,	@IsExcludeLeagues	BIT = 1
	,	@Market				SMALLINT = 1
AS    
/*  
	 Created:	20220117@John.Ngo
	 Task :		Support drilldown BetChoiceDetail
	 DB:		DB06.bodb_TGRS_UAT & DB061.bodb_TGRS
	 Original:  
 
	 Revisions:
		- 20220117@John.Ngo: 	Support view down for Total Goal, Time Machine and Corner bettype [Redmine: #166679]
		
	 Param's Explanation:
		- @BetType IN (228,229): SABA HDP Time Machine
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
			SELECT 	P.hdp1												AS HDP1
				,	ISNULL(COUNT(DISTINCT P.LeagueId), 0)				AS LeagueCount
				,	ISNULL(COUNT(DISTINCT P.MatchId), 0)				AS MatchCount
				,	ISNULL(SUM(P.BetCount), 0)							AS BetCount
				,	ISNULL(SUM(P.Stake), 0)								AS Turnover
				,	ISNULL(SUM(P.WinLost), 0) - ISNULL(SUM (P.Comm), 0)	AS WinLoss
				,	CASE WHEN ISNULL(SUM(P.Stake), 0) <> 0 THEN (ISNULL(SUM(P.WinLost), 0) - ISNULL(SUM(P.Comm), 0)) * 100/SUM(P.Stake) ELSE NULL END AS Margin
				,	ISNULL(SUM(P.Stake_Real),0) 						AS TurnoverReal		
				,	ISNULL(SUM(CASE WHEN P.Is8RM = 0 THEN P.WinLost_Real ELSE 0 END),0) AS WinLossReal
				,	CASE WHEN ISNULL(SUM(P.Stake_Real),0) <> 0 THEN ISNULL(SUM(CASE WHEN P.Is8RM = 0 THEN P.WinLost_Real ELSE 0 END),0) * 100/ISNULL(SUM(P.Stake_Real),0) ELSE NULL END AS MarginReal
			FROM dbo.TraderPerformance_BetChoice_Detail AS P WITH (NOLOCK)
				INNER JOIN bodb02.dbo.League AS L WITH (NOLOCK) ON P.LeagueId = L.LeagueId
				LEFT JOIN dbo.BetChoiceMapping AS bcm WITH (NOLOCK) ON bcm.BetType = P.BetType AND bcm.BetChoice = P.betteam
				LEFT JOIN dbo.LeagueExclusion le WITH(NOLOCK) ON P.LeagueId = le.LeagueId
				LEFT JOIN @LeagueGroups AS lg ON L.LeagueGroupId = lg.LeagueGroupId
			WHERE P.EventDate BETWEEN @FromDate AND @ToDate
				AND	P.BetType = @BetType
				AND ISNULL(bcm.TGRSBetChoice,P.betteam) = @BetTeam
				AND P.oddsspread = @PointHDP
				AND (@Market = -1 OR P.IsLive = @Market)	
				AND (@IsExcludeLeagues = 0 OR le.LeagueId IS NULL)
				AND (@LeagueGroupIds = '' OR lg.LeagueGroupId IS NOT NULL)
			GROUP BY P.hdp1
			ORDER BY P.hdp1 ASC;
		END;
	ELSE
		BEGIN
			SELECT 	P.hdp1												AS HDP1
				,	ISNULL(COUNT(DISTINCT P.LeagueId), 0)				AS LeagueCount
				,	ISNULL(COUNT(DISTINCT P.MatchId), 0)				AS MatchCount
				,	ISNULL(SUM(P.BetCount), 0)							AS BetCount
				,	ISNULL(SUM(P.Stake), 0)								AS Turnover
				,	ISNULL(SUM(P.WinLost), 0) - ISNULL(SUM (P.Comm), 0)	AS WinLoss
				,	CASE WHEN ISNULL(SUM(P.Stake), 0) <> 0 THEN (ISNULL(SUM(P.WinLost), 0) - ISNULL(SUM(P.Comm), 0)) * 100/SUM(P.Stake) ELSE NULL END AS Margin
				,	ISNULL(SUM(P.Stake_Real),0) 						AS TurnoverReal		
				,	ISNULL(SUM(CASE WHEN P.Is8RM = 0 THEN P.WinLost_Real ELSE 0 END),0) AS WinLossReal
				,	CASE WHEN ISNULL(SUM(P.Stake_Real),0) <> 0 THEN ISNULL(SUM(CASE WHEN P.Is8RM = 0 THEN P.WinLost_Real ELSE 0 END),0) * 100/ISNULL(SUM(P.Stake_Real),0) ELSE NULL END AS MarginReal
			FROM dbo.TraderPerformance_BetChoice_Detail AS P WITH (NOLOCK)
				INNER JOIN bodb02.dbo.League AS L WITH (NOLOCK) ON P.LeagueId = L.LeagueId
				LEFT JOIN dbo.BetChoiceMapping AS bcm WITH (NOLOCK) ON bcm.BetType = P.BetType AND bcm.BetChoice = P.betteam
				LEFT JOIN dbo.LeagueExclusion le WITH(NOLOCK) ON P.LeagueId = le.LeagueId	
				LEFT JOIN @LeagueGroups AS lg ON L.LeagueGroupId = lg.LeagueGroupId				
			WHERE P.EventDate BETWEEN @FromDate AND @ToDate
				AND	P.BetType = @BetType
				AND ISNULL(bcm.TGRSBetChoice,P.betteam) = @BetTeam
				AND L.LeagueName LIKE '%' + @LeagueName + '%'
				AND P.oddsspread = @PointHDP
				AND (@Market = -1 OR P.IsLive = @Market)	
				AND (@IsExcludeLeagues = 0 OR le.LeagueId IS NULL)
				AND (@LeagueGroupIds = '' OR lg.LeagueGroupId IS NOT NULL)
			GROUP BY P.hdp1
			ORDER BY P.hdp1 ASC;
		END;	
	
END;

GO

/*<info serverAlias="DBTGRS-bodb_TGRS" executers="bodbTGRSNet" isFunction="0" isNested="0"></info>*/
