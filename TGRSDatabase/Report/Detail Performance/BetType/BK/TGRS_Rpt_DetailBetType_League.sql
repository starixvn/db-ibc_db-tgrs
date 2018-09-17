
USE [bodb_TGRS]
GO
/****** Object:  StoredProcedure [dbo].[TGRS_Rpt_DetailBetType_League]    Script Date: 6/18/2014 2:49:19 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[TGRS_Rpt_DetailBetType_League]  	
	@FromDate				DATE,
	@ToDate					DATE,
	@BetTypeBMFrom			MONEY = NULL,
	@BetTypeBMTo			MONEY = NULL,
	@Bettype				SMALLINT,
	@IsExcludeLeagues		BIT = 1
AS
/*  
 Created:	20140619@Tom.Vo
 Task :		Detail report League Performance - Detail League
 DB:		DBTGRS.bodb_TGRS
 Original:  
  
 Revisions:      
	- 20140728@Sophia:	Change Benchmark to percentage instead of decimal number
   	- 20141209@Sophia:	Get Benchmark by Workshift		
	- 20180911@Long:	Support excluding Leagues from report [Redmine ID: #100322]

 Param's Explanation:  	
	
EXEC  [dbo].[TGRS_Rpt_DetailBetType_League]   @FromDate='2014-06-03 00:00:00'
	,@Bettype=-5,@ToDate='2014-06-17 00:00:00'
 Exam: 
	  
*/  
 
BEGIN 
	SET NOCOUNT ON; 

	SELECT P.LeagueId , L.LeagueName, 
		MAX(CASE WHEN ISNULL(BL.WorkShift,0) = 1 THEN ISNULL(BL.Benchmark,0) * 100 ELSE 0 END) AS BetTypeBMShift1,
		MAX(CASE WHEN ISNULL(BL.WorkShift,0) = 2 THEN ISNULL(BL.Benchmark,0) * 100 ELSE 0 END) AS BetTypeBMShift2,
		MAX(CASE WHEN ISNULL(BL.WorkShift,0) = 3 THEN ISNULL(BL.Benchmark,0) * 100 ELSE 0 END) AS BetTypeBMShift3,
		ISNULL(COUNT(DISTINCT P.CustId),0) AS TraderCount, 
		ISNULL(COUNT(DISTINCT P.MatchId),0) AS MatchCount, 
		ISNULL(SUM(P.Stake),0) AS Turnover, 
		ISNULL(SUM(P.WinLost),0) - ISNULL(SUM (P.Comm),0) AS WinLost, 
		ISNULL(SUM (BetCount),0) AS BetCount,
		CASE WHEN ISNULL(SUM(P.Stake),0) <> 0 THEN (ISNULL(SUM(P.WinLost),0) - ISNULL(SUM(P.Comm),0)) * 100/ISNULL(SUM(P.Stake),0) ELSE NULL END AS Margin	
	FROM	dbo.TraderPerformance P WITH (NOLOCK)
	INNER JOIN bodb02.dbo.League L WITH (NOLOCK) 
			ON P.LeagueId = L.LeagueId	 
	LEFT JOIN dbo.Benchmark_BetType BL WITH (NOLOCK)
			ON BL.LeagueId = P.LeagueId 
			AND BL.BetType = P.Bettype 
			AND BL.WorkShift = P.WorkShift
	WHERE	P.EventDate BETWEEN @FromDate AND @ToDate			
		AND P.Bettype = @Bettype
		AND ISNULL(BL.Benchmark,0) * 100 >= CASE WHEN @BetTypeBMFrom IS NULL THEN ISNULL(BL.Benchmark,0) * 100 ELSE @BetTypeBMFrom END 
		AND ISNULL(BL.Benchmark,0) * 100 <= CASE WHEN @BetTypeBMTo IS NULL THEN ISNULL(BL.Benchmark,0) * 100 ELSE @BetTypeBMTo END 
		AND (@IsExcludeLeagues = 0 OR (P.LeagueId NOT IN (SELECT le.LeagueId FROM dbo.LeagueExclusion le WITH(NOLOCK))))
	GROUP BY P.LeagueId , L.LeagueName;
END 

GO

GO
/*<info serverAlias="DBTGRS-bodb_TGRS" executers="bodbTGRSNet" isFunction="0" isNested="0"></info>*/