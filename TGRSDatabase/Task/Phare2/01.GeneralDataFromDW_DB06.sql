--DB06

/*  
 Created:	20141202@Tom.Vo
 Task :		GeneralDataFromDW_DB06.sql
 DB:		DBPRO.bodb02
 Original:  
  
 Revisions:      
   			
 Param's Explanation:  
	 
 Exam: 

	 
*/

IF @@SERVERNAME NOT IN ('DB06', 'DBPRO','DB215')
BEGIN
	SELECT 1000 ErrCode
		,'Wrong Server Name' ErrorMsg

	RETURN
END

USE bodb02
GO

SET NOCOUNT ON

DECLARE @fromdate DATETIME
	,@todate DATETIME

SELECT @fromdate = '2014-01-01 00:00:00'
	,@todate = CONVERT(NVARCHAR(20), GETDATE(), 101)

IF OBJECT_ID('tempdb..#tmpMatch') IS NOT NULL
	DROP TABLE #tmpMatch

CREATE TABLE #tmpMatch (
	matchid INT
	,kickofftime DATETIME
	,matchcode VARCHAR(100)
	,leagueid INT
	,homeid INT
	,awayid INT
	)

INSERT INTO #tmpMatch (
	matchid
	,kickofftime
	,matchcode
	,leagueid
	,homeid
	,awayid
	)
SELECT matchid
	,kickofftime
	,matchcode
	,leagueid
	,homeid
	,awayid
FROM DBDW2.bodb_Staging.dbo.match m WITH (NOLOCK)
WHERE m.eventdate BETWEEN @fromdate AND @todate
	AND m.sporttype = 1
	AND m.matchcode NOT LIKE '%hedge%'

IF OBJECT_ID('tempdb..#tmpTraderPer') IS NOT NULL
	DROP TABLE #tmpTraderPer

CREATE TABLE #tmpTraderPer (
	CustID INT
	,matchid INT
	,WorkShift TINYINT
	,bettype INT
	,OUtype INT
	,matchcode VARCHAR(100)
	)

INSERT INTO #tmpTraderPer (
	CustID
	,[WorkShift]
	,matchid
	,bettype
	,OUtype
	,matchcode
	)
SELECT a.operatorid CustID
	,CASE 
		WHEN CAST(m.kickofftime AS TIME) >= '00:00:00' AND CAST(m.kickofftime AS TIME) <'6:00:00' THEN 1--  Afternoon: 12:00:00 ~ 17:59:59 (GMT + 8)
		WHEN CAST(m.kickofftime AS TIME) >= '6:00:00' AND CAST(m.kickofftime AS TIME) <'16:00:00'THEN 2 -- Night: 18:00:00 ~ 3:59:59 (GMT + 8)		
		--WHEN CAST(m.kickofftime AS TIME) >= '16:00:00' AND CAST(m.kickofftime AS TIME) <'24:00:00'THEN 3 --  Midnight: 4:00:00 ~ 11:59:59 (GMT + 8)
		ELSE 3
	END [WorkShift]
	,m.matchID
	,CASE WHEN (a.bettype = 1 OR a.bettype = 5)
			AND (a.operatortype = 1) THEN 1 WHEN (a.bettype = 1 AND a.operatortype = 2) THEN 7 
											WHEN (a.bettype = 2 AND a.operatortype = 1) THEN 3 
											WHEN (a.bettype = 2 AND a.operatortype = 2) THEN 8 
											WHEN (a.bettype = 3 AND a.operatortype = 1) THEN 5 
											WHEN (a.bettype = 3 AND a.operatortype = 2) THEN 15 
											WHEN (a.bettype = 4 AND a.operatortype = 1) THEN 2 
											WHEN (a.bettype = 4 AND a.operatortype = 2) THEN 12 
											ELSE 0 END bettype
	,CASE WHEN leaguename LIKE '%SPECIFIC 15 MINS NUMBER OF CORNERS%' THEN 6 
		  WHEN leaguename LIKE '%SPECIFIC 15 MINS%' AND t.teamname LIKE '%No. of Corners%' THEN 6 
		  WHEN t.teamname LIKE '%No.of Corners%' THEN 1 WHEN t.teamname LIKE '%Total Bookings' THEN 3 
		  WHEN t.teamname LIKE '%Booking' THEN 5 WHEN t.teamname LIKE '%Corner%' THEN 4 
		  WHEN leaguename LIKE '%SPECIFIC 15 MINS TOTAL BOOKINGS%' THEN 7 
		  WHEN leaguename LIKE '%SPECIFIC 15 MINS%' AND t.teamname LIKE '%TOTAL BOOKINGS%' THEN 7 
		  WHEN leaguename LIKE '%SPECIFIC 15 MINS%' THEN 2 
		  WHEN leaguename LIKE '%SPECIFIC 10 MINS%' THEN 8 
		  WHEN leaguename LIKE '%SPECIALS'
			AND (
				t.teamname LIKE '%Over'
				OR t.teamname LIKE '%Under'
				) THEN 9 ELSE 0 END OUtype
	,m.matchcode
FROM (
	SELECT matchid
		,OperatorType
		,OperatorID
		,bettype
	FROM bodb02.dbo.Dot_admin_Assignment_Operator a WITH (NOLOCK)
	WHERE a.operatortype < 3
	
	UNION ALL
	SELECT matchid
		,OperatorType
		,OperatorID
		,bettype
	FROM bodb_archive.dbo.Dot_Admin_Assignment_Operator_bk WITH (NOLOCK)
	WHERE operatortype < 3
	) a
	INNER JOIN #tmpMatch m
	ON a.matchid = m.matchid
	LEFT JOIN bodb02.dbo.Team t WITH (NOLOCK)
	ON t.teamid = m.homeid
	LEFT JOIN bodb02.dbo.league l WITH (NOLOCK)
	ON m.leagueid = l.leagueid
	
IF OBJECT_ID('tempdb..#tmpTraderPerformance') IS NOT NULL
	DROP TABLE #tmpTraderPerformance

CREATE TABLE [dbo].#tmpTraderPerformance (
	[CustId] [int] NULL
	,[MatchId] [int] NULL
	,WorkShift [TINYINT] NULL
	,matchcode [VARCHAR](100) NULL
	,[EventDate] [date] NULL
	,[SportType] [tinyint] NULL
	,[BetType] [smallint] NULL
	,[LeagueId] [int] NULL
	,TurnoverIBC [money] NULL
	,WinlossIBC [money] NULL
	,[Comm] [money] NULL
	,[BetCount] [int] NULL
	,[HomeId] [int] NULL
	,[AwayId] [int] NULL
	)

INSERT INTO #tmpTraderPerformance (
	custid
	,matchid
	,matchcode
	,WorkShift
	,SportType
	,EventDate
	,BetType
	,LeagueId
	,[HomeId]
	,[AwayId]
	,TurnoverIBC
	,WinlossIBC
	,[Comm]
	,BetCount
	)
SELECT cm.custid
	,cm.matchid
	,cm.matchcode
	,cm.WorkShift
	,1 SportType
	,b.rptdate EventDate
	,CASE WHEN b.bettype IN (15, 125) THEN 1 --'1st 1X2'
		WHEN b.bettype IN (5, 124)	AND cm.OUtype = 0	THEN 2 --'1X2
		WHEN b.bettype IN (5, 124)	AND cm.OUtype = 2	THEN 3 --15mins 1X2
		WHEN b.BetType IN (5, 124)	AND cm.OUtype = 8	THEN 22 --10mins 1x2
		WHEN b.bettype = 7								THEN 4 --1st HDP
		WHEN b.bettype = 1			AND cm.OUtype = 0	THEN 5 --HDP
		WHEN b.BetType = 1			AND cm.OUtype = 8	THEN 23 --10mins HDP
		WHEN b.bettype = 1			AND cm.OUType = 2	THEN 6 --15mins HDP
		WHEN b.bettype = 8			AND cm.OUtype = 0	THEN 7 --1st O/U
		WHEN b.bettype = 3			AND cm.OUtype = 0	THEN 8 --O/U
		WHEN b.bettype = 3			AND cm.OUType = 2	THEN 9 --15mins O/U
		WHEN b.bettype = 3			AND cm.OUtype = 8	THEN 10 --10mins O/U
		WHEN b.bettype IN (3, 8)	AND OUtype = 9		THEN 11 --Single Team O/U
		WHEN b.bettype = 8			AND cm.OUtype = 1	THEN 12 --1st No. of Corner
		WHEN b.bettype = 3			AND cm.OUType = 1	THEN 13 --No. of Corner
		WHEN b.bettype = 3			AND cm.OUtype = 6	THEN 14 --Corners 15mins O/U
		WHEN b.bettype = 1			AND cm.OUtype = 4	THEN 15 --Next Corner
		WHEN b.bettype = 8			AND cm.OUType = 3	THEN 16 --1st TotalBookings
		WHEN b.bettype = 3			AND cm.OUType = 3	THEN 17 --Total Bookings
		WHEN b.bettype = 3			AND cm.OUtype = 7	THEN 18 --Total Bookings 15mins O/U
		WHEN b.bettype = 1			AND cm.OUtype = 5	THEN 19 --Next Booking
		WHEN b.bettype = 12								THEN 20 --1st O/E
		WHEN b.bettype = 2								THEN 21 --O/E
		WHEN b.bettype IN (5, 124)						THEN 2 --'1X2
		ELSE b.bettype END BetType
	,b.[LeagueId]
	,b.teamhomeID
	,b.teamawayID
	,SUM(CASE WHEN b.STATUS IN (12, 13) THEN 0.5 * b.TurnoverIBCVirtual ELSE b.TurnoverIBCVirtual END) TurnoverIBC
	,SUM(b.winlossibcvirtual - b.CommissionVirtual) WinlossIBC
	,SUM(- b.CommissionVirtual) Commission
	,SUM(b.betcount) BetCount
FROM DBDW2.bodb_account.dbo.rptMatch b WITH (NOLOCK)
	INNER JOIN #tmpTraderPer cm
	ON b.matchid = cm.matchid
		AND (b.bettype = cm.bettype OR b.bettype IN(124, 125))
WHERE b.rptdate BETWEEN @fromdate AND @todate
	AND b.isLive = 1
	AND b.STATUS NOT IN (- 1, 18, 9, 10, 14, 3)
	AND (b.CustomerCategory NOT IN (30)
		OR (
			b.CustomerCategory = 30
			AND b.turnoverIBC <> 0
			)
		)
GROUP BY cm.custid
	,cm.matchid
	,cm.matchcode
	,cm.WorkShift
	,b.rptdate
	,CASE WHEN b.bettype IN (15, 125) THEN 1 --'1st 1X2'
		WHEN b.bettype IN (5, 124)	AND cm.OUtype = 0	THEN 2 --'1X2
		WHEN b.bettype IN (5, 124)	AND cm.OUtype = 2	THEN 3 --15mins 1X2
		WHEN b.BetType IN (5, 124)	AND cm.OUtype = 8	THEN 22 --10mins 1x2
		WHEN b.bettype = 7								THEN 4 --1st HDP
		WHEN b.bettype = 1			AND cm.OUtype = 0	THEN 5 --HDP
		WHEN b.BetType = 1			AND cm.OUtype = 8	THEN 23 --10mins HDP
		WHEN b.bettype = 1			AND cm.OUType = 2	THEN 6 --15mins HDP
		WHEN b.bettype = 8			AND cm.OUtype = 0	THEN 7 --1st O/U
		WHEN b.bettype = 3			AND cm.OUtype = 0	THEN 8 --O/U
		WHEN b.bettype = 3			AND cm.OUType = 2	THEN 9 --15mins O/U
		WHEN b.bettype = 3			AND cm.OUtype = 8	THEN 10 --10mins O/U
		WHEN b.bettype IN (3, 8)	AND OUtype = 9		THEN 11 --Single Team O/U
		WHEN b.bettype = 8			AND cm.OUtype = 1	THEN 12 --1st No. of Corner
		WHEN b.bettype = 3			AND cm.OUType = 1	THEN 13 --No. of Corner
		WHEN b.bettype = 3			AND cm.OUtype = 6	THEN 14 --Corners 15mins O/U
		WHEN b.bettype = 1			AND cm.OUtype = 4	THEN 15 --Next Corner
		WHEN b.bettype = 8			AND cm.OUType = 3	THEN 16 --1st TotalBookings
		WHEN b.bettype = 3			AND cm.OUType = 3	THEN 17 --Total Bookings
		WHEN b.bettype = 3			AND cm.OUtype = 7	THEN 18 --Total Bookings 15mins O/U
		WHEN b.bettype = 1			AND cm.OUtype = 5	THEN 19 --Next Booking
		WHEN b.bettype = 12								THEN 20 --1st O/E
		WHEN b.bettype = 2								THEN 21 --O/E
		WHEN b.bettype IN (5, 124)						THEN 2 --'1X2
		ELSE b.bettype END
	,b.[LeagueId]
	,b.teamhomeID
	,b.teamawayID


DELETE #tmpTraderPerformance
WHERE TurnoverIBC IS NULL

IF OBJECT_ID('tempdb..#tmpBetType') IS NOT NULL
	DROP TABLE #tmpBetType

CREATE TABLE #tmpBetType (
	BetType SMALLINT
	,TypeName VARCHAR(100)
	,MapBetType SMALLINT
	)

INSERT INTO #tmpBetType (
	BetType
	,TypeName
	,MapBetType
	)
VALUES (1,'1st 1X2',15)
	,(2,'1X2',5	)
	,(3,'15mins 1X2',- 4)
	,(4,'1st HDP',7)
	,(5,'HDP',1	)
	,(6,'15mins HDP',- 1)	
	,(7,'1st O/U',8	)
	,(8,'O/U',3	)
	,(9,'15mins O/U',- 5)
	,(10,'10mins O/U',- 6	)
	,(11,'Single Team O/U',- 11	)
	,(12,'1st No. of Corner',- 12	)
	,(13,'No. of Corner',- 13	)
	,(14,'Corners 15mins O/U',- 7	)
	,(15,'Next Corner',- 2	)
	,(16,'1st TotalBookings',- 9	)
	,(17,'Total Bookings',- 8	)
	,(18,'Total Bookings 15mins O/U',- 10	)
	,(19,'Next Booking',- 3	)
	,(20,'1st O/E',12	)
	,(21,'O/E',2	)
	,(22,'10mins 1X2',- 14	)
	,(23,'10mins HDP',- 15	)

DELETE [bodb_TGRS].[dbo].[TraderPerformance]
WHERE EventDate BETWEEN @fromdate AND @todate

INSERT INTO [bodb_TGRS].[dbo].[TraderPerformance] (
	[CustId]
	,[MatchId]
	,WorkShift
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
	,matchcode
	)
SELECT td.custid
	,td.matchid
	,td.WorkShift
	,td.EventDate
	,td.SportType
	,bt.MapBetType
	,td.LeagueId
	,td.[HomeId]
	,td.[AwayId]
	,td_T.TeamId
	,td_G.Grade
	,td.TurnoverIBC
	,td.WinlossIBC
	,td.[Comm]
	,td.BetCount
	,td.matchcode
FROM #tmpTraderPerformance td WITH (NOLOCK)
	LEFT JOIN #tmpBetType bt WITH (NOLOCK)
	ON td.BetType = bt.BetType
	LEFT JOIN [bodb_TGRS].dbo.[TraderGrade_History] td_G WITH (NOLOCK)
	ON td_G.CustID = td.custid
		AND td.EventDate BETWEEN td_G.BeginDate AND ISNULL(td_G.EndDate, GETDATE())
	LEFT JOIN [bodb_TGRS].dbo.[TraderTeam_History] td_T WITH (NOLOCK)
	ON td_T.CustID = td.custid
		AND td.EventDate BETWEEN td_T.BeginDate AND ISNULL(td_T.EndDate, GETDATE())
ORDER BY td.EventDate



IF OBJECT_ID('tempdb..#tmpTraderPerformance') IS NOT NULL
	DROP TABLE #tmpTraderPerformance
