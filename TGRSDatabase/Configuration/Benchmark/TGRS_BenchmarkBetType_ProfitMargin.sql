 
ALTER PROCEDURE [dbo].[TGRS_BenchmarkBetType_ProfitMargin]
	@LeagueId	INT	,
	@BetType	SMALLINT
/*
Created: 20140513@Sophia
Task : Benchmark by BetType - Profit Margin
DB: DBTGRS.bodb_TGRS

Revisions:
	- 20140728@Sophia: Calculate average Margin of 3 years -> yesterday
Explanation : 

Exam:
	EXEC TGRS_BenchmarkBetType_ProfitMargin @LeagueId = -1, @BetType = 1
	
   
*/ 

AS
BEGIN
	SET NOCOUNT ON 		 

	DECLARE @Year INT, @FromDate DATE, @ToDate DATE
	SELECT @Year = YEAR(GETDATE())

	SELECT @FromDate = DATEADD(yy,@Year-3 -1900,0),  @ToDate = DATEADD(dd, -1 ,getdate())


	SELECT  P.LeagueId, P.BetType, YEAR(P.EventDate) AS Year,CASE WHEN SUM(P.Stake) <> 0 THEN (SUM(P.WinLost)-SUM(P.Comm)) * 100 /SUM(P.Stake) ELSE NULL END AS Margin 
	FROM	dbo.SummaryByBetType_Monthly P WITH (NOLOCK)  
	WHERE	P.LeagueId = @LeagueId
			AND P.BetType = @BetType
			AND P.EventDate BETWEEN @FromDate AND @ToDate
	GROUP BY P.LeagueId, P.BetType, YEAR(P.EventDate)
	ORDER BY Year DESC 		 

END
 
GO
GRANT EXECUTE ON [dbo].[TGRS_BenchmarkBetType_ProfitMargin] TO [bodbTGRSNet]
GO
	
