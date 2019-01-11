SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO
ALTER PROCEDURE	[dbo].[Task_StagingOSDataTGRS]
		@Debug					BIT = 0
	,	@BeforeMoveBetsDay		BIT = 1	
	,	@GenerateFromDate		SMALLDATETIME = NULL
	,	@GenerateToDate			SMALLDATETIME = NULL
AS
/*  
	Created:	20160810@Long.Luu
	Task :		Staging Data for Other Sports on TGRS DB
	DB:			DBTGRS.bodb_TGRS
	Original:
  
	Revisions:  
		- 20170227@Aaron:	Added MatchCount
		- 20170306@John:	Change table OSDataTGRS
		- 20170330@Long:	Apply ExtraPT
   		- 20170711@Billy:	Remove delete OSStagingDataTGRS part to update Juice for next step - [Redmine: #79615]
		- 20180928@Long:	Support more bettypes - [Redmine: #83185]
		- 20190108@John:	Exclude Cashout tickets from Betcount figures in TGR reports [Redmine ID: 107602]
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
		;

	DECLARE @BalanceUpDay			SMALLDATETIME
		,	@MoveBetsDay			SMALLDATETIME
		,	@Yesterday				SMALLDATETIME
		,	@Today					SMALLDATETIME
		,	@winlostdate			DATETIME
		;

	-- Check running job
	DECLARE @IsRunningJob				BIT;
	
	IF (@GenerateFromDate IS NULL OR @GenerateToDate IS NULL)
	BEGIN
		SELECT @IsRunningJob = 1
	END
	--
		
	IF	OBJECT_ID('tempdb..#tmpDLBUMBData') IS NOT NULL
	BEGIN
		DROP TABLE	#tmpDLBUMBData
	END;

	CREATE TABLE	#tmpDLBUMBData (
			BUDay	SMALLDATETIME
		,	MBDay	SMALLDATETIME
	);

	INSERT INTO #tmpDLBUMBData(BUDay,MBDay)
	EXECUTE bodb02.dbo.Age_SelBalanceUpDay;

	SELECT	TOP(1)
			@BalanceUpDay	= BUDay
		,	@MoveBetsDay	= MBDay
	FROM #tmpDLBUMBData;

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

	IF	OBJECT_ID('tempdb..#tmpOSTrader') IS NOT NULL
	BEGIN
		DROP TABLE #tmpOSTrader;
	END;

	CREATE TABLE	#tmpOSTrader (
						CustId				INT
					,	matchid				INT
					,	SportType			INT
					,	EventDate			DATETIME
					,	BetType				SMALLINT
					,	OSTarget			DECIMAL(18, 2)
					);

	CREATE CLUSTERED INDEX	#CIX_tmpOSTraderIdx ON #tmpOSTrader (
			CustId				ASC
		,	EventDate			ASC
		,	MatchId				ASC
		,	BetType				ASC
	);

	IF	OBJECT_ID('tempdb..#tmpBettransDate') IS NOT NULL
	BEGIN
		DROP TABLE	#tmpBettransDate;
	END;

	CREATE TABLE	#tmpBettransDate (
						winlostdate DATE
					);

	IF	OBJECT_ID('tempdb..#tmpFilteredBettransByBatch') IS NOT NULL
	BEGIN
		DROP TABLE	#tmpFilteredBettransByBatch;
	END;

	CREATE TABLE	#tmpFilteredBettransByBatch (
						transid				BIGINT
					,	custid				INT
					,	matchid				INT
					,	winlostdate			SMALLDATETIME
					,	bettype				SMALLINT
					,	modds				SMALLMONEY
					,	stake				MONEY
					,	actual_stake		MONEY
					,	virtualrate			FLOAT
					,	winlost				MONEY
					,	awinlost			MONEY
					,	mwinlost			MONEY
					,	swinlost			MONEY
					,	tpositiontaking		SMALLMONEY
					,	srecommend			INT
					,	scomm				MONEY
					);

	CREATE CLUSTERED INDEX	#CIX_tmpFilteredBettrans14ByBatchIdx ON #tmpFilteredBettransByBatch (
						winlostdate			ASC
					,	matchid				ASC
					,	bettype				ASC
					);
	
	CREATE NONCLUSTERED INDEX	#NCIX_tmpFilteredBettrans14ByBatchIdx ON #tmpFilteredBettransByBatch (
					    custid				ASC
	);
	
	IF	OBJECT_ID('tempdb..#tmpFilteredBettrans') IS NOT NULL
	BEGIN
		DROP TABLE	#tmpFilteredBettrans;
	END;

		CREATE TABLE	#tmpFilteredBettrans (
						transid				BIGINT
					,	custid				INT
					,	matchid				INT
					,	winlostdate			SMALLDATETIME
					,	bettype				SMALLINT
					,	modds				SMALLMONEY
					,	stake				MONEY
					,	actual_stake		MONEY
					,	virtualrate			FLOAT
					,	winlost				MONEY
					,	awinlost			MONEY
					,	mwinlost			MONEY
					,	swinlost			MONEY
					,	tpositiontaking		SMALLMONEY
					,	srecommend			INT
					,	scomm				MONEY
					);

	CREATE CLUSTERED INDEX	#CIX_tmpFilteredBettransIdx ON #tmpFilteredBettrans (
								winlostdate	ASC
							,	matchid		ASC
							,	bettype		ASC
							);
	CREATE NONCLUSTERED INDEX	#NCIX_tmpFilteredBettransIdx ON #tmpFilteredBettrans (
								custid		ASC
	);

	IF	OBJECT_ID('tempdb..#tmpStagingOSTraderPerformance') IS NOT NULL
	BEGIN
		DROP TABLE	#tmpStagingOSTraderPerformance;
	END;

	CREATE TABLE	#tmpStagingOSTraderPerformance (
						CustId				INT
					,	MemberCustId		INT
					,	EventDate			DATE
					,	MatchId				INT
					,	BetType				SMALLINT
					,	Stake				MONEY
					,	WinLost				MONEY
					,	SMAWinLost			MONEY
					,	Comm				MONEY
					,	ExtraPT				DECIMAL(9, 8)
					,	TPositionTaking		SMALLMONEY
					,	VirtualRate			FLOAT
					);
	
	CREATE CLUSTERED INDEX #CIX_tmpStagingOSTraderPerformanceIdx ON #tmpStagingOSTraderPerformance (
						CustId				ASC
					,	EventDate			ASC
	); 

	CREATE NONCLUSTERED INDEX	#NCIX_tmpStagingOSTraderPerformanceIdx ON #tmpStagingOSTraderPerformance (
						MemberCustId		ASC
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
		TRUNCATE TABLE dbo.OSStaging_EventDate;

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
	END;

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

	IF	@IsGetDataFromBK = 1
	BEGIN

		TRUNCATE TABLE #tmpOSTrader;
		INSERT INTO	#tmpOSTrader (CustId, matchid, SportType, EventDate, BetType, OSTarget)
		SELECT	DISTINCT
				[CustId]	= a.OperatorID
			,	[matchid]	= m.matchid
			,	[SportType]	= m.sporttype
			,	[EventDate]	= m.EventDate
			,	[BetType]	= CASE	WHEN a.bettype = 5 AND a.operatortype = 1
										THEN 1
									ELSE ISNULL(b.MainDBBetType, 0) 
								END
			,	[OSTarget]	= dbo.f_GetOSTargetBySportLeagueBettype(m.sporttype, m.leagueid, a.bettype, m.eventdate)
		FROM		bodb_archive.dbo.Dot_Admin_Assignment_Operator_bk AS a WITH (NOLOCK)
		INNER JOIN	bodb_Archive.dbo.Match_bk AS m WITH (NOLOCK)
				ON	a.matchid = m.matchid
		LEFT JOIN	dbo.OSBettype AS b WITH (NOLOCK)
				ON	a.bettype = b.AssignmentBetType
				AND	a.OperatorType = b.OperatorType
		WHERE	m.EventDate BETWEEN @FromDateBK AND @ToDateBK
			AND	a.OperatorType < 3
			AND	m.MatchCode NOT LIKE '%hedge%'
			AND	m.sporttype <> 1
			AND	(a.bettype < 31 
				OR a.bettype BETWEEN 121 AND 999 
				OR a.bettype BETWEEN 1301 AND 1399
				OR a.bettype BETWEEN 9001 AND 9074)
			AND	a.bettype NOT BETWEEN 801 AND 806 -- metric gaming
			AND	a.bettype NOT IN (901, 902, 903) -- bettrade
		;

		SELECT	@RowCount	= @@ROWCOUNT
			,	@Duration	= DATEDIFF(millisecond, @Begin, GETDATE())
			;

		IF	@Debug = 1
		BEGIN
			-- Force the output to appear immediately --
			RAISERROR('From BK - Insert #tmpOSTrader - %d rows - %d ms', 0, 0, @RowCount, @Duration) WITH NOWAIT;
		END;
	
		INSERT INTO	#tmpBettransDate (winlostdate)
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
			-- Force the output to appear immediately --
			RAISERROR('From BK - Insert #tmpBettransDate - %d rows - %d ms', 0, 0, @RowCount, @Duration) WITH NOWAIT;
		END;

		-- No input date range: Default job run
		IF (@IsRunningJob = 1)
		BEGIN
			INSERT INTO dbo.OSStaging_EventDate(EventDate)
			SELECT winlostdate FROM #tmpBettransDate

			SELECT	@RowCount	= @@ROWCOUNT
				,	@Duration	= DATEDIFF(millisecond, @Begin, GETDATE())
				;

			IF	@Debug = 1
			BEGIN
				-- Force the output to appear immediately --
				RAISERROR('From BK - Insert OSStaging_EventDate - %d rows - %d ms', 0, 0, @RowCount, @Duration) WITH NOWAIT;
			END;
		END;

		INSERT INTO #tmpFilteredBettrans
			(	  transid,  custid, matchid,   winlostdate,   bettype,   modds,   stake,   actual_stake,   virtualrate,   winlost,   awinlost,   mwinlost,   swinlost,   tpositiontaking,   srecommend,   scomm)
		SELECT	b.transid, b.custid, b.matchid, b.winlostdate, b.bettype, b.modds, b.stake, b.actual_stake, b.virtualrate, b.winlost, b.awinlost, b.mwinlost, b.swinlost, b.tpositiontaking, b.srecommend, b.scomm
		FROM	bodb_Archive.dbo.bettrans_bk AS b WITH (NOLOCK)
		WHERE	b.winlostdate BETWEEN @FromDateBK AND @ToDateBK
			AND	b.statusID IN (112, 113)
			AND	b.Currency NOT IN (20, 27, 28)
			AND	b.LiveIndicator = 1
		;
		
		WHILE	EXISTS (SELECT 1 FROM #tmpBettransDate)
		BEGIN
			SELECT	TOP(1)
					@WinLostDate = d.winlostdate
			FROM	#tmpBettransDate AS d;
			
			TRUNCATE TABLE	#tmpFilteredBettransByBatch;
			INSERT INTO #tmpFilteredBettransByBatch 
				(	  transid,  custid, matchid,   winlostdate,   bettype,   modds,   stake,   actual_stake,   virtualrate,   winlost,   awinlost,   mwinlost,   swinlost,   tpositiontaking,   srecommend,   scomm)
			SELECT	b.transid, b.custid, b.matchid, b.winlostdate, b.bettype, b.modds, b.stake, b.actual_stake, b.virtualrate, b.winlost, b.awinlost, b.mwinlost, b.swinlost, b.tpositiontaking, b.srecommend, b.scomm
			FROM	#tmpFilteredBettrans AS b WITH (NOLOCK)
			WHERE	b.winlostdate = @WinLostDate;
			
			SELECT	@RowCount	= @@ROWCOUNT
				,	@Duration	= DATEDIFF(millisecond, @Begin, GETDATE())
				;
	
			IF	@Debug = 1
			BEGIN
				-- Force the output to appear immediately --
				RAISERROR('From BK - Insert #tmpFilteredBettransByBatch - %d rows - %d ms', 0, 0, @RowCount, @Duration) WITH NOWAIT;
			END;
			
			INSERT INTO #tmpStagingOSTraderPerformance (CustId, MemberCustId, EventDate, MatchId, BetType, Stake, WinLost, SMAWinLost, Comm, ExtraPT, TPositionTaking, VirtualRate)
			SELECT	[CustId]			= t.CustId
				,	[MemberCustId]		= b.custid
				,	[EventDate]			= t.EventDate
				,	[MatchId]			= t.matchid
				,	[BetType]			= b.bettype
				,	[Stake]				= ((CASE WHEN b.modds = 0.25 OR b.modds = -0.25 THEN ABS(b.stake) / 2 ELSE ABS(b.stake) END) * b.virtualrate) --turn over
				,	[WinLost]			= (b.winlost - b.actual_stake)  --Winlost
				,	[SMAWinLost]		= (b.awinlost + b.mwinlost + b.swinlost)  --SMAWinlost
				,	[Comm]				= b.scomm  --Commission
				,	[ExtraPT]			= SUM(ISNULL(es.ExtraPT, 0))
				,	[TPositionTaking]	= b.tpositiontaking
				,	[VirtualRate]		= b.virtualrate
			FROM		#tmpFilteredBettransByBatch AS b
			INNER JOIN	#tmpOSTrader AS t WITH (NOLOCK)
					ON	b.winlostdate = t.EventDate
					AND	b.matchid = t.matchid
					AND	b.bettype = t.BetType
			LEFT JOIN	bodb_ACC.dbo.Acc_GroupExtraPTSetting AS es WITH (NOLOCK)
					ON	es.SuperId = b.srecommend
					AND	es.ProductId = 1
					AND	es.SportType = 0
					AND	es.SubProduct = ''
					AND	t.EventDate BETWEEN es.FromDate AND es.ToDate
			GROUP BY	t.CustId, b.custid, t.EventDate, t.matchid, b.bettype
					,	((CASE WHEN b.modds = 0.25 OR b.modds = -0.25 THEN ABS(b.stake) / 2 ELSE ABS(b.stake) END) * b.virtualrate)
					,	(b.winlost - b.actual_stake), (b.awinlost + b.mwinlost + b.swinlost)
					,	b.scomm, b.tpositiontaking, b.virtualrate, b.transid
			OPTION (MAXDOP 2);

			SELECT	@RowCount	= @@ROWCOUNT
				,	@Duration	= DATEDIFF(millisecond, @Begin, GETDATE())
				;

			IF	@Debug = 1
			BEGIN
				-- Force the output to appear immediately --
				RAISERROR('From BK - Insert #tmpStagingOSTraderPerformance - %d rows - %d ms', 0, 0, @RowCount, @Duration) WITH NOWAIT;
			END;
			
			DELETE dbo.OSDataTGRS WHERE EventDate = @winlostdate;

			INSERT INTO	dbo.OSDataTGRS (TraderId, MatchId, MatchCode, EventDate, SportId, LeagueId, BettypeId, Turnover, WinLoss, Comm, BetCount, Target)
			SELECT	[TraderId]		= t.CustId
				,	[MatchId]		= m.MatchId
				,	[MatchCode]		= m.matchcode
				,	[EventDate]		= t.EventDate
				,	[SportId]		= t.SportType
				,	[LeagueId]		= m.LeagueId
				,	[BettypeId]		= b.BetType
				,	[Turnover]		= SUM(b.Stake * (1 - b.TPositionTaking - b.ExtraPT))
				,	[WinLoss]		= SUM(((-(b.WinLost + b.SMAWinLost)) + b.WinLost * b.ExtraPT) * b.VirtualRate)
				,	[Comm]			= SUM((b.Comm - (CASE WHEN b.TPositionTaking = 1 THEN 0 ELSE (b.Comm * b.ExtraPT / (1 - b.TPositionTaking)) END)) * b.VirtualRate)
				,	[BetCount]		= SUM(CASE WHEN tc.custid IS NULL THEN 1 ELSE 0 END)  --Live BetCount				
				,	[Target]		= t.OSTarget
			FROM		#tmpStagingOSTraderPerformance AS b WITH (NOLOCK)
			INNER JOIN	bodb_Archive.dbo.Match_bk AS m WITH (NOLOCK)
					ON	b.MatchId = m.MatchId
			INNER JOIN	#tmpOSTrader AS t WITH (NOLOCK)
					ON	m.MatchId = t.matchid
					AND	t.CustId = b.CustId
					AND	b.BetType = t.BetType
			LEFT JOIN bodb02.dbo.TradeCust tc WITH (NOLOCK) ON b.MemberCustId = tc.custid AND tc.VendorID = 14
			WHERE m.eventdate = @WinLostDate
			GROUP BY t.CustId, m.MatchId, m.matchcode, t.EventDate, t.SportType, m.LeagueId, b.BetType, t.OSTarget;
			
			SELECT	@RowCount	= @@ROWCOUNT
				,	@Duration	= DATEDIFF(millisecond, @Begin, GETDATE())
				;

			IF	@Debug = 1
			BEGIN
				-- Force the output to appear immediately --
				RAISERROR('From BK - Insert OSDataTGRS - %d rows - %d ms', 0, 0, @RowCount, @Duration) WITH NOWAIT;
			END;
			
			-- Remove batched-data (bettrans & date) from source
			DELETE
			FROM	#tmpFilteredBettrans
			WHERE	winlostdate = @winlostdate;

			DELETE
			FROM	#tmpBettransDate
			WHERE	winlostdate = @winlostdate;
			
			TRUNCATE TABLE	#tmpStagingOSTraderPerformance;
			TRUNCATE TABLE	#tmpFilteredBettransByBatch;
		END;
	END;

	IF	@IsGetDataFrom14 = 1
	BEGIN
		
		TRUNCATE TABLE #tmpOSTrader;
		INSERT INTO	#tmpOSTrader (CustId, matchid, SportType, EventDate, BetType, OSTarget)
		SELECT	DISTINCT
				[CustId]	= a.OperatorID
			,	[matchid]	= m.matchid
			,	[SportType]	= m.sporttype
			,	[EventDate]	= m.EventDate
			,	[BetType]	= CASE	WHEN a.bettype = 5 AND a.operatortype = 1
										THEN 1
									ELSE ISNULL(b.MainDBBetType, 0) 
								END
			,	[OSTarget]	= dbo.f_GetOSTargetBySportLeagueBettype(m.sporttype, m.leagueid, a.bettype, m.eventdate)
		FROM		bodb_archive.dbo.Dot_Admin_Assignment_Operator_bk AS a WITH (NOLOCK)
		INNER JOIN	bodb02.dbo.Match14 AS m WITH (NOLOCK)
				ON	a.matchid = m.matchid
		LEFT JOIN	dbo.OSBettype AS b WITH (NOLOCK)
				ON	a.bettype = b.AssignmentBetType
				AND	a.OperatorType = b.OperatorType
		WHERE	m.EventDate BETWEEN @BalanceUpDay AND @MoveBetsDay
			AND	a.OperatorType < 3
			AND	m.MatchCode NOT LIKE '%hedge%'
			AND	m.sporttype <> 1
			AND	(a.bettype < 31 
				OR a.bettype BETWEEN 121 AND 999 
				OR a.bettype BETWEEN 1301 AND 1399
				OR a.bettype BETWEEN 9001 AND 9074)
			AND	a.bettype NOT BETWEEN 801 AND 806 -- metric gaming
			AND	a.bettype NOT IN (901, 902, 903) -- bettrade
		;

		SELECT	@RowCount	= @@ROWCOUNT
			,	@Duration	= DATEDIFF(millisecond, @Begin, GETDATE())
			;

		IF	@Debug = 1
		BEGIN
			-- Force the output to appear immediately --
			RAISERROR('From 14 - Insert #tmpOSTrader - %d rows - %d ms', 0, 0, @RowCount, @Duration) WITH NOWAIT;
		END;
	
		INSERT INTO	#tmpBettransDate (winlostdate)
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
			-- Force the output to appear immediately --
			RAISERROR('From 14 - Insert #tmpBettransDate - %d rows - %d ms', 0, 0, @RowCount, @Duration) WITH NOWAIT;
		END;

		-- No input date range: Default job run
		IF (@IsRunningJob = 1)
		BEGIN
			INSERT INTO dbo.OSStaging_EventDate(EventDate)
			SELECT winlostdate FROM #tmpBettransDate

			SELECT	@RowCount	= @@ROWCOUNT
				,	@Duration	= DATEDIFF(millisecond, @Begin, GETDATE())
				;

			IF	@Debug = 1
			BEGIN
				-- Force the output to appear immediately --
				RAISERROR('From 14 - Insert OSStaging_EventDate - %d rows - %d ms', 0, 0, @RowCount, @Duration) WITH NOWAIT;
			END;
		END;

		INSERT INTO #tmpFilteredBettrans
			(	  transid,  custid, matchid,   winlostdate,   bettype,   modds,   stake,   actual_stake,   virtualrate,   winlost,   awinlost,   mwinlost,   swinlost,   tpositiontaking,   srecommend,   scomm)
		SELECT	b.transid, b.custid, b.matchid, b.winlostdate, b.bettype, b.modds, b.stake, b.actual_stake, b.virtualrate, b.winlost, b.awinlost, b.mwinlost, b.swinlost, b.tpositiontaking, b.srecommend, b.scomm
		FROM	bodb02.dbo.bettrans14 AS b WITH (NOLOCK)
		WHERE	b.winlostdate BETWEEN @FromDate14 AND @ToDate14
			AND	b.statusID IN (112, 113)
			AND	b.Currency NOT IN (20, 27, 28)
			AND	b.LiveIndicator = 1
		;
		
		WHILE	EXISTS (SELECT 1 FROM #tmpBettransDate)
		BEGIN
			SELECT	TOP(1)
					@WinLostDate = d.winlostdate
			FROM	#tmpBettransDate AS d;
			
			TRUNCATE TABLE	#tmpFilteredBettransByBatch;
			INSERT INTO #tmpFilteredBettransByBatch 
				(	  transid,  custid, matchid,   winlostdate,   bettype,   modds,   stake,   actual_stake,   virtualrate,   winlost,   awinlost,   mwinlost,   swinlost,   tpositiontaking,   srecommend,   scomm)
			SELECT	b.transid, b.custid, b.matchid, b.winlostdate, b.bettype, b.modds, b.stake, b.actual_stake, b.virtualrate, b.winlost, b.awinlost, b.mwinlost, b.swinlost, b.tpositiontaking, b.srecommend, b.scomm
			FROM	#tmpFilteredBettrans AS b WITH (NOLOCK)
			WHERE	b.winlostdate = @WinLostDate;
			
			SELECT	@RowCount	= @@ROWCOUNT
				,	@Duration	= DATEDIFF(millisecond, @Begin, GETDATE())
				;
	
			IF	@Debug = 1
			BEGIN
				-- Force the output to appear immediately --
				RAISERROR('From 14 - Insert #tmpFilteredBettransByBatch - %d rows - %d ms', 0, 0, @RowCount, @Duration) WITH NOWAIT;
			END;
			
			INSERT INTO #tmpStagingOSTraderPerformance (CustId, MemberCustId, EventDate, MatchId, BetType, Stake, WinLost, SMAWinLost, Comm, ExtraPT, TPositionTaking, VirtualRate)
			SELECT	[CustId]			= t.CustId
				,	[MemberCustId]		= b.custid
				,	[EventDate]			= t.EventDate
				,	[MatchId]			= t.matchid
				,	[BetType]			= b.bettype
				,	[Stake]				= ((CASE WHEN b.modds = 0.25 OR b.modds = -0.25 THEN ABS(b.stake) / 2 ELSE ABS(b.stake) END) * b.virtualrate) --turn over
				,	[WinLost]			= (b.winlost - b.actual_stake)  --Winlost
				,	[SMAWinLost]		= (b.awinlost + b.mwinlost + b.swinlost)  --SMAWinlost
				,	[Comm]				= b.scomm  --Commission
				,	[ExtraPT]			= SUM(ISNULL(es.ExtraPT, 0))
				,	[TPositionTaking]	= b.tpositiontaking
				,	[VirtualRate]		= b.virtualrate
			FROM		#tmpFilteredBettransByBatch AS b
			INNER JOIN	#tmpOSTrader AS t WITH (NOLOCK)
					ON	b.winlostdate = t.EventDate
					AND	b.matchid = t.matchid
					AND	b.bettype = t.BetType
			LEFT JOIN	bodb_ACC.dbo.Acc_GroupExtraPTSetting AS es WITH (NOLOCK)
					ON	es.SuperId = b.srecommend
					AND	es.ProductId = 1
					AND	es.SportType = 0
					AND	es.SubProduct = ''
					AND	t.EventDate BETWEEN es.FromDate AND es.ToDate
			GROUP BY	t.CustId, b.custid, t.EventDate, t.matchid, b.bettype
					,	((CASE WHEN b.modds = 0.25 OR b.modds = -0.25 THEN ABS(b.stake) / 2 ELSE ABS(b.stake) END) * b.virtualrate)
					,	(b.winlost - b.actual_stake), (b.awinlost + b.mwinlost + b.swinlost)
					,	b.scomm, b.tpositiontaking, b.virtualrate, b.transid
			OPTION (MAXDOP 2);

			SELECT	@RowCount	= @@ROWCOUNT
				,	@Duration	= DATEDIFF(millisecond, @Begin, GETDATE())
				;

			IF	@Debug = 1
			BEGIN
				-- Force the output to appear immediately --
				RAISERROR('From 14 - Insert #tmpStagingOSTraderPerformance - %d rows - %d ms', 0, 0, @RowCount, @Duration) WITH NOWAIT;
			END;
			
			DELETE dbo.OSDataTGRS WHERE EventDate = @winlostdate;

			INSERT INTO	dbo.OSDataTGRS (TraderId, MatchId, MatchCode, EventDate, SportId, LeagueId, BettypeId, Turnover, WinLoss, Comm, BetCount, Target)
			SELECT	[TraderId]		= t.CustId
				,	[MatchId]		= m.MatchId
				,	[MatchCode]		= m.matchcode
				,	[EventDate]		= t.EventDate
				,	[SportId]		= t.SportType
				,	[LeagueId]		= m.LeagueId
				,	[BettypeId]		= b.BetType
				,	[Turnover]		= SUM(b.Stake * (1 - b.TPositionTaking - b.ExtraPT))
				,	[WinLoss]		= SUM(((-(b.WinLost + b.SMAWinLost)) + b.WinLost * b.ExtraPT) * b.VirtualRate)
				,	[Comm]			= SUM((b.Comm - (CASE WHEN b.TPositionTaking = 1 THEN 0 ELSE (b.Comm * b.ExtraPT / (1 - b.TPositionTaking)) END)) * b.VirtualRate)
				,	[BetCount]		= SUM(CASE WHEN tc.custid IS NULL THEN 1 ELSE 0 END)  --Live BetCount				
				,	[Target]		= t.OSTarget
			FROM		#tmpStagingOSTraderPerformance AS b WITH (NOLOCK)
			INNER JOIN	bodb02.dbo.match14 AS m WITH (NOLOCK)
					ON	b.MatchId = m.MatchId
			INNER JOIN	#tmpOSTrader AS t WITH (NOLOCK)
					ON	m.MatchId = t.matchid
					AND	t.CustId = b.CustId
					AND	b.BetType = t.BetType
			LEFT JOIN bodb02.dbo.TradeCust tc WITH (NOLOCK) ON b.MemberCustId = tc.custid AND tc.VendorID = 14
			WHERE m.eventdate = @WinLostDate
			GROUP BY t.CustId, m.MatchId, m.matchcode, t.EventDate, t.SportType, m.LeagueId, b.BetType, t.OSTarget;
			
			SELECT	@RowCount	= @@ROWCOUNT
				,	@Duration	= DATEDIFF(millisecond, @Begin, GETDATE())
				;

			IF	@Debug = 1
			BEGIN
				-- Force the output to appear immediately --
				RAISERROR('From 14 - Insert OSDataTGRS - %d rows - %d ms', 0, 0, @RowCount, @Duration) WITH NOWAIT;
			END;
			
			-- Remove batched-data (bettrans & date) from source
			DELETE
			FROM	#tmpFilteredBettrans
			WHERE	winlostdate = @winlostdate;

			DELETE
			FROM	#tmpBettransDate
			WHERE	winlostdate = @winlostdate;
			
			TRUNCATE TABLE	#tmpStagingOSTraderPerformance;
			TRUNCATE TABLE	#tmpFilteredBettransByBatch;
		END;
	END;
	
	IF	@IsGetDataFromOrigin = 1
	BEGIN
	
		TRUNCATE TABLE #tmpOSTrader;
		INSERT INTO	#tmpOSTrader (CustId, matchid, SportType, EventDate, BetType, OSTarget)
		SELECT	DISTINCT
				[CustId]		= a.OperatorID
			,	[matchid]		= m.matchid
			,	[SportType]		= m.sporttype
			,	[EventDate]		= m.EventDate
			,	[BetType]		= CASE	WHEN a.bettype = 5 AND a.operatortype = 1
											THEN 1
										ELSE ISNULL(b.MainDBBetType, 0) 
									END
			,	[OSTarget]		= dbo.f_GetOSTargetBySportLeagueBettype(m.sporttype, m.leagueid, a.bettype, m.eventdate)
		FROM		bodb02.dbo.Dot_admin_Assignment_Operator AS a WITH (NOLOCK)
		INNER JOIN	bodb02.dbo.match AS m WITH (NOLOCK)
				ON	a.matchid = m.matchid
		LEFT JOIN	dbo.OSBettype AS b WITH (NOLOCK)
				ON	a.bettype = b.AssignmentBetType
				AND	a.OperatorType = b.OperatorType
		WHERE	m.EventDate BETWEEN @FromDateOrigin AND @ToDateOrigin
			AND	m.EventStatus = 'completed'
			AND	a.OperatorType < 3
			AND	m.MatchCode NOT LIKE '%hedge%'
			AND	m.sporttype <> 1
			AND	(a.bettype < 31 
				OR a.bettype BETWEEN 121 AND 999 
				OR a.bettype BETWEEN 1301 AND 1399
				OR a.bettype BETWEEN 9001 AND 9074)
			AND	a.bettype NOT BETWEEN 801
			AND	806 -- metric gaming
			AND	a.bettype NOT IN (901, 902, 903) -- bettrade
		;

		SELECT	@RowCount	= @@ROWCOUNT
			,	@Duration	= DATEDIFF(millisecond, @Begin, GETDATE())
			;

		IF	@Debug = 1
		BEGIN
			-- Force the output to appear immediately --
			RAISERROR('From Origin - Insert #tmpOSTrader - %d rows - %d ms', 0, 0, @RowCount, @Duration) WITH NOWAIT;
		END;
	
		INSERT INTO	#tmpBettransDate (winlostdate)
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
			-- Force the output to appear immediately --
			RAISERROR('From Origin - Insert #tmpBettransDate - %d rows - %d ms', 0, 0, @RowCount, @Duration) WITH NOWAIT;
		END;

		-- No input date range: Default job run
		IF (@IsRunningJob = 1)
		BEGIN
			INSERT INTO dbo.OSStaging_EventDate(EventDate)
			SELECT winlostdate FROM #tmpBettransDate

			SELECT	@RowCount	= @@ROWCOUNT
				,	@Duration	= DATEDIFF(millisecond, @Begin, GETDATE())
				;

			IF	@Debug = 1
			BEGIN
				-- Force the output to appear immediately --
				RAISERROR('From Origin - Insert OSStaging_EventDate - %d rows - %d ms', 0, 0, @RowCount, @Duration) WITH NOWAIT;
			END;
		END;

		INSERT INTO #tmpFilteredBettrans
			(	  transid,  custid, matchid,   winlostdate,   bettype,   modds,   stake,   actual_stake,   virtualrate,   winlost,   awinlost,   mwinlost,   swinlost,   tpositiontaking,   srecommend,   scomm)
		SELECT	b.transid, b.custid, b.matchid, b.winlostdate, b.bettype, b.modds, b.stake, b.actual_stake, b.virtualrate, b.winlost, b.awinlost, b.mwinlost, b.swinlost, b.tpositiontaking, b.srecommend, b.scomm
		FROM	bodb02.dbo.bettrans AS b WITH (NOLOCK)
		WHERE	b.winlostdate BETWEEN @FromDateOrigin AND @ToDateOrigin
			AND	b.statusID IN (112, 113)
			AND	b.ruben = 1
			AND	b.Currency NOT IN (20, 27, 28)
			AND	b.LiveIndicator = 1
		;
		
		WHILE	EXISTS (SELECT 1 FROM #tmpBettransDate)
		BEGIN
			SELECT	TOP(1)
					@WinLostDate = d.winlostdate
			FROM	#tmpBettransDate AS d;
			
			TRUNCATE TABLE	#tmpFilteredBettransByBatch;
			INSERT INTO #tmpFilteredBettransByBatch 
				(	  transid,  custid, matchid,   winlostdate,   bettype,   modds,   stake,   actual_stake,   virtualrate,   winlost,   awinlost,   mwinlost,   swinlost,   tpositiontaking,   srecommend,   scomm)
			SELECT	b.transid, b.custid, b.matchid, b.winlostdate, b.bettype, b.modds, b.stake, b.actual_stake, b.virtualrate, b.winlost, b.awinlost, b.mwinlost, b.swinlost, b.tpositiontaking, b.srecommend, b.scomm
			FROM	#tmpFilteredBettrans AS b WITH (NOLOCK)
			WHERE	b.winlostdate = @WinLostDate;
			
			SELECT	@RowCount	= @@ROWCOUNT
				,	@Duration	= DATEDIFF(millisecond, @Begin, GETDATE())
				;
	
			IF	@Debug = 1
			BEGIN
				-- Force the output to appear immediately --
				RAISERROR('From Origin - Insert #tmpFilteredBettransByBatch - %d rows - %d ms', 0, 0, @RowCount, @Duration) WITH NOWAIT;
			END;
			
			INSERT INTO #tmpStagingOSTraderPerformance (CustId, MemberCustId, EventDate, MatchId, BetType, Stake, WinLost, SMAWinLost, Comm, ExtraPT, TPositionTaking, VirtualRate)
			SELECT	[CustId]			= t.CustId
				,	[MemberCustId]		= b.custid
				,	[EventDate]			= t.EventDate
				,	[MatchId]			= t.matchid
				,	[BetType]			= b.bettype
				,	[Stake]				= ((CASE WHEN b.modds = 0.25 OR b.modds = -0.25 THEN ABS(b.stake) / 2 ELSE ABS(b.stake) END) * b.virtualrate) --turn over
				,	[WinLost]			= (b.winlost - b.actual_stake)  --Winlost
				,	[SMAWinLost]		= (b.awinlost + b.mwinlost + b.swinlost)  --SMAWinlost
				,	[Comm]				= b.scomm  --Commission
				,	[ExtraPT]			= SUM(ISNULL(es.ExtraPT, 0))
				,	[TPositionTaking]	= b.tpositiontaking
				,	[VirtualRate]		= b.virtualrate
			FROM		#tmpFilteredBettransByBatch AS b
			INNER JOIN	#tmpOSTrader AS t WITH (NOLOCK)
					ON	b.winlostdate = t.EventDate
					AND	b.matchid = t.matchid
					AND	b.bettype = t.BetType
			LEFT JOIN	bodb_ACC.dbo.Acc_GroupExtraPTSetting AS es WITH (NOLOCK)
					ON	es.SuperId = b.srecommend
					AND	es.ProductId = 1
					AND	es.SportType = 0
					AND	es.SubProduct = ''
					AND	t.EventDate BETWEEN es.FromDate AND es.ToDate
			GROUP BY	t.CustId, b.custid, t.EventDate, t.matchid, b.BetType
					,	((CASE WHEN b.modds = 0.25 OR b.modds = -0.25 THEN ABS(b.stake) / 2 ELSE ABS(b.stake) END) * b.virtualrate)
					,	(WinLost - actual_stake), (awinlost + mwinlost + swinlost)
					,	b.scomm, b.tpositiontaking, b.virtualrate, b.transid
			OPTION (MAXDOP 2);

			SELECT	@RowCount	= @@ROWCOUNT
				,	@Duration	= DATEDIFF(millisecond, @Begin, GETDATE())
				;

			IF	@Debug = 1
			BEGIN
				-- Force the output to appear immediately --
				RAISERROR('From Origin - Insert #tmpStagingOSTraderPerformance - %d rows - %d ms', 0, 0, @RowCount, @Duration) WITH NOWAIT;
			END;
			
			DELETE dbo.OSDataTGRS WHERE EventDate = @winlostdate;

			INSERT INTO dbo.OSDataTGRS(TraderId, MatchId, MatchCode, EventDate, SportId, LeagueId, BettypeId, Turnover, WinLoss, Comm, BetCount, Target)
			SELECT	[TraderId]		= t.CustId
				,	[MatchId]		= m.MatchId
				,	[MatchCode]		= m.matchcode
				,	[EventDate]		= t.EventDate
				,	[SportId]		= t.SportType
				,	[LeagueId]		= m.LeagueId
				,	[BettypeId]		= b.BetType
				,	[Turnover]		= SUM(b.Stake * (1 - b.TPositionTaking - b.ExtraPT))
				,	[WinLoss]		= SUM(((-(b.WinLost + b.SMAWinLost)) + b.WinLost * b.ExtraPT) * b.VirtualRate)
				,	[Comm]			= SUM((b.Comm - (CASE WHEN b.TPositionTaking = 1 THEN 0 ELSE (b.Comm * b.ExtraPT / (1 - b.TPositionTaking)) END)) * b.VirtualRate)
				,	[BetCount]		= SUM(CASE WHEN tc.custid IS NULL THEN 1 ELSE 0 END) --Live BetCount	
				,	[Target]		= t.OSTarget
			FROM		#tmpStagingOSTraderPerformance AS b WITH (NOLOCK)
			INNER JOIN	bodb02.dbo.match AS m WITH (NOLOCK)
					ON	b.MatchId = m.MatchId
			INNER JOIN	#tmpOSTrader AS t WITH (NOLOCK)
					ON	m.MatchId = t.matchid
					AND	t.CustId = b.CustId
					AND	b.BetType = t.BetType
			LEFT JOIN bodb02.dbo.TradeCust tc WITH (NOLOCK) ON b.MemberCustId = tc.custid AND tc.VendorID = 14
			WHERE m.eventdate = @WinLostDate
			GROUP BY t.CustId, m.MatchId, m.matchcode, t.EventDate, t.SportType, m.LeagueId, b.BetType, t.OSTarget;
			
			SELECT	@RowCount	= @@ROWCOUNT
				,	@Duration	= DATEDIFF(millisecond, @Begin, GETDATE())
				;

			IF	@Debug = 1
			BEGIN
				-- Force the output to appear immediately --
				RAISERROR('From Origin - Insert OSDataTGRS - %d rows - %d ms', 0, 0, @RowCount, @Duration) WITH NOWAIT;
			END;
			
			-- Remove batched-data (bettrans & date) from source
			DELETE
			FROM	#tmpFilteredBettrans
			WHERE	winlostdate = @winlostdate;

			DELETE
			FROM	#tmpBettransDate
			WHERE	winlostdate = @winlostdate;
			
			TRUNCATE TABLE	#tmpStagingOSTraderPerformance;
			TRUNCATE TABLE	#tmpFilteredBettransByBatch;
		END;
	END;
END;

GO
/*<info serverAlias="DBTGRS-bodb_TGRS" executers="bodbTGRSNet" isFunction="0" isNested="0"></info>*/