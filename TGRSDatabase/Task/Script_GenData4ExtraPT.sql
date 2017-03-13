----------------------------------------------------------------------------------------------------------------------
-- SCRIPT TO GENERATE DATA FOR TRADERPERFORMANCE FROM *_BK
USE bodb_TGRS

DECLARE @FromDate DATE = '2017-01-01';
DECLARE @ToDate DATE = '2017-01-01';-- SHOULD BE BEFORE BALANCE-UP DATE
----------------------------------------------------------------------------------------------------------------------
-- STEP 1: STAGING DATA TO [Staging_TraderPerformance]
----------------------------------------------------------------------------------------------------------------------
DECLARE @Debug INT = 0

DECLARE @Begin DATETIME = GETDATE()
	,@RowCount INT;
DECLARE @Spread1x2 TABLE (
	Margin MONEY
	,Spread MONEY
	)

INSERT INTO @Spread1x2 (
	Margin
	,Spread
	)
VALUES (
	1.05
	,0.2
	)
	,(
	1.08
	,0.3
	)
	,(
	1.10
	,0.36
	)
	,(
	1.12
	,0.44
	)
	,(
	1.15
	,0.52
	)

IF OBJECT_ID('tempdb..#tmpTrader') IS NOT NULL
	DROP TABLE #tmpTrader;

CREATE TABLE #tmpTrader (
	CustId INT
	,LeagueId INT
	,MatchId INT
	,[WorkShift] TINYINT
	,MatchCode VARCHAR(100)
	,SportType INT
	,EventDate DATETIME
	,HomeId INT
	,AwayId INT
	,BetType SMALLINT
	,SpecialType TINYINT
	);

IF OBJECT_ID('tempdb..#tmpFilteredBettransBK') IS NOT NULL
	DROP TABLE #tmpFilteredBettransBK

CREATE TABLE #tmpFilteredBettransBK (
	transid BIGINT
	,matchid INT
	,winlostdate SMALLDATETIME
	,bettype SMALLINT
	,modds SMALLMONEY
	,stake MONEY
	,actual_stake MONEY
	,virtualrate FLOAT
	,winlost MONEY
	,awinlost MONEY	
	,mwinlost MONEY	
	,swinlost MONEY
	,tpositiontaking SMALLMONEY
	,srecommend INT
	,scomm MONEY
	,betteam VARCHAR(10)
	,livehomescore SMALLINT
	,liveawayscore SMALLINT
	,odds SMALLMONEY
	,hdp1 SMALLMONEY
	,hdp2 SMALLMONEY
	)

IF OBJECT_ID('tempdb..#tmpStagingTraderPerformance') IS NOT NULL
	DROP TABLE #tmpStagingTraderPerformance
	
CREATE TABLE #tmpStagingTraderPerformance (
	CustId INT
	,[WorkShift] TINYINT
	,MatchId INT
	,MatchCode VARCHAR(100)
	,EventDate DATETIME
	,SportType INT
	,LeagueId INT
	,HomeId INT
	,AwayId INT
	,[TeamId] INT
	,Grade TINYINT
	,BetType SMALLINT
	,Stake MONEY
	,WinLost MONEY
	,SMAWinLost MONEY
	,Comm MONEY
	,BetCount INT
	,Spread MONEY
	,ExtraPT DECIMAL(9, 8)
	,TPositionTaking SMALLMONEY
	,VirtualRate FLOAT
	)
TRUNCATE TABLE dbo.[Staging_TraderPerformance]

TRUNCATE TABLE #tmpTrader

TRUNCATE TABLE #tmpStagingTraderPerformance

INSERT INTO #tmpTrader (
	CustId
	,LeagueId
	,MatchId
	,[WorkShift]
	,SportType
	,EventDate
	,HomeId
	,AwayId
	,BetType
	,SpecialType
	,Matchcode
	)
SELECT DISTINCT a.OperatorID AS CustId
	,m.LeagueId
	,m.MatchId
	,CASE 
		WHEN CAST(m.kickofftime AS TIME) >= '00:00:00'
			AND CAST(m.kickofftime AS TIME) < '6:00:00'
			THEN 1 --  Afternoon: 12:00:00 ~ 17:59:59 (GMT + 8)
		WHEN CAST(m.kickofftime AS TIME) >= '6:00:00'
			AND CAST(m.kickofftime AS TIME) < '16:00:00'
			THEN 2 -- Night: 18:00:00 ~ 3:59:59 (GMT + 8)				
				--WHEN CAST(m.kickofftime AS TIME) >= '16:00:00' AND CAST(m.kickofftime AS TIME) <'24:00:00'THEN 3 --  Midnight: 4:00:00 ~ 11:59:59 (GMT + 8)
		ELSE 3
		END [WorkShift]
	,m.sporttype AS SportType
	,m.EventDate
	,m.HomeId
	,m.AwayId
	,CASE 
		WHEN (
				a.BetType = 1
				OR a.BetType = 5
				)
			AND (a.OperatorType = 1)
			THEN 1
		WHEN (
				a.BetType = 1
				AND a.OperatorType = 2
				)
			THEN 7
		WHEN (
				a.BetType = 2
				AND a.OperatorType = 1
				)
			THEN 3
		WHEN (
				a.BetType = 2
				AND a.OperatorType = 2
				)
			THEN 8
		WHEN (
				a.BetType = 3
				AND a.OperatorType = 1
				)
			THEN 5
		WHEN (
				a.BetType = 3
				AND a.OperatorType = 2
				)
			THEN 15
		WHEN (
				a.BetType = 4
				AND a.OperatorType = 1
				)
			THEN 2
		WHEN (
				a.BetType = 4
				AND a.OperatorType = 2
				)
			THEN 12
		ELSE 0
		END AS BetType
	,CASE 
		WHEN LeagueName LIKE '%SPECIFIC 15 MINS TOTAL BOOKINGS%'
			THEN 1
		WHEN LeagueName LIKE '%SPECIFIC 15 MINS%'
			AND t.TeamName LIKE '%No.of Corners%'
			THEN 2
		WHEN LeagueName LIKE '%SPECIALS'
			AND (
				t.TeamName LIKE '%Over'
				OR t.TeamName LIKE '%Under'
				)
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
		END SpecialType
	,m.Matchcode
FROM [bodb_archive].[dbo].[Dot_Admin_Assignment_Operator_bk] a WITH (NOLOCK)
INNER JOIN [bodb_archive].[dbo].Match_bk m WITH (NOLOCK) ON a.matchid = m.matchid
LEFT JOIN bodb02.dbo.Team t WITH (NOLOCK) ON m.homeid = t.teamid
LEFT JOIN bodb02.dbo.League l WITH (NOLOCK) ON m.leagueid = l.leagueid
WHERE m.EventDate BETWEEN @FromDate
		AND @ToDate
	AND m.EventStatus = 'completed'
	AND m.SportType = 1
	AND a.OperatorType < 3
	AND m.MatchCode NOT LIKE '%hedge%'

IF @Debug = 1
	SELECT 'Insert #Dot_admin_Assignment_Operator' Step
		,DATEDIFF(millisecond, @Begin, GETDATE()) Duration
		
-- Filter bettrans_bk at first
INSERT INTO #tmpFilteredBettransBK (
	transid
	,matchid
	,winlostdate
	,bettype
	,modds
	,stake
	,actual_stake
	,virtualrate
	,winlost
	,awinlost	
	,mwinlost	
	,swinlost
	,tpositiontaking
	,srecommend
	,scomm
	,betteam
	,livehomescore
	,liveawayscore
	,odds
	,hdp1
	,hdp2
	)
SELECT 
	b.transid
	,b.matchid
	,b.winlostdate
	,b.bettype
	,b.modds
	,b.stake
	,b.actual_stake
	,b.virtualrate
	,b.winlost
	,b.awinlost	
	,b.mwinlost	
	,b.swinlost
	,b.tpositiontaking
	,b.srecommend
	,b.scomm
	,b.betteam
	,b.livehomescore
	,b.liveawayscore
	,b.odds
	,hdp1
	,hdp2
FROM [bodb_archive].[dbo].bettrans_bk b WITH (NOLOCK)
WHERE b.winlostdate BETWEEN @FromDate
		AND @ToDate
	AND b.statusID IN (
		112
		,113
		)
	AND b.Currency NOT IN (
		20
		,27
		,28
		)
	AND b.LiveIndicator = 1
----

INSERT INTO #tmpStagingTraderPerformance (
	[CustId]
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
	,[SMAWinLost]
	,[Comm]
	,[BetCount]
	,[Spread]
	,[ExtraPT]
	,[TPositionTaking]
	,[VirtualRate]
	)
SELECT t.Custid
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
		WHEN b.BetType = 1
			AND SpecialType = 0
			THEN 1 --HDP
		WHEN b.BetType = 7
			THEN 7 --1st HDP
		WHEN b.BetType = 3
			AND SpecialType = 0
			THEN 3 --O/U		
		WHEN b.BetType = 8
			AND SpecialType = 0
			THEN 8 --1st O/U
		WHEN b.BetType = 2
			THEN 2 --O/E
		WHEN b.BetType = 12
			THEN 12 --1x2
		WHEN b.BetType IN (
				5
				,124
				)
			AND SpecialType = 0
			THEN 5 --1x2		
		WHEN b.BetType IN (
				5
				,124
				)
			AND SpecialType = 5
			THEN - 14 --10mins 1x2
		WHEN b.BetType IN (
				15
				,125
				)
			AND SpecialType = 0
			THEN 15 --1st 1x2
		WHEN b.BetType = 1
			AND SpecialType = 4
			THEN - 1 --15mins HDP
		WHEN b.BetType = 1
			AND SpecialType = 8
			THEN - 2 --Next Corner
		WHEN b.BetType = 1
			AND SpecialType = 5
			THEN - 15 --10mins HDP
		WHEN b.BetType = 1
			AND SpecialType = 9
			THEN - 3 --Next Booking
		WHEN b.BetType IN (
				5
				,124
				)
			AND SpecialType = 4
			THEN - 4 --15mins 1X2
		WHEN b.BetType = 3
			AND SpecialType = 4
			THEN - 5 --15mins O/U
		WHEN b.BetType = 3
			AND SpecialType = 5
			THEN - 6 --10mins O/U
		WHEN b.BetType = 3
			AND SpecialType = 2
			THEN - 7 --Corners 15mins O/U
		WHEN b.BetType = 3
			AND SpecialType = 7
			THEN - 8 --Total Bookings
		WHEN b.BetType = 3
			AND SpecialType = 1
			THEN - 10 --Total Bookings 15mins O/U
		WHEN b.BetType = 3
			AND SpecialType = 6
			THEN - 13 --No. of Corner
		WHEN b.BetType = 8
			AND SpecialType = 6
			THEN - 12 --1st No. of Corner
		WHEN b.BetType = 8
			AND SpecialType = 7
			THEN - 9 --1st TotalBookings
		WHEN (
				b.BetType = 3
				OR b.BetType = 8
				)
			AND SpecialType = 3
			THEN - 11 --Single Team O/U
		WHEN b.BetType IN (
				5
				,124
				)
			THEN 5 --1x2	
		WHEN b.BetType IN (
				15
				,125
				)
			THEN 15 --1st 1x2
		ELSE b.BetType
		END AS BetType
	,(
		(
			CASE 
				WHEN b.modds = 0.25
					OR b.modds = - 0.25
					THEN ABS(b.stake) / 2
				ELSE ABS(b.stake)
				END
			) * b.virtualrate
		) AS Stake --turn over
	,(winlost - actual_stake) AS WinLost --Winlost
	,(awinlost + mwinlost + swinlost) AS SMAWinLost --SMAWinlost
	,b.scomm AS Comm --Commission
	,1 AS BetCount --Live BetCount
	,(
		CASE 
			WHEN mm.BetType IN (
					5
					,15
					)
				THEN ISNULL(s.Spread, - (4 / mm.Spread - 4))
			ELSE mm.Spread
			END
		) AS Spread
	,SUM(ISNULL(es.ExtraPT, 0)) AS ExtraPT
	,b.tpositiontaking
	,b.virtualrate
FROM #tmpFilteredBettransBK b
INNER JOIN #tmpTrader t WITH (NOLOCK) ON b.winlostdate = t.EventDate
	AND b.matchid = t.matchid
	AND (
		b.BetType = t.BetType
		OR (
			b.bettype = 124
			AND t.BetType = 5
			)
		OR (
			b.bettype = 125
			AND t.BetType = 15
			)
		)
LEFT JOIN dbo.[TraderGrade_History] td_G WITH (NOLOCK) ON td_G.CustID = t.custid
	AND t.EventDate BETWEEN td_G.BeginDate
		AND ISNULL(td_G.EndDate, GETDATE() + 10)
LEFT JOIN dbo.[TraderTeam_History] td_T WITH (NOLOCK) ON td_T.CustID = t.custid
	AND t.EventDate BETWEEN td_T.BeginDate
		AND ISNULL(td_T.EndDate, GETDATE() + 10)
LEFT JOIN [bodb_archive].[dbo].MatchMaxbet_bk AS mm WITH (NOLOCK) ON mm.MatchId = b.matchid
	AND (
		mm.BetType = b.bettype
		OR (
			b.bettype = 124
			AND mm.BetType = 5
			)
		OR (
			b.bettype = 125
			AND mm.BetType = 15
			)
		)
LEFT JOIN @Spread1x2 s ON mm.Spread = s.Margin
	AND mm.BetType IN (
		5
		,15
		)
LEFT JOIN [bodb_ACC].[dbo].[Acc_GroupExtraPTSetting] es WITH (NOLOCK) ON es.SuperId = b.srecommend
	AND es.ProductId = 1
	AND es.Sporttype = 0
	AND es.SubProduct = ''
	AND t.EventDate BETWEEN es.FromDate
		AND es.ToDate
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
		WHEN b.BetType = 1
			AND SpecialType = 0
			THEN 1 --HDP
		WHEN b.BetType = 7
			THEN 7 --1st HDP
		WHEN b.BetType = 3
			AND SpecialType = 0
			THEN 3 --O/U		
		WHEN b.BetType = 8
			AND SpecialType = 0
			THEN 8 --1st O/U
		WHEN b.BetType = 2
			THEN 2 --O/E
		WHEN b.BetType = 12
			THEN 12 --1x2
		WHEN b.BetType IN (
				5
				,124
				)
			AND SpecialType = 0
			THEN 5 --1x2		
		WHEN b.BetType IN (
				5
				,124
				)
			AND SpecialType = 5
			THEN - 14 --10mins 1x2
		WHEN b.BetType IN (
				15
				,125
				)
			AND SpecialType = 0
			THEN 15 --1st 1x2
		WHEN b.BetType = 1
			AND SpecialType = 4
			THEN - 1 --15mins HDP
		WHEN b.BetType = 1
			AND SpecialType = 8
			THEN - 2 --Next Corner
		WHEN b.BetType = 1
			AND SpecialType = 5
			THEN - 15 --10mins HDP
		WHEN b.BetType = 1
			AND SpecialType = 9
			THEN - 3 --Next Booking
		WHEN b.BetType IN (
				5
				,124
				)
			AND SpecialType = 4
			THEN - 4 --15mins 1X2
		WHEN b.BetType = 3
			AND SpecialType = 4
			THEN - 5 --15mins O/U
		WHEN b.BetType = 3
			AND SpecialType = 5
			THEN - 6 --10mins O/U
		WHEN b.BetType = 3
			AND SpecialType = 2
			THEN - 7 --Corners 15mins O/U
		WHEN b.BetType = 3
			AND SpecialType = 7
			THEN - 8 --Total Bookings
		WHEN b.BetType = 3
			AND SpecialType = 1
			THEN - 10 --Total Bookings 15mins O/U
		WHEN b.BetType = 3
			AND SpecialType = 6
			THEN - 13 --No. of Corner
		WHEN b.BetType = 8
			AND SpecialType = 6
			THEN - 12 --1st No. of Corner
		WHEN b.BetType = 8
			AND SpecialType = 7
			THEN - 9 --1st TotalBookings
		WHEN (
				b.BetType = 3
				OR b.BetType = 8
				)
			AND SpecialType = 3
			THEN - 11 --Single Team O/U
		WHEN b.BetType IN (
				5
				,124
				)
			THEN 5 --1x2	
		WHEN b.BetType IN (
				15
				,125
				)
			THEN 15 --1st 1x2
		ELSE b.BetType
		END
	,(
		(
			CASE 
				WHEN b.modds = 0.25
					OR b.modds = - 0.25
					THEN ABS(b.stake) / 2
				ELSE ABS(b.stake)
				END
			) * b.virtualrate
		)
	
	,(winlost - actual_stake)
	,(awinlost + mwinlost + swinlost)
	,b.scomm
	,(
		CASE 
			WHEN mm.BetType IN (
					5
					,15
					)
				THEN ISNULL(s.Spread, - (4 / mm.Spread - 4))
			ELSE mm.Spread
			END
		)
	,b.tpositiontaking
	,b.virtualrate
	,b.transid

INSERT INTO dbo.[Staging_TraderPerformance] (
	[CustId]
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
SELECT t.[CustId]
	,t.[WorkShift]
	,t.[MatchId]
	,t.[MatchCode]
	,t.[EventDate]
	,t.[SportType]
	,t.[LeagueId]
	,t.[HomeId]
	,t.[AwayId]
	,t.[TeamId]
	,t.[Grade]
	,t.[BetType]
	,SUM(t.Stake * (1 - t.TPositionTaking - t.ExtraPT)) AS [Stake]
	,SUM(((-(t.WinLost + t.SMAWinLost)) + t.WinLost * t.ExtraPT) * t.virtualrate) AS [WinLost]
	,SUM((Comm - (CASE WHEN t.TPositionTaking = 1 THEN 0 ELSE (Comm * t.ExtraPT/(1 - t.TPositionTaking)) END)) * t.virtualrate) AS [Comm]
	,SUM(t.[BetCount])
	,MAX(t.[Spread])
FROM #tmpStagingTraderPerformance t
GROUP BY t.[CustId]
	,t.[WorkShift]
	,t.[MatchId]
	,t.[MatchCode]
	,t.[EventDate]
	,t.[SportType]
	,t.[LeagueId]
	,t.[HomeId]
	,t.[AwayId]
	,t.[TeamId]
	,t.[Grade]
	,t.[BetType]

IF @Debug = 1
	SELECT 'Insert #bettrans' Step
		,DATEDIFF(millisecond, @Begin, GETDATE()) Duration

IF OBJECT_ID('tempdb..#tmpTrader') IS NOT NULL
	DROP TABLE #tmpTrader

IF OBJECT_ID('tempdb..#tmpTraderPerformance') IS NOT NULL
	DROP TABLE #tmpTraderPerformance

CREATE TABLE #tmpTraderPerformance (
	[CustId] [int] NULL
	,[MatchId] [int] NULL
	,[WorkShift] TINYINT NULL
	,[EventDate] [date] NULL
	,[SportType] [tinyint] NULL
	,[BetType] [smallint] NULL
	,[LeagueId] [int] NULL
	,[TeamId] [smallint] NULL
	,[Grade] [tinyint] NULL
	,[Stake] [money] NULL
	,[WinLost] [money] NULL
	,[Comm] [money] NULL
	,[BetCount] [int] NULL
	,[HomeId] [int] NULL
	,[AwayId] [int] NULL
	)

INSERT INTO #tmpTraderPerformance (
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
FROM [dbo].TraderPerformance WITH (NOLOCK)
WHERE [EventDate] BETWEEN @FromDate
		AND @ToDate
GROUP BY [CustId]
	,[EventDate]
	,[SportType]
	,[LeagueId]
	,[TeamId]
	,[Grade]
	,[BetType]
	,[WorkShift]

SET @RowCount = @@ROWCOUNT

IF @Debug = 1
	SELECT 'Insert #TraderPerformance' Step
		,DATEDIFF(millisecond, @Begin, GETDATE()) Duration
		,@RowCount [RowCount]

IF OBJECT_ID('tempdb..#tmpEventDate') IS NOT NULL
	DROP TABLE #tmpEventDate

CREATE TABLE #tmpEventDate ([EventDate] DATE)

INSERT INTO #tmpEventDate ([EventDate])
SELECT [EventDate]
FROM (
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
	FROM [dbo].[Staging_TraderPerformance] WITH (NOLOCK)
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
	FROM #tmpTraderPerformance
	) tmp
GROUP BY [EventDate]

SET @RowCount = @@ROWCOUNT

IF @Debug = 1
	SELECT 'Insert ##tmpEventDate EXCEPT TraderPerformance' Step
		,DATEDIFF(millisecond, @Begin, GETDATE()) Duration
		,@RowCount [RowCount]

INSERT INTO #tmpEventDate ([EventDate])
SELECT [EventDate]
FROM (
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
	FROM #tmpTraderPerformance
	
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
	FROM [dbo].[Staging_TraderPerformance] WITH (NOLOCK)
	GROUP BY [CustId]
		,[EventDate]
		,[SportType]
		,[LeagueId]
		,[TeamId]
		,[Grade]
		,[BetType]
		,[WorkShift]
	) tmp
GROUP BY [EventDate]

SET @RowCount = @@ROWCOUNT

IF @Debug = 1
	SELECT 'Insert ##tmpEventDate EXCEPT Staging' Step
		,DATEDIFF(millisecond, @Begin, GETDATE()) Duration
		,@RowCount [RowCount]

IF OBJECT_ID('tempdb..#tmpTraderPerformance') IS NOT NULL
	DROP TABLE #tmpTraderPerformance

DELETE
FROM [dbo].[Staging_TraderPerformance]
WHERE [EventDate] NOT IN (
		SELECT [EventDate]
		FROM #tmpEventDate
		WHERE [EventDate] IS NOT NULL
		)

SET @RowCount = @@ROWCOUNT

IF @Debug = 1
	SELECT 'DELETE Staging_TraderPerformance' Step
		,DATEDIFF(millisecond, @Begin, GETDATE()) Duration
		,@RowCount [RowCount]

IF @Debug = 1
	SELECT *
	FROM #tmpEventDate

IF OBJECT_ID('tempdb..#tmpEventDate') IS NOT NULL
	DROP TABLE #tmpEventDate

----------------------------------------------------------------------------------------------------------------------
-- STEP 2: SUM DAILY FROM [Staging_TraderPerformance] to [TraderPerformance]
----------------------------------------------------------------------------------------------------------------------
DELETE [bodb_TGRS].[dbo].[TraderPerformance] WHERE EventDate BETWEEN @FromDate AND @ToDate;

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
FROM [dbo].[Staging_TraderPerformance] WITH(NOLOCK)
WHERE EventDate BETWEEN @FromDate AND @ToDate;

DELETE [dbo].[SummaryByBetType_Daily] WHERE EventDate BETWEEN @FromDate AND @ToDate;

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
SELECT [EventDate]
	  ,[LeagueId]
	  ,[BetType]
	   ,[WorkShift]
	  ,SUM([Stake]) [Stake]
	  ,SUM([WinLost]) [WinLost]
	  ,SUM([Comm]) [Comm]
	  ,SUM([BetCount]) BetCount
	  ,COUNT(DISTINCT [MatchId])[MatchCount]
FROM [dbo].[Staging_TraderPerformance] WITH(NOLOCK)
WHERE EventDate BETWEEN @FromDate AND @ToDate
GROUP BY [EventDate]
	  ,[LeagueId]
	  ,[BetType]
	  ,[WorkShift];

DELETE [dbo].[SummaryByLeague_Daily] WHERE EventDate BETWEEN @FromDate AND @ToDate;

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
SELECT [EventDate]
	  ,[LeagueId]
	   ,[WorkShift]
	  ,SUM([Stake]) [Stake]
	  ,SUM([WinLost]) [WinLost]
	  ,SUM([Comm]) [Comm]
	  ,SUM([BetCount]) BetCount
	  ,COUNT(DISTINCT [MatchId])[MatchCount]
FROM [dbo].[Staging_TraderPerformance] WITH(NOLOCK)
WHERE EventDate BETWEEN @FromDate AND @ToDate
GROUP BY [EventDate]
	  ,[LeagueId]
	   ,[WorkShift];

DELETE [dbo].[SummaryByTeam_Daily]	WHERE EventDate BETWEEN @FromDate AND @ToDate;

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
SELECT [EventDate]
	  ,[TeamId]
	   ,[WorkShift]
	  ,SUM([Stake]) [Stake]
	  ,SUM([WinLost]) [WinLost]
	  ,SUM([Comm]) [Comm]
	  ,SUM([BetCount]) BetCount
	  ,COUNT(DISTINCT [MatchId])[MatchCount]
FROM [dbo].[Staging_TraderPerformance] WITH(NOLOCK)
WHERE EventDate  BETWEEN @FromDate AND @ToDate
GROUP BY [EventDate]
	  ,[TeamId]
	   ,[WorkShift];
	  
----------------------------------------------------------------------------------------------------------------------
-- STEP 3: Sum Monthly from [TraderPerformance] for Jan 2017
----------------------------------------------------------------------------------------------------------------------
DECLARE @Month DATE = '2017-1-1'
DECLARE @StartDate DATE, @EndDate DATE
SELECT @StartDate = DATEADD(DD, -DAY(@Month) + 1, @Month)
SELECT @EndDate = DATEADD(DD, -1, DATEADD(MM, 1, @StartDate))
SELECT @Month = @StartDate

DELETE [dbo].[SummaryByTrader_Monthly] WHERE EventDate = @Month

INSERT INTO [dbo].[SummaryByTrader_Monthly](
	[Eventdate]
	  ,[CustId]
	   ,[WorkShift]
	  ,[Stake]
	  ,[WinLost]
	  ,[Comm]
	  ,[BetCount]
	  ,[MatchCount]
	  )
SELECT @Month [Eventdate]
	  ,[CustId]
	   ,[WorkShift]
	  ,SUM([Stake]) [Stake]
	  ,SUM([WinLost]) [WinLost]
	  ,SUM([Comm]) [Comm]
	  ,SUM([BetCount]) [BetCount]
	  ,COUNT(DISTINCT [MatchId])[MatchCount]
FROM [dbo].[TraderPerformance] WITH(NOLOCK)
WHERE EventDate BETWEEN @StartDate AND @EndDate
GROUP BY [CustId]
	   ,[WorkShift]

DELETE [dbo].[SummaryByBetType_Monthly]	WHERE EventDate = @Month

INSERT INTO [dbo].[SummaryByBetType_Monthly]
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
SELECT @Month [EventDate]
	  ,[LeagueId]
	  ,[BetType]
	   ,[WorkShift]
	  ,SUM([Stake]) [Stake]
	  ,SUM([WinLost]) [WinLost]
	  ,SUM([Comm]) [Comm]
	  ,SUM([BetCount]) BetCount
	  ,COUNT(DISTINCT [MatchId])[MatchCount]
FROM [dbo].[TraderPerformance] WITH(NOLOCK)
WHERE EventDate BETWEEN @StartDate AND @EndDate
GROUP BY [LeagueId]
	,[BetType]
	   ,[WorkShift]

DELETE [dbo].SummaryByLeague_Monthly	WHERE EventDate = @Month

INSERT INTO [dbo].SummaryByLeague_Monthly
	([EventDate]
	  ,[LeagueId]
	   ,[WorkShift]
	  ,[Stake]
	  ,[WinLost]
	  ,[Comm]
	  ,[BetCount]
	  ,[MatchCount]
	)
SELECT @Month [EventDate]
	  ,[LeagueId]
	   ,[WorkShift]
	  ,SUM([Stake]) [Stake]
	  ,SUM([WinLost]) [WinLost]
	  ,SUM([Comm]) [Comm]
	  ,SUM([BetCount]) BetCount
	  ,COUNT(DISTINCT [MatchId])[MatchCount]
FROM [dbo].[TraderPerformance] WITH(NOLOCK)
WHERE EventDate BETWEEN @StartDate AND @EndDate
GROUP BY [LeagueId]
	   ,[WorkShift]

DELETE [dbo].SummaryByTeam_Monthly	WHERE EventDate = @Month

INSERT INTO [dbo].SummaryByTeam_Monthly
	([EventDate]
	  ,[TeamId]
	   ,[WorkShift]
	  ,[Stake]
	  ,[WinLost]
	  ,[Comm]
	  ,[BetCount]
	  ,[MatchCount]
	)
SELECT @Month [EventDate]
	  ,[TeamId]
	   ,[WorkShift]
	  ,SUM([Stake]) [Stake]
	  ,SUM([WinLost]) [WinLost]
	  ,SUM([Comm]) [Comm]
	  ,SUM([BetCount]) BetCount
	  ,COUNT(DISTINCT [MatchId])[MatchCount]
FROM [dbo].[TraderPerformance] WITH(NOLOCK)
WHERE EventDate BETWEEN @StartDate AND @EndDate
GROUP BY [TeamId]
	   ,[WorkShift]
	   
----------------------------------------------------------------------------------------------------------------------
-- STEP 4: Sum Monthly from [TraderPerformance] for Feb 2017
----------------------------------------------------------------------------------------------------------------------
SET @Month = '2017-2-2'
SET @StartDate = DATEADD(DD, -DAY(@Month) + 1, @Month)
SET @EndDate = DATEADD(DD, -1, DATEADD(MM, 1, @StartDate))
SET @Month = @StartDate

DELETE [dbo].[SummaryByTrader_Monthly] WHERE EventDate = @Month

INSERT INTO [dbo].[SummaryByTrader_Monthly](
	[Eventdate]
	  ,[CustId]
	   ,[WorkShift]
	  ,[Stake]
	  ,[WinLost]
	  ,[Comm]
	  ,[BetCount]
	  ,[MatchCount]
	  )
SELECT @Month [Eventdate]
	  ,[CustId]
	   ,[WorkShift]
	  ,SUM([Stake]) [Stake]
	  ,SUM([WinLost]) [WinLost]
	  ,SUM([Comm]) [Comm]
	  ,SUM([BetCount]) [BetCount]
	  ,COUNT(DISTINCT [MatchId])[MatchCount]
FROM [dbo].[TraderPerformance] WITH(NOLOCK)
WHERE EventDate BETWEEN @StartDate AND @EndDate
GROUP BY [CustId]
	   ,[WorkShift]

DELETE [dbo].[SummaryByBetType_Monthly]	WHERE EventDate = @Month

INSERT INTO [dbo].[SummaryByBetType_Monthly]
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
SELECT @Month [EventDate]
	  ,[LeagueId]
	  ,[BetType]
	   ,[WorkShift]
	  ,SUM([Stake]) [Stake]
	  ,SUM([WinLost]) [WinLost]
	  ,SUM([Comm]) [Comm]
	  ,SUM([BetCount]) BetCount
	  ,COUNT(DISTINCT [MatchId])[MatchCount]
FROM [dbo].[TraderPerformance] WITH(NOLOCK)
WHERE EventDate BETWEEN @StartDate AND @EndDate
GROUP BY [LeagueId]
	,[BetType]
	   ,[WorkShift]

DELETE [dbo].SummaryByLeague_Monthly	WHERE EventDate = @Month

INSERT INTO [dbo].SummaryByLeague_Monthly
	([EventDate]
	  ,[LeagueId]
	   ,[WorkShift]
	  ,[Stake]
	  ,[WinLost]
	  ,[Comm]
	  ,[BetCount]
	  ,[MatchCount]
	)
SELECT @Month [EventDate]
	  ,[LeagueId]
	   ,[WorkShift]
	  ,SUM([Stake]) [Stake]
	  ,SUM([WinLost]) [WinLost]
	  ,SUM([Comm]) [Comm]
	  ,SUM([BetCount]) BetCount
	  ,COUNT(DISTINCT [MatchId])[MatchCount]
FROM [dbo].[TraderPerformance] WITH(NOLOCK)
WHERE EventDate BETWEEN @StartDate AND @EndDate
GROUP BY [LeagueId]
	   ,[WorkShift]

DELETE [dbo].SummaryByTeam_Monthly	WHERE EventDate = @Month

INSERT INTO [dbo].SummaryByTeam_Monthly
	([EventDate]
	  ,[TeamId]
	   ,[WorkShift]
	  ,[Stake]
	  ,[WinLost]
	  ,[Comm]
	  ,[BetCount]
	  ,[MatchCount]
	)
SELECT @Month [EventDate]
	  ,[TeamId]
	   ,[WorkShift]
	  ,SUM([Stake]) [Stake]
	  ,SUM([WinLost]) [WinLost]
	  ,SUM([Comm]) [Comm]
	  ,SUM([BetCount]) BetCount
	  ,COUNT(DISTINCT [MatchId])[MatchCount]
FROM [dbo].[TraderPerformance] WITH(NOLOCK)
WHERE EventDate BETWEEN @StartDate AND @EndDate
GROUP BY [TeamId]
	   ,[WorkShift]

----------------------------------------------------------------------------------------------------------------------
-- STEP 5: Sum Monthly from [TraderPerformance] for Mar 2017
----------------------------------------------------------------------------------------------------------------------
SET @Month = '2017-3-3'
SET @StartDate = DATEADD(DD, -DAY(@Month) + 1, @Month)
SET @EndDate = DATEADD(DD, -1, DATEADD(MM, 1, @StartDate))
SET @Month = @StartDate

DELETE [dbo].[SummaryByTrader_Monthly] WHERE EventDate = @Month

INSERT INTO [dbo].[SummaryByTrader_Monthly](
	[Eventdate]
	  ,[CustId]
	   ,[WorkShift]
	  ,[Stake]
	  ,[WinLost]
	  ,[Comm]
	  ,[BetCount]
	  ,[MatchCount]
	  )
SELECT @Month [Eventdate]
	  ,[CustId]
	   ,[WorkShift]
	  ,SUM([Stake]) [Stake]
	  ,SUM([WinLost]) [WinLost]
	  ,SUM([Comm]) [Comm]
	  ,SUM([BetCount]) [BetCount]
	  ,COUNT(DISTINCT [MatchId])[MatchCount]
FROM [dbo].[TraderPerformance] WITH(NOLOCK)
WHERE EventDate BETWEEN @StartDate AND @EndDate
GROUP BY [CustId]
	   ,[WorkShift]

DELETE [dbo].[SummaryByBetType_Monthly]	WHERE EventDate = @Month

INSERT INTO [dbo].[SummaryByBetType_Monthly]
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
SELECT @Month [EventDate]
	  ,[LeagueId]
	  ,[BetType]
	   ,[WorkShift]
	  ,SUM([Stake]) [Stake]
	  ,SUM([WinLost]) [WinLost]
	  ,SUM([Comm]) [Comm]
	  ,SUM([BetCount]) BetCount
	  ,COUNT(DISTINCT [MatchId])[MatchCount]
FROM [dbo].[TraderPerformance] WITH(NOLOCK)
WHERE EventDate BETWEEN @StartDate AND @EndDate
GROUP BY [LeagueId]
	,[BetType]
	   ,[WorkShift]

DELETE [dbo].SummaryByLeague_Monthly	WHERE EventDate = @Month

INSERT INTO [dbo].SummaryByLeague_Monthly
	([EventDate]
	  ,[LeagueId]
	   ,[WorkShift]
	  ,[Stake]
	  ,[WinLost]
	  ,[Comm]
	  ,[BetCount]
	  ,[MatchCount]
	)
SELECT @Month [EventDate]
	  ,[LeagueId]
	   ,[WorkShift]
	  ,SUM([Stake]) [Stake]
	  ,SUM([WinLost]) [WinLost]
	  ,SUM([Comm]) [Comm]
	  ,SUM([BetCount]) BetCount
	  ,COUNT(DISTINCT [MatchId])[MatchCount]
FROM [dbo].[TraderPerformance] WITH(NOLOCK)
WHERE EventDate BETWEEN @StartDate AND @EndDate
GROUP BY [LeagueId]
	   ,[WorkShift]

DELETE [dbo].SummaryByTeam_Monthly	WHERE EventDate = @Month

INSERT INTO [dbo].SummaryByTeam_Monthly
	([EventDate]
	  ,[TeamId]
	   ,[WorkShift]
	  ,[Stake]
	  ,[WinLost]
	  ,[Comm]
	  ,[BetCount]
	  ,[MatchCount]
	)
SELECT @Month [EventDate]
	  ,[TeamId]
	   ,[WorkShift]
	  ,SUM([Stake]) [Stake]
	  ,SUM([WinLost]) [WinLost]
	  ,SUM([Comm]) [Comm]
	  ,SUM([BetCount]) BetCount
	  ,COUNT(DISTINCT [MatchId])[MatchCount]
FROM [dbo].[TraderPerformance] WITH(NOLOCK)
WHERE EventDate BETWEEN @StartDate AND @EndDate
GROUP BY [TeamId]
	   ,[WorkShift]

----------------------------------------------------------------------------------------------------------------------
-- STEP 6: Staging Juice
----------------------------------------------------------------------------------------------------------------------
IF OBJECT_ID('tempdb..#tmpDataGroup') IS NOT NULL
	DROP TABLE #tmpDataGroup;

CREATE TABLE #tmpDataGroup (
	CustId INT
	,EventDate DATE
	,MatchId INT
	,BetType SMALLINT
	,BetTeam VARCHAR(10)
	,ScoreHDP SMALLMONEY
	,AVGOdds FLOAT
	,StakeMY MONEY
	,Stake MONEY
	);
	
IF OBJECT_ID('tempdb..#tmpStagingTraderPerformance1') IS NOT NULL
	DROP TABLE #tmpStagingTraderPerformance1

CREATE TABLE #tmpStagingTraderPerformance1 (
	CustId INT
	,EventDate DATE
	,MatchId INT
	,BetType SMALLINT
	,BetTeam VARCHAR(10)
	,ScoreHDP SMALLMONEY
	,Odds FLOAT
	,StakeOrigin MONEY
	,StakeMY MONEY
	,Stake MONEY
	,ExtraPT DECIMAL(9, 8)
	,TPositionTaking SMALLMONEY
	,VirtualRate FLOAT
	)

IF OBJECT_ID('tempdb..#tmpTrader1') IS NOT NULL
	DROP TABLE #tmpTrader1;

CREATE TABLE #tmpTrader1 (
	CustId INT
	,MatchId INT
	,EventDate DATETIME
	,BetType SMALLINT
	,SpecialType TINYINT
	,SportType INT
	,SubProduct VARCHAR(500)
	);

CREATE INDEX #IDX_tmpTrader ON #tmpTrader1 (
	EventDate
	,MatchId
	,BetType
	)

TRUNCATE TABLE #tmpTrader1;

TRUNCATE TABLE #tmpStagingTraderPerformance1;

INSERT INTO #tmpTrader1 (
	CustId
	,MatchId
	,EventDate
	,BetType
	,SpecialType
	,SportType
	)
SELECT DISTINCT a.OperatorID AS CustId
	,m.MatchId
	,m.EventDate
	,CASE 
		WHEN (
				a.BetType = 1
				OR a.BetType = 5
				)
			AND (a.OperatorType = 1)
			THEN 1
		WHEN (
				a.BetType = 1
				AND a.OperatorType = 2
				)
			THEN 7
		WHEN (
				a.BetType = 2
				AND a.OperatorType = 1
				)
			THEN 3
		WHEN (
				a.BetType = 2
				AND a.OperatorType = 2
				)
			THEN 8
		ELSE 0
		END AS BetType
	,CASE 
		WHEN LeagueName LIKE '%SPECIFIC 15 MINS TOTAL BOOKINGS%'
			THEN 1
		WHEN LeagueName LIKE '%SPECIFIC 15 MINS%'
			AND t.TeamName LIKE '%No.of Corners%'
			THEN 2
		WHEN LeagueName LIKE '%SPECIALS'
			AND (
				t.TeamName LIKE '%Over'
				OR t.TeamName LIKE '%Under'
				)
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
		END SpecialType
	,m.sporttype AS SportType
FROM [bodb_archive].[dbo].[Dot_Admin_Assignment_Operator_bk] a WITH (NOLOCK)
INNER JOIN [bodb_archive].[dbo].Match_bk m WITH (NOLOCK) ON a.matchid = m.matchid
LEFT JOIN bodb02.dbo.Team t WITH (NOLOCK) ON m.homeid = t.teamid
LEFT JOIN bodb02.dbo.League l WITH (NOLOCK) ON m.leagueid = l.leagueid
WHERE m.EventDate BETWEEN @FromDate
		AND @ToDate
	AND m.EventStatus = 'completed'
	AND m.SportType = 1
	AND a.OperatorType < 3
	AND m.MatchCode NOT LIKE '%hedge%';

INSERT INTO #tmpStagingTraderPerformance1 (
	[CustId]
	,[EventDate]
	,[MatchId]
	,[BetType]
	,[BetTeam]
	,[ScoreHDP]
	,[Odds]
	,[StakeOrigin]
	,[StakeMY]
	,[Stake]
	,[ExtraPT]
	,[TPositionTaking]
	,[VirtualRate]
	)
SELECT t.CustId
	,t.EventDate
	,t.MatchId
	,CASE 
		WHEN b.BetType = 1
			AND SpecialType = 0
			THEN 1 --HDP
		WHEN b.BetType = 7
			THEN 7 --1st HDP
		WHEN b.BetType = 3
			AND SpecialType = 0
			THEN 3 --O/U		
		WHEN b.BetType = 8
			AND SpecialType = 0
			THEN 8 --1st O/U
		WHEN b.BetType = 1
			AND SpecialType = 4
			THEN - 1 --15mins HDP
		WHEN b.BetType = 1
			AND SpecialType = 8
			THEN - 2 --Next Corner
		WHEN b.BetType = 1
			AND SpecialType = 5
			THEN - 15 --10mins HDP
		WHEN b.BetType = 1
			AND SpecialType = 9
			THEN - 3 --Next Booking
		WHEN b.BetType = 3
			AND SpecialType = 4
			THEN - 5 --15mins O/U
		WHEN b.BetType = 3
			AND SpecialType = 5
			THEN - 6 --10mins O/U
		WHEN b.BetType = 3
			AND SpecialType = 2
			THEN - 7 --Corners 15mins O/U
		WHEN b.BetType = 3
			AND SpecialType = 7
			THEN - 8 --Total Bookings
		WHEN b.BetType = 3
			AND SpecialType = 1
			THEN - 10 --Total Bookings 15mins O/U
		WHEN b.BetType = 3
			AND SpecialType = 6
			THEN - 13 --No. of Corner
		WHEN b.BetType = 8
			AND SpecialType = 6
			THEN - 12 --1st No. of Corner
		WHEN b.BetType = 8
			AND SpecialType = 7
			THEN - 9 --1st TotalBookings
		WHEN (
				b.BetType = 3
				OR b.BetType = 8
				)
			AND SpecialType = 3
			THEN - 11 --Single Team O/U
		ELSE b.BetType
		END AS BetType
	,b.betteam
	,CASE 
		WHEN b.bettype IN (
				1
				,7
				)
			THEN (hdp1 + b.liveawayscore) - (hdp2 + b.livehomescore)
		ELSE hdp1
		END
	,b.odds
	,b.stake -- stakeorigin
	,(
		CASE 
			WHEN odds <= 1
				THEN 1
			ELSE odds
			END * (
			CASE 
				WHEN ABS(b.modds) = 0.25
					THEN 0.5
				ELSE 1
				END
			) * ABS(b.stake) * virtualrate
		) -- stakemy
	,(
		(
			CASE 
				WHEN ABS(b.modds) = 0.25
					THEN 0.5
				ELSE 1
				END
			) * ABS(b.stake) * virtualrate
		) -- stake
	,SUM(ISNULL(es.ExtraPT, 0)) AS ExtraPT
	,b.tpositiontaking
	,b.virtualrate
FROM #tmpFilteredBettransBK b WITH (NOLOCK)
INNER JOIN #tmpTrader1 t WITH (NOLOCK) ON b.winlostdate = t.EventDate
	AND b.matchid = t.matchid
	AND b.BetType = t.BetType
LEFT JOIN [bodb_ACC].[dbo].[Acc_GroupExtraPTSetting] es WITH (NOLOCK) ON es.SuperId = b.srecommend
	AND es.ProductId = 1
	AND es.Sporttype = 0
	AND es.SubProduct = ''
	AND t.EventDate BETWEEN es.FromDate
		AND es.ToDate
WHERE b.bettype IN (
		1
		,3
		,7
		,8
		)
GROUP BY t.CustId
	,t.EventDate
	,t.MatchId
	,CASE 
		WHEN b.BetType = 1
			AND SpecialType = 0
			THEN 1 --HDP
		WHEN b.BetType = 7
			THEN 7 --1st HDP
		WHEN b.BetType = 3
			AND SpecialType = 0
			THEN 3 --O/U		
		WHEN b.BetType = 8
			AND SpecialType = 0
			THEN 8 --1st O/U
		WHEN b.BetType = 1
			AND SpecialType = 4
			THEN - 1 --15mins HDP
		WHEN b.BetType = 1
			AND SpecialType = 8
			THEN - 2 --Next Corner
		WHEN b.BetType = 1
			AND SpecialType = 5
			THEN - 15 --10mins HDP
		WHEN b.BetType = 1
			AND SpecialType = 9
			THEN - 3 --Next Booking
		WHEN b.BetType = 3
			AND SpecialType = 4
			THEN - 5 --15mins O/U
		WHEN b.BetType = 3
			AND SpecialType = 5
			THEN - 6 --10mins O/U
		WHEN b.BetType = 3
			AND SpecialType = 2
			THEN - 7 --Corners 15mins O/U
		WHEN b.BetType = 3
			AND SpecialType = 7
			THEN - 8 --Total Bookings
		WHEN b.BetType = 3
			AND SpecialType = 1
			THEN - 10 --Total Bookings 15mins O/U
		WHEN b.BetType = 3
			AND SpecialType = 6
			THEN - 13 --No. of Corner
		WHEN b.BetType = 8
			AND SpecialType = 6
			THEN - 12 --1st No. of Corner
		WHEN b.BetType = 8
			AND SpecialType = 7
			THEN - 9 --1st TotalBookings
		WHEN (
				b.BetType = 3
				OR b.BetType = 8
				)
			AND SpecialType = 3
			THEN - 11 --Single Team O/U
		ELSE b.BetType
		END
	,b.betteam
	,CASE 
		WHEN b.bettype IN (
				1
				,7
				)
			THEN (hdp1 + b.liveawayscore) - (hdp2 + b.livehomescore)
		ELSE hdp1
		END
	,b.odds
	,b.stake
	,(
		CASE 
			WHEN odds <= 1
				THEN 1
			ELSE odds
			END * (
			CASE 
				WHEN ABS(b.modds) = 0.25
					THEN 0.5
				ELSE 1
				END
			) * ABS(b.stake) * virtualrate
		) -- stakemy
	,(
		(
			CASE 
				WHEN ABS(b.modds) = 0.25
					THEN 0.5
				ELSE 1
				END
			) * ABS(b.stake) * virtualrate
		) -- stake
	,b.tpositiontaking
	,b.virtualrate
	,b.transid
OPTION (MAXDOP 2)

INSERT INTO #tmpDataGroup (
	CustId
	,EventDate
	,MatchId
	,BetType
	,BetTeam
	,ScoreHDP
	,AVGOdds
	,StakeMY
	,Stake
	)
SELECT t.[CustId]
	,t.[EventDate]
	,t.[MatchId]
	,t.[BetType]
	,t.[BetTeam]
	,t.[ScoreHDP]
	,SUM(CASE 
			WHEN t.[Odds] < 0
				THEN 1
			ELSE t.[Odds]
			END * ABS(t.[StakeOrigin]) * t.VirtualRate * (1 - t.TPositionTaking - t.ExtraPT)) / SUM(CASE 
			WHEN t.[Odds] < 0
				THEN - t.[Odds]
			ELSE 1
			END * ABS(t.[StakeOrigin]) * t.VirtualRate * (1 - t.TPositionTaking - t.ExtraPT))
	,SUM(t.[StakeMY] * (1 - t.TPositionTaking - t.ExtraPT))
	,SUM(t.[Stake] * (1 - t.TPositionTaking - t.ExtraPT))
FROM #tmpStagingTraderPerformance1 t
GROUP BY [CustId]
	,[EventDate]
	,[MatchId]
	,[BetType]
	,[BetTeam]
	,[ScoreHDP]

IF @Debug = 1
	SELECT *
	FROM #tmpDataGroup
	ORDER BY MatchId
		,BetType
		,ScoreHDP
		,BetTeam DESC

IF OBJECT_ID('tempdb..#tmpJuice') IS NOT NULL
	DROP TABLE #tmpJuice;

CREATE TABLE #tmpJuice (
	EventDate DATE
	,MatchId INT
	,BetType SMALLINT
	,StakeMY MONEY
	,Juice MONEY
	);

CREATE INDEX #IDX_EventDate ON #tmpJuice (
	EventDate
	,MatchId
	,BetType
	)

INSERT INTO #tmpJuice (
	EventDate
	,MatchId
	,BetType
	,StakeMY
	,Juice
	)
SELECT temp1.EventDate
	,temp1.MatchId
	,temp1.BetType
	,SUM(temp1.StakeMY) AS StakeMY
	,SUM(ISNULL((
				CASE 
					WHEN temp1.BetTeam IN ('h')
						THEN (
								CASE 
									WHEN temp2.Stake * (1 + abs(temp2.AVGOdds)) / (1 + abs(temp1.AVGOdds)) > temp1.Stake
										THEN temp1.Stake
									ELSE temp2.Stake * (1 + abs(temp2.AVGOdds)) / (1 + abs(temp1.AVGOdds))
									END
								) * CASE 
								WHEN temp1.AVGOdds > 0
									THEN 1
								ELSE - temp1.AVGOdds
								END - (
								CASE 
									WHEN temp1.Stake * (1 + abs(temp1.AVGOdds)) / (1 + abs(temp2.AVGOdds)) > temp2.Stake
										THEN temp2.Stake
									ELSE temp1.Stake * (1 + abs(temp1.AVGOdds)) / (1 + abs(temp2.AVGOdds))
									END
								) * CASE 
								WHEN temp2.AVGOdds > 0
									THEN temp2.AVGOdds
								ELSE 1
								END
					ELSE 0
					END
				), 0)) AS [Juice]
FROM #tmpDataGroup AS temp1 WITH (NOLOCK)
LEFT JOIN #tmpDataGroup AS temp2 ON temp1.MatchId = temp2.MatchId
	AND temp1.BetType = temp2.BetType
	AND temp1.ScoreHDP = temp2.ScoreHDP
	AND temp1.BetTeam <> temp2.BetTeam
GROUP BY temp1.MatchId
	,temp1.BetType
	,temp1.EventDate

IF @Debug = 1
	SELECT *
	FROM #tmpJuice
	ORDER BY matchid
		,bettype

UPDATE tp
SET tp.Juice = t.Juice
	,tp.StakeMYR = t.StakeMY
FROM dbo.TraderPerformance tp WITH (
		ROWLOCK
		,UPDLOCK
		)
INNER JOIN #tmpJuice t WITH (NOLOCK) ON t.MatchId = tp.matchid
	AND t.BetType = tp.bettype
WHERE tp.EventDate = t.EventDate --AND (ISNULL(tp.Juice, 0) <> t.Juice OR ISNULL(tp.StakeMYR, 0) <> t.StakeMY)

IF OBJECT_ID('tempdb..#tmpFilteredBettransBK') IS NOT NULL
	DROP TABLE #tmpFilteredBettransBK