ALTER PROCEDURE [dbo].[TGRS_BenchmarkTeam_SelectAll]
	 
/*
Created: 20140513@Sophia
Task : List of Benchmark by Team
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
	DECLARE @Year INT, @FromDate DATE, @ToDate DATE
	SELECT @Year = YEAR(GETDATE())

	SELECT @FromDate = DATEADD(yy,@Year-3 -1900,0), @ToDate = DATEADD(dd, -1 ,getdate())


	SELECT	T.TeamId, T.TeamName, ISNULL(P.Margin,0) AS Margin, ISNULL(B.BenchMark,0 ) * 100 AS BenchMark
	FROM	dbo.Team T WITH (NOLOCK) 
		LEFT JOIN dbo.BenchMark_Team B WITH (NOLOCK)
				ON	T.TeamId = B.TeamId
		LEFT JOIN	(		SELECT  CASE WHEN SUM(P.Stake) <> 0 THEN (SUM(P.WinLost)-SUM(P.Comm)) * 100/SUM(P.Stake) ELSE NULL END AS Margin, P.TeamId 
							FROM	dbo.SummaryByTeam_Monthly P WITH (NOLOCK)  
							WHERE	P.EventDate BETWEEN @FromDate AND @ToDate
								AND P.IsLive = 1	
							GROUP BY P.TeamId 								 
					) P  
				ON	T.TeamId = P.TeamId
	ORDER BY T.TeamName

END
 
GO
/*<info serverAlias="DBTGRS-bodb_TGRS" executers="bodbTGRSNet" isFunction="0" isNested="0"></info>*/
