ALTER PROCEDURE [dbo].[Task_StagingJuice]
		@Debug					BIT = 0
	,	@BeforeMoveBetsDay		BIT = 1	
	,	@GenerateFromDate		SMALLDATETIME = NULL
	,	@GenerateToDate			SMALLDATETIME = NULL
AS
/*  
	Created:	20170214@Long
	Task :		Update Juice for Trader Performance
	DB:			DBTGRS.bodb_TGRS
	Original:
  
	Revisions:
   		- 20170315@Long:		Apply ExtraPT and Calc for TO & WL's Leftover
		- 20170330@John:		Update TO & WL's Leftover
		- 20170315@Long:		Devide batch by date (not by 200k records as it is)
		- 20170830@Long:		Support UnassignedTrader
		- 20170914@Billy:		Format code and tune performance for Task Staging Juice - [Redmine: #81465]
		- 20170918@Billy:		Remove hedge match from bettrans data - [Redmine: #83470]		
		- 20180102@Long:		Change the way to get BU & MB days
		- 20180103@Long:		Support code for generating historical data
		- 20180105@Aaron:		Fix date range. Note: BU & MB are in bettrans14
		- 20180423@John:		Update date range [Redmine: #89493]
		- 20190116@John:		Fix date range for generating historical data [Redmine: #108008]
		- 20190304@Long:		Calc Actual-rate values for Soccer [Redmine ID: 108920]
		- 20190704@John.Ngo:	Implement change request to the job sum and enhance logic on Extra PT WL calculation [Redmine ID: 116379]
   		
	Param's Explanation:
		
	Exam:
	 
*/
BEGIN;
	SET NOCOUNT ON;

	-- Common variables
	DECLARE	@IdForUnassignedTrader	INT	= 0
		;

	DECLARE	@BalanceUpDay			SMALLDATETIME
		,	@MoveBetsDay			SMALLDATETIME
		,	@Yesterday				SMALLDATETIME
		;

	DECLARE	@RowCount				INT
		,	@Begin					DATETIME = GETDATE()
		,	@winlostdate			DATETIME
		,	@Duration				INT
		,	@Msg					NVARCHAR(MAX)
		,	@Date					NVARCHAR(250)
		;
	IF	OBJECT_ID('tempdb..#tmpDataGroup') IS NOT NULL
	BEGIN;
		DROP TABLE	#tmpDataGroup;
	END;

	CREATE TABLE	#tmpDataGroup (
			CustId					INT
		,	EventDate				DATE
		,	MatchId					INT
		,	BetType					SMALLINT
		,	BetTeam					VARCHAR(10)
		,	ScoreHDP				SMALLMONEY
		,	AVGOdds					FLOAT
		,	StakeMYBeforeComm		MONEY
		,	StakeMY					MONEY
		,	Stake					MONEY
		,	MOdds					SMALLMONEY
		,	StatusID				TINYINT
		,	AVGOdds_AR				FLOAT
		,	StakeMYBeforeComm_AR	MONEY
		,	StakeMY_AR				MONEY
		,	Stake_AR				MONEY
	);
					
	IF	OBJECT_ID('tempdb..#winlostdate') IS NOT NULL
	BEGIN;
		DROP TABLE	#winlostdate;
	END;

	CREATE TABLE	#winlostdate (
			winlostdate				DATETIME
	);

	IF	OBJECT_ID('tempdb..#ExtraPTSportbook') IS NOT NULL
	BEGIN
		DROP TABLE	#ExtraPTSportbook;
	END;

	CREATE TABLE #ExtraPTSportbook
	(
		SuperId		INT,
		ExtraPT		MONEY,
		FromDate	DATETIME,
		ToDate		DATETIME
	);

	IF	OBJECT_ID('tempdb..#tmpFilteredBettransBKByBatch2') IS NOT NULL
	BEGIN;
		DROP TABLE	#tmpFilteredBettransBKByBatch2;
	END;

	CREATE TABLE	#tmpFilteredBettransBKByBatch2 (
			transid					BIGINT
		,	matchid					INT
		,	winlostdate				SMALLDATETIME
		,	bettype					SMALLINT
		,	modds					SMALLMONEY
		,	virtualrate				FLOAT
		,	actualrate				FLOAT
		,	tpositiontaking			SMALLMONEY
		,	scomm					MONEY
		,	betteam					VARCHAR(10)
		,	odds					SMALLMONEY
		,	statusID				TINYINT
		,	ExtraPT					DECIMAL(12, 8)
		,	ScoreHDP				SMALLMONEY
		,	StakeMY					MONEY
		,	Stake					MONEY
	);

	CREATE CLUSTERED INDEX	#CIX_tmpFilteredBettransBKByBatchIdx2 ON #tmpFilteredBettransBKByBatch2 (
			winlostdate				ASC
		,	MatchId					ASC
		,	BetType					ASC
	);
							
	IF	OBJECT_ID('tempdb..#tmpStagingTraderPerformance2') IS NOT NULL
	BEGIN;
		DROP TABLE	#tmpStagingTraderPerformance2;
	END;

	CREATE TABLE	#tmpStagingTraderPerformance2 (
			CustId					INT
		,	EventDate				DATE
		,	MatchId					INT
		,	BetType					SMALLINT
		,	BetTeam					VARCHAR(10)
		,	ScoreHDP				SMALLMONEY
		,	Odds					FLOAT
		,	StakeMY					MONEY
		,	Stake					MONEY
		,	ExtraPT					DECIMAL(12, 8)
		,	TPositionTaking			SMALLMONEY
		,	VirtualRate				FLOAT
		,	ActualRate				FLOAT
		,	Scomm					MONEY
		,	MOdds					SMALLMONEY
		,	StatusID				TINYINT
	);
					
	IF	OBJECT_ID('tempdb..#tmpTrader2') IS NOT NULL
	BEGIN;
		DROP TABLE	#tmpTrader2;
	END;

	CREATE TABLE	#tmpTrader2 (
			CustId					INT
		,	MatchId					INT
		,	EventDate				DATETIME
		,	BetType					SMALLINT
		,	SpecialType				TINYINT
	);

	CREATE INDEX	#IDX_tmpTrader2 ON #tmpTrader2 (
			EventDate				ASC
		,	MatchId					ASC
		,	BetType					ASC
	);

	IF	OBJECT_ID('tempdb..#tmpJuice') IS NOT NULL
	BEGIN;
		DROP TABLE	#tmpJuice;
	END;

	CREATE TABLE	#tmpJuice (
			EventDate				DATE
		,	MatchId					INT
		,	BetType					SMALLINT
		,	StakeMYBeforeComm		MONEY
		,	StakeMY					MONEY
		,	Juice					MONEY
		,	StakeMYRJuice			MONEY
		,	StakeMYRTotal			MONEY
		,	ScoreHDP				SMALLMONEY
		,	StakeMYBeforeComm_AR	MONEY
		,	StakeMY_AR				MONEY
		,	Juice_AR				MONEY
		,	StakeMYRJuice_AR		MONEY
		,	StakeMYRTotal_AR		MONEY
	);

	CREATE INDEX	#IDX_EventDate ON #tmpJuice (
			EventDate
		,	MatchId
		,	BetType
	);


	IF	OBJECT_ID('tempdb..#tmpSumTotal') IS NOT NULL
	BEGIN;
		DROP TABLE	#tmpSumTotal;
	END;

	CREATE TABLE	#tmpSumTotal (
			EventDate				DATE
		,	MatchId					INT
		,	BetType					SMALLINT
		,	StakeMYBeforeComm		MONEY
		,	Juice					MONEY
		,	StakeMYRJuice			MONEY
		,	StakeMYBeforeComm_AR	MONEY
		,	Juice_AR				MONEY
		,	StakeMYRJuice_AR		MONEY
	);

	IF	OBJECT_ID('tempdb..#tmpResults') IS NOT NULL
	BEGIN;
		DROP TABLE	#tmpResults;
	END;

	CREATE TABLE	#tmpResults (
			EventDate				DATE
		,	MatchId					INT
		,	BetType					SMALLINT
		,	StakeMYBeforeComm		MONEY
		,	Juice					MONEY
		,	StakeMYRJuice			MONEY
		,	StakeMYBeforeComm_AR	MONEY
		,	Juice_AR				MONEY
		,	StakeMYRJuice_AR		MONEY
	);

	IF	OBJECT_ID('tempdb..#BUMBData') IS NOT NULL
	BEGIN;
		DROP TABLE	#BUMBData
	END;

	CREATE TABLE	#BUMBData (
			BUDay	SMALLDATETIME
		,	MBDay	SMALLDATETIME
	);

	INSERT INTO #BUMBData(BUDay,MBDay)
	EXECUTE bodb02.dbo.Age_SelBalanceUpDay;

	SELECT	TOP 1 @BalanceUpDay	= BUDay FROM #BUMBData;
	SELECT	TOP 1 @MoveBetsDay	= MBDay FROM #BUMBData;
	SELECT	@Yesterday		= CONVERT(DATE, GETDATE() - 1);
		
	IF	@Debug = 1
	BEGIN;
		SELECT	@Msg = '
			@BalanceUpDay = ' + CONVERT(NVARCHAR, @BalanceUpDay, 120) + N'
			@MoveBetsDay  = ' + CONVERT(NVARCHAR, @MoveBetsDay, 120) + N'
			@Yesterday    = ' + CONVERT(NVARCHAR, @Yesterday, 120);

		-- Force the output to appear immediately --
		RAISERROR(@Msg, 0, 0) WITH NOWAIT;
	END;

	-- Initialize date range
	DECLARE @IsGetDataFromOrigin	BIT = 0
		,	@IsGetDataFrom14		BIT = 0
		,	@IsGetDataFromBK		BIT = 0;

	DECLARE @FromDateOrigin			SMALLDATETIME = NULL
		,	@ToDateOrigin			SMALLDATETIME = NULL
		,	@FromDate14				SMALLDATETIME = NULL
		,	@ToDate14				SMALLDATETIME = NULL
		,	@FromDateBK				SMALLDATETIME = NULL
		,	@ToDateBK				SMALLDATETIME = NULL
	
	-- No input date range: Default job run
	IF (@GenerateFromDate IS NULL OR @GenerateToDate IS NULL)
	BEGIN
		SELECT @GenerateToDate = @Yesterday;

		IF @BeforeMoveBetsDay = 1
		BEGIN
			SELECT @GenerateFromDate =	CASE WHEN (@MoveBetsDay - 3) > @BalanceUpDay 
											THEN (@MoveBetsDay - 3) 
										ELSE @BalanceUpDay END;
		END
		ELSE
		BEGIN
			SELECT @GenerateFromDate = @MoveBetsDay + 1;
		END
	END

	-- Return immediately if wrong date range
	IF @GenerateToDate < @GenerateFromDate
	BEGIN
		IF @Debug = 1
		BEGIN
			SELECT	@Msg = 'GenerateToDate < GenerateFromDate: Unacceptable!';

			-- Force the output to appear immediately --
			RAISERROR(@Msg, 0, 0) WITH NOWAIT;
		END;

		RETURN;
	END;

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

	IF @IsGetDataFromBK = 1
	BEGIN
		
		SELECT @Date = '@FromDateBK = ' + CONVERT(NVARCHAR, @FromDateBK, 120) + ', @ToDateBK = ' + CONVERT(NVARCHAR, @ToDateBK, 120);

		INSERT INTO	#tmpTrader2 (CustId, MatchId, EventDate, BetType, SpecialType)
		SELECT	DISTINCT
				[CustId]		= a.OperatorID
			,	[MatchId]		= m.MatchId
			,	[EventDate]		= m.EventDate
			,	[BetType]		= CASE	WHEN (a.BetType = 1 OR a.BetType = 5) AND a.OperatorType = 1
											THEN 1
										WHEN a.BetType = 1 AND a.OperatorType = 2
											THEN 7
										WHEN a.BetType = 2 AND a.OperatorType = 1
											THEN 3
										WHEN a.BetType = 2 AND a.OperatorType = 2
											THEN 8
										ELSE 0
									END
			,	[SpecialType]	= CASE	WHEN LeagueName LIKE '%SPECIFIC 15 MINS TOTAL BOOKINGS%'
											THEN 1
										WHEN LeagueName LIKE '%SPECIFIC 15 MINS%' AND t.TeamName LIKE '%No.of Corners%'
											THEN 2
										WHEN LeagueName LIKE '%SPECIALS' AND (t.TeamName LIKE '%Over' OR t.TeamName LIKE '%Under')
											THEN 3
										WHEN LeagueName LIKE '%SPECIFIC 15 MINS%'
											THEN 4
										WHEN LeagueName LIKE '%SPECIFIC 10 MINS%'
											THEN 5
										WHEN t.TeamName LIKE '%No.of Corners%'
											THEN 6
										WHEN t.TeamName LIKE '%Total Bookings'
											THEN 7
										WHEN t.TeamName LIKE '%Corner%'
											THEN 8
										WHEN t.TeamName LIKE '%Booking'
											THEN 9
										ELSE 0
									END
		FROM		DBARC.bodb_Archive.dbo.Dot_admin_Assignment_Operator_bk AS a WITH (NOLOCK)
		INNER JOIN	DBARC.bodb_Archive.dbo.Match_bk AS m WITH (NOLOCK)
				ON	a.matchid = m.matchid
		LEFT JOIN	bodb02.dbo.Team AS t WITH (NOLOCK)
				ON	m.homeid = t.teamid
		LEFT JOIN	bodb02.dbo.League AS l WITH (NOLOCK)
				ON	m.leagueid = l.leagueid
		WHERE	m.EventDate BETWEEN @FromDateBK AND @ToDateBK
			AND	m.EventStatus = 'completed'
			AND	m.SportType = 1
			AND	a.OperatorType < 3
			AND	m.MatchCode NOT LIKE '%hedge%';
		
		SELECT	@RowCount	= @@ROWCOUNT
			,	@Duration	= DATEDIFF(millisecond, @Begin, GETDATE())
			;

		IF	@Debug = 1
		BEGIN
			-- Force the output to appear immediately
			RAISERROR('From BK - Insert #tmpTrader2 - Date: "%s" - %d rows - %d ms', 0, 0, @Date, @RowCount, @Duration) WITH NOWAIT;
		END;
		
		INSERT INTO	#winlostdate (winlostdate)
		SELECT	tally.winlostdate
		FROM	(
			SELECT	'NoDays' = DATEDIFF(DAY, @FromDateBK, @ToDateBK) + 1
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
			RAISERROR('From BK - Insert #winlostdate - Date: "%s" - %d rows - %d ms', 0, 0, @Date, @RowCount, @Duration) WITH NOWAIT;
		END;

		-- SUM(ExtraPT)
		TRUNCATE TABLE	#ExtraPTSportbook;
		INSERT INTO #ExtraPTSportbook
		SELECT SuperId, SUM(ExtraPT) AS ExtraPT, FromDate, ToDate
		FROM
		(
			SELECT SuperId, ExtraPT, FromDate, ToDate
			FROM bodb02.dbo.Acc_GroupExtraPTSetting WITH (NOLOCK)
			WHERE
				(
					@FromDateBK BETWEEN FromDate AND ToDate
					OR @ToDateBK BETWEEN FromDate AND ToDate
				)
				AND ProductId = 1 AND Sporttype = 0 AND SubProduct = ''
		) A
		GROUP BY SuperId, FromDate, ToDate;
		
		WHILE	EXISTS (SELECT 1 FROM #winlostdate)
		BEGIN;
			SELECT	TOP(1)
					@WinLostDate = d.winlostdate
			FROM	#winlostdate AS d WITH (NOLOCK);

			SELECT @Date = CONVERT(NVARCHAR, @WinLostDate, 120);

			-- Insert data into batch by Date
			INSERT INTO #tmpFilteredBettransBKByBatch2 (transid, matchid, winlostdate, bettype, modds, virtualrate, actualrate, 
			tpositiontaking, scomm, betteam, odds, statusID, ExtraPT, ScoreHDP, StakeMY, Stake)
			SELECT	[transid]			= b.transid
				,	[matchid]			= b.matchid
				,	[winlostdate]		= b.winlostdate
				,	[bettype]			= b.bettype
				,	[modds]				= b.modds
				,	[virtualrate]		= b.virtualrate
				,	[actualrate]		= b.actualrate
				,	[tpositiontaking]	= b.tpositiontaking
				,	[scomm]				= b.scomm
				,	[betteam]			= b.betteam
				,	[odds]				= b.odds
				,	[statusID]			= b.statusID
				,	[ExtraPT]			= CASE WHEN m.eventdate < '20170221' THEN 0 ELSE es.ExtraPT END
				,	[ScoreHDP]			= CASE	WHEN b.bettype IN (1, 7) THEN (b.hdp1 + b.livehomescore) - (b.hdp2 + b.liveawayscore)
												ELSE b.hdp1
											END
				,	[StakeMY]			= CASE WHEN ABS(b.odds) <= 1 THEN 1 ELSE ABS(b.odds) END
										* CASE WHEN ABS(b.modds) = 0.25 THEN 0.5 ELSE 1 END
										* ABS(b.stake)
				,	[Stake]				= CASE WHEN ABS(b.modds) = 0.25 THEN 0.5 ELSE 1 END
										* ABS(b.stake)
			FROM		DBARC.bodb_Archive.dbo.bettrans_bk AS b WITH (NOLOCK)
			INNER JOIN	DBARC.bodb_Archive.dbo.match_bk AS m WITH (NOLOCK)
					ON	b.matchid = m.matchid
			LEFT JOIN	#ExtraPTSportbook AS es WITH (NOLOCK)
					ON	es.SuperId = b.srecommend
					AND	b.winlostdate BETWEEN es.FromDate AND es.ToDate
			WHERE	b.winlostdate = @winlostdate
				AND	b.bettype IN (1, 3, 7, 8)
				AND	b.statusID IN (112, 113)
				AND	b.Currency NOT IN (20, 27, 28)
				AND	b.LiveIndicator = 1
				AND	m.SportType = 1
				AND	m.MatchCode NOT LIKE '%hedge%';
			
			SELECT	@RowCount	= @@ROWCOUNT
				,	@Duration	= DATEDIFF(millisecond, @Begin, GETDATE())
				;
			
			IF	@Debug = 1
			BEGIN
				-- Force the output to appear immediately
				RAISERROR('From BK - Insert #tmpFilteredBettransBKByBatch2 - Date: "%s" - %d rows - %d ms', 0, 0, @Date, @RowCount, @Duration) WITH NOWAIT;
			END;

			-- Staging Performance 
			INSERT INTO #tmpStagingTraderPerformance2 (CustId, EventDate, MatchId, BetType, BetTeam, ScoreHDP, Odds, StakeMY, Stake, 
			ExtraPT, TPositionTaking, VirtualRate, ActualRate, Scomm, MOdds, StatusID)
			SELECT	[CustId]			= ISNULL(t.Custid, @IdForUnassignedTrader)
				,	[EventDate]			= b.winlostdate
				,	[MatchId]			= b.matchid
				,	[BetType]			= ca.BetType
				,	[BetTeam]			= b.betteam
				,	[ScoreHDP]			= b.ScoreHDP
				,	[Odds]				= b.odds
				,	[StakeMY]			= b.StakeMY
				,	[Stake]				= b.Stake
				,	[ExtraPT]			= ISNULL(b.ExtraPT, 0)
				,	[TPositionTaking]	= b.tpositiontaking
				,	[VirtualRate]		= b.virtualrate
				,	[ActualRate]		= b.actualrate
				,	[Scomm]				= b.scomm
				,	[MOdds]				= b.modds
				,	[StatusID]			= b.statusID
			FROM		#tmpFilteredBettransBKByBatch2 AS b WITH(NOLOCK)
			LEFT JOIN	#tmpTrader2 AS t WITH (NOLOCK)
					ON	b.winlostdate = t.EventDate
					AND	b.matchid = t.matchid
					AND	b.BetType = t.BetType
			CROSS APPLY	(
				SELECT	[BetType]		= CASE	WHEN b.BetType = 1 AND SpecialType = 0
													THEN 1 --HDP
												WHEN b.BetType = 7
													THEN 7 --1st HDP
												WHEN b.BetType = 3 AND SpecialType = 0
													THEN 3 --O/U		
												WHEN b.BetType = 8 AND SpecialType = 0
													THEN 8 --1st O/U
												WHEN b.BetType = 1 AND SpecialType = 4
													THEN -1 --15mins HDP
												WHEN b.BetType = 1 AND SpecialType = 8
													THEN -2 --Next Corner
												WHEN b.BetType = 1 AND SpecialType = 5
													THEN -15 --10mins HDP
												WHEN b.BetType = 1 AND SpecialType = 9
													THEN -3 --Next Booking
												WHEN b.BetType = 3 AND SpecialType = 4
													THEN -5 --15mins O/U
												WHEN b.BetType = 3 AND SpecialType = 5
													THEN -6 --10mins O/U
												WHEN b.BetType = 3 AND SpecialType = 2
													THEN -7 --Corners 15mins O/U
												WHEN b.BetType = 3 AND SpecialType = 7
													THEN -8 --Total Bookings
												WHEN b.BetType = 1 AND SpecialType = 1
													THEN - 37 --Total Bookings 15mins HDP
												WHEN b.BetType = 3 AND SpecialType = 1
													THEN -10 --Total Bookings 15mins O/U
												WHEN b.BetType = 3 AND SpecialType = 6
													THEN -13 --No. of Corner
												WHEN b.BetType = 8 AND SpecialType = 6
													THEN -12 --1st No. of Corner
												WHEN b.BetType = 8 AND SpecialType = 7
													THEN -9 --1st TotalBookings
												WHEN (b.BetType = 3 OR b.BetType = 8) AND SpecialType = 3
													THEN -11 --Single Team O/U
												ELSE b.BetType
											END
			) AS ca
			WHERE	b.winlostdate = @WinLostDate
			GROUP BY	ISNULL(t.Custid, @IdForUnassignedTrader)
					,	b.winlostdate
					,	b.matchid
					,	ca.BetType
					,	b.betteam
					,	b.ScoreHDP
					,	b.odds
					,	b.StakeMY
					,	b.Stake
					,	ISNULL(b.ExtraPT, 0)
					,	b.tpositiontaking
					,	b.virtualrate
					,	b.actualrate
					,	b.scomm
					,	b.modds
					,	b.statusID
					,	b.transid -- should not be removed since there is a case that extraPT is changed in the range of time --> duplicate row
			OPTION (MAXDOP 2);

			SELECT	@RowCount	= @@ROWCOUNT
				,	@Duration	= DATEDIFF(millisecond, @Begin, GETDATE())
				;
			
			IF	@Debug = 1
			BEGIN
				-- Force the output to appear immediately
				RAISERROR('From BK - Insert #tmpStagingTraderPerformance2 - Date: "%s" - %d rows - %d ms', 0, 0, @Date, @RowCount, @Duration) WITH NOWAIT;
			END;

			INSERT INTO #tmpDataGroup (CustId, EventDate, MatchId, BetType, BetTeam, ScoreHDP, MOdds, StatusID, AVGOdds, StakeMYBeforeComm, StakeMY, Stake, 
				AVGOdds_AR, StakeMYBeforeComm_AR, StakeMY_AR, Stake_AR)
			SELECT	[CustId]			= t.CustId
				,	[EventDate]			= t.EventDate
				,	[MatchId]			= t.MatchId
				,	[BetType]			= t.BetType
				,	[BetTeam]			= t.BetTeam
				,	[ScoreHDP]			= t.ScoreHDP
				,	[MOdds]				= t.MOdds
				,	[StatusID]			= t.StatusID
				,	[AVGOdds]			= SUM((CASE WHEN t.Odds < 0 THEN 1 ELSE t.Odds END) * ABS(t.Stake) * (1 - t.TPositionTaking - t.ExtraPT) * t.VirtualRate)
										/ SUM((CASE WHEN t.Odds < 0 THEN -t.Odds ELSE 1 END) * ABS(t.Stake) * (1 - t.TPositionTaking - t.ExtraPT) * t.VirtualRate)
										--TotalWin/TotalLose
				,	[StakeMYBeforeComm]	= SUM(t.StakeMY * (1 - t.TPositionTaking - t.ExtraPT) * t.VirtualRate)
				,	[StakeMY]			= SUM(t.StakeMY * (1 - t.TPositionTaking - t.ExtraPT) * t.VirtualRate - (t.Scomm - CASE WHEN t.TPositionTaking = 1 THEN 0 ELSE t.Scomm * t.ExtraPT / (1 - t.TPositionTaking) END) * (CASE WHEN t.VirtualRate > t.ActualRate THEN t.ActualRate ELSE t.VirtualRate END))
				,	[Stake]				= SUM(CASE WHEN t.Odds < 0 THEN -t.Odds ELSE 1 END * ABS(t.Stake) * (1 - t.TPositionTaking - t.ExtraPT) * t.VirtualRate - (t.Scomm - CASE WHEN t.TPositionTaking = 1 THEN 0 ELSE t.Scomm * t.ExtraPT / (1 - t.TPositionTaking) END) * (CASE WHEN t.VirtualRate > t.ActualRate THEN t.ActualRate ELSE t.VirtualRate END))
				
				,	[AVGOdds_AR]		= SUM((CASE WHEN t.Odds < 0 THEN 1 ELSE t.Odds END) * ABS(t.Stake) * (1 - t.TPositionTaking - t.ExtraPT) * (CASE WHEN t.VirtualRate > t.ActualRate THEN t.VirtualRate ELSE t.ActualRate END))
										/ SUM((CASE WHEN t.Odds < 0 THEN -t.Odds ELSE 1 END) * ABS(t.Stake) * (1 - t.TPositionTaking - t.ExtraPT) * (CASE WHEN t.VirtualRate > t.ActualRate THEN t.VirtualRate ELSE t.ActualRate END))
										--TotalWin/TotalLose
				,	[StakeMYBeforeComm_AR]	= SUM(t.StakeMY * (1 - t.TPositionTaking - t.ExtraPT) * (CASE WHEN t.VirtualRate > t.ActualRate THEN t.VirtualRate ELSE t.ActualRate END))
				,	[StakeMY_AR]		= SUM(t.StakeMY * (1 - t.TPositionTaking - t.ExtraPT) * (CASE WHEN t.VirtualRate > t.ActualRate THEN t.VirtualRate ELSE t.ActualRate END) - (t.Scomm - CASE WHEN t.TPositionTaking = 1 THEN 0 ELSE t.Scomm * t.ExtraPT / (1 - t.TPositionTaking) END) * t.ActualRate)
				,	[Stake_AR]			= SUM(CASE WHEN t.Odds < 0 THEN -t.Odds ELSE 1 END * ABS(t.Stake) * (1 - t.TPositionTaking - t.ExtraPT) * (CASE WHEN t.VirtualRate > t.ActualRate THEN t.VirtualRate ELSE t.ActualRate END) - (t.Scomm - CASE WHEN t.TPositionTaking = 1 THEN 0 ELSE t.Scomm * t.ExtraPT / (1 - t.TPositionTaking) END) * t.ActualRate)
			FROM	#tmpStagingTraderPerformance2 AS t WITH(NOLOCK)
			GROUP BY CustId, EventDate, MatchId, BetType, BetTeam, ScoreHDP, MOdds, StatusID;
		
			SELECT	@RowCount	= @@ROWCOUNT
				,	@Duration	= DATEDIFF(millisecond, @Begin, GETDATE())
				;

			IF	@Debug = 1
			BEGIN
				-- Force the output to appear immediately
				RAISERROR('From BK - Insert #tmpDataGroup - Date: "%s" - %d rows - %d ms', 0, 0, @Date, @RowCount, @Duration) WITH NOWAIT;
			END;

			DELETE	d
			FROM	#winlostdate AS d
			WHERE	d.winlostdate = @WinLostDate;
						
			SELECT	@RowCount	= @@ROWCOUNT
				,	@Duration	= DATEDIFF(millisecond, @Begin, GETDATE())
				;

			IF	@Debug = 1
			BEGIN
				-- Force the output to appear immediately
				RAISERROR('From BK - DELETE #winlostdate - Date: "%s" - %d rows - %d ms', 0, 0, @Date, @RowCount, @Duration) WITH NOWAIT;
			END;

			TRUNCATE TABLE	#tmpStagingTraderPerformance2;
			TRUNCATE TABLE	#tmpFilteredBettransBKByBatch2;
		END;
	END;

	IF	@IsGetDataFrom14 = 1
	BEGIN	
		TRUNCATE TABLE	#winlostdate;
		TRUNCATE TABLE	#tmpTrader2;
		TRUNCATE TABLE	#tmpStagingTraderPerformance2;
		TRUNCATE TABLE	#tmpFilteredBettransBKByBatch2;
		
		SELECT @Date = '@FromDate14 = ' + CONVERT(NVARCHAR, @FromDate14, 120) + ', @ToDate14 = ' + CONVERT(NVARCHAR, @ToDate14, 120);

		INSERT INTO	#tmpTrader2 (CustId, MatchId, EventDate, BetType, SpecialType)
		SELECT	DISTINCT
				[CustId]		= a.OperatorID
			,	[MatchId]		= m.MatchId
			,	[EventDate]		= m.EventDate
			,	[BetType]		= CASE	WHEN (a.BetType = 1 OR a.BetType = 5) AND a.OperatorType = 1
											THEN 1
										WHEN a.BetType = 1 AND a.OperatorType = 2
											THEN 7
										WHEN a.BetType = 2 AND a.OperatorType = 1
											THEN 3
										WHEN a.BetType = 2 AND a.OperatorType = 2
											THEN 8
										ELSE 0
									END
			,	[SpecialType]	= CASE	WHEN LeagueName LIKE '%SPECIFIC 15 MINS TOTAL BOOKINGS%'
											THEN 1
										WHEN LeagueName LIKE '%SPECIFIC 15 MINS%' AND t.TeamName LIKE '%No.of Corners%'
											THEN 2
										WHEN LeagueName LIKE '%SPECIALS' AND (t.TeamName LIKE '%Over' OR t.TeamName LIKE '%Under')
											THEN 3
										WHEN LeagueName LIKE '%SPECIFIC 15 MINS%'
											THEN 4
										WHEN LeagueName LIKE '%SPECIFIC 10 MINS%'
											THEN 5
										WHEN t.TeamName LIKE '%No.of Corners%'
											THEN 6
										WHEN t.TeamName LIKE '%Total Bookings'
											THEN 7
										WHEN t.TeamName LIKE '%Corner%'
											THEN 8
										WHEN t.TeamName LIKE '%Booking'
											THEN 9
										ELSE 0
									END
		FROM		DBARC.bodb_archive.dbo.Dot_Admin_Assignment_Operator_bk AS a WITH (NOLOCK)
		INNER JOIN	bodb02.dbo.Match14 AS m WITH (NOLOCK)
				ON	a.matchid = m.matchid
		LEFT JOIN	bodb02.dbo.Team AS t WITH (NOLOCK)
				ON	m.homeid = t.teamid
		LEFT JOIN	bodb02.dbo.League l WITH (NOLOCK)
				ON	m.leagueid = l.leagueid
		WHERE	m.EventDate BETWEEN @FromDate14 AND @ToDate14
			AND	m.SportType = 1
			AND	a.OperatorType < 3
			AND	m.MatchCode NOT LIKE '%hedge%';
			
		SELECT	@RowCount	= @@ROWCOUNT
			,	@Duration	= DATEDIFF(millisecond, @Begin, GETDATE())
			;

		IF	@Debug = 1
		BEGIN
			-- Force the output to appear immediately
			RAISERROR('From 14 - Insert #tmpTrader2 - Date: "%s" - %d rows - %d ms', 0, 0, @Date, @RowCount, @Duration) WITH NOWAIT;
		END;

		INSERT INTO	#winlostdate (winlostdate)
		SELECT	tally.winlostdate
		FROM	(
			SELECT	'NoDays' = DATEDIFF(DAY, @FromDate14, @ToDate14) + 1
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
			RAISERROR('From 14 - Insert #winlostdate - Date: "%s" - %d rows - %d ms', 0, 0, @Date, @RowCount, @Duration) WITH NOWAIT;
		END;

		-- SUM(ExtraPT)
		TRUNCATE TABLE	#ExtraPTSportbook;
		INSERT INTO #ExtraPTSportbook
		SELECT SuperId, SUM(ExtraPT) AS ExtraPT, FromDate, ToDate
		FROM
		(
			SELECT SuperId, ExtraPT, FromDate, ToDate
			FROM bodb02.dbo.Acc_GroupExtraPTSetting WITH (NOLOCK)
			WHERE
				(
					@FromDate14 BETWEEN FromDate AND ToDate
					OR @ToDate14 BETWEEN FromDate AND ToDate
				)
				AND ProductId = 1 AND Sporttype = 0 AND SubProduct = ''
		) A
		GROUP BY SuperId, FromDate, ToDate;

		WHILE	EXISTS (SELECT 1 FROM #winlostdate)
		BEGIN;
			SELECT	TOP(1)
					@WinLostDate = d.winlostdate
			FROM	#winlostdate AS d WITH (NOLOCK);

			SELECT @Date = CONVERT(NVARCHAR, @WinLostDate, 120);

			-- Insert data into batch by Date
			INSERT INTO #tmpFilteredBettransBKByBatch2 (transid, matchid, winlostdate, bettype, modds, virtualrate, actualrate, 
			tpositiontaking, scomm, betteam, odds, statusID, ExtraPT, ScoreHDP, StakeMY, Stake)
			SELECT	[transid]			= b.transid
				,	[MatchId]			= b.matchid
				,	[winlostdate]		= b.winlostdate
				,	[BetType]			= b.bettype
				,	[MOdds]				= b.modds
				,	[VirtualRate]		= b.virtualrate
				,	[actualrate]		= b.actualrate
				,	[TPositionTaking]	= b.tpositiontaking
				,	[Scomm]				= b.scomm
				,	[BetTeam]			= b.betteam
				,	[Odds]				= b.odds
				,	[StatusID]			= b.statusID
				,	[ExtraPT]			= CASE WHEN m.eventdate < '20170221' THEN 0 ELSE es.ExtraPT END
				,	[ScoreHDP]			= CASE	WHEN b.bettype IN (1, 7) THEN (b.hdp1 + b.livehomescore) - (b.hdp2 + b.liveawayscore)
												ELSE b.hdp1
											END
				,	[StakeMY]			= CASE WHEN ABS(b.odds) <= 1 THEN 1 ELSE ABS(b.odds) END
										* CASE WHEN ABS(b.modds) = 0.25 THEN 0.5 ELSE 1 END
										* ABS(b.stake)
				,	[Stake]				= CASE WHEN ABS(b.modds) = 0.25 THEN 0.5 ELSE 1 END
										* ABS(b.stake)
			FROM		bodb02.dbo.bettrans14 AS b WITH (NOLOCK)
			INNER JOIN	bodb02.dbo.Match14 AS m WITH (NOLOCK)
					ON	b.matchid = m.matchid
			LEFT JOIN	#ExtraPTSportbook AS es WITH (NOLOCK)
					ON	es.SuperId = b.srecommend
					AND	b.winlostdate BETWEEN es.FromDate AND es.ToDate
			WHERE	b.winlostdate = @WinLostDate
				AND	b.bettype IN (1, 3, 7, 8)
				AND	b.statusID IN (112, 113)
				AND	b.Currency NOT IN (20, 27, 28)
				AND	b.LiveIndicator = 1
				AND	m.SportType = 1
				AND	m.MatchCode NOT LIKE '%hedge%';
			
			SELECT	@RowCount	= @@ROWCOUNT
				,	@Duration	= DATEDIFF(millisecond, @Begin, GETDATE())
				;

			IF	@Debug = 1
			BEGIN
				-- Force the output to appear immediately
				RAISERROR('From 14 - Insert #tmpFilteredBettransBKByBatch2 - Date: "%s" - %d rows - %d ms', 0, 0, @Date, @RowCount, @Duration) WITH NOWAIT;
			END;

			-- Staging Performance 
			INSERT INTO #tmpStagingTraderPerformance2 (CustId, EventDate, MatchId, BetType, BetTeam, ScoreHDP, Odds, StakeMY, Stake, 
			ExtraPT, TPositionTaking, VirtualRate, ActualRate, Scomm, MOdds, StatusID)
			SELECT	[CustId]			= ISNULL(t.Custid, @IdForUnassignedTrader)
				,	[EventDate]			= b.winlostdate
				,	[MatchId]			= b.matchid
				,	[BetType]			= ca.BetType
				,	[BetTeam]			= b.betteam
				,	[ScoreHDP]			= b.ScoreHDP
				,	[Odds]				= b.odds
				,	[StakeMY]			= b.StakeMY
				,	[Stake]				= b.Stake
				,	[ExtraPT]			= ISNULL(b.ExtraPT, 0)
				,	[TPositionTaking]	= b.tpositiontaking
				,	[VirtualRate]		= b.virtualrate
				,	[ActualRate]		= b.actualrate
				,	[Scomm]				= b.scomm
				,	[MOdds]				= b.modds
				,	[StatusID]			= b.statusID
			FROM		#tmpFilteredBettransBKByBatch2 AS b WITH(NOLOCK)
			LEFT JOIN	#tmpTrader2 AS t WITH (NOLOCK)
					ON	b.winlostdate = t.EventDate
					AND	b.matchid = t.matchid
					AND	b.BetType = t.BetType
			CROSS APPLY	(
				SELECT	[BetType]		= CASE	WHEN b.BetType = 1 AND SpecialType = 0
													THEN 1 --HDP
												WHEN b.BetType = 7
													THEN 7 --1st HDP
												WHEN b.BetType = 3 AND SpecialType = 0
													THEN 3 --O/U		
												WHEN b.BetType = 8 AND SpecialType = 0
													THEN 8 --1st O/U
												WHEN b.BetType = 1 AND SpecialType = 4
													THEN -1 --15mins HDP
												WHEN b.BetType = 1 AND SpecialType = 8
													THEN -2 --Next Corner
												WHEN b.BetType = 1 AND SpecialType = 5
													THEN -15 --10mins HDP
												WHEN b.BetType = 1 AND SpecialType = 9
													THEN -3 --Next Booking
												WHEN b.BetType = 3 AND SpecialType = 4
													THEN -5 --15mins O/U
												WHEN b.BetType = 3 AND SpecialType = 5
													THEN -6 --10mins O/U
												WHEN b.BetType = 3 AND SpecialType = 2
													THEN -7 --Corners 15mins O/U
												WHEN b.BetType = 3 AND SpecialType = 7
													THEN -8 --Total Bookings
												WHEN b.BetType = 1 AND SpecialType = 1
													THEN - 37 --Total Bookings 15mins HDP
												WHEN b.BetType = 3 AND SpecialType = 1
													THEN -10 --Total Bookings 15mins O/U
												WHEN b.BetType = 3 AND SpecialType = 6
													THEN -13 --No. of Corner
												WHEN b.BetType = 8 AND SpecialType = 6
													THEN -12 --1st No. of Corner
												WHEN b.BetType = 8 AND SpecialType = 7
													THEN -9 --1st TotalBookings
												WHEN (b.BetType = 3 OR b.BetType = 8) AND SpecialType = 3
													THEN -11 --Single Team O/U
												ELSE b.BetType
											END
			) AS ca
			WHERE	b.winlostdate = @winlostdate
			GROUP BY	ISNULL(t.Custid, @IdForUnassignedTrader)
					,	b.winlostdate
					,	b.matchid
					,	ca.BetType
					,	b.betteam
					,	b.ScoreHDP
					,	b.odds
					,	b.StakeMY
					,	b.Stake
					,	ISNULL(b.ExtraPT, 0)
					,	b.tpositiontaking
					,	b.virtualrate
					,	b.actualrate
					,	b.scomm
					,	b.modds
					,	b.statusID
					,	b.transid -- should not be removed since there is a case that extraPT is changed in the range of time --> duplicate row
			OPTION (MAXDOP 2);
			
			SELECT	@RowCount	= @@ROWCOUNT
				,	@Duration	= DATEDIFF(millisecond, @Begin, GETDATE())
				;

			IF	@Debug = 1
			BEGIN
				-- Force the output to appear immediately
				RAISERROR('From 14 - Insert #tmpStagingTraderPerformance2 - Date: "%s" - %d rows - %d ms', 0, 0, @Date, @RowCount, @Duration) WITH NOWAIT;
			END;

			INSERT INTO #tmpDataGroup (CustId, EventDate, MatchId, BetType, BetTeam, ScoreHDP, MOdds, StatusID, AVGOdds, StakeMYBeforeComm, StakeMY, Stake, 
				AVGOdds_AR, StakeMYBeforeComm_AR, StakeMY_AR, Stake_AR)
			SELECT	[CustId]			= t.CustId
				,	[EventDate]			= t.EventDate
				,	[MatchId]			= t.MatchId
				,	[BetType]			= t.BetType
				,	[BetTeam]			= t.BetTeam
				,	[ScoreHDP]			= t.ScoreHDP
				,	[MOdds]				= t.MOdds
				,	[StatusID]			= t.StatusID
				,	[AVGOdds]			= SUM((CASE WHEN t.Odds < 0 THEN 1 ELSE t.Odds END) * ABS(t.Stake) * (1 - t.TPositionTaking - t.ExtraPT) * t.VirtualRate)
										/ SUM((CASE WHEN t.Odds < 0 THEN -t.Odds ELSE 1 END) * ABS(t.Stake) * (1 - t.TPositionTaking - t.ExtraPT) * t.VirtualRate)
										--TotalWin/TotalLose
				,	[StakeMYBeforeComm]	= SUM(t.StakeMY * (1 - t.TPositionTaking - t.ExtraPT) * t.VirtualRate)
				,	[StakeMY]			= SUM(t.StakeMY * (1 - t.TPositionTaking - t.ExtraPT) * t.VirtualRate - (t.Scomm - CASE WHEN t.TPositionTaking = 1 THEN 0 ELSE t.Scomm * t.ExtraPT / (1 - t.TPositionTaking) END) * (CASE WHEN t.VirtualRate > t.ActualRate THEN t.ActualRate ELSE t.VirtualRate END))
				,	[Stake]				= SUM(CASE WHEN t.Odds < 0 THEN -t.Odds ELSE 1 END * ABS(t.Stake) * (1 - t.TPositionTaking - t.ExtraPT) * t.VirtualRate - (t.Scomm - CASE WHEN t.TPositionTaking = 1 THEN 0 ELSE t.Scomm * t.ExtraPT / (1 - t.TPositionTaking) END) * (CASE WHEN t.VirtualRate > t.ActualRate THEN t.ActualRate ELSE t.VirtualRate END))
				
				,	[AVGOdds_AR]		= SUM((CASE WHEN t.Odds < 0 THEN 1 ELSE t.Odds END) * ABS(t.Stake) * (1 - t.TPositionTaking - t.ExtraPT) * (CASE WHEN t.VirtualRate > t.ActualRate THEN t.VirtualRate ELSE t.ActualRate END))
										/ SUM((CASE WHEN t.Odds < 0 THEN -t.Odds ELSE 1 END) * ABS(t.Stake) * (1 - t.TPositionTaking - t.ExtraPT) * (CASE WHEN t.VirtualRate > t.ActualRate THEN t.VirtualRate ELSE t.ActualRate END))
										--TotalWin/TotalLose
				,	[StakeMYBeforeComm_AR]	= SUM(t.StakeMY * (1 - t.TPositionTaking - t.ExtraPT) * (CASE WHEN t.VirtualRate > t.ActualRate THEN t.VirtualRate ELSE t.ActualRate END))
				,	[StakeMY_AR]		= SUM(t.StakeMY * (1 - t.TPositionTaking - t.ExtraPT) * (CASE WHEN t.VirtualRate > t.ActualRate THEN t.VirtualRate ELSE t.ActualRate END) - (t.Scomm - CASE WHEN t.TPositionTaking = 1 THEN 0 ELSE t.Scomm * t.ExtraPT / (1 - t.TPositionTaking) END) * t.ActualRate)
				,	[Stake_AR]			= SUM(CASE WHEN t.Odds < 0 THEN -t.Odds ELSE 1 END * ABS(t.Stake) * (1 - t.TPositionTaking - t.ExtraPT) * (CASE WHEN t.VirtualRate > t.ActualRate THEN t.VirtualRate ELSE t.ActualRate END) - (t.Scomm - CASE WHEN t.TPositionTaking = 1 THEN 0 ELSE t.Scomm * t.ExtraPT / (1 - t.TPositionTaking) END) * t.ActualRate)
			FROM	#tmpStagingTraderPerformance2 AS t WITH(NOLOCK)
			GROUP BY CustId, EventDate, MatchId, BetType, BetTeam, ScoreHDP, MOdds, StatusID;
			
			SELECT	@RowCount	= @@ROWCOUNT
				,	@Duration	= DATEDIFF(millisecond, @Begin, GETDATE())
				;

			IF	@Debug = 1
			BEGIN
				-- Force the output to appear immediately
				RAISERROR('From 14 - Insert #tmpDataGroup - Date: "%s" - %d rows - %d ms', 0, 0, @Date, @RowCount, @Duration) WITH NOWAIT;
			END;

			DELETE	d
			FROM	#winlostdate AS d
			WHERE	d.winlostdate = @WinLostDate;
						
			SELECT	@RowCount	= @@ROWCOUNT
				,	@Duration	= DATEDIFF(millisecond, @Begin, GETDATE())
				;

			
			IF	@Debug = 1
			BEGIN
				-- Force the output to appear immediately
				RAISERROR('From 14 - DELETE #winlostdate - Date: "%s" - %d rows - %d ms', 0, 0, @Date, @RowCount, @Duration) WITH NOWAIT;
			END;

			TRUNCATE TABLE	#tmpStagingTraderPerformance2;
			TRUNCATE TABLE	#tmpFilteredBettransBKByBatch2;
		END;
	END;

	IF	@IsGetDataFromOrigin = 1
	BEGIN
		TRUNCATE TABLE	#winlostdate;
		TRUNCATE TABLE	#tmpTrader2;
		TRUNCATE TABLE	#tmpStagingTraderPerformance2;
		TRUNCATE TABLE	#tmpFilteredBettransBKByBatch2;
		
		SELECT @Date = '@FromDateOrigin = ' + CONVERT(NVARCHAR, @FromDateOrigin, 120) + ', @ToDateOrigin = ' + CONVERT(NVARCHAR, @ToDateOrigin, 120);

		INSERT INTO	#tmpTrader2 (CustId, MatchId, EventDate, BetType, SpecialType)
		SELECT	DISTINCT
				[CustId]		= a.OperatorID
			,	[MatchId]		= m.MatchId
			,	[EventDate]		= m.EventDate
			,	[BetType]		= CASE	WHEN (a.BetType = 1 OR a.BetType = 5) AND a.OperatorType = 1
											THEN 1
										WHEN a.BetType = 1 AND a.OperatorType = 2
											THEN 7
										WHEN a.BetType = 2 AND a.OperatorType = 1
											THEN 3
										WHEN a.BetType = 2 AND a.OperatorType = 2
											THEN 8
										ELSE 0
									END
			,	[SpecialType]	= CASE	WHEN LeagueName LIKE '%SPECIFIC 15 MINS TOTAL BOOKINGS%'
											THEN 1
										WHEN LeagueName LIKE '%SPECIFIC 15 MINS%' AND t.TeamName LIKE '%No.of Corners%'
											THEN 2
										WHEN LeagueName LIKE '%SPECIALS' AND (t.TeamName LIKE '%Over' OR t.TeamName LIKE '%Under')
											THEN 3
										WHEN LeagueName LIKE '%SPECIFIC 15 MINS%'
											THEN 4
										WHEN LeagueName LIKE '%SPECIFIC 10 MINS%'
											THEN 5
										WHEN t.TeamName LIKE '%No.of Corners%'
											THEN 6
										WHEN t.TeamName LIKE '%Total Bookings'
											THEN 7
										WHEN t.TeamName LIKE '%Corner%'
											THEN 8
										WHEN t.TeamName LIKE '%Booking'
											THEN 9
										ELSE 0
									END
		FROM		bodb02.dbo.Dot_admin_Assignment_Operator AS a WITH (NOLOCK)
		INNER JOIN	bodb02.dbo.Match AS m WITH (NOLOCK)
				ON	a.matchid = m.matchid
		LEFT JOIN	bodb02.dbo.Team AS t WITH (NOLOCK)
				ON	m.homeid = t.teamid
		LEFT JOIN	bodb02.dbo.League AS l WITH (NOLOCK)
				ON	m.leagueid = l.leagueid
		WHERE	m.EventDate BETWEEN @FromDateOrigin AND @ToDateOrigin
			AND	m.EventStatus = 'completed'
			AND	m.SportType = 1
			AND	a.OperatorType < 3
			AND	m.MatchCode NOT LIKE '%hedge%';
		
		SELECT	@RowCount	= @@ROWCOUNT
			,	@Duration	= DATEDIFF(millisecond, @Begin, GETDATE())
			;

		IF	@Debug = 1
		BEGIN
			-- Force the output to appear immediately
			RAISERROR('From Origin - Insert #tmpTrader2 - Date: "%s" - %d rows - %d ms', 0, 0, @Date, @RowCount, @Duration) WITH NOWAIT;
		END;

		INSERT INTO	#winlostdate (winlostdate)
		SELECT	tally.winlostdate
		FROM	(
			SELECT	'NoDays' = DATEDIFF(DAY, @FromDateOrigin, @ToDateOrigin) + 1
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
			RAISERROR('From Origin - Insert #winlostdate - Date: "%s" - %d rows - %d ms', 0, 0, @Date, @RowCount, @Duration) WITH NOWAIT;
		END;

		-- SUM(ExtraPT)
		TRUNCATE TABLE	#ExtraPTSportbook;
		INSERT INTO #ExtraPTSportbook
		SELECT SuperId, SUM(ExtraPT) AS ExtraPT, FromDate, ToDate
		FROM
		(
			SELECT SuperId, ExtraPT, FromDate, ToDate
			FROM bodb02.dbo.Acc_GroupExtraPTSetting WITH (NOLOCK)
			WHERE
				(
					@FromDateOrigin BETWEEN FromDate AND ToDate
					OR @ToDateOrigin BETWEEN FromDate AND ToDate
				)
				AND ProductId = 1 AND Sporttype = 0 AND SubProduct = ''
		) A
		GROUP BY SuperId, FromDate, ToDate;

		WHILE	EXISTS (SELECT 1 FROM #winlostdate)
		BEGIN;
			SELECT	TOP(1)
					@WinLostDate = d.winlostdate
			FROM	#winlostdate AS d WITH (NOLOCK);

			SELECT @Date = CONVERT(NVARCHAR, @WinLostDate, 120);

			-- Insert data into batch by Date
			INSERT INTO #tmpFilteredBettransBKByBatch2 (transid, matchid, winlostdate, bettype, modds, virtualrate, actualrate, 
			tpositiontaking, scomm, betteam, odds, statusID, ExtraPT, ScoreHDP, StakeMY, Stake)
			SELECT	[transid]			= b.transid
				,	[matchid]			= b.matchid
				,	[winlostdate]		= b.winlostdate
				,	[bettype]			= b.bettype
				,	[modds]				= b.modds
				,	[virtualrate]		= b.virtualrate
				,	[actualrate]		= b.actualrate
				,	[tpositiontaking]	= b.tpositiontaking
				,	[scomm]				= b.scomm
				,	[betteam]			= b.betteam
				,	[odds]				= b.odds
				,	[statusID]			= b.statusID
				,	[ExtraPT]			= CASE WHEN m.eventdate < '20170221' THEN 0 ELSE es.ExtraPT END
				,	[ScoreHDP]			= CASE	WHEN b.bettype IN (1, 7) THEN (b.hdp1 + b.livehomescore) - (b.hdp2 + b.liveawayscore)
												ELSE b.hdp1
											END
				,	[StakeMY]			= CASE WHEN ABS(b.odds) <= 1 THEN 1 ELSE ABS(b.odds) END
										* CASE WHEN ABS(b.modds) = 0.25 THEN 0.5 ELSE 1 END
										* ABS(b.stake)
				,	[Stake]				= CASE WHEN ABS(b.modds) = 0.25 THEN 0.5 ELSE 1 END
										* ABS(b.stake)
			FROM		bodb02.dbo.bettrans AS b WITH (NOLOCK)
			INNER JOIN	bodb02.dbo.Match AS m WITH (NOLOCK)
					ON	b.matchid = m.matchid
			LEFT JOIN	#ExtraPTSportbook AS es WITH (NOLOCK)
					ON	es.SuperId = b.srecommend
					AND	b.winlostdate BETWEEN es.FromDate AND es.ToDate
			WHERE	b.winlostdate = @winlostdate
				AND	b.bettype IN (1, 3, 7, 8)
				AND	b.statusID IN (112, 113)
				AND	b.Currency NOT IN (20, 27, 28)
				AND	b.LiveIndicator = 1
				AND	m.SportType = 1
				AND	m.MatchCode NOT LIKE '%hedge%';
			
			SELECT	@RowCount	= @@ROWCOUNT
				,	@Duration	= DATEDIFF(millisecond, @Begin, GETDATE())
				;

			IF	@Debug = 1
			BEGIN
				-- Force the output to appear immediately
				RAISERROR('From Origin - Insert #tmpFilteredBettransBKByBatch2 - Date: "%s" - %d rows - %d ms', 0, 0, @Date, @RowCount, @Duration) WITH NOWAIT;
			END;

			-- Staging Performance 
			INSERT INTO #tmpStagingTraderPerformance2 (CustId, EventDate, MatchId, BetType, BetTeam, ScoreHDP, Odds, StakeMY, Stake, 
			ExtraPT, TPositionTaking, VirtualRate, ActualRate, Scomm, MOdds, StatusID)
			SELECT	[CustId]			= ISNULL(t.Custid, @IdForUnassignedTrader)
				,	[EventDate]			= b.winlostdate
				,	[MatchId]			= b.matchid
				,	[BetType]			= ca.BetType
				,	[BetTeam]			= b.betteam
				,	[ScoreHDP]			= b.ScoreHDP
				,	[Odds]				= b.odds
				,	[StakeMY]			= b.StakeMY
				,	[Stake]				= b.Stake
				,	[ExtraPT]			= ISNULL(b.ExtraPT, 0)
				,	[TPositionTaking]	= b.tpositiontaking
				,	[VirtualRate]		= b.virtualrate
				,	[ActualRate]		= b.actualrate
				,	[Scomm]				= b.scomm
				,	[MOdds]				= b.modds
				,	[StatusID]			= b.statusID
			FROM		#tmpFilteredBettransBKByBatch2 AS b WITH(NOLOCK)
			LEFT JOIN	#tmpTrader2 AS t WITH (NOLOCK)
					ON	b.winlostdate = t.EventDate
					AND	b.matchid = t.matchid
					AND	b.BetType = t.BetType
			CROSS APPLY	(
				SELECT	[BetType]		= CASE	WHEN b.BetType = 1 AND SpecialType = 0
													THEN 1 --HDP
												WHEN b.BetType = 7
													THEN 7 --1st HDP
												WHEN b.BetType = 3 AND SpecialType = 0
													THEN 3 --O/U		
												WHEN b.BetType = 8 AND SpecialType = 0
													THEN 8 --1st O/U
												WHEN b.BetType = 1 AND SpecialType = 4
													THEN -1 --15mins HDP
												WHEN b.BetType = 1 AND SpecialType = 8
													THEN -2 --Next Corner
												WHEN b.BetType = 1 AND SpecialType = 5
													THEN -15 --10mins HDP
												WHEN b.BetType = 1 AND SpecialType = 9
													THEN -3 --Next Booking
												WHEN b.BetType = 3 AND SpecialType = 4
													THEN -5 --15mins O/U
												WHEN b.BetType = 3 AND SpecialType = 5
													THEN -6 --10mins O/U
												WHEN b.BetType = 3 AND SpecialType = 2
													THEN -7 --Corners 15mins O/U
												WHEN b.BetType = 3 AND SpecialType = 7
													THEN -8 --Total Bookings
												WHEN b.BetType = 1 AND SpecialType = 1
													THEN - 37 --Total Bookings 15mins HDP
												WHEN b.BetType = 3 AND SpecialType = 1
													THEN -10 --Total Bookings 15mins O/U
												WHEN b.BetType = 3 AND SpecialType = 6
													THEN -13 --No. of Corner
												WHEN b.BetType = 8 AND SpecialType = 6
													THEN -12 --1st No. of Corner
												WHEN b.BetType = 8 AND SpecialType = 7
													THEN -9 --1st TotalBookings
												WHEN (b.BetType = 3 OR b.BetType = 8) AND SpecialType = 3
													THEN -11 --Single Team O/U
												ELSE b.BetType
											END
			) AS ca
			WHERE	b.winlostdate = @WinLostDate
			GROUP BY	ISNULL(t.Custid, @IdForUnassignedTrader)
					,	b.winlostdate
					,	b.matchid
					,	ca.BetType
					,	b.betteam
					,	b.ScoreHDP
					,	b.odds
					,	b.StakeMY
					,	b.Stake
					,	ISNULL(b.ExtraPT, 0)
					,	b.tpositiontaking
					,	b.virtualrate
					,	b.actualrate
					,	b.scomm
					,	b.modds
					,	b.statusID
					,	b.transid -- should not be removed since there is a case that extraPT is changed in the range of time --> duplicate row
			OPTION (MAXDOP 2);
		
			SELECT	@RowCount	= @@ROWCOUNT
				,	@Duration	= DATEDIFF(millisecond, @Begin, GETDATE())
				;
			
			IF	@Debug = 1
			BEGIN
				-- Force the output to appear immediately
				RAISERROR('From Origin - Insert #tmpStagingTraderPerformance2 - Date: "%s" - %d rows - %d ms', 0, 0, @Date, @RowCount, @Duration) WITH NOWAIT;
			END;

			INSERT INTO #tmpDataGroup (CustId, EventDate, MatchId, BetType, BetTeam, ScoreHDP, MOdds, StatusID, AVGOdds, StakeMYBeforeComm, StakeMY, Stake, 
				AVGOdds_AR, StakeMYBeforeComm_AR, StakeMY_AR, Stake_AR)
			SELECT	[CustId]			= t.CustId
				,	[EventDate]			= t.EventDate
				,	[MatchId]			= t.MatchId
				,	[BetType]			= t.BetType
				,	[BetTeam]			= t.BetTeam
				,	[ScoreHDP]			= t.ScoreHDP
				,	[MOdds]				= t.MOdds
				,	[StatusID]			= t.StatusID
				,	[AVGOdds]			= SUM((CASE WHEN t.Odds < 0 THEN 1 ELSE t.Odds END) * ABS(t.Stake) * (1 - t.TPositionTaking - t.ExtraPT) * t.VirtualRate)
										/ SUM((CASE WHEN t.Odds < 0 THEN -t.Odds ELSE 1 END) * ABS(t.Stake) * (1 - t.TPositionTaking - t.ExtraPT) * t.VirtualRate)
										--TotalWin/TotalLose
				,	[StakeMYBeforeComm]	= SUM(t.StakeMY * (1 - t.TPositionTaking - t.ExtraPT) * t.VirtualRate)
				,	[StakeMY]			= SUM(t.StakeMY * (1 - t.TPositionTaking - t.ExtraPT) * t.VirtualRate - (t.Scomm - CASE WHEN t.TPositionTaking = 1 THEN 0 ELSE t.Scomm * t.ExtraPT / (1 - t.TPositionTaking) END) * (CASE WHEN t.VirtualRate > t.ActualRate THEN t.ActualRate ELSE t.VirtualRate END))
				,	[Stake]				= SUM(CASE WHEN t.Odds < 0 THEN -t.Odds ELSE 1 END * ABS(t.Stake) * (1 - t.TPositionTaking - t.ExtraPT) * t.VirtualRate - (t.Scomm - CASE WHEN t.TPositionTaking = 1 THEN 0 ELSE t.Scomm * t.ExtraPT / (1 - t.TPositionTaking) END) * (CASE WHEN t.VirtualRate > t.ActualRate THEN t.ActualRate ELSE t.VirtualRate END))
				
				,	[AVGOdds_AR]		= SUM((CASE WHEN t.Odds < 0 THEN 1 ELSE t.Odds END) * ABS(t.Stake) * (1 - t.TPositionTaking - t.ExtraPT) * (CASE WHEN t.VirtualRate > t.ActualRate THEN t.VirtualRate ELSE t.ActualRate END))
										/ SUM((CASE WHEN t.Odds < 0 THEN -t.Odds ELSE 1 END) * ABS(t.Stake) * (1 - t.TPositionTaking - t.ExtraPT) * (CASE WHEN t.VirtualRate > t.ActualRate THEN t.VirtualRate ELSE t.ActualRate END))
										--TotalWin/TotalLose
				,	[StakeMYBeforeComm_AR]	= SUM(t.StakeMY * (1 - t.TPositionTaking - t.ExtraPT) * (CASE WHEN t.VirtualRate > t.ActualRate THEN t.VirtualRate ELSE t.ActualRate END))
				,	[StakeMY_AR]		= SUM(t.StakeMY * (1 - t.TPositionTaking - t.ExtraPT) * (CASE WHEN t.VirtualRate > t.ActualRate THEN t.VirtualRate ELSE t.ActualRate END) - (t.Scomm - CASE WHEN t.TPositionTaking = 1 THEN 0 ELSE t.Scomm * t.ExtraPT / (1 - t.TPositionTaking) END) * t.ActualRate)
				,	[Stake_AR]			= SUM(CASE WHEN t.Odds < 0 THEN -t.Odds ELSE 1 END * ABS(t.Stake) * (1 - t.TPositionTaking - t.ExtraPT) * (CASE WHEN t.VirtualRate > t.ActualRate THEN t.VirtualRate ELSE t.ActualRate END) - (t.Scomm - CASE WHEN t.TPositionTaking = 1 THEN 0 ELSE t.Scomm * t.ExtraPT / (1 - t.TPositionTaking) END) * t.ActualRate)
			FROM	#tmpStagingTraderPerformance2 AS t WITH(NOLOCK)
			GROUP BY CustId, EventDate, MatchId, BetType, BetTeam, ScoreHDP, MOdds, StatusID;
		
			SELECT	@RowCount	= @@ROWCOUNT
				,	@Duration	= DATEDIFF(millisecond, @Begin, GETDATE())
				;

			IF	@Debug = 1
			BEGIN
				-- Force the output to appear immediately
				RAISERROR('From Origin - Insert #tmpDataGroup - Date: "%s" - %d rows - %d ms', 0, 0, @Date, @RowCount, @Duration) WITH NOWAIT;
			END;
		
			DELETE	d
			FROM	#winlostdate AS d
			WHERE	d.winlostdate = @WinLostDate;
						
			SELECT	@RowCount	= @@ROWCOUNT
				,	@Duration	= DATEDIFF(millisecond, @Begin, GETDATE())
				;

			IF	@Debug = 1
			BEGIN
				-- Force the output to appear immediately
				RAISERROR('From Origin - DELETE #winlostdate - Date: "%s" - %d rows - %d ms', 0, 0, @Date, @RowCount, @Duration) WITH NOWAIT;
			END;

			TRUNCATE TABLE	#tmpStagingTraderPerformance2;
			TRUNCATE TABLE	#tmpFilteredBettransBKByBatch2;
		END;
	END;

	-- Start calculating juice and update to TraderPerformance table
	IF	@Debug = 1
	BEGIN;
		SELECT	*
		FROM	#tmpDataGroup WITH(NOLOCK)
		ORDER BY MatchId, BetType, ScoreHDP, BetTeam DESC;
	END;

	INSERT INTO #tmpJuice (EventDate, MatchId, BetType, ScoreHDP, StakeMYBeforeComm, StakeMY, Juice, StakeMYRJuice, StakeMYRTotal, 
		StakeMYBeforeComm_AR, StakeMY_AR, Juice_AR, StakeMYRJuice_AR, StakeMYRTotal_AR)
	SELECT	[EventDate]			= temp1.EventDate
		,	[MatchId]			= temp1.MatchId
		,	[BetType]			= temp1.BetType
		,	[ScoreHDP]			= temp1.ScoreHDP
		,	[StakeMYBeforeComm]	= SUM(temp1.StakeMYBeforeComm)
		,	[StakeMY]			= SUM(temp1.StakeMY)
		,	[Juice]				= SUM(ISNULL( CASE	WHEN temp1.BetTeam IN ('h')
														THEN  CASE WHEN temp2.Stake * (1 + ABS(temp2.AVGOdds)) / (1 + ABS(temp1.AVGOdds)) > temp1.Stake THEN temp1.Stake ELSE temp2.Stake * (1 + ABS(temp2.AVGOdds)) / (1 + ABS(temp1.AVGOdds)) END * CASE WHEN temp1.AVGOdds > 0 THEN 1 ELSE -temp1.AVGOdds END
															- CASE WHEN temp1.Stake * (1 + ABS(temp1.AVGOdds)) / (1 + ABS(temp2.AVGOdds)) > temp2.Stake THEN temp2.Stake ELSE temp1.Stake * (1 + ABS(temp1.AVGOdds)) / (1 + ABS(temp2.AVGOdds)) END * CASE WHEN temp2.AVGOdds > 0 THEN temp2.AVGOdds ELSE 1 END 
													ELSE 0 
											  END
											, 0
									  )
								  )
		,	[StakeMYRJuice]		= SUM(ISNULL( CASE	WHEN temp1.BetTeam IN ('h')
														THEN  CASE WHEN temp2.Stake * (1 + ABS(temp2.AVGOdds)) / (1 + ABS(temp1.AVGOdds)) > temp1.Stake THEN temp1.Stake ELSE temp2.Stake * (1 + ABS(temp2.AVGOdds)) / (1 + ABS(temp1.AVGOdds)) END * CASE WHEN ABS(temp1.AVGOdds) > 1 THEN ABS(temp1.AVGOdds) ELSE 1 END
															+ CASE WHEN temp1.Stake * (1 + ABS(temp1.AVGOdds)) / (1 + ABS(temp2.AVGOdds)) > temp2.Stake THEN temp2.Stake ELSE temp1.Stake * (1 + ABS(temp1.AVGOdds)) / (1 + ABS(temp2.AVGOdds)) END * CASE WHEN ABS(temp2.AVGOdds) > 1 THEN ABS(temp2.AVGOdds) ELSE 1 END
													ELSE 0
											  END
											, 0
									  )
								  )
		,	[StakeMYRTotal]		= SUM(ISNULL( CASE	WHEN temp1.BetTeam IN ('h')
														THEN  temp1.Stake * CASE WHEN ABS(temp1.AVGOdds) > 1 THEN ABS(temp1.AVGOdds) ELSE 1 END
															+ temp2.Stake * CASE WHEN ABS(temp2.AVGOdds) > 1 THEN ABS(temp2.AVGOdds) ELSE 1 END
													ELSE 0
											  END
											, 0
									  )
								  )
		,	[StakeMYBeforeComm_AR]	= SUM(temp1.StakeMYBeforeComm_AR)
		,	[StakeMY_AR]			= SUM(temp1.StakeMY_AR)
		,	[Juice_AR]				= SUM(ISNULL( CASE	WHEN temp1.BetTeam IN ('h')
														THEN  CASE WHEN temp2.Stake_AR * (1 + ABS(temp2.AVGOdds_AR)) / (1 + ABS(temp1.AVGOdds_AR)) > temp1.Stake_AR THEN temp1.Stake_AR ELSE temp2.Stake_AR * (1 + ABS(temp2.AVGOdds_AR)) / (1 + ABS(temp1.AVGOdds_AR)) END * CASE WHEN temp1.AVGOdds_AR > 0 THEN 1 ELSE -temp1.AVGOdds_AR END
															- CASE WHEN temp1.Stake_AR * (1 + ABS(temp1.AVGOdds_AR)) / (1 + ABS(temp2.AVGOdds_AR)) > temp2.Stake_AR THEN temp2.Stake_AR ELSE temp1.Stake_AR * (1 + ABS(temp1.AVGOdds_AR)) / (1 + ABS(temp2.AVGOdds_AR)) END * CASE WHEN temp2.AVGOdds_AR > 0 THEN temp2.AVGOdds_AR ELSE 1 END 
													ELSE 0 
											  END
											, 0
									  )
								  )
		,	[StakeMYRJuice_AR]		= SUM(ISNULL( CASE	WHEN temp1.BetTeam IN ('h')
														THEN  CASE WHEN temp2.Stake_AR * (1 + ABS(temp2.AVGOdds_AR)) / (1 + ABS(temp1.AVGOdds_AR)) > temp1.Stake_AR THEN temp1.Stake_AR ELSE temp2.Stake_AR * (1 + ABS(temp2.AVGOdds_AR)) / (1 + ABS(temp1.AVGOdds_AR)) END * CASE WHEN ABS(temp1.AVGOdds_AR) > 1 THEN ABS(temp1.AVGOdds_AR) ELSE 1 END
															+ CASE WHEN temp1.Stake_AR * (1 + ABS(temp1.AVGOdds_AR)) / (1 + ABS(temp2.AVGOdds_AR)) > temp2.Stake_AR THEN temp2.Stake_AR ELSE temp1.Stake_AR * (1 + ABS(temp1.AVGOdds_AR)) / (1 + ABS(temp2.AVGOdds_AR)) END * CASE WHEN ABS(temp2.AVGOdds_AR) > 1 THEN ABS(temp2.AVGOdds_AR) ELSE 1 END
													ELSE 0
											  END
											, 0
									  )
								  )
		,	[StakeMYRTotal_AR]		= SUM(ISNULL( CASE	WHEN temp1.BetTeam IN ('h')
														THEN  temp1.Stake_AR * CASE WHEN ABS(temp1.AVGOdds_AR) > 1 THEN ABS(temp1.AVGOdds_AR) ELSE 1 END
															+ temp2.Stake_AR * CASE WHEN ABS(temp2.AVGOdds_AR) > 1 THEN ABS(temp2.AVGOdds_AR) ELSE 1 END
													ELSE 0
											  END
											, 0
									  )
								  )
	FROM		#tmpDataGroup AS temp1 WITH (NOLOCK)
	LEFT JOIN	#tmpDataGroup AS temp2 WITH (NOLOCK)
			ON	temp1.MatchId = temp2.MatchId
			AND	temp1.BetType = temp2.BetType
			AND	temp1.ScoreHDP = temp2.ScoreHDP
			AND	temp1.BetTeam <> temp2.BetTeam
	GROUP BY temp1.MatchId, temp1.BetType, temp1.EventDate, temp1.ScoreHDP;

	IF	@Debug = 1
	BEGIN;
		SELECT	*
		FROM	#tmpJuice
		ORDER BY matchid, bettype;
	END;

	INSERT INTO	#tmpSumTotal (EventDate, MatchId, BetType, StakeMYBeforeComm, Juice, StakeMYRJuice, StakeMYBeforeComm_AR, Juice_AR, StakeMYRJuice_AR)
	SELECT	[EventDate]			= t.EventDate
		,	[MatchId]			= t.MatchId
		,	[BetType]			= t.BetType
		,	[StakeMYBeforeComm]	= SUM(t.StakeMYBeforeComm)
		,	[Juice]				= SUM(t.Juice)
		,	[StakeMYRJuice]		= SUM(CASE WHEN t.StakeMYRTotal = 0 THEN 0 ELSE CAST(t.StakeMYBeforeComm AS DECIMAL(38,18)) * t.StakeMYRJuice / t.StakeMYRTotal END) -- Before comm		
		,	[StakeMYBeforeComm_AR]	= SUM(t.StakeMYBeforeComm_AR)
		,	[Juice_AR]			= SUM(t.Juice_AR)
		,	[StakeMYRJuice_AR]	= SUM(CASE WHEN t.StakeMYRTotal_AR = 0 THEN 0 ELSE CAST(t.StakeMYBeforeComm_AR AS DECIMAL(38,18)) * t.StakeMYRJuice_AR / t.StakeMYRTotal_AR END) -- Before comm
	FROM	#tmpJuice t WITH(NOLOCK)
	GROUP BY t.MatchId, t.BetType, t.EventDate, t.ScoreHDP;
		
	INSERT INTO #tmpResults (EventDate, MatchId, BetType, StakeMYBeforeComm, Juice, StakeMYRJuice, StakeMYBeforeComm_AR, Juice_AR, StakeMYRJuice_AR)
	SELECT	[EventDate]			= t.EventDate
		,	[MatchId]			= t.MatchId
		,	[BetType]			= t.BetType
		,	[StakeMYBeforeComm]	= SUM(t.StakeMYBeforeComm)
		,	[Juice]				= SUM(t.Juice)
		,	[StakeMYRJuice]		= SUM(t.StakeMYRJuice)		
		,	[StakeMYBeforeComm_AR]	= SUM(t.StakeMYBeforeComm_AR)
		,	[Juice_AR]			= SUM(t.Juice_AR)
		,	[StakeMYRJuice_AR]	= SUM(t.StakeMYRJuice_AR)
	FROM	#tmpSumTotal t WITH(NOLOCK)
	GROUP BY t.MatchId, t.BetType, t.EventDate;
	
	UPDATE	tp
	SET		tp.Juice = t.Juice
		,	tp.StakeMYR = t.StakeMYBeforeComm
		,	tp.StakeMYRJuice = t.StakeMYRJuice
		,	tp.Juice_AR = t.Juice_AR
		,	tp.StakeMYR_AR = t.StakeMYBeforeComm_AR
		,	tp.StakeMYRJuice_AR = t.StakeMYRJuice_AR
	FROM		dbo.TraderPerformance AS tp WITH (ROWLOCK, UPDLOCK)
	INNER JOIN	#tmpResults AS t WITH (NOLOCK)
			ON	t.MatchId = tp.matchid
			AND	t.BetType = tp.bettype
	WHERE	tp.EventDate = t.EventDate
			AND tp.IsLive = 1; -- temporarily update Juice for live tickets only
	
	SELECT	@RowCount	= @@ROWCOUNT
		,	@Duration	= DATEDIFF(millisecond, @Begin, GETDATE())
	;

	IF	@Debug = 1
	BEGIN;
		-- Force the output to appear immediately --
		RAISERROR('UPDATE TraderPerformance - %d rows - %d ms', 0, 0, @RowCount, @Duration) WITH NOWAIT;
	END;
END;