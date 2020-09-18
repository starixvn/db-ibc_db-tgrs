ALTER PROCEDURE [dbo].[TGRS_OS_Rpt_SummaryTopSport] 
		@Top		TINYINT  = 10
	,	@IsBottom	BIT		 = 0
	,	@FromDate	DATE
	,	@ToDate		DATE
	,	@LiveType	SMALLINT = 1
AS
/*  
 Created:	20170224@Aaron
 Task :		Summary report - Top Traders
 DB:		DBTGRS.bodb_TGRS
 Original:  
  
 Revisions:      
   		- 20200914@John.Ngo: Support Live/Nonlive for OSDataTGRS [Redmine ID: 140875]
		
 Param's Explanation:
		- @Top		= XX:  Rows to display
		- @IsBottom = 0: List top traders
					= 1: List bottom traders
		- @LiveType: -1 All; 0 Nonlive; 1 Live

 Exam: 
	EXEC TGRS_OS_Rpt_SummaryTopSport @Top = 10, @IsBottom = 0, @FromDate = '2016-01-01', @ToDate = '2017-02-23'
  
*/
BEGIN
	SET NOCOUNT ON;
		
	SET @FromDate = DATEADD(m, DATEDIFF(m, 0, @FromDate), 0);
	SET @ToDate = DATEADD(m, DATEDIFF(m, 0, @ToDate), 0);

	IF ISNULL(@IsBottom, 0) = 0
	BEGIN
		SELECT TOP (@Top) s.SportName AS SportName
			,ISNULL(SUM(tp.Turnover), 0) AS Turnover
			,ISNULL(SUM(tp.WinLoss), 0) - ISNULL(SUM(tp.Comm), 0) AS WinLoss
		FROM dbo.OSSummaryByTrader_Monthly tp WITH (NOLOCK)
		INNER JOIN bodb02.dbo.Sports s WITH(NOLOCK) ON tp.SportId = s.SportType
		WHERE tp.EventDate BETWEEN @FromDate AND @ToDate
			AND (@LiveType = -1 OR tp.IsLive = @LiveType)
		GROUP BY s.SportName
		ORDER BY CASE 
				WHEN ISNULL(SUM(tp.Turnover), 0) <> 0
					THEN (ISNULL(SUM(tp.WinLoss), 0) - ISNULL(SUM(tp.Comm), 0)) / ISNULL(SUM(tp.Turnover), 0)
				ELSE NULL
				END DESC
	END;
	ELSE
	BEGIN
		SELECT TOP (@Top) s.SportName AS SportName
			,ISNULL(SUM(tp.Turnover), 0) AS Turnover
			,ISNULL(SUM(tp.WinLoss), 0) - ISNULL(SUM(tp.Comm), 0) AS WinLoss
		FROM dbo.OSSummaryByTrader_Monthly tp WITH (NOLOCK)
		INNER JOIN bodb02.dbo.Sports s WITH(NOLOCK) ON tp.SportId = s.SportType
		WHERE tp.EventDate BETWEEN @FromDate AND @ToDate
			AND (@LiveType = -1 OR tp.IsLive = @LiveType)
		GROUP BY s.SportName
		ORDER BY CASE 
				WHEN ISNULL(SUM(tp.Turnover), 0) <> 0
					THEN (ISNULL(SUM(tp.WinLoss), 0) - ISNULL(SUM(tp.Comm), 0)) / ISNULL(SUM(tp.Turnover), 0)
				ELSE NULL
				END ASC
	END;
END;

GO
/*<info serverAlias="DBTGRS-bodb_TGRS" executers="bodbTGRSNet" isFunction="0" isNested="0"></info>*/