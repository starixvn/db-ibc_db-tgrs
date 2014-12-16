 
ALTER PROCEDURE [dbo].[TGRS_BenchmarkLeague_SelectAll]
	@SportType SMALLINT = 1,
	@DisplayMode TINYINT = 0, 
	@ProgramId VARCHAR(10) = '',
	@CountryCode VARCHAR(20) = '',
	@MainMarket SMALLINT = 1,
	@LeagueName NVARCHAR(100) = '' 
/*
Created: 20140513@Sophia
Task : List of Benchmark by League
DB:  DBTGRS.bodb_TGRS

Revisions:
	- 20140728@Sophia: Change Benchmark to percentage instead of decimal number		
					   Calculate average Margin of 3 years -> yesterday
	- 20141121@Sophia:  Change the param @MainMarket to get Other Market
						Change the calculation of margin
Explanation : 
	@MainMarket =-1: All
				= 1: Main 
				= 0: Other

Test string:
	EXEC TGRS_BenchmarkLeague_SelectAll_Xtest @DisplayMode=0,@CountryCode='',@SportType=1,@ProgramId='',@MainMarket=-1,@LeagueName=N''
   	
   
*/ 

AS
BEGIN
	SET NOCOUNT ON 	
	DECLARE @Year INT, @FromDate DATE, @ToDate DATE
	SELECT @Year = YEAR(GETDATE())

	SELECT @FromDate = DATEADD(yy,@Year-3 -1900,0), @ToDate = DATEADD(dd, -1 ,getdate())

	SELECT	L.Leagueid, L.LeagueName, ISNULL(P.Margin,0) AS Margin, ISNULL(B.Benchmark,0) * 100 as Benchmark
	FROM	bodb02.dbo.League L WITH (NOLOCK) 
		LEFT JOIN dbo.BenchMark_League B WITH (NOLOCK)
				ON	B.LeagueId = L.LeagueId
		LEFT JOIN	(			
						SELECT  CASE WHEN SUM(P.Stake) <> 0 THEN (SUM(P.WinLost)-SUM(P.Comm))* 100/SUM(P.Stake) ELSE NULL END AS Margin, P.LeagueId
						FROM	dbo.SummaryByLeague_Monthly P WITH (NOLOCK)  
						WHERE	P.EventDate BETWEEN @FromDate AND @ToDate
						GROUP BY P.LeagueId												 
					) P  
				ON	P.LeagueId = L.LeagueId
	WHERE	L.SportType = @SportType
			AND L.IsActive = 1
			AND L.IsTest = 0
			AND l.DisplayMode = CASE WHEN @DisplayMode = 0 THEN L.DisplayMode ELSE @DisplayMode END 
			AND ISNULL(L.ProgramId,'') = CASE WHEN @ProgramId = '' THEN ISNULL(L.ProgramId,'') ELSE @ProgramId END  
			AND ISNULL(L.CountryCode,'') = CASE WHEN @CountryCode = '' THEN ISNULL(L.CountryCode,'') ELSE @CountryCode END
			AND L.IsMainMarket = CASE WHEN @MainMarket = -1 THEN L.IsMainMarket ELSE @MainMarket END
			AND L.LeagueName LIKE '%'+@LeagueName+'%'				
	ORDER BY L.LeagueName

END
 
GO
GRANT EXECUTE ON [dbo].[TGRS_BenchmarkLeague_SelectAll] TO [bodbTGRSNet]
GO
	 