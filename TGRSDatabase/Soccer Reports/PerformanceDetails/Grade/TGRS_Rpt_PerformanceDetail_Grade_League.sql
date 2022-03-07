ALTER PROCEDURE [dbo].[TGRS_Rpt_PerformanceDetail_Grade_League]  	
		@FromDate			DATE
	,	@ToDate				DATE
	,	@LeagueGroupIds		VARCHAR(2000) = ''
	,	@Grade				INT
	,	@Bettypes			VARCHAR(2000) =  '0'
	,	@IsExcludeLeagues	BIT = 1
	,	@Market				SMALLINT = 1
AS    
/*  
 Created:	20160328@Aaron.Cao
 Task :		Detail report - Grade -> League Performance
 DB:		DBTGRS.bodb_TGRS
 Original:  
 
 Revisions:      	
	- 20171019@Simon:		Change VARCHAR(200) to VARCHAR(2000)
	- 20171205@Simon:		get only Live data & Bettypes are not disabled
	- 20180912@Simon:		add league exclusion
	- 20190822@Long.Luu:	grade brokendown for details performance [Redmine ID: 117030]
	- 20190919@Long.Luu:	Support Nonlive Data [Redmine ID: 118959]
	- 20191023@John.Ngo:	Enhance performance [Redmine ID: 121268]
	- 20200713@John.Ngo:	Performance Detail - Support filter by league group [Redmine ID: 137276]
	- 20210827@Adam.Tran: 	Sports - Performance Real Figures [Redmine: #158981]
	- 20220222@John.Ngo:	Separate League Group for Virtual and SABA PinGoal [Redmine: #161859]
	- 20220307@John.Ngo: 	Update Separate League Group for Virtual [Redmine: #161859]

 Param's Explanation:  	
	- @Market: -1 All; 0 Nonlive; 1 Live

 Exam: 
	  EXEC  TGRS_Rpt_PerformanceDetail_Grade_League @FromDate = '2016-03-13', @ToDate= '2016-03-27', @Grade = 1
*/  
 
BEGIN 
	SET NOCOUNT ON;

	DECLARE @OtherGroupsId SMALLINT = 12;
	
	DECLARE @LeagueGroups AS TABLE (LeagueGroupId SMALLINT PRIMARY KEY CLUSTERED, LeagueGroupName VARCHAR(200), TargetLeagueGroupId SMALLINT)
	INSERT INTO @LeagueGroups(LeagueGroupId, LeagueGroupName, TargetLeagueGroupId)
	EXECUTE dbo.[TGRS_LeagueGroupSoccer_Get] @LeagueGroupIds = @LeagueGroupIds;
	
	DECLARE @BettypeList AS TABLE (Bettype SMALLINT);
	IF @Bettypes <> '0'
		INSERT INTO @BettypeList
		SELECT val 
		FROM dbo.strSplit_Key(@Bettypes,',');
	ELSE 
		INSERT INTO @BettypeList
		SELECT Bettype 
		FROM dbo.Bettype WITH (NOLOCK);
	
	SELECT P.LeagueId
		,	L.LeagueName
		,   lg.TargetLeagueGroupId AS LeagueGroupID
		,	P.IsLive
		,	ISNULL(COUNT(DISTINCT P.CustId), 0) 					AS TraderCount
		,	ISNULL(COUNT(DISTINCT P.MatchId), 0) 					AS MatchCount
		,	ISNULL(SUM(P.Stake), 0) 								AS Turnover
		,	ISNULL(SUM(P.WinLost), 0) - ISNULL(SUM (P.Comm),0) 		AS WinLoss
		,	CASE WHEN ISNULL(SUM(P.Stake), 0) <> 0 THEN (ISNULL(SUM(P.WinLost), 0) - ISNULL(SUM(P.Comm), 0)) * 100/SUM(P.Stake) ELSE NULL END AS Margin
		,	ISNULL(SUM(P.Stake_Real),0) 							AS TurnoverReal
		,	ISNULL(SUM(CASE WHEN P.Is8RM = 0 THEN P.WinLost_Real ELSE 0 END),0) 	AS WinLossReal
		,	CASE WHEN ISNULL(SUM(P.Stake_Real),0) <> 0 THEN ISNULL(SUM(CASE WHEN P.Is8RM = 0 THEN P.WinLost_Real ELSE 0 END),0) * 100/ISNULL(SUM(P.Stake_Real),0) ELSE NULL END 							   AS MarginReal
		,	ISNULL(SUM(P.BetCount), 0) AS BetCount
	FROM dbo.TraderPerformance AS P WITH (NOLOCK)
		INNER JOIN bodb02.dbo.League AS L WITH (NOLOCK) ON P.LeagueId = L.LeagueId
		LEFT JOIN @LeagueGroups AS lg ON L.LeagueGroupId = lg.LeagueGroupId
		LEFT JOIN dbo.LeagueExclusion le WITH(NOLOCK) ON P.LeagueId = le.LeagueId
	WHERE	P.Bettype IN (SELECT bettype FROM @BettypeList)
		AND P.Grade = @Grade
		AND P.EventDate BETWEEN @FromDate AND @ToDate	
		AND (@Market = -1 OR P.IsLive = @Market)
		AND (@IsExcludeLeagues = 0 OR le.LeagueId IS NULL)
		AND (@LeagueGroupIds = '' OR lg.LeagueGroupId IS NOT NULL)
	GROUP BY P.LeagueId, L.LeagueName, L.LeagueGroupID
		,   lg.TargetLeagueGroupId
		,	P.IsLive	
	ORDER BY Margin DESC, LeagueName ASC;
END;

GO

/*<info serverAlias="DBTGRS-bodb_TGRS" executers="bodbTGRSNet" isFunction="0" isNested="0"></info>*/
