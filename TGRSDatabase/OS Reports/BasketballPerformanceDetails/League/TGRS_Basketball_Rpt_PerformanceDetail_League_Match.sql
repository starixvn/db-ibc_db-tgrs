ALTER PROCEDURE [dbo].[TGRS_Basketball_Rpt_PerformanceDetail_League_Match]  	
		@FromDate			DATE
	,	@ToDate				DATE
	,	@LeagueId			INT
	,	@LeagueGroupIds		VARCHAR(2000) = ''
	,	@Bettypes			VARCHAR(2000) = '0'
	,	@LiveType			SMALLINT = -1
AS    
/*  
	Task :		Basketball Performance Detail - League - Match
	DB:			DBTGRS.bodb_TGRS
	Original:  
  
	Revisions: 	
   		- 20250414@Jaden: Basketball Performance Detail - League - Match dimension

	Param's Explanation:  	
		- @LiveType: -1 All; 0 Nonlive; 1 Live
		
	Exam: 
		EXEC TGRS_Basketball_Rpt_PerformanceDetail_League_Match @FromDate = '2024-01-01', @ToDate= '2024-12-30', @LeagueId = 78368, @LiveType = 0
*/  
 
BEGIN 
	SET NOCOUNT ON;
	
	DECLARE @LeagueGroups AS TABLE (LeagueGroupId SMALLINT PRIMARY KEY CLUSTERED, LeagueGroupName NVARCHAR(200))
	IF @LeagueGroupIds <> ''
		BEGIN
			INSERT INTO @LeagueGroups(LeagueGroupId)
			SELECT value
			FROM STRING_SPLIT(@LeagueGroupIds, ',');
		END
	ELSE 
		BEGIN
			INSERT INTO @LeagueGroups(LeagueGroupId, LeagueGroupName)
			EXECUTE dbo.TGRS_LeagueGroup_GetBySportId @SportId = 2;
		END;

	DECLARE @BettypeList AS TABLE (BettypeId SMALLINT)
	IF @Bettypes <> '0'
		BEGIN
			INSERT INTO @BettypeList
			SELECT value
			FROM STRING_SPLIT(@Bettypes, ',');
		END;
	ELSE
		BEGIN
			INSERT INTO @BettypeList
			SELECT b.typeid
			FROM bodb02.dbo.bettype b WITH(NOLOCK)
			WHERE b.typeid IN (SELECT bettype FROM bodb02.dbo.SportBettypeMatrix WITH (NOLOCK) WHERE SportType = 2);
		END;
	
	-- Create a temporary table with match information from all sources
	IF OBJECT_ID('tempdb..#MatchData') IS NOT NULL
	BEGIN
		DROP TABLE #MatchData;
	END;

	CREATE TABLE #MatchData (
		MatchId INT,
		HomeTeamId INT,
		AwayTeamId INT,
		EventDate DATETIME
	);

	-- Insert data from bodb02.dbo.match
	INSERT INTO #MatchData (MatchId, HomeTeamId, AwayTeamId, EventDate)
	SELECT matchid, homeid, awayid, eventdate
	FROM bodb02.dbo.[match] WITH (NOLOCK)
	WHERE eventdate BETWEEN @FromDate AND @ToDate
		AND leagueid = @LeagueId;

	-- Insert data from bodb02.dbo.match14
	INSERT INTO #MatchData (MatchId, HomeTeamId, AwayTeamId, EventDate)
	SELECT matchid, homeid, awayid, eventdate
	FROM bodb02.dbo.match14 WITH (NOLOCK)
	WHERE eventdate BETWEEN @FromDate AND @ToDate
		AND matchid NOT IN (SELECT MatchId FROM #MatchData)
		AND leagueid = @LeagueId;

	-- Insert data from bodb_Archive.dbo.match_bk
	INSERT INTO #MatchData (MatchId, HomeTeamId, AwayTeamId, EventDate)
	SELECT matchid, homeid, awayid, eventdate
	FROM bodb_Archive.dbo.match_bk WITH (NOLOCK)
	WHERE eventdate BETWEEN @FromDate AND @ToDate
		AND matchid NOT IN (SELECT MatchId FROM #MatchData)
		AND leagueid = @LeagueId;

	-- Create index for better performance
	CREATE CLUSTERED INDEX IX_MatchData ON #MatchData (MatchId);
	
	SELECT 
		P.MatchId,
		HomeTeam.teamname + '-vs-' + AwayTeam.teamname AS MatchName,
		P.EventDate,
		ISNULL(SUM(P.BetCount), 0) AS BetCount,
		ISNULL(SUM(P.Turnover), 0) AS Turnover,
		ISNULL(SUM(P.Winloss), 0) - ISNULL(SUM(P.Comm), 0) AS WinLoss,
		CASE WHEN ISNULL(SUM(P.Turnover), 0) <> 0
			THEN (ISNULL(SUM(P.Winloss), 0) - ISNULL(SUM(P.Comm), 0)) * 100/SUM(P.Turnover)
			ELSE NULL
		END AS Margin,
		ISNULL(SUM(P.Turnover_AR), 0) AS Turnover_AR,
		ISNULL(SUM(P.Winloss_AR), 0) - ISNULL(SUM(P.Comm_AR), 0) AS WinLoss_AR,
		CASE WHEN ISNULL(SUM(P.Turnover_AR), 0) <> 0
			THEN (ISNULL(SUM(P.Winloss_AR), 0) - ISNULL(SUM(P.Comm_AR), 0)) * 100/SUM(P.Turnover_AR)
			ELSE NULL
		END AS Margin_AR
	FROM dbo.OSDataTGRS AS P WITH (NOLOCK)
		INNER JOIN #MatchData AS M ON P.MatchId = M.MatchId
		INNER JOIN bodb02.dbo.team AS HomeTeam WITH (NOLOCK) ON M.HomeTeamId = HomeTeam.teamid
		INNER JOIN bodb02.dbo.team AS AwayTeam WITH (NOLOCK) ON M.AwayTeamId = AwayTeam.teamid
		INNER JOIN bodb02.dbo.League AS L WITH (NOLOCK) ON P.LeagueId = L.LeagueId
		LEFT JOIN @LeagueGroups AS lg_filter ON L.LeagueGroupId = lg_filter.LeagueGroupId
		LEFT JOIN @BettypeList bl ON P.BettypeId = bl.BettypeId
	WHERE P.EventDate BETWEEN @FromDate AND @ToDate
		AND P.SportId = 2
		AND P.LeagueId = @LeagueId
		AND (@Bettypes = '0' OR bl.BettypeId IS NOT NULL)
		AND (@LiveType = -1 OR P.IsLive = @LiveType)
		AND (@LeagueGroupIds = '' OR lg_filter.LeagueGroupId IS NOT NULL)
	GROUP BY P.MatchId, HomeTeam.teamname, AwayTeam.teamname, P.EventDate
	ORDER BY P.EventDate DESC, Margin DESC;
			 		
END;

GO
/*<info serverAlias="DBTGRS-bodb_TGRS" executers="wsv_tgrs" isFunction="0" isNested="0"></info>*/