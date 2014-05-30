ALTER PROCEDURE [dbo].[Task_rpt_TraderPerformance] 
	@Date DATE = NULL
	 
AS

/*
Created:	20140516@Sophia
Task :		Summarize latest 3 days data for table rpt_TraderPerformance 
DB:			DBTGRS.bodb_TGRS
Original:	Task_rptTraderPerformance

Revision:


*/

SET NOCOUNT ON

IF @Date IS NULL  
SELECT @Date = GETDATE() - 1 

 
--temp table for operator username AND number of matches control by an operator
DECLARE @TMP_Trader TABLE (
	CustId		INT
	,TeamId		INT
	,Grade		INT
	,LeagueId	INT
	,MatchId	INT
	,SportType	INT
	,EventDate	DATETIME
	,HomeId		INT
	,AwayId		INT
	,BetType	SMALLINT
	,SpecialType	TINYINT	 ----Special condition type
	)


-- Soccer sport --
	INSERT  @TMP_Trader
	SELECT  a.operatorid AS CustId, TH.TeamId, GH.Grade, m.LeagueId, m.MatchId, 1 as SportType,
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
			END

	FROM bodb02.dbo.Dot_admin_Assignment_Operator a WITH (NOLOCK)  
		INNER JOIN bodb02.dbo.Match m WITH (NOLOCK) ON a.matchid=m.matchid
		INNER JOIN bodb02.dbo.Team t WITH (NOLOCK) ON m.homeid=t.teamid		
		INNER JOIN bodb02.dbo.Team ta WITH (NOLOCK) ON m.awayid=ta.teamid	
		INNER JOIN bodb02.dbo.League l WITH (NOLOCK) ON m.leagueid=l.leagueid
		INNER JOIN (	 
					SELECT	TH.CustId, TH.BeginDate, TH.TeamId 
					FROM	dbo.TraderTeam_History TH WITH (NOLOCK)
					WHERE	@Date BETWEEN BeginDate AND ISNULL(EndDate,'9999-12-31')					 
				   ) TH ON TH.CustId = a.operatorid
		INNER JOIN (	 
					SELECT	TH.CustId, TH.BeginDate, TH.Grade 
					FROM	dbo.TraderGrade_History TH WITH (NOLOCK)
					WHERE	@Date BETWEEN BeginDate AND ISNULL(EndDate,'9999-12-31')					 
				   ) GH ON GH.CustId = a.operatorid
	WHERE	m.EventDate = @Date
			AND m.EventStatus='completed'
			AND m.SportType= 1
			AND a.OperatorType < 3
			AND m.MatchCode not like '%hedge%'

	
-------------------End Soccer---------------------------


-----------/*Delete data before inserting*/------
DELETE dbo.rpt_TraderPerformance WHERE Eventdate = @Date
-------------------------------------------------
INSERT INTO dbo.rpt_TraderPerformance (
			CustId
			,TeamId
			,Grade
			,MatchId
			,EventDate
			,SportType
			,LeagueId
			,HomeId
			,AwayId
			,BetType
			,Stake
			,WinLost
			,Comm
			,BetCount
			)

SELECT	t.Custid, t.TeamId, t.Grade, 
		t.MatchId, t.EventDate, t.SportType, 
		t.LeagueId, t.HomeId, t.AwayId, 
		CASE
			WHEN b.BetType = 1 AND SpecialType = 0 THEN 1
			WHEN b.BetType = 7 THEN 7	
					
			WHEN b.BetType = 3 AND SpecialType = 0 THEN 3				
			WHEN b.BetType = 8 AND SpecialType = 0 THEN 8	
			WHEN b.BetType = 2  THEN 2				
			WHEN b.BetType = 12 THEN 12		
					
			WHEN b.BetType = 5 AND SpecialType = 0 THEN 5				
			WHEN b.BetType = 15 AND SpecialType = 0 THEN 15	
										
			--------------------------

			WHEN b.BetType = 1 AND SpecialType = 4 THEN -1
			WHEN b.BetType = 1 AND SpecialType = 8 THEN -2
			WHEN b.BetType = 1 AND SpecialType = 9 THEN -3

			WHEN b.BetType = 5 AND SpecialType = 4 THEN -4 

			WHEN b.BetType = 3 AND SpecialType = 4 THEN -5
			WHEN b.BetType = 3 AND SpecialType = 5 THEN -6
			WHEN b.BetType = 3 AND SpecialType = 2 THEN -7
			WHEN b.BetType = 3 AND SpecialType = 7 THEN -8				
			WHEN b.BetType = 3 AND SpecialType = 1 THEN -10
			WHEN b.BetType = 3 AND SpecialType = 6 THEN -13
								
			WHEN b.BetType = 8 AND SpecialType = 6 THEN -12
			WHEN b.BetType = 8 AND SpecialType = 7 THEN -9

			WHEN (b.BetType = 3 OR b.BetType = 8) AND SpecialType = 3 THEN -11
		ELSE b.BetType END AS BetType,		 
		--turn over		
		SUM ((CASE WHEN b.modds = 0.25 OR b.modds = -0.25 THEN ABS(b.stake)/2 ELSE ABS(b.stake) END)*(1-b.tpositiontaking)*b.virtualrate) AS Stake,				
		--Winlost
		-SUM ((winlost - actual_stake + awinlost + mwinlost+ swinlost) * b.virtualrate) AS WinLost,		
		--Commission
		SUM (scomm * b.virtualrate) AS Comm,			
		--Live BetCount				
		SUM (1) AS BetCount				
FROM	bodb02.dbo.bettrans b WITH (NOLOCK) 		
	INNER JOIN	@TMP_Trader t 
			ON	b.matchid = t.matchid AND b.BetType = t.BetType AND b.LiveIndicator = 1
WHERE	b.statusID IN (112,113) AND b.ruben = 1
		AND b.Currency NOT IN (20,27,28)
GROUP BY t.Custid,  t.TeamId, t.Grade, t.MatchId, t.EventDate, t.SportType, t.LeagueId, t.HomeId, t.AwayId, b.bettype, t.SpecialType
 
 
GO
GRANT EXECUTE ON [dbo].[Task_rpt_TraderPerformance] TO [bodbTGRSNet]
