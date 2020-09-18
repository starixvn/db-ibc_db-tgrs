ALTER PROCEDURE [dbo].[TGRS_OS_Rpt_SummaryDataByMonth]
		@FromDate	DATE
	,	@ToDate		DATE
	,	@LiveType	SMALLINT = 1
AS
/*  
 Created:	20170307@Aaron
 Task :		Summary report - Get All data from a range of months
 DB:		DBTGRS.bodb_TGRS
 Original:  
  
 Revisions:      
   		- 20200914@John.Ngo: Support Live/Nonlive for OSDataTGRS [Redmine ID: 140875]

 Param's Explanation:
		- @LiveType: -1 All; 0 Nonlive; 1 Live

 Exam: 
	EXEC TGRS_OS_Rpt_SummaryDataByMonth @FromDate = '2016-01-01', @ToDate = '2017-05-23'
  
*/
BEGIN
	SET NOCOUNT ON;
		
	SET @FromDate = DATEADD(m, DATEDIFF(m, 0, @FromDate), 0);
	SET @ToDate = DATEADD(m, DATEDIFF(m, 0, @ToDate), 0);

	SELECT ISNULL(SUM(tp.MatchCount), 0) AS MatchCount
		,ISNULL(SUM(tp.Turnover), 0) AS Turnover
		,ISNULL(SUM(tp.WinLoss), 0) - ISNULL(SUM(tp.Comm), 0) AS WinLoss
		,tp.EventDate
	FROM dbo.OSSummaryByLeague_Monthly tp WITH (NOLOCK)
	WHERE tp.EventDate BETWEEN @FromDate AND @ToDate
		AND (@LiveType = -1 OR tp.IsLive = @LiveType)
	GROUP BY tp.EventDate;
END;

GO
/*<info serverAlias="DBTGRS-bodb_TGRS" executers="bodbTGRSNet" isFunction="0" isNested="0"></info>*/