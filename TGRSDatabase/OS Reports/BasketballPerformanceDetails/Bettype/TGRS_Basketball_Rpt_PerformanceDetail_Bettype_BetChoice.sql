CREATE PROCEDURE [dbo].[TGRS_Basketball_Rpt_PerformanceDetail_Bettype_BetChoice]  	
		@FromDate			DATE
	,	@ToDate				DATE
	,	@LeagueName			NVARCHAR(500)= ''
	,	@LeagueGroupIds		VARCHAR(2000) =  ''
	,	@Bettype			SMALLINT
	,	@LiveType			SMALLINT = 1
AS    
/*  
	Created:	20200918@John.Ngo
	Task :		Basketball Performance Detail - Bettype - BetChoice
	DB:			DBTGRS.bodb_TGRS
	Original:  
  
	Revisions: 	
   		- 20200918@John.Ngo: Basketball Performance Detail - Bettype - BetChoice [Redmine ID: 140875]

	Param's Explanation:  	
		- @LiveType: -1 All; 0 Nonlive; 1 Live

	 Exam: 
		EXEC  TGRS_Basketball_Rpt_PerformanceDetail_Bettype_BetChoice @FromDate = '2020-01-01', @ToDate= '2020-12-30', @Bettype = 20
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
			SELECT P.BetChoice										AS BetChoice,
				P.IsLive											AS IsLive,
				ISNULL(COUNT(DISTINCT P.LeagueId), 0)				AS LeagueCount, 
				ISNULL(COUNT(DISTINCT P.MatchId), 0)				AS MatchCount, 
				ISNULL(SUM(P.Turnover), 0)							AS Turnover, 
				ISNULL(SUM(P.WinLoss), 0) - ISNULL(SUM (P.Comm), 0)	AS WinLoss, 
				ISNULL(SUM(P.BetCount), 0)							AS BetCount
			FROM dbo.OSDataTGRS_BetChoice AS P WITH (NOLOCK)
				INNER JOIN bodb02.dbo.League AS L WITH (NOLOCK) ON P.LeagueId = L.LeagueId
				LEFT JOIN @LeagueGroups AS lg ON L.LeagueGroupId = lg.LeagueGroupId
			WHERE	P.BettypeId = @Bettype
				AND P.EventDate BETWEEN @FromDate AND @ToDate
				AND P.SportId = 2
				AND (@LiveType = -1 OR P.IsLive = @LiveType)
				AND (@LeagueGroupIds = '' OR lg.LeagueGroupId IS NOT NULL)
			GROUP BY P.BetChoice,
				P.IsLive;
		END;
	ELSE
		BEGIN
			SELECT P.BetChoice										AS BetChoice,
				P.IsLive											AS IsLive,
				ISNULL(COUNT(DISTINCT P.LeagueId), 0)				AS LeagueCount, 
				ISNULL(COUNT(DISTINCT P.MatchId), 0)				AS MatchCount, 
				ISNULL(SUM(P.Turnover), 0)							AS Turnover, 
				ISNULL(SUM(P.WinLoss), 0) - ISNULL(SUM (P.Comm), 0)	AS WinLoss, 
				ISNULL(SUM(P.BetCount), 0)							AS BetCount
			FROM dbo.OSDataTGRS_BetChoice AS P WITH (NOLOCK)
				INNER JOIN bodb02.dbo.League AS L WITH (NOLOCK) ON P.LeagueId = L.LeagueId
				LEFT JOIN @LeagueGroups AS lg ON L.LeagueGroupId = lg.LeagueGroupId
			WHERE	P.BettypeId = @Bettype
				AND P.EventDate BETWEEN @FromDate AND @ToDate
				AND P.SportId = 2
				AND L.LeagueName LIKE '%' + @LeagueName + '%'
				AND (@LiveType = -1 OR P.IsLive = @LiveType)
				AND (@LeagueGroupIds = '' OR lg.LeagueGroupId IS NOT NULL)
			GROUP BY P.BetChoice,
				P.IsLive;
		END;
END;

GO
/*<info serverAlias="DBTGRS-bodb_TGRS" executers="bodbTGRSNet" isFunction="0" isNested="0"></info>*/