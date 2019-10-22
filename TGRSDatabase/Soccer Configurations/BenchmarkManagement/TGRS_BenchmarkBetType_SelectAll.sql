ALTER PROCEDURE [dbo].[TGRS_BenchmarkBetType_SelectAll]
	@LeagueId	INT
/*
Created: 20140513@Sophia
Task : List of Benchmark by bettype 
DB:  DBTGRS.bodb_TGRS

Revisions:
	- 20140728@Sophia:		Change Benchmark to percentage instead of decimal number		
							Calculate average Margin of 3 years -> yesterday
	- 20141121@Sophia:		Change the calculation of margin
	- 20190919@John.Ngo:	Only Support Live Data [Redmine ID: 118959]

Explanation : 
	
*/ 

AS
BEGIN
	SET NOCOUNT ON 	
	DECLARE @Year INT, @ToDate DATE, @FromDate2 DATE, @FromDate3 DATE, @FromDate4 DATE
	SELECT @Year = YEAR(GETDATE())
	
	SELECT  @ToDate = DATEADD(dd, -1 ,getdate())
 
	SELECT @FromDate2 = DATEADD(yy,@Year-1 -1900,0)
 
	SELECT @FromDate3 = DATEADD(yy,@Year-2 -1900,0)
 
	SELECT @FromDate4 = DATEADD(yy,@Year-3 -1900,0) 


	SELECT	T.BetType, T.TypeName, T.OrderId,
			MAX(ISNULL(P2.Margin,0)) AS Margin2, 
			MAX(ISNULL(P3.Margin,0)) AS Margin3, 
			MAX(ISNULL(P4.Margin,0)) AS Margin4, 
			MAX(CASE WHEN B.WorkShift = 1 THEN B.Benchmark * 100 ELSE 0 END) AS BenchMarkShift1,
			MAX(CASE WHEN B.WorkShift = 2 THEN B.Benchmark * 100 ELSE 0 END) AS BenchMarkShift2,
			MAX(CASE WHEN B.WorkShift = 3 THEN B.Benchmark * 100 ELSE 0 END) AS BenchMarkShift3
	FROM	dbo.BetType T WITH (NOLOCK) 		
		LEFT JOIN	(SELECT  CASE WHEN SUM(P.Stake) <> 0 THEN (SUM(P.WinLost)-SUM(P.Comm)) * 100/SUM(P.Stake) ELSE NULL END AS Margin, P.BetType
					 FROM	dbo.SummaryByBetType_Monthly P WITH (NOLOCK)  
					 WHERE	P.EventDate BETWEEN @FromDate2 AND @ToDate
							AND P.LeagueId = @LeagueId
							AND P.IsLive = 1
					 GROUP BY P.BetType								 
					) P2  
				ON	T.BetType = P2.BetType			 
		LEFT JOIN	(SELECT  CASE WHEN SUM(P.Stake) <> 0 THEN (SUM(P.WinLost)-SUM(P.Comm)) * 100/SUM(P.Stake) ELSE NULL END AS Margin, P.BetType
					 FROM	dbo.SummaryByBetType_Monthly P WITH (NOLOCK)  
					 WHERE	P.EventDate BETWEEN @FromDate3 AND @ToDate
							AND P.LeagueId = @LeagueId
							AND P.IsLive = 1
					 GROUP BY P.BetType							 
					) P3  
				ON	T.BetType = P3.BetType
		LEFT JOIN	(SELECT  CASE WHEN SUM(P.Stake) <> 0 THEN (SUM(P.WinLost)-SUM(P.Comm)) * 100/SUM(P.Stake) ELSE NULL END AS Margin, P.BetType
					 FROM	dbo.SummaryByBetType_Monthly P WITH (NOLOCK)  
					 WHERE	P.EventDate BETWEEN @FromDate4 AND @ToDate
							AND P.LeagueId = @LeagueId
							AND P.IsLive = 1
					 GROUP BY P.BetType							 
					) P4 
				ON	T.BetType = P4.BetType 			
		LEFT JOIN dbo.BenchMark_BetType B WITH (NOLOCK)
				ON	T.BetType = B.BetType 
					AND B.LeagueId = @LeagueId		
		GROUP BY	T.BetType, T.TypeName,T.OrderId					
		ORDER BY 	T.OrderId

END
 
GO
/*<info serverAlias="DBTGRS-bodb_TGRS" executers="bodbTGRSNet" isFunction="0" isNested="0"></info>*/
