
CREATE PROCEDURE [dbo].[TGRS_Rpt_PerformanceDetail_League_Match_Bettype]  	
	@FromDate	DATE,
	@ToDate		DATE,
	@LeagueId	INT,	
	@MatchId	INT,
	@Bettypes	VARCHAR(2000) =  '0'
AS    
/*  
	Created:	20160301@Thai
	Task :		Detail report League Performance - Detail Bettype based on League and Match
	DB:		DBTGRS.bodb_TGRS
	Original:  
  
	Revisions:  
	- 20171019@Simon: Change VARCHAR(200) to VARCHAR(2000)
	- 20171205@Simon: get only Live data & Bettypes are not disabled

	Param's Explanation:  	
	
	Exam: 				
		exec [TGRS_Rpt_PerformanceDetail_League_Match_Bettype] @FromDate='2016-02-15 00:00:00',@LeagueId=30730,@Bettypes='5,1,3', @MatchId=16922489,@ToDate='2016-02-29 00:00:00'	  
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
		
	SELECT	tp.BetType
		,	TN.TypeName		
		,	ISNULL(SUM(tp.Stake), 0)								AS Turnover
		,	ISNULL(SUM(tp.WinLost), 0) - ISNULL(SUM(tp.Comm), 0)	AS WinLoss				
		,	ISNULL(SUM(tp.BetCount), 0)								AS BetCount
		,	CASE	WHEN SUM(tp.Stake) = 0
					THEN NULL
					ELSE (SUM(tp.WinLost) - SUM(tp.Comm)) * 100 / SUM(tp.Stake)
			END														AS Margin
	FROM		dbo.TraderPerformance AS tp WITH (NOLOCK)	
	LEFT JOIN dbo.BetType TN WITH (NOLOCK) ON TN.BetType = tp.BetType
	WHERE	tp.LeagueId = @LeagueId			
		AND tp.MatchId = @MatchId			
		AND tp.EventDate BETWEEN @FromDate AND @ToDate
		AND tp.Bettype IN (SELECT Bettype FROM @BettypeList)		
		AND tp.IsLive = 1
	GROUP BY	tp.BetType, TN.TypeName		
	ORDER BY	Margin DESC;
END

/*
GRANT EXECUTE ON [dbo].[TGRS_Rpt_PerformanceDetail_League_Match_Bettype] TO [bodbTGRSNet]
GRANT VIEW DEFINITION ON [dbo].[TGRS_Rpt_PerformanceDetail_League_Match_Bettype] TO [bodbTGRSNet ]
*/