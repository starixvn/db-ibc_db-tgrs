ALTER PROCEDURE [dbo].[TGRS_Rpt_PerformanceDetail_Bettype_BetChoice_League]  	
		@FromDate			DATE
	,	@ToDate				DATE
	,	@LeagueName			NVARCHAR(500)= ''
	,	@LeagueGroupIds		VARCHAR(2000) =  ''
	,	@BetType			SMALLINT
	,	@BetChoice			NVARCHAR(50)
	,	@BetTeam			NVARCHAR(50)
	,	@Oddsspread			MONEY = NULL
	,	@IsFMBetType		BIT = 0
	,	@IsExcludeLeagues	BIT = 1
	,	@Market				SMALLINT = 1	
AS    
/*  
	 Created:	20200731@John.Ngo
	 Task :		Detail report - Bet choice detail from Bet Type - Bet Choice - League
	 DB:		DB06.bodb_TGRS_UAT & DB061.bodb_TGRS
	 Original:  
 
	 Revisions:
		- 20200731@John.Ngo:	View down bet choice from League performance [Redmine ID: 137278]
		- 20200909@John.Ngo:	Performance Detail - Bettype - Support filter by LeagueName [Redmine ID: 141294]
		- 20210419@John.Ngo:	Wrong data Bettype betchoice league detail [Redmine ID: 153628]
		- 20210809@Adam.Tran: 	Sports - Performance Real Figures [Redmine: #158981]
		- 20210921@Adam.Tran:	Add Fast Market Bettype - [Redmine: #157999]
		- 20220117@John.Ngo: 	Support view down for Total Goal, Time Machine and Corner bettype [Redmine: #166679]
		- 20220222@John.Ngo:	Separate League Group for Virtual and SABA PinGoal [Redmine: #161859]
		- 20220307@John.Ngo: 	Update Separate League Group for Virtual [Redmine: #161859]
		- 20250312@Jaden.Tang:  Return League Group name instead of League Group ID [Redmine: #213765]
		
	 Param's Explanation:  	
		- @Market: -1 All; 0 Nonlive; 1 Live

*/  
 
BEGIN 
	SET NOCOUNT ON;	
	
	DECLARE @OtherGroupsId SMALLINT = 12;
	
	DECLARE @LeagueGroups AS TABLE (LeagueGroupId SMALLINT PRIMARY KEY CLUSTERED, LeagueGroupName VARCHAR(200), TargetLeagueGroupId SMALLINT)
	INSERT INTO @LeagueGroups(LeagueGroupId, LeagueGroupName, TargetLeagueGroupId)
	EXECUTE dbo.[TGRS_LeagueGroupSoccer_Get] @LeagueGroupIds = @LeagueGroupIds;
  
	IF (@LeagueName IS NULL OR @LeagueName = '')
		BEGIN
			IF @IsFMBetType = 1
				BEGIN
					SELECT 	P.LeagueId
						,	L.LeagueName
						,   lg.TargetLeagueGroupId AS LeagueGroupID
						,	lg.LeagueGroupName
						,	P.IsLive
						,	ISNULL(COUNT(DISTINCT P.CustId), 0) 	AS TraderCount  
						,	ISNULL(COUNT(DISTINCT P.MatchId), 0) 	AS MatchCount
						,	ISNULL(SUM(P.Stake), 0) 				AS Turnover 
						,	ISNULL(SUM(P.WinLost), 0) - ISNULL(SUM (P.Comm), 0) AS WinLoss  
						,	ISNULL(SUM(P.BetCount), 0) 			AS BetCount  
						,	CASE WHEN ISNULL(SUM(P.Stake), 0) <> 0 THEN (ISNULL(SUM(P.WinLost), 0) - ISNULL(SUM(P.Comm), 0)) * 100/SUM(P.Stake) ELSE NULL END AS Margin
						,	ISNULL(SUM(P.Stake_Real),0) 		AS TurnoverReal				
						,	ISNULL(SUM(CASE WHEN P.Is8RM = 0 THEN P.WinLost_Real ELSE 0 END),0) AS WinLossReal
						,	CASE WHEN ISNULL(SUM(P.Stake_Real),0) <> 0 THEN ISNULL(SUM(CASE WHEN P.Is8RM = 0 THEN P.WinLost_Real ELSE 0 END),0) * 100/ISNULL(SUM(P.Stake_Real),0) ELSE NULL END AS MarginReal
					FROM dbo.TraderPerformance_BetChoice_Detail AS P WITH (NOLOCK)
						INNER JOIN bodb02.dbo.League AS L WITH (NOLOCK) ON P.LeagueId = L.LeagueId
						LEFT JOIN @LeagueGroups AS lg ON L.LeagueGroupId = lg.LeagueGroupId						
						LEFT JOIN dbo.LeagueExclusion le WITH(NOLOCK) ON P.LeagueId = le.LeagueId
					WHERE P.EventDate BETWEEN @FromDate AND @ToDate
						AND P.BetType = @BetType 
						AND P.betteam = @BetTeam
						AND	(@Oddsspread = -1 OR P.Oddsspread = @Oddsspread)
						AND (@Market = -1 OR P.IsLive = @Market)
						AND (@IsExcludeLeagues = 0 OR le.LeagueId IS NULL) 
						AND (@LeagueGroupIds = '' OR lg.LeagueGroupId IS NOT NULL)
					GROUP BY P.LeagueId, L.LeagueName
						,	lg.TargetLeagueGroupId
						,	lg.LeagueGroupName
						,	P.IsLive
					ORDER BY Margin DESC, LeagueName ASC;
				END;
			ELSE
				BEGIN
					SELECT 	P.LeagueId
						,	L.LeagueName
						,   lg.TargetLeagueGroupId AS LeagueGroupID
						,   lg.LeagueGroupName
						,	P.IsLive
						,	ISNULL(COUNT(DISTINCT P.CustId), 0) 	AS TraderCount  
						,	ISNULL(COUNT(DISTINCT P.MatchId), 0) 	AS MatchCount
						,	ISNULL(SUM(P.Stake), 0) 				AS Turnover 
						,	ISNULL(SUM(P.WinLost), 0) - ISNULL(SUM (P.Comm), 0) AS WinLoss  
						,	ISNULL(SUM(P.BetCount), 0) 			AS BetCount  
						,	CASE WHEN ISNULL(SUM(P.Stake), 0) <> 0 THEN (ISNULL(SUM(P.WinLost), 0) - ISNULL(SUM(P.Comm), 0)) * 100/SUM(P.Stake) ELSE NULL END AS Margin
						,	ISNULL(SUM(P.Stake_Real),0) 		AS TurnoverReal				
						,	ISNULL(SUM(CASE WHEN P.Is8RM = 0 THEN P.WinLost_Real ELSE 0 END),0) AS WinLossReal
						,	CASE WHEN ISNULL(SUM(P.Stake_Real),0) <> 0 THEN ISNULL(SUM(CASE WHEN P.Is8RM = 0 THEN P.WinLost_Real ELSE 0 END),0) * 100/ISNULL(SUM(P.Stake_Real),0) ELSE NULL END AS MarginReal
					FROM dbo.TraderPerformance_BetChoice AS P WITH (NOLOCK)    
						INNER JOIN bodb02.dbo.League AS L WITH (NOLOCK) ON P.LeagueId = L.LeagueId
						LEFT JOIN @LeagueGroups AS lg ON L.LeagueGroupId = lg.LeagueGroupId
						LEFT JOIN dbo.BetChoiceMapping AS bcm WITH (NOLOCK) ON bcm.BetType = @BetType AND bcm.BetChoice = p.BetChoice
						LEFT JOIN dbo.LeagueExclusion le WITH(NOLOCK) ON P.LeagueId = le.LeagueId
					WHERE P.EventDate BETWEEN @FromDate AND @ToDate
						AND P.BetType = @BetType 
						AND ISNULL(bcm.TGRSBetChoice,P.BetChoice) = @BetChoice
						AND (@Market = -1 OR P.IsLive = @Market)
						AND (@IsExcludeLeagues = 0 OR le.LeagueId IS NULL) 
						AND (@LeagueGroupIds = '' OR lg.LeagueGroupId IS NOT NULL)
					GROUP BY P.LeagueId, L.LeagueName
						,   lg.LeagueGroupName
						,   lg.TargetLeagueGroupId
						,	P.IsLive
					ORDER BY Margin DESC, LeagueName ASC;
				END;
		END;
	ELSE
		BEGIN
			IF @IsFMBetType = 1
				BEGIN
					SELECT 	P.LeagueId
						,	L.LeagueName
						,   lg.TargetLeagueGroupId AS LeagueGroupID
						,   lg.LeagueGroupName
						,	P.IsLive
						,	ISNULL(COUNT(DISTINCT P.CustId), 0) 	AS TraderCount  
						,	ISNULL(COUNT(DISTINCT P.MatchId), 0) 	AS MatchCount
						,	ISNULL(SUM(P.Stake), 0) 				AS Turnover  
						,	ISNULL(SUM(P.WinLost), 0) - ISNULL(SUM (P.Comm), 0) AS WinLoss  
						,	ISNULL(SUM(P.BetCount), 0) 				AS BetCount  
						,	CASE WHEN ISNULL(SUM(P.Stake), 0) <> 0 THEN (ISNULL(SUM(P.WinLost), 0) - ISNULL(SUM(P.Comm), 0)) * 100/SUM(P.Stake) ELSE NULL END AS Margin
						,	ISNULL(SUM(P.Stake_Real),0) 			AS TurnoverReal				
						,	ISNULL(SUM(CASE WHEN P.Is8RM = 0 THEN P.WinLost_Real ELSE 0 END),0) AS WinLossReal
						,	CASE WHEN ISNULL(SUM(P.Stake_Real),0) <> 0 THEN ISNULL(SUM(CASE WHEN P.Is8RM = 0 THEN P.WinLost_Real ELSE 0 END),0) * 100/ISNULL(SUM(P.Stake_Real),0) ELSE NULL END AS MarginReal
					FROM dbo.TraderPerformance_BetChoice_Detail AS P WITH (NOLOCK)    
						INNER JOIN bodb02.dbo.League AS L WITH (NOLOCK) ON P.LeagueId = L.LeagueId
						LEFT JOIN @LeagueGroups AS lg ON L.LeagueGroupId = lg.LeagueGroupId						
						LEFT JOIN dbo.LeagueExclusion le WITH(NOLOCK) ON P.LeagueId = le.LeagueId
					WHERE P.EventDate BETWEEN @FromDate AND @ToDate
						AND  P.BetType = @BetType 
						AND P.betteam = @BetTeam
						AND	(@Oddsspread = -1 OR P.Oddsspread = @Oddsspread)
						AND L.LeagueName LIKE '%' + @LeagueName + '%'
						AND (@Market = -1 OR P.IsLive = @Market)
						AND (@IsExcludeLeagues = 0 OR le.LeagueId IS NULL) 
						AND (@LeagueGroupIds = '' OR lg.LeagueGroupId IS NOT NULL)
					GROUP BY P.LeagueId, L.LeagueName
						,   lg.LeagueGroupName
						,   lg.TargetLeagueGroupId
						,	P.IsLive    
					ORDER BY Margin DESC, LeagueName ASC;
				END;
			ELSE
				BEGIN
					SELECT 	P.LeagueId
						,	L.LeagueName
						,   lg.TargetLeagueGroupId AS LeagueGroupID
						,   lg.LeagueGroupName
						,	P.IsLive
						,	ISNULL(COUNT(DISTINCT P.CustId), 0) 	AS TraderCount  
						,	ISNULL(COUNT(DISTINCT P.MatchId), 0) 	AS MatchCount
						,	ISNULL(SUM(P.Stake), 0) 				AS Turnover  
						,	ISNULL(SUM(P.WinLost), 0) - ISNULL(SUM (P.Comm), 0) AS WinLoss  
						,	ISNULL(SUM(P.BetCount), 0) 				AS BetCount  
						,	CASE WHEN ISNULL(SUM(P.Stake), 0) <> 0 THEN (ISNULL(SUM(P.WinLost), 0) - ISNULL(SUM(P.Comm), 0)) * 100/SUM(P.Stake) ELSE NULL END AS Margin
						,	ISNULL(SUM(P.Stake_Real),0) 			AS TurnoverReal				
						,	ISNULL(SUM(CASE WHEN P.Is8RM = 0 THEN P.WinLost_Real ELSE 0 END),0) AS WinLossReal
						,	CASE WHEN ISNULL(SUM(P.Stake_Real),0) <> 0 THEN ISNULL(SUM(CASE WHEN P.Is8RM = 0 THEN P.WinLost_Real ELSE 0 END),0) * 100/ISNULL(SUM(P.Stake_Real),0) ELSE NULL END AS MarginReal
					FROM dbo.TraderPerformance_BetChoice AS P WITH (NOLOCK)    
						INNER JOIN bodb02.dbo.League AS L WITH (NOLOCK) ON P.LeagueId = L.LeagueId
						LEFT JOIN @LeagueGroups AS lg ON L.LeagueGroupId = lg.LeagueGroupId
						LEFT JOIN dbo.BetChoiceMapping AS bcm WITH (NOLOCK) ON bcm.BetType = @BetType AND bcm.BetChoice = p.BetChoice
						LEFT JOIN dbo.LeagueExclusion le WITH(NOLOCK) ON P.LeagueId = le.LeagueId
					WHERE P.EventDate BETWEEN @FromDate AND @ToDate
						AND P.BetType = @BetType 
						AND ISNULL(bcm.TGRSBetChoice,P.BetChoice) = @BetChoice
						AND L.LeagueName LIKE '%' + @LeagueName + '%'
						AND (@Market = -1 OR P.IsLive = @Market)
						AND (@IsExcludeLeagues = 0 OR le.LeagueId IS NULL) 
						AND (@LeagueGroupIds = '' OR lg.LeagueGroupId IS NOT NULL)
					GROUP BY P.LeagueId, L.LeagueName
						,   lg.LeagueGroupName
						,   lg.TargetLeagueGroupId
						,	P.IsLive    
					ORDER BY Margin DESC, LeagueName ASC;     
				END;
		END;
END;

GO

/*<info serverAlias="DBTGRS-bodb_TGRS" executers="wsv_tgrs" isFunction="0" isNested="0"></info>*/