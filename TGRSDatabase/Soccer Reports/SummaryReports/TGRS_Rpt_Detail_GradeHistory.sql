ALTER PROCEDURE [dbo].[TGRS_Rpt_Detail_GradeHistory]  
		@CustId				INT
	,	@TeamId				SMALLINT = 0
	,	@FromDate			DATE
	,	@ToDate				DATE
	,	@LeagueId			INT = 0
	,	@Bettypes			VARCHAR(2000) = '0'
	,	@BetTypeBMFrom		MONEY = NULL
	,	@BetTypeBMTo		MONEY = NULL
	,	@IsExcludeLeagues	BIT = 1
	,	@Market				SMALLINT = 1
AS    
/*  
 Created:	20140523@Sophia
 Task :		Detail of grade History
 DB:		DBTGRS.bodb_TGRS
 Original:  
  
 Revisions: 
	- 20140728@Sophia:	Change Benchmark to percentage instead of decimal number		     
   	- 20171019@Simon:	Change VARCHAR(200) to VARCHAR(2000)
	- 20180911@Long:	Support excluding Leagues from report [Redmine ID: #100322]
	- 20190919@John.Ngo:	Support Nonlive Data [Redmine ID: 118959]

 Param's Explanation (filtered by):
	- @Market:	-1 All; 0 Nonlive; 1 Live
	 
 Exam: 
	EXEC TGRS_Rpt_Detail_GradeHistory @CustId= 2843, @FromDate = '2014-01-01', @ToDate ='2015-01-18'	 
*/   
BEGIN 
	SET NOCOUNT ON;
	
	SELECT	@TeamId = ISNULL(@TeamId,0)
		,	@LeagueId = ISNULL(@LeagueId, 0)
		,	@Bettypes = ISNULL(@Bettypes, 0);

	DECLARE @BettypeList AS TABLE (bettype SMALLINT)
	IF @Bettypes <> '0'
		INSERT INTO @BettypeList
		SELECT val 
		FROM dbo.strSplit_Key(@Bettypes,',');
	ELSE 
		INSERT INTO @BettypeList
		SELECT Bettype 
		FROM dbo.Bettype WITH (NOLOCK);
	
	IF @IsExcludeLeagues = 0
	BEGIN
		SELECT  P.CustId, P.Grade, GH.BeginDate AS GradeEffectiveDate, 
				ISNULL(COUNT(DISTINCT P.MatchID),0) AS MatchCount, 
				ISNULL(SUM(P.Betcount),0) as Betcount,
				ISNULL(SUM(P.Stake),0) AS Turnover, 
				ISNULL(SUM(P.WinLost),0) - ISNULL(SUM(P.Comm),0) AS WinLost, 
				CASE WHEN ISNULL(SUM(P.Stake),0) <> 0 THEN (ISNULL(SUM(P.WinLost),0) - ISNULL(SUM(P.Comm),0)) * 100/ISNULL(SUM(P.Stake),0) ELSE NULL END AS Margin,
				P.IsLive
		FROM	dbo.TraderPerformance P WITH (NOLOCK) 
			LEFT JOIN dbo.TraderGrade_History GH WITH (NOLOCK)
				ON  P.EventDate BETWEEN ISNULL(GH.BeginDate,'1900-01-01') AND ISNULL(GH.EndDate,'9999-12-31')
					AND P.Grade = GH.Grade
					AND P.CustId = GH.CustId
			LEFT JOIN dbo.Benchmark_BetType BT WITH (NOLOCK)
				 ON BT.LeagueId = P.LeagueId
					AND BT.BetType = P.BetType
					AND BT.WorkShift = P.WorkShift
		WHERE	P.CustId = @CustId	
				AND P.EventDate BETWEEN @FromDate AND @ToDate
				AND P.LeagueId = CASE WHEN @LeagueId <> 0 THEN @LeagueId ELSE P.LeagueId END
				AND P.TeamId = CASE WHEN @TeamId <> 0 THEN @TeamId ELSE P.TeamId END
				AND P.Bettype IN (SELECT Bettype FROM @BettypeList)
				AND (@Market = -1 OR P.IsLive = @Market)			 
				AND ISNULL(BT.Benchmark,0) * 100 >= CASE WHEN @BetTypeBMFrom IS NULL THEN ISNULL(BT.Benchmark,0) * 100 ELSE @BetTypeBMFrom END 
				AND ISNULL(BT.Benchmark,0) * 100 <= CASE WHEN @BetTypeBMTo IS NULL THEN ISNULL(BT.Benchmark,0) * 100 ELSE @BetTypeBMTo END 
		GROUP BY P.CustId, P.Grade, GH.BeginDate, P.IsLive 
		ORDER BY GH.BeginDate;
	END
	ELSE
	BEGIN
		SELECT  P.CustId, P.Grade, GH.BeginDate AS GradeEffectiveDate, 
				ISNULL(COUNT(DISTINCT P.MatchID),0) AS MatchCount, 
				ISNULL(SUM(P.Betcount),0) as Betcount,
				ISNULL(SUM(P.Stake),0) AS Turnover, 
				ISNULL(SUM(P.WinLost),0) - ISNULL(SUM(P.Comm),0) AS WinLost, 
				CASE WHEN ISNULL(SUM(P.Stake),0) <> 0 THEN (ISNULL(SUM(P.WinLost),0) - ISNULL(SUM(P.Comm),0)) * 100/ISNULL(SUM(P.Stake),0) ELSE NULL END AS Margin,
				P.IsLive
		FROM	dbo.TraderPerformance P WITH (NOLOCK) 
			LEFT JOIN dbo.TraderGrade_History GH WITH (NOLOCK)
				ON  P.EventDate BETWEEN ISNULL(GH.BeginDate,'1900-01-01') AND ISNULL(GH.EndDate,'9999-12-31')
					AND P.Grade = GH.Grade
					AND P.CustId = GH.CustId
			LEFT JOIN dbo.Benchmark_BetType BT WITH (NOLOCK)
				ON BT.LeagueId = P.LeagueId
					AND BT.BetType = P.BetType
					AND BT.WorkShift = P.WorkShift			
			LEFT JOIN dbo.LeagueExclusion AS le WITH(NOLOCK) ON P.LeagueId = le.LeagueId
		WHERE	P.CustId = @CustId	
				AND P.EventDate BETWEEN @FromDate AND @ToDate
				AND P.LeagueId = CASE WHEN @LeagueId <> 0 THEN @LeagueId ELSE P.LeagueId END
				AND le.LeagueId IS NULL
				AND P.TeamId = CASE WHEN @TeamId <> 0 THEN @TeamId ELSE P.TeamId END
				AND P.Bettype IN (SELECT Bettype FROM @BettypeList)
				AND (@Market = -1 OR P.IsLive = @Market)			 
				AND ISNULL(BT.Benchmark,0) * 100 >= CASE WHEN @BetTypeBMFrom IS NULL THEN ISNULL(BT.Benchmark,0) * 100 ELSE @BetTypeBMFrom END 
				AND ISNULL(BT.Benchmark,0) * 100 <= CASE WHEN @BetTypeBMTo IS NULL THEN ISNULL(BT.Benchmark,0) * 100 ELSE @BetTypeBMTo END 
		GROUP BY P.CustId, P.Grade, GH.BeginDate, P.IsLive 
		ORDER BY GH.BeginDate;
	END;	 
END 

GO
/*<info serverAlias="DBTGRS-bodb_TGRS" executers="bodbTGRSNet" isFunction="0" isNested="0"></info>*/