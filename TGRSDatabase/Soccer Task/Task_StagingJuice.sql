ALTER PROCEDURE [dbo].[Task_StagingJuice]
		@BeforeMoveBetsDay		BIT = 1	
	,	@GenerateFromDate		SMALLDATETIME = NULL
	,	@GenerateToDate			SMALLDATETIME = NULL
AS
/*  
	Created:	20170214@Long
	Task :		Update Juice for Trader Performance
	DB:			DBTGRS.bodb_TGRS
	Original:
  
	Revisions:
   		- 20170315@Long:	 Apply ExtraPT and Calc for TO & WL's Leftover
		- 20170330@John:	 Update TO & WL's Leftover
		- 20170315@Long:	 Devide batch by date (not by 200k records as it is)
		- 20170830@Long:	 Support UnassignedTrader
		- 20170914@Billy:	 Format code and tune performance for Task Staging Juice - [Redmine: #81465]
		- 20170918@Billy:	 Remove hedge match from bettrans data - [Redmine: #83470]		
		- 20180102@Long:	 Change the way to get BU & MB days
		- 20180103@Long:	 Support code for generating historical data
		- 20180105@Aaron:	 Fix date range. Note: BU & MB are in bettrans14
		- 20180423@John:	 Update date range [Redmine: #89493]
		- 20190116@John:	 Fix date range for generating historical data [Redmine: #108008]
		- 20190304@Long:	 Calc Actual-rate values for Soccer [Redmine ID: 108920]
		- 20190704@John.Ngo: Implement change request to the job sum and enhance logic on Extra PT WL calculation [Redmine ID: 116379]
		- 20191018@John.Ngo: Remove 'Select temp data' when debug = 1 [Redmine ID: 118959]
		- 20200331@John.Ngo: Update new table [Dot_Admin_Assignment_Trader] [Redmine ID: 120634]
		- 20200504@John.Ngo: [TGR] Get ExtraPT from epositiontaking column in bettrans table [Redmine ID: 133409]
		- 20200721@John.Ngo: New Negative Bettype No Of Corner HDP [Redmine ID: 138095]
		- 20221025@John.Ngo: [TGR] Enhance for the case of TPositionTaking = 1 [Redmine ID: 179546]
		- 20230421@John.Ngo: Update formula of Juice and Leftover (Separate 8RM data) [Redmine ID: 187082]
		- 20250915@Jaden.Tang: Store Juice data in TraderJuicePerformance table instead of TraderPerformance table [Redmine ID: #237899]
							   As having SiteID will make Juice data different
   		
	Param's Explanation:
		
	Exam:
*/
BEGIN;
	SET NOCOUNT ON;

	DECLARE @BalanceUpDay SMALLDATETIME, @MoveBetsDay SMALLDATETIME;
	SELECT @MoveBetsDay = MoveBetsDay, @BalanceUpDay = BalanceUpDay
	FROM OPENQUERY(DBACC,'exec bodb02.dbo.Age_SelBalanceUpDay')

	DECLARE @Yesterday SMALLDATETIME = DATEADD(DAY, -1, GETDATE());

	-- No input date range: Default job run
	IF (@GenerateToDate IS NULL)
		SELECT @GenerateToDate = @Yesterday;

	IF (@GenerateFromDate IS NULL)
	BEGIN
		IF @BeforeMoveBetsDay = 1
			BEGIN
				SELECT @GenerateFromDate =	CASE WHEN (@MoveBetsDay - 3) > @BalanceUpDay 
												THEN (@MoveBetsDay - 3) 
											ELSE @BalanceUpDay END;
			END
		ELSE
			BEGIN
				SELECT @GenerateFromDate = @MoveBetsDay + 1;
			END;
	END;

	IF @GenerateToDate < @GenerateFromDate
	BEGIN
		RAISERROR('GenerateToDate < GenerateFromDate: Unacceptable!', 0, 0) WITH NOWAIT;
		RETURN;
	END;

	CREATE TABLE #tmpSoccerMatch (
		MatchId INT,
		LeagueId INT,
		HomeId INT,
		SpecialType SMALLINT,
		PRIMARY KEY (MatchId)
	);

	CREATE TABLE #tmpBetTypeMapping (
		BetType				SMALLINT,
		SpecialType			SMALLINT,
		MappedBetType		SMALLINT,
		PRIMARY KEY (BetType, SpecialType)
	);
	
	INSERT INTO #tmpBetTypeMapping (BetType, SpecialType, MappedBetType) 
	VALUES
		(1, 0, 1),   -- HDP
		(3, 0, 3),   -- O/U
		(8, 0, 8),   -- 1st O/U
		(1, 4, -1),  -- 15mins HDP
		(1, 8, -2),  -- Next Corner
		(1, 5, -15), -- 10mins HDP
		(1, 9, -3),  -- Next Booking
		(3, 4, -5),  -- 15mins O/U
		(3, 5, -6),  -- 10mins O/U
		(1, 2, -39), -- No. of Corners 15mins HPD
		(3, 2, -7),  -- No. of Corner 15mins O/U
		(3, 7, -8),  -- Total Bookings
		(1, 1, -37), -- Total Bookings 15mins HDP
		(3, 1, -10), -- Total Bookings 15mins O/U
		(1, 6, -41), -- No. of Corners HPD
		(3, 6, -13), -- No. of Corners O/U
		(7, 6, -40), -- 1st No. of Corners HDP
		(8, 6, -12), -- 1st No. of Corners O/U
		(8, 7, -9),  -- 1st TotalBookings
		(3, 3, -11), -- Single Team O/U
		(8, 3, -11); -- Single Team O/U

	CREATE TABLE	#tmpDataGroup (
		EventDate				DATE
	,	MatchId					INT
	,	BetType					SMALLINT
	,	BetTeam					VARCHAR(10)
	,	ScoreHDP				SMALLMONEY
	/*Juice metrics*/
	,	AVGOdds					FLOAT
	,	StakeMYBeforeComm		MONEY
	,	StakeMY					MONEY
	,	Stake					MONEY
	,	AVGOdds_AR				FLOAT
	,	StakeMYBeforeComm_AR	MONEY
	,	StakeMY_AR				MONEY
	,	Stake_AR				MONEY
	,	Is8RM					BIT
	);


	
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
		,	Is8RM					BIT
	);

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
		,	Is8RM					BIT
	);

	-- Step 1: Insert data from sources
	INSERT INTO #tmpDataGroup WITH (TABLOCK) (EventDate, MatchId, BetType, BetTeam, ScoreHDP, AVGOdds, StakeMYBeforeComm, StakeMY, Stake, 
		AVGOdds_AR, StakeMYBeforeComm_AR, StakeMY_AR, Stake_AR, Is8RM)
	SELECT	
		[EventDate]			= b.winlostdate,
		[MatchId]			= b.matchid,
		[BetType]		    = b.BetType,
		[BetTeam]			= b.betteam,
		[ScoreHDP]			= CASE WHEN b.bettype IN (1, 7) THEN (b.hdp1 + b.livehomescore) - (b.hdp2 + b.liveawayscore) ELSE b.hdp1 END,
		[AVGOdds]			= SUM(
			(CASE WHEN b.odds < 0 THEN 1 ELSE b.odds END) * ABS(CASE WHEN ABS(b.modds) = 0.25 THEN 0.5 ELSE 1 END * ABS(b.stake)) 
			* (1 - b.tpositiontaking - ISNULL(b.epositiontaking, 0)) 
			* b.virtualrate
		)
		/ SUM(
			(CASE WHEN b.odds < 0 THEN -b.odds ELSE 1 END) * ABS(CASE WHEN ABS(b.modds) = 0.25 THEN 0.5 ELSE 1 END * ABS(b.stake)) 
			* (CASE WHEN (1 - b.tpositiontaking - ISNULL(b.epositiontaking, 0) = 0) THEN 1 ELSE (1 - b.tpositiontaking - ISNULL(b.epositiontaking, 0)) END) 
			* b.virtualrate
		),
		[StakeMYBeforeComm]	= SUM(
			(CASE WHEN ABS(b.odds) <= 1 THEN 1 ELSE ABS(b.odds) END * CASE WHEN ABS(b.modds) = 0.25 THEN 0.5 ELSE 1 END * ABS(b.stake)) 
			* (1 - b.tpositiontaking - ISNULL(b.epositiontaking, 0)) 
			* b.virtualrate
		),
		[StakeMY]			= SUM(
			(CASE WHEN ABS(b.odds) <= 1 THEN 1 ELSE ABS(b.odds) END * CASE WHEN ABS(b.modds) = 0.25 THEN 0.5 ELSE 1 END * ABS(b.stake)) 
			* (1 - b.tpositiontaking - ISNULL(b.epositiontaking, 0)) 
			* b.virtualrate 
			- (b.scomm - CASE WHEN b.tpositiontaking = 1 THEN 0 ELSE b.scomm * ISNULL(b.epositiontaking, 0) / (1 - b.tpositiontaking) END) 
			* (CASE WHEN b.virtualrate > b.actualrate THEN b.actualrate ELSE b.virtualrate END)
		),
		[Stake]				= SUM(
			CASE WHEN b.odds < 0 THEN -b.odds ELSE 1 END * ABS(CASE WHEN ABS(b.modds) = 0.25 THEN 0.5 ELSE 1 END * ABS(b.stake)) 
			* (1 - b.tpositiontaking - ISNULL(b.epositiontaking, 0)) 
			* b.virtualrate 
			- (b.scomm - CASE WHEN b.tpositiontaking = 1 THEN 0 ELSE b.scomm * ISNULL(b.epositiontaking, 0) / (1 - b.tpositiontaking) END) 
			* (CASE WHEN b.virtualrate > b.actualrate THEN b.actualrate ELSE b.virtualrate END)
		),
		[AVGOdds_AR]		= SUM(
			(CASE WHEN b.odds < 0 THEN 1 ELSE b.odds END) * ABS(CASE WHEN ABS(b.modds) = 0.25 THEN 0.5 ELSE 1 END * ABS(b.stake)) 
			* (1 - b.tpositiontaking - ISNULL(b.epositiontaking, 0)) 
			* (CASE WHEN b.virtualrate > b.actualrate THEN b.virtualrate ELSE b.actualrate END)
		) / SUM(
			(CASE WHEN b.odds < 0 THEN -b.odds ELSE 1 END) * ABS(CASE WHEN ABS(b.modds) = 0.25 THEN 0.5 ELSE 1 END * ABS(b.stake)) 
			* (CASE WHEN (1 - b.tpositiontaking - ISNULL(b.epositiontaking, 0) = 0) THEN 1 ELSE (1 - b.tpositiontaking - ISNULL(b.epositiontaking, 0)) END) 
			* (CASE WHEN b.virtualrate > b.actualrate THEN b.virtualrate ELSE b.actualrate END)
		),
		[StakeMYBeforeComm_AR]	= SUM(
			(CASE WHEN ABS(b.odds) <= 1 THEN 1 ELSE ABS(b.odds) END * CASE WHEN ABS(b.modds) = 0.25 THEN 0.5 ELSE 1 END * ABS(b.stake)) 
			* (1 - b.tpositiontaking - ISNULL(b.epositiontaking, 0)) 
			* (CASE WHEN b.virtualrate > b.actualrate THEN b.virtualrate ELSE b.actualrate END)
		),
		[StakeMY_AR]		= SUM(
			(CASE WHEN ABS(b.odds) <= 1 THEN 1 ELSE ABS(b.odds) END * CASE WHEN ABS(b.modds) = 0.25 THEN 0.5 ELSE 1 END * ABS(b.stake)) 
			* (1 - b.tpositiontaking - ISNULL(b.epositiontaking, 0)) 
			* (CASE WHEN b.virtualrate > b.actualrate THEN b.virtualrate ELSE b.actualrate END) 
			- (b.scomm - CASE WHEN b.tpositiontaking = 1 THEN 0 ELSE b.scomm * ISNULL(b.epositiontaking, 0) / (1 - b.tpositiontaking) END) 
			* b.actualrate
		),
		[Stake_AR]			= SUM(
			CASE WHEN b.odds < 0 THEN -b.odds ELSE 1 END * ABS(CASE WHEN ABS(b.modds) = 0.25 THEN 0.5 ELSE 1 END * ABS(b.stake)) 
			* (1 - b.tpositiontaking - ISNULL(b.epositiontaking, 0)) 
			* (CASE WHEN b.virtualrate > b.actualrate THEN b.virtualrate ELSE b.actualrate END) 
			- (b.scomm - CASE WHEN b.tpositiontaking = 1 THEN 0 ELSE b.scomm * ISNULL(b.epositiontaking, 0) / (1 - b.tpositiontaking) END) 
			* b.actualrate
		),
		[Is8RM]				= CASE WHEN b.recommend != 52466 THEN 0 ELSE 1 END
	FROM (
		SELECT winlostdate, matchid, BetType, betteam, hdp1, hdp2, livehomescore, liveawayscore, odds, modds, stake, tpositiontaking, epositiontaking, virtualrate, actualrate, scomm, recommend, statusid, currency, liveindicator  
		FROM bodb_archive.dbo.bettrans_bk WITH (NOLOCK)
		WHERE winlostdate BETWEEN @GenerateFromDate AND @GenerateToDate AND winlostdate < @BalanceUpDay
		UNION ALL
		SELECT winlostdate, matchid, BetType, betteam, hdp1, hdp2, livehomescore, liveawayscore, odds, modds, stake, tpositiontaking, epositiontaking, virtualrate, actualrate, scomm, recommend, statusid, currency, liveindicator 
		FROM bodb02.dbo.bettrans14 WITH (NOLOCK)
		WHERE winlostdate BETWEEN @GenerateFromDate AND @GenerateToDate AND winlostdate BETWEEN @BalanceUpDay AND @MoveBetsDay
		UNION ALL
		SELECT winlostdate, matchid, BetType, betteam, hdp1, hdp2, livehomescore, liveawayscore, odds, modds, stake, tpositiontaking, epositiontaking, virtualrate, actualrate, scomm, recommend, statusid, currency, liveindicator 
		FROM bodb02.dbo.bettrans WITH (NOLOCK)
		WHERE winlostdate BETWEEN @GenerateFromDate AND @GenerateToDate AND winlostdate > @MoveBetsDay
	) AS b
	WHERE b.bettype IN (1, 3, 7, 8)
		AND b.StatusID IN (112, 113)
		AND b.Currency NOT IN (20, 27, 28)
		AND b.LiveIndicator = 1
	GROUP BY 
		b.winlostdate,
		b.matchid,
		b.BetType,
		b.betteam,
		CASE WHEN b.bettype IN (1, 7) THEN (b.hdp1 + b.livehomescore) - (b.hdp2 + b.liveawayscore) ELSE b.hdp1 END,
		CASE WHEN b.recommend != 52466 THEN 0 ELSE 1 END
	OPTION (RECOMPILE, MAX_GRANT_PERCENT = 10, HASH JOIN);

	CREATE CLUSTERED INDEX #IDX_tmpDataGroup ON #tmpDataGroup (MatchId, BetType);

	-- Step 2: Calculate Juice
	INSERT INTO #tmpJuice (EventDate, MatchId, BetType, ScoreHDP, StakeMYBeforeComm, StakeMY, Juice, StakeMYRJuice, StakeMYRTotal, 
		StakeMYBeforeComm_AR, StakeMY_AR, Juice_AR, StakeMYRJuice_AR, StakeMYRTotal_AR, Is8RM)
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
		,	[Is8RM]				= temp1.Is8RM
	FROM		#tmpDataGroup AS temp1 WITH (NOLOCK)
	LEFT JOIN	#tmpDataGroup AS temp2 WITH (NOLOCK)
			ON	temp1.MatchId = temp2.MatchId
			AND	temp1.BetType = temp2.BetType
			AND	temp1.ScoreHDP = temp2.ScoreHDP
			AND	temp1.BetTeam <> temp2.BetTeam
			AND	temp1.Is8RM = temp2.Is8RM
	GROUP BY temp1.EventDate, temp1.MatchId, temp1.BetType, temp1.ScoreHDP, temp1.Is8RM;

	-- Step 3: Aggregate data by MatchId/BetType
	INSERT INTO	#tmpSumTotal (EventDate, MatchId, BetType, StakeMYBeforeComm, Juice, StakeMYRJuice, StakeMYBeforeComm_AR, Juice_AR, StakeMYRJuice_AR, Is8RM)
	SELECT	[EventDate]			= t.EventDate
		,	[MatchId]			= t.MatchId
		,	[BetType]			= t.BetType
		,	[StakeMYBeforeComm]	= SUM(t.StakeMYBeforeComm)
		,	[Juice]				= SUM(t.Juice)
		,	[StakeMYRJuice]		= SUM(CASE WHEN t.StakeMYRTotal = 0 THEN 0 ELSE CAST(t.StakeMYBeforeComm AS DECIMAL(38,18)) * t.StakeMYRJuice / t.StakeMYRTotal END) -- Before comm		
		,	[StakeMYBeforeComm_AR]	= SUM(t.StakeMYBeforeComm_AR)
		,	[Juice_AR]			= SUM(t.Juice_AR)
		,	[StakeMYRJuice_AR]	= SUM(CASE WHEN t.StakeMYRTotal_AR = 0 THEN 0 ELSE CAST(t.StakeMYBeforeComm_AR AS DECIMAL(38,18)) * t.StakeMYRJuice_AR / t.StakeMYRTotal_AR END) -- Before comm
		,	[Is8RM]				= t.Is8RM
	FROM	#tmpJuice t WITH(NOLOCK)
	GROUP BY t.EventDate, t.MatchId, t.BetType, t.Is8RM;

	-- Step 4: Prepare match data for filtering and mapping to TGRS specific bettypes
	-- Prerequisite: TraderPerformance must already be populated
	INSERT INTO #tmpSoccerMatch (MatchId, LeagueId, HomeId)
	SELECT DISTINCT MatchId, LeagueId, HomeId FROM dbo.TraderPerformance WITH (NOLOCK)
	WHERE EventDate BETWEEN @GenerateFromDate AND @GenerateToDate
		AND IsLive = 1
	OPTION (RECOMPILE, MAX_GRANT_PERCENT = 10);
	
	WITH CTE_SpecialMatch AS (
		SELECT fm.MatchId, 
			CASE 
				WHEN tm.TeamName LIKE '%No.of Corners%' THEN 6
				WHEN tm.TeamName LIKE '%Total Bookings' THEN 7
				WHEN tm.TeamName LIKE '%Corner%' THEN 8
				WHEN tm.TeamName LIKE '%Booking' THEN 9
				ELSE 0
			END AS SpecialType
		FROM #tmpSoccerMatch AS fm
		INNER JOIN bodb02.dbo.Team AS tm WITH (NOLOCK) 
				ON fm.homeid = tm.teamid
				AND (
					tm.TeamName LIKE '%No.of Corners%'
					OR tm.TeamName LIKE '%Total Bookings'
					OR tm.TeamName LIKE '%Corner%'
					OR tm.TeamName LIKE '%Booking%'
				)
		UNION ALL
		SELECT fm.MatchId, 
			CASE 
				WHEN l.LeagueName LIKE '%SPECIFIC 15 MINS TOTAL BOOKINGS%' THEN 1
				WHEN l.LeagueName LIKE '%SPECIFIC 15 MINS%' AND tm.TeamName LIKE '%No.of Corners%' THEN 2
				WHEN l.LeagueName LIKE '%SPECIALS' AND (tm.TeamName LIKE '%Over' OR tm.TeamName LIKE '%Under') THEN 3
				WHEN l.LeagueName LIKE '%SPECIFIC 15 MINS%' THEN 4
				WHEN l.LeagueName LIKE '%SPECIFIC 10 MINS%' THEN 5
				ELSE 0
			END AS SpecialType
		FROM #tmpSoccerMatch AS fm
		INNER JOIN bodb02.dbo.League AS l WITH (NOLOCK) 
				ON fm.leagueid = l.LeagueId
				AND (
					l.LeagueName LIKE '%SPECIFIC 15 MINS TOTAL BOOKINGS%'
					OR l.LeagueName LIKE '%SPECIFIC 15 MINS%'
					OR l.LeagueName LIKE '%SPECIFIC 10 MINS%'
				)
		LEFT JOIN bodb02.dbo.Team AS tm WITH (NOLOCK) 
				ON fm.homeid = tm.teamid
				AND (
					tm.TeamName LIKE '%No.of Corners%'
					OR tm.TeamName LIKE '%Over' OR tm.TeamName LIKE '%Under'
				)
	)
	UPDATE #tmpSoccerMatch
	SET SpecialType = sm.SpecialType
	FROM #tmpSoccerMatch AS fm
	INNER JOIN CTE_SpecialMatch AS sm ON fm.MatchId = sm.MatchId;

	-- Step 5: Update BetType to the mapped bettype
	UPDATE #tmpSumTotal
	SET BetType = btm.MappedBetType
	FROM #tmpSumTotal AS tst
	INNER JOIN #tmpSoccerMatch AS sm ON tst.MatchId = sm.MatchId
	INNER JOIN #tmpBetTypeMapping AS btm ON sm.SpecialType = btm.SpecialType AND tst.BetType = btm.BetType;

	-- Step 6: Delete existing data and insert new data
	DELETE FROM dbo.TraderJuicePerformance
	WHERE EventDate BETWEEN @GenerateFromDate AND @GenerateToDate
	OPTION (RECOMPILE);

	INSERT INTO dbo.TraderJuicePerformance (
		EventDate,
		MatchId,
		CustID,
		BetType,
		LeagueID,
		HomeID,
		AwayID,
		WorkShift,
		Is8RM,
		IsLive,
		/*Juice metrics: Get from #tmpSumTotal*/
		Juice,
		StakeMYR,
		StakeMYRJuice,
		Juice_AR,
		StakeMYR_AR,
		StakeMYRJuice_AR,
		/*Other metrics: Get from TraderPerformance*/
		WinLost,
		Comm,
		Spread,
		BetCount
	)
	SELECT tst.EventDate, 
		tst.MatchId, 
		tp.CustId,
		tst.BetType,
		tp.LeagueId,
		tp.HomeId,
		tp.AwayId,
		tp.WorkShift,
		tst.Is8RM, 
		tp.IsLive,
		SUM(tst.Juice) AS Juice, 
		SUM(tst.StakeMYBeforeComm) AS StakeMYR, 
		SUM(tst.StakeMYRJuice) AS StakeMYRJuice,
		SUM(tst.Juice_AR) AS Juice_AR, 
		SUM(tst.StakeMYBeforeComm_AR) AS StakeMYR_AR,
		SUM(tst.StakeMYRJuice_AR) AS StakeMYRJuice_AR,
		SUM(tp.WinLost) AS WinLost,
		SUM(tp.Comm) AS Comm,
		MAX(tp.Spread) AS Spread,
		SUM(tp.BetCount) AS BetCount
	FROM #tmpSumTotal AS tst
	LEFT JOIN dbo.TraderPerformance AS tp WITH (NOLOCK)
		ON tst.EventDate = tp.EventDate
		AND tst.MatchId = tp.MatchId
		AND tst.BetType = tp.BetType
		AND tst.Is8RM = tp.Is8RM
	WHERE tp.EventDate BETWEEN @GenerateFromDate AND @GenerateToDate
		AND tp.IsLive = 1
	GROUP BY tst.EventDate, 
		tst.MatchId, 
		tp.CustId,
		tst.BetType,
		tp.LeagueId,
		tp.HomeId,
		tp.AwayId,
		tp.WorkShift,
		tst.Is8RM, 
		tp.IsLive
	OPTION (RECOMPILE);

	DROP TABLE #tmpBetTypeMapping;
	DROP TABLE #tmpDataGroup;
	DROP TABLE #tmpJuice;
	DROP TABLE #tmpSumTotal;
    DROP TABLE #tmpSoccerMatch;
END;

GO
/*<info serverAlias="DBTGRS-bodb_TGRS" executers="wsv_tgrs" isFunction="0" isNested="0"></info>*/