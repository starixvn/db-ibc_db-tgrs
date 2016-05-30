USE bodb02
GO

SET NOCOUNT ON

DECLARE @fromdate datetime,@todate datetime

SELECT @fromdate ='2014-05-24 00:00:00',@todate ='2014-06-01 00:00:00' 

IF OBJECT_ID('tempdb..#tmpMatch') IS NOT NULL    DROP TABLE #tmpMatch

CREATE TABLE #tmpMatch(matchid INT,matchcode VARCHAR(100),leagueid INT,homeid INT,awayid INT)

INSERT INTO #tmpMatch(matchid,matchcode,leagueid,homeid,awayid)
SELECT matchid,matchcode,leagueid,homeid,awayid
FROM bodb_account.dbo.match m WITH (NOLOCK)
WHERE m.eventdate between @fromdate and @todate 
	and m.matchcode not like '%hedge%' 
UNION
SELECT matchid,matchcode,leagueid,homeid,awayid
FROM bodb_archive.dbo.match m WITH (NOLOCK)
WHERE m.eventdate between @fromdate and @todate 
	and m.matchcode not like '%hedge%'

IF OBJECT_ID('tempdb..#tmpTraderPer') IS NOT NULL    DROP TABLE #tmpTraderPer

CREATE TABLE #tmpTraderPer(CustID INT,matchid INT,
	bettype INT,
	OUtype INT,
	matchcode varchar(100))

INSERT INTO #tmpTraderPer(CustID,matchid,bettype,OUtype,matchcode)
select a.operatorid CustID, m.matchID,  
    case when (a.bettype = 1 or a.bettype =5)  and (a.operatortype = 1) then 1   
      when (a.bettype = 1 and a.operatortype = 2) then 7
      when (a.bettype = 2 and a.operatortype = 1) then 3
      when (a.bettype = 2 and a.operatortype = 2) then 8
      when (a.bettype = 3 and a.operatortype = 1) then 5
      when (a.bettype = 3 and a.operatortype = 2) then 15
      --when (a.bettype = 4 and a.operatortype = 1) then 22 -- Next Goal
      when (a.bettype = 4 and a.operatortype = 1) then 2
      when (a.bettype = 4 and a.operatortype = 2) then 12
    else 0  end bettype, 
	case
		when leaguename LIKE '%SPECIFIC 15 MINS NUMBER OF CORNERS%' THEN 6
		when leaguename LIKE '%SPECIFIC 15 MINS%' AND t.teamname LIKE '%No. of Corners%' THEN 6
		when t.teamname LIKE '%No.of Corners%' then 1
		when t.teamname LIKE '%Total Bookings' then 3
		when t.teamname LIKE '%Booking' then 5
		--when a.bettype=5 then 4
		when t.teamname LIKE '%Corner%' then 4
		when leaguename LIKE '%SPECIFIC 15 MINS TOTAL BOOKINGS%' then 7
		when leaguename LIKE '%SPECIFIC 15 MINS%' AND t.teamname LIKE '%TOTAL BOOKINGS%' then 7
		when leaguename LIKE '%SPECIFIC 15 MINS%' then 2
		when leaguename LIKE '%SPECIFIC 10 MINS%' then 8
		when leaguename LIKE '%SPECIALS' and (t.teamname LIKE '%Over' or t.teamname LIKE '%Under') THEN 9 
	   else 0  
  end  OUtype,
	m.matchcode
  from (
		SELECT matchid ,OperatorType,OperatorID,bettype FROM [DBARC].bodb02.dbo.Dot_admin_Assignment_Operator a WITH (NOLOCK)  
		UNION ALL
		SELECT matchid ,OperatorType,OperatorID,bettype FROM [DBARC].[bodb_archive].[dbo].[Dot_Admin_Assignment_Operator_bk] WITH (NOLOCK) 
  ) a
  INNER JOIN #tmpMatch m  on a.matchid=m.matchid
  LEFT JOIN bodb02.dbo.Team t with(nolock) on t.teamid=m.homeid
  LEFT JOIN bodb_account.dbo.league l with(nolock) on m.leagueid=l.leagueid  
  where   
     l.sportid in (1)--exclude number game  
   and a.operatortype < 3  

IF OBJECT_ID('tempdb..#tmpTraderPerformance') IS NOT NULL    DROP TABLE #tmpTraderPerformance

CREATE TABLE [dbo].#tmpTraderPerformance(
	[CustId] [int] NULL,
	[MatchId] [int] NULL,
	matchcode VARCHAR(100) NULL,
	[EventDate] [date] NULL,
	[SportType] [tinyint] NULL,
	[BetType] [smallint] NULL,
	[LeagueId] [int] NULL,
	TurnoverIBC [money] NULL,
	WinlossIBC [money] NULL,
	[Comm] [money] NULL,
	[BetCount] [int] NULL,
	[HomeId] [int] NULL,
	[AwayId] [int] NULL
) 

INSERT INTO #tmpTraderPerformance(custid,matchid,SportType,EventDate,BetType,LeagueId,[HomeId],[AwayId],TurnoverIBC,WinlossIBC,[Comm],BetCount)
SELECT  
	cm.custid,
	b.matchid,
	1 SportType,
	b.rptdate EventDate,
    CASE  
		when b.bettype =15 then 1 
		when b.bettype =5 and cm.OUtype =0 then 2
		when b.bettype =5 and cm.OUtype =2 then 3
		WHEN b.BetType =5 AND cm.OUtype =8 THEN 22		--10mins 1x2
		when b.bettype =7 then 4
		when b.bettype =1 and cm.OUtype =0 then 5
		WHEN b.BetType =1 AND cm.OUtype =8 THEN 23		--10mins HDP
		when b.bettype =1 and cm.OUType =2 then 6
		when b.bettype =8 and cm.OUtype =0 then 7
		when b.bettype =3 and cm.OUtype =0 then 8
		when b.bettype =3 and cm.OUType =2 then 9
		when b.bettype =3 and cm.OUtype =8 then 10
		when b.bettype IN (3,8) and OUtype = 9 then 11
		when b.bettype =8 and cm.OUtype =1 then 12
		when b.bettype =3 and cm.OUType =1 then 13
		when b.bettype =3 and cm.OUtype =6 then 14
		when b.bettype =1 and cm.OUtype =4 then 15
		when b.bettype =8 and cm.OUType =3 then 16
		when b.bettype =3 and cm.OUType =3 then 17
		when b.bettype =3 and cm.OUtype =7 then 18
		when b.bettype =1 and cm.OUtype =5 then 19
		when b.bettype =12 then 20
		when b.bettype =2 then 21
		else b.bettype
		end BetType,
	b.[LeagueId],
	b.teamhomeID,
	b.teamawayID,
	SUM(CASE WHEN b.status in (12,13) THEN 0.5*b.TurnoverIBCVirtual ELSE b.TurnoverIBCVirtual END) TurnoverIBC,
	SUM(b.winlossibcvirtual-b.CommissionVirtual) WinlossIBC,
	SUM(-b.CommissionVirtual) Commission,
	SUM(b.betcount) BetCount
   from bodb_account.dbo.rptMatch b with(nolock)   
    inner join #tmpTraderPer cm on b.matchid=cm.matchid and b.bettype = cm.bettype
   where 
	b.rptdate between @fromdate and @todate  AND
	b.isLive =  1 and
	b.status NOT IN  (-1,18,9,10,14,3) AND 
	(b.CustomerCategory not in (30) OR (b.CustomerCategory = 30 AND b.turnoverIBC <> 0))
   group by  
	cm.custid,
	b.matchid,
	b.rptdate,
    CASE  
		when b.bettype =15 then 1 
		when b.bettype =5 and cm.OUtype =0 then 2
		when b.bettype =5 and cm.OUtype =2 then 3
		WHEN b.BetType =5 AND cm.OUtype =8 THEN 22		--10mins 1x2
		when b.bettype =7 then 4
		when b.bettype =1 and cm.OUtype =0 then 5
		WHEN b.BetType =1 AND cm.OUtype =8 THEN 23		--10mins HDP
		when b.bettype =1 and cm.OUType =2 then 6
		when b.bettype =8 and cm.OUtype =0 then 7
		when b.bettype =3 and cm.OUtype =0 then 8
		when b.bettype =3 and cm.OUType =2 then 9
		when b.bettype =3 and cm.OUtype =8 then 10
		when b.bettype IN (3,8) and OUtype = 9 then 11
		when b.bettype =8 and cm.OUtype =1 then 12
		when b.bettype =3 and cm.OUType =1 then 13
		when b.bettype =3 and cm.OUtype =6 then 14
		when b.bettype =1 and cm.OUtype =4 then 15
		when b.bettype =8 and cm.OUType =3 then 16
		when b.bettype =3 and cm.OUType =3 then 17
		when b.bettype =3 and cm.OUtype =7 then 18
		when b.bettype =1 and cm.OUtype =5 then 19
		when b.bettype =12 then 20
		when b.bettype =2 then 21
		else b.bettype
		end,
	b.[LeagueId],
	b.teamhomeID,
	b.teamawayID


	DELETE #tmpTraderPerformance WHERE  TurnoverIBC IS NULL

	IF OBJECT_ID('tempdb..#tmpBetType') IS NOT NULL    DROP TABLE #tmpBetType	

	CREATE TABLE #tmpBetType(BetType SMALLINT,TypeName VARCHAR(100),MapBetType SMALLINT)

	INSERT INTO #tmpBetType(BetType,TypeName,MapBetType)
	VALUES (1,'1st 1X2',15),
		(2,'1X2',5),
		(3,'15mins 1X2',-4),
		(4,'1st HDP',7),
		(5,'HDP',1),
		(6,'15mins HDP',-1),
		(7,'1st O/U',8),
		(8,'O/U',3),
		(9,'15mins O/U',-5),
		(10,'10mins O/U',-6),
		(11,'Single Team O/U',-11),
		(12,'1st No. of Corner',-12),
		(13,'No. of Corner',-13),
		(14,'Corners 15mins O/U',-7),
		(15,'Next Corner',-2),
		(16,'1st TotalBookings',-9),
		(17,'Total Bookings',-8),
		(18,'Total Bookings 15mins O/U',-10),
		(19,'Next Booking',-3),
		(20,'1st O/E',12),
		(21,'O/E',2),
		(22,'10mins 1X2',-14),
		(23,'10mins HDP',-15)
		  

	DELETE DBACC.[bodb_TGRS].[dbo].[TraderPerformance]
	WHERE EventDate BETWEEN @fromdate AND @todate 

	INSERT INTO DBACC.[bodb_TGRS].[dbo].[TraderPerformance]
           ([CustId]
           ,[MatchId]
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
           )

   SELECT td.custid,
		td.matchid,
		td.EventDate,
		td.SportType,		
		bt.MapBetType,
		td.LeagueId,
		td.[HomeId],
		td.[AwayId],
		td_T.TeamId,
		td_G.Grade,
		td.TurnoverIBC,
		td.WinlossIBC,
		td.[Comm],
		td.BetCount
   FROM #tmpTraderPerformance td  WITH(NOLOCK)
	LEFT JOIN #tmpBetType bt  WITH(NOLOCK)
		ON td.BetType = bt.BetType
	LEFT JOIN DBACC.[bodb_TGRS].dbo.[TraderGrade_History] td_G WITH(NOLOCK)
		ON td_G.CustID = td.custid AND td.EventDate BETWEEN td_G.BeginDate AND ISNULL(td_G.EndDate,GETDATE()+10)
	LEFT JOIN DBACC.[bodb_TGRS].dbo.[TraderTeam_History] td_T WITH(NOLOCK)
		ON td_T.CustID = td.custid AND td.EventDate BETWEEN td_T.BeginDate AND ISNULL(td_T.EndDate,GETDATE()+10)


DELETE DBACC.[bodb_TGRS].[dbo].[SummaryByBetType_Daily]
WHERE EventDate BETWEEN @fromdate AND @todate 

INSERT INTO  DBACC.[bodb_TGRS].[dbo].[SummaryByBetType_Daily]
( [EventDate]
      ,[LeagueId]
      ,[BetType]
      ,[Stake]
      ,[WinLost]
      ,[Comm]
      --,[Margin]
      ,[BetCount]
      ,[MatchCount]
 )

  SELECT td.EventDate,
		td.LeagueId,
		bt.MapBetType,
		SUM(td.TurnoverIBC) TurnoverIBC,
		SUM(td.WinlossIBC) WinlossIBC,
		SUM(td.[Comm]) [Comm],
		--SUM(td.WinlossIBC) / SUM(td.TurnoverIBC) [MarginIBC],		
		SUM(td.BetCount) BetCount,
		COUNT(DISTINCT td.matchid) [MatchCount]		
   FROM #tmpTraderPerformance td  WITH(NOLOCK)
	LEFT JOIN #tmpBetType bt  WITH(NOLOCK)
		ON td.BetType = bt.BetType
	GROUP BY td.EventDate,
		td.LeagueId,
		bt.MapBetType

 
DELETE DBACC.[bodb_TGRS].[dbo].SummaryByLeague_Daily
WHERE EventDate BETWEEN @fromdate AND @todate 

INSERT INTO DBACC.[bodb_TGRS].[dbo].SummaryByLeague_Daily
	([EventDate]
      ,[LeagueId]
      ,[Stake]
      ,[WinLost]
      ,[Comm]
      --,[Margin]
      ,[BetCount]
      ,[MatchCount])
  SELECT td.EventDate,
		td.LeagueId,
		SUM(td.TurnoverIBC) TurnoverIBC,
		SUM(td.WinlossIBC) WinlossIBC,
		SUM(td.[Comm]) [Comm],
		--SUM(td.WinlossIBC) / SUM(td.TurnoverIBC) [MarginIBC],		
		SUM(td.BetCount) BetCount,
		COUNT(DISTINCT td.matchid) [MatchCount]		
   FROM #tmpTraderPerformance td  WITH(NOLOCK)
	GROUP BY td.EventDate,
		td.LeagueId 


DELETE DBACC.[bodb_TGRS].[dbo].[SummaryByTeam_Daily]
WHERE EventDate BETWEEN @fromdate AND @todate 

INSERT INTO DBACC.[bodb_TGRS].[dbo].[SummaryByTeam_Daily]
	( [EventDate]
      ,[TeamId]
      ,[Stake]
      ,[WinLost]
      ,[Comm]
      --,[Margin]
      ,[BetCount]
      ,[MatchCount])
    SELECT td.EventDate,
		td_T.TeamId,		
		SUM(td.TurnoverIBC) TurnoverIBC,
		SUM(td.WinlossIBC) WinlossIBC,
		SUM(td.[Comm]) [Comm],
		--SUM(td.WinlossIBC) / SUM(td.TurnoverIBC) [MarginIBC],		
		SUM(td.BetCount) BetCount,
		COUNT(DISTINCT td.matchid) [MatchCount]
   FROM #tmpTraderPerformance td  WITH(NOLOCK)
	LEFT JOIN DBACC.[bodb_TGRS].dbo.[TraderTeam_History] td_T WITH(NOLOCK)
		ON td_T.CustID = td.custid AND td.EventDate BETWEEN td_T.BeginDate AND ISNULL(td_T.EndDate,GETDATE()+10)
	GROUP BY td.EventDate,
		td_T.TeamId

  