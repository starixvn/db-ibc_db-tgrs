CREATE PROCEDURE [dbo].[TGRS_Basketball_Rpt_PerformanceDetail_Bettype_League_BetChoice_Quarter]  	
		@FromDate			DATE
	,	@ToDate				DATE
	,	@LeagueId			INT
	,	@Bettype			SMALLINT
	,	@BetChoice			NVARCHAR(50)
	,	@LiveType			SMALLINT = 1
AS    
/*  
	Created:	20211201@Adam.Tran
	Task :		Basketball - View report to Set X Game Y - [Redmine: #164165]
	DB:			DBTGRS.bodb_TGRS
	Original:  
  
	Revisions: 	
   		- 20211201@Adam.Tran: Basketball - View report to Set X Game Y [Redmine: #164165]

	Param's Explanation:  	
		- @LiveType: -1 All; 0 Nonlive; 1 Live

	 Exam: 
		EXEC  TGRS_Basketball_Rpt_PerformanceDetail_Bettype_League_BetChoice_Quarter @FromDate = '2021-08-01', @ToDate= '2021-12-01', @LeagueId = 78368, @Bettype = 614, @BetChoice = N'a5-8', @LiveType = 0
*/  
 
BEGIN 
	SET NOCOUNT ON;
	
	SELECT  P.betid												AS BetId			
		,	P.IsLive											AS IsLive
		,	ISNULL(COUNT(DISTINCT P.MatchId), 0)				AS MatchCount
		,	ISNULL(SUM(P.Turnover), 0)							AS Turnover
		,	ISNULL(SUM(P.WinLoss), 0) - ISNULL(SUM (P.Comm), 0)	AS WinLoss
		,	ISNULL(SUM(P.BetCount), 0)							AS BetCount
		,	CASE WHEN ISNULL(SUM(P.Turnover), 0) <> 0 THEN (ISNULL(SUM(P.WinLoss), 0) - ISNULL(SUM(P.Comm), 0)) * 100/SUM(P.Turnover) ELSE NULL END AS Margin		
	FROM dbo.OSDataTGRS_BetChoice AS P WITH (NOLOCK)
	WHERE P.EventDate BETWEEN @FromDate AND @ToDate
		AND P.SportId = 2
		AND	P.BettypeId = @Bettype 
		AND P.LeagueId = @LeagueId
		AND P.BetChoice = @BetChoice
		AND (@LiveType = -1 OR P.IsLive = @LiveType)
	GROUP BY P.betid, P.BetChoice, P.IsLive;
END;

GO
/*<info serverAlias="DBTGRS-bodb_TGRS" executers="bodbTGRSNet" isFunction="0" isNested="0"></info>*/