CREATE PROCEDURE [dbo].[TGRS_Basketball_Rpt_PerformanceDetail_Bettype_Trader_Match]  	
		@FromDate			DATE
	,	@ToDate				DATE
	,	@LeagueName			NVARCHAR(500)= ''
	,	@LeagueGroupIds		VARCHAR(2000) = ''
	,	@TraderId			INT
	,	@Bettype			SMALLINT
	,	@LiveType			SMALLINT = 1
AS    
/*  
	Created:	20200918@John.Ngo
	Task :		Basketball Performance Detail - Bettype - Trader - Match
	DB:			DBTGRS.bodb_TGRS
	Original:  
  
	Revisions: 	
   		- 20200918@John.Ngo:	Basketball Performance Detail - Bettype - Trader - Match [Redmine ID: 140875]

	Param's Explanation:  	
		- @LiveType: -1 All; 0 Nonlive; 1 Live	
	
	Example: 
		exec [TGRS_Basketball_Rpt_PerformanceDetail_Bettype_Trader_Match] @Bettype=20,@FromDate='2020-01-01',@ToDate='2020-12-30',@CustId=2438 
*/  
 
BEGIN 
    SET NOCOUNT ON;			   

	-- Initialize date range
	DECLARE @IsGetDataFromOrigin	BIT = 0
		,	@IsGetDataFrom14		BIT = 0
		,	@IsGetDataFromBK		BIT = 0;

	DECLARE @BalanceUpDay			SMALLDATETIME
		,	@MoveBetsDay			SMALLDATETIME;

	IF	OBJECT_ID('tempdb..#tmpDLBUMBData') IS NOT NULL
	BEGIN
		DROP TABLE	#tmpDLBUMBData
	END;

	CREATE TABLE	#tmpDLBUMBData (
			BUDay	SMALLDATETIME
		,	MBDay	SMALLDATETIME
	);
	
	-- Get MB & BU dates
	INSERT INTO #tmpDLBUMBData(BUDay,MBDay)
	EXECUTE bodb02.dbo.Age_SelBalanceUpDay;

	SELECT	TOP(1)
			@BalanceUpDay	= BUDay
		,	@MoveBetsDay	= MBDay
	FROM #tmpDLBUMBData;
	
	-- Compute Date range
	IF @FromDate < @BalanceUpDay
	BEGIN
		SELECT @IsGetDataFromBK = 1
	END
	ELSE IF @FromDate <= @MoveBetsDay
	BEGIN
		SELECT @IsGetDataFrom14 = 1
	END
	ELSE IF @FromDate > @MoveBetsDay
	BEGIN
		SELECT @IsGetDataFromOrigin = 1
	END;

	IF @ToDate < @BalanceUpDay
	BEGIN
		SELECT @IsGetDataFromBK = 1
	END
	ELSE IF @ToDate <= @MoveBetsDay
	BEGIN
		SELECT @IsGetDataFrom14 = 1
	END
	ELSE IF @ToDate > @MoveBetsDay
	BEGIN
		SELECT @IsGetDataFromOrigin = 1
	END;

	IF @FromDate < @BalanceUpDay AND @ToDate > @MoveBetsDay
	BEGIN
		SELECT @IsGetDataFromBK = 1
		SELECT @IsGetDataFrom14 = 1
		SELECT @IsGetDataFromOrigin = 1
	END;
	
	IF	OBJECT_ID('tempdb..#tmpOSDataTGRS') IS NOT NULL
	BEGIN
		DROP TABLE	#tmpOSDataTGRS;
	END;

	CREATE TABLE #tmpOSDataTGRS (
			MatchId				INT
		,	LeagueId			INT
		,	LeagueGroupID		SMALLINT
		,	HomeId				INT
		,	AwayId				INT
		,	EventDate			DATETIME
		,	IsLive				BIT
		,	Turnover			MONEY
		,	WinLoss				MONEY
		,	BetCount			INT
		,	Margin				MONEY
	);
	
	CREATE CLUSTERED INDEX #CIX_tmpOSDataTGRSIdx ON #tmpOSDataTGRS (
			MatchId			ASC
	);

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
			INSERT INTO #tmpOSDataTGRS (MatchId, LeagueId, LeagueGroupID, EventDate, IsLive, Turnover, WinLoss, BetCount, Margin)
			SELECT P.MatchId, P.LeagueId, L.LeagueGroupID, P.EventDate, P.IsLive,
					ISNULL(SUM(P.Turnover), 0) AS Turnover, 
					ISNULL(SUM(P.WinLoss), 0) - ISNULL(SUM(P.Comm), 0) AS WinLoss, 
					ISNULL(SUM(P.BetCount), 0) as BetCount,
					CASE WHEN ISNULL(SUM(P.Turnover), 0) <> 0 THEN (ISNULL(SUM(P.WinLoss), 0)- ISNULL(SUM(P.Comm), 0)) * 100/ISNULL(SUM(P.Turnover), 0) ELSE NULL END AS Margin	
			 FROM	dbo.OSDataTGRS AS P WITH (NOLOCK)
	 			INNER JOIN bodb02.dbo.League AS L WITH (NOLOCK) ON P.LeagueId = L.LeagueId
				LEFT JOIN @LeagueGroups AS lg ON L.LeagueGroupId = lg.LeagueGroupId	 
			 WHERE	P.TraderId = @TraderId
					AND P.BettypeId = @Bettype
					AND P.EventDate BETWEEN @FromDate AND @ToDate
					AND P.SportId = 2
					AND (@LiveType = -1 OR P.IsLive = @LiveType)
					AND (@LeagueGroupIds = '' OR lg.LeagueGroupId IS NOT NULL)
			GROUP BY P.MatchId, P.LeagueId, L.LeagueGroupID, P.EventDate, P.IsLive;
		END;
	ELSE
		BEGIN
			INSERT INTO #tmpOSDataTGRS (MatchId, LeagueId, LeagueGroupID, EventDate, IsLive, Turnover, WinLoss, BetCount, Margin)
			SELECT P.MatchId, P.LeagueId, L.LeagueGroupID, P.EventDate, P.IsLive,
					ISNULL(SUM(P.Turnover), 0) AS Turnover, 
					ISNULL(SUM(P.WinLoss), 0) - ISNULL(SUM(P.Comm), 0) AS WinLoss, 
					ISNULL(SUM(P.BetCount), 0) as BetCount,
					CASE WHEN ISNULL(SUM(P.Turnover), 0) <> 0 THEN (ISNULL(SUM(P.WinLoss), 0)- ISNULL(SUM(P.Comm), 0)) * 100/ISNULL(SUM(P.Turnover), 0) ELSE NULL END AS Margin	
			 FROM	dbo.OSDataTGRS AS P WITH (NOLOCK)
	 			INNER JOIN bodb02.dbo.League AS L WITH (NOLOCK) ON P.LeagueId = L.LeagueId
				LEFT JOIN @LeagueGroups AS lg ON L.LeagueGroupId = lg.LeagueGroupId	 
			 WHERE	P.TraderId = @TraderId
					AND P.BettypeId = @Bettype
					AND P.EventDate BETWEEN @FromDate AND @ToDate
					AND P.SportId = 2
					AND L.LeagueName LIKE '%' + @LeagueName + '%'
					AND (@LiveType = -1 OR P.IsLive = @LiveType)
					AND (@LeagueGroupIds = '' OR lg.LeagueGroupId IS NOT NULL)
			GROUP BY P.MatchId, P.LeagueId, L.LeagueGroupID, P.EventDate, P.IsLive;
		END;

	IF(@IsGetDataFromOrigin = 1)
	BEGIN
		UPDATE t WITH(ROWLOCK, UPDLOCK)
		SET 	t.HomeId = m.homeid
			,	t.AwayId = m.awayid
		FROM #tmpOSDataTGRS AS t
			INNER JOIN bodb02.dbo.match AS m WITH(NOLOCK) ON t.MatchId = m.matchid;
	END;

	IF(@IsGetDataFrom14 = 1)
	BEGIN
		UPDATE t WITH(ROWLOCK, UPDLOCK)
		SET 	t.HomeId = m.homeid
			,	t.AwayId = m.awayid
		FROM #tmpOSDataTGRS AS t
			INNER JOIN bodb02.dbo.match14 AS m WITH(NOLOCK) ON t.MatchId = m.matchid;
	END;

	IF(@IsGetDataFromBK = 1)
	BEGIN
		UPDATE t WITH(ROWLOCK, UPDLOCK)
		SET		t.HomeId = m.homeid
			,	t.AwayId = m.awayid
		FROM #tmpOSDataTGRS AS t
			INNER JOIN bodb_Archive.dbo.match_bk AS m WITH(NOLOCK) ON t.MatchId = m.matchid;
	END;

	SELECT  ostp.MatchId
		,	ostp.LeagueId
		,	ostp.LeagueGroupID		
		,	ostp.HomeId
		,	ostp.AwayId
		,	ostp.EventDate
		,	ostp.IsLive
		,	ostp.Turnover
		,	ostp.WinLoss
		,	ostp.BetCount
		,	ostp.Margin	
	FROM	#tmpOSDataTGRS AS ostp WITH (NOLOCK)
	ORDER BY ostp.Margin DESC, ostp.EventDate ASC;

END;

GO
/*<info serverAlias="DBTGRS-bodb_TGRS" executers="bodbTGRSNet" isFunction="0" isNested="0"></info>*/