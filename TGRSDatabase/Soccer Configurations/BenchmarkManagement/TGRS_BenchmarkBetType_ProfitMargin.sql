ALTER PROCEDURE [dbo].[TGRS_BenchmarkBetType_ProfitMargin]
	@LeagueId	INT	,
	@BetType	SMALLINT,
	@Type		SMALLINT = 2 
/*
Created: 20140513@Sophia
Task : Benchmark by BetType - Profit Margin
DB: DBTGRS.bodb_TGRS

Revisions:
	- 20140728@Sophia:		Calculate average Margin of 3 years -> yesterday
	- 20190919@John.Ngo:	Only Support Live Data [Redmine ID: 118959]

Explanation : 
	@Type : 2 = Last 2 years 
			3 =  Last 3 years
			4 =  Last 4 years

Exam:
	EXEC TGRS_BenchmarkBetType_ProfitMargin @LeagueId = -1, @BetType = 1, @Type = 2
   
*/ 

AS
BEGIN
	SET NOCOUNT ON 		 

	DECLARE @Year INT, @ToDate DATE, @FromDate DATE 

	SELECT @Year = YEAR(GETDATE())
	SELECT @ToDate = DATEADD(dd, -1 ,getdate())

	IF @Type = 2 
		SELECT @FromDate = DATEADD(yy,@Year-1 -1900,0)
	ELSE IF @Type = 3
		SELECT @FromDate = DATEADD(yy,@Year-2 -1900,0)
	ELSE IF @Type = 4 
		SELECT @FromDate = DATEADD(yy,@Year-3 -1900,0)

		

	SELECT  P.LeagueId, P.BetType, P.WorkShift, 
			YEAR(P.EventDate) AS Year,
			ISNULL(SUM(P.WinLost)-SUM(P.Comm),0) AS WinLoss,
			ISNULL(SUM(P.Stake),0) AS Stake, 
			CASE WHEN ISNULL(SUM(P.Stake),0) <> 0 THEN ISNULL(SUM(P.WinLost)-SUM(P.Comm),0) * 100 /SUM(P.Stake) ELSE NULL END AS Margin 

	FROM	dbo.SummaryByBetType_Monthly P WITH (NOLOCK)  
	WHERE	P.LeagueId = @LeagueId
			AND P.BetType = @BetType
			AND P.EventDate BETWEEN @FromDate AND @ToDate
			AND P.IsLive = 1
	GROUP BY P.LeagueId, P.BetType, P.WorkShift, YEAR(P.EventDate)
	ORDER BY Year DESC, WorkShift		 

END
 
GO
/*<info serverAlias="DBTGRS-bodb_TGRS" executers="bodbTGRSNet" isFunction="0" isNested="0"></info>*/
