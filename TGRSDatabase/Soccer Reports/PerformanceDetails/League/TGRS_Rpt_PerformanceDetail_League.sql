ALTER PROCEDURE [dbo].[TGRS_Rpt_PerformanceDetail_League]  	
		@FromDate			DATE
	,	@ToDate				DATE
	,	@LeagueName			NVARCHAR(100)= ''
	,	@LeagueGroupIds		VARCHAR(2000) =  ''
	,	@Turnover			MONEY = NULL
	,	@WinLoss			MONEY = NULL
	,	@MarginFrom			MONEY = NULL
	,	@MarginTo			MONEY = NULL
	,	@Bettypes			VARCHAR(2000) =  '0'
	,	@IsExcludeLeagues	BIT = 1
	,	@Market				SMALLINT = 1
AS    
/*  
	 Created:	20160216@Long.Luu
	 Task :		Detail report - League Performance
	 DB:		DBTGRS.bodb_TGRS
	 Original:  
 
	 Revisions:      	
 		- 20171019@Simon:		Change VARCHAR(200) to VARCHAR(2000)
		- 20171205@Simon:		get only Live data & Bettypes are not disabled
		- 20180912@Simon:		add league exclusion
		- 20190919@Long.Luu:	Support Nonlive Data [Redmine ID: 118959]
		- 20191023@John.Ngo:	Enhance performance [Redmine ID: 121268]
		- 20200709@John.Ngo:	Performance Detail - Support filter by league group [Redmine ID: 137276]

	 Param's Explanation:  
		- @Market: -1 All; 0 Nonlive; 1 Live	

	 Exam: 
	  	EXEC  TGRS_Rpt_PerformanceDetail_League @FromDate = '2014-01-01', @ToDate= '2014-05-30'   
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

	DECLARE @BettypeList AS TABLE (bettype SMALLINT);

	IF @Bettypes <> '0'
		INSERT INTO @BettypeList
		SELECT val 
		FROM dbo.strSplit_Key(@Bettypes,',');
	ELSE 
		INSERT INTO @BettypeList
		SELECT Bettype 
		FROM dbo.Bettype WITH (NOLOCK);
	
	IF (@LeagueName IS NULL OR @LeagueName = '')
		BEGIN
			SELECT *, CASE WHEN p.Turnover <> 0  THEN  p.WinLoss * 100 /p.Turnover ELSE NULL END  AS margin
			FROM 
				(SELECT P.LeagueId, 
						L.LeagueName, 
						L.LeagueGroupID,
						P.IsLive,
						ISNULL(COUNT(DISTINCT P.CustId), 0) AS TraderCount, 
						ISNULL(COUNT(DISTINCT P.MatchId), 0) AS MatchCount, 
						ISNULL(SUM(P.Stake), 0) AS Turnover, 
						ISNULL(SUM(P.WinLost), 0) - ISNULL(SUM (P.Comm), 0) AS WinLoss, 
						ISNULL(SUM (BetCount), 0) AS BetCount
					FROM dbo.TraderPerformance AS P WITH (NOLOCK)
						INNER JOIN bodb02.dbo.League AS L WITH (NOLOCK) ON P.LeagueId = L.LeagueId
						LEFT JOIN @LeagueGroups AS lg ON L.LeagueGroupId = lg.LeagueGroupId
						LEFT JOIN dbo.LeagueExclusion le WITH(NOLOCK) ON P.LeagueId = le.LeagueId
					WHERE P.EventDate BETWEEN @FromDate AND @ToDate
						AND P.Bettype IN (SELECT Bettype FROM @BettypeList)
						AND (@Market = -1 OR P.IsLive = @Market)
						AND (@IsExcludeLeagues = 0 OR le.LeagueId IS NULL)
						AND (@LeagueGroupIds = '' OR lg.LeagueGroupId IS NOT NULL)
					GROUP BY P.LeagueId , L.LeagueName, L.LeagueGroupID, P.IsLive 
				) AS p 
			WHERE  (@WinLoss IS NULL  OR P.WinLoss >= @WinLoss)
				AND ( @Turnover IS NULL OR p.Turnover >= @Turnover)
				AND ( @MarginFrom IS NULL  OR (Turnover <> 0 and  p.WinLoss * 100 /p.Turnover  >= @MarginFrom))
				AND ( @MarginTo IS NULL OR (Turnover <> 0 and  p.WinLoss * 100 /p.Turnover <= @MarginTo))
			ORDER BY Margin DESC, P.LeagueName ASC;
		END;
	ELSE
		BEGIN
			SELECT *, CASE WHEN p.Turnover <> 0  THEN  p.WinLoss * 100 /p.Turnover ELSE NULL END  AS margin
			FROM 
				(SELECT P.LeagueId, 
						L.LeagueName,
						L.LeagueGroupID,
						P.IsLive,
						ISNULL(COUNT(DISTINCT P.CustId), 0) AS TraderCount, 
						ISNULL(COUNT(DISTINCT P.MatchId), 0) AS MatchCount, 
						ISNULL(SUM(P.Stake), 0) AS Turnover, 
						ISNULL(SUM(P.WinLost), 0) - ISNULL(SUM (P.Comm), 0) AS WinLoss, 
						ISNULL(SUM (BetCount), 0) AS BetCount
					FROM dbo.TraderPerformance AS P WITH (NOLOCK)
						INNER JOIN bodb02.dbo.League AS L WITH (NOLOCK) ON P.LeagueId = L.LeagueId
						LEFT JOIN @LeagueGroups AS lg ON L.LeagueGroupId = lg.LeagueGroupId
						LEFT JOIN dbo.LeagueExclusion le WITH(NOLOCK) ON P.LeagueId = le.LeagueId
					WHERE P.EventDate BETWEEN @FromDate AND @ToDate
						AND P.Bettype IN (SELECT Bettype FROM @BettypeList)
						AND L.LeagueName LIKE '%' + @LeagueName + '%'
						AND (@Market = -1 OR P.IsLive = @Market)
						AND (@IsExcludeLeagues = 0 OR le.LeagueId IS NULL)
						AND (@LeagueGroupIds = '' OR lg.LeagueGroupId IS NOT NULL)
					GROUP BY P.LeagueId, L.LeagueName, L.LeagueGroupID, P.IsLive 
				) AS p 
			WHERE  (@WinLoss IS NULL  OR P.WinLoss >= @WinLoss)
				AND ( @Turnover IS NULL OR p.Turnover >= @Turnover)
				AND ( @MarginFrom IS NULL  OR (Turnover <> 0 and  p.WinLoss * 100 /p.Turnover  >= @MarginFrom))
				AND ( @MarginTo IS NULL OR (Turnover <> 0 and  p.WinLoss * 100 /p.Turnover <= @MarginTo))
			ORDER BY Margin DESC, P.LeagueName ASC;
		END;
END;

GO
/*<info serverAlias="DBTGRS-bodb_TGRS" executers="bodbTGRSNet" isFunction="0" isNested="0"></info>*/