USE [bodb_TGRS]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[TGRS_Rpt_BettypePerformanceMonthly] 
	@Year	INT
	,@BetTypes NVARCHAR(MAX)
AS
/*
	Created: 20180719@CaseyHuynh
	Task : TGRS_Rpt_BettypePerformanceMonthly is used to display Monthly Perfromance by Bettype
	DB: bodb_FraudSensor
	Original:

	Revisions:

	Param's Explanation (filtered by):
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
		TypeID	SMALLINT
	 );
		
	-- 2. Table Bettype Performance: TurnOver, Winloss, BetCount, Margin
	IF  OBJECT_ID('tempdb..#tmpBettypePerformance')  IS NOT NULL
	BEGIN
		DROP TABLE	#tmpBettypePerformance;
	END;
		
	CREATE TABLE #tmpBettypePerformance (
		BetType		SMALLINT
		, MonthNo	TINYINT
		, TurnOver	MONEY
		, Winloss	MONEY
		, BetCount	INT
	 );
	
	-- 3. GET Monthly: MatchCount
	IF  OBJECT_ID('tempdb..#tmpBettypeMatchCount')  IS NOT NULL
	BEGIN
		DROP TABLE	#tmpBettypeMatchCount;
	END;
		
	CREATE TABLE #tmpBettypeMatchCount (
		BetType			SMALLINT
		, MonthNo		TINYINT
		, MatchCount	INT
	 );
	---===========2. PROCESS DATA==================================
	--=============================================================
	--1: GET BetType
	INSERT INTO #tmpBettype(TypeID)
	SELECT CAST(VAL AS INT)  AS TypeID
	FROM dbo.strSplit_Key(@BetTypes,',');
	
	--2: GET BettypePerformance
	INSERT INTO #tmpBettypePerformance(BetType, MonthNo, TurnOver, Winloss, BetCount)
	SELECT	tp.BetType
			, MONTH(tp.eventDate) AS MonthNo
			, SUM(tp.TurnOver) AS TurnOver
			, SUM(tp.WinLoss) AS WinLoss
			, SUM(tp.BetCount) AS BetCount
	FROM	TraderPerformance_Monthly AS tp	WITH (NOLOCK)
			INNER JOIN #tmpBettype AS bt WITH (NOLOCK) ON tp.BetType = bt.TypeID
	WHERE	YEAR(tp.EventDate) = @Year
	GROUP BY 	tp.BetType, MONTH(tp.eventDate)	
	
	--3: GET BettypeMatchCount
	INSERT INTO #tmpBettypeMatchCount(BetType, MonthNo,MatchCount)
	SELECT	tm.BetType
			, MONTH(tm.eventDate) AS MonthNo
			, SUM(tm.MatchCount) AS MatchCount
	FROM	TraderMatchCount_Monthly AS tm	WITH (NOLOCK)
			INNER JOIN #tmpBettype AS bt WITH (NOLOCK) ON tm.BetType = bt.TypeID
	WHERE	YEAR(tm.EventDate) = @Year
			AND tm.IsLive = -1
	GROUP BY 	tm.BetType, MONTH(tm.eventDate)	
	
	---===========3. RETURN DATA===================================
	--=============================================================
	
	--1: RETURN BetType Performance Monthly
	SELECT	bp.BetType
			, bp.MonthNo
			, TurnOver
			, Winloss
			, BetCount
			, bm.MatchCount
	FROM	#tmpBettypePerformance AS bp WITH (NOLOCK)
			INNER JOIN #tmpBettypeMatchCount AS bm WITH(NOLOCK) ON  bp.MonthNo = bm.MonthNo AND bp.BetType = bm.BetType
	ORDER BY MonthNo, BetType	
	
	--2: RETURN BetType Performance - 1st Half Year
	SELECT	bp.BetType
			, SUM(TurnOver) AS TurnOver
			, SUM(Winloss) AS Winloss
			, SUM(BetCount) AS BetCount
			, SUM(bm.MatchCount) AS MatchCount
	FROM	#tmpBettypePerformance AS bp WITH (NOLOCK)
			INNER JOIN #tmpBettypeMatchCount AS bm WITH(NOLOCK) ON  bp.MonthNo = bm.MonthNo AND bp.BetType = bm.BetType
	WHERE	bp.MonthNo BETWEEN 1 AND 6
	GROUP BY	bp.BetType
	ORDER BY	bp.BetType
	
	--3: RETURN BetType Performance - 2nd Half Year
	SELECT	bp.BetType
			, SUM(TurnOver) AS TurnOver
			, SUM(Winloss) AS Winloss
			, SUM(BetCount) AS BetCount
			, SUM(bm.MatchCount) AS MatchCount
	FROM	#tmpBettypePerformance AS bp WITH (NOLOCK)
			INNER JOIN #tmpBettypeMatchCount AS bm WITH(NOLOCK) ON  bp.MonthNo = bm.MonthNo AND bp.BetType = bm.BetType
	WHERE	bp.MonthNo BETWEEN 7 AND 12
	GROUP BY	bp.BetType
	ORDER BY	bp.BetType	
	
	--4: RETURN BetType Performance - Full Year
	SELECT	bp.BetType
			, SUM(TurnOver) AS TurnOver
			, SUM(Winloss) AS Winloss
			, SUM(BetCount) AS BetCount
			, SUM(bm.MatchCount) AS MatchCount
	FROM	#tmpBettypePerformance AS bp WITH (NOLOCK)
			INNER JOIN #tmpBettypeMatchCount AS bm WITH(NOLOCK) ON  bp.MonthNo = bm.MonthNo AND bp.BetType = bm.BetType
	GROUP BY	bp.BetType
	ORDER BY	bp.BetType
	
END;

GO
GRANT EXECUTE ON [dbo].[TGRS_Rpt_BettypePerformanceMonthly] TO [bodbTGRSNet]
GO
GRANT VIEW DEFINITION ON [dbo].[TGRS_Rpt_BettypePerformanceMonthly] TO [bodbTGRSNet]
GO