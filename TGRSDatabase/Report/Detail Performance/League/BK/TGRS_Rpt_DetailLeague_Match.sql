ALTER PROCEDURE [dbo].[TGRS_Rpt_DetailLeague_Match]  	
	@FromDate				DATE,
	@ToDate					DATE,
	@LeagueId				INT,
	@CustId					INT,
	@Bettypes				VARCHAR(2000) =  '0',
	@IsExcludeLeagues		BIT = 1
AS    
/*  
 Created:	20140523@Sophia
 Task :		Detail report League Performance - Detail Match 
 DB:		DBTGRS.bodb_TGRS
 Original:  
  
 Revisions:      
	- 20180911@Long:	Support excluding Leagues from report [Redmine ID: #100322]
   			
 Param's Explanation:  	

 Exam: 
	EXEC TGRS_Rpt_DailyLeague_Match @FromDate = '2014-01-01', @ToDate= '2014-05-30', @LeagueId = 6394, @Bettypes = '0', @CustID =52002
*/   
BEGIN 
	 SET NOCOUNT ON;

	 DECLARE @BettypeList AS TABLE (bettype SMALLINT)
	 IF @Bettypes <> '0'
		 INSERT INTO @BettypeList
		 SELECT val FROM dbo.strSplit_Key(@Bettypes,',')
	 ELSE 
		 INSERT INTO @BettypeList
		 SELECT Bettype FROM dbo.Bettype WITH (NOLOCK)
		 
	SELECT P.MatchId, P.HomeId, P.AwayId, P.EventDate,
		ISNULL(SUM(P.Stake),0) AS Turnover, 
		ISNULL(SUM(P.WinLost),0) - ISNULL(SUM(P.Comm),0) AS WinLost, 
		ISNULL(SUM(BetCount),0) as BetCount,
		CASE WHEN ISNULL(SUM(P.Stake),0) <> 0 THEN (ISNULL(SUM(P.WinLost),0)- ISNULL(SUM(P.Comm),0)) * 100/ISNULL(SUM(P.Stake),0) ELSE NULL END AS Margin	
	FROM	dbo.TraderPerformance P WITH (NOLOCK)		 
	WHERE	P.EventDate BETWEEN @FromDate AND @ToDate
		AND P.LeagueId = @LeagueId
		AND P.CustId = @CustId
		AND P.Bettype IN (SELECT Bettype FROM @BettypeList)
		AND (@IsExcludeLeagues = 0 OR (P.LeagueId NOT IN (SELECT le.LeagueId FROM dbo.LeagueExclusion le)))
	GROUP BY P.MatchId, P.HomeId, P.AwayId, P.EventDate
	ORDER BY Margin DESC, P.EventDate ASC;
END;

GO
GRANT EXECUTE ON [dbo].[TGRS_Rpt_DetailLeague_Match] TO [bodbTGRSNet]
GO



/*<info serverAlias="DBTGRS-bodb_TGRS" executers="bodbTGRSNet" isFunction="0" isNested="0"></info>*/