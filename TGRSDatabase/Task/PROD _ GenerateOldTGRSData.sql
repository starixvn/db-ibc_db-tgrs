DECLARE	@FROM	DATETIME = '20170723'
	,	@TO		DATETIME = '20170731'
	;


--	BEGIN STEP 1:
--		Task_StagingDataTGRS
----------------------------------------------------------------------------------------------------

SET NOCOUNT ON;

DECLARE	@IdForUnassignedTrader	INT = 0
	;

DECLARE	@Begin					DATETIME	= GETDATE()
	,	@RowCount				INT
	,	@Msg					NVARCHAR(MAX)
	,	@Duration				INT
	;

DECLARE @BalanceUpDay			DATETIME
	;

DECLARE	@WinLostDate			DATETIME
	;


BEGIN;
	IF	OBJECT_ID('tempdb..#Spread1x2') IS NOT NULL
	BEGIN;
		DROP TABLE	#Spread1x2
	END;

	CREATE TABLE	#Spread1x2 (
						Margin	MONEY
					,	Spread	MONEY
					);
						
	INSERT INTO	#Spread1x2
			(Margin, Spread)
	VALUES	(1.05  , 0.2   )
		,	(1.08  , 0.3   )
		,	(1.10  , 0.36  )
		,	(1.12  , 0.44  )
		,	(1.15  , 0.52  )
		;

	SELECT	@BalanceUpDay	= MIN(winlostdate)
	FROM	bodb02.dbo.bettrans14 WITH (NOLOCK);

	BEGIN;
		SELECT	@Msg = '
@BalanceUpDay = ' + CONVERT(NVARCHAR, @BalanceUpDay, 120) + N'
@FROM         = ' + CONVERT(NVARCHAR, @FROM, 120) + N'
@TO           = ' + CONVERT(NVARCHAR, @TO, 120) + N'


';

		-- Force the output to appear immediately --
		RAISERROR(@Msg, 0, 0) WITH NOWAIT;
	END;
	
	IF	@FROM > @TO OR @FROM >= @BalanceUpDay
	BEGIN;
		RAISERROR('@FROM > @TO OR @FROM > @BalanceUpDay', 0, 0) WITH NOWAIT;
		RETURN;
	END;

	IF	@TO	>= @BalanceUpDay
	BEGIN;
		SELECT	@TO = DATEADD(DAY, -1, @BalanceUpDay);
	END;
	
	BEGIN;
		SELECT	@Msg = '-- RUNNING --
@BalanceUpDay = ' + CONVERT(NVARCHAR, @BalanceUpDay, 120) + N'
@FROM         = ' + CONVERT(NVARCHAR, @FROM, 120) + N'
@TO           = ' + CONVERT(NVARCHAR, @TO, 120) + N'

';

		-- Force the output to appear immediately --
		RAISERROR(@Msg, 0, 0) WITH NOWAIT;
	END;
	
	IF	OBJECT_ID('tempdb..#tmpTrader') IS NOT NULL
	BEGIN;
		DROP TABLE #tmpTrader;
	END;
	
	CREATE TABLE	#tmpTrader (
						CustId			INT
					,	LeagueId		INT
					,	MatchId			INT
					,	WorkShift		TINYINT
					,	MatchCode		VARCHAR(100)
					,	SportType		INT
					,	EventDate		DATETIME
					,	HomeId			INT
					,	AwayId			INT
					,	BetType			SMALLINT
					,	SpecialType		TINYINT
					,	TeamId			INT
					,	Grade			TINYINT
					);

	CREATE CLUSTERED INDEX	#CIX_tmpTraderIdx ON #tmpTrader (
								CustId		ASC
							,	EventDate	ASC
							,	MatchId		ASC
							,	BetType		ASC
							);

	IF	OBJECT_ID('tempdb..#winlostdate') IS NOT NULL
	BEGIN;
		DROP TABLE	#winlostdate;
	END;

	CREATE TABLE	#winlostdate (
						winlostdate		DATETIME
					);

	IF	OBJECT_ID('tempdb..#tmpFilteredBettransBKByBatch') IS NOT NULL
	BEGIN;
		DROP TABLE	#tmpFilteredBettransBKByBatch;
	END;
	
	CREATE TABLE	#tmpFilteredBettransBKByBatch (
						transid				BIGINT
					,	matchid				INT
					,	winlostdate			SMALLDATETIME
					,	bettype				SMALLINT
					,	modds				SMALLMONEY
					,	virtualrate			FLOAT
					,	tpositiontaking		SMALLMONEY
					,	srecommend			INT
					,	scomm				MONEY
					,	ExtraPT				DECIMAL(9, 8)
					,	Spread				MONEY
					,	Stake				MONEY
					,	WinLost				MONEY
					,	SMAWinLost			MONEY
					,	MatchCode			VARCHAR(100)
					,	EventDate			DATETIME
					,	SportType			INT
					,	LeagueId			INT
					,	HomeId				INT
					,	AwayId				INT
					);

	CREATE CLUSTERED INDEX	#CIX_tmpFilteredBettransBKByBatchIdx ON #tmpFilteredBettransBKByBatch (
								winlostdate		ASC
							,	MatchId			ASC
							,	BetType			ASC
							);

	IF	OBJECT_ID('tempdb..#tmpStagingTraderPerformance') IS NOT NULL
	BEGIN;
		DROP TABLE	#tmpStagingTraderPerformance;
	END;

	CREATE TABLE	#tmpStagingTraderPerformance (
						CustId				INT
					,	WorkShift			TINYINT
					,	MatchId				INT
					,	MatchCode			VARCHAR(100)
					,	EventDate			DATETIME
					,	SportType			INT
					,	LeagueId			INT
					,	HomeId				INT
					,	AwayId				INT
					,	TeamId				INT
					,	Grade				TINYINT
					,	BetType				SMALLINT
					,	Stake				MONEY
					,	WinLost				MONEY
					,	SMAWinLost			MONEY
					,	Comm				MONEY
					,	BetCount			INT
					,	Spread				MONEY
					,	ExtraPT				DECIMAL(9, 8)
					,	TPositionTaking		SMALLMONEY
					,	VirtualRate			FLOAT
					);
		
	IF	OBJECT_ID('tempdb..#Staging_TraderPerformance') IS NOT NULL
	BEGIN;
		DROP TABLE	#Staging_TraderPerformance;
	END;

	CREATE TABLE	#Staging_TraderPerformance(
						CustId			INT				NULL
					,	MatchId			INT				NULL
					,	MatchCode		VARCHAR(100)	NULL
					,	EventDate		DATE			NULL
					,	SportType		TINYINT			NULL
					,	BetType			SMALLINT		NULL
					,	LeagueId		INT				NULL
					,	TeamId			SMALLINT		NULL
					,	Grade			TINYINT			NULL
					,	Stake			MONEY			NULL
					,	WinLost			MONEY			NULL
					,	Comm			MONEY			NULL
					,	BetCount		INT				NULL
					,	HomeId			INT				NULL
					,	AwayId			INT				NULL
					,	WorkShift		TINYINT			NULL
					,	Spread			MONEY			NULL
					);

	BEGIN;
		INSERT INTO	#tmpTrader (CustId, LeagueId, WorkShift, MatchId, SportType, EventDate, HomeId, AwayId, BetType, SpecialType, Matchcode, TeamId, Grade)
		SELECT	DISTINCT
				'CustId'		= a.OperatorID
			,	'LeagueId'		= m.LeagueId
			,	'WorkShift'		= CASE	WHEN CAST(m.kickofftime AS TIME) >= '00:00:00' AND CAST(m.kickofftime AS TIME) < '06:00:00'
											THEN 1 --  Afternoon: 12:00:00 ~ 17:59:59 (GMT + 8)
										WHEN CAST(m.kickofftime AS TIME) >= '06:00:00' AND CAST(m.kickofftime AS TIME) < '16:00:00'
											THEN 2 -- Night: 18:00:00 ~ 3:59:59 (GMT + 8)				
										--WHEN CAST(m.kickofftime AS TIME) >= '16:00:00' AND CAST(m.kickofftime AS TIME) <'24:00:00'THEN 3 --  Midnight: 4:00:00 ~ 11:59:59 (GMT + 8)
										ELSE 3
								  END
			,	'MatchId'		= m.MatchId
			,	'SportType'		= m.sporttype
			,	'EventDate'		= m.EventDate
			,	'HomeId'		= m.HomeId
			,	'AwayId'		= m.AwayId
			,	'BetType'		= CASE	WHEN a.bettype = 5 AND a.operatortype = 1
											THEN 1
										ELSE ISNULL(b.MainDBBetType, 0) 
								  END
			,	'SpecialType'	= CASE	WHEN LeagueName LIKE '%SPECIFIC 15 MINS TOTAL BOOKINGS%'
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
			,	'Matchcode'		= m.Matchcode
			,	'TeamId'		= td_T.TeamId
			,	'Grade'			= td_G.Grade
		FROM		bodb_archive.dbo.Dot_Admin_Assignment_Operator_bk AS a WITH (NOLOCK)
		INNER JOIN	bodb_archive.dbo.Match_bk AS m WITH (NOLOCK)
				ON	a.matchid = m.matchid
		LEFT JOIN	bodb02.dbo.Team AS t WITH (NOLOCK)
				ON	m.homeid = t.teamid
		LEFT JOIN	bodb02.dbo.League AS l WITH (NOLOCK)
				ON	m.leagueid = l.leagueid
		LEFT JOIN	dbo.BetType AS b WITH (NOLOCK)
				ON	a.bettype = b.AssignmentBetType
				AND	a.OperatorType = b.OperatorType
		LEFT JOIN	dbo.TraderGrade_History AS td_G WITH (NOLOCK)
				ON	td_G.CustID = a.OperatorID
				AND	m.EventDate BETWEEN td_G.BeginDate AND ISNULL(td_G.EndDate, GETDATE() + 10)
		LEFT JOIN	dbo.TraderTeam_History AS td_T WITH (NOLOCK)
				ON	td_T.CustID = a.OperatorID
				AND	m.EventDate BETWEEN td_T.BeginDate AND ISNULL(td_T.EndDate, GETDATE() + 10)
		WHERE	m.EventDate BETWEEN @FROM AND @TO
			--AND	m.EventStatus='completed'
			AND	m.SportType = 1
			AND	a.OperatorType < 3
			AND	m.MatchCode NOT LIKE '%hedge%';

		SELECT	@RowCount	= @@ROWCOUNT
			,	@Duration	= DATEDIFF(millisecond, @Begin, GETDATE())
			;

		BEGIN;
			-- Force the output to appear immediately --
			RAISERROR('Insert #tmpTrader - %d rows - %d ms', 0, 0, @RowCount, @Duration) WITH NOWAIT;
		END;

		INSERT INTO	#winlostdate (winlostdate)
		SELECT	tally.winlostdate
		FROM	(
			SELECT	'NoDays' = DATEDIFF(DAY, @FROM, @TO) + 1
		) cnt
		CROSS APPLY	(
			SELECT	TOP(cnt.NoDays)
					'winlostdate' = DATEADD(DAY, ROW_NUMBER() OVER(ORDER BY (SELECT NULL)) - 1, @FROM)
			FROM		(VALUES (0), (0), (0), (0), (0), (0), (0), (0), (0), (0)) x10(n)
			CROSS APPLY	(VALUES (0), (0), (0), (0), (0), (0), (0), (0), (0), (0)) x100(n)
			CROSS APPLY	(VALUES (0), (0), (0), (0), (0), (0), (0), (0), (0), (0)) x1000(n)
		) tally;

		SELECT	@RowCount	= @@ROWCOUNT
			,	@Duration	= DATEDIFF(millisecond, @Begin, GETDATE())
			;

		BEGIN;
			-- Force the output to appear immediately --
			RAISERROR('Insert #winlostdate - %d rows - %d ms', 0, 0, @RowCount, @Duration) WITH NOWAIT;
		END;

		------------
		WHILE	EXISTS (SELECT 1 FROM #winlostdate)
		BEGIN;
			SELECT	TOP(1)
					@WinLostDate = d.winlostdate
			FROM	#winlostdate AS d;
			
			INSERT INTO	#tmpFilteredBettransBKByBatch (transid, matchid, winlostdate, bettype, modds, virtualrate, tpositiontaking, srecommend, scomm, ExtraPT, Spread, Stake, WinLost, SMAWinLost, MatchCode, EventDate, SportType, LeagueId, HomeId, AwayId)
			SELECT	'transid'			= b.transid
				,	'matchid'			= b.matchid
				,	'winlostdate'		= b.winlostdate
				,	'bettype'			= CASE	WHEN b.bettype = 1308
													THEN 153
												WHEN b.bettype = 1311
													THEN 154
												WHEN b.bettype = 1316
													THEN 155
												WHEN b.bettype IN (2, 4, 6, 12, 13, 16, 22, 24, 25, 26, 27, 28, 30, 121, 122, 123, 126, 129, 143, 144, 151, 159, 161, 162, 171, 191, 401, 402, 403, 404, 405, 406, 407, 408, 409, 410, 411, 412, 413, 414, 417, 418, 448, 449, 450, 451, 452, 458)
													THEN 459
												ELSE b.bettype
											END
				,	'modds'				= b.modds
				,	'virtualrate'		= b.virtualrate
				,	'tpositiontaking'	= b.tpositiontaking
				,	'srecommend'		= b.srecommend
				,	'scomm'				= b.scomm
				,	'ExtraPT'			= CASE WHEN m.eventdate < '20170221' THEN 0 ELSE es.ExtraPT END
				,	'Spread'			= CASE WHEN mm.BetType IN (5, 15) THEN ISNULL(s.Spread, - (4 / mm.Spread - 4)) ELSE mm.Spread END
				,	'Stake'				= ((CASE WHEN b.modds = 0.25 OR b.modds = - 0.25 THEN ABS(b.stake) / 2 ELSE ABS(b.stake) END) * b.virtualrate)
				,	'WinLost'			= winlost - actual_stake
				,	'SMAWinLost'		= awinlost + mwinlost + swinlost
				,	'MatchCode'			= m.MatchCode
				,	'EventDate'			= m.EventDate
				,	'SportType'			= m.SportType
				,	'LeagueId'			= m.LeagueId
				,	'HomeId'			= m.HomeId
				,	'AwayId'			= m.AwayId
			FROM		bodb_Archive.dbo.bettrans_bk AS b WITH (NOLOCK)
			INNER JOIN	bodb_Archive.dbo.match_bk AS m WITH (NOLOCK)
					ON	b.matchid = m.matchid
			LEFT JOIN	bodb_ACC.dbo.Acc_GroupExtraPTSetting AS es WITH (NOLOCK)
					ON	es.SuperId = b.srecommend
					AND	es.ProductId = 1
					AND	es.Sporttype = 0
					AND	es.SubProduct = ''
					AND	b.winlostdate BETWEEN es.FromDate AND es.ToDate
			LEFT JOIN	bodb_Archive.dbo.MatchMaxbet_bk AS mm WITH (NOLOCK)
					ON	mm.MatchId = b.matchid
					AND	(	mm.BetType = b.bettype
						OR	(b.bettype = 124 AND mm.BetType = 5)
						OR	(b.bettype = 125 AND mm.BetType = 15)
						)
			LEFT JOIN	#Spread1x2 AS s
					ON	mm.Spread = s.Margin
					AND	mm.BetType IN (5, 15)
			WHERE	b.winlostdate = @WinLostDate
				AND	b.statusID IN (112, 113)
				AND	b.Currency NOT IN (20, 27, 28)
				AND	b.LiveIndicator = 1
				AND	m.sporttype = 1
				AND	m.MatchCode NOT LIKE '%hedge%';
					
			SELECT	@RowCount	= @@ROWCOUNT
				,	@Duration	= DATEDIFF(millisecond, @Begin, GETDATE())
				;

			BEGIN;
				-- Force the output to appear immediately --
				RAISERROR('	Insert #tmpFilteredBettransBKByBatch - %d rows - %d ms', 0, 0, @RowCount, @Duration) WITH NOWAIT;
			END;
			
			INSERT INTO	#tmpStagingTraderPerformance (CustId, WorkShift, MatchId, MatchCode, EventDate, SportType, LeagueId, HomeId, AwayId, TeamId, Grade, BetType, Stake, WinLost, SMAWinLost, Comm, BetCount, Spread, ExtraPT, TPositionTaking, VirtualRate)
			SELECT	'CustId'			= ISNULL(t.Custid, @IdForUnassignedTrader)
				,	'WorkShift'			= ISNULL(t.WorkShift, 1)
				,	'MatchId'			= b.MatchId
				,	'MatchCode'			= b.MatchCode
				,	'EventDate'			= b.EventDate
				,	'SportType'			= b.SportType
				,	'LeagueId'			= b.LeagueId
				,	'HomeId'			= b.HomeId
				,	'AwayId'			= b.AwayId
				,	'TeamId'			= t.TeamId
				,	'Grade'				= t.Grade
				,	'BetType'			= ca.BetType
				,	'Stake'				= b.Stake --turn over
				,	'WinLost'			= b.WinLost
				,	'SMAWinLost'		= b.SMAWinLost
				,	'Comm'				= scomm --Commission
				,	'BetCount'			= 1 --Live BetCount
				,	'Spread'			= b.Spread
				,	'ExtraPT'			= SUM(ISNULL(b.ExtraPT, 0))
				,	'TPositionTaking'	= b.tpositiontaking
				,	'VirtualRate'		= b.virtualrate
			FROM		#tmpFilteredBettransBKByBatch AS b WITH (NOLOCK)
			LEFT JOIN	#tmpTrader AS t WITH (NOLOCK)
					ON	b.winlostdate = t.EventDate
					AND	b.matchid = t.matchid
					AND	(	b.BetType = t.BetType
						OR	(b.bettype = 124 AND t.BetType = 5)
						OR	(b.bettype = 125 AND t.BetType = 15)
						OR	(b.bettype = 23 AND t.BetType = 1)
						)
			CROSS APPLY	(
				SELECT	'BetType'	= CASE	WHEN b.BetType = 1 AND SpecialType = 0
												THEN 1 --HDP
											WHEN b.BetType = 7
												THEN 7 --1st HDP
											WHEN b.BetType = 3 AND SpecialType = 0
												THEN 3 --O/U		
											WHEN b.BetType = 8 AND SpecialType = 0
												THEN 8 --1st O/U
											WHEN b.BetType = 2
												THEN 2 --O/E
											WHEN b.BetType = 12
												THEN 12 --1x2
											WHEN b.BetType IN (5, 124) AND SpecialType = 0
												THEN 5 --1x2		
											WHEN b.BetType IN (5, 124) AND SpecialType = 5
												THEN - 14 --10mins 1x2
											WHEN b.BetType IN (15, 125) AND SpecialType = 0
												THEN 15 --1st 1x2
											WHEN b.BetType = 1 AND SpecialType = 4
												THEN - 1 --15mins HDP
											WHEN (b.bettype = 23 AND t.BetType = 1) OR (b.BetType = 1 AND SpecialType = 8)
												THEN - 2 --Next Corner
											WHEN b.BetType = 1 AND SpecialType = 5
												THEN - 15 --10mins HDP
											WHEN b.BetType = 1 AND SpecialType = 9
												THEN - 3 --Next Booking
											WHEN b.BetType IN (5, 124) AND SpecialType = 4
												THEN - 4 --15mins 1X2
											WHEN b.BetType = 3 AND SpecialType = 4
												THEN - 5 --15mins O/U
											WHEN b.BetType = 3 AND SpecialType = 5
												THEN - 6 --10mins O/U
											WHEN b.BetType = 3 AND SpecialType = 2
												THEN - 7 --Corners 15mins O/U
											WHEN b.BetType = 3 AND SpecialType = 7
												THEN - 8 --Total Bookings
											WHEN b.BetType = 3 AND SpecialType = 1
												THEN - 10 --Total Bookings 15mins O/U
											WHEN b.BetType = 3 AND SpecialType = 6
												THEN - 13 --No. of Corner
											WHEN b.BetType = 8 AND SpecialType = 6
												THEN - 12 --1st No. of Corner
											WHEN b.BetType = 8 AND SpecialType = 7
												THEN - 9 --1st TotalBookings
											WHEN (b.BetType = 3 OR b.BetType = 8) AND SpecialType = 3
												THEN - 11 --Single Team O/U
											WHEN b.BetType IN (5, 124)
												THEN 5 --1x2	
											WHEN b.BetType IN (15, 125)
												THEN 15 --1st 1x2
											ELSE b.BetType
										END
			) AS ca
			WHERE	b.winlostdate = @WinLostDate
			GROUP BY	ISNULL(t.Custid, @IdForUnassignedTrader)
					,	ISNULL(t.WorkShift, 1)
					,	b.MatchId
					,	b.MatchCode
					,	b.EventDate
					,	b.SportType
					,	b.LeagueId
					,	b.HomeId
					,	b.AwayId
					,	t.TeamId
					,	t.Grade
					,	ca.BetType
					,	b.Stake
					,	b.WinLost
					,	b.SMAWinLost
					,	scomm
					,	b.Spread
					,	b.tpositiontaking
					,	b.virtualrate
					,	b.transid
					;
			
			SELECT	@RowCount	= @@ROWCOUNT
				,	@Duration	= DATEDIFF(millisecond, @Begin, GETDATE())
				;

			BEGIN;
				-- Force the output to appear immediately --
				RAISERROR('	Insert #tmpStagingTraderPerformance - %d rows - %d ms', 0, 0, @RowCount, @Duration) WITH NOWAIT;
			END;

			INSERT INTO	#Staging_TraderPerformance (CustId, WorkShift, MatchId, MatchCode, EventDate, SportType, LeagueId, HomeId, AwayId, TeamId, Grade, BetType, Stake, WinLost, Comm, BetCount, Spread)
			SELECT	'CustId'			= t.CustId
				,	'WorkShift'			= t.WorkShift
				,	'MatchId'			= t.MatchId
				,	'MatchCode'			= t.MatchCode
				,	'EventDate'			= t.EventDate
				,	'SportType'			= t.SportType
				,	'LeagueId'			= t.LeagueId
				,	'HomeId'			= t.HomeId
				,	'AwayId'			= t.AwayId
				,	'TeamId'			= t.TeamId
				,	'Grade'				= t.Grade
				,	'BetType'			= t.BetType
				,	'Stake'				= SUM(t.Stake * (1 - t.TPositionTaking - t.ExtraPT))
				,	'WinLost'			= SUM(((-(t.WinLost + t.SMAWinLost)) + t.WinLost * t.ExtraPT) * t.virtualrate)
				,	'Comm'				= SUM((Comm - (CASE WHEN t.TPositionTaking = 1 THEN 0 ELSE (Comm * t.ExtraPT/(1 - t.TPositionTaking)) END)) * t.virtualrate)
				,	'BetCount'			= SUM(t.BetCount)
				,	'Spread'			= MAX(t.Spread)
			FROM	#tmpStagingTraderPerformance AS t
			GROUP BY t.CustId, t.WorkShift, t.MatchId, t.MatchCode, t.EventDate, t.SportType, t.LeagueId, t.HomeId, t.AwayId, t.TeamId, t.Grade, t.BetType;
					
			SELECT	@RowCount	= @@ROWCOUNT
				,	@Duration	= DATEDIFF(millisecond, @Begin, GETDATE())
				;

			BEGIN;
				-- Force the output to appear immediately --
				RAISERROR('	Insert #Staging_TraderPerformance - %d rows - %d ms', 0, 0, @RowCount, @Duration) WITH NOWAIT;
			END;

			DELETE	d
			FROM	#winlostdate AS d
			WHERE	d.winlostdate = @WinLostDate;
				
			SELECT	@RowCount	= @@ROWCOUNT
				,	@Duration	= DATEDIFF(millisecond, @Begin, GETDATE())
				;

			BEGIN;
				-- Force the output to appear immediately --
				PRINT	@WinLostDate
				RAISERROR('DELETE #winlostdate - %d rows - %d ms', 0, 0, @RowCount, @Duration) WITH NOWAIT;
			END;

			TRUNCATE TABLE #tmpStagingTraderPerformance;
			TRUNCATE TABLE #tmpFilteredBettransBKByBatch;
		END;
	END;
END;


--	BEGIN STEP 2:
--		Daily
----------------------------------------------------------------------------------------------------

DECLARE db_cursor CURSOR FOR  
SELECT EventDate FROM #Staging_TraderPerformance WITH(NOLOCK) GROUP BY EventDate

OPEN db_cursor   
FETCH NEXT FROM db_cursor INTO @WinLostDate   

WHILE @@FETCH_STATUS = 0   
BEGIN   
       PRINT @WinLostDate
	   
	DELETE [dbo].[TraderPerformance]	WHERE EventDate = @WinLostDate;

	INSERT INTO [dbo].[TraderPerformance]
           ([CustId]
           ,[MatchId]
		   ,[WorkShift]
		   ,[MatchCode]
           ,[EventDate]
           ,[SportType]
           ,[BetType]
           ,[LeagueId]
 		   ,[HomeId]
           ,[AwayId]
           ,[TeamId]
           ,[Grade]
           ,[Stake]
           ,[WinLost]
           ,[Comm]
           ,[BetCount]
		   ,[Spread]
           )
 
	SELECT [CustId]
           ,[MatchId]
		   ,[WorkShift]
		   ,[MatchCode]
           ,[EventDate]
           ,[SportType]
           ,[BetType]
           ,[LeagueId]
 		   ,[HomeId]
           ,[AwayId]
           ,[TeamId]
           ,[Grade]
           ,[Stake]
           ,[WinLost]
           ,[Comm]
           ,[BetCount]
		   ,[Spread]
	  FROM #Staging_TraderPerformance WITH(NOLOCK)
	  WHERE EventDate = @WinLostDate;
 
	DELETE [dbo].[SummaryByBetType_Daily]	WHERE EventDate = @WinLostDate;

	INSERT INTO [dbo].[SummaryByBetType_Daily]
		([EventDate]
		  ,[LeagueId]
		  ,[BetType]
		   ,[WorkShift]
		  ,[Stake]
		  ,[WinLost]
		  ,[Comm]
		  ,[BetCount]
		  ,[MatchCount]
		)
	SELECT @WinLostDate [EventDate]
		  ,[LeagueId]
		  ,[BetType]
		   ,[WorkShift]
		  ,SUM([Stake]) [Stake]
		  ,SUM([WinLost]) [WinLost]
		  ,SUM([Comm]) [Comm]
		  ,SUM([BetCount]) BetCount
		  ,COUNT(DISTINCT [MatchId])[MatchCount]
	  FROM #Staging_TraderPerformance WITH(NOLOCK)
	  WHERE EventDate = @WinLostDate
	  GROUP BY [LeagueId]
		  ,[BetType]
		   ,[WorkShift];

	DELETE [dbo].[SummaryByLeague_Daily]	WHERE EventDate = @WinLostDate;

	INSERT INTO [dbo].[SummaryByLeague_Daily]
		([EventDate]
		  ,[LeagueId]
		   ,[WorkShift]
		  ,[Stake]
		  ,[WinLost]
		  ,[Comm]
		  ,[BetCount]
		  ,[MatchCount]
		)
	SELECT @WinLostDate [EventDate]
		  ,[LeagueId]
		   ,[WorkShift]
		  ,SUM([Stake]) [Stake]
		  ,SUM([WinLost]) [WinLost]
		  ,SUM([Comm]) [Comm]
		  ,SUM([BetCount]) BetCount
		  ,COUNT(DISTINCT [MatchId])[MatchCount]
	  FROM #Staging_TraderPerformance WITH(NOLOCK)
	  WHERE EventDate = @WinLostDate
	  GROUP BY [LeagueId]
		   ,[WorkShift];

	DELETE [dbo].[SummaryByTeam_Daily]	WHERE EventDate = @WinLostDate;

	INSERT INTO [dbo].[SummaryByTeam_Daily]
		([EventDate]
		  ,[TeamId]
		   ,[WorkShift]
		  ,[Stake]
		  ,[WinLost]
		  ,[Comm]
		  ,[BetCount]
		  ,[MatchCount]
		)
	SELECT @WinLostDate [EventDate]
		  ,[TeamId]
		   ,[WorkShift]
		  ,SUM([Stake]) [Stake]
		  ,SUM([WinLost]) [WinLost]
		  ,SUM([Comm]) [Comm]
		  ,SUM([BetCount]) BetCount
		  ,COUNT(DISTINCT [MatchId])[MatchCount]
	  FROM #Staging_TraderPerformance WITH(NOLOCK)
	  WHERE EventDate = @WinLostDate
	  GROUP BY [TeamId]
		   ,[WorkShift];

       FETCH NEXT FROM db_cursor INTO @WinLostDate   
END   

CLOSE db_cursor   
DEALLOCATE db_cursor


--	BEGIN STEP 3:
--		Monthly
----------------------------------------------------------------------------------------------------

DECLARE db_cursor CURSOR FOR  
SELECT DISTINCT EventDate = DATEADD(MONTH, DATEDIFF(MONTH, 0, EventDate), 0)
FROM #Staging_TraderPerformance WITH(NOLOCK) 

OPEN db_cursor   
FETCH NEXT FROM db_cursor INTO @WinLostDate   

WHILE @@FETCH_STATUS = 0   
BEGIN   
       PRINT @WinLostDate
	   EXEC [dbo].[Task_StagingTraderPerformanceByMonth]	@Month=@WinLostDate
       FETCH NEXT FROM db_cursor INTO @WinLostDate   
END   

CLOSE db_cursor   
DEALLOCATE db_cursor


--	BEGIN STEP 4:
--		Task_StagingJuice
----------------------------------------------------------------------------------------------------

BEGIN;
	BEGIN;
		SELECT	@Msg = '-- RUNNING --
@BalanceUpDay = ' + CONVERT(NVARCHAR, @BalanceUpDay, 120) + N'
@FROM         = ' + CONVERT(NVARCHAR, @FROM, 120) + N'
@TO           = ' + CONVERT(NVARCHAR, @TO, 120) + N'

';

		-- Force the output to appear immediately --
		RAISERROR(@Msg, 0, 0) WITH NOWAIT;
	END;
	
	IF	OBJECT_ID('tempdb..#tmpDataGroup') IS NOT NULL
	BEGIN;
		DROP TABLE	#tmpDataGroup;
	END;

	CREATE TABLE	#tmpDataGroup (
						CustId				INT
					,	EventDate			DATE
					,	MatchId				INT
					,	BetType				SMALLINT
					,	BetTeam				VARCHAR(10)
					,	ScoreHDP			SMALLMONEY
					,	AVGOdds				FLOAT
					,	StakeMYBeforeComm	MONEY
					,	StakeMY				MONEY
					,	Stake				MONEY
					,	MOdds				SMALLMONEY
					,	StatusID			TINYINT
					);

	IF	OBJECT_ID('tempdb..#tmpFilteredBettransBKByBatch2') IS NOT NULL
	BEGIN;
		DROP TABLE	#tmpFilteredBettransBKByBatch2;
	END;

	CREATE TABLE	#tmpFilteredBettransBKByBatch2 (
						transid				BIGINT
					,	matchid				INT
					,	winlostdate			SMALLDATETIME
					,	bettype				SMALLINT
					,	modds				SMALLMONEY
					,	virtualrate			FLOAT
					,	tpositiontaking		SMALLMONEY
					,	scomm				MONEY
					,	betteam				VARCHAR(10)
					,	odds				SMALLMONEY
					,	statusID			TINYINT
					,	ExtraPT				DECIMAL(9, 8)
					,	ScoreHDP			SMALLMONEY
					,	StakeMY				MONEY
					,	Stake				MONEY
					);

	CREATE CLUSTERED INDEX	#CIX_tmpFilteredBettransBKByBatchIdx2 ON #tmpFilteredBettransBKByBatch2 (
								winlostdate	ASC
							,	MatchId		ASC
							,	BetType		ASC
							);

	IF	OBJECT_ID('tempdb..#tmpStagingTraderPerformance2') IS NOT NULL
	BEGIN;
		DROP TABLE	#tmpStagingTraderPerformance2;
	END;

	CREATE TABLE	#tmpStagingTraderPerformance2 (
						CustId				INT
					,	EventDate			DATE
					,	MatchId				INT
					,	BetType				SMALLINT
					,	BetTeam				VARCHAR(10)
					,	ScoreHDP			SMALLMONEY
					,	Odds				FLOAT
					,	StakeMY				MONEY
					,	Stake				MONEY
					,	ExtraPT				DECIMAL(9, 8)
					,	TPositionTaking		SMALLMONEY
					,	VirtualRate			FLOAT
					,	Scomm				MONEY
					,	MOdds				SMALLMONEY
					,	StatusID			TINYINT
					);

	IF	OBJECT_ID('tempdb..#tmpTrader2') IS NOT NULL
	BEGIN;
		DROP TABLE	#tmpTrader2;
	END;

	CREATE TABLE	#tmpTrader2 (
						CustId				INT
					,	MatchId				INT
					,	EventDate			DATETIME
					,	BetType				SMALLINT
					,	SpecialType			TINYINT
					);

	CREATE INDEX	#IDX_tmpTrader2 ON #tmpTrader2 (
						EventDate	ASC
					,	MatchId		ASC
					,	BetType		ASC
					);
					
	BEGIN;
		INSERT INTO	#tmpTrader2 (CustId, MatchId, EventDate, BetType, SpecialType)
		SELECT	DISTINCT
				'CustId'		= a.OperatorID
			,	'MatchId'		= m.MatchId
			,	'EventDate'		= m.EventDate
			,	'BetType'		= CASE	WHEN (a.BetType = 1 OR a.BetType = 5) AND a.OperatorType = 1
											THEN 1
										WHEN a.BetType = 1 AND a.OperatorType = 2
											THEN 7
										WHEN a.BetType = 2 AND a.OperatorType = 1
											THEN 3
										WHEN a.BetType = 2 AND a.OperatorType = 2
											THEN 8
										ELSE 0
								  END
			,	'SpecialType'	= CASE	WHEN LeagueName LIKE '%SPECIFIC 15 MINS TOTAL BOOKINGS%'
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
		FROM		bodb_Archive.dbo.Dot_Admin_Assignment_Operator_bk AS a WITH (NOLOCK)
		INNER JOIN	bodb_Archive.dbo.Match_bk AS m WITH (NOLOCK)
				ON	a.matchid = m.matchid
		LEFT JOIN	bodb02.dbo.Team AS t WITH (NOLOCK)
				ON	m.homeid = t.teamid
		LEFT JOIN	bodb02.dbo.League l WITH (NOLOCK)
				ON	m.leagueid = l.leagueid
		WHERE	m.EventDate BETWEEN @FROM AND @TO
			AND	m.SportType = 1
			AND	a.OperatorType < 3
			AND	m.MatchCode NOT LIKE '%hedge%';
			
		SELECT	@RowCount	= @@ROWCOUNT
			,	@Duration	= DATEDIFF(millisecond, @Begin, GETDATE())
			;

		BEGIN;
			-- Force the output to appear immediately --
			RAISERROR('Insert #tmpTrader2 - %d rows - %d ms', 0, 0, @RowCount, @Duration) WITH NOWAIT;
		END;
		
		INSERT INTO	#winlostdate (winlostdate)
		SELECT	tally.winlostdate
		FROM	(
			SELECT	'NoDays' = DATEDIFF(DAY, @FROM, @TO) + 1
		) cnt
		CROSS APPLY	(
			SELECT	TOP(cnt.NoDays)
					'winlostdate' = DATEADD(DAY, ROW_NUMBER() OVER(ORDER BY (SELECT NULL)) - 1, @FROM)
			FROM		(VALUES (0), (0), (0), (0), (0), (0), (0), (0), (0), (0)) x10(n)
			CROSS APPLY	(VALUES (0), (0), (0), (0), (0), (0), (0), (0), (0), (0)) x100(n)
			CROSS APPLY	(VALUES (0), (0), (0), (0), (0), (0), (0), (0), (0), (0)) x1000(n)
		) tally;

		SELECT	@RowCount	= @@ROWCOUNT
			,	@Duration	= DATEDIFF(millisecond, @Begin, GETDATE())
			;

		BEGIN;
			-- Force the output to appear immediately --
			RAISERROR('Insert #winlostdate - %d rows - %d ms', 0, 0, @RowCount, @Duration) WITH NOWAIT;
		END;

		------------
		WHILE	EXISTS (SELECT 1 FROM #winlostdate)
		BEGIN;
			SELECT	TOP(1)
					@WinLostDate = d.winlostdate
			FROM	#winlostdate AS d WITH (NOLOCK);

			-- Insert data into batch by Date
			INSERT INTO #tmpFilteredBettransBKByBatch2 (transid, matchid, winlostdate, bettype, modds, virtualrate, tpositiontaking, scomm, betteam, odds, statusID, ExtraPT, ScoreHDP, StakeMY, Stake)
			SELECT	'transid'			= b.transid
				,	'matchid'			= b.matchid
				,	'winlostdate'		= b.winlostdate
				,	'bettype'			= b.bettype
				,	'modds'				= b.modds
				,	'virtualrate'		= b.virtualrate
				,	'tpositiontaking'	= b.tpositiontaking
				,	'scomm'				= b.scomm
				,	'betteam'			= b.betteam
				,	'odds'				= b.odds
				,	'statusID'			= b.statusID
				,	'ExtraPT'			= CASE WHEN m.eventdate < '20170221' THEN 0 ELSE es.ExtraPT END
				,	'ScoreHDP'			= CASE	WHEN b.bettype IN (1, 7) THEN (b.hdp1 + b.livehomescore) - (b.hdp2 + b.liveawayscore)
												ELSE b.hdp1
											END
				,	'StakeMY'			= CASE WHEN ABS(b.odds) <= 1 THEN 1 ELSE ABS(b.odds) END
										* CASE WHEN ABS(b.modds) = 0.25 THEN 0.5 ELSE 1 END
										* ABS(b.stake)
				,	'Stake'				= CASE WHEN ABS(b.modds) = 0.25 THEN 0.5 ELSE 1 END
										* ABS(b.stake)
			FROM		bodb_archive.dbo.bettrans_bk AS b WITH (NOLOCK)
			INNER JOIN	bodb_Archive.dbo.Match_bk AS m WITH (NOLOCK)
					ON	b.matchid = m.matchid
			LEFT JOIN	bodb_ACC.dbo.Acc_GroupExtraPTSetting AS es WITH (NOLOCK)
					ON	es.SuperId = b.srecommend
					AND	es.ProductId = 1
					AND	es.Sporttype = 0
					AND	es.SubProduct = ''
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

			BEGIN;
				-- Force the output to appear immediately --
				RAISERROR('	Insert #tmpFilteredBettransBKByBatch2 - %d rows - %d ms', 0, 0, @RowCount, @Duration) WITH NOWAIT;
			END;

			-- Staging Performance 
			INSERT INTO #tmpStagingTraderPerformance2 (CustId, EventDate, MatchId, BetType, BetTeam, ScoreHDP, Odds, StakeMY, Stake, ExtraPT, TPositionTaking, VirtualRate, Scomm, MOdds, StatusID)
			SELECT	'CustId'			= ISNULL(t.Custid, @IdForUnassignedTrader)
				,	'EventDate'			= b.winlostdate
				,	'MatchId'			= b.matchid
				,	'BetType'			= ca.BetType
				,	'BetTeam'			= b.betteam
				,	'ScoreHDP'			= b.ScoreHDP
				,	'Odds'				= b.odds
				,	'StakeMY'			= b.StakeMY
				,	'Stake'				= b.Stake
				,	'ExtraPT'			= SUM(ISNULL(b.ExtraPT, 0))
				,	'TPositionTaking'	= b.tpositiontaking
				,	'VirtualRate'		= b.virtualrate
				,	'Scomm'				= b.scomm
				,	'MOdds'				= b.modds
				,	'StatusID'			= b.statusID
			FROM		#tmpFilteredBettransBKByBatch2 AS b
			LEFT JOIN	#tmpTrader2 AS t WITH (NOLOCK)
					ON	b.winlostdate = t.EventDate
					AND	b.matchid = t.matchid
					AND	b.BetType = t.BetType
			CROSS APPLY	(
				SELECT	'BetType'		= CASE	WHEN b.BetType = 1 AND SpecialType = 0
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
					,	b.tpositiontaking
					,	b.virtualrate
					,	b.scomm
					,	b.modds
					,	b.statusID
					,	b.transid
			OPTION (MAXDOP 2);
			
			SELECT	@RowCount	= @@ROWCOUNT
				,	@Duration	= DATEDIFF(millisecond, @Begin, GETDATE())
				;

			BEGIN;
				-- Force the output to appear immediately --
				RAISERROR('	Insert #tmpStagingTraderPerformance2 - %d rows - %d ms', 0, 0, @RowCount, @Duration) WITH NOWAIT;
			END;

			INSERT INTO #tmpDataGroup (CustId, EventDate, MatchId, BetType, BetTeam, ScoreHDP, MOdds, StatusID, AVGOdds, StakeMYBeforeComm, StakeMY, Stake)
			SELECT	'CustId'			= t.CustId
				,	'EventDate'			= t.EventDate
				,	'MatchId'			= t.MatchId
				,	'BetType'			= t.BetType
				,	'BetTeam'			= t.BetTeam
				,	'ScoreHDP'			= t.ScoreHDP
				,	'MOdds'				= t.MOdds
				,	'StatusID'			= t.StatusID
				,	'AVGOdds'			= SUM((CASE WHEN t.Odds < 0 THEN 1 ELSE t.Odds END * ABS(t.Stake) * (1 - t.TPositionTaking - t.ExtraPT) + (t.Scomm - CASE WHEN t.TPositionTaking = 1 THEN 0 ELSE t.Scomm * t.ExtraPT / (1 - t.TPositionTaking) END)) * t.VirtualRate)
										/ SUM((CASE WHEN t.Odds < 0 THEN -t.Odds ELSE 1 END * ABS(t.Stake) * (1 - t.TPositionTaking - t.ExtraPT) - (t.Scomm - CASE WHEN t.TPositionTaking = 1 THEN 0 ELSE t.Scomm * t.ExtraPT / (1 - t.TPositionTaking) END)) * t.VirtualRate)
										--TotalWin/TotalLose
				,	'StakeMYBeforeComm'	= SUM(t.StakeMY * (1 - t.TPositionTaking - t.ExtraPT) * t.VirtualRate)
				,	'StakeMY'			= SUM((t.StakeMY * (1 - t.TPositionTaking - t.ExtraPT) - (t.Scomm - CASE WHEN t.TPositionTaking = 1 THEN 0 ELSE t.Scomm * t.ExtraPT / (1 - t.TPositionTaking) END)) * t.VirtualRate)
				,	'Stake'				= SUM((CASE WHEN t.Odds < 0 THEN -t.Odds ELSE 1 END * ABS(t.Stake) * (1 - t.TPositionTaking - t.ExtraPT) - (t.Scomm - CASE WHEN t.TPositionTaking = 1 THEN 0 ELSE t.Scomm * t.ExtraPT / (1 - t.TPositionTaking) END)) * t.VirtualRate)
			FROM	#tmpStagingTraderPerformance2 AS t
			GROUP BY CustId, EventDate, MatchId, BetType, BetTeam, ScoreHDP, MOdds, StatusID;
			
			SELECT	@RowCount	= @@ROWCOUNT
				,	@Duration	= DATEDIFF(millisecond, @Begin, GETDATE())
				;

			BEGIN;
				-- Force the output to appear immediately --
				RAISERROR('	Insert ##tmpDataGroup - %d rows - %d ms', 0, 0, @RowCount, @Duration) WITH NOWAIT;
			END;

	
			-- Remove batched-data (bettrans & date) from source
			DELETE	d
			FROM	#winlostdate AS d
			WHERE	d.winlostdate = @WinLostDate;
						
			SELECT	@RowCount	= @@ROWCOUNT
				,	@Duration	= DATEDIFF(millisecond, @Begin, GETDATE())
				;

			BEGIN;
				-- Force the output to appear immediately --
				PRINT	@WinLostDate
				RAISERROR('DELETE #winlostdate - %d rows - %d ms', 0, 0, @RowCount, @Duration) WITH NOWAIT;
			END;

			TRUNCATE TABLE	#tmpStagingTraderPerformance2;

			TRUNCATE TABLE	#tmpFilteredBettransBKByBatch2;
		END;
	END;

	IF	OBJECT_ID('tempdb..#tmpJuice') IS NOT NULL
	BEGIN;
		DROP TABLE	#tmpJuice;
	END;

	CREATE TABLE	#tmpJuice (
						EventDate			DATE
					,	MatchId				INT
					,	BetType				SMALLINT
					,	StakeMYBeforeComm	MONEY
					,	StakeMY				MONEY
					,	Juice				MONEY
					,	StakeMYRJuice		MONEY
					,	StakeMYRTotal		MONEY
					,	ScoreHDP			SMALLMONEY
					);

	CREATE INDEX	#IDX_EventDate ON #tmpJuice (
						EventDate
					,	MatchId
					,	BetType
					);

	INSERT INTO #tmpJuice (EventDate, MatchId, BetType, ScoreHDP, StakeMYBeforeComm, StakeMY, Juice, StakeMYRJuice, StakeMYRTotal)
	SELECT	'EventDate'			= temp1.EventDate
		,	'MatchId'			= temp1.MatchId
		,	'BetType'			= temp1.BetType
		,	'ScoreHDP'			= temp1.ScoreHDP
		,	'StakeMYBeforeComm'	= SUM(temp1.StakeMYBeforeComm)
		,	'StakeMY'			= SUM(temp1.StakeMY)
		,	'Juice'				= SUM(ISNULL( CASE	WHEN temp1.BetTeam IN ('h')
														THEN  CASE WHEN temp2.Stake * (1 + ABS(temp2.AVGOdds)) / (1 + ABS(temp1.AVGOdds)) > temp1.Stake THEN temp1.Stake ELSE temp2.Stake * (1 + ABS(temp2.AVGOdds)) / (1 + ABS(temp1.AVGOdds)) END * CASE WHEN temp1.AVGOdds > 0 THEN 1 ELSE -temp1.AVGOdds END
															- CASE WHEN temp1.Stake * (1 + ABS(temp1.AVGOdds)) / (1 + ABS(temp2.AVGOdds)) > temp2.Stake THEN temp2.Stake ELSE temp1.Stake * (1 + ABS(temp1.AVGOdds)) / (1 + ABS(temp2.AVGOdds)) END * CASE WHEN temp2.AVGOdds > 0 THEN temp2.AVGOdds ELSE 1 END 
													ELSE 0 
											  END
											, 0
									  )
								  )
		,	'StakeMYRJuice'		= SUM(ISNULL( CASE	WHEN temp1.BetTeam IN ('h')
														THEN  CASE WHEN temp2.Stake * (1 + ABS(temp2.AVGOdds)) / (1 + ABS(temp1.AVGOdds)) > temp1.Stake THEN temp1.Stake ELSE temp2.Stake * (1 + ABS(temp2.AVGOdds)) / (1 + ABS(temp1.AVGOdds)) END * CASE WHEN ABS(temp1.AVGOdds) > 1 THEN ABS(temp1.AVGOdds) ELSE 1 END
															+ CASE WHEN temp1.Stake * (1 + ABS(temp1.AVGOdds)) / (1 + ABS(temp2.AVGOdds)) > temp2.Stake THEN temp2.Stake ELSE temp1.Stake * (1 + ABS(temp1.AVGOdds)) / (1 + ABS(temp2.AVGOdds)) END * CASE WHEN ABS(temp2.AVGOdds) > 1 THEN ABS(temp2.AVGOdds) ELSE 1 END
													ELSE 0
											  END
											, 0
									  )
								  )
		,	'StakeMYRTotal'		= SUM(ISNULL( CASE	WHEN temp1.BetTeam IN ('h')
														THEN  temp1.Stake * CASE WHEN ABS(temp1.AVGOdds) > 1 THEN ABS(temp1.AVGOdds) ELSE 1 END
															+ temp2.Stake * CASE WHEN ABS(temp2.AVGOdds) > 1 THEN ABS(temp2.AVGOdds) ELSE 1 END
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

	IF	OBJECT_ID('tempdb..#tmpSumTotal') IS NOT NULL
	BEGIN;
		DROP TABLE	#tmpSumTotal;
	END;

	CREATE TABLE	#tmpSumTotal (
						EventDate			DATE
					,	MatchId				INT
					,	BetType				SMALLINT
					,	StakeMYBeforeComm	MONEY
					,	Juice				MONEY
					,	StakeMYRJuice		MONEY
					);

	INSERT INTO	#tmpSumTotal (EventDate, MatchId, BetType, StakeMYBeforeComm, Juice, StakeMYRJuice)
	SELECT	'EventDate'			= t.EventDate
		,	'MatchId'			= t.MatchId
		,	'BetType'			= t.BetType
		,	'StakeMYBeforeComm'	= SUM(t.StakeMYBeforeComm)
		,	'Juice'				= SUM(t.Juice)
		,	'StakeMYRJuice'		= SUM(CASE WHEN t.StakeMYRTotal = 0 THEN 0 ELSE CAST(t.StakeMYBeforeComm AS DECIMAL(38,18)) * t.StakeMYRJuice / t.StakeMYRTotal END) -- Before comm
	FROM	#tmpJuice t
	GROUP BY t.MatchId, t.BetType, t.EventDate, t.ScoreHDP;

	IF	OBJECT_ID('tempdb..#tmpResults') IS NOT NULL
	BEGIN;
		DROP TABLE	#tmpResults;
	END;

	CREATE TABLE	#tmpResults (
						EventDate			DATE
					,	MatchId				INT
					,	BetType				SMALLINT
					,	StakeMYBeforeComm	MONEY
					,	Juice				MONEY
					,	StakeMYRJuice		MONEY
					);

	INSERT INTO #tmpResults (EventDate, MatchId, BetType, StakeMYBeforeComm, Juice, StakeMYRJuice)
	SELECT	'EventDate'			= t.EventDate
		,	'MatchId'			= t.MatchId
		,	'BetType'			= t.BetType
		,	'StakeMYBeforeComm'	= SUM(t.StakeMYBeforeComm)
		,	'Juice'				= SUM(t.Juice)
		,	'StakeMYRJuice'		= SUM(t.StakeMYRJuice)
	FROM	#tmpSumTotal t
	GROUP BY t.MatchId, t.BetType, t.EventDate;
	
	UPDATE	tp
	SET		tp.Juice = t.Juice
		,	tp.StakeMYR = t.StakeMYBeforeComm
		,	tp.StakeMYRJuice = t.StakeMYRJuice
	FROM		dbo.TraderPerformance AS tp WITH (ROWLOCK, UPDLOCK)
	INNER JOIN	#tmpResults AS t WITH (NOLOCK)
			ON	t.MatchId = tp.matchid
			AND	t.BetType = tp.bettype
	WHERE	tp.EventDate = t.EventDate;
	
	SELECT	@RowCount	= @@ROWCOUNT
		,	@Duration	= DATEDIFF(millisecond, @Begin, GETDATE())
		;

	BEGIN;
		-- Force the output to appear immediately --
		RAISERROR('UPDATE TraderPerformance - %d rows - %d ms', 0, 0, @RowCount, @Duration) WITH NOWAIT;
	END;
END;