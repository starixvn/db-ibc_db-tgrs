ALTER PROCEDURE [dbo].[TGRS_BenchmarkLeague_ProfitMargin]
	@LeagueId INT	 
/*
Created: 20140513@Sophia
Task : Benchmark by League - Profit Margin
DB: DBTGRS.bodb_TGRS

Revisions:
	- 20140728@Sophia: average Margin of 3 years -> yesterday
	- 20190919@John.Ngo:	Only Support Live Data [Redmine ID: 118959]

Explanation :
   
*/ 

AS
BEGIN
	SET NOCOUNT ON 	
	
	DECLARE @Year INT, @FromDate DATE, @ToDate DATE
	SELECT @Year = YEAR(GETDATE())

	SELECT @FromDate = DATEADD(yy,@Year-3 -1900,0), @ToDate = DATEADD(dd, -1 ,getdate())
	
	SELECT  P.LeagueId, YEAR(P.EventDate) AS Year, CASE WHEN SUM(P.Stake) <> 0 THEN (SUM(P.WinLost)-SUM(P.Comm)) *100/SUM(P.Stake) ELSE NULL END AS Margin 
	FROM	dbo.SummaryByLeague_Monthly P WITH (NOLOCK)  
	WHERE	P.LeagueId = @LeagueId
			AND P.EventDate BETWEEN @FromDate AND @ToDate	
			AND P.IsLive = 1
	GROUP BY P.LeagueId, YEAR(P.EventDate)
	ORDER BY Year DESC 		 

END
 
GO
/*<info serverAlias="DBTGRS-bodb_TGRS" executers="bodbTGRSNet" isFunction="0" isNested="0"></info>*/
