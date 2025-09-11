--should be around 10 minutes per month

DECLARE @FromDateBK		SMALLDATETIME = '2025-01-01'
	,	@ToDateBK	    SMALLDATETIME = '2025-01-30'

BEGIN;
	SET NOCOUNT ON;

	-- Common variables
	DECLARE	@IdForUnassignedTrader	INT	= 0;
	
	-- Create BetType mapping table for better performance
	CREATE TABLE #tmpBetTypeMapping (
		BetType		SMALLINT,
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
		TraderId				INT
	,	EventDate				DATE
	,   CustID					INT
	,	MatchId					INT
	,	BetType					SMALLINT
	,	BetTeam					VARCHAR(10)
	,	ScoreHDP				SMALLMONEY
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
		,	TraderId				INT
		,	CustID					INT
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
		,	TraderId				INT
		,	SiteID					INT
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

    --SET STATISTICS XML ON 
	BEGIN
		-- Step 1: Insert all data with placeholder TraderId = @IdForUnassignedTrader
		INSERT INTO #tmpDataGroup (TraderId, EventDate, CustID, MatchId, BetType, BetTeam, ScoreHDP, AVGOdds, StakeMYBeforeComm, StakeMY, Stake, 
			AVGOdds_AR, StakeMYBeforeComm_AR, StakeMY_AR, Stake_AR, Is8RM)
		SELECT	
			[TraderId]			= @IdForUnassignedTrader,
			[EventDate]			= b.winlostdate,
			[CustID]			= b.custid,
			[MatchId]			= b.matchid,
			[BetType]		    = b.BetType,
			[BetTeam]			= b.betteam,
			[ScoreHDP]			= CASE WHEN b.bettype IN (1, 7) THEN (b.hdp1 + b.livehomescore) - (b.hdp2 + b.liveawayscore) ELSE b.hdp1 END,
			[AVGOdds]			= SUM((CASE WHEN b.odds < 0 THEN 1 ELSE b.odds END) * ABS(
				CASE WHEN ABS(b.modds) = 0.25 THEN 0.5 ELSE 1 END * ABS(b.stake)
			) * (1 - b.tpositiontaking - ISNULL(b.epositiontaking, 0)) * b.virtualrate)
									/ SUM((CASE WHEN b.odds < 0 THEN -b.odds ELSE 1 END) * ABS(
				CASE WHEN ABS(b.modds) = 0.25 THEN 0.5 ELSE 1 END * ABS(b.stake)
			) * (CASE WHEN (1 - b.tpositiontaking - ISNULL(b.epositiontaking, 0) = 0) THEN 1 ELSE (1 - b.tpositiontaking - ISNULL(b.epositiontaking, 0)) END) * b.virtualrate),
			[StakeMYBeforeComm]	= SUM((CASE WHEN ABS(b.odds) <= 1 THEN 1 ELSE ABS(b.odds) END * CASE WHEN ABS(b.modds) = 0.25 THEN 0.5 ELSE 1 END * ABS(b.stake)) * (1 - b.tpositiontaking - ISNULL(b.epositiontaking, 0)) * b.virtualrate),
			[StakeMY]			= SUM((CASE WHEN ABS(b.odds) <= 1 THEN 1 ELSE ABS(b.odds) END * CASE WHEN ABS(b.modds) = 0.25 THEN 0.5 ELSE 1 END * ABS(b.stake)) * (1 - b.tpositiontaking - ISNULL(b.epositiontaking, 0)) * b.virtualrate - (b.scomm - CASE WHEN b.tpositiontaking = 1 THEN 0 ELSE b.scomm * ISNULL(b.epositiontaking, 0) / (1 - b.tpositiontaking) END) * (CASE WHEN b.virtualrate > b.actualrate THEN b.actualrate ELSE b.virtualrate END)),
			[Stake]				= SUM(CASE WHEN b.odds < 0 THEN -b.odds ELSE 1 END * ABS(CASE WHEN ABS(b.modds) = 0.25 THEN 0.5 ELSE 1 END * ABS(b.stake)) * (1 - b.tpositiontaking - ISNULL(b.epositiontaking, 0)) * b.virtualrate - (b.scomm - CASE WHEN b.tpositiontaking = 1 THEN 0 ELSE b.scomm * ISNULL(b.epositiontaking, 0) / (1 - b.tpositiontaking) END) * (CASE WHEN b.virtualrate > b.actualrate THEN b.actualrate ELSE b.virtualrate END)),
			[AVGOdds_AR]		= SUM((CASE WHEN b.odds < 0 THEN 1 ELSE b.odds END) * ABS(CASE WHEN ABS(b.modds) = 0.25 THEN 0.5 ELSE 1 END * ABS(b.stake)) * (1 - b.tpositiontaking - ISNULL(b.epositiontaking, 0)) * (CASE WHEN b.virtualrate > b.actualrate THEN b.virtualrate ELSE b.actualrate END))
									/ SUM((CASE WHEN b.odds < 0 THEN -b.odds ELSE 1 END) * ABS(CASE WHEN ABS(b.modds) = 0.25 THEN 0.5 ELSE 1 END * ABS(b.stake)) * (CASE WHEN (1 - b.tpositiontaking - ISNULL(b.epositiontaking, 0) = 0) THEN 1 ELSE (1 - b.tpositiontaking - ISNULL(b.epositiontaking, 0)) END) * (CASE WHEN b.virtualrate > b.actualrate THEN b.virtualrate ELSE b.actualrate END)),
			[StakeMYBeforeComm_AR]	= SUM((CASE WHEN ABS(b.odds) <= 1 THEN 1 ELSE ABS(b.odds) END * CASE WHEN ABS(b.modds) = 0.25 THEN 0.5 ELSE 1 END * ABS(b.stake)) * (1 - b.tpositiontaking - ISNULL(b.epositiontaking, 0)) * (CASE WHEN b.virtualrate > b.actualrate THEN b.virtualrate ELSE b.actualrate END)),
			[StakeMY_AR]		= SUM((CASE WHEN ABS(b.odds) <= 1 THEN 1 ELSE ABS(b.odds) END * CASE WHEN ABS(b.modds) = 0.25 THEN 0.5 ELSE 1 END * ABS(b.stake)) * (1 - b.tpositiontaking - ISNULL(b.epositiontaking, 0)) * (CASE WHEN b.virtualrate > b.actualrate THEN b.virtualrate ELSE b.actualrate END) - (b.scomm - CASE WHEN b.tpositiontaking = 1 THEN 0 ELSE b.scomm * ISNULL(b.epositiontaking, 0) / (1 - b.tpositiontaking) END) * b.actualrate),
			[Stake_AR]			= SUM(CASE WHEN b.odds < 0 THEN -b.odds ELSE 1 END * ABS(CASE WHEN ABS(b.modds) = 0.25 THEN 0.5 ELSE 1 END * ABS(b.stake)) * (1 - b.tpositiontaking - ISNULL(b.epositiontaking, 0)) * (CASE WHEN b.virtualrate > b.actualrate THEN b.virtualrate ELSE b.actualrate END) - (b.scomm - CASE WHEN b.tpositiontaking = 1 THEN 0 ELSE b.scomm * ISNULL(b.epositiontaking, 0) / (1 - b.tpositiontaking) END) * b.actualrate),
			[Is8RM]				= CASE WHEN b.recommend != 52466 THEN 0 ELSE 1 END
		FROM bodb_Archive.dbo.bettrans_bk AS b WITH (NOLOCK)
		WHERE b.winlostdate BETWEEN @FromDateBK AND @ToDateBK
			AND b.bettype IN (1, 3, 7, 8)
			AND b.StatusID IN (112, 113)
			AND b.Currency NOT IN (20, 27, 28)
			AND b.LiveIndicator = 1
		GROUP BY 
			b.winlostdate,
			b.custid,
			b.matchid,
			b.BetType,
			b.betteam,
			CASE WHEN b.bettype IN (1, 7) THEN (b.hdp1 + b.livehomescore) - (b.hdp2 + b.liveawayscore) ELSE b.hdp1 END,
			CASE WHEN b.recommend != 52466 THEN 0 ELSE 1 END
		OPTION (RECOMPILE, MAX_GRANT_PERCENT = 15);

		-- Step 2: Update TraderId using a simple join (force use seek on IX_MatchID and key look up - fast for under ~50k rows)
		WITH LatestTraderAssignments AS (
			SELECT 
				a.TraderId,
				a.MatchId,
				a.BetType,
				ROW_NUMBER() OVER(
					PARTITION BY a.MatchId, a.BetType 
					ORDER BY a.UpdatedTime DESC, a.ID DESC
				) AS Row_Num
			FROM bodb_archive.dbo.Dot_Admin_Assignment_Trader_bk AS a WITH (NOLOCK, INDEX(IX_MatchID))
			WHERE a.TraderId <> 0 
				AND a.bettype IN (1, 3, 7, 8)
				AND a.MatchId IN (SELECT MatchId FROM #tmpDataGroup)
		)
		UPDATE dg 
		SET TraderId = lta.TraderId
		FROM #tmpDataGroup dg
		INNER JOIN LatestTraderAssignments lta 
			ON dg.MatchId = lta.MatchId 
			AND dg.BetType = lta.BetType 
			AND lta.Row_Num = 1;

		-- Step 3: Update BetType to the mapped bettype
		WITH SpecialType AS (
			SELECT  
				fm.MatchId,
				CASE 
					WHEN l.LeagueName LIKE '%SPECIFIC 15 MINS TOTAL BOOKINGS%' THEN 1
					WHEN l.LeagueName LIKE '%SPECIFIC 15 MINS%' AND tm.TeamName LIKE '%No.of Corners%' THEN 2
					WHEN l.LeagueName LIKE '%SPECIALS' AND (tm.TeamName LIKE '%Over' OR tm.TeamName LIKE '%Under') THEN 3
					WHEN l.LeagueName LIKE '%SPECIFIC 15 MINS%' THEN 4
					WHEN l.LeagueName LIKE '%SPECIFIC 10 MINS%' THEN 5
					WHEN tm.TeamName LIKE '%No.of Corners%' THEN 6
					WHEN tm.TeamName LIKE '%Total Bookings' THEN 7
					WHEN tm.TeamName LIKE '%Corner%' THEN 8
					WHEN tm.TeamName LIKE '%Booking' THEN 9
					ELSE 0
				END AS SpecialType
			FROM bodb_archive.dbo.match_bk AS fm WITH (NOLOCK)
			LEFT HASH JOIN bodb02.dbo.Team AS tm WITH (NOLOCK) ON fm.homeid = tm.teamid
			LEFT HASH JOIN bodb02.dbo.League AS l WITH (NOLOCK) ON fm.leagueid = l.LeagueId
		)
		UPDATE dg
		SET dg.BetType = btm.MappedBetType
		FROM #tmpDataGroup dg
		INNER HASH JOIN SpecialType st
			ON dg.MatchId = st.MatchId
		INNER JOIN #tmpBetTypeMapping btm
			ON dg.BetType = btm.BetType
			AND st.SpecialType = btm.SpecialType
		OPTION (MAX_GRANT_PERCENT = 10);
	END;


	INSERT INTO #tmpJuice (EventDate, TraderId, MatchId, CustID, BetType, ScoreHDP, StakeMYBeforeComm, StakeMY, Juice, StakeMYRJuice, StakeMYRTotal, 
		StakeMYBeforeComm_AR, StakeMY_AR, Juice_AR, StakeMYRJuice_AR, StakeMYRTotal_AR, Is8RM)
	SELECT	[EventDate]			= temp1.EventDate
		,	[TraderId]			= temp1.TraderId
		,	[MatchId]			= temp1.MatchId
		,	[CustID]			= temp1.CustID
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
			AND	temp1.TraderId = temp2.TraderId
			AND	temp1.CustID = temp2.CustID
	GROUP BY temp1.EventDate, temp1.TraderId, temp1.MatchId, temp1.CustID, temp1.BetType, temp1.ScoreHDP, temp1.Is8RM;

	INSERT INTO	#tmpSumTotal (EventDate, TraderId, MatchId, SiteID, BetType, StakeMYBeforeComm, Juice, StakeMYRJuice, StakeMYBeforeComm_AR, Juice_AR, StakeMYRJuice_AR, Is8RM)
	SELECT	[EventDate]			= t.EventDate
		,	[TraderId]			= t.TraderId
		,	[MatchId]			= t.MatchId
		,	[SiteID]			= s.siteid
		,	[BetType]			= t.BetType
		,	[StakeMYBeforeComm]	= SUM(t.StakeMYBeforeComm)
		,	[Juice]				= SUM(t.Juice)
		,	[StakeMYRJuice]		= SUM(CASE WHEN t.StakeMYRTotal = 0 THEN 0 ELSE CAST(t.StakeMYBeforeComm AS DECIMAL(38,18)) * t.StakeMYRJuice / t.StakeMYRTotal END) -- Before comm		
		,	[StakeMYBeforeComm_AR]	= SUM(t.StakeMYBeforeComm_AR)
		,	[Juice_AR]			= SUM(t.Juice_AR)
		,	[StakeMYRJuice_AR]	= SUM(CASE WHEN t.StakeMYRTotal_AR = 0 THEN 0 ELSE CAST(t.StakeMYBeforeComm_AR AS DECIMAL(38,18)) * t.StakeMYRJuice_AR / t.StakeMYRTotal_AR END) -- Before comm
		,	[Is8RM]				= t.Is8RM
	FROM	#tmpJuice t WITH(NOLOCK)
		INNER JOIN bodb02.dbo.vw_Customer AS c WITH (NOLOCK) ON t.CustID = c.CustID
		INNER JOIN bodb02.dbo.Site AS s WITH (NOLOCK) ON c.site = s.site
	GROUP BY t.EventDate, t.TraderId, t.MatchId, s.siteid, t.BetType, t.ScoreHDP, t.Is8RM;
	
	--Update real data
	UPDATE	tp
	SET		tp.Juice = t.Juice
		,	tp.StakeMYR = t.StakeMYBeforeComm
		,	tp.StakeMYRJuice = t.StakeMYRJuice
		,	tp.Juice_AR = t.Juice_AR
		,	tp.StakeMYR_AR = t.StakeMYBeforeComm_AR
		,	tp.StakeMYRJuice_AR = t.StakeMYRJuice_AR
	FROM dbo.TraderPerformance AS tp WITH (ROWLOCK, UPDLOCK)
		INNER JOIN	#tmpSumTotal AS t WITH (NOLOCK) ON t.MatchId = tp.matchid
			AND	t.BetType = tp.bettype AND t.Is8RM = tp.Is8RM AND t.TraderId = tp.CustID AND t.SiteID = tp.SiteID
	WHERE tp.EventDate = t.EventDate
		AND tp.EventDate BETWEEN @FromDateBK AND @ToDateBK
		AND tp.IsLive = 1
	OPTION (RECOMPILE, MAX_GRANT_PERCENT = 15);
    
END;

GO
/*<info serverAlias="DBTGRS-bodb_TGRS" executers="bodbTGRSNet" isFunction="0" isNested="0"></info>*/