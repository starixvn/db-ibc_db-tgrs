ALTER PROCEDURE [dbo].[TGRS_Rpt_Detail_GradeHistory]  
	@CustId		 INT,
	@TeamId		 SMALLINT = 0,
	@FromDate	 DATE,
	@ToDate		 DATE,
	@LeagueId	 INT = 0, 
	@Bettypes    VARCHAR(200) = '0',
	@BetTypeBMFrom MONEY = NULL,
	@BetTypeBMTo MONEY = NULL
AS    
/*  
 Created:	20140523@Sophia
 Task :		Detail of grade History
 DB:		DBTGRS.bodb_TGRS
 Original:  
  
 Revisions: 
	- 20140728@Sophia: Change Benchmark to percentage instead of decimal number		     
   			
 Param's Explanation:  
	 
 Exam: 
	EXEC TGRS_Rpt_Detail_GradeHistory @CustId= 2843, @FromDate = '2014-01-01', @ToDate ='2015-01-18' 

	 
*/  
 
BEGIN 
	SET NOCOUNT ON 
	
	SELECT @TeamId = ISNULL(@TeamId,0),@LeagueId = ISNULL(@LeagueId,0),	@Bettypes = ISNULL(@Bettypes,0)

	DECLARE @BettypeList AS TABLE (bettype SMALLINT)
	IF @Bettypes <> '0'
		INSERT INTO @BettypeList
		SELECT val FROM dbo.strSplit_Key(@Bettypes,',')
	ELSE 
		INSERT INTO @BettypeList
		SELECT Bettype FROM dbo.Bettype WITH (NOLOCK)
	

	SELECT  P.CustId, P.Grade, GH.BeginDate AS GradeEffectiveDate, 
			ISNULL(COUNT(DISTINCT MatchID),0) AS MatchCount, 
			ISNULL(SUM(Betcount),0) as Betcount,
			ISNULL(SUM(Stake),0) AS Turnover, 
			ISNULL(SUM(WinLost),0) - ISNULL(SUM(Comm),0) AS WinLost, 
			CASE WHEN ISNULL(SUM(P.Stake),0) <> 0 THEN (ISNULL(SUM(P.WinLost),0) - ISNULL(SUM(P.Comm),0)) * 100/ISNULL(SUM(P.Stake),0) ELSE NULL END AS Margin
	FROM	dbo.TraderPerformance P WITH (NOLOCK) 
		LEFT JOIN dbo.TraderGrade_History GH WITH (NOLOCK)
			ON  P.EventDate BETWEEN ISNULL(GH.BeginDate,'1900-01-01') AND ISNULL(GH.EndDate,'9999-12-31')
				AND P.Grade = GH.Grade
				AND P.CustId = GH.CustId
		LEFT JOIN dbo.Benchmark_BetType BT WITH (NOLOCK)
			 ON BT.LeagueId = P.LeagueId
				AND BT.BetType = P.BetType
	WHERE	P.CustId = @CustId	
			AND P.EventDate BETWEEN @FromDate AND @ToDate
			AND P.LeagueId = CASE WHEN @LeagueId <> 0 THEN @LeagueId ELSE P.LeagueId END
			AND P.TeamId = CASE WHEN @TeamId <> 0 THEN @TeamId ELSE P.TeamId END
			AND P.Bettype IN (SELECT Bettype FROM @BettypeList)			 
			AND ISNULL(BT.Benchmark,0) * 100 >= CASE WHEN @BetTypeBMFrom IS NULL THEN ISNULL(BT.Benchmark,0) * 100 ELSE @BetTypeBMFrom END 
			AND ISNULL(BT.Benchmark,0) * 100 <= CASE WHEN @BetTypeBMTo IS NULL THEN ISNULL(BT.Benchmark,0) * 100 ELSE @BetTypeBMTo END 
	GROUP BY P.CustId, P.Grade, GH.BeginDate 
	ORDER BY GH.BeginDate 

	 
END 
GO
GRANT EXECUTE ON [dbo].[TGRS_Rpt_Detail_GradeHistory] TO [bodbTGRSNet]
GO
 
