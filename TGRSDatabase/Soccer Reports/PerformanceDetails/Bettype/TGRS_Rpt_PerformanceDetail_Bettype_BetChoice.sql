ALTER PROCEDURE [dbo].[TGRS_Rpt_PerformanceDetail_Bettype_BetChoice]  	
		@FromDate			DATE
	,	@ToDate				DATE
	,	@LeagueName			NVARCHAR(500)= ''
	,	@LeagueGroupIds		VARCHAR(2000) =  ''
	,	@Bettype			SMALLINT
	,	@IsExcludeLeagues	BIT = 1
	,	@Market				SMALLINT = 1
AS    
/*  
	 Created:	20171212@Aaron
	 Task :		Detail report - Bet choice detail from Bet Type
	 DB:		DB06.bodb_TGRS_UAT & DB061.bodb_TGRS
	 Original:  
 
	 Revisions:
		- 20180912@Simon:		add league exclusion
		- 20190919@Long.Luu:	Support Nonlive Data [Redmine ID: 118959]
		- 20191022@Long.Luu:	Showing betteam in case of betchoices are not mapped [Redmine ID: 121268]
		- 20191023@John.Ngo:	Enhance performance [Redmine ID: 121268]
		- 20200709@John.Ngo:	Performance Detail - Support filter by league group & Fix issue 'show betteam' [Redmine ID: 137276]
		- 20200909@John.Ngo:	Performance Detail - Bettype - Support filter by LeagueName [Redmine ID: 141294]
		- 20210809@Adam.Tran: 	Sports - Performance Real Figures [Redmine: #158981]
		- 20210915@Adam.Tran: 	Add Fast Market Bettype - [Redmine: #157999]
	 Param's Explanation:  	
		- @Market: -1 All; 0 Nonlive; 1 Live

	 Exam: 
		EXEC  TGRS_Rpt_PerformanceDetail_Bettype_BetChoice @FromDate = '2017-11-01', @ToDate= '2018-05-30', @Bettype = 15
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
	
	DECLARE @IsFMBetType 	BIT;
	
	SET @IsFMBetType = 
		CASE 
			WHEN EXISTS (
				SELECT b.BetType
				FROM dbo.BetChoice_FastMarketMapping AS b
				WHERE b.BetType = @Bettype) THEN 1
			ELSE 0
		END;

	IF (@LeagueName IS NULL OR @LeagueName = '')		
		BEGIN
			IF @IsFMBetType = 1
				BEGIN
					SELECT P.betteam											AS BetTeam
						,	FM.BetOption										AS BetOption
						,	P.oddsspread										AS OddsSpread
						,	P.IsLive											AS IsLive
						,	ISNULL(COUNT(DISTINCT P.LeagueId), 0)				AS LeagueCount
						,	ISNULL(COUNT(DISTINCT P.MatchId), 0)				AS MatchCount
						,	ISNULL(SUM(P.Stake), 0)								AS Turnover 
						,	ISNULL(SUM(P.WinLost), 0) - ISNULL(SUM (P.Comm), 0)	AS WinLoss
						,	ISNULL(SUM(P.Stake_Real),0) 						AS TurnoverReal				
						,	ISNULL(SUM(CASE WHEN P.Is8RM = 0 THEN P.WinLost_Real ELSE 0 END),0) AS WinLossReal
						,	ISNULL(SUM(P.BetCount), 0)							AS BetCount
					FROM dbo.TraderPerformance_FastMarketBetChoice AS P WITH (NOLOCK)
						INNER JOIN bodb02.dbo.League AS L WITH (NOLOCK) ON P.LeagueId = L.LeagueId
						LEFT JOIN @LeagueGroups AS lg ON L.LeagueGroupId = lg.LeagueGroupId
						LEFT JOIN dbo.LeagueExclusion le WITH(NOLOCK) ON P.LeagueId = le.LeagueId
						LEFT JOIN dbo.BetChoice_FastMarketMapping AS FM WITH (NOLOCK) ON FM.BetType = P.BetType
					WHERE	P.BetType = @Bettype
						AND P.EventDate BETWEEN @FromDate AND @ToDate
						AND (@Market = -1 OR P.IsLive = @Market)
						AND (@IsExcludeLeagues = 0 OR le.LeagueId IS NULL)
						AND (@LeagueGroupIds = '' OR lg.LeagueGroupId IS NOT NULL)
					GROUP BY P.betteam, FM.BetOption, P.oddsspread, P.IsLive;
				END;
			ELSE
				BEGIN
					SELECT ISNULL(bcm.TGRSBetChoice, P.BetChoice)				AS BetChoice
						,	P.IsLive											AS IsLive
						,	ISNULL(COUNT(DISTINCT P.LeagueId), 0)				AS LeagueCount
						,	ISNULL(COUNT(DISTINCT P.MatchId), 0)				AS MatchCount
						,	ISNULL(SUM(P.Stake), 0)								AS Turnover 
						,	ISNULL(SUM(P.WinLost), 0) - ISNULL(SUM (P.Comm), 0)	AS WinLoss
						,	ISNULL(SUM(P.Stake_Real),0) 						AS TurnoverReal				
						,	ISNULL(SUM(CASE WHEN P.Is8RM = 0 THEN P.WinLost_Real ELSE 0 END),0) AS WinLossReal
						,	ISNULL(SUM(P.BetCount), 0)							AS BetCount
					FROM dbo.TraderPerformance_BetChoice AS P WITH (NOLOCK)
						INNER JOIN bodb02.dbo.League AS L WITH (NOLOCK) ON P.LeagueId = L.LeagueId
						LEFT JOIN @LeagueGroups AS lg ON L.LeagueGroupId = lg.LeagueGroupId
						LEFT JOIN dbo.BetChoiceMapping AS bcm WITH (NOLOCK) ON bcm.BetType = @Bettype
						LEFT JOIN dbo.LeagueExclusion le WITH(NOLOCK) ON P.LeagueId = le.LeagueId
					WHERE	P.Bettype = @Bettype
						AND P.EventDate BETWEEN @FromDate AND @ToDate
						AND (@Market = -1 OR P.IsLive = @Market)
						AND (P.BetChoice = bcm.BetChoice OR bcm.BetChoice IS NULL)
						AND (@IsExcludeLeagues = 0 OR le.LeagueId IS NULL)
						AND (@LeagueGroupIds = '' OR lg.LeagueGroupId IS NOT NULL)
					GROUP BY ISNULL(bcm.TGRSBetChoice, P.BetChoice), P.IsLive;
				END;			
		END;
	ELSE
		BEGIN
			IF @IsFMBetType = 1
				BEGIN
					SELECT P.betteam										AS BetTeam
					,	FM.BetOption										AS BetOption
					,	P.oddsspread										AS OddsSpread
					,	P.IsLive											AS IsLive
					,	ISNULL(COUNT(DISTINCT P.LeagueId), 0)				AS LeagueCount
					,	ISNULL(COUNT(DISTINCT P.MatchId), 0)				AS MatchCount
					,	ISNULL(SUM(P.Stake), 0)								AS Turnover 
					,	ISNULL(SUM(P.WinLost), 0) - ISNULL(SUM (P.Comm), 0)	AS WinLoss
					,	ISNULL(SUM(P.Stake_Real),0) 						AS TurnoverReal
					,	ISNULL(SUM(P.WinLost_Real),0) 						AS WinLossReal
					,	ISNULL(SUM(CASE WHEN P.Is8RM = 0 THEN P.WinLost_Real ELSE 0 END),0) AS WinLossReal
					,	ISNULL(SUM(P.BetCount), 0)							AS BetCount				
					FROM dbo.TraderPerformance_FastMarketBetChoice AS P WITH (NOLOCK)
						INNER JOIN bodb02.dbo.League AS L WITH (NOLOCK) ON P.LeagueId = L.LeagueId
						LEFT JOIN @LeagueGroups AS lg ON L.LeagueGroupId = lg.LeagueGroupId
						LEFT JOIN dbo.LeagueExclusion le WITH(NOLOCK) ON P.LeagueId = le.LeagueId
						LEFT JOIN dbo.BetChoice_FastMarketMapping AS FM WITH (NOLOCK) ON FM.BetType = P.BetType
					WHERE	P.Bettype = @Bettype
						AND P.EventDate BETWEEN @FromDate AND @ToDate
						AND L.LeagueName LIKE '%' + @LeagueName + '%'
						AND (@Market = -1 OR P.IsLive = @Market)						
						AND (@IsExcludeLeagues = 0 OR le.LeagueId IS NULL)
						AND (@LeagueGroupIds = '' OR lg.LeagueGroupId IS NOT NULL)
					GROUP BY P.betteam, FM.BetOption, P.oddsspread, P.IsLive;
				END;
			ELSE
				BEGIN
					SELECT ISNULL(bcm.TGRSBetChoice, P.BetChoice)			AS BetChoice
					,	P.IsLive											AS IsLive
					,	ISNULL(COUNT(DISTINCT P.LeagueId), 0)				AS LeagueCount
					,	ISNULL(COUNT(DISTINCT P.MatchId), 0)				AS MatchCount
					,	ISNULL(SUM(P.Stake), 0)								AS Turnover 
					,	ISNULL(SUM(P.WinLost), 0) - ISNULL(SUM (P.Comm), 0)	AS WinLoss
					,	ISNULL(SUM(P.Stake_Real),0) 						AS TurnoverReal
					,	ISNULL(SUM(P.WinLost_Real),0) 						AS WinLossReal
					,	ISNULL(SUM(CASE WHEN P.Is8RM = 0 THEN P.WinLost_Real ELSE 0 END),0) AS WinLossReal
					,	ISNULL(SUM(P.BetCount), 0)							AS BetCount				
					FROM dbo.TraderPerformance_BetChoice AS P WITH (NOLOCK)
						INNER JOIN bodb02.dbo.League AS L WITH (NOLOCK) ON P.LeagueId = L.LeagueId
						LEFT JOIN @LeagueGroups AS lg ON L.LeagueGroupId = lg.LeagueGroupId
						LEFT JOIN dbo.BetChoiceMapping AS bcm WITH (NOLOCK) ON bcm.BetType = @Bettype
						LEFT JOIN dbo.LeagueExclusion le WITH(NOLOCK) ON P.LeagueId = le.LeagueId
					WHERE	P.Bettype = @Bettype
						AND P.EventDate BETWEEN @FromDate AND @ToDate
						AND L.LeagueName LIKE '%' + @LeagueName + '%'
						AND (@Market = -1 OR P.IsLive = @Market)
						AND (P.BetChoice = bcm.BetChoice OR bcm.BetChoice IS NULL)
						AND (@IsExcludeLeagues = 0 OR le.LeagueId IS NULL)
						AND (@LeagueGroupIds = '' OR lg.LeagueGroupId IS NOT NULL)
					GROUP BY ISNULL(bcm.TGRSBetChoice, P.BetChoice), P.IsLive;
				END;
		END;
		
		SELECT @IsFMBetType AS IsFMBetType;
END;

GO


