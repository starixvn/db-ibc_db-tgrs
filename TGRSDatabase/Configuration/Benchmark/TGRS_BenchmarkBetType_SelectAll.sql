 
ALTER PROCEDURE [dbo].[TGRS_BenchmarkBetType_SelectAll]
	@LeagueId	INT
/*
Created: 20140513@Sophia
Task : List of Benchmark by bettype 
DB:  DBTGRS.bodb_TGRS

Revisions:
	 20140728@Sophia: Change Benchmark to percentage instead of decimal number		
					  Calculate average Margin of 3 years -> yesterday
Explanation : 
	
   
*/ 

AS
BEGIN
	SET NOCOUNT ON 	
	DECLARE @Year INT, @FromDate DATE, @ToDate DATE
	SELECT @Year = YEAR(GETDATE())

	SELECT @FromDate = DATEADD(yy,@Year-3 -1900,0),  @ToDate = DATEADD(dd, -1 ,getdate())


	SELECT	T.BetType, T.TypeName, ISNULL(P.Margin,0) AS Margin, ISNULL(B.BenchMark,0) * 100 AS BenchMark
	FROM	dbo.BetType T WITH (NOLOCK) 
		LEFT JOIN dbo.BenchMark_BetType B WITH (NOLOCK)
				ON	T.BetType = B.BetType AND B.LeagueId = @LeagueId
		LEFT JOIN	(	SELECT AVG (A.Margin) AS Margin, A.BetType, A.LeagueId
						FROM (
								SELECT  CASE WHEN SUM(P.Stake) <> 0 THEN (SUM(P.WinLost)-SUM(P.Comm)) * 100/SUM(P.Stake) ELSE NULL END AS Margin, P.BetType, P.LeagueId, YEAR(P.EventDate) AS Year  
								FROM	dbo.SummaryByBetType_Monthly P WITH (NOLOCK)  
								WHERE	P.EventDate BETWEEN @FromDate AND @ToDate
										AND P.LeagueId = @LeagueId
								GROUP BY P.BetType, P.LeagueId, YEAR(P.EventDate)
							) A
						GROUP BY A.BetType, A.LeagueId					 
					) P  
				ON	T.BetType = P.BetType 
	ORDER BY T.OrderId

END
 
GO
GRANT EXECUTE ON [dbo].[TGRS_BenchmarkBetType_SelectAll] TO [bodbTGRSNet]
GO
	 