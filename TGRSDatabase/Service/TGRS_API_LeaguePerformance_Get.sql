ALTER PROCEDURE [dbo].[TGRS_API_LeaguePerformance_Get] 
		@FromDate		DATE
	,	@ToDate			DATE
	,	@SportName		NVARCHAR(50)	= 'Soccer'
	,	@LeagueName		NVARCHAR(MAX)	= ''
AS    
/*  
	Created:	20240109@John.Ngo
	Task :		Web API - League Performance Get
	DB:			DBTGRS.bodb_TGRS
	Original:  
	 
	Revisions:
		- 20240109@John.Ngo: Created [Redmine: #199020]

	Param's Explanation:
	
	Example: EXEC [dbo].[TGRS_API_LeaguePerformance_Get] @FromDate = '2023-11-01', @ToDate = '2024-01-01',	@SportName = 'Soccer',	@LeagueName = 'ITALY CUP,CLUB FRIENDLY'
*/ 
BEGIN 
	SET NOCOUNT ON;  

	CREATE TABLE #tmpSports	(
			SportId				SMALLINT
		,	SportName			NVARCHAR(50)
	);

	IF	OBJECT_ID('tempdb..#tmpLeagueName') IS NOT NULL
	BEGIN
		DROP TABLE #tmpLeagueName;
	END;

	CREATE TABLE	#tmpLeagueName (
			LeagueId			INT
		,	LeagueName			NVARCHAR(500)
	);

	IF	OBJECT_ID('tempdb..#LeaguePerformance') IS NOT NULL
	BEGIN
		DROP TABLE #LeaguePerformance;
	END;

	CREATE TABLE #LeaguePerformance (
			SportId				SMALLINT
		,	LeagueId			INT
		,	Turnover			MONEY
		,	WinLoss				MONEY
	);

	INSERT INTO #tmpSports (SportName)
	SELECT	s.val
	FROM	dbo.strSplit_Key(@SportName, ',') s;

	INSERT INTO #tmpLeagueName (LeagueName)
	SELECT	l.val
	FROM	dbo.strSplit_Key(@LeagueName, ',') l;

	UPDATE tmps WITH(UPDLOCK)
	SET tmps.SportId = s.SportType
	FROM #tmpSports AS tmps
		INNER JOIN bodb02.dbo.Sports s WITH (NOLOCK) ON tmps.SportName = s.SportName;
	
	UPDATE tmpl WITH(UPDLOCK)
	SET tmpl.LeagueId = L.leagueid
	FROM #tmpLeagueName AS tmpl
		INNER JOIN bodb02.dbo.league l WITH (NOLOCK) ON tmpl.LeagueName = l.LeagueName;
	
	-- Soccer
	IF EXISTS (SELECT TOP 1 (1) FROM #tmpSports AS s WHERE s.SportId = 1)
		BEGIN
			INSERT INTO	#LeaguePerformance (
					SportId
				,	LeagueId
				,	Turnover
				,	WinLoss
			)
			SELECT	tp.SportType
				,	tp.LeagueId
				,	ISNULL(SUM(tp.Stake), 0)								AS Turnover
				,	ISNULL(SUM(tp.WinLost), 0) - ISNULL(SUM(tp.Comm), 0)	AS WinLoss					
			FROM	dbo.TraderPerformance AS tp WITH (NOLOCK)
				INNER JOIN #tmpLeagueName AS l WITH(NOLOCK) ON tp.LeagueId = l.leagueid
			WHERE	tp.EventDate BETWEEN @FromDate AND @ToDate
			GROUP BY tp.SportType
				,	tp.LeagueId
		END;

	-- All Sportbook <> Soccer
	IF EXISTS (SELECT TOP 1 (1) FROM #tmpSports AS s WHERE s.SportId <> 1)
		BEGIN
			INSERT INTO	#LeaguePerformance (
					SportId
				,	LeagueId
				,	Turnover
				,	WinLoss
			)
			SELECT	tp.SportId
				,	tp.LeagueId
				,	ISNULL(SUM(tp.Turnover), 0)								AS Turnover
				,	ISNULL(SUM(tp.WinLoss), 0) - ISNULL(SUM(tp.Comm), 0)	AS WinLoss					
			FROM	dbo.OSDataTGRS AS tp WITH (NOLOCK)
				INNER JOIN #tmpSports AS s ON tp.SportId = s.SportId
				INNER JOIN #tmpLeagueName AS l WITH(NOLOCK) ON tp.LeagueId = l.leagueid
			WHERE	tp.EventDate BETWEEN @FromDate AND @ToDate
			GROUP BY tp.SportId
				,	tp.LeagueId
		END;

	SELECT	s.SportName
		,	l.LeagueName
		,	lp.Turnover
		,	lp.WinLoss					
	FROM	#LeaguePerformance AS lp WITH (NOLOCK)
		INNER JOIN #tmpSports AS s ON lp.SportId = s.SportId
		INNER JOIN #tmpLeagueName AS l WITH(NOLOCK) ON lp.LeagueId = l.leagueid
	ORDER BY lp.SportId ASC, l.LeagueName ASC;

	DROP TABLE #LeaguePerformance;
END;

GO
/*<info serverAlias="DBTGRS-bodb_TGRS" executers="bodbTGRSNet" isFunction="0" isNested="0"></info>*/