ALTER PROCEDURE [dbo].[TGRS_BenchmarkLeague_ProfitMargin]
	@LeagueId INT	 
/*
Created: 20140513@Sophia
Task : Benchmark by League - Profit Margin
DB: DBTGRS.bodb_TGRS

Revisions:

Explanation : 
	
   
*/ 

AS
BEGIN
	SET NOCOUNT ON 	
	
	DECLARE @Year INT, @FromDate DATE, @ToDate DATE
	SELECT @Year = YEAR(GETDATE())

	SELECT @FromDate = DATEADD(yy,@Year-3 -1900,0), @ToDate = DATEADD(yy,@Year-1 -1899,-1)
	
	SELECT  P.LeagueId, YEAR(P.EventDate) AS Year, CASE WHEN SUM(P.Stake) <> 0 THEN (SUM(P.WinLost)-SUM(P.Comm))/SUM(P.Stake) ELSE NULL END AS Margin 
	FROM	dbo.SummaryByLeague_Monthly P WITH (NOLOCK)  
	WHERE	P.LeagueId = @LeagueId
			AND P.EventDate BETWEEN @FromDate AND @ToDate	
	GROUP BY P.LeagueId, YEAR(P.EventDate)
	ORDER BY Year DESC 		 

END
 
GO
GRANT EXECUTE ON [dbo].[TGRS_BenchmarkLeague_ProfitMargin] TO [bodbTGRSNet]
GO
	
