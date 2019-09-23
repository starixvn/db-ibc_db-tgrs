ALTER PROCEDURE [dbo].[TGRS_Rpt_SummaryGeneralInfo]  
		@ReportType			TINYINT = 2
	,	@FromDate			DATE
	,	@ToDate				DATE
	,	@ViewPermission		SMALLINT
	,	@IsExcludeLeagues	BIT = 1
	,	@Market				SMALLINT = 1
AS    
/*  
 Created:	20140520@Sophia
 Task :		General Info of Summary report
 DB:		DBTGRS.bodb_TGRS
 Original:  
  
 Revisions:      
		- 20140729@Sophia: Change the way to get MatchCount (from TraderPerformance)
   		- 20171024@Simon: Add ViewPermission param	
		- 20171025@Long: Change the way to get MatchCount
		- 20180912@Simon: add league exclusion
		- 20190116@John: Fix excluding Leagues from report [Redmine ID: #108008]
		- 20190919@John.Ngo:	Support Nonlive Data [Redmine ID: 118959]

 Param's Explanation (filtered by):
		- @Market:	-1 All; 0 Nonlive; 1 Live
		- @ReportType = 1: by Date
			 = 2: By Month
			 = 3: By Year
			 
		- @ViewPermission = 0: all bet types
			 = 1: major bet types
			 = 2: PHAIO bet types
 Exam: 
	EXEC TGRS_Rpt_SummaryGeneralInfo @FromDate = '2014-05-01', @ToDate = '2014-05-20', @ViewPermission = 0
  
*/  
 
BEGIN 
	SET NOCOUNT ON

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

	INSERT INTO #MatchCountByDate(
			EventDate
		,	MatchCount
		,	IsLive
	)
	SELECT tp.EventDate
		,	COUNT_BIG(DISTINCT tp.MatchId) AS MatchCount
		,	tp.IsLive
	FROM dbo.TraderPerformance tp WITH(NOLOCK)
		INNER JOIN dbo.BetType bt WITH(NOLOCK) on tp.BetType = bt.BetType
	WHERE tp.EventDate BETWEEN @FromDate AND @ToDate
		AND (@Market = -1 OR tp.IsLive = @Market)
		AND (
				@ViewPermission = 0
				OR bt.BettypeGroup = @ViewPermission
			)
		AND bt.[Disabled] = 0
		AND (@IsExcludeLeagues = 0 OR (tp.LeagueId NOT IN (SELECT le.LeagueId FROM dbo.LeagueExclusion le WITH(NOLOCK))))
	GROUP BY tp.EventDate, tp.IsLive;
	
	IF @ReportType	= 2  ---by month 
	BEGIN 
		
		SELECT  ISNULL(SUM(S.Stake),0) AS Turnover,  
				ISNULL(SUM(S.WinLost),0) - ISNULL(SUM(S.Comm),0) AS WinLost,  
				CASE WHEN ISNULL(SUM(S.Stake),0) <> 0 THEN (ISNULL(SUM(S.WinLost),0) - ISNULL(SUM(S.Comm),0)) * 100/ISNULL(SUM(S.Stake),0) ELSE NULL END AS Margin, 
				m.MatchCount AS MatchCount,
				S.IsLive
		FROM	dbo.SummaryByLeague_Monthly S WITH (NOLOCK)
		INNER JOIN #MatchCountByDate m ON S.EventDate = m.EventDate AND S.IsLive = m.IsLive
		WHERE	S.EventDate BETWEEN @FromDate AND @ToDate	
				AND (@Market = -1 OR S.IsLive = @Market)
				AND (
						@ViewPermission = 0
						OR BettypeGroup = @ViewPermission
					)
				AND (@IsExcludeLeagues = 0 OR (S.LeagueId NOT IN (SELECT le.LeagueId FROM LeagueExclusion le WITH(NOLOCK))))
		GROUP BY S.IsLive;
				
	END
	ELSE---- by date
	BEGIN 
	
		SELECT  ISNULL(SUM(S.Stake),0) AS Turnover,  
				ISNULL(SUM(S.WinLost),0) - ISNULL(SUM(S.Comm),0) AS WinLost, 
				CASE WHEN ISNULL(SUM(S.Stake),0) <> 0 THEN (ISNULL(SUM(S.WinLost),0) - ISNULL(SUM(S.Comm),0)) * 100/ISNULL(SUM(S.Stake),0) ELSE NULL END AS Margin,
				m.MatchCount AS MatchCount,
				S.IsLive
		FROM	dbo.SummaryByLeague_Daily S WITH (NOLOCK)
		INNER JOIN #MatchCountByDate m ON S.EventDate = m.EventDate	AND S.IsLive = m.IsLive	
		WHERE	S.EventDate BETWEEN @FromDate AND @ToDate
				AND (@Market = -1 OR S.IsLive = @Market)
				AND (
						@ViewPermission = 0
						OR BettypeGroup = @ViewPermission
					)
				AND (@IsExcludeLeagues = 0 OR (S.LeagueId NOT IN (SELECT le.LeagueId FROM LeagueExclusion le WITH(NOLOCK))))
		GROUP BY S.IsLive;
	END
END

GO
/*<info serverAlias="DBTGRS-bodb_TGRS" executers="bodbTGRSNet" isFunction="0" isNested="0"></info>*/