
/****** Object:  Stored Procedure dbo.TGRS_Rpt_NewPerformanceDetail_Team    Script Date: 1/17/2017 11:20:01 AM ******/

/****** Object:  Stored Procedure dbo.TGRS_Rpt_PerformanceDetail_Team    Script Date: 3/23/2016 11:22:29 PM ******/
/****** Object:  Stored Procedure dbo.TGRS_Rpt_PerformanceDetail_Team    Script Date: 3/22/2016 12:48:52 PM ******/
CREATE PROCEDURE [dbo].[TGRS_Rpt_NewPerformanceDetail_Team] 
	 @FromDate DATE
	,@ToDate DATE
	,@TeamIds VARCHAR(200) = '0'
AS
/*  
	Created:	20170111@Aaron
	Task :		New Performance Detail Report - Team
	DB:			DBTGRS.bodb_TGRS
	Original:  
	 
	Revisions:
		- 20170316@Long: apply TO's Leftover

	Param's Explanation:  	
	
	Example: 	
				EXECUTE	TGRS_Rpt_NewPerformanceDetail_Team 
					@FromDate = '2016-02-22'
				,	@ToDate = '2016-03-14'
				,	@TeamIds = '0'

*/
BEGIN
	SET NOCOUNT ON;

	CREATE TABLE #ScoreDetail (
		CustID INT
		,WinLoss MONEY
		,SumCategory MONEY
		);

	DECLARE @TeamList TABLE (TeamId SMALLINT);
	DECLARE @Team TABLE (
		TeamId SMALLINT
		,TeamName NVARCHAR(50)
		,TraderCount INT
		,LeagueCount INT
		,MatchCount INT
		,Turnover MONEY
		,TurnoverJuice MONEY
		,Juice MONEY
		,WinLoss MONEY
		,BetCount INT
		,Score MONEY
		);

	IF @TeamIds <> '0'
		INSERT INTO @TeamList (TeamId)
		SELECT ssk.val
		FROM dbo.strSplit_Key(@TeamIds, ',') ssk;
	ELSE
		INSERT INTO @TeamList (TeamId)
		SELECT t.TeamId
		FROM dbo.Team AS t WITH (NOLOCK);

	INSERT INTO #ScoreDetail (
		CustID
		,WinLoss
		,SumCategory
		)
	SELECT tp.CustId
		,ISNULL(SUM(tp.WinLost), 0) - ISNULL(SUM(tp.Comm), 0) AS WinLoss
		,ISNULL(SUM(tp.StakeMYR * ISNULL(s.BenchMark, tp.Spread * tm.Rate)), 0) AS SumCategory
	FROM dbo.TraderPerformance AS tp WITH (NOLOCK)
	INNER JOIN dbo.TargetedMargin AS tm WITH (NOLOCK) ON tm.BetType = tp.BetType
		AND tm.WorkShift = tp.WorkShift
	LEFT JOIN dbo.Benchmark_SpecialSetting AS s WITH (NOLOCK) ON s.Spread = tp.Spread
		AND s.Rate = tm.Rate
	LEFT JOIN dbo.BetType TN WITH (NOLOCK) ON TN.BetType = tp.BetType
	WHERE tp.EventDate BETWEEN @FromDate
			AND @ToDate
		AND TN.MainDBBetType IN (1,3,7,8)
		AND TN.[Disabled] = 0
		AND tp.IsLive = 1
	GROUP BY tp.CustId;

	WITH TeamDetail
	AS (
		SELECT t.TeamId
			,COUNT(DISTINCT tp.CustId) AS TraderCount
			,COUNT(DISTINCT tp.LeagueId) AS LeagueCount
			,COUNT(DISTINCT tp.MatchId) AS MatchCount
			,ISNULL(SUM(tp.StakeMYR), 0) AS Turnover
		,ISNULL(SUM(tp.StakeMYRJuice), 0) AS TurnoverJuice
		,ISNULL(SUM(tp.Juice), 0) AS Juice
			,ISNULL(SUM(tp.WinLost), 0) - ISNULL(SUM(tp.Comm), 0) AS WinLoss
			,ISNULL(SUM(tp.BetCount), 0) AS BetCount
		FROM dbo.TraderPerformance AS tp WITH (NOLOCK)
		INNER JOIN dbo.Trader AS t WITH (NOLOCK) ON t.CustId = tp.CustId
	LEFT JOIN dbo.BetType TN WITH (NOLOCK) ON TN.BetType = tp.BetType
		WHERE tp.EventDate BETWEEN @FromDate
				AND @ToDate
			AND TN.MainDBBetType IN (1,3,7,8)
			AND t.TeamId IN (
				SELECT tl.TeamId
				FROM @TeamList AS tl
				)
		AND TN.[Disabled] = 0
		AND tp.IsLive = 1
		GROUP BY t.TeamId
		)
	INSERT INTO @Team (
		TeamId
		,TeamName
		,TraderCount
		,LeagueCount
		,MatchCount
		,Turnover
		,TurnoverJuice
		,Juice
		,WinLoss
		,BetCount
		)
	SELECT td.TeamId
		,t.TeamName
		,td.TraderCount
		,td.LeagueCount
		,td.MatchCount
		,td.Turnover
		,td.TurnoverJuice
		,td.Juice
		,td.WinLoss
		,td.BetCount
	FROM TeamDetail td
	INNER JOIN dbo.Team AS t WITH (NOLOCK) ON t.TeamId = td.TeamId;
	
	WITH score AS (
			SELECT t.TeamId
				,AVG(CASE 
						WHEN sd.SumCategory = 0
							THEN NULL
						ELSE sd.WinLoss * 100 / sd.SumCategory
						END) AS Score
			FROM #ScoreDetail AS sd WITH (NOLOCK)
			INNER JOIN dbo.Trader AS t WITH (NOLOCK) ON t.CustId = sd.CustID
			GROUP BY t.TeamId
			)

	UPDATE t
	SET t.Score = s.Score
	FROM @Team AS t
	INNER JOIN score AS s ON s.TeamId = t.TeamId;

	SELECT t.TeamId
		,t.TeamName
		,t.TraderCount
		,t.LeagueCount
		,t.MatchCount
		,t.Turnover
		,t.TurnoverJuice
		,t.Juice
		,t.WinLoss
		,t.BetCount
		,t.Score
	FROM @Team AS t

	DROP TABLE #ScoreDetail;
END;
/*
GO
GRANT EXECUTE ON [dbo].[TGRS_Rpt_NewPerformanceDetail_Team] TO [bodbTGRSNet]
GO
GRANT VIEW DEFINITION ON [dbo].[TGRS_Rpt_NewPerformanceDetail_Team] TO [bodbTGRSNet ]
GO
*/