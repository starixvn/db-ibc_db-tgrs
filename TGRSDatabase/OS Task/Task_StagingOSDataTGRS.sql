USE [bodb_TGRS]
GO
ALTER PROCEDURE	[dbo].[Task_StagingOSDataTGRS]
					@Debug				BIT = 0
				,	@BeforeMoveBetsDay	BIT = 1
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

	Param's Explanation:
		
	Exam:
	 
*/
BEGIN
	SET NOCOUNT ON;

	DECLARE	@Begin			DATETIME = GETDATE()
		,	@RowCount		INT
		;

	DECLARE	@BalanceUpDay	SMALLDATETIME
		,	@MoveBetsDay	SMALLDATETIME
		,	@Yesterday		SMALLDATETIME
		;

	SELECT	@BalanceUpDay	= MIN(winlostdate)
		,	@MoveBetsDay	= MAX(winlostdate)
		,	@Yesterday		= CONVERT(DATE, GETDATE() - 1)
	FROM	bodb02.dbo.bettrans14 WITH (NOLOCK);

	IF	@BeforeMoveBetsDay <> 1
		SELECT	@BalanceUpDay = @MoveBetsDay + 1;

	IF	@Debug = 1
		SELECT	'BalanceUpDay'	= @BalanceUpDay
			,	'MoveBetsDay'	= @MoveBetsDay
			,	'Yesterday'		= @Yesterday
			;

	IF	OBJECT_ID('tempdb..#tmpFilteredBettrans14') IS NOT NULL
		DROP TABLE	#tmpFilteredBettrans14;

	CREATE TABLE	#tmpFilteredBettrans14 (
						transid				BIGINT
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

	CREATE CLUSTERED INDEX	#CIX_tmpFilteredBettrans14Idx ON #tmpFilteredBettrans14 (
								winlostdate	ASC
							,	matchid		ASC
							,	bettype		ASC
							);

	IF	OBJECT_ID('tempdb..#tmpFilteredBettrans14ByBatch') IS NOT NULL
		DROP TABLE	#tmpFilteredBettrans14ByBatch;

	CREATE TABLE	#tmpFilteredBettrans14ByBatch (
						transid				BIGINT
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

	IF	OBJECT_ID('tempdb..#tmpStagingOSTraderPerformance') IS NOT NULL
		DROP TABLE	#tmpStagingOSTraderPerformance;

	CREATE TABLE	#tmpStagingOSTraderPerformance (
						CustId				INT
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

	IF	OBJECT_ID('tempdb..#tmpOSTrader') IS NOT NULL
		DROP TABLE	#tmpOSTrader;

	CREATE TABLE	#tmpOSTrader (
						CustId				INT
					,	matchid				INT
					,	SportType			INT
					,	EventDate			DATETIME
					,	BetType				SMALLINT
					,	OSTarget			DECIMAL(18, 2)
					);

	IF	OBJECT_ID('tempdb..#tmpBettrans14Date') IS NOT NULL
		DROP TABLE	#tmpBettrans14Date;

	CREATE TABLE	#tmpBettrans14Date (
						EventDate DATE
					);

	TRUNCATE TABLE	dbo.OSStagingDataTGRS;

	IF	@BeforeMoveBetsDay = 1
	BEGIN
		INSERT INTO	#tmpOSTrader (CustId, matchid, SportType, EventDate, BetType, OSTarget)
		SELECT	DISTINCT
				'CustId'	= a.OperatorID
			,	'matchid'	= m.matchid
			,	'SportType'	= m.sporttype
			,	'EventDate'	= m.EventDate
			,	'BetType'	= CASE	WHEN a.bettype = 5 AND a.operatortype = 1
										THEN 1
									ELSE ISNULL(b.MainDBBetType, 0) 
								END
			,	'OSTarget'	= dbo.f_GetOSTargetBySportLeagueBettype(m.sporttype, m.leagueid, a.bettype, m.eventdate)
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

		IF	@Debug = 1
			SELECT	'Step'		= 'Insert #[Dot_Admin_Assignment_Operator_bk]'
				,	'Duration'	= DATEDIFF(MILLISECOND, @Begin, GETDATE())
				;

		INSERT INTO #tmpFilteredBettrans14
			(	  transid,   matchid,   winlostdate,   bettype,   modds,   stake,   actual_stake,   virtualrate,   winlost,   awinlost,   mwinlost,   swinlost,   tpositiontaking,   srecommend,   scomm)
		SELECT	b.transid, b.matchid, b.winlostdate, b.bettype, b.modds, b.stake, b.actual_stake, b.virtualrate, b.winlost, b.awinlost, b.mwinlost, b.swinlost, b.tpositiontaking, b.srecommend, b.scomm
		FROM	bodb02.dbo.bettrans14 AS b WITH (NOLOCK)
		WHERE	b.winlostdate BETWEEN @BalanceUpDay AND @MoveBetsDay
			AND	b.statusID IN (112, 113)
			AND	b.Currency NOT IN (20, 27, 28)
			AND	b.LiveIndicator = 1
		;
	
		INSERT INTO	#tmpBettrans14Date (EventDate)
		SELECT	DISTINCT
				b.winlostdate
		FROM	#tmpFilteredBettrans14 AS b;

		DECLARE	@DateToDivideBatch	DATE = '';

		WHILE	(SELECT COUNT(1) FROM #tmpBettrans14Date) > 0
		BEGIN
			SELECT	TOP(1)
					@DateToDivideBatch = d.EventDate
			FROM	#tmpBettrans14Date AS d
			ORDER BY d.EventDate DESC;

			INSERT INTO #tmpFilteredBettrans14ByBatch 
				(	  transid,   matchid,   winlostdate,   bettype,   modds,   stake,   actual_stake,   virtualrate,   winlost,   awinlost,   mwinlost,   swinlost,   tpositiontaking,   srecommend,   scomm)
			SELECT	b.transid, b.matchid, b.winlostdate, b.bettype, b.modds, b.stake, b.actual_stake, b.virtualrate, b.winlost, b.awinlost, b.mwinlost, b.swinlost, b.tpositiontaking, b.srecommend, b.scomm
			FROM	#tmpFilteredBettrans14 AS b
			WHERE	b.winlostdate = @DateToDivideBatch;

			INSERT INTO #tmpStagingOSTraderPerformance (CustId, EventDate, MatchId, BetType, Stake, WinLost, SMAWinLost, Comm, ExtraPT, TPositionTaking, VirtualRate)
			SELECT	'CustId'			= t.CustId
				,	'EventDate'			= t.EventDate
				,	'MatchId'			= t.matchid
				,	'BetType'			= b.bettype
				,	'Stake'				= ((CASE WHEN b.modds = 0.25 OR b.modds = -0.25 THEN ABS(b.stake) / 2 ELSE ABS(b.stake) END) * b.virtualrate) --turn over
				,	'WinLost'			= (b.winlost - b.actual_stake)  --Winlost
				,	'SMAWinLost'		= (b.awinlost + b.mwinlost + b.swinlost)  --SMAWinlost
				,	'Comm'				= b.scomm  --Commission
				,	'ExtraPT'			= SUM(ISNULL(es.ExtraPT, 0))
				,	'TPositionTaking'	= b.tpositiontaking
				,	'VirtualRate'		= b.virtualrate
			FROM		#tmpFilteredBettrans14ByBatch AS b
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
			GROUP BY	t.CustId, t.EventDate, t.matchid, b.bettype
					,	((CASE WHEN b.modds = 0.25 OR b.modds = -0.25 THEN ABS(b.stake) / 2 ELSE ABS(b.stake) END) * b.virtualrate)
					,	(b.winlost - b.actual_stake), (b.awinlost + b.mwinlost + b.swinlost)
					,	b.scomm, b.tpositiontaking, b.virtualrate, b.transid
			OPTION (MAXDOP 2);

			INSERT INTO	dbo.OSStagingDataTGRS (TraderId, MatchId, MatchCode, EventDate, SportId, LeagueId, BettypeId, Turnover, WinLoss, Comm, BetCount, Target)
			SELECT	'TraderId'		= t.CustId
				,	'MatchId'		= m.MatchId
				,	'MatchCode'		= m.matchcode
				,	'EventDate'		= t.EventDate
				,	'SportId'		= t.SportType
				,	'LeagueId'		= m.LeagueId
				,	'BettypeId'		= b.BetType
				,	'Turnover'		= SUM(b.Stake * (1 - b.TPositionTaking - b.ExtraPT))
				,	'WinLoss'		= SUM(((-(b.WinLost + b.SMAWinLost)) + b.WinLost * b.ExtraPT) * b.VirtualRate)
				,	'Comm'			= SUM((b.Comm - (CASE WHEN b.TPositionTaking = 1 THEN 0 ELSE (b.Comm * b.ExtraPT / (1 - b.TPositionTaking)) END)) * b.VirtualRate)
				,	'BetCount'		= SUM(1)  --Live BetCount				
				,	'Target'		= t.OSTarget
			FROM		#tmpStagingOSTraderPerformance AS b WITH (NOLOCK)
			INNER JOIN	bodb02.dbo.match14 AS m WITH (NOLOCK)
					ON	b.MatchId = m.MatchId
			INNER JOIN	#tmpOSTrader AS t WITH (NOLOCK)
					ON	m.MatchId = t.matchid
					AND	t.CustId = b.CustId
					AND	b.BetType = t.BetType
			GROUP BY t.CustId, m.MatchId, m.matchcode, t.EventDate, t.SportType, m.LeagueId, b.BetType, t.OSTarget;

			-- Remove batched-data (bettrans & date) from source
			DELETE
			FROM	#tmpFilteredBettrans14
			WHERE	winlostdate = @DateToDivideBatch;

			DELETE
			FROM	#tmpBettrans14Date
			WHERE	EventDate = @DateToDivideBatch;

			TRUNCATE TABLE	#tmpStagingOSTraderPerformance;

			TRUNCATE TABLE	#tmpFilteredBettrans14ByBatch;
		END;

		IF	@Debug = 1
			SELECT	'Step'		= 'Insert #bettrans14'
				,	'Duration'	= DATEDIFF(MILLISECOND, @Begin, GETDATE())
				;
	END;

	TRUNCATE TABLE	#tmpOSTrader;

	TRUNCATE TABLE	#tmpStagingOSTraderPerformance;

	TRUNCATE TABLE	#tmpFilteredBettrans14;

	TRUNCATE TABLE	#tmpFilteredBettrans14ByBatch;

	INSERT INTO	#tmpOSTrader (CustId, matchid, SportType, EventDate, BetType, OSTarget)
	SELECT	DISTINCT
			'CustId'		= a.OperatorID
		,	'matchid'		= m.matchid
		,	'SportType'		= m.sporttype
		,	'EventDate'		= m.EventDate
		,	'BetType'		= CASE	WHEN a.bettype = 5 AND a.operatortype = 1
										THEN 1
									ELSE ISNULL(b.MainDBBetType, 0) 
								END
		,	'OSTarget'		= dbo.f_GetOSTargetBySportLeagueBettype(m.sporttype, m.leagueid, a.bettype, m.eventdate)
	FROM		bodb02.dbo.Dot_admin_Assignment_Operator AS a WITH (NOLOCK)
	INNER JOIN	bodb02.dbo.Match AS m WITH (NOLOCK)
			ON	a.matchid = m.matchid
	LEFT JOIN	dbo.OSBettype AS b WITH (NOLOCK)
			ON	a.bettype = b.AssignmentBetType
			AND	a.OperatorType = b.OperatorType
	WHERE	m.EventDate BETWEEN @MoveBetsDay + 1
		AND	@Yesterday
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

	IF	@Debug = 1
		SELECT	'Step'		= 'Insert #Dot_admin_Assignment_Operator' 
			,	'Duration'	= DATEDIFF(MILLISECOND, @Begin, GETDATE())
			;

	INSERT INTO	#tmpStagingOSTraderPerformance (CustId, EventDate, MatchId, BetType, Stake, WinLost, SMAWinLost, Comm, ExtraPT, TPositionTaking, VirtualRate)
	SELECT	'CustId'			= t.CustId
		,	'EventDate'			= t.EventDate
		,	'MatchId'			= t.matchid
		,	'BetType'			= b.BetType
		,	'Stake'				= ((CASE WHEN b.modds = 0.25 OR b.modds = -0.25 THEN ABS(b.stake) / 2 ELSE ABS(b.stake) END) * b.virtualrate)  --turn over
		,	'WinLost'			= (b.winlost - b.actual_stake)  --Winlost
		,	'SMAWinLost'		= (b.awinlost + b.mwinlost + b.swinlost)  --SMAWinlost
		,	'Comm'				= scomm  --Commission
		,	'ExtraPT'			= SUM(ISNULL(es.ExtraPT, 0))
		,	'TPositionTaking'	= b.tpositiontaking
		,	'VirtualRate'		= b.virtualrate
	FROM		bodb02.dbo.bettrans AS b WITH (NOLOCK)
	INNER JOIN	#tmpOSTrader AS t WITH (NOLOCK)
			ON	b.winlostdate = t.EventDate
			AND	b.matchid = t.matchid
			AND	b.BetType = t.BetType
	LEFT JOIN	bodb_ACC.dbo.Acc_GroupExtraPTSetting AS es WITH (NOLOCK)
			ON	es.SuperId = b.srecommend
			AND	es.ProductId = 1
			AND	es.SportType = 0
			AND	es.SubProduct = ''
			AND	t.EventDate BETWEEN es.FromDate
			AND	es.ToDate
	WHERE	b.statusID IN (112, 113)
		AND	b.ruben = 1
		AND	b.Currency NOT IN (20, 27, 28)
		AND	b.LiveIndicator = 1
	GROUP BY	t.CustId, t.EventDate, t.matchid, b.BetType
			,	((CASE WHEN b.modds = 0.25 OR b.modds = -0.25 THEN ABS(b.stake) / 2 ELSE ABS(b.stake) END) * b.virtualrate)
			,	(WinLost - actual_stake), (awinlost + mwinlost + swinlost)
			,	b.scomm, b.tpositiontaking, b.virtualrate, b.transid
	OPTION (MAXDOP 2);

	INSERT INTO dbo.OSStagingDataTGRS (TraderId, MatchId, MatchCode, EventDate, SportId, LeagueId, BettypeId, Turnover, WinLoss, Comm, BetCount, Target)
	SELECT	'TraderId'		= t.CustId
		,	'MatchId'		= m.MatchId
		,	'MatchCode'		= m.matchcode
		,	'EventDate'		= t.EventDate
		,	'SportId'		= t.SportType
		,	'LeagueId'		= m.LeagueId
		,	'BettypeId'		= b.BetType
		,	'Turnover'		= SUM(b.Stake * (1 - b.TPositionTaking - b.ExtraPT))
		,	'WinLoss'		= SUM(((-(b.WinLost + b.SMAWinLost)) + b.WinLost * b.ExtraPT) * b.VirtualRate)
		,	'Comm'			= SUM((b.Comm - (CASE WHEN b.TPositionTaking = 1 THEN 0 ELSE (b.Comm * b.ExtraPT / (1 - b.TPositionTaking)) END)) * b.VirtualRate)
		,	'BetCount'		= SUM(1) --Live BetCount	
		,	'Target'		= t.OSTarget
	FROM		#tmpStagingOSTraderPerformance AS b WITH (NOLOCK)
	INNER JOIN	bodb02.dbo.match AS m WITH (NOLOCK)
			ON	b.MatchId = m.MatchId
	INNER JOIN	#tmpOSTrader AS t
			ON	m.MatchId = t.matchid
			AND	t.CustId = b.CustId
			AND	b.BetType = t.BetType
	GROUP BY t.CustId, m.MatchId, m.matchcode, t.EventDate, t.SportType, m.LeagueId, b.BetType, t.OSTarget;

	IF	@Debug = 1
		SELECT	'Step'		= 'Insert #bettrans'
			,	'Duration'	= DATEDIFF(MILLISECOND, @Begin, GETDATE())
			;

	IF	OBJECT_ID('tempdb..#tmpOSTrader') IS NOT NULL
		DROP TABLE	#tmpOSTrader;
END;
GO