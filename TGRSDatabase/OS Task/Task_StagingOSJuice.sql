SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO
ALTER PROCEDURE	[dbo].[Task_StagingOSJuice]
		@Debug					BIT = 0
	,	@BeforeMoveBetsDay		BIT = 1	
	,	@GenerateFromDate		SMALLDATETIME = NULL
	,	@GenerateToDate			SMALLDATETIME = NULL
AS
/*  
	Created:	20170329@Long.Luu
	Task :		Staging Juice for Other Sports on TGRS DB
	DB:			DBTGRS.bodb_TGRS
	Original:
  
	Revisions:
		- 20170712@Billy:	Change from 200000 rows batch to 100 matchs batch - [Redmine: #79615]
		- 20190108@John:	Exclude Cashout tickets from Betcount figures in TGR reports [Redmine ID: 107602]
   		
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

	IF	OBJECT_ID('tempdb..#tmpOSDataGroup') IS NOT NULL
		DROP TABLE	#tmpOSDataGroup;

	CREATE TABLE	#tmpOSDataGroup (
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
					);

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
					,	betteam				VARCHAR(10)
					,	livehomescore		SMALLINT
					,	liveawayscore		SMALLINT
					,	odds				SMALLMONEY
					,	hdp1				SMALLMONEY
					,	hdp2				SMALLMONEY
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
					,	betteam				VARCHAR(10)
					,	livehomescore		SMALLINT
					,	liveawayscore		SMALLINT
					,	odds				SMALLMONEY
					,	hdp1				SMALLMONEY
					,	hdp2				SMALLMONEY
					);

	CREATE CLUSTERED INDEX	#CIX_tmpFilteredBettrans14ByBatchIdx ON #tmpFilteredBettrans14ByBatch (
								winlostdate	ASC
							,	matchid		ASC
							,	bettype		ASC
							);

	IF	OBJECT_ID('tempdb..#tmpStagingOSTraderPerformance') IS NOT NULL
		DROP TABLE	#tmpStagingOSTraderPerformance;

	CREATE TABLE	#tmpStagingOSTraderPerformance (
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

	IF	OBJECT_ID('tempdb..#tmpOSTrader') IS NOT NULL
		DROP TABLE	#tmpOSTrader;

	CREATE TABLE	#tmpOSTrader (
						CustId				INT
					,	matchid				INT
					,	SportType			INT
					,	EventDate			DATETIME
					,	BetType				SMALLINT
					);

	IF	OBJECT_ID('tempdb..#tmpOSJuice') IS NOT NULL
		DROP TABLE	#tmpOSJuice;

	CREATE TABLE	#tmpOSJuice (
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

	CREATE CLUSTERED INDEX	#IDX_EventDate ON #tmpOSJuice (
								EventDate	ASC
							,	MatchId		ASC
							,	BetType		ASC
							);

	IF	@BeforeMoveBetsDay = 1
	BEGIN
		INSERT INTO	#tmpOSTrader (CustId, matchid, SportType, EventDate, BetType)
		SELECT	DISTINCT
				'CustId'	= a.OperatorID
			,	'matchid'	= m.matchid
			,	'SportType'	= m.sporttype
			,	'EventDate'	= m.eventdate
			,	'BetType'	= CASE	WHEN (a.bettype = 1 OR a.bettype = 5) AND a.OperatorType = 1 THEN 1
									WHEN (a.bettype = 1 AND a.OperatorType = 2) THEN 7
									WHEN (a.bettype = 2 AND a.OperatorType = 1) THEN 3
									WHEN (a.bettype = 2 AND a.OperatorType = 2) THEN 8
									WHEN (a.bettype = 3 AND a.OperatorType = 1) THEN 5
									WHEN (a.bettype = 3 AND a.OperatorType = 2) THEN 15
									WHEN (a.bettype = 4 AND a.OperatorType = 1) THEN 2
									WHEN (a.bettype = 4 AND a.OperatorType = 2) THEN 12
									ELSE 0
							  END
		FROM		bodb_Archive.dbo.Dot_Admin_Assignment_Operator_bk AS a WITH (NOLOCK)
		INNER JOIN	bodb02.dbo.match14 AS m WITH (NOLOCK)
				ON	a.matchid = m.matchid
		WHERE	m.eventdate BETWEEN @BalanceUpDay
			AND	@MoveBetsDay
			AND	a.OperatorType < 3
			AND	m.matchcode NOT LIKE '%hedge%'
			AND	m.sporttype <> 1
		;

		IF	@Debug = 1
			SELECT	'Step'		= 'Insert #[Dot_Admin_Assignment_Operator_bk]'
				,	'Duration'	= DATEDIFF(MILLISECOND, @Begin, GETDATE())
				;

		INSERT INTO #tmpFilteredBettrans14
			(	  transid,   matchid,   winlostdate,   bettype,   modds,   stake,   actual_stake,   virtualrate,   winlost,   awinlost,   mwinlost,   swinlost,   tpositiontaking,   srecommend,   scomm,   betteam,   livehomescore,   liveawayscore,   odds,   hdp1,   hdp2)
		SELECT	b.transid, b.matchid, b.winlostdate, b.bettype, b.modds, b.stake, b.actual_stake, b.virtualrate, b.winlost, b.awinlost, b.mwinlost, b.swinlost, b.tpositiontaking, b.srecommend, b.scomm, b.betteam, b.livehomescore, b.liveawayscore, b.odds, b.hdp1, b.hdp2
		FROM	bodb02.dbo.bettrans14 AS b WITH (NOLOCK)
		WHERE	b.winlostdate BETWEEN @BalanceUpDay AND @MoveBetsDay
			AND	b.statusID IN (112, 113)
			AND	b.currency NOT IN (20, 27, 28)
			AND	b.liveindicator = 1
			AND	b.bettype IN (1, 3, 7, 8, 2, 12)
		;

		IF	OBJECT_ID('tempdb..#match') IS NOT NULL
			DROP TABLE	#match;

		CREATE TABLE	#match (
							matchid		INT
						);

		WHILE	(SELECT COUNT(1) FROM #tmpFilteredBettrans14) > 0
		BEGIN
			TRUNCATE TABLE	#match;

			INSERT INTO	#match (matchid)
			SELECT	TOP(100)
					b.matchid
			FROM	#tmpFilteredBettrans14 AS b
			GROUP BY b.matchid;

			INSERT INTO	#tmpFilteredBettrans14ByBatch
				(	  transid,   matchid,   winlostdate,   bettype,   modds,   stake,   actual_stake,   virtualrate,   winlost,   awinlost,   mwinlost,   swinlost,   tpositiontaking,   srecommend,   scomm,   betteam,   livehomescore,   liveawayscore,   odds,   hdp1,   hdp2)
			SELECT	b.transid, b.matchid, b.winlostdate, b.bettype, b.modds, b.stake, b.actual_stake, b.virtualrate, b.winlost, b.awinlost, b.mwinlost, b.swinlost, b.tpositiontaking, b.srecommend, b.scomm, b.betteam, b.livehomescore, b.liveawayscore, b.odds, b.hdp1, b.hdp2
			FROM		#tmpFilteredBettrans14 AS b
			INNER JOIN	#match AS m
					ON	m.matchid = b.matchid;

			-- Remove batched-data from source
			DELETE	b
			FROM		#tmpFilteredBettrans14 AS b
			INNER JOIN	#match AS m
					ON	m.matchid = b.matchid;

			INSERT INTO	#tmpStagingOSTraderPerformance
				(	CustId, EventDate, MatchId, BetType, BetTeam, ScoreHDP, Odds, StakeMY, Stake, ExtraPT, TPositionTaking, VirtualRate, Scomm, MOdds)
			SELECT	'CustId'			= t.CustId
				,	'EventDate'			= t.EventDate
				,	'MatchId'			= t.matchid
				,	'BetType'			= b.bettype
				,	'BetTeam'			= b.betteam
				,	'ScoreHDP'			= (CASE WHEN b.bettype IN (1, 7) THEN (b.hdp1 + b.livehomescore) - (b.hdp2 + b.liveawayscore) ELSE b.hdp1 END)
				,	'Odds'				= b.odds
				,	'StakeMY'			= (CASE WHEN ABS(b.odds) <= 1 THEN 1 ELSE ABS(b.odds) END * (CASE WHEN ABS(b.modds) = 0.25 THEN 0.5 ELSE 1 END) * ABS(b.stake)) -- stakemy
				,	'Stake'				= ((CASE WHEN ABS(b.modds) = 0.25 THEN 0.5 ELSE 1 END) * ABS(b.stake)) -- stake
				,	'ExtraPT'			= SUM(ISNULL(es.ExtraPT, 0))
				,	'TPositionTaking'	= b.tpositiontaking
				,	'VirtualRate'		= b.virtualrate
				,	'Scomm'				= b.scomm
				,	'MOdds'				= b.modds
			FROM		#tmpFilteredBettrans14ByBatch AS b
			INNER JOIN	#tmpOSTrader AS t WITH (NOLOCK)
					ON	b.winlostdate = t.EventDate
					AND	b.matchid = t.matchid
					AND	b.bettype = t.BetType
			LEFT JOIN	bodb_ACC.dbo.Acc_GroupExtraPTSetting AS es WITH (NOLOCK)
					ON	es.SuperId = b.srecommend
					AND	es.ProductId = 1
					AND	es.Sporttype = 0
					AND	es.SubProduct = ''
					AND	t.EventDate BETWEEN es.FromDate
					AND	es.ToDate
			GROUP BY	t.CustId, t.EventDate, t.matchid, b.bettype, b.betteam
					,	(CASE WHEN b.bettype IN (1, 7) THEN (b.hdp1 + b.livehomescore) - (b.hdp2 + b.liveawayscore) ELSE b.hdp1 END)
					,	b.odds
					,	(CASE WHEN ABS(b.odds) <= 1 THEN 1 ELSE ABS(b.odds) END * (CASE WHEN ABS(b.modds) = 0.25 THEN 0.5 ELSE 1 END) * ABS(b.stake)) -- stakemy
					,	((CASE WHEN ABS(b.modds) = 0.25 THEN 0.5 ELSE 1 END) * ABS(b.stake)) -- stake
					,	b.tpositiontaking, b.virtualrate, b.scomm, b.modds, b.transid
			OPTION (MAXDOP 2);

			INSERT INTO	#tmpOSDataGroup
				(	CustId, EventDate, MatchId, BetType, BetTeam, ScoreHDP, MOdds, AVGOdds, StakeMYBeforeComm, StakeMY, Stake)
			SELECT	'CustId'			= t.CustId
				,	'EventDate'			= t.EventDate
				,	'MatchId'			= t.MatchId
				,	'BetType'			= t.BetType
				,	'BetTeam'			= t.BetTeam
				,	'ScoreHDP'			= t.ScoreHDP
				,	'MOdds'				= t.MOdds
				,	'AVGOdds'			= SUM((CASE WHEN t.Odds < 0 THEN 1 ELSE t.Odds END * t.Stake * (1 - t.TPositionTaking - t.ExtraPT) + (t.Scomm - (CASE WHEN t.TPositionTaking = 1 THEN 0 ELSE (t.Scomm * t.ExtraPT / (1 - t.TPositionTaking)) END))) * t.VirtualRate)
										/ SUM((CASE WHEN t.Odds < 0 THEN -t.Odds ELSE 1 END * t.Stake * (1 - t.TPositionTaking - t.ExtraPT) - (t.Scomm - (CASE WHEN t.TPositionTaking = 1 THEN 0 ELSE (t.Scomm * t.ExtraPT / (1 - t.TPositionTaking)) END))) * t.VirtualRate)
				,	'StakeMYBeforeComm'	= SUM(t.StakeMY * (1 - t.TPositionTaking - t.ExtraPT) * t.VirtualRate)
				,	'StakeMY'			= SUM((t.StakeMY * (1 - t.TPositionTaking - t.ExtraPT) - (t.Scomm - (CASE WHEN t.TPositionTaking = 1 THEN 0 ELSE (t.Scomm * t.ExtraPT / (1 - t.TPositionTaking)) END))) * t.VirtualRate)
				,	'Stake'				= SUM((CASE WHEN t.Odds < 0 THEN -t.Odds ELSE 1 END * t.Stake * (1 - t.TPositionTaking - t.ExtraPT) - (t.Scomm - (CASE WHEN t.TPositionTaking = 1 THEN 0 ELSE (t.Scomm * t.ExtraPT / (1 - t.TPositionTaking)) END))) * t.VirtualRate)
			FROM	#tmpStagingOSTraderPerformance AS t
			GROUP BY t.CustId, t.EventDate, t.MatchId, t.BetType, t.BetTeam, t.ScoreHDP, t.MOdds;

			TRUNCATE TABLE	#tmpStagingOSTraderPerformance;

			TRUNCATE TABLE	#tmpFilteredBettrans14ByBatch;
		END;

		IF	@Debug = 1
			SELECT	'Step'		= 'Insert #bettrans14'
				,	'Duration'	= DATEDIFF(MILLISECOND, @Begin, GETDATE());
	END;

	TRUNCATE TABLE	#tmpOSTrader;

	TRUNCATE TABLE	#tmpStagingOSTraderPerformance;

	TRUNCATE TABLE	#tmpFilteredBettrans14;

	TRUNCATE TABLE	#tmpFilteredBettrans14ByBatch;

	INSERT INTO	#tmpOSTrader
		(	CustId, matchid, SportType, EventDate, BetType)
	SELECT	DISTINCT
			'CustId'			= a.OperatorID
		,	'matchid'			= m.matchid
		,	'SportType'			= m.sporttype
		,	'EventDate'			= m.eventdate
		,	'BetType'			= CASE	WHEN (a.bettype = 1 OR a.bettype = 5) AND a.OperatorType = 1 THEN 1
										WHEN (a.bettype = 1 AND a.OperatorType = 2) THEN 7
										WHEN (a.bettype = 2 AND a.OperatorType = 1) THEN 3
										WHEN (a.bettype = 2 AND a.OperatorType = 2) THEN 8
										WHEN (a.bettype = 3 AND a.OperatorType = 1) THEN 5
										WHEN (a.bettype = 3 AND a.OperatorType = 2) THEN 15
										WHEN (a.bettype = 4 AND a.OperatorType = 1) THEN 2
										WHEN (a.bettype = 4 AND a.OperatorType = 2) THEN 12
										ELSE 0
								  END
	FROM		bodb02.dbo.Dot_Admin_Assignment_Operator AS a WITH (NOLOCK)
	INNER JOIN	bodb02.dbo.match AS m WITH (NOLOCK)
			ON	a.matchid = m.matchid
	WHERE	m.eventdate BETWEEN @MoveBetsDay + 1
		AND	@Yesterday
		AND	m.eventstatus = 'completed'
		AND	a.OperatorType < 3
		AND	m.matchcode NOT LIKE '%hedge%'
		AND	m.sporttype <> 1;

	IF	@Debug = 1
		SELECT	'Step'		= 'Insert #Dot_admin_Assignment_Operator'
			,	'Duration'	= DATEDIFF(MILLISECOND, @Begin, GETDATE());

	INSERT INTO #tmpStagingOSTraderPerformance
		(	CustId, EventDate, MatchId, BetType, BetTeam, ScoreHDP, Odds, StakeMY, Stake, ExtraPT, TPositionTaking, VirtualRate, Scomm, MOdds)
	SELECT	'CustId'			= t.CustId
		,	'EventDate'			= t.EventDate
		,	'MatchId'			= t.matchid
		,	'BetType'			= b.bettype
		,	'BetTeam'			= b.betteam
		,	'ScoreHDP'			= (CASE WHEN b.bettype IN (1, 7) THEN (b.hdp1 + b.livehomescore) - (b.hdp2 + b.liveawayscore) ELSE b.hdp1 END)
		,	'Odds'				= b.odds
		,	'StakeMY'			= (CASE WHEN ABS(b.odds) <= 1 THEN 1 ELSE ABS(b.odds) END * (CASE WHEN ABS(b.modds) = 0.25 THEN 0.5 ELSE 1 END) * b.stake) -- stakemy
		,	'Stake'				= ((CASE WHEN ABS(b.modds) = 0.25 THEN 0.5 ELSE 1 END) * b.stake) -- stake
		,	'ExtraPT'			= SUM(ISNULL(es.ExtraPT, 0))
		,	'TPositionTaking'	= b.tpositiontaking
		,	'VirtualRate'		= b.virtualrate
		,	'Scomm'				= b.scomm
		,	'MOdds'				= b.modds
	FROM		bodb02.dbo.bettrans AS b WITH (NOLOCK)
	INNER JOIN	#tmpOSTrader AS t WITH (NOLOCK)
			ON	b.winlostdate = t.EventDate
			AND	b.matchid = t.matchid
			AND	b.bettype = t.BetType
	LEFT JOIN	bodb_ACC.dbo.Acc_GroupExtraPTSetting AS es WITH (NOLOCK)
			ON	es.SuperId = b.srecommend
			AND	es.ProductId = 1
			AND	es.Sporttype = 0
			AND	es.SubProduct = ''
			AND	t.EventDate BETWEEN es.FromDate
			AND	es.ToDate
	WHERE	t.EventDate BETWEEN @MoveBetsDay + 1 AND @Yesterday
		AND	b.statusID IN (112, 113)
		AND	b.currency NOT IN (20, 27, 28)
		AND	b.liveindicator = 1
		AND	b.bettype IN (1, 3, 7, 8, 2, 12)
	GROUP BY	t.CustId, t.EventDate, t.matchid, b.bettype, b.betteam
			,	(CASE WHEN b.bettype IN (1, 7) THEN (b.hdp1 + b.livehomescore) - (b.hdp2 + b.liveawayscore) ELSE b.hdp1 END)
			,	b.odds
			,	(CASE WHEN ABS(b.odds) <= 1 THEN 1 ELSE ABS(b.odds) END * (CASE WHEN ABS(b.modds) = 0.25 THEN 0.5 ELSE 1 END) * b.stake) -- stakemy
			,	((CASE WHEN ABS(b.modds) = 0.25 THEN 0.5 ELSE 1 END) * b.stake) -- stake
			,	b.tpositiontaking, b.virtualrate, b.scomm, b.modds, b.transid
	OPTION (MAXDOP 2);

	INSERT INTO #tmpOSDataGroup
		(	CustId, EventDate, MatchId, BetType, BetTeam, ScoreHDP, MOdds, AVGOdds, StakeMYBeforeComm, StakeMY, Stake)
	SELECT	'CustId'			= t.CustId
		,	'EventDate'			= t.EventDate
		,	'MatchId'			= t.MatchId
		,	'BetType'			= t.BetType
		,	'BetTeam'			= t.BetTeam
		,	'ScoreHDP'			= t.ScoreHDP
		,	'MOdds'				= t.MOdds
		,	'AVGOdds'			= SUM((CASE WHEN t.Odds < 0 THEN 1 ELSE t.Odds END * t.Stake * (1 - t.TPositionTaking - t.ExtraPT) + (t.Scomm - (CASE WHEN t.TPositionTaking = 1 THEN 0 ELSE (t.Scomm * t.ExtraPT / (1 - t.TPositionTaking)) END))) * t.VirtualRate)
								/ SUM((CASE WHEN t.Odds < 0 THEN -t.Odds ELSE 1 END * t.Stake * (1 - t.TPositionTaking - t.ExtraPT) - (t.Scomm - (CASE WHEN t.TPositionTaking = 1 THEN 0 ELSE (t.Scomm * t.ExtraPT / (1 - t.TPositionTaking)) END))) * t.VirtualRate)
		,	'StakeMYBeforeComm'	= SUM(t.StakeMY * (1 - t.TPositionTaking - t.ExtraPT) * t.VirtualRate)
		,	'StakeMY'			= SUM((t.StakeMY * (1 - t.TPositionTaking - t.ExtraPT) - (t.Scomm - (CASE WHEN t.TPositionTaking = 1 THEN 0 ELSE (t.Scomm * t.ExtraPT / (1 - t.TPositionTaking)) END))) * t.VirtualRate)
		,	'Stake'				= SUM((CASE WHEN t.Odds < 0 THEN -t.Odds ELSE 1 END * t.Stake * (1 - t.TPositionTaking - t.ExtraPT) - (t.Scomm - (CASE WHEN t.TPositionTaking = 1 THEN 0 ELSE (t.Scomm * t.ExtraPT / (1 - t.TPositionTaking)) END))) * t.VirtualRate)
	FROM	#tmpStagingOSTraderPerformance AS t
	GROUP BY t.CustId, t.EventDate, t.MatchId, t.BetType, t.BetTeam, t.ScoreHDP, t.MOdds;

	IF	@Debug = 1
		SELECT	'Step'		= 'Insert #bettrans'
			,	'Duration'	= DATEDIFF(MILLISECOND, @Begin, GETDATE())
			;

	IF	OBJECT_ID('tempdb..#tmpOSTrader') IS NOT NULL
		DROP TABLE	#tmpOSTrader;

	INSERT INTO	#tmpOSJuice
		(	EventDate, MatchId, BetType, ScoreHDP, StakeMYBeforeComm, StakeMY, Juice, StakeMYRJuice, StakeMYRTotal)
	SELECT	'EventDate'			= temp1.EventDate
		,	'MatchId'			= temp1.MatchId
		,	'BetType'			= temp1.BetType
		,	'ScoreHDP'			= temp1.ScoreHDP
		,	'StakeMYBeforeComm'	= SUM(temp1.StakeMYBeforeComm)
		,	'StakeMY'			= SUM(temp1.StakeMY)
		,	'Juice'				= SUM(ISNULL(CASE	WHEN temp1.BetTeam IN ('h')
														THEN	CASE WHEN temp2.Stake * (1 + ABS(temp2.AVGOdds)) / (1 + ABS(temp1.AVGOdds)) > temp1.Stake THEN temp1.Stake ELSE temp2.Stake * (1 + ABS(temp2.AVGOdds)) / (1 + ABS(temp1.AVGOdds)) END * CASE WHEN temp1.AVGOdds > 0 THEN 1 ELSE -temp1.AVGOdds END
															-	CASE WHEN temp1.Stake * (1 + ABS(temp1.AVGOdds)) / (1 + ABS(temp2.AVGOdds)) > temp2.Stake THEN temp2.Stake ELSE temp1.Stake * (1 + ABS(temp1.AVGOdds)) / (1 + ABS(temp2.AVGOdds)) END * CASE WHEN temp2.AVGOdds > 0 THEN temp2.AVGOdds ELSE 1 END
													ELSE 0
											 END, 0))
		,	'StakeMYRJuice'		= SUM(ISNULL(CASE	WHEN temp1.BetTeam IN ('h') 
														THEN	CASE WHEN temp2.Stake * (1 + ABS(temp2.AVGOdds)) / (1 + ABS(temp1.AVGOdds)) > temp1.Stake THEN temp1.Stake ELSE temp2.Stake * (1 + ABS(temp2.AVGOdds)) / (1 + ABS(temp1.AVGOdds)) END * CASE WHEN ABS(temp1.AVGOdds) > 1 THEN ABS(temp1.AVGOdds) ELSE 1 END
															+	CASE WHEN temp1.Stake * (1 + ABS(temp1.AVGOdds)) / (1 + ABS(temp2.AVGOdds)) > temp2.Stake THEN temp2.Stake ELSE temp1.Stake * (1 + ABS(temp1.AVGOdds)) / (1 + ABS(temp2.AVGOdds)) END * CASE WHEN ABS(temp2.AVGOdds) > 1 THEN ABS(temp2.AVGOdds) ELSE 1 END

													ELSE 0
											 END, 0))
		,	'StakeMYRTotal'		= SUM(ISNULL((CASE	WHEN temp1.BetTeam IN ('h')
														THEN	temp1.Stake * CASE WHEN ABS(temp1.AVGOdds) > 1 THEN ABS(temp1.AVGOdds) ELSE 1 END
															+	temp2.Stake * CASE WHEN ABS(temp2.AVGOdds) > 1 THEN ABS(temp2.AVGOdds) ELSE 1 END
														ELSE 0
											 END), 0))
	FROM		#tmpOSDataGroup AS temp1 WITH (NOLOCK)
	LEFT JOIN	#tmpOSDataGroup AS temp2
			ON	temp1.MatchId = temp2.MatchId
			AND	temp1.BetType = temp2.BetType
			AND	temp1.ScoreHDP = temp2.ScoreHDP
			AND	temp1.BetTeam <> temp2.BetTeam
	GROUP BY temp1.MatchId, temp1.BetType, temp1.EventDate, temp1.ScoreHDP;

	IF	@Debug = 1
		SELECT	*
		FROM	#tmpOSJuice
		ORDER BY MatchId, BetType;

	IF	OBJECT_ID('tempdb..#tmpSumTotal') IS NOT NULL
		DROP TABLE	#tmpSumTotal;

	CREATE TABLE	#tmpSumTotal (
						EventDate			DATE
					,	MatchId				INT
					,	BetType				SMALLINT
					,	StakeMYBeforeComm	MONEY
					,	Juice				MONEY
					,	StakeMYRJuice		MONEY
					);

	INSERT INTO	#tmpSumTotal
		(	EventDate, MatchId, BetType, StakeMYBeforeComm, Juice, StakeMYRJuice)
	SELECT	'EventDate'			= t.EventDate
		,	'MatchId'			= t.MatchId
		,	'BetType'			= t.BetType
		,	'StakeMYBeforeComm'	= SUM(t.StakeMYBeforeComm)
		,	'Juice'				= SUM(t.Juice)
		,	'StakeMYRJuice'		= SUM(CASE WHEN t.StakeMYRTotal = 0 THEN 0 ELSE t.StakeMYBeforeComm * t.StakeMYRJuice / t.StakeMYRTotal END) -- Before comm
	FROM	#tmpOSJuice AS t
	GROUP BY t.MatchId, t.BetType, t.EventDate, t.ScoreHDP;

	IF	OBJECT_ID('tempdb..#tmpResults') IS NOT NULL
		DROP TABLE	#tmpResults;

	CREATE TABLE	#tmpResults (
						EventDate			DATE
					,	MatchId				INT
					,	BetType				SMALLINT
					,	StakeMYBeforeComm	MONEY
					,	Juice				MONEY
					,	StakeMYRJuice		MONEY
					);

	INSERT INTO	#tmpResults
		(	EventDate, MatchId, BetType, StakeMYBeforeComm, Juice, StakeMYRJuice)
	SELECT	'EventDate'			= t.EventDate
		,	'MatchId'			= t.MatchId
		,	'BetType'			= t.BetType
		,	'StakeMYBeforeComm'	= SUM(t.StakeMYBeforeComm)
		,	'Juice'				= SUM(t.Juice)
		,	'StakeMYRJuice'		= SUM(t.StakeMYRJuice)
	FROM	#tmpSumTotal AS t
	GROUP BY t.MatchId, t.BetType, t.EventDate;

	UPDATE	tp
	SET		tp.Juice = t.Juice
		,	tp.StakeMYR = t.StakeMYBeforeComm
		,	tp.StakeMYRJuice = t.StakeMYRJuice
	FROM		dbo.OSStagingDataTGRS AS tp WITH (ROWLOCK, UPDLOCK)
	INNER JOIN	#tmpResults AS t WITH (NOLOCK)
			ON	t.MatchId = tp.MatchId
			AND	t.BetType = tp.BettypeId
	WHERE	tp.EventDate = t.EventDate;
END;

GO
/*<info serverAlias="DBTGRS-bodb_TGRS" executers="bodbTGRSNet" isFunction="0" isNested="0"></info>*/