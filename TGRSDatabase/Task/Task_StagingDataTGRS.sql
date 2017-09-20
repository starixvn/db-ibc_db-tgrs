/*<info serverAlias="DBTGRS-bodb_TGRS" executers="bodbTGRSNet" viewers="" isFunction="0" isNested="0"></info>*/
USE [bodb_TGRS]
GO
ALTER PROCEDURE	[dbo].[Task_StagingDataTGRS]
						@Debug				BIT = 0
					,	@BeforeMoveBetsDay	BIT = 1
AS
/*
	Created:	20140603@Tom.Vo
	Task :		Staging Data on TGRS DB
	DB:			DBTGRS.bodb_TGRS
	Original:
  
	Revisions:
		- 20141203@Tom.Vo:	Staging data with new requirement
		- 20160307@Billy:	Add new field Spread for staging data - [Redmine: #53240]
		- 20160318@Aaron:	Bug fixes on generating (1 st) 1x2 data from bettrans 
		- 20160329@Sophia: 	Change datatype of Spread Column [Redmine: #54943]
		- 20160517@Percy:	Recalculate Spread for group bettype 1x2 [RedmineID: #56999]    
		- 20170209@Long:	Apply ExtraPT
		- 20170315@Long:	devide batch by date (not by 200k records as it is)		
		- 20170517@Long:	Add more bettypes from Dot_Assginment
		- 20170830@Long:	Add more bettypes from Dot_Assginment
		- 20170816@Percy:	Change data type of Sporttype [RedmineID: #73545]
		- 20170914@Billy:	Format code and tune performance for Task Staging - [Redmine: #81465]
		- 20170918@Billy:	Remove hedge match from bettrans data - [Redmine: #83470]
   		
	Param's Explanation:
		
	Exam:
	 
*/
BEGIN;
	SET NOCOUNT ON;

	DECLARE	@IdForUnassignedTrader	INT = 0
		;

	DECLARE	@Begin					DATETIME	= GETDATE()
		,	@RowCount				INT
		,	@Duration				INT
		;

	DECLARE @BalanceUpDay			SMALLDATETIME
		,	@MoveBetsDay			SMALLDATETIME
		,	@Yesterday				SMALLDATETIME
		;

	DECLARE	@winlostdate			DATETIME
		;
		
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
		,	@MoveBetsDay	= MAX(winlostdate)
		,	@Yesterday		= CONVERT(DATE, GETDATE() - 1)
	FROM	bodb02.dbo.bettrans14 WITH (NOLOCK);

	IF	@BeforeMoveBetsDay <> 1
	BEGIN;
		SELECT	@BalanceUpDay = @MoveBetsDay + 1;
	END;

	IF	@Debug = 1
	BEGIN;
		SELECT	'@BalanceUpDay'	= @BalanceUpDay
			,	'@MoveBetsDay'	= @MoveBetsDay
			,	'@Yesterday'	= @Yesterday
			;

		-- Force the output to appear immediately --
		RAISERROR('', 0, 0) WITH NOWAIT;
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
		
	TRUNCATE TABLE	dbo.Staging_TraderPerformance;

	IF	@BeforeMoveBetsDay = 1
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
		FROM		DB06.bodb_archive.dbo.Dot_Admin_Assignment_Operator_bk AS a WITH (NOLOCK)
		INNER JOIN	bodb02.dbo.Match14 AS m WITH (NOLOCK)
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
		WHERE	m.EventDate BETWEEN @BalanceUpDay AND @MoveBetsDay
			--AND	m.EventStatus='completed'
			AND	m.SportType = 1
			AND	a.OperatorType < 3
			AND	m.MatchCode NOT LIKE '%hedge%';
			
		SELECT	@RowCount	= @@ROWCOUNT
			,	@Duration	= DATEDIFF(millisecond, @Begin, GETDATE())
			;
			
		IF	@Debug = 1
		BEGIN;
			-- Force the output to appear immediately --
			RAISERROR('Insert #tmpTrader - %d rows - %d ms', 0, 0, @RowCount, @Duration) WITH NOWAIT;
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
				,	'ExtraPT'			= es.ExtraPT
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
			FROM		bodb02.dbo.bettrans14 AS b WITH (NOLOCK)
			INNER JOIN	bodb02.dbo.match14 AS m WITH (NOLOCK)
					ON	b.matchid = m.matchid
			LEFT JOIN	bodb_ACC.dbo.Acc_GroupExtraPTSetting AS es WITH (NOLOCK)
					ON	es.SuperId = b.srecommend
					AND	es.ProductId = 1
					AND	es.Sporttype = 0
					AND	es.SubProduct = ''
					AND	b.winlostdate BETWEEN es.FromDate AND es.ToDate
			LEFT JOIN	bodb02.dbo.MatchMaxbet14 AS mm WITH (NOLOCK)
					ON	mm.MatchId = b.matchid
					AND	(	mm.BetType = b.bettype
						OR	(b.bettype = 124 AND mm.BetType = 5)
						OR	(b.bettype = 125 AND mm.BetType = 15)
						)
			LEFT JOIN	#Spread1x2 AS s
					ON	mm.Spread = s.Margin
					AND	mm.BetType IN (5, 15)
			WHERE	b.winlostdate = @winlostdate
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
			WHERE	b.winlostdate = @winlostdate
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

			IF	@Debug = 1
			BEGIN;
				-- Force the output to appear immediately --
				RAISERROR('	Insert #tmpStagingTraderPerformance - %d rows - %d ms', 0, 0, @RowCount, @Duration) WITH NOWAIT;
			END;
			INSERT INTO	dbo.Staging_TraderPerformance (CustId, WorkShift, MatchId, MatchCode, EventDate, SportType, LeagueId, HomeId, AwayId, TeamId, Grade, BetType, Stake, WinLost, Comm, BetCount, Spread)
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

			IF	@Debug = 1
			BEGIN;
				-- Force the output to appear immediately --
				RAISERROR('	Insert #Staging_TraderPerformance - %d rows - %d ms', 0, 0, @RowCount, @Duration) WITH NOWAIT;
			END;
			
			DELETE	d
			FROM	#winlostdate AS d
			WHERE	d.winlostdate = @winlostdate;
				
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
		END
	END
	
	TRUNCATE TABLE #tmpTrader;
	TRUNCATE TABLE #tmpStagingTraderPerformance;
	
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
	FROM		bodb02.dbo.Dot_admin_Assignment_Operator AS a WITH (NOLOCK)
	INNER JOIN	bodb02.dbo.Match AS m WITH (NOLOCK)
			ON	a.matchid = m.matchid
	LEFT JOIN	bodb02.dbo.Team AS t WITH (NOLOCK)
			ON	m.homeid = t.teamid
	LEFT JOIN	bodb02.dbo.League AS l WITH (NOLOCK)
			ON	m.leagueid = l.leagueid
	LEFT JOIN	dbo.BetType AS b WITH(NOLOCK)
			ON	a.bettype = b.AssignmentBetType
			AND	a.OperatorType = b.OperatorType
	LEFT JOIN	dbo.TraderGrade_History AS td_G WITH (NOLOCK)
			ON	td_G.CustID = a.OperatorID
			AND	m.EventDate BETWEEN td_G.BeginDate AND ISNULL(td_G.EndDate, GETDATE() + 10)
	LEFT JOIN	dbo.TraderTeam_History AS td_T WITH (NOLOCK)
			ON	td_T.CustID = a.OperatorID
			AND	m.EventDate BETWEEN td_T.BeginDate AND ISNULL(td_T.EndDate, GETDATE() + 10)
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
		RAISERROR('Insert #tmpTrader - %d rows - %d ms', 0, 0, @RowCount, @Duration) WITH NOWAIT;
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

	WHILE	EXISTS (SELECT 1 FROM #winlostdate)
	BEGIN;
		SELECT	TOP(1)
				@WinLostDate = d.winlostdate
		FROM	#winlostdate AS d;
			
		TRUNCATE TABLE	#tmpFilteredBettransBKByBatch;
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
		FROM		bodb02.dbo.bettrans AS b WITH (NOLOCK)
		INNER JOIN	bodb02.dbo.match AS m WITH (NOLOCK)
				ON	b.matchid = m.matchid
		LEFT JOIN	bodb_ACC.dbo.Acc_GroupExtraPTSetting AS es WITH (NOLOCK)
				ON	es.SuperId = b.srecommend
				AND	es.ProductId = 1
				AND	es.Sporttype = 0
				AND	es.SubProduct = ''
				AND	b.winlostdate BETWEEN es.FromDate AND es.ToDate
		LEFT JOIN	bodb02.dbo.MatchMaxbet AS mm WITH (NOLOCK)
				ON	mm.MatchId = b.matchid
				AND	(	mm.BetType = b.bettype
					OR	(b.bettype = 124 AND mm.BetType = 5)
					OR	(b.bettype = 125 AND mm.BetType = 15)
					)
		LEFT JOIN	#Spread1x2 AS s
				ON	mm.Spread = s.Margin
				AND	mm.BetType IN (5, 15)
		WHERE	b.winlostdate = @winlostdate
			AND	b.statusID IN (112, 113)
			AND	b.Currency NOT IN (20, 27, 28)
			AND	b.LiveIndicator = 1
			AND	m.sporttype = 1
			AND	m.MatchCode NOT LIKE '%hedge%';
			
		SELECT	@RowCount	= @@ROWCOUNT
			,	@Duration	= DATEDIFF(millisecond, @Begin, GETDATE())
			;

		IF	@Debug = 1
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
		WHERE	b.winlostdate = @winlostdate
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

		IF	@Debug = 1
		BEGIN;
			-- Force the output to appear immediately --
			RAISERROR('	Insert #tmpStagingTraderPerformance - %d rows - %d ms', 0, 0, @RowCount, @Duration) WITH NOWAIT;
		END;

		INSERT INTO	dbo.Staging_TraderPerformance (CustId, WorkShift, MatchId, MatchCode, EventDate, SportType, LeagueId, HomeId, AwayId, TeamId, Grade, BetType, Stake, WinLost, Comm, BetCount, Spread)
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

		IF	@Debug = 1
		BEGIN;
			-- Force the output to appear immediately --
			RAISERROR('	Insert Staging_TraderPerformance - %d rows - %d ms', 0, 0, @RowCount, @Duration) WITH NOWAIT;
		END;
		
		DELETE	d
		FROM	#winlostdate AS d
		WHERE	d.winlostdate = @winlostdate;
				
		SELECT	@RowCount	= @@ROWCOUNT
			,	@Duration	= DATEDIFF(millisecond, @Begin, GETDATE())
			;

		IF	@Debug = 1
		BEGIN;
			-- Force the output to appear immediately --
			PRINT	@winlostdate;
			RAISERROR('DELETE #winlostdate - %d rows - %d ms', 0, 0, @RowCount, @Duration) WITH NOWAIT;
		END;

		TRUNCATE TABLE #tmpStagingTraderPerformance;
		TRUNCATE TABLE #tmpFilteredBettransBKByBatch;
	END;

	--IF	OBJECT_ID('tempdb..#tmpTrader') IS NOT NULL
	--BEGIN;
	--	DROP TABLE	#tmpTrader;
	--END;

	--IF	OBJECT_ID('tempdb..#tmpTraderPerformance') IS NOT NULL
	--BEGIN;
	--	DROP TABLE	#tmpTraderPerformance;
	--END;

	--CREATE TABLE	#tmpTraderPerformance (
	--					CustId			INT			NULL
	--				,	MatchId			INT			NULL
	--				,	WorkShift		TINYINT		NULL
	--				,	EventDate		DATE		NULL
	--				,	SportType		SMALLINT	NULL
	--				,	BetType			SMALLINT	NULL
	--				,	LeagueId		INT			NULL
	--				,	TeamId			SMALLINT	NULL
	--				,	Grade			TINYINT		NULL
	--				,	Stake			MONEY		NULL
	--				,	WinLost			MONEY		NULL
	--				,	Comm			MONEY		NULL
	--				,	BetCount		INT			NULL
	--				,	HomeId			INT			NULL
	--				,	AwayId			INT			NULL
	--				);

	--INSERT INTO #tmpTraderPerformance (CustId, EventDate, SportType, LeagueId, TeamId, Grade, BetType, WorkShift, MatchId, Stake, WinLost, Comm, BetCount)
	--SELECT	'CustId'		= CustId
	--	,	'EventDate'		= EventDate
	--	,	'SportType'		= SportType
	--	,	'LeagueId'		= LeagueId
	--	,	'TeamId'		= TeamId
	--	,	'Grade'			= Grade
	--	,	'BetType'		= BetType
	--	,	'WorkShift'		= WorkShift
	--	,	'MatchId'		= COUNT(MatchId)
	--	,	'Stake'			= FLOOR(SUM(Stake))
	--	,	'WinLost'		= FLOOR(SUM(WinLost))
	--	,	'Comm'			= FLOOR(SUM(Comm))
	--	,	'BetCount'		= FLOOR(SUM(BetCount))
	--FROM	dbo.TraderPerformance WITH (NOLOCK)
	--WHERE	EventDate BETWEEN @BalanceUpDay AND @Yesterday
	--GROUP BY CustId, EventDate, SportType, LeagueId, TeamId, Grade, BetType, WorkShift

	--SELECT	@RowCount = @@ROWCOUNT;

	--IF	@Debug = 1
	--BEGIN;
	--	SELECT	'Step'		= 'INSERT #TraderPerformance' 
	--		,	'Duration'	= DATEDIFF(millisecond, @Begin, GETDATE()) 
	--		,	'RowCount'	= @RowCount 
	--		;

	--	-- Force the output to appear immediately --
	--	RAISERROR('', 0, 0) WITH NOWAIT;
	--END;

	--IF	OBJECT_ID('tempdb..#tmpEventDate') IS NOT NULL
	--BEGIN;
	--	DROP TABLE	#tmpEventDate;
	--END;

	--CREATE TABLE	#tmpEventDate (
	--					EventDate	DATE
	--				);

	--INSERT INTO #tmpEventDate (EventDate)
	--SELECT	EventDate
	--FROM	(
	--	SELECT	'CustId'	= CustId
	--		,	'EventDate'	= EventDate
	--		,	'SportType'	= SportType
	--		,	'LeagueId'	= LeagueId
	--		,	'TeamId'	= TeamId
	--		,	'Grade'		= Grade
	--		,	'BetType'	= BetType
	--		,	'WorkShift'	= WorkShift
	--		,	'MatchId'	= COUNT(MatchId)
	--		,	'Stake'		= FLOOR(SUM(Stake))
	--		,	'WinLost'	= FLOOR(SUM(WinLost))
	--		,	'Comm'		= FLOOR(SUM(Comm))
	--		,	'BetCount'	= FLOOR(SUM(BetCount))
	--	FROM	dbo.Staging_TraderPerformance WITH (NOLOCK)
	--	GROUP BY CustId, EventDate, SportType, LeagueId, TeamId, Grade, BetType, WorkShift

	--	EXCEPT

	--	SELECT	'CustId'	= CustId
	--		,	'EventDate'	= EventDate
	--		,	'SportType'	= SportType
	--		,	'LeagueId'	= LeagueId
	--		,	'TeamId'	= TeamId
	--		,	'Grade'		= Grade
	--		,	'BetType'	= BetType
	--		,	'WorkShift'	= WorkShift
	--		,	'MatchId'	= MatchId
	--		,	'Stake'		= Stake
	--		,	'WinLost'	= WinLost
	--		,	'Comm'		= Comm
	--		,	'BetCount'	= BetCount
	--	FROM	#tmpTraderPerformance
	--) tmp
	--GROUP BY EventDate;

	--SELECT	@RowCount = @@ROWCOUNT;

	--IF	@Debug = 1
	--BEGIN;
	--	SELECT	'Step'		= 'INSERT EventDate FROM Staging_TraderPerformance EXCEPT #tmpTraderPerformance'
	--		,	'Duration'	= DATEDIFF(millisecond, @Begin, GETDATE()) 
	--		,	'RowCount'	= @RowCount
	--		;

	--	-- Force the output to appear immediately --
	--	RAISERROR('', 0, 0) WITH NOWAIT;
	--END;

	--INSERT INTO	#tmpEventDate (EventDate)
	--SELECT	EventDate
	--FROM	(
	--	SELECT	'CustId'	= CustId
	--		,	'EventDate'	= EventDate
	--		,	'SportType'	= SportType
	--		,	'LeagueId'	= LeagueId
	--		,	'TeamId'	= TeamId
	--		,	'Grade'		= Grade
	--		,	'BetType'	= BetType
	--		,	'WorkShift'	= WorkShift
	--		,	'MatchId'	= MatchId
	--		,	'Stake'		= Stake
	--		,	'WinLost'	= WinLost
	--		,	'Comm'		= Comm
	--		,	'BetCount'	= BetCount
	--	FROM	#tmpTraderPerformance
		
	--	EXCEPT
		
	--	SELECT CustId
	--		,EventDate
	--		,SportType
	--		,LeagueId
	--		,TeamId
	--		,Grade
	--		,BetType
	--		,WorkShift
	--		,COUNT(MatchId) MatchId
	--		,FLOOR(SUM(Stake)) Stake
	--		,FLOOR(SUM(WinLost)) WinLost
	--		,FLOOR(SUM(Comm)) Comm
	--		,FLOOR(SUM(BetCount)) BetCount
	--	FROM dbo.Staging_TraderPerformance WITH (NOLOCK)
	--	GROUP BY CustId
	--		,EventDate
	--		,SportType
	--		,LeagueId
	--		,TeamId
	--		,Grade
	--		,BetType
	--		,WorkShift
	--	) tmp
	--GROUP BY EventDate
	--EXCEPT
	--SELECT	EventDate
	--FROM	#tmpEventDate;

	--SELECT	@RowCount = @@ROWCOUNT
	
	--IF	@Debug = 1
	--BEGIN;
	--	SELECT	'Step'		= 'INSERT EventDate FROM #tmpTraderPerformance EXCEPT Staging_TraderPerformance'
	--		,	'Duration'	= DATEDIFF(millisecond, @Begin, GETDATE()) 
	--		,	'RowCount'	= @RowCount
	--		;

	--	-- Force the output to appear immediately --
	--	RAISERROR('', 0, 0) WITH NOWAIT;
	--END;

	--IF	OBJECT_ID('tempdb..#tmpTraderPerformance') IS NOT NULL
	--BEGIN;
	--	DROP TABLE	#tmpTraderPerformance;
	--END;

	--DELETE
	--FROM	dbo.Staging_TraderPerformance
	--WHERE	EventDate NOT IN (SELECT EventDate FROM #tmpEventDate WHERE EventDate IS NOT NULL)

	--SELECT	@RowCount = @@ROWCOUNT;

	--IF	@Debug = 1
	--BEGIN;
	--	SELECT	'Step'		= 'DELETE Staging_TraderPerformance'
	--		,	'Duration'	= DATEDIFF(millisecond, @Begin, GETDATE()) 
	--		,	'RowCount'	= @RowCount
	--		;

	--	SELECT	*
	--	FROM	#tmpEventDate

	--	-- Force the output to appear immediately --
	--	RAISERROR('', 0, 0) WITH NOWAIT;
	--END;

	--IF	OBJECT_ID('tempdb..#tmpEventDate') IS NOT NULL
	--BEGIN;
	--	DROP TABLE	#tmpEventDate;
	--END;
END;
GO