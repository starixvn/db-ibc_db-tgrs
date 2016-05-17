USE [bodb_TGRS]
GO

ALTER PROCEDURE	[dbo].[Task_StagingDataTGRS]
	@Debug				BIT	= 0,
	@BeforeMoveBetsDay	BIT	= 1
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
		- 20160517@Percy: Recalculate Spread for group bettype 1x2 [RedmineID: #56999]    
   		
	Param's Explanation:
		
	Exam:
	 
*/  
BEGIN
	SET NOCOUNT ON;

	DECLARE @Begin DATETIME = GETDATE(), @RowCount INT;

	DECLARE @BalanceUpDay SMALLDATETIME, @MoveBetsDay SMALLDATETIME, @Yesterday SMALLDATETIME;

	DECLARE @Spread1x2 TABLE (Margin MONEY, Spread MONEY)
	INSERT INTO @Spread1x2 (Margin, Spread)
	VALUES
	(1.05, 0.2),
	(1.08, 0.3),
	(1.10, 0.36),
	(1.12, 0.44),
	(1.15, 0.52)

	SELECT	@BalanceUpDay = MIN(winlostdate),
			@MoveBetsDay  = MAX(winlostdate),
			@Yesterday    = CONVERT(DATE,GETDATE()-1)
	FROM	bodb02.dbo.bettrans14 WITH(NOLOCK);

	IF @BeforeMoveBetsDay <> 1	
		SELECT @BalanceUpDay = @MoveBetsDay+1;

	IF @Debug = 1
		SELECT @BalanceUpDay AS BalanceUpDay, @MoveBetsDay AS MoveBetsDay, @Yesterday AS Yesterday;

	IF OBJECT_ID('tempdb..#tmpTrader') IS NOT NULL DROP TABLE #tmpTrader;

	CREATE TABLE #tmpTrader (
		CustId				INT 
		,LeagueId			INT
		,MatchId			INT
		,[WorkShift]		TINYINT
		,MatchCode			VARCHAR(100)
		,SportType			INT
		,EventDate			DATETIME
		,HomeId				INT
		,AwayId				INT
		,BetType			SMALLINT
		,SpecialType		TINYINT
		);

	TRUNCATE TABLE dbo.[Staging_TraderPerformance];

	IF @BeforeMoveBetsDay = 1
	BEGIN
		INSERT INTO #tmpTrader(CustId,LeagueId,WorkShift,MatchId,SportType,EventDate,HomeId,AwayId,BetType,SpecialType,Matchcode)
		SELECT DISTINCT  
			a.OperatorID AS CustId
		,	m.LeagueId
		,	CASE
				WHEN CAST(m.kickofftime AS TIME) >= '00:00:00' AND CAST(m.kickofftime AS TIME) <'6:00:00' THEN 1--  Afternoon: 12:00:00 ~ 17:59:59 (GMT + 8)
				WHEN CAST(m.kickofftime AS TIME) >= '6:00:00' AND CAST(m.kickofftime AS TIME) <'16:00:00'THEN 2 -- Night: 18:00:00 ~ 3:59:59 (GMT + 8)				
				--WHEN CAST(m.kickofftime AS TIME) >= '16:00:00' AND CAST(m.kickofftime AS TIME) <'24:00:00'THEN 3 --  Midnight: 4:00:00 ~ 11:59:59 (GMT + 8)
				ELSE 3
			END [WorkShift]
		,	m.MatchId
		,	m.sporttype as SportType
		,	m.EventDate
		,	m.HomeId
		,	m.AwayId
		,	CASE
				WHEN (a.BetType = 1 or a.BetType=5) AND (a.OperatorType = 1) THEN 1   
				WHEN (a.BetType = 1 AND a.OperatorType = 2) THEN 7   
				WHEN (a.BetType = 2 AND a.OperatorType = 1) THEN 3  
				WHEN (a.BetType = 2 AND a.OperatorType = 2) THEN 8  
				WHEN (a.BetType = 3 AND a.OperatorType = 1) THEN 5  
				WHEN (a.BetType = 3 AND a.OperatorType = 2) THEN 15  
				WHEN (a.BetType = 4 AND a.OperatorType = 1) THEN 2  
				WHEN (a.BetType = 4 AND a.OperatorType = 2) THEN 12            
			   ELSE 0  
			END AS BetType
		,	CASE
				WHEN LeagueName LIKE '%SPECIFIC 15 MINS TOTAL BOOKINGS%' THEN 1 	
				WHEN LeagueName LIKE '%SPECIFIC 15 MINS%' AND t.TeamName LIKE '%No.of Corners%' THEN 2  
				WHEN LeagueName LIKE '%SPECIALS' AND (t.TeamName LIKE '%Over' or t.TeamName LIKE '%Under') THEN 3  		
				WHEN LeagueName LIKE '%SPECIFIC 15 MINS%' THEN 4				 
				WHEN LeagueName LIKE '%SPECIFIC 10 MINS%' THEN 5	
				WHEN t.TeamName LIKE '%No.of Corners%' THEN 6  
				WHEN t.TeamName LIKE '%Total Bookings' THEN 7   						     
				WHEN t.TeamName LIKE '%Corner%' THEN 8
				WHEN t.TeamName LIKE '%Booking' THEN 9		  
				ELSE 0  
			END  SpecialType
		,	m.Matchcode
		FROM [bodb_archive].[dbo].[Dot_Admin_Assignment_Operator_bk] a WITH (NOLOCK)
			INNER JOIN bodb02.dbo.Match14 m WITH (NOLOCK) ON a.matchid=m.matchid
			LEFT JOIN bodb02.dbo.Team t WITH (NOLOCK) ON m.homeid=t.teamid
			LEFT JOIN bodb02.dbo.League l WITH (NOLOCK) ON m.leagueid=l.leagueid
		WHERE	m.EventDate BETWEEN @BalanceUpDay AND @MoveBetsDay
				--AND m.EventStatus='completed'
				AND m.SportType= 1
				AND a.OperatorType < 3
				AND m.MatchCode not like '%hedge%';

		IF @Debug = 1
			SELECT 'Insert #[Dot_Admin_Assignment_Operator_bk]' Step, DATEDIFF(millisecond,@Begin,GETDATE()) Duration;
		 
		INSERT INTO [dbo].[Staging_TraderPerformance]
				   ([CustId]
				   ,WorkShift
				   ,[MatchId]
				   ,[MatchCode]
				   ,[EventDate]
				   ,[SportType]           
				   ,[LeagueId]
				   ,[HomeId]
				   ,[AwayId]
				   ,[TeamId]
				   ,[Grade]
				   ,[BetType]
				   ,[Stake]
				   ,[WinLost]
				   ,[Comm]
				   ,[BetCount]
				   ,[Spread]
				   )

			SELECT	t.Custid
					,t.WorkShift
					,t.MatchId
					,t.MatchCode
					,t.EventDate 
					,t.SportType 
					,t.LeagueId 
					,t.HomeId
					,t.AwayId
					,td_T.TeamId
					,td_G.Grade
					,CASE
						WHEN b.BetType = 1 AND SpecialType = 0 THEN 1 --HDP
						WHEN b.BetType = 7 THEN 7	--1st HDP
					
						WHEN b.BetType = 3 AND SpecialType = 0 THEN 3	--O/U		
						WHEN b.BetType = 8 AND SpecialType = 0 THEN 8	--1st O/U
						WHEN b.BetType = 2  THEN 2		--O/E
						WHEN b.BetType = 12 THEN 12		--1x2
					
						WHEN b.BetType IN (5,124) AND SpecialType = 0 THEN 5		--1x2		
						WHEN b.BetType IN (5,124) AND SpecialType = 5 THEN -14		--10mins 1x2
						WHEN b.BetType IN (15,125) AND SpecialType = 0 THEN 15		--1st 1x2

						WHEN b.BetType = 1 AND SpecialType = 4 THEN -1		--15mins HDP
						WHEN b.BetType = 1 AND SpecialType = 8 THEN -2		--Next Corner
						WHEN b.BetType = 1 AND SpecialType = 5 THEN -15		--10mins HDP
						WHEN b.BetType = 1 AND SpecialType = 9 THEN -3		--Next Booking

						WHEN b.BetType IN (5,124) AND SpecialType = 4 THEN -4		--15mins 1X2

						WHEN b.BetType = 3 AND SpecialType = 4 THEN -5		--15mins O/U
						WHEN b.BetType = 3 AND SpecialType = 5 THEN -6		--10mins O/U
						WHEN b.BetType = 3 AND SpecialType = 2 THEN -7		--Corners 15mins O/U
						WHEN b.BetType = 3 AND SpecialType = 7 THEN -8		--Total Bookings
						WHEN b.BetType = 3 AND SpecialType = 1 THEN -10		--Total Bookings 15mins O/U
						WHEN b.BetType = 3 AND SpecialType = 6 THEN -13		--No. of Corner
								
						WHEN b.BetType = 8 AND SpecialType = 6 THEN -12		--1st No. of Corner
						WHEN b.BetType = 8 AND SpecialType = 7 THEN -9		--1st TotalBookings

						WHEN (b.BetType = 3 OR b.BetType = 8) AND SpecialType = 3 THEN -11	--Single Team O/U
						WHEN b.BetType IN (5,124) THEN 5	--1x2	
						WHEN b.BetType IN (15,125) THEN 15	--1st 1x2
					ELSE b.BetType END AS BetType
				
					,SUM ((CASE WHEN b.modds = 0.25 OR b.modds = -0.25 THEN ABS(b.stake)/2 ELSE ABS(b.stake) END)*(1-b.tpositiontaking)*b.virtualrate) AS Stake	--turn over
					,-SUM ((winlost - actual_stake + awinlost + mwinlost+ swinlost) * b.virtualrate) AS WinLost		--Winlost
					,SUM (scomm * b.virtualrate) AS Comm --Commission
					,SUM (1) AS BetCount		--Live BetCount
					,MAX(CASE WHEN mm.BetType IN (5,15) THEN ISNULL(s.Spread, 400/s.Margin - 4) ELSE mm.Spread END) AS Spread
			FROM	bodb02.dbo.bettrans14 b WITH (NOLOCK)
				INNER JOIN	#tmpTrader t WITH (NOLOCK)
					ON	b.winlostdate = t.EventDate 
						AND b.matchid = t.matchid 
						AND	b.LiveIndicator = 1
						AND (b.BetType = t.BetType OR (b.bettype = 124 AND t.BetType = 5) OR (b.bettype = 125 AND t.BetType = 15))
				LEFT JOIN dbo.[TraderGrade_History] td_G WITH(NOLOCK)
					ON td_G.CustID = t.custid AND t.EventDate BETWEEN td_G.BeginDate AND ISNULL(td_G.EndDate,GETDATE()+10)
				LEFT JOIN dbo.[TraderTeam_History] td_T WITH(NOLOCK)
					ON td_T.CustID = t.custid AND t.EventDate BETWEEN td_T.BeginDate AND ISNULL(td_T.EndDate,GETDATE()+10)
				LEFT JOIN bodb02.dbo.MatchMaxbet14 AS mm WITH (NOLOCK)
					ON	mm.MatchId = b.matchid
					AND	(mm.BetType = b.bettype OR (b.bettype = 124 AND mm.BetType = 5) OR (b.bettype = 125 AND mm.BetType = 15))
				LEFT JOIN @Spread1x2 s
					ON mm.Spread = s.Margin
			WHERE	b.statusID IN (112,113) 			
					AND b.Currency NOT IN (20,27,28)
			GROUP BY t.Custid
					,t.WorkShift
					,t.MatchId
					,t.MatchCode
					,t.EventDate 
					,t.SportType 
					,t.LeagueId 
					,t.HomeId
					,t.AwayId
					,td_T.TeamId
					,td_G.Grade
					,CASE
						WHEN b.BetType = 1 AND SpecialType = 0 THEN 1 --HDP
						WHEN b.BetType = 7 THEN 7	--1st HDP
					
						WHEN b.BetType = 3 AND SpecialType = 0 THEN 3	--O/U		
						WHEN b.BetType = 8 AND SpecialType = 0 THEN 8	--1st O/U
						WHEN b.BetType = 2  THEN 2		--O/E
						WHEN b.BetType = 12 THEN 12		--1x2
					
						WHEN b.BetType IN (5,124) AND SpecialType = 0 THEN 5		--1x2		
						WHEN b.BetType IN (5,124) AND SpecialType = 5 THEN -14		--10mins 1x2
						WHEN b.BetType IN (15,125) AND SpecialType = 0 THEN 15		--1st 1x2

						WHEN b.BetType = 1 AND SpecialType = 4 THEN -1		--15mins HDP
						WHEN b.BetType = 1 AND SpecialType = 8 THEN -2		--Next Corner
						WHEN b.BetType = 1 AND SpecialType = 5 THEN -15		--10mins HDP
						WHEN b.BetType = 1 AND SpecialType = 9 THEN -3		--Next Booking

						WHEN b.BetType IN (5,124) AND SpecialType = 4 THEN -4		--15mins 1X2

						WHEN b.BetType = 3 AND SpecialType = 4 THEN -5		--15mins O/U
						WHEN b.BetType = 3 AND SpecialType = 5 THEN -6		--10mins O/U
						WHEN b.BetType = 3 AND SpecialType = 2 THEN -7		--Corners 15mins O/U
						WHEN b.BetType = 3 AND SpecialType = 7 THEN -8		--Total Bookings
						WHEN b.BetType = 3 AND SpecialType = 1 THEN -10		--Total Bookings 15mins O/U
						WHEN b.BetType = 3 AND SpecialType = 6 THEN -13		--No. of Corner
								
						WHEN b.BetType = 8 AND SpecialType = 6 THEN -12		--1st No. of Corner
						WHEN b.BetType = 8 AND SpecialType = 7 THEN -9		--1st TotalBookings

						WHEN (b.BetType = 3 OR b.BetType = 8) AND SpecialType = 3 THEN -11	--Single Team O/U
						WHEN b.BetType IN (5,124) THEN 5	--1x2	
						WHEN b.BetType IN (15,125) THEN 15	--1st 1x2
					ELSE b.BetType END;

		IF @Debug = 1
			SELECT 'Insert #bettrans14' Step, DATEDIFF(millisecond,@Begin,GETDATE()) Duration;
	END;

	TRUNCATE TABLE #tmpTrader;

	INSERT INTO #tmpTrader(CustId,LeagueId,MatchId,[WorkShift],SportType,EventDate,HomeId,AwayId,BetType,SpecialType,Matchcode)
	SELECT  DISTINCT  a.OperatorID AS CustId
			,m.LeagueId
			,m.MatchId
			,CASE 
				WHEN CAST(m.kickofftime AS TIME) >= '00:00:00' AND CAST(m.kickofftime AS TIME) <'6:00:00' THEN 1--  Afternoon: 12:00:00 ~ 17:59:59 (GMT + 8)
				WHEN CAST(m.kickofftime AS TIME) >= '6:00:00' AND CAST(m.kickofftime AS TIME) <'16:00:00'THEN 2 -- Night: 18:00:00 ~ 3:59:59 (GMT + 8)				
				--WHEN CAST(m.kickofftime AS TIME) >= '16:00:00' AND CAST(m.kickofftime AS TIME) <'24:00:00'THEN 3 --  Midnight: 4:00:00 ~ 11:59:59 (GMT + 8)
				ELSE 3
			END [WorkShift]
			,m.sporttype as SportType,
			m.EventDate, m.HomeId, m.AwayId,
			CASE
					WHEN (a.BetType = 1 or a.BetType=5) AND (a.OperatorType = 1) THEN 1   
					WHEN (a.BetType = 1 AND a.OperatorType = 2) THEN 7   
					WHEN (a.BetType = 2 AND a.OperatorType = 1) THEN 3  
					WHEN (a.BetType = 2 AND a.OperatorType = 2) THEN 8  
					WHEN (a.BetType = 3 AND a.OperatorType = 1) THEN 5  
					WHEN (a.BetType = 3 AND a.OperatorType = 2) THEN 15  
					WHEN (a.BetType = 4 AND a.OperatorType = 1) THEN 2  
					WHEN (a.BetType = 4 AND a.OperatorType = 2) THEN 12            
				   ELSE 0  
				END AS BetType,  
				CASE
					WHEN LeagueName LIKE '%SPECIFIC 15 MINS TOTAL BOOKINGS%' THEN 1 	
					WHEN LeagueName LIKE '%SPECIFIC 15 MINS%' AND t.TeamName LIKE '%No.of Corners%' THEN 2  
					WHEN LeagueName LIKE '%SPECIALS' AND (t.TeamName LIKE '%Over' or t.TeamName LIKE '%Under') THEN 3  		
					WHEN LeagueName LIKE '%SPECIFIC 15 MINS%' THEN 4				 
					WHEN LeagueName LIKE '%SPECIFIC 10 MINS%' THEN 5	
					WHEN t.TeamName LIKE '%No.of Corners%' THEN 6  
					WHEN t.TeamName LIKE '%Total Bookings' THEN 7   						     
					WHEN t.TeamName LIKE '%Corner%' THEN 8
					WHEN t.TeamName LIKE '%Booking' THEN 9		  
				   ELSE 0  
				END  SpecialType,	
			m.Matchcode
	FROM bodb02.dbo.Dot_admin_Assignment_Operator a WITH (NOLOCK)
		INNER JOIN bodb02.dbo.Match m WITH (NOLOCK) ON a.matchid=m.matchid
		LEFT JOIN bodb02.dbo.Team t WITH (NOLOCK) ON m.homeid=t.teamid
		LEFT JOIN bodb02.dbo.League l WITH (NOLOCK) ON m.leagueid=l.leagueid
	WHERE	m.EventDate BETWEEN @MoveBetsDay+1 AND @Yesterday
			AND m.EventStatus='completed'
			AND m.SportType= 1
			AND a.OperatorType < 3
			AND m.MatchCode not like '%hedge%';

	IF @Debug = 1
		SELECT 'Insert #Dot_admin_Assignment_Operator' Step, DATEDIFF(millisecond,@Begin,GETDATE()) Duration;
 
	INSERT INTO [dbo].[Staging_TraderPerformance]
			   ([CustId]
			   ,[MatchId]
			   ,[WorkShift]
			   ,[MatchCode]
			   ,[EventDate]
			   ,[SportType]           
			   ,[LeagueId]
			   ,[HomeId]
			   ,[AwayId]
			   ,[TeamId]
			   ,[Grade]
			   ,[BetType]
			   ,[Stake]
			   ,[WinLost]
			   ,[Comm]
			   ,[BetCount]
			   ,[Spread]
			   )

		SELECT	t.Custid
				,t.MatchId
				,t.[WorkShift]
				,t.MatchCode
				,t.EventDate 
				,t.SportType 
				,t.LeagueId 
				,t.HomeId
				,t.AwayId
				,td_T.TeamId
				,td_G.Grade
				,CASE
						WHEN b.BetType = 1 AND SpecialType = 0 THEN 1 --HDP
						WHEN b.BetType = 7 THEN 7	--1st HDP
					
						WHEN b.BetType = 3 AND SpecialType = 0 THEN 3	--O/U		
						WHEN b.BetType = 8 AND SpecialType = 0 THEN 8	--1st O/U
						WHEN b.BetType = 2  THEN 2		--O/E
						WHEN b.BetType = 12 THEN 12		--1x2
					
						WHEN b.BetType IN (5,124) AND SpecialType = 0 THEN 5		--1x2		
						WHEN b.BetType IN (5,124) AND SpecialType = 5 THEN -14		--10mins 1x2
						WHEN b.BetType IN (15,125) AND SpecialType = 0 THEN 15		--1st 1x2

						WHEN b.BetType = 1 AND SpecialType = 4 THEN -1		--15mins HDP
						WHEN b.BetType = 1 AND SpecialType = 8 THEN -2		--Next Corner
						WHEN b.BetType = 1 AND SpecialType = 5 THEN -15		--10mins HDP
						WHEN b.BetType = 1 AND SpecialType = 9 THEN -3		--Next Booking

						WHEN b.BetType IN (5,124) AND SpecialType = 4 THEN -4		--15mins 1X2

						WHEN b.BetType = 3 AND SpecialType = 4 THEN -5		--15mins O/U
						WHEN b.BetType = 3 AND SpecialType = 5 THEN -6		--10mins O/U
						WHEN b.BetType = 3 AND SpecialType = 2 THEN -7		--Corners 15mins O/U
						WHEN b.BetType = 3 AND SpecialType = 7 THEN -8		--Total Bookings
						WHEN b.BetType = 3 AND SpecialType = 1 THEN -10		--Total Bookings 15mins O/U
						WHEN b.BetType = 3 AND SpecialType = 6 THEN -13		--No. of Corner
								
						WHEN b.BetType = 8 AND SpecialType = 6 THEN -12		--1st No. of Corner
						WHEN b.BetType = 8 AND SpecialType = 7 THEN -9		--1st TotalBookings

						WHEN (b.BetType = 3 OR b.BetType = 8) AND SpecialType = 3 THEN -11	--Single Team O/U
						WHEN b.BetType IN (5,124) THEN 5	--1x2	
						WHEN b.BetType IN (15,125) THEN 15	--1st 1x2
					ELSE b.BetType END BetType
			
				,SUM ((CASE WHEN b.modds = 0.25 OR b.modds = -0.25 THEN ABS(b.stake)/2 ELSE ABS(b.stake) END)*(1-b.tpositiontaking)*b.virtualrate) AS Stake	--turn over
				,-SUM ((winlost - actual_stake + awinlost + mwinlost+ swinlost) * b.virtualrate) AS WinLost	--Winlost
				,SUM (scomm * b.virtualrate) AS Comm--Commission
				,SUM (1) AS BetCount			--Live BetCount	
				,MAX(CASE WHEN mm.BetType IN (5,15) THEN ISNULL(s.Spread, 400/s.Margin - 4) ELSE mm.Spread END) AS Spread
		FROM	bodb02.dbo.bettrans b WITH (NOLOCK) 		
			INNER JOIN	#tmpTrader t 
				ON	b.winlostdate = t.EventDate 
					AND b.matchid = t.matchid 
					AND	b.LiveIndicator = 1
					AND (b.BetType = t.BetType OR (b.bettype = 124 AND t.BetType = 5) OR (b.bettype = 125 AND t.BetType = 15))
			LEFT JOIN dbo.[TraderGrade_History] td_G WITH(NOLOCK)
				ON td_G.CustID = t.custid 
					AND (t.EventDate BETWEEN td_G.BeginDate AND ISNULL(td_G.EndDate,GETDATE()+10))
			LEFT JOIN dbo.[TraderTeam_History] td_T WITH(NOLOCK)
				ON td_T.CustID = t.custid 
				AND (t.EventDate BETWEEN td_T.BeginDate AND ISNULL(td_T.EndDate,GETDATE()+10))
			LEFT JOIN	bodb02.dbo.MatchMaxbet AS mm WITH (NOLOCK)
					ON	mm.MatchId = b.matchid
					AND	(mm.BetType = b.bettype OR (b.bettype = 124 AND mm.BetType = 5) OR (b.bettype = 125 AND mm.BetType = 15))
			LEFT JOIN @Spread1x2 s
					ON mm.Spread = s.Margin
		WHERE	b.statusID IN (112,113) 
				AND b.ruben = 1
				AND b.Currency NOT IN (20,27,28)
		GROUP BY t.Custid
				,t.MatchId
				,t.[WorkShift]
				,t.MatchCode
				,t.EventDate
				,t.SportType
				,t.LeagueId
				,t.HomeId
				,t.AwayId
				,td_T.TeamId
				,td_G.Grade
				,CASE
						WHEN b.BetType = 1 AND SpecialType = 0 THEN 1 --HDP
						WHEN b.BetType = 7 THEN 7	--1st HDP
					
						WHEN b.BetType = 3 AND SpecialType = 0 THEN 3	--O/U		
						WHEN b.BetType = 8 AND SpecialType = 0 THEN 8	--1st O/U
						WHEN b.BetType = 2  THEN 2		--O/E
						WHEN b.BetType = 12 THEN 12		--1x2
					
						WHEN b.BetType IN (5,124) AND SpecialType = 0 THEN 5		--1x2		
						WHEN b.BetType IN (5,124) AND SpecialType = 5 THEN -14		--10mins 1x2
						WHEN b.BetType IN (15,125) AND SpecialType = 0 THEN 15		--1st 1x2

						WHEN b.BetType = 1 AND SpecialType = 4 THEN -1		--15mins HDP
						WHEN b.BetType = 1 AND SpecialType = 8 THEN -2		--Next Corner
						WHEN b.BetType = 1 AND SpecialType = 5 THEN -15		--10mins HDP
						WHEN b.BetType = 1 AND SpecialType = 9 THEN -3		--Next Booking

						WHEN b.BetType IN (5,124) AND SpecialType = 4 THEN -4		--15mins 1X2

						WHEN b.BetType = 3 AND SpecialType = 4 THEN -5		--15mins O/U
						WHEN b.BetType = 3 AND SpecialType = 5 THEN -6		--10mins O/U
						WHEN b.BetType = 3 AND SpecialType = 2 THEN -7		--Corners 15mins O/U
						WHEN b.BetType = 3 AND SpecialType = 7 THEN -8		--Total Bookings
						WHEN b.BetType = 3 AND SpecialType = 1 THEN -10		--Total Bookings 15mins O/U
						WHEN b.BetType = 3 AND SpecialType = 6 THEN -13		--No. of Corner
								
						WHEN b.BetType = 8 AND SpecialType = 6 THEN -12		--1st No. of Corner
						WHEN b.BetType = 8 AND SpecialType = 7 THEN -9		--1st TotalBookings

						WHEN (b.BetType = 3 OR b.BetType = 8) AND SpecialType = 3 THEN -11	--Single Team O/U
						WHEN b.BetType IN (5,124) THEN 5	--1x2	
						WHEN b.BetType IN (15,125) THEN 15	--1st 1x2
					ELSE b.BetType END;

	IF @Debug = 1
		SELECT 'Insert #bettrans' Step, DATEDIFF(millisecond,@Begin,GETDATE()) Duration;

	IF OBJECT_ID('tempdb..#tmpTrader') IS NOT NULL    DROP TABLE #tmpTrader;

	IF OBJECT_ID('tempdb..#tmpTraderPerformance') IS NOT NULL    DROP TABLE #tmpTraderPerformance;

	CREATE TABLE #tmpTraderPerformance(
		[CustId] [int] NULL,
		[MatchId] [int] NULL,
		[WorkShift] TinyInt NULL,
		[EventDate] [date] NULL,
		[SportType] [tinyint] NULL,
		[BetType] [smallint] NULL,
		[LeagueId] [int] NULL,
		[TeamId] [smallint] NULL,
		[Grade] [tinyint] NULL,
		[Stake] [money] NULL,
		[WinLost] [money] NULL,
		[Comm] [money] NULL,
		[BetCount] [int] NULL,
		[HomeId] [int] NULL,
		[AwayId] [int] NULL
	);  

	INSERT INTO #tmpTraderPerformance(
			[CustId]
			,[EventDate]
			,[SportType]
			,[LeagueId]
			,[TeamId]
			,[Grade]
			,[BetType]
			,[WorkShift]
			,[MatchId]		
			,[Stake]
			,[WinLost]
			,[Comm]
			,[BetCount]
			)

	SELECT [CustId]
			,[EventDate]
			,[SportType]
			,[LeagueId]
			,[TeamId]
			,[Grade]
			,[BetType]
			,[WorkShift]
			,COUNT([MatchId]) [MatchId]
			,FLOOR(SUM([Stake])) [Stake]
			,FLOOR(SUM([WinLost])) [WinLost]
			,FLOOR(SUM([Comm])) [Comm]
			,FLOOR(SUM([BetCount])) [BetCount]
	FROM  [dbo].TraderPerformance  WITH(NOLOCK)
	WHERE [EventDate] BETWEEN @BalanceUpDay AND @Yesterday
	GROUP BY [CustId]     
			,[EventDate]
			,[SportType]           
			,[LeagueId]
			,[TeamId]
			,[Grade]
			,[BetType]
			,[WorkShift];

	SET @RowCount = @@ROWCOUNT;

	IF @Debug = 1
		SELECT 'Insert #TraderPerformance' Step, DATEDIFF(millisecond,@Begin,GETDATE()) Duration,@RowCount  [RowCount];

	IF OBJECT_ID('tempdb..#tmpEventDate') IS NOT NULL    DROP TABLE #tmpEventDate;

	CREATE TABLE #tmpEventDate([EventDate] DATE);

	INSERT INTO #tmpEventDate([EventDate])
	SELECT [EventDate]
	FROM
		(
			SELECT [CustId]     
					,[EventDate]
					,[SportType]
					,[LeagueId]
					,[TeamId]
					,[Grade]
					,[BetType]
					,[WorkShift]
					,COUNT([MatchId]) [MatchId]
					,FLOOR(SUM([Stake])) [Stake]
					,FLOOR(SUM([WinLost])) [WinLost]
					,FLOOR(SUM([Comm])) [Comm]
					,FLOOR(SUM([BetCount])) [BetCount]
			FROM  [dbo].[Staging_TraderPerformance] WITH(NOLOCK)
			GROUP BY [CustId]     
					,[EventDate]
					,[SportType]           
					,[LeagueId]
					,[TeamId]
					,[Grade]
					,[BetType]
					,[WorkShift]
			EXCEPT
			SELECT [CustId]
					,[EventDate]
					,[SportType]
					,[LeagueId]
					,[TeamId]
					,[Grade]
					,[BetType]
					,[WorkShift]
					,[MatchId]
					,[Stake]
					,[WinLost]
					,[Comm]
					,[BetCount]
			FROM  #tmpTraderPerformance
		)tmp
	GROUP BY [EventDate];

	SET @RowCount = @@ROWCOUNT;

	IF @Debug = 1
		SELECT 'Insert ##tmpEventDate EXCEPT TraderPerformance' Step, DATEDIFF(millisecond,@Begin,GETDATE()) Duration,@RowCount  [RowCount];

	INSERT INTO #tmpEventDate([EventDate])
	SELECT [EventDate]
	FROM
		(
			SELECT [CustId]
					,[EventDate]
					,[SportType]
					,[LeagueId]
					,[TeamId]
					,[Grade]
					,[BetType]
					,[WorkShift]
					,[MatchId]
					,[Stake]
					,[WinLost]
					,[Comm]
					,[BetCount]
			FROM  #tmpTraderPerformance
			EXCEPT
			SELECT [CustId]     
					,[EventDate]
					,[SportType]
					,[LeagueId]
					,[TeamId]
					,[Grade]
					,[BetType]	
					,[WorkShift]			
					,COUNT([MatchId]) [MatchId]
					,FLOOR(SUM([Stake])) [Stake]
					,FLOOR(SUM([WinLost])) [WinLost]
					,FLOOR(SUM([Comm])) [Comm]
					,FLOOR(SUM([BetCount])) [BetCount]
			FROM  [dbo].[Staging_TraderPerformance] WITH(NOLOCK)
			GROUP BY [CustId]     
					,[EventDate]
					,[SportType]           
					,[LeagueId]
					,[TeamId]
					,[Grade]
					,[BetType]
					,[WorkShift]
		)tmp
	GROUP BY [EventDate];

	SET @RowCount = @@ROWCOUNT;

	IF @Debug = 1
		SELECT 'Insert ##tmpEventDate EXCEPT Staging' Step, DATEDIFF(millisecond,@Begin,GETDATE()) Duration,@RowCount  [RowCount];

	IF OBJECT_ID('tempdb..#tmpTraderPerformance') IS NOT NULL    DROP TABLE #tmpTraderPerformance;

	DELETE	FROM  [dbo].[Staging_TraderPerformance] 
	WHERE [EventDate] NOT IN(SELECT [EventDate] FROM #tmpEventDate WHERE [EventDate] IS NOT  NULL);

	SET @RowCount = @@ROWCOUNT;

	IF @Debug = 1
		SELECT 'DELETE Staging_TraderPerformance' Step, DATEDIFF(millisecond,@Begin,GETDATE()) Duration,@RowCount  [RowCount];

	IF @Debug = 1
		SELECT * FROM #tmpEventDate;
	IF OBJECT_ID('tempdb..#tmpEventDate') IS NOT NULL    DROP TABLE #tmpEventDate;

END;
GO

GRANT EXECUTE ON [dbo].[Task_StagingDataTGRS] TO [bodbTGRSNet] AS [dbo];
GO