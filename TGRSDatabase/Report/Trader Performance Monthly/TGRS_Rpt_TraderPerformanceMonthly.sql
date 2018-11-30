SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

ALTER PROCEDURE [dbo].[TGRS_Rpt_TraderPerformanceMonthly]  	
	@Bettype			INT = -1,
	@TraderName			VARCHAR(30) = '',
	@LeagueName			VARCHAR(500) = '',
	@LiveStatus			INT = 1,
	@Year				INT = 2018,
	@Shift				INT = -1,
	@Grade				INT = -1,
	@IsExcludeLeagues	BIT = 1
AS    
/*  
	Created:	20171129@Long.Luu
	Task :		Trader Performance Monthly report
	DB:			DBTGRS.bodb_TGRS
	Original:  
 
	Revisions:      	
			- 20171129@LongLuu: Create New
			- 20180226@Aaron: #90868 - improve UX and support more data
			- 20180912@Simon: add league exclusion
			- 20181114@Long: fix issue of summing data [Redmine ID: #104753]
			- 20181129@Long: support filter by league [Redmine ID: #105513]
 
	Param's Explanation:  	
			- @Bettype: -1 all bettype, x specific bettype
			- @LiveStatus: -1 all status, 1 live, 0 non-live
	Exam: 
	  		EXEC  TGRS_Rpt_TraderPerformanceMonthly @Bettype = -1, @TraderName = '', @LiveStatus = -1, @Year = 2018 , @Shift = -1,
	@Grade = -1
  
*/  
 
BEGIN 
	SET NOCOUNT ON;

	DECLARE @CurrentYear			INT = @Year;
	DECLARE @LastYear				INT = @CurrentYear - 1;
	DECLARE @FirstHalfFromDate		DATE = CAST(CAST(@CurrentYear AS VARCHAR) + '-01-01' AS DATE);
	DECLARE @FirstHalfToDate		DATE = CAST(CAST(@CurrentYear AS VARCHAR) + '-06-30' AS DATE);
	DECLARE @SecondHalfFromDate		DATE = CAST(CAST(@CurrentYear AS VARCHAR) + '-07-01' AS DATE);
	DECLARE @SecondHalfToDate		DATE = CAST(CAST(@CurrentYear AS VARCHAR) + '-12-31' AS DATE);
	
	IF	OBJECT_ID('tempdb..#tmpTrader') IS NOT NULL
	BEGIN;
		DROP TABLE #tmpTrader;
	END;

	CREATE TABLE	#tmpTrader (
			TraderID		INT
		,	TraderName		VARCHAR(30)
		,	Product			VARCHAR(100)
		,	Grade			TINYINT
		,	TeamName		NVARCHAR(50)
		,	ShiftName		NVARCHAR(50)
		,	Remark			NVARCHAR(2000)
	);

	CREATE CLUSTERED INDEX	#CIX_tmpTraderIdx ON #tmpTrader (
			TraderID		ASC
		,	TraderName		ASC
	);

	IF	OBJECT_ID('tempdb..#tmpTraderProduct') IS NOT NULL
	BEGIN;
		DROP TABLE #tmpTraderProduct;
	END;

	CREATE TABLE	#tmpTraderProduct (
			TraderID		INT
		,	Product			VARCHAR(100)
	);

	CREATE CLUSTERED INDEX	#CIX_tmpTraderProductIdx ON #tmpTraderProduct (
			TraderID		ASC
	);

	IF	OBJECT_ID('tempdb..#tmpLeagues') IS NOT NULL
	BEGIN;
		DROP TABLE #tmpLeagues;
	END;

	CREATE TABLE	#tmpLeagues (
			LeagueID		INT PRIMARY KEY
	);

	IF	OBJECT_ID('tempdb..#tmpTraderBettypes') IS NOT NULL
	BEGIN;
		DROP TABLE #tmpTraderBettypes;
	END;

	CREATE TABLE	#tmpTraderBettypes (
			CustId		INT
		,	BetType		INT
	);

	CREATE CLUSTERED INDEX	#CIX_tmpTraderBettypesIdx ON #tmpTraderBettypes (
			CustId		ASC
		,	BetType		ASC
	);

	-- START
	-- Get the leagues
	SELECT @LeagueName = ISNULL(@LeagueName, '');
	IF (@LeagueName <> '')
	BEGIN
		INSERT INTO #tmpLeagues(LeagueID)
		SELECT l.leagueid
		FROM bodb02.dbo.League l WITH(NOLOCK)
		WHERE l.leaguename = @LeagueName;
	END;

	-- Get the traders
	INSERT INTO #tmpTrader(
			TraderID
		,	TraderName
		,	Grade
		,	TeamName
		,	ShiftName
		,	Remark
	)
	SELECT t.CustId
		,	t.Username
		,	t.Grade
		,	tm.TeamName
		,	s.ShiftName
		,	t.Remark
	FROM dbo.Trader t WITH(NOLOCK)
		INNER JOIN Team tm WITH(NOLOCK) ON t.TeamId = tm.TeamId
		INNER JOIN [Shift] s WITH(NOLOCK) ON t.[Shift] = s.ShiftId
	WHERE t.[Shift] IS NOT NULL
		AND	(ISNULL(@TraderName, '') = '' OR t.Username LIKE '%' + @TraderName + '%')
		AND (ISNULL(@Shift, -1) = -1 OR t.Shift = @Shift)
		AND (ISNULL(@Grade, -1) = -1 OR t.Grade = @Grade)
			
	INSERT INTO #tmpTraderBettypes(CustId, BetType)
	SELECT DISTINCT custid, bettype
	FROM dbo.TraderPerformance_Yearly p1 WITH(NOLOCK)
	WHERE (@IsExcludeLeagues = 0 
		OR (p1.LeagueId NOT IN (SELECT le.LeagueId FROM dbo.LeagueExclusion le WITH(NOLOCK) WHERE le.LeagueId = p1.LeagueId)))
		AND (@LeagueName = '' OR (p1.LeagueId IN (SELECT le.LeagueId FROM #tmpLeagues le WITH(NOLOCK))));

	INSERT INTO #tmpTraderProduct(
			TraderID
		,	Product
	)
	SELECT  t.CustId
       ,STUFF((SELECT ', ' + CAST(t1.bettype AS VARCHAR(10)) [text()]
         FROM #tmpTraderBettypes AS t1 WITH(NOLOCK)
         WHERE t1.custid = t.custid
         FOR XML PATH(''), TYPE)
        .value('.','NVARCHAR(MAX)'),1,2,' ') AS Products
	FROM #tmpTraderBettypes AS t WITH(NOLOCK)
	GROUP BY t.CustId;

	UPDATE #tmpTrader
	SET Product = ttp.Product
	FROM #tmpTraderProduct ttp
	INNER JOIN #tmpTrader tt ON ttp.TraderID = tt.TraderID;

	-- Get Trader's info
	SELECT	TraderID
		,	TraderName
		,	Product
		,	Grade
		,	TeamName
		,	ShiftName
		,	Remark
	FROM #tmpTrader
	WHERE Product IS NOT NULL;

	-- Sum for current year first-half
	SELECT	tpm.CustId AS TraderID
		,	SUM(tpm.Turnover) AS Turnover
		,	SUM(tpm.WinLoss - tpm.Comm) AS WinLoss
		,	SUM(tpm.BetCount) AS BetCount
		,	SUM(tmc.MatchCount) AS MatchCount
	FROM dbo.TraderPerformance_Monthly tpm WITH (NOLOCK)
		INNER JOIN #tmpTrader t ON tpm.CustId = t.TraderId
		INNER JOIN dbo.TraderMatchCount_Monthly tmc WITH (NOLOCK) ON tpm.CustId = tmc.CustId  AND tpm.EventDate = tmc.EventDate 
			 AND tpm.LeagueId = tmc.LeagueId AND tpm.SportType = tmc.SportType
			 AND tmc.BetType = tpm.BetType AND tmc.IsLive = tpm.IsLive
    WHERE tpm.EventDate BETWEEN @FirstHalfFromDate AND @FirstHalfToDate
		AND tpm.BetType = @Bettype AND tpm.IsLive = @LiveStatus
		AND (@IsExcludeLeagues = 0 OR (tpm.LeagueId NOT IN (SELECT le.LeagueId FROM dbo.LeagueExclusion le WITH(NOLOCK)))) 
		AND (@LeagueName = '' OR (tpm.LeagueId IN (SELECT le.LeagueId FROM #tmpLeagues le WITH(NOLOCK))))
	GROUP BY tpm.CustId;

	-- Sum for current year second-half
	SELECT	tpm.CustId AS TraderID
		,	SUM(tpm.Turnover) AS Turnover
		,	SUM(tpm.WinLoss - tpm.Comm) AS WinLoss
		,	SUM(tpm.BetCount) AS BetCount
		,	SUM(tmc.MatchCount) AS MatchCount
	FROM dbo.TraderPerformance_Monthly tpm WITH (NOLOCK)
		INNER JOIN #tmpTrader t ON tpm.CustId = t.TraderId
		INNER JOIN dbo.TraderMatchCount_Monthly tmc WITH (NOLOCK) ON tpm.CustId = tmc.CustId  AND tpm.EventDate = tmc.EventDate 
			 AND tpm.LeagueId = tmc.LeagueId AND tpm.SportType = tmc.SportType
			 AND tmc.BetType = tpm.BetType AND tmc.IsLive = tpm.IsLive
    WHERE tpm.EventDate BETWEEN @SecondHalfFromDate AND @SecondHalfToDate
		AND tpm.BetType = @Bettype AND tpm.IsLive = @LiveStatus
		AND (@IsExcludeLeagues = 0 OR (tpm.LeagueId NOT IN (SELECT le.LeagueId FROM dbo.LeagueExclusion le WITH(NOLOCK))))
		AND (@LeagueName = '' OR (tpm.LeagueId IN (SELECT le.LeagueId FROM #tmpLeagues le WITH(NOLOCK)))) 
	GROUP BY tpm.CustId;

	-- Sum for current & last year
	SELECT	tpm.CustId AS TraderID
		,	tpm.[Year]
		,	SUM(tpm.Turnover) AS Turnover
		,	SUM(tpm.WinLoss - tpm.Comm) AS WinLoss
		,	SUM(tpm.BetCount) AS BetCount
		,	SUM(tmc.MatchCount) AS MatchCount
	FROM dbo.TraderPerformance_Yearly tpm WITH (NOLOCK)	
		INNER JOIN #tmpTrader t ON tpm.CustId = t.TraderId
		INNER JOIN dbo.TraderMatchCount_Yearly tmc WITH (NOLOCK) ON tpm.CustId = tmc.CustId  AND tpm.Year = tmc.Year 
			 AND tpm.LeagueId = tmc.LeagueId AND tpm.SportType = tmc.SportType
			 AND tmc.BetType = tpm.BetType AND tmc.IsLive = tpm.IsLive
	WHERE tpm.[Year] IN (@CurrentYear, @LastYear)
		AND tmc.BetType = @Bettype
		AND tmc.IsLive = @LiveStatus
		AND (@IsExcludeLeagues = 0 OR (tmc.LeagueId NOT IN (SELECT le.LeagueId FROM dbo.LeagueExclusion le WITH(NOLOCK) WHERE le.LeagueId = tmc.LeagueId)))		
		AND (@LeagueName = '' OR (tpm.LeagueId IN (SELECT le.LeagueId FROM #tmpLeagues le WITH(NOLOCK)))) 
	GROUP BY tpm.CustId, tpm.Year;

	-- Sum for each month of current year
	SELECT	tpm.CustId AS TraderID
		,	DATEPART(MONTH ,tpm.EventDate) AS [Month]
		,	SUM(tpm.Turnover) AS Turnover
		,	SUM(tpm.WinLoss - tpm.Comm) AS WinLoss
		,	SUM(tpm.BetCount) AS BetCount
		,	SUM(tmc.MatchCount) AS MatchCount
	FROM dbo.TraderPerformance_Monthly tpm WITH (NOLOCK)	
		INNER JOIN #tmpTrader t ON tpm.CustId = t.TraderId
		INNER JOIN dbo.TraderMatchCount_Monthly tmc WITH (NOLOCK) ON tpm.CustId = tmc.CustId  AND tpm.EventDate = tmc.EventDate 
			 AND tpm.LeagueId = tmc.LeagueId AND tpm.SportType = tmc.SportType
			 AND tmc.BetType = tpm.BetType AND tmc.IsLive = tpm.IsLive
	WHERE tpm.EventDate BETWEEN @FirstHalfFromDate AND @SecondHalfToDate
		AND tmc.BetType = @Bettype
		AND tmc.IsLive = @LiveStatus
		AND (@IsExcludeLeagues = 0 OR (tmc.LeagueId NOT IN (SELECT le.LeagueId FROM dbo.LeagueExclusion le WITH(NOLOCK) WHERE le.LeagueId = tmc.LeagueId)))
		AND (@LeagueName = '' OR (tpm.LeagueId IN (SELECT le.LeagueId FROM #tmpLeagues le WITH(NOLOCK)))) 
	GROUP BY tpm.CustId, tpm.EventDate;
END;

GO
/*<info serverAlias="DBTGRS-bodb_TGRS" executers="bodbTGRSNet" isFunction="0" isNested="0"></info>*/