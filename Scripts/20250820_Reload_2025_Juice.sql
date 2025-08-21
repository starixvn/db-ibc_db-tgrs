DECLARE @FromDateBK		SMALLDATETIME = '2025-01-01'
	,	@ToDateBK	    SMALLDATETIME = '2025-01-04'

BEGIN;
	SET NOCOUNT ON;

	-- Common variables
	DECLARE	@IdForUnassignedTrader	INT	= 0;
	
	-- Create BetType mapping table for better performance
	CREATE TABLE #tmpBetTypeMapping (
		OriginalBetType		SMALLINT,
		SpecialType			SMALLINT,
		MappedBetType		SMALLINT,
		PRIMARY KEY (OriginalBetType, SpecialType)
	);
	
	INSERT INTO #tmpBetTypeMapping (OriginalBetType, SpecialType, MappedBetType) 
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

	CREATE TABLE	#tmpFilteredBettransBKByBatch2 (
		MatchId					INT
	,	Winlostdate				SMALLDATETIME
	,	Bettype					SMALLINT
	,	Virtualrate				FLOAT
	,	Actualrate				FLOAT
	,	Tpositiontaking			SMALLMONEY
	,	Scomm					MONEY
	,	Betteam					VARCHAR(10)
	,	Odds					SMALLMONEY
	,	StatusID				TINYINT
	,	ExtraPT					DECIMAL(12, 8)
	,	ScoreHDP				SMALLMONEY
	,	StakeMY					MONEY
	,	Stake					MONEY
	,	Is8RM					BIT
	);

	CREATE TABLE	#tmpTrader2 (
		TraderId				INT
	,	MatchId					INT
	,	BetType					SMALLINT
	);
	
	CREATE TABLE    #tmpSpecialType (
		MatchId					INT
	,	SpecialType				SMALLINT
	);

	CREATE TABLE #tmpStagingTraderPerformance (
		TraderId			INT,
		EventDate			DATE,
		MatchId				INT,
		BetType				SMALLINT,
		BetTeam				VARCHAR(10),
		ScoreHDP			SMALLMONEY,
		Odds				SMALLMONEY,
		StakeMY				MONEY,
		Stake				MONEY,
		ExtraPT				DECIMAL(12, 8),
		TPositionTaking		SMALLMONEY,
		VirtualRate			FLOAT,
		ActualRate			FLOAT,
		Scomm				MONEY,
		Is8RM				BIT
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
		,	Is8RM					BIT
	);

	DECLARE @InsertedMatchID TABLE (
			MatchId					INT
	);

    SET STATISTICS XML ON 
	BEGIN
		--slow
        INSERT INTO #tmpFilteredBettransBKByBatch2 (MatchId, Winlostdate, Bettype, Virtualrate, Actualrate, 
        Tpositiontaking, Scomm, Betteam, Odds, ExtraPT, ScoreHDP, StakeMY, Stake, Is8RM)
		OUTPUT	INSERTED.MatchId
		INTO	@InsertedMatchID
        SELECT	[MatchId]			= b.matchid
            ,	[Winlostdate]		= b.winlostdate
            ,	[Bettype]			= b.bettype
            ,	[Virtualrate]		= b.virtualrate
            ,	[Actualrate]		= b.actualrate
            ,	[Tpositiontaking]	= b.tpositiontaking
            ,	[Scomm]				= b.scomm
            ,	[Betteam]			= b.betteam
            ,	[Odds]				= b.odds
            ,	[ExtraPT]			= ISNULL(b.epositiontaking, 0)
            ,	[ScoreHDP]			= CASE	WHEN b.bettype IN (1, 7) THEN (b.hdp1 + b.livehomescore) - (b.hdp2 + b.liveawayscore)
                                            ELSE b.hdp1
                                        END
            ,	[StakeMY]			= CASE WHEN ABS(b.odds) <= 1 THEN 1 ELSE ABS(b.odds) END
                                    * CASE WHEN ABS(b.modds) = 0.25 THEN 0.5 ELSE 1 END
                                    * ABS(b.stake)
            ,	[Stake]				= CASE WHEN ABS(b.modds) = 0.25 THEN 0.5 ELSE 1 END
                                    * ABS(b.stake)
            ,	[Is8RM]				= CASE WHEN b.recommend != 52466 THEN 0 ELSE 1 END
        FROM		bodb_Archive.dbo.bettrans_bk AS b WITH (NOLOCK)
        WHERE	b.winlostdate BETWEEN @FromDateBK AND @ToDateBK
            AND	b.bettype IN (1, 3, 7, 8)
            AND	b.StatusID IN (112, 113)
            AND	b.Currency NOT IN (20, 27, 28)
            AND	b.LiveIndicator = 1
        OPTION (RECOMPILE)
        
        ;WITH LatestTraderAssignments AS (
            SELECT 
                a.TraderId,
                a.MatchId,
                a.BetType,
                ROW_NUMBER() OVER(
                    PARTITION BY a.MatchId, a.BetType 
                    ORDER BY a.UpdatedTime DESC,a.ID DESC
                ) AS Row_Num
            FROM bodb_archive.dbo.Dot_Admin_Assignment_Trader_bk AS a WITH (NOLOCK)
            WHERE a.TraderId <> 0 AND a.MatchID IN (SELECT MatchID FROM @InsertedMatchID)
			   AND a.bettype IN (1, 3, 7, 8)
        )
        INSERT INTO	#tmpTrader2 (TraderId, MatchId, BetType)
        SELECT DISTINCT
            lta.TraderId,
            lta.MatchId,
            lta.BetType
        FROM LatestTraderAssignments lta
        WHERE lta.Row_Num = 1
        OPTION (RECOMPILE);

		;WITH SpecialType AS (
			SELECT  fm.MatchId,
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
				LEFT JOIN bodb02.dbo.Team AS tm WITH (NOLOCK) ON fm.homeid = tm.teamid
				LEFT JOIN bodb02.dbo.League AS l WITH (NOLOCK) ON fm.leagueid = l.LeagueId
				WHERE fm.MatchId IN (SELECT MatchId FROM @InsertedMatchID)
		)
		INSERT INTO #tmpSpecialType (MatchId, SpecialType)
		SELECT
			MatchId,
			SpecialType
		FROM SpecialType;
        
		--slow
        INSERT INTO #tmpStagingTraderPerformance
        SELECT	[TraderId]			= ISNULL(t.TraderId, @IdForUnassignedTrader)
            ,	[EventDate]			= b.winlostdate
            ,	[MatchId]			= b.matchid
            ,	[BetType]			= ISNULL(btm.MappedBetType, b.BetType)
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
            ,	[Is8RM]				= b.Is8RM
        FROM		#tmpFilteredBettransBKByBatch2 AS b WITH(NOLOCK)
            LEFT JOIN	#tmpTrader2 AS t WITH (NOLOCK)
                    ON	b.matchid = t.matchid
                    AND	b.BetType = t.BetType
			LEFT JOIN #tmpSpecialType AS st WITH (NOLOCK)
					ON b.matchid = st.MatchId
			LEFT JOIN #tmpBetTypeMapping AS btm WITH (NOLOCK)
					ON b.BetType = btm.OriginalBetType
					AND st.SpecialType = btm.SpecialType;
        
		--slow
        INSERT INTO #tmpDataGroup (TraderId, EventDate, MatchId, BetType, BetTeam, ScoreHDP, AVGOdds, StakeMYBeforeComm, StakeMY, Stake, 
            AVGOdds_AR, StakeMYBeforeComm_AR, StakeMY_AR, Stake_AR, Is8RM)
        SELECT	[TraderId]			= t.TraderId
            ,	[EventDate]			= t.EventDate
            ,	[MatchId]			= t.MatchId
            ,	[BetType]			= t.BetType
            ,	[BetTeam]			= t.BetTeam
            ,	[ScoreHDP]			= t.ScoreHDP
            ,	[AVGOdds]			= SUM((CASE WHEN t.Odds < 0 THEN 1 ELSE t.Odds END) * ABS(t.Stake) * (1 - t.TPositionTaking - t.ExtraPT) * t.VirtualRate)
                                    / SUM((CASE WHEN t.Odds < 0 THEN -t.Odds ELSE 1 END) * ABS(t.Stake) * (CASE WHEN (1 - t.TPositionTaking - t.ExtraPT = 0) THEN 1 ELSE (1 - t.TPositionTaking - t.ExtraPT) END) * t.VirtualRate)
            ,	[StakeMYBeforeComm]	= SUM(t.StakeMY * (1 - t.TPositionTaking - t.ExtraPT) * t.VirtualRate)
            ,	[StakeMY]			= SUM(t.StakeMY * (1 - t.TPositionTaking - t.ExtraPT) * t.VirtualRate - (t.Scomm - CASE WHEN t.TPositionTaking = 1 THEN 0 ELSE t.Scomm * t.ExtraPT / (1 - t.TPositionTaking) END) * (CASE WHEN t.VirtualRate > t.ActualRate THEN t.ActualRate ELSE t.VirtualRate END))
            ,	[Stake]				= SUM(CASE WHEN t.Odds < 0 THEN -t.Odds ELSE 1 END * ABS(t.Stake) * (1 - t.TPositionTaking - t.ExtraPT) * t.VirtualRate - (t.Scomm - CASE WHEN t.TPositionTaking = 1 THEN 0 ELSE t.Scomm * t.ExtraPT / (1 - t.TPositionTaking) END) * (CASE WHEN t.VirtualRate > t.ActualRate THEN t.ActualRate ELSE t.VirtualRate END))
            ,	[AVGOdds_AR]		= SUM((CASE WHEN t.Odds < 0 THEN 1 ELSE t.Odds END) * ABS(t.Stake) * (1 - t.TPositionTaking - t.ExtraPT) * (CASE WHEN t.VirtualRate > t.ActualRate THEN t.VirtualRate ELSE t.ActualRate END))
                                    / SUM((CASE WHEN t.Odds < 0 THEN -t.Odds ELSE 1 END) * ABS(t.Stake) * (CASE WHEN (1 - t.TPositionTaking - t.ExtraPT = 0) THEN 1 ELSE (1 - t.TPositionTaking - t.ExtraPT) END) * (CASE WHEN t.VirtualRate > t.ActualRate THEN t.VirtualRate ELSE t.ActualRate END))
            ,	[StakeMYBeforeComm_AR]	= SUM(t.StakeMY * (1 - t.TPositionTaking - t.ExtraPT) * (CASE WHEN t.VirtualRate > t.ActualRate THEN t.VirtualRate ELSE t.ActualRate END))
            ,	[StakeMY_AR]		= SUM(t.StakeMY * (1 - t.TPositionTaking - t.ExtraPT) * (CASE WHEN t.VirtualRate > t.ActualRate THEN t.VirtualRate ELSE t.ActualRate END) - (t.Scomm - CASE WHEN t.TPositionTaking = 1 THEN 0 ELSE t.Scomm * t.ExtraPT / (1 - t.TPositionTaking) END) * t.ActualRate)
            ,	[Stake_AR]			= SUM(CASE WHEN t.Odds < 0 THEN -t.Odds ELSE 1 END * ABS(t.Stake) * (1 - t.TPositionTaking - t.ExtraPT) * (CASE WHEN t.VirtualRate > t.ActualRate THEN t.VirtualRate ELSE t.ActualRate END) - (t.Scomm - CASE WHEN t.TPositionTaking = 1 THEN 0 ELSE t.Scomm * t.ExtraPT / (1 - t.TPositionTaking) END) * t.ActualRate)
            ,	[Is8RM]				= t.Is8RM	
        FROM	#tmpStagingTraderPerformance AS t
        GROUP BY t.TraderId, t.EventDate, t.MatchId, t.BetType, t.BetTeam, t.ScoreHDP, t.Is8RM;
	END;


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
	GROUP BY t.EventDate, t.MatchId, t.BetType, t.ScoreHDP, t.Is8RM;
		
	INSERT INTO #tmpResults (EventDate, MatchId, BetType, StakeMYBeforeComm, Juice, StakeMYRJuice, StakeMYBeforeComm_AR, Juice_AR, StakeMYRJuice_AR, Is8RM)
	SELECT	[EventDate]			= t.EventDate
		,	[MatchId]			= t.MatchId
		,	[BetType]			= t.BetType
		,	[StakeMYBeforeComm]	= SUM(t.StakeMYBeforeComm)
		,	[Juice]				= SUM(t.Juice)
		,	[StakeMYRJuice]		= SUM(t.StakeMYRJuice)		
		,	[StakeMYBeforeComm_AR]	= SUM(t.StakeMYBeforeComm_AR)
		,	[Juice_AR]			= SUM(t.Juice_AR)
		,	[StakeMYRJuice_AR]	= SUM(t.StakeMYRJuice_AR)
		,	[Is8RM]				= t.Is8RM
	FROM	#tmpSumTotal t WITH(NOLOCK)
	GROUP BY t.EventDate, t.MatchId, t.BetType, t.Is8RM;
	
	SELECT TOP 100 t.* 
    FROM #tmpResults t WITH (NOLOCK)
    INNER JOIN dbo.TraderPerformance AS tp WITH (NOLOCK)
    ON tp.EventDate = t.EventDate 
    AND tp.matchid = t.MatchId 
    AND tp.bettype = t.BetType 
    AND tp.Is8RM = t.Is8RM;
	
END;

GO
/*<info serverAlias="DBTGRS-bodb_TGRS" executers="bodbTGRSNet" isFunction="0" isNested="0"></info>*/