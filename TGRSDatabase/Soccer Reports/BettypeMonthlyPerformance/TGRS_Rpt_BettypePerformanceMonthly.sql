ALTER PROCEDURE [dbo].[TGRS_Rpt_BettypePerformanceMonthly] 
		@Year				INT
	,	@BetTypes			NVARCHAR(MAX)
	,	@IsExcludeLeagues	BIT = 0
	,	@Market				SMALLINT = 1
AS
/*
	Created: 20180719@CaseyHuynh
	Task : TGRS_Rpt_BettypePerformanceMonthly is used to display Monthly Perfromance by Bettype
	DB: bodb_FraudSensor
	Original:

	Revisions:
		- 20180911@Long:		Support excluding Leagues from report [Redmine ID: #100322]
		- 20190919@John.Ngo:	Support Nonlive Data [Redmine ID: 118959]

	Param's Explanation (filtered by):
		- @Market:	-1 All; 0 Nonlive; 1 Live
*/
BEGIN
	SET NOCOUNT ON;	
	
	---===========1. DECLARE AND INITIAL===========================
	--=============================================================
	-- 1. Table Bettype
	IF  OBJECT_ID('tempdb..#tmpBettype')  IS NOT NULL
	BEGIN
		DROP TABLE	#tmpBettype;
	END;
		
	CREATE TABLE #tmpBettype (
		BetType	SMALLINT
		, BetTypeName	NVARCHAR(100)
	 );
		
	-- 2. Table Bettype Performance: TurnOver, Winloss, BetCount
	IF  OBJECT_ID('tempdb..#tmpBettypePerformance')  IS NOT NULL
	BEGIN
		DROP TABLE	#tmpBettypePerformance;
	END;
		
	CREATE TABLE #tmpBettypePerformance (
		BetType		SMALLINT
		, BetTypeName	NVARCHAR(100)
		, MonthNo	TINYINT
		, TurnOver	MONEY
		, Winloss	MONEY
		, BetCount	INT
		, MatchCount INT
		, IsLive BIT
	 );

	---===========2. PROCESS DATA==================================
	--=============================================================
	--1: GET BetType
	INSERT INTO #tmpBettype(BetType)
	SELECT CAST(VAL AS INT)  AS BetType
	FROM dbo.strSplit_Key(@BetTypes,',');
	
	UPDATE	tbt
	SET		tbt.BetTypeName = bt.TypeName
	FROM	#tmpBettype AS tbt WITH (ROWLOCK)
			INNER JOIN dbo.BetType AS bt WITH (NOLOCK) ON tbt.BetType = bt.BetType;

	--2: GET BettypePerformance
	INSERT INTO #tmpBettypePerformance(BetType, BetTypeName, MonthNo, TurnOver, Winloss, BetCount, MatchCount, IsLive)
	SELECT	sbt.BetType
			, bt.BetTypeName
			, MONTH(sbt.eventDate) AS MonthNo
			, SUM(sbt.Stake) AS TurnOver
			, SUM(sbt.WinLost) - SUM(sbt.Comm) AS WinLoss
			, SUM(sbt.BetCount) AS BetCount
			, SUM(sbt.MatchCount) AS MatchCount
			, sbt.IsLive
	FROM	dbo.SummaryByBetType_Daily AS sbt	WITH (NOLOCK)
			INNER JOIN #tmpBettype AS bt WITH (NOLOCK) ON sbt.BetType = bt.BetType
	WHERE	YEAR(sbt.EventDate) = @Year
		AND (@Market = -1 OR sbt.IsLive = @Market)
		AND (@IsExcludeLeagues = 0 OR (sbt.LeagueId NOT IN (SELECT le.LeagueId FROM dbo.LeagueExclusion le WITH(NOLOCK))))
	GROUP BY 	sbt.BetType, bt.BetTypeName, MONTH(sbt.eventDate), sbt.IsLive;
	
	---===========3. RETURN DATA===================================
	--=============================================================
	
	--1: RETURN BetType Performance Monthly
	SELECT	bp.BetType
			, bp.BetTypeName
			, bp.MonthNo
			, bp.TurnOver
			, bp.Winloss
			, bp.BetCount
			, bp.MatchCount
			, bp.IsLive
	FROM	#tmpBettypePerformance AS bp WITH (NOLOCK)
	ORDER BY MonthNo, BetType, bp.BetTypeName, bp.IsLive;
	
	--2: RETURN BetType Performance - 1st Half Year
	SELECT	bp.BetType
			, bp.BetTypeName
			, SUM(bp.TurnOver) AS TurnOver
			, SUM(bp.Winloss) AS Winloss
			, SUM(bp.BetCount) AS BetCount
			, SUM(bp.MatchCount) AS MatchCount
			, bp.IsLive
	FROM	#tmpBettypePerformance AS bp WITH (NOLOCK)
	WHERE	bp.MonthNo BETWEEN 1 AND 6
	GROUP BY	bp.BetType, bp.BetTypeName, bp.IsLive
	ORDER BY	bp.BetType;
	
	--3: RETURN BetType Performance - 2nd Half Year
	SELECT	bp.BetType
			, bp.BetTypeName
			, SUM(bp.TurnOver) AS TurnOver
			, SUM(bp.Winloss) AS Winloss
			, SUM(bp.BetCount) AS BetCount
			, SUM(bp.MatchCount) AS MatchCount
			, bp.IsLive
	FROM	#tmpBettypePerformance AS bp WITH (NOLOCK)
	WHERE	bp.MonthNo BETWEEN 7 AND 12
	GROUP BY	bp.BetType, bp.BetTypeName, bp.IsLive
	ORDER BY	bp.BetType;
	
	--4: RETURN BetType Performance - Full Year
	SELECT	bp.BetType
			, bp.BetTypeName
			, SUM(bp.TurnOver) AS TurnOver
			, SUM(bp.Winloss) AS Winloss
			, SUM(bp.BetCount) AS BetCount
			, SUM(bp.MatchCount) AS MatchCount
			, bp.IsLive
	FROM	#tmpBettypePerformance AS bp WITH (NOLOCK)
	GROUP BY	bp.BetType, bp.BetTypeName, bp.IsLive
	ORDER BY	bp.BetType;
	
END;

GO
/*<info serverAlias="DBTGRS-bodb_TGRS" executers="bodbTGRSNet" isFunction="0" isNested="0"></info>*/