ALTER PROCEDURE [dbo].[TGRS_Rpt_PerformanceDetail_Bettype_BetChoice_League]  	
		@FromDate			DATE
	,	@ToDate				DATE
	,	@LeagueName			NVARCHAR(500)= ''
	,	@LeagueGroupIds		VARCHAR(2000) =  ''
	,	@Bettype			SMALLINT
	,	@BetChoice			NVARCHAR(50)
	,	@IsExcludeLeagues	BIT = 1
	,	@Market				SMALLINT = 1
AS    
/*  
	 Created:	20200731@John.Ngo
	 Task :		Detail report - Bet choice detail from Bet Type - Bet Choice - League
	 DB:		DBTGRS.bodb_TGRS
	 Original:  
 
	 Revisions:
		- 20200731@John.Ngo:	View down bet choice from League performance [Redmine ID: 137278]
		- 20200909@John.Ngo:	Performance Detail - Bettype - Support filter by LeagueName [Redmine ID: 141294]

	 Param's Explanation:  	
		- @Market: -1 All; 0 Nonlive; 1 Live

*/  
 
BEGIN 
	SET NOCOUNT ON;
 
 IF EXISTS (SELECT 1 FROM dbo.BetChoiceMapping AS bcm WITH (NOLOCK) WHERE bcm.BetType = @Bettype AND bcm.TGRSBetChoice = @BetChoice)
	BEGIN
		SELECT @BetChoice = bcm.BetChoice FROM dbo.BetChoiceMapping AS bcm WITH (NOLOCK) WHERE bcm.BetType = @Bettype AND bcm.TGRSBetChoice = @BetChoice
	END;

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
				  ISNULL(COUNT(DISTINCT P.CustId), 0) AS TraderCount,  
				  ISNULL(COUNT(DISTINCT P.MatchId), 0) AS MatchCount,
				  ISNULL(SUM(P.Stake), 0) AS Turnover,   
				  ISNULL(SUM(P.WinLost), 0) - ISNULL(SUM (P.Comm), 0) AS WinLoss,   
				  ISNULL(SUM(P.BetCount), 0) AS BetCount,  
				  CASE WHEN ISNULL(SUM(P.Stake), 0) <> 0 THEN (ISNULL(SUM(P.WinLost), 0) - ISNULL(SUM(P.Comm), 0)) * 100/SUM(P.Stake) ELSE NULL END AS Margin    
			FROM dbo.TraderPerformance_BetChoice AS P WITH (NOLOCK)    
				INNER JOIN bodb02.dbo.League AS L WITH (NOLOCK) ON P.LeagueId = L.LeagueId
				LEFT JOIN @LeagueGroups AS lg ON L.LeagueGroupId = lg.LeagueGroupId
				LEFT JOIN dbo.LeagueExclusion le WITH(NOLOCK) ON P.LeagueId = le.LeagueId
			WHERE P.EventDate BETWEEN @FromDate AND @ToDate
				AND  P.Bettype = @Bettype and P.BetChoice = @BetChoice
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
				  ISNULL(COUNT(DISTINCT P.CustId), 0) AS TraderCount,  
				  ISNULL(COUNT(DISTINCT P.MatchId), 0) AS MatchCount,
				  ISNULL(SUM(P.Stake), 0) AS Turnover,   
				  ISNULL(SUM(P.WinLost), 0) - ISNULL(SUM (P.Comm), 0) AS WinLoss,   
				  ISNULL(SUM(P.BetCount), 0) AS BetCount,  
				  CASE WHEN ISNULL(SUM(P.Stake), 0) <> 0 THEN (ISNULL(SUM(P.WinLost), 0) - ISNULL(SUM(P.Comm), 0)) * 100/SUM(P.Stake) ELSE NULL END AS Margin    
			FROM dbo.TraderPerformance_BetChoice AS P WITH (NOLOCK)    
				INNER JOIN bodb02.dbo.League AS L WITH (NOLOCK) ON P.LeagueId = L.LeagueId
				LEFT JOIN @LeagueGroups AS lg ON L.LeagueGroupId = lg.LeagueGroupId
				LEFT JOIN dbo.LeagueExclusion le WITH(NOLOCK) ON P.LeagueId = le.LeagueId
			WHERE P.EventDate BETWEEN @FromDate AND @ToDate
				AND  P.Bettype = @Bettype and P.BetChoice = @BetChoice
				AND L.LeagueName LIKE '%' + @LeagueName + '%'
				AND (@Market = -1 OR P.IsLive = @Market)
				AND (@IsExcludeLeagues = 0 OR le.LeagueId IS NULL) 
				AND (@LeagueGroupIds = '' OR lg.LeagueGroupId IS NOT NULL)
			GROUP BY P.LeagueId, L.LeagueName, L.LeagueGroupID, P.IsLive    
			ORDER BY Margin DESC, LeagueName ASC;     
		END;
END;

GO
/*<info serverAlias="DBTGRS-bodb_TGRS" executers="bodbTGRSNet" isFunction="0" isNested="0"></info>*/