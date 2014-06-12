 
ALTER PROCEDURE [dbo].[TGRS_BenchmarkLeague_SelectAll]
	@SportType SMALLINT = 1,
	@DisplayMode TINYINT = 0, 
	@ProgramId VARCHAR(10) = '',
	@CountryCode VARCHAR(20) = '',
	@AllMarket BIT = 1,
	@LeagueName NVARCHAR(100) = '' 
/*
Created: 20140513@Sophia
Task : List of Benchmark by League
DB:  DBTGRS.bodb_TGRS

Revisions:

Explanation : 
	
   
*/ 

AS
BEGIN
	SET NOCOUNT ON 	
	DECLARE @Year INT, @FromDate DATE, @ToDate DATE
	SELECT @Year = YEAR(GETDATE())

	SELECT @FromDate = DATEADD(yy,@Year-3 -1900,0), @ToDate = DATEADD(yy,@Year-1 -1899,-1)

	SELECT	L.Leagueid, L.LeagueName, ISNULL(P.Margin,0) AS Margin, ISNULL(B.Benchmark,0) as Benchmark
	FROM	bodb02.dbo.League L WITH (NOLOCK) 
		LEFT JOIN dbo.BenchMark_League B WITH (NOLOCK)
				ON	B.LeagueId = L.LeagueId
		LEFT JOIN	(	SELECT AVG(A.Margin) AS Margin, A.LeagueId
						FROM (
								SELECT  CASE WHEN SUM(P.Stake) <> 0 THEN (SUM(P.WinLost)-SUM(P.Comm))/SUM(P.Stake) * 100 ELSE NULL END AS Margin, P.LeagueId, YEAR(P.EventDate) AS Year  
								FROM	dbo.SummaryByLeague_Monthly P WITH (NOLOCK)  
								WHERE	P.EventDate BETWEEN @FromDate AND @ToDate
								GROUP BY P.LeagueId, YEAR(P.EventDate) 
								) A
						GROUP BY A.LeagueId						 
					) P  
				ON	P.LeagueId = L.LeagueId
	WHERE	L.SportType = @SportType
			AND L.IsActive = 1
			AND L.IsTest = 0
			AND l.DisplayMode = CASE WHEN @DisplayMode = 0 THEN L.DisplayMode ELSE @DisplayMode END 
			AND ISNULL(L.ProgramId,'') = CASE WHEN @ProgramId = '' THEN ISNULL(L.ProgramId,'') ELSE @ProgramId END  
			AND ISNULL(L.CountryCode,'') = CASE WHEN @CountryCode = '' THEN ISNULL(L.CountryCode,'') ELSE @CountryCode END
			AND L.IsMainMarket = CASE WHEN @AllMarket = 1 THEN L.IsMainMarket ELSE 1 END
			AND L.LeagueName LIKE '%'+@LeagueName+'%'					
			
	ORDER BY L.LeagueName

END
 
GO
GRANT EXECUTE ON [dbo].[TGRS_BenchmarkLeague_SelectAll] TO [bodbTGRSNet]
GO
	 