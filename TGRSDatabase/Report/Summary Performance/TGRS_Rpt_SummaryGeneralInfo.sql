

ALTER PROCEDURE [dbo].[TGRS_Rpt_SummaryGeneralInfo]  
	@ReportType	 	TINYINT = 2,
	@FromDate	 	DATE,
	@ToDate		 	DATE,
	@ViewPermission SMALLINT
AS    
/*  
 Created:	20140520@Sophia
 Task :		General Info of Summary report
 DB:		DBTGRS.bodb_TGRS
 Original:  
  
 Revisions:      
	- 20140729@Sophia: Change the way to get MatchCount (from TraderPerformance)
   	- 20171024@Simon: Add ViewPermission param	
	- 20171025@Long: Change the way to get MatchCount
		
 Param's Explanation:  
	@ReportType = 1: by Date
			 = 2: By Month
			 = 3: By Year
			 
	@ViewPermission = 0: all bet types
			 = 1: major bet types
			 = 2: PHAIO bet types
 Exam: 
	EXEC TGRS_Rpt_SummaryGeneralInfo @FromDate = '2014-05-01', @ToDate = '2014-05-20', @ViewPermission = 0
	EXEC TGRS_Rpt_SummaryGeneralInfo @FromDate = '2014-02-01', @ToDate = '2014-04-30', @ViewPermission = 1
	EXEC TGRS_Rpt_SummaryGeneralInfo @FromDate = '2012-01-01', @ToDate = '2013-12-31', @ViewPermission = 2
  
*/  
 
BEGIN 
	SET NOCOUNT ON  

	DECLARE @MatchCount BIGINT = 0;

	SELECT @MatchCount = COUNT_BIG(DISTINCT tp.MatchId)
	FROM dbo.TraderPerformance tp WITH(NOLOCK)
		INNER JOIN dbo.BetType b WITH(NOLOCK) ON tp.BetType = b.BetType
	WHERE tp.EventDate BETWEEN @FromDate AND @ToDate
			AND (
					@ViewPermission = 0
					OR b.[BettypeGroup] = @ViewPermission
				)
	
	IF @ReportType	= 2  ---by month 
	BEGIN 
		
		SELECT  ISNULL(SUM(Stake),0) AS Turnover,  
				ISNULL(SUM(WinLost),0) - ISNULL(SUM(Comm),0) AS WinLost,  
				CASE WHEN ISNULL(SUM(Stake),0) <> 0 THEN (ISNULL(SUM(WinLost),0) - ISNULL(SUM(Comm),0)) * 100/ISNULL(SUM(Stake),0) ELSE NULL END AS Margin, 
				@MatchCount AS MatchCount
		FROM	dbo.SummaryByLeague_Monthly WITH (NOLOCK)
		WHERE	
				EventDate BETWEEN @FromDate AND @ToDate	
				AND (
						@ViewPermission = 0
						OR BettypeGroup = @ViewPermission
					)
	END
	ELSE---- by date
	BEGIN 
	
		SELECT  ISNULL(SUM(S.Stake),0) AS Turnover,  
				ISNULL(SUM(S.WinLost),0) - ISNULL(SUM(S.Comm),0) AS WinLost, 
				CASE WHEN ISNULL(SUM(S.Stake),0) <> 0 THEN (ISNULL(SUM(S.WinLost),0) - ISNULL(SUM(S.Comm),0)) * 100/ISNULL(SUM(S.Stake),0) ELSE NULL END AS Margin,
				@MatchCount AS MatchCount
		FROM	dbo.SummaryByLeague_Daily S WITH (NOLOCK)		
		WHERE	S.EventDate BETWEEN @FromDate AND @ToDate
				AND (
						@ViewPermission = 0
						OR BettypeGroup = @ViewPermission
					)		
	END
END 
GO
GRANT EXECUTE ON [dbo].[TGRS_Rpt_SummaryGeneralInfo] TO [bodbTGRSNet]
GO

