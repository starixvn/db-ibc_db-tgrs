ALTER PROCEDURE [dbo].[TGRS_API_TraderPerformance_Get] 
	@FromDate			DATE,
	@ToDate				DATE, 	
	@TraderIds			VARCHAR(MAX) = '',
	@MajorBettypeIds	VARCHAR(200) = '1,3,7,8'
AS    
/*  
	Created:	20191205@Long.Luu
	Task :		Web API - Trader Performance 
	DB:			DBTGRS.bodb_TGRS
	Original:  
	 
	Revisions:
		- 20191205@Long.Luu: Created [Redmine: #118960]

	Param's Explanation:  	
	
	Example:
*/ 
BEGIN 
	
	SET NOCOUNT ON;  
	 
	DECLARE	@BettypeList	TABLE (
			BetType				SMALLINT
	);

	CREATE TABLE #TraderDetail (
			TraderId			INT
		,	BetType				INT
		,	Turnover			MONEY
		,	WinLoss				MONEY
	);

	IF	OBJECT_ID('tempdb..#tmpTraders') IS NOT NULL
	BEGIN
		DROP TABLE #tmpTraders;
	END;

	CREATE TABLE	#tmpTraders (
			CustId				INT PRIMARY KEY			
	);

	INSERT INTO #tmpTraders (CustId)
	SELECT	t.val
	FROM	dbo.strSplit_Key(@TraderIds, ',') t;

	INSERT INTO @BettypeList (BetType)
	SELECT	b.val
	FROM	dbo.strSplit_Key(@MajorBettypeIds, ',') b;
	
	INSERT INTO	#TraderDetail (
			TraderId
		,	BetType
		,	Turnover
		,	WinLoss
	)
	SELECT	tp.CustId
		,	tp.BetType
		,	ISNULL(SUM(tp.Stake), 0)								AS Turnover
		,	ISNULL(SUM(tp.WinLost), 0) - ISNULL(SUM(tp.Comm), 0)	AS WinLoss					
	FROM	dbo.TraderPerformance AS tp WITH (NOLOCK)
		INNER JOIN #tmpTraders AS t WITH(NOLOCK) ON tp.CustId = t.CustId
	WHERE	tp.EventDate BETWEEN @FromDate AND @ToDate
	GROUP BY	tp.CustId, tp.BetType;

	UPDATE td WITH(UPDLOCK)
	SET td.BetType = 0
	FROM #TraderDetail AS td
		LEFT JOIN @BettypeList AS b ON td.BetType = b.BetType
	WHERE b.BetType IS NULL;

	SELECT	tp.TraderId
		,	tp.BetType
		,	ISNULL(SUM(tp.Turnover), 0)	AS Turnover
		,	ISNULL(SUM(tp.WinLoss), 0)	AS WinLoss					
	FROM	#TraderDetail AS tp WITH (NOLOCK)
	GROUP BY	tp.TraderId, tp.BetType;

	DROP TABLE #TraderDetail;
END;

GO
/*<info serverAlias="DBTGRS-bodb_TGRS" executers="bodbTGRSNet" isFunction="0" isNested="0"></info>*/