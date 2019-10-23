ALTER PROCEDURE [dbo].[TGRS_Rpt_SummaryGeneralInfo_Detail]  
			@ReportType			TINYINT = 2
		,	@FromDate			DATE
		,	@ToDate				DATE
		,	@ViewPermission		SMALLINT
		,	@IsExcludeLeagues	BIT = 1
		,	@Market				SMALLINT = 1
AS    
/*  
 Created:	20141211@Sophia
 Task :		General Info of Summary report detail by Month/ Date
 DB:		DBTGRS/bodb_TGRS
 Original:  
  
 Revisions:      
		- 20171024@Simon: Add ViewPermission param 
		- 20171025@Long: change the way to get MatchCount
		- 20180912@Simon: add league exclusion
		- 20190116@John: Fix excluding Leagues from report [Redmine ID: #108008]
		- 20190919@John.Ngo:	Support Nonlive Data [Redmine ID: 118959]
		- 20191023@John.Ngo:	Enhance performance [Redmine ID: 121268]

 Param's Explanation (filtered by):
		- @Market:	-1 All; 0 Nonlive; 1 Live
		- @ReportType = 1: by Date
			 = 2: By Month
			 = 3: By Year
			 
		- @ViewPermission = 0: all bet types
			 = 1: major bet types
			 = 2: PHAIO bet types

 Exam: 
	EXEC TGRS_Rpt_SummaryGeneralInfo_Detail @FromDate = '2014-05-01', @ToDate = '2014-12-01',  @ReportType = 2
*/  
 
BEGIN 
	SET NOCOUNT ON  

	DECLARE @Today DATE = GETDATE ()
		,	@StartDate				DATE
		,	@EndDate				DATE
		,	@Month					DATE
		,	@WinlostDate			DATE;

	IF	OBJECT_ID('tempdb..#MatchCountByDate') IS NOT NULL
	BEGIN;
		DROP TABLE #MatchCountByDate;
	END;

	CREATE TABLE #MatchCountByDate (
		EventDate		DATE, 
		MatchCount		BIGINT,
		IsLive			BIT
	);
	
	CREATE CLUSTERED INDEX	#CIX_MatchCountByDateIdx ON #MatchCountByDate (
								EventDate	ASC,
								IsLive		ASC
							);
	IF	OBJECT_ID('tempdb..#MatchCountByMonth') IS NOT NULL
	BEGIN;
		DROP TABLE #MatchCountByMonth;
	END;

	CREATE TABLE #MatchCountByMonth (
		EventDate		DATE, 
		MatchCount		BIGINT,
		IsLive			BIT
	);
	
	CREATE CLUSTERED INDEX	#CIX_MatchCountByMonthIdx ON #MatchCountByMonth (
								EventDate	ASC,
								IsLive		ASC
							);

	IF @ReportType = 2
	BEGIN 
		IF	OBJECT_ID('tempdb..#tmpWinlostDate') IS NOT NULL
		BEGIN;
			DROP TABLE	#tmpWinlostDate;
		END;

		CREATE TABLE	#tmpWinlostDate (
			winlostdate			DATE
		);

		INSERT INTO	#tmpWinlostDate (winlostdate)
		SELECT	tally.EventDate
		FROM	(
			SELECT	[NoMonths] = DATEDIFF(MONTH, @FromDate, @ToDate) + 1
		) cnt
		CROSS APPLY	(
			SELECT	TOP(cnt.NoMonths)
					[EventDate] = DATEADD(MONTH, ROW_NUMBER() OVER(ORDER BY (SELECT NULL)) - 1, @FromDate)
			FROM		(VALUES (0), (0), (0), (0), (0), (0), (0), (0), (0), (0)) x10(n)
			CROSS APPLY	(VALUES (0), (0), (0), (0), (0), (0), (0), (0), (0), (0)) x100(n)
			CROSS APPLY	(VALUES (0), (0), (0), (0), (0), (0), (0), (0), (0), (0)) x1000(n)
		) tally;
		
		WHILE	EXISTS (SELECT 1 FROM #tmpWinlostDate)
		BEGIN;
			SELECT	TOP(1)
					@WinLostDate = d.winlostdate
			FROM	#tmpWinlostDate AS d;

			SELECT @StartDate = DATEADD(DD, -DAY(@WinLostDate) + 1, @WinLostDate);
			SELECT @EndDate = DATEADD(DD, -1 , DATEADD(MM, 1, @StartDate));
			SELECT @Month = @StartDate;	
		
			TRUNCATE TABLE #MatchCountByDate;
			INSERT INTO #MatchCountByDate(
					EventDate
				,	MatchCount
				,	IsLive )
			SELECT  tp.EventDate
				,	COUNT_BIG(DISTINCT tp.MatchId) AS MatchCount
				,	tp.IsLive
			FROM dbo.TraderPerformance tp WITH(NOLOCK)
				INNER JOIN dbo.BetType b WITH(NOLOCK) ON tp.BetType = b.BetType
				LEFT JOIN dbo.LeagueExclusion le WITH(NOLOCK) ON tp.LeagueId = le.LeagueId
			WHERE tp.EventDate BETWEEN @FromDate AND @ToDate
				AND (@Market = -1 OR tp.IsLive = @Market)
				AND (@ViewPermission = 0 OR b.BettypeGroup = @ViewPermission)
				AND (@IsExcludeLeagues = 0 OR le.LeagueId IS NULL)
			GROUP BY tp.EventDate, tp.IsLive;
			
			INSERT INTO #MatchCountByMonth(
					EventDate
				,	MatchCount
				,	IsLive )
			SELECT  @Month AS EventDate
				,	SUM(mc.MatchCount) AS MatchCount
				,	mc.IsLive
			FROM #MatchCountByDate mc WITH(NOLOCK)
			WHERE mc.EventDate BETWEEN @StartDate AND @EndDate
			GROUP BY mc.IsLive;
			
			DELETE	d
			FROM	#tmpWinlostDate AS d
			WHERE	d.winlostdate = @WinlostDate;
		END;

		SELECT  S.EventDate,
				ISNULL(SUM(S.Stake),0) AS Turnover,  
				ISNULL(SUM(S.WinLost),0) - ISNULL(SUM(S.Comm),0) AS WinLost,  
				CASE WHEN ISNULL(SUM(S.Stake),0) <> 0 THEN (ISNULL(SUM(S.WinLost),0) - ISNULL(SUM(S.Comm),0)) * 100/ISNULL(SUM(S.Stake),0) ELSE NULL END AS Margin, 
				m.MatchCount AS MatchCount,
				S.IsLive
		FROM	dbo.SummaryByLeague_Monthly S WITH (NOLOCK)	
			INNER JOIN #MatchCountByMonth m ON S.IsLive = m.IsLive AND m.EventDate = S.EventDate
			LEFT JOIN dbo.LeagueExclusion le WITH(NOLOCK) ON S.LeagueId = le.LeagueId
		WHERE S.EventDate BETWEEN @FromDate AND @ToDate
			AND (@Market = -1 OR S.IsLive = @Market)	
			AND (@ViewPermission = 0 OR BettypeGroup = @ViewPermission)
			AND (@IsExcludeLeagues = 0 OR le.LeagueId IS NULL)
		GROUP BY S.EventDate, m.MatchCount, S.IsLive;
	END	
	ELSE 
	BEGIN
		TRUNCATE TABLE #MatchCountByDate;
		INSERT INTO #MatchCountByDate(
				EventDate
			,	MatchCount
			,	IsLive )
		SELECT  tp.EventDate
			,	COUNT_BIG(DISTINCT tp.MatchId) AS MatchCount
			,	tp.IsLive
		FROM dbo.TraderPerformance tp WITH(NOLOCK)
			INNER JOIN dbo.BetType b WITH(NOLOCK) ON tp.BetType = b.BetType
			LEFT JOIN dbo.LeagueExclusion le WITH(NOLOCK) ON tp.LeagueId = le.LeagueId
		WHERE tp.EventDate BETWEEN @FromDate AND @ToDate
			AND (@Market = -1 OR tp.IsLive = @Market)
			AND (@ViewPermission = 0 OR b.BettypeGroup = @ViewPermission)
			AND (@IsExcludeLeagues = 0 OR le.LeagueId IS NULL)
		GROUP BY tp.EventDate, tp.IsLive;

		SELECT  m.EventDate,
				ISNULL(SUM(S.Stake),0) AS Turnover,  
				ISNULL(SUM(S.WinLost),0) - ISNULL(SUM(S.Comm),0) AS WinLost,  
				CASE WHEN ISNULL(SUM(S.Stake),0) <> 0 THEN (ISNULL(SUM(S.WinLost),0) - ISNULL(SUM(S.Comm),0)) * 100/ISNULL(SUM(S.Stake),0) ELSE NULL END AS Margin, 
				m.MatchCount AS MatchCount,
				S.IsLive
		FROM	dbo.SummaryByLeague_Daily S WITH (NOLOCK)	
			INNER JOIN #MatchCountByDate m ON S.IsLive = m.IsLive AND m.EventDate = S.EventDate
			LEFT JOIN dbo.LeagueExclusion le WITH(NOLOCK) ON S.LeagueId = le.LeagueId
		WHERE S.EventDate BETWEEN @FromDate AND @ToDate	
			AND (@Market = -1 OR S.IsLive = @Market)
			AND (@ViewPermission = 0 OR BettypeGroup = @ViewPermission)
			AND (@IsExcludeLeagues = 0 OR le.LeagueId IS NULL)
		GROUP BY m.EventDate,m.MatchCount, S.IsLive;
	END

END 

GO
/*<info serverAlias="DBTGRS-bodb_TGRS" executers="bodbTGRSNet" isFunction="0" isNested="0"></info>*/