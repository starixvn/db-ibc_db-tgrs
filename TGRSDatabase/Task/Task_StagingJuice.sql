USE [bodb_TGRS]
GO
/****** Object:  StoredProcedure [dbo].[Task_StagingJuice]    Script Date: 1/2/2018 2:24:50 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE	[dbo].[Task_StagingJuice]
						@Debug				BIT = 0
					,	@BeforeMoveBetsDay	BIT = 1
AS
/*  
	Created:	20170214@Long
	Task :		Update Juice for Trader Performance
	DB:			DBTGRS.bodb_TGRS
	Original:
  
	Revisions:
   		- 20170315@Long:	apply ExtraPT and Calc for TO & WL's Leftover
		- 20170330@John:	Update TO & WL's Leftover
		- 20170315@Long:	devide batch by date (not by 200k records as it is)
		- 20170830@Long:	support UnassignedTrader
		- 20170914@Billy:	Format code and tune performance for Task Staging Juice - [Redmine: #81465]
		- 20170918@Billy:	Remove hedge match from bettrans data - [Redmine: #83470]		
		- 20180102@Long:	Change the way to get BU & MB days
   		
	Param's Explanation:
		
	Exam:
	 
*/
BEGIN;
	SET NOCOUNT ON;
	
	DECLARE	@IdForUnassignedTrader	INT		= 0
		;

	DECLARE	@BalanceUpDay			SMALLDATETIME
		,	@MoveBetsDay			SMALLDATETIME
		,	@Yesterday				SMALLDATETIME
		;

	DECLARE	@RowCount				INT
		,	@Begin					DATETIME		= GETDATE()
		,	@winlostdate			DATETIME
		,	@Duration				INT
		,	@Msg					NVARCHAR(MAX)
		;

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

	IF	@BeforeMoveBetsDay <> 1
	BEGIN;
		SELECT	@BalanceUpDay = @MoveBetsDay + 1;
	END;
	
	IF	@Debug = 1
	BEGIN;
		SELECT	@Msg = '
@BalanceUpDay = ' + CONVERT(NVARCHAR, @BalanceUpDay, 120) + N'
@MoveBetsDay  = ' + CONVERT(NVARCHAR, @MoveBetsDay, 120) + N'
@Yesterday    = ' + CONVERT(NVARCHAR, @Yesterday, 120);

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
					
	IF	OBJECT_ID('tempdb..#winlostdate') IS NOT NULL
	BEGIN;
		DROP TABLE	#winlostdate;
	END;

	CREATE TABLE	#winlostdate (
						winlostdate		DATETIME
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
					
	IF	@BeforeMoveBetsDay = 1
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
		FROM		DBARC.bodb_archive.dbo.Dot_Admin_Assignment_Operator_bk AS a WITH (NOLOCK)
		INNER JOIN	bodb02.dbo.Match14 AS m WITH (NOLOCK)
				ON	a.matchid = m.matchid
		LEFT JOIN	bodb02.dbo.Team AS t WITH (NOLOCK)
				ON	m.homeid = t.teamid
		LEFT JOIN	bodb02.dbo.League l WITH (NOLOCK)
				ON	m.leagueid = l.leagueid
		WHERE	m.EventDate BETWEEN @BalanceUpDay AND @MoveBetsDay
			AND	m.SportType = 1
			AND	a.OperatorType < 3
			AND	m.MatchCode NOT LIKE '%hedge%';
			
		SELECT	@RowCount	= @@ROWCOUNT
			,	@Duration	= DATEDIFF(millisecond, @Begin, GETDATE())
			;

		IF	@Debug = 1
		BEGIN;
			-- Force the output to appear immediately --
			RAISERROR('Insert #tmpTrader2 - %d rows - %d ms', 0, 0, @RowCount, @Duration) WITH NOWAIT;
		END;
		
		INSERT INTO	#winlostdate (winlostdate)
		SELECT	tally.winlostdate
		FROM	(
			SELECT	'NoDays' = DATEDIFF(DAY, @BalanceUpDay, @MoveBetsDay) + 1
		) cnt
		CROSS APPLY	(
			SELECT	TOP(cnt.NoDays)
					'winlostdate' = DATEADD(DAY, ROW_NUMBER() OVER(ORDER BY (SELECT NULL)) - 1, @BalanceUpDay)
			FROM		(VALUES (0), (0), (0), (0), (0), (0), (0), (0), (0), (0)) x10(n)
			CROSS APPLY	(VALUES (0), (0), (0), (0), (0), (0), (0), (0), (0), (0)) x100(n)
			CROSS APPLY	(VALUES (0), (0), (0), (0), (0), (0), (0), (0), (0), (0)) x1000(n)
		) tally;

		SELECT	@RowCount	= @@ROWCOUNT
			,	@Duration	= DATEDIFF(millisecond, @Begin, GETDATE())
			;

		IF	@Debug = 1
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
			FROM		bodb02.dbo.bettrans14 AS b WITH (NOLOCK)
			INNER JOIN	bodb02.dbo.Match14 AS m WITH (NOLOCK)
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

			IF	@Debug = 1
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

			IF	@Debug = 1
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

			IF	@Debug = 1
			BEGIN;
				-- Force the output to appear immediately --
				RAISERROR('	Insert ##tmpDataGroup - %d rows - %d ms', 0, 0, @RowCount, @Duration) WITH NOWAIT;
			END;

			DELETE	d
			FROM	#winlostdate AS d
			WHERE	d.winlostdate = @WinLostDate;
						
			SELECT	@RowCount	= @@ROWCOUNT
				,	@Duration	= DATEDIFF(millisecond, @Begin, GETDATE())
				;

			IF	@Debug = 1
			BEGIN;
				-- Force the output to appear immediately --
				PRINT	@WinLostDate
				RAISERROR('DELETE #winlostdate - %d rows - %d ms', 0, 0, @RowCount, @Duration) WITH NOWAIT;
			END;

			TRUNCATE TABLE	#tmpStagingTraderPerformance2;

			TRUNCATE TABLE	#tmpFilteredBettransBKByBatch2;
		END;
	END;

	TRUNCATE TABLE	#tmpTrader2;

	TRUNCATE TABLE	#tmpStagingTraderPerformance2;

	TRUNCATE TABLE	#tmpFilteredBettransBKByBatch2;
	
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
	FROM		bodb02.dbo.Dot_admin_Assignment_Operator AS a WITH (NOLOCK)
	INNER JOIN	bodb02.dbo.Match AS m WITH (NOLOCK)
			ON	a.matchid = m.matchid
	LEFT JOIN	bodb02.dbo.Team AS t WITH (NOLOCK)
			ON	m.homeid = t.teamid
	LEFT JOIN	bodb02.dbo.League AS l WITH (NOLOCK)
			ON	m.leagueid = l.leagueid
	WHERE	m.EventDate BETWEEN @MoveBetsDay + 1 AND @Yesterday
		AND	m.EventStatus = 'completed'
		AND	m.SportType = 1
		AND	a.OperatorType < 3
		AND	m.MatchCode NOT LIKE '%hedge%';
		
	SELECT	@RowCount	= @@ROWCOUNT
		,	@Duration	= DATEDIFF(millisecond, @Begin, GETDATE())
		;

	IF	@Debug = 1
	BEGIN;
		-- Force the output to appear immediately --
		RAISERROR('Insert #tmpTrader2 - %d rows - %d ms', 0, 0, @RowCount, @Duration) WITH NOWAIT;
	END;
		
	INSERT INTO	#winlostdate (winlostdate)
	SELECT	tally.winlostdate
	FROM	(
		SELECT	'NoDays' = DATEDIFF(DAY, @MoveBetsDay + 1, @Yesterday) + 1
	) cnt
	CROSS APPLY	(
		SELECT	TOP(cnt.NoDays)
				'winlostdate' = DATEADD(DAY, ROW_NUMBER() OVER(ORDER BY (SELECT NULL)) - 1, @MoveBetsDay + 1)
		FROM		(VALUES (0), (0), (0), (0), (0), (0), (0), (0), (0), (0)) x10(n)
		CROSS APPLY	(VALUES (0), (0), (0), (0), (0), (0), (0), (0), (0), (0)) x100(n)
		CROSS APPLY	(VALUES (0), (0), (0), (0), (0), (0), (0), (0), (0), (0)) x1000(n)
	) tally;

	SELECT	@RowCount	= @@ROWCOUNT
		,	@Duration	= DATEDIFF(millisecond, @Begin, GETDATE())
		;

	IF	@Debug = 1
	BEGIN;
		-- Force the output to appear immediately --
		RAISERROR('Insert #winlostdate - %d rows - %d ms', 0, 0, @RowCount, @Duration) WITH NOWAIT;
	END;

	-------
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
		FROM		bodb02.dbo.bettrans AS b WITH (NOLOCK)
		INNER JOIN	bodb02.dbo.Match AS m WITH (NOLOCK)
				ON	b.matchid = m.matchid
		LEFT JOIN	bodb_ACC.dbo.Acc_GroupExtraPTSetting AS es WITH (NOLOCK)
				ON	es.SuperId = b.srecommend
				AND	es.ProductId = 1
				AND	es.Sporttype = 0
				AND	es.SubProduct = ''
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

		IF	@Debug = 1
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

		IF	@Debug = 1
		BEGIN;
			-- Force the output to appear immediately --
			RAISERROR('	Insert ##tmpDataGroup - %d rows - %d ms', 0, 0, @RowCount, @Duration) WITH NOWAIT;
		END;
		
		DELETE	d
		FROM	#winlostdate AS d
		WHERE	d.winlostdate = @WinLostDate;
						
		SELECT	@RowCount	= @@ROWCOUNT
			,	@Duration	= DATEDIFF(millisecond, @Begin, GETDATE())
			;

		IF	@Debug = 1
		BEGIN;
			-- Force the output to appear immediately --
			PRINT	@WinLostDate
			RAISERROR('DELETE #winlostdate - %d rows - %d ms', 0, 0, @RowCount, @Duration) WITH NOWAIT;
		END;

		TRUNCATE TABLE	#tmpStagingTraderPerformance2;

		TRUNCATE TABLE	#tmpFilteredBettransBKByBatch2;
	END;

	IF	@Debug = 1
	BEGIN;
		SELECT	*
		FROM	#tmpDataGroup
		ORDER BY MatchId, BetType, ScoreHDP, BetTeam DESC;
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

	IF	@Debug = 1
	BEGIN;
		SELECT	*
		FROM	#tmpJuice
		ORDER BY matchid, bettype;
	END;

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

	IF	@Debug = 1
	BEGIN;
		-- Force the output to appear immediately --
		RAISERROR('UPDATE TraderPerformance - %d rows - %d ms', 0, 0, @RowCount, @Duration) WITH NOWAIT;
	END;
END;
