CREATE PROCEDURE  [dbo].[Task_OS_Market_StagingData]
		@Debug					BIT = 0
	,	@GenerateFromDate		SMALLDATETIME = NULL
	,	@GenerateToDate			SMALLDATETIME = NULL
AS
/*
	Created:	20201124@John.Ngo
	Task :		Staging Data for OSSummaryMarket
	DB:			DBTGRS.bodb_TGRS
	Original:
  
	Revisions:
		- 20201202@John.Ngo: Support Summary Data for OSSummaryMarket [Redmine ID: 145990]
	
	Param's Explanation:
	Exam:
	 
*/
BEGIN
	SET NOCOUNT ON;

	-- Common variables
	DECLARE	@Begin					DATETIME = GETDATE()
		,	@RowCount				INT
		,	@Duration				INT
		,	@Msg					NVARCHAR(MAX)
		,	@Date					NVARCHAR(250)

	DECLARE @BalanceUpDay			SMALLDATETIME
		,	@MoveBetsDay			SMALLDATETIME
		,	@Yesterday				SMALLDATETIME
		,	@Today					SMALLDATETIME
		,	@Winlostdate			DATETIME;

	DECLARE	@IsRunningJob			BIT;
	
	IF (@GenerateFromDate IS NULL OR @GenerateToDate IS NULL)
	BEGIN
		SELECT @IsRunningJob = 1;
	END;

	IF	OBJECT_ID('tempdb..#tmpDLFilteredBettypes') IS NOT NULL
		DROP TABLE	#tmpDLFilteredBettypes;

	CREATE TABLE	#tmpDLFilteredBettypes (
			BetTypeId					INT PRIMARY KEY
	);

	INSERT INTO #tmpDLFilteredBettypes(BetTypeId)
	SELECT	DISTINCT m.bettype
	FROM	bodb02.dbo.SportBettypeMatrix AS m WITH(NOLOCK)
	WHERE	m.sporttype NOT IN (1,2)
		AND m.ProductID = 1
		AND	m.bettype IS NOT NULL;

	-- BU & MB
	DECLARE @tmpDLBUMBData TABLE (
			BUDay	SMALLDATETIME
		,	MBDay	SMALLDATETIME
	);

	
	IF	OBJECT_ID('tempdb..#tmpDLFilteredSports') IS NOT NULL
		DROP TABLE	#tmpDLFilteredSports;

	CREATE TABLE	#tmpDLFilteredSports (
			SportId					INT PRIMARY KEY
	);

	INSERT INTO #tmpDLFilteredSports(SportId)
	SELECT	DISTINCT osm.SportId
	FROM	dbo.OSMarket AS osm WITH(NOLOCK);

	INSERT INTO @tmpDLBUMBData(BUDay,MBDay)
	EXECUTE bodb02.dbo.Age_SelBalanceUpDay;

	SELECT	TOP(1)
			@BalanceUpDay	= BUDay
		,	@MoveBetsDay	= MBDay
	FROM @tmpDLBUMBData;

	SELECT	@Today			= CONVERT(DATE, @Begin);
	SELECT	@Yesterday		= DATEADD(DAY, -1, @Today);

	IF	@Debug = 1
	BEGIN
		SELECT	@Msg = '
			@BalanceUpDay = ' + CONVERT(NVARCHAR, @BalanceUpDay, 120) + N'
			@MoveBetsDay  = ' + CONVERT(NVARCHAR, @MoveBetsDay, 120) + N'
			@Yesterday    = ' + CONVERT(NVARCHAR, @Yesterday, 120);

		-- Force the output to appear immediately --
		RAISERROR(@Msg, 0, 0) WITH NOWAIT;
	END;
	
	IF	OBJECT_ID('tempdb..#tmpDLScannedMatches') IS NOT NULL
	BEGIN
		DROP TABLE #tmpDLScannedMatches;
	END;

	CREATE TABLE	#tmpDLScannedMatches (
			  MatchId		INT NOT NULL PRIMARY KEY CLUSTERED
			, EventDate		DATETIME
			, MatchCode		NVARCHAR(50)			
			, LeagueId		INT			
			, SportId		INT
			, HomeId		INT
			, AwayId		INT
			, LeagueName	NVARCHAR(512)
			, HomeName		NVARCHAR(100)	
	);
	
	CREATE NONCLUSTERED INDEX #IX_tmpDLScannedMatches_EventDate ON #tmpDLScannedMatches (
		EventDate	ASC
	);

	IF	OBJECT_ID('tempdb..#tmpDLwinlostdate') IS NOT NULL
	BEGIN
		DROP TABLE	#tmpDLwinlostdate;
	END;

	CREATE TABLE	#tmpDLwinlostdate (
		Winlostdate				DATE
	);

	IF	OBJECT_ID('tempdb..#tmpDLFilteredBettrans') IS NOT NULL
	BEGIN
		DROP TABLE	#tmpDLFilteredBettrans;
	END;

	CREATE TABLE	#tmpDLFilteredBettrans (
			TransId				BIGINT
		,	CustId				INT
		,	MatchId				INT
		,	Winlostdate			SMALLDATETIME
		,	BettypeId			INT
		,	MatchCode			VARCHAR(100)
		,	EventDate			DATETIME
		,	SportId				INT
		,	LeagueId			INT
		,	LeagueName			NVARCHAR(512)
		,	HomeId				INT
		,	AwayId				INT
		,	LiveIndicator		BIT
		,	BetCount			INT
	);	
	
	CREATE CLUSTERED INDEX #CIX_tmpDLFilteredBettransByBatch_CustIdIdx ON #tmpDLFilteredBettrans (
			CustId				ASC
	);

	CREATE NONCLUSTERED INDEX #IX_tmpDLFilteredBettransByBatchIdx ON #tmpDLFilteredBettrans (
			Winlostdate			ASC
		,	MatchId				ASC
		,	BetTypeId			ASC
	);

	IF	OBJECT_ID('tempdb..#tmpDLStagingMarket') IS NOT NULL
	BEGIN
		DROP TABLE	#tmpDLStagingMarket;
	END;

	CREATE TABLE	#tmpDLStagingMarket (
			CustId				INT
		,	MatchId				INT
		,	MatchCode			VARCHAR(100)
		,	EventDate			DATETIME
		,	SportId				INT
		,	LeagueId			INT
		,	HomeId				INT
		,	AwayId				INT
		,	BetTypeId			INT
		,	MarketId			INT
		,	BetCount			INT
		,	IsLive				BIT
	);
	
	CREATE CLUSTERED INDEX #CIX_tmpDLStagingMarketIdx ON #tmpDLStagingMarket (
			EventDate			ASC
	); 

	CREATE NONCLUSTERED INDEX #IX_tmpDLStagingMarket_CustIdIdx ON #tmpDLStagingMarket (
			CustId				ASC
	);

	-- Initialize date range
	DECLARE @IsGetDataFromOrigin	BIT = 0
		,	@IsGetDataFrom14		BIT = 0
		,	@IsGetDataFromBK		BIT = 0;

	DECLARE @FromDateOrigin			SMALLDATETIME = NULL
		,	@ToDateOrigin			SMALLDATETIME = NULL
		,	@FromDate14				SMALLDATETIME = NULL
		,	@ToDate14				SMALLDATETIME = NULL
		,	@FromDateBK				SMALLDATETIME = NULL
		,	@ToDateBK				SMALLDATETIME = NULL;

	-- No input date range: Default job run
	IF (@IsRunningJob = 1)
		BEGIN
			SELECT @GenerateToDate   = @Yesterday;
			SELECT @GenerateFromDate =	CASE WHEN (@MoveBetsDay - 3) > @BalanceUpDay 
											 THEN (@MoveBetsDay - 3) 
										ELSE @BalanceUpDay END;
		END;

	-- Return immediately if wrong date range
	IF @GenerateToDate < @GenerateFromDate
	BEGIN
		IF @Debug = 1
		BEGIN
			SELECT	@Msg = 'GenerateToDate < GenerateFromDate: Unacceptable!';
			RAISERROR(@Msg, 0, 0) WITH NOWAIT;
		END;

		RETURN;
	END;

	-- Compute the date range for origin, 14, & bk if any (You guys should not touch here)
	IF @GenerateFromDate < @BalanceUpDay
	BEGIN
		SELECT @IsGetDataFromBK = 1
	END
	ELSE IF @GenerateFromDate <= @MoveBetsDay
	BEGIN
		SELECT @IsGetDataFrom14 = 1
	END
	ELSE IF @GenerateFromDate > @MoveBetsDay
	BEGIN
		SELECT @IsGetDataFromOrigin = 1
	END;

	IF @GenerateToDate < @BalanceUpDay
	BEGIN
		SELECT @IsGetDataFromBK = 1
	END
	ELSE IF @GenerateToDate <= @MoveBetsDay
	BEGIN
		SELECT @IsGetDataFrom14 = 1
	END
	ELSE IF @GenerateToDate > @MoveBetsDay
	BEGIN
		SELECT @IsGetDataFromOrigin = 1
	END;

	IF @GenerateFromDate < @BalanceUpDay AND @GenerateToDate > @MoveBetsDay
	BEGIN
		SELECT @IsGetDataFromBK = 1
		SELECT @IsGetDataFrom14 = 1
		SELECT @IsGetDataFromOrigin = 1
	END;

	IF @IsGetDataFromBK = 1 AND @IsGetDataFromOrigin = 1
	BEGIN
		SELECT	@FromDateOrigin = @MoveBetsDay + 1
				,	@ToDateOrigin = @GenerateToDate
				,	@FromDate14 = @BalanceUpDay
				,	@ToDate14 = @MoveBetsDay
				,	@FromDateBK = @GenerateFromDate 
				,	@ToDateBK = @BalanceUpDay - 1;
	END;

	IF @IsGetDataFromBK = 1 AND @IsGetDataFrom14 = 1 AND @IsGetDataFromOrigin = 0
	BEGIN
		SELECT	@FromDate14 = @BalanceUpDay
				,	@ToDate14 = @GenerateToDate
				,	@FromDateBK = @GenerateFromDate 
				,	@ToDateBK = @BalanceUpDay - 1;
	END;

	IF @IsGetDataFromBK = 0 AND @IsGetDataFrom14 = 1 AND @IsGetDataFromOrigin = 1
	BEGIN
		SELECT	@FromDateOrigin = @MoveBetsDay + 1
				,	@ToDateOrigin = @GenerateToDate
				,	@FromDate14 = @GenerateFromDate
				,	@ToDate14 = @MoveBetsDay
	END;

	IF @IsGetDataFromBK = 1 AND @IsGetDataFrom14 = 0 AND @IsGetDataFromOrigin = 0
	BEGIN
		SELECT	@FromDateBK = @GenerateFromDate 
				,	@ToDateBK = @GenerateToDate;
	END;

	IF @IsGetDataFromBK = 0 AND @IsGetDataFrom14 = 1 AND @IsGetDataFromOrigin = 0
	BEGIN
		SELECT	@FromDate14 = @GenerateFromDate
				,	@ToDate14 = @GenerateToDate
	END;

	IF @IsGetDataFromBK = 0 AND @IsGetDataFrom14 = 0 AND @IsGetDataFromOrigin = 1
	BEGIN
		SELECT	@FromDateOrigin = @GenerateFromDate
				,	@ToDateOrigin = @GenerateToDate
	END;

	IF @IsGetDataFromBK = 1 AND @IsGetDataFrom14 = 1 AND @IsGetDataFromOrigin = 1
	BEGIN
		SELECT	@FromDateOrigin = @MoveBetsDay + 1
				,	@ToDateOrigin = @GenerateToDate
				,	@FromDate14 = @BalanceUpDay
				,	@ToDate14 = @MoveBetsDay
				,	@FromDateBK = @GenerateFromDate 
				,	@ToDateBK = @BalanceUpDay - 1;
	END;

	IF	@IsGetDataFromBK = 1
	BEGIN
		TRUNCATE TABLE #tmpDLScannedMatches;

		SELECT @Date = '@FromDateBK = ' + CONVERT(NVARCHAR, @FromDateBK, 120) + ', @ToDateBK = ' + CONVERT(NVARCHAR, @ToDateBK, 120);

		-- GET Scanned Match List: Completed Soccer Match
		INSERT INTO #tmpDLScannedMatches(MatchId, EventDate, MatchCode, LeagueId, SportId, HomeId, AwayId, LeagueName, HomeName)
		SELECT	m.matchid
				, m.eventdate
				, m.MatchCode
				, m.leagueid
				, m.SportType
				, m.homeid
				, m.awayId
				, l.leaguename
				, t.teamname AS HomeName
		FROM	bodb_Archive.dbo.Match_bk AS m WITH (NOLOCK)
				INNER JOIN #tmpDLFilteredSports AS s WITH (NOLOCK) ON m.sporttype = s.SportId
				INNER JOIN bodb02.dbo.league AS l WITH (NOLOCK) ON l.leagueid = m.leagueid
				LEFT JOIN bodb02.dbo.team AS t WITH (NOLOCK) ON t.teamid = homeid
		WHERE	m.EventDate BETWEEN @FromDateBK AND @ToDateBK
				AND	m.SportType not in (1,2);
		
		INSERT INTO	#tmpDLwinlostdate (Winlostdate)
		SELECT	tally.winlostdate
		FROM	(
			SELECT	[NoDays] = DATEDIFF(DAY, @FromDateBK, @ToDateBK) + 1
		) cnt
		CROSS APPLY	(
			SELECT	TOP(cnt.NoDays)
					[winlostdate] = DATEADD(DAY, ROW_NUMBER() OVER(ORDER BY (SELECT NULL)) - 1, @FromDateBK)
			FROM		(VALUES (0), (0), (0), (0), (0), (0), (0), (0), (0), (0)) x10(n)
			CROSS APPLY	(VALUES (0), (0), (0), (0), (0), (0), (0), (0), (0), (0)) x100(n)
			CROSS APPLY	(VALUES (0), (0), (0), (0), (0), (0), (0), (0), (0), (0)) x1000(n)
		) tally;

		SELECT	@RowCount	= @@ROWCOUNT
			,	@Duration	= DATEDIFF(millisecond, @Begin, GETDATE())
			;
		
		IF	@Debug = 1
		BEGIN
			-- Force the output to appear immediately
			RAISERROR('From BK - Insert #tmpDLwinlostdate - Date: "%s" - %d rows - %d ms', 0, 0, @Date, @RowCount, @Duration) WITH NOWAIT;
		END;

		WHILE	EXISTS (SELECT 1 FROM #tmpDLwinlostdate WITH(NOLOCK))
		BEGIN
			SELECT	TOP(1)
					@WinLostDate = d.winlostdate
			FROM	#tmpDLwinlostdate AS d WITH(NOLOCK)
			ORDER BY winlostdate DESC;
			
			SELECT @Date = CONVERT(NVARCHAR, @winlostdate, 120);

			TRUNCATE TABLE	#tmpDLFilteredBettrans;
			INSERT INTO	#tmpDLFilteredBettrans (TransId, CustId, MatchId, Winlostdate, BettypeId, 
						MatchCode, EventDate, SportId, LeagueId, LeagueName, HomeId, AwayId, LiveIndicator, BetCount)
			SELECT	[TransId]			= b.transid
				,	[CustId]			= b.custid
				,	[MatchId]			= b.matchId
				,	[Winlostdate]		= b.winlostdate
				,	[BettypeId]			= b.bettype
				,	[MatchCode]			= m.MatchCode
				,	[EventDate]			= m.EventDate
				,	[SportId]			= m.SportId
				,	[LeagueId]			= m.LeagueId
				,	[LeagueId]			= m.LeagueName
				,	[HomeId]			= m.HomeId
				,	[AwayId]			= m.AwayId
				,	[LiveIndicator]		= b.liveindicator
				,	[BetCount]			= 1
			FROM	bodb_Archive.dbo.bettrans_bk AS b WITH (NOLOCK)
				INNER JOIN	#tmpDLScannedMatches AS m WITH (NOLOCK) ON	b.matchid = m.matchid
				INNER JOIN  #tmpDLFilteredBettypes AS bt WITH(NOLOCK) ON b.bettype = bt.BetTypeId
			WHERE	b.winlostdate = @winlostdate
				AND	b.Currency NOT IN (20, 27, 28);
			
			SELECT	@RowCount	= @@ROWCOUNT
				,	@Duration	= DATEDIFF(millisecond, @Begin, GETDATE())
				;

			IF	@Debug = 1
			BEGIN
				-- Force the output to appear immediately
				RAISERROR('From BK - Insert #tmpDLFilteredBettransByBatch - Date: "%s" - %d rows - %d ms', 0, 0, @Date, @RowCount, @Duration) WITH NOWAIT;
			END;
			
				-- "DISTINCT" Prevent Page Splits
			DELETE b WITH(ROWLOCK)
			FROM	(	
						SELECT *, ROW_NUMBER() OVER (PARTITION BY TransId ORDER BY TransId) AS rn
						FROM #tmpDLFilteredBettrans
					) AS b
			WHERE b.rn > 1;
			
			INSERT INTO	#tmpDLStagingMarket (MatchId, EventDate, SportId, LeagueId, HomeId, AwayId, BetTypeId, MarketId, BetCount, IsLive)
			SELECT	[MatchId]			= b.MatchId
				,	[EventDate]			= b.EventDate
				,	[SportId]			= b.SportId
				,	[LeagueId]			= b.LeagueId
				,	[HomeId]			= b.HomeId
				,	[AwayId]			= b.AwayId
				,	[BetTypeId]			= b.BetTypeId
				,	[MarketId]			= mp.MarketId
				,	[BetCount]			= SUM(b.BetCount)
				,	[IsLive]			= b.LiveIndicator
			FROM	#tmpDLFilteredBettrans AS b WITH (NOLOCK)
				INNER JOIN #tmpDLFilteredBettypes AS bt WITH(NOLOCK) ON b.BetTypeId = bt.BetTypeId
				CROSS APPLY (SELECT mp.MarketId, ROW_NUMBER() OVER(ORDER BY ISNULL(mp.LeagueNameMarket, '') DESC, ISNULL(mp.BetTypeId, 0) DESC) AS RN
							 FROM dbo.OSMarketMapping AS mp WITH(NOLOCK)
							 WHERE b.SportId = mp.SportId
								AND (
									b.LeagueName LIKE '%' + mp.LeagueNameMarket
									OR mp.LeagueNameMarket IS NULL AND b.BettypeId = mp.BetTypeId
									OR mp.LeagueNameMarket IS NULL AND mp.BetTypeId IS NULL
									)
								 ) mp
			WHERE	b.winlostdate = @winlostdate
				AND mp.RN = 1
			GROUP BY b.MatchId
				,	b.EventDate
				,	b.SportId
				,	b.LeagueId
				,	b.HomeId
				,	b.AwayId
				,	b.BetTypeId
				,	mp.MarketId
				,	b.LiveIndicator;

			SELECT	@RowCount	= @@ROWCOUNT
				,	@Duration	= DATEDIFF(millisecond, @Begin, GETDATE())
				;

			IF	@Debug = 1
			BEGIN
				-- Force the output to appear immediately
				RAISERROR('From BK - Insert #tmpDLStagingMarket - Date: "%s" - %d rows - %d ms', 0, 0, @Date, @RowCount, @Duration) WITH NOWAIT;
			END;

			DELETE osm WITH(ROWLOCK) 
			FROM dbo.OSSummaryMarket AS osm
			WHERE osm.EventDate = @winlostdate;

			INSERT INTO	dbo.OSSummaryMarket (MatchId, EventDate, SportId, LeagueId, HomeId, AwayId, BetTypeId, MarketId, BetCount, IsLive)
			SELECT	[MatchId]			= t.MatchId
				,	[EventDate]			= t.EventDate
				,	[SportId]			= t.SportId
				,	[LeagueId]			= t.LeagueId
				,	[HomeId]			= t.HomeId
				,	[AwayId]			= t.AwayId
				,	[BetTypeId]			= t.BetTypeId
				,	[MarketId]			= t.MarketId
				,	[BetCount]			= t.BetCount
				,	[IsLive]			= t.IsLive
			FROM	#tmpDLStagingMarket AS t WITH(NOLOCK) 
			WHERE	t.EventDate = @winlostdate
			ORDER BY t.SportId,t.CustId,t.LeagueId,t.MatchId,t.BetTypeId,t.MarketId
				
			SELECT	@RowCount	= @@ROWCOUNT
				,	@Duration	= DATEDIFF(millisecond, @Begin, GETDATE())
				;

			IF	@Debug = 1
			BEGIN
				-- Force the output to appear immediately
				RAISERROR('From BK - Insert OSSummaryMarket - Date: "%s" - %d rows - %d ms', 0, 0, @Date, @RowCount, @Duration) WITH NOWAIT;
			END;

			DELETE	d
			FROM	#tmpDLwinlostdate AS d
			WHERE	d.winlostdate = @winlostdate;
				
			SELECT	@RowCount	= @@ROWCOUNT
				,	@Duration	= DATEDIFF(millisecond, @Begin, GETDATE());

			IF	@Debug = 1
			BEGIN
				-- Force the output to appear immediately
				RAISERROR('From BK - DELETE #tmpDLwinlostdate - Date: "%s" - %d rows - %d ms', 0, 0, @Date, @RowCount, @Duration) WITH NOWAIT;
			END;

			TRUNCATE TABLE #tmpDLStagingMarket;
			TRUNCATE TABLE #tmpDLFilteredBettrans;
		END;
	END;

	IF	@IsGetDataFrom14 = 1
	BEGIN
		TRUNCATE TABLE #tmpDLScannedMatches;

		SELECT @Date = '@FromDate14 = ' + CONVERT(NVARCHAR, @FromDate14, 120) + ', @ToDate14 = ' + CONVERT(NVARCHAR, @ToDate14, 120);

		-- GET Scanned Match List: Completed Soccer Match
		INSERT INTO #tmpDLScannedMatches(MatchId, EventDate, MatchCode, LeagueId, SportId, HomeId, AwayId, LeagueName, HomeName)
		SELECT	m.matchid
				, m.eventdate
				, m.MatchCode
				, m.leagueid
				, m.SportType
				, m.homeid
				, m.awayId
				, l.leaguename
				, t.teamname AS HomeName
		FROM	bodb02.dbo.Match14 AS m WITH (NOLOCK)
				INNER JOIN #tmpDLFilteredSports AS s WITH (NOLOCK) ON m.sporttype = s.SportId
				INNER JOIN bodb02.dbo.league AS l WITH (NOLOCK) ON l.leagueid = m.leagueid
				LEFT JOIN bodb02.dbo.team AS t WITH (NOLOCK) ON t.teamid = homeid
		WHERE	m.EventDate BETWEEN @FromDate14 AND @ToDate14
				AND	m.SportType not in (1,2);
		
		INSERT INTO	#tmpDLwinlostdate (winlostdate)
		SELECT	tally.winlostdate
		FROM	(
			SELECT	[NoDays] = DATEDIFF(DAY, @FromDate14, @ToDate14) + 1
		) cnt
		CROSS APPLY	(
			SELECT	TOP(cnt.NoDays)
					[winlostdate] = DATEADD(DAY, ROW_NUMBER() OVER(ORDER BY (SELECT NULL)) - 1, @FromDate14)
			FROM		(VALUES (0), (0), (0), (0), (0), (0), (0), (0), (0), (0)) x10(n)
			CROSS APPLY	(VALUES (0), (0), (0), (0), (0), (0), (0), (0), (0), (0)) x100(n)
			CROSS APPLY	(VALUES (0), (0), (0), (0), (0), (0), (0), (0), (0), (0)) x1000(n)
		) tally;

		SELECT	@RowCount	= @@ROWCOUNT
			,	@Duration	= DATEDIFF(millisecond, @Begin, GETDATE())
			;

		IF	@Debug = 1
		BEGIN
			-- Force the output to appear immediately
			RAISERROR('From 14 - Insert #tmpDLwinlostdate - Date: "%s" - %d rows - %d ms', 0, 0, @Date, @RowCount, @Duration) WITH NOWAIT;
		END;

		WHILE	EXISTS (SELECT 1 FROM #tmpDLwinlostdate WITH(NOLOCK))
		BEGIN
			SELECT	TOP(1)
					@WinLostDate = d.winlostdate
			FROM	#tmpDLwinlostdate AS d WITH(NOLOCK)
			ORDER BY winlostdate DESC;
			
			SELECT @Date = CONVERT(NVARCHAR, @winlostdate, 120);

			TRUNCATE TABLE	#tmpDLFilteredBettrans;
			INSERT INTO	#tmpDLFilteredBettrans (TransId, CustId, MatchId, Winlostdate, BettypeId, 
						MatchCode, EventDate, SportId, LeagueId, LeagueName, HomeId, AwayId, LiveIndicator, BetCount)
			SELECT	[TransId]			= b.transid
				,	[CustId]			= b.custid
				,	[MatchId]			= b.matchId
				,	[Winlostdate]		= b.winlostdate
				,	[BettypeId]			= b.bettype
				,	[MatchCode]			= m.MatchCode
				,	[EventDate]			= m.EventDate
				,	[SportId]			= m.SportId
				,	[LeagueId]			= m.LeagueId
				,	[LeagueId]			= m.LeagueName
				,	[HomeId]			= m.HomeId
				,	[AwayId]			= m.AwayId
				,	[LiveIndicator]		= b.liveindicator
				,	[BetCount]			= 1
			FROM	bodb02.dbo.bettrans14 AS b WITH (NOLOCK)
				INNER JOIN	#tmpDLScannedMatches AS m WITH (NOLOCK) ON	b.matchid = m.matchid
				INNER JOIN  #tmpDLFilteredBettypes AS bt WITH(NOLOCK) ON b.bettype = bt.BetTypeId
			WHERE	b.winlostdate = @winlostdate
				AND	b.Currency NOT IN (20, 27, 28);
			
			SELECT	@RowCount	= @@ROWCOUNT
				,	@Duration	= DATEDIFF(millisecond, @Begin, GETDATE())
				;

			IF	@Debug = 1
			BEGIN
				-- Force the output to appear immediately
				RAISERROR('From 14 - Insert #tmpDLFilteredBettransByBatch - Date: "%s" - %d rows - %d ms', 0, 0, @Date, @RowCount, @Duration) WITH NOWAIT;
			END;
			
				-- "DISTINCT" Prevent Page Splits
			DELETE b WITH(ROWLOCK)
			FROM	(	
						SELECT *, ROW_NUMBER() OVER (PARTITION BY TransId ORDER BY TransId) AS rn
						FROM #tmpDLFilteredBettrans
					) AS b
			WHERE b.rn > 1;
			
			INSERT INTO	#tmpDLStagingMarket (MatchId, EventDate, SportId, LeagueId, HomeId, AwayId, BetTypeId, MarketId, BetCount, IsLive)
			SELECT	[MatchId]			= b.MatchId
				,	[EventDate]			= b.EventDate
				,	[SportId]			= b.SportId
				,	[LeagueId]			= b.LeagueId
				,	[HomeId]			= b.HomeId
				,	[AwayId]			= b.AwayId
				,	[BetTypeId]			= b.BetTypeId
				,	[MarketId]			= mp.MarketId
				,	[BetCount]			= SUM(b.BetCount)
				,	[IsLive]			= b.LiveIndicator
			FROM	#tmpDLFilteredBettrans AS b WITH (NOLOCK)
				INNER JOIN #tmpDLFilteredBettypes AS bt WITH(NOLOCK) ON b.BetTypeId = bt.BetTypeId
				CROSS APPLY (SELECT mp.MarketId, ROW_NUMBER() OVER(ORDER BY ISNULL(mp.LeagueNameMarket, '') DESC, ISNULL(mp.BetTypeId, 0) DESC) AS RN
							 FROM dbo.OSMarketMapping AS mp WITH(NOLOCK)
							 WHERE b.SportId = mp.SportId
								AND (
									b.LeagueName LIKE '%' + mp.LeagueNameMarket
									OR mp.LeagueNameMarket IS NULL AND b.BettypeId = mp.BetTypeId
									OR mp.LeagueNameMarket IS NULL AND mp.BetTypeId IS NULL
									)
								 ) mp
			WHERE	b.winlostdate = @winlostdate
				AND mp.RN = 1
			GROUP BY b.MatchId
				,	b.EventDate
				,	b.SportId
				,	b.LeagueId
				,	b.HomeId
				,	b.AwayId
				,	b.BetTypeId
				,	mp.MarketId
				,	b.LiveIndicator;

			SELECT	@RowCount	= @@ROWCOUNT
				,	@Duration	= DATEDIFF(millisecond, @Begin, GETDATE())
				;

			IF	@Debug = 1
			BEGIN
				-- Force the output to appear immediately
				RAISERROR('From 14 - Insert #tmpDLStagingMarket - Date: "%s" - %d rows - %d ms', 0, 0, @Date, @RowCount, @Duration) WITH NOWAIT;
			END;

			DELETE osm WITH(ROWLOCK) 
			FROM dbo.OSSummaryMarket AS osm
			WHERE osm.EventDate = @winlostdate;

			INSERT INTO	dbo.OSSummaryMarket (MatchId, EventDate, SportId, LeagueId, HomeId, AwayId, BetTypeId, MarketId, BetCount, IsLive)
			SELECT	[MatchId]			= t.MatchId
				,	[EventDate]			= t.EventDate
				,	[SportId]			= t.SportId
				,	[LeagueId]			= t.LeagueId
				,	[HomeId]			= t.HomeId
				,	[AwayId]			= t.AwayId
				,	[BetTypeId]			= t.BetTypeId
				,	[MarketId]			= t.MarketId
				,	[BetCount]			= t.BetCount
				,	[IsLive]			= t.IsLive
			FROM	#tmpDLStagingMarket AS t WITH(NOLOCK) 
			WHERE	t.EventDate = @winlostdate
			ORDER BY t.SportId,t.CustId,t.LeagueId,t.MatchId,t.BetTypeId,t.MarketId
				
			SELECT	@RowCount	= @@ROWCOUNT
				,	@Duration	= DATEDIFF(millisecond, @Begin, GETDATE())
				;

			IF	@Debug = 1
			BEGIN
				-- Force the output to appear immediately
				RAISERROR('From 14 - Insert OSSummaryMarket - Date: "%s" - %d rows - %d ms', 0, 0, @Date, @RowCount, @Duration) WITH NOWAIT;
			END;

			DELETE	d
			FROM	#tmpDLwinlostdate AS d
			WHERE	d.winlostdate = @winlostdate;
				
			SELECT	@RowCount	= @@ROWCOUNT
				,	@Duration	= DATEDIFF(millisecond, @Begin, GETDATE());

			IF	@Debug = 1
			BEGIN
				-- Force the output to appear immediately
				RAISERROR('From 14 - DELETE #tmpDLwinlostdate - Date: "%s" - %d rows - %d ms', 0, 0, @Date, @RowCount, @Duration) WITH NOWAIT;
			END;

			TRUNCATE TABLE #tmpDLStagingMarket;
			TRUNCATE TABLE #tmpDLFilteredBettrans;
		END;
	END;
	
	IF	@IsGetDataFromOrigin = 1
	BEGIN
		TRUNCATE TABLE #tmpDLScannedMatches;

		SELECT @Date = '@FromDateOrigin = ' + CONVERT(NVARCHAR, @FromDateOrigin, 120) + ', @ToDateOrigin = ' + CONVERT(NVARCHAR, @ToDateOrigin, 120);

		-- GET Scanned Match List: Completed Soccer Match
		INSERT INTO #tmpDLScannedMatches(MatchId, EventDate, MatchCode, LeagueId, SportId, HomeId, AwayId, LeagueName, HomeName)
		SELECT	m.matchid
				, m.eventdate
				, m.MatchCode
				, m.leagueid
				, m.SportType
				, m.homeid
				, m.awayId
				, l.leaguename
				, t.teamname AS HomeName
		FROM	bodb02.dbo.Match AS m WITH (NOLOCK)
				INNER JOIN #tmpDLFilteredSports AS s WITH (NOLOCK) ON m.sporttype = s.SportId
				INNER JOIN bodb02.dbo.league AS l WITH (NOLOCK) ON l.leagueid = m.leagueid
				LEFT JOIN bodb02.dbo.team AS t WITH (NOLOCK) ON t.teamid = homeid
		WHERE	m.EventDate BETWEEN @FromDateOrigin AND @ToDateOrigin
				AND	m.SportType not in (1,2);
		
		INSERT INTO	#tmpDLwinlostdate (winlostdate)
		SELECT	tally.winlostdate
		FROM	(
			SELECT	[NoDays] = DATEDIFF(DAY, @FromDateOrigin, @ToDateOrigin) + 1
		) cnt
		CROSS APPLY	(
			SELECT	TOP(cnt.NoDays)
					[winlostdate] = DATEADD(DAY, ROW_NUMBER() OVER(ORDER BY (SELECT NULL)) - 1, @FromDateOrigin)
			FROM		(VALUES (0), (0), (0), (0), (0), (0), (0), (0), (0), (0)) x10(n)
			CROSS APPLY	(VALUES (0), (0), (0), (0), (0), (0), (0), (0), (0), (0)) x100(n)
			CROSS APPLY	(VALUES (0), (0), (0), (0), (0), (0), (0), (0), (0), (0)) x1000(n)
		) tally;

		SELECT	@RowCount	= @@ROWCOUNT
			,	@Duration	= DATEDIFF(millisecond, @Begin, GETDATE())
			;

		IF	@Debug = 1
		BEGIN
			-- Force the output to appear immediately
			RAISERROR('From Origin - Insert #tmpDLwinlostdate - Date: "%s" - %d rows - %d ms', 0, 0, @Date, @RowCount, @Duration) WITH NOWAIT;
		END;

		WHILE	EXISTS (SELECT 1 FROM #tmpDLwinlostdate WITH(NOLOCK))
		BEGIN
			SELECT	TOP(1)
					@WinLostDate = d.winlostdate
			FROM	#tmpDLwinlostdate AS d WITH(NOLOCK)
			ORDER BY winlostdate DESC;
			
			SELECT @Date = CONVERT(NVARCHAR, @winlostdate, 120);

			TRUNCATE TABLE	#tmpDLFilteredBettrans;
			INSERT INTO	#tmpDLFilteredBettrans (TransId, CustId, MatchId, Winlostdate, BettypeId, 
						MatchCode, EventDate, SportId, LeagueId, LeagueName, HomeId, AwayId, LiveIndicator, BetCount)
			SELECT	[TransId]			= b.transid
				,	[CustId]			= b.custid
				,	[MatchId]			= b.matchId
				,	[Winlostdate]		= b.winlostdate
				,	[BettypeId]			= b.bettype
				,	[MatchCode]			= m.MatchCode
				,	[EventDate]			= m.EventDate
				,	[SportId]			= m.SportId
				,	[LeagueId]			= m.LeagueId
				,	[LeagueId]			= m.LeagueName
				,	[HomeId]			= m.HomeId
				,	[AwayId]			= m.AwayId
				,	[LiveIndicator]		= b.liveindicator
				,	[BetCount]			= 1
			FROM	bodb02.dbo.bettrans AS b WITH (NOLOCK)
				INNER JOIN	#tmpDLScannedMatches AS m WITH (NOLOCK) ON	b.matchid = m.matchid
				INNER JOIN  #tmpDLFilteredBettypes AS bt WITH(NOLOCK) ON b.bettype = bt.BetTypeId
			WHERE	b.winlostdate = @winlostdate
				AND	b.Currency NOT IN (20, 27, 28);
			
			SELECT	@RowCount	= @@ROWCOUNT
				,	@Duration	= DATEDIFF(millisecond, @Begin, GETDATE())
				;

			IF	@Debug = 1
			BEGIN
				-- Force the output to appear immediately
				RAISERROR('From Origin - Insert #tmpDLFilteredBettransByBatch - Date: "%s" - %d rows - %d ms', 0, 0, @Date, @RowCount, @Duration) WITH NOWAIT;
			END;
			
				-- "DISTINCT" Prevent Page Splits
			DELETE b WITH(ROWLOCK)
			FROM	(	
						SELECT *, ROW_NUMBER() OVER (PARTITION BY TransId ORDER BY TransId) AS rn
						FROM #tmpDLFilteredBettrans
					) AS b
			WHERE b.rn > 1;
			
			INSERT INTO	#tmpDLStagingMarket (MatchId, EventDate, SportId, LeagueId, HomeId, AwayId, BetTypeId, MarketId, BetCount, IsLive)
			SELECT	[MatchId]			= b.MatchId
				,	[EventDate]			= b.EventDate
				,	[SportId]			= b.SportId
				,	[LeagueId]			= b.LeagueId
				,	[HomeId]			= b.HomeId
				,	[AwayId]			= b.AwayId
				,	[BetTypeId]			= b.BetTypeId
				,	[MarketId]			= mp.MarketId
				,	[BetCount]			= SUM(b.BetCount)
				,	[IsLive]			= b.LiveIndicator
			FROM	#tmpDLFilteredBettrans AS b WITH (NOLOCK)
				INNER JOIN #tmpDLFilteredBettypes AS bt WITH(NOLOCK) ON b.BetTypeId = bt.BetTypeId
				CROSS APPLY (SELECT mp.MarketId, ROW_NUMBER() OVER(ORDER BY ISNULL(mp.LeagueNameMarket, '') DESC, ISNULL(mp.BetTypeId, 0) DESC) AS RN
							 FROM dbo.OSMarketMapping AS mp WITH(NOLOCK)
							 WHERE b.SportId = mp.SportId
								AND (
									b.LeagueName LIKE '%' + mp.LeagueNameMarket
									OR mp.LeagueNameMarket IS NULL AND b.BettypeId = mp.BetTypeId
									OR mp.LeagueNameMarket IS NULL AND mp.BetTypeId IS NULL
									)
								 ) mp
			WHERE	b.winlostdate = @winlostdate
				AND mp.RN = 1
			GROUP BY b.MatchId
				,	b.EventDate
				,	b.SportId
				,	b.LeagueId
				,	b.HomeId
				,	b.AwayId
				,	b.BetTypeId
				,	mp.MarketId
				,	b.LiveIndicator;

			SELECT	@RowCount	= @@ROWCOUNT
				,	@Duration	= DATEDIFF(millisecond, @Begin, GETDATE())
				;

			IF	@Debug = 1
			BEGIN
				-- Force the output to appear immediately
				RAISERROR('From Origin - Insert #tmpDLStagingMarket - Date: "%s" - %d rows - %d ms', 0, 0, @Date, @RowCount, @Duration) WITH NOWAIT;
			END;

			DELETE osm WITH(ROWLOCK) 
			FROM dbo.OSSummaryMarket AS osm
			WHERE osm.EventDate = @winlostdate;

			INSERT INTO	dbo.OSSummaryMarket (MatchId, EventDate, SportId, LeagueId, HomeId, AwayId, BetTypeId, MarketId, BetCount, IsLive)
			SELECT	[MatchId]			= t.MatchId
				,	[EventDate]			= t.EventDate
				,	[SportId]			= t.SportId
				,	[LeagueId]			= t.LeagueId
				,	[HomeId]			= t.HomeId
				,	[AwayId]			= t.AwayId
				,	[BetTypeId]			= t.BetTypeId
				,	[MarketId]			= t.MarketId
				,	[BetCount]			= t.BetCount
				,	[IsLive]			= t.IsLive
			FROM	#tmpDLStagingMarket AS t WITH(NOLOCK) 
			WHERE	t.EventDate = @winlostdate
			ORDER BY t.SportId,t.CustId,t.LeagueId,t.MatchId,t.BetTypeId,t.MarketId
				
			SELECT	@RowCount	= @@ROWCOUNT
				,	@Duration	= DATEDIFF(millisecond, @Begin, GETDATE())
				;

			IF	@Debug = 1
			BEGIN
				-- Force the output to appear immediately
				RAISERROR('From Origin - Insert OSSummaryMarket - Date: "%s" - %d rows - %d ms', 0, 0, @Date, @RowCount, @Duration) WITH NOWAIT;
			END;

			DELETE	d
			FROM	#tmpDLwinlostdate AS d
			WHERE	d.winlostdate = @winlostdate;
				
			SELECT	@RowCount	= @@ROWCOUNT
				,	@Duration	= DATEDIFF(millisecond, @Begin, GETDATE());

			IF	@Debug = 1
			BEGIN
				-- Force the output to appear immediately
				RAISERROR('From Origin - DELETE #tmpDLwinlostdate - Date: "%s" - %d rows - %d ms', 0, 0, @Date, @RowCount, @Duration) WITH NOWAIT;
			END;

			TRUNCATE TABLE #tmpDLStagingMarket;
			TRUNCATE TABLE #tmpDLFilteredBettrans;
		END;
	END;
END;

GO
/*<info serverAlias="DBTGRS-bodb_TGRS" executers="bodbTGRSNet" isFunction="0" isNested="0"></info>*/