
ALTER PROCEDURE [dbo].[TGRS_Rpt_PerformanceDetail_League_Match]
		@FROMDate	DATE
	,	@ToDate		DATE
	,	@LeagueId		INT
	,	@Bettypes	VARCHAR(2000) =  '0'
	,	@IsExcludeLeagues	BIT = 1
AS    
/*  
	Created:	20160328@Thai.Tran
	TASk:		Detail report League Performance - Detail Match
	DB:			DBTGRS.bodb_TGRS
	Original:      
				
	Revisions: 
		- 20171019@Simon: Change VARCHAR(200) to VARCHAR(2000)
		- 20171205@Simon: get only Live data & Bettypes are not disabled
		- 20180912@Simon: add league exclusion

	Param's ExplanatiON:  	
	
	Example: 
		EXEC [TGRS_Rpt_PerformanceDetail_League_Match] @FROMDate = '2014-01-01', @ToDate= '2014-12-30', @Bettypes = '0', @LeagueId = 364  
*/  
 
BEGIN 
	SET NOCOUNT ON;

	DECLARE @BettypeList AS TABLE (bettype SMALLINT);

	IF @Bettypes <> '0'
		INSERT INTO @BettypeList
		SELECT val 
		FROM dbo.strSplit_Key(@Bettypes,',');
	ELSE 
		INSERT INTO @BettypeList
		SELECT Bettype 
		FROM dbo.Bettype WITH (NOLOCK);
		 	 		 		 	
	SELECT P.MatchId, P.HomeId, P.AwayId, P.EventDate,
		ISNULL(SUM(P.Stake),0) AS Turnover, 
		ISNULL(SUM(P.WinLost),0) - ISNULL(SUM(P.Comm),0) AS WinLoss, 
		ISNULL(SUM(BetCount),0) AS BetCount,
		CASE WHEN ISNULL(SUM(P.Stake),0) <> 0 THEN (ISNULL(SUM(P.WinLost),0)- ISNULL(SUM(P.Comm),0)) * 100 /ISNULL(SUM(P.Stake),0)  ELSE NULL END AS Margin	
	FROM	dbo.TraderPerformance P WITH (NOLOCK)		 
	WHERE	P.LeagueId = @LeagueId
		AND P.Bettype IN (SELECT bettype FROM @BettypeList)
		AND P.EventDate BETWEEN @FROMDate AND @ToDate
		AND P.IsLive = 1
		AND (@IsExcludeLeagues = 0 OR (P.LeagueId NOT IN (SELECT le.LeagueId FROM dbo.LeagueExclusion le WHERE le.LeagueId = P.LeagueId)))
	GROUP BY P.MatchId, P.LeagueId, P.HomeId, P.AwayId, P.EventDate			
	ORDER BY P.LeagueId ASC,Margin DESC, P.EventDate ASC; 
END;

/*

GRANT EXECUTE ON [dbo].[TGRS_Rpt_PerformanceDetail_League_Match] TO [bodbTGRSNet]
GRANT VIEW DEFINITION ON [dbo].[TGRS_Rpt_PerformanceDetail_League_Match] TO [bodbTGRSNet ]

*/

/*<info serverAlias="DBTGRS-bodb_TGRS" executers="bodbTGRSNet" isFunction="0" isNested="0"></info>*/