 
ALTER PROCEDURE [dbo].[TGRS_BenchmarkTeam_ProfitMargin]
	@TeamId INT	 
/*
Created: 20140513@Sophia
Task : Benchmark by Team - Profit Margin
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

 
	SELECT  P.TeamId, YEAR(P.EventDate) AS Year, CASE WHEN SUM(P.Stake) <> 0 THEN (SUM(P.WinLost)-SUM(P.Comm))/SUM(P.Stake) ELSE NULL END AS Margin 
	FROM	dbo.SummaryByTeam_Monthly P WITH (NOLOCK)  
	WHERE	P.TeamId = @TeamId
			AND P.EventDate BETWEEN @FromDate AND @ToDate		
	GROUP BY P.TeamId, YEAR(P.EventDate) 
	ORDER BY Year DESC 		 

END
 
GO
GRANT EXECUTE ON [dbo].[TGRS_BenchmarkTeam_ProfitMargin] TO [bodbTGRSNet]
GO
	
