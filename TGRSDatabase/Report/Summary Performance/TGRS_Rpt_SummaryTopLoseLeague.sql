ALTER PROCEDURE [dbo].[TGRS_Rpt_SummaryTopLoseLeague]  
	@ReportType		TINYINT = 1,
	@FromDate		DATE,
	@ToDate			DATE,
	@ViewPermission TINYINT = 0
AS    
/*  
 Created:	20140520@Sophia
 Task :		Summary report - Top 5 Winning Leagues
 DB:		DBTGRS.bodb_TGRS
 Original:  
  
 Revisions:     
			20160322@Aaron: changed WinLost to WinLoss 
			20171025@Harvey: add @ViewPermission param for data permission
   			
 Param's Explanation:  
	@ReportType = 1: by Date
			 = 2: By Month
			 = 3: By Year

	@ViewPermission = 0: all bet types
			 = 1: major bet types
			 = 2: PHAIO bet types

 Exam: 
	EXEC TGRS_Rpt_SummaryTopLoseLeague @FromDate = '2014-05-01', @ToDate = '2014-05-20' 
  
*/  
 select top 10 * from bodb02.dbo.League L
BEGIN 
	SET NOCOUNT ON  
	IF @ReportType	= 1 --- by date
	BEGIN 	
		SELECT  TOP 5 L.LeagueId, L.LeagueName,
				ISNULL(SUM(Stake),0) AS Turnover, 
				ISNULL(SUM(WinLost),0) - ISNULL(SUM(Comm),0) AS WinLoss, 
				CASE WHEN  ISNULL(SUM(Stake),0) <> 0 THEN (ISNULL(SUM(WinLost),0) - ISNULL(SUM(Comm),0)) * 100/ISNULL(SUM(Stake),0) ELSE NULL END AS Margin 												
		FROM	dbo.SummaryByLeague_Daily S WITH (NOLOCK)
			INNER JOIN	bodb02.dbo.League L WITH (NOLOCK) 
					ON	S.LeagueId = L.LeagueId
		WHERE	 S.EventDate BETWEEN @FromDate AND @ToDate 
					AND (@ViewPermission = 0 OR BettypeGroup = @ViewPermission)
		GROUP BY L.LeagueId, L.LeagueName
		ORDER BY Margin ASC, WinLoss ASC, Turnover ASC
	END
	ELSE
	BEGIN 
		SELECT  TOP 5 L.LeagueId, L.LeagueName,
				ISNULL(SUM(Stake),0) AS Turnover,  
				ISNULL(SUM(WinLost),0) -  ISNULL(SUM(Comm),0) AS WinLoss, 
				CASE WHEN  ISNULL(SUM(Stake),0) <> 0 THEN (ISNULL(SUM(WinLost),0) - ISNULL(SUM(Comm),0)) * 100 /ISNULL(SUM(Stake),0) ELSE NULL END AS Margin 
		FROM	dbo.SummaryByLeague_Monthly S WITH (NOLOCK)
			INNER JOIN	bodb02.dbo.League L WITH (NOLOCK) 
					ON	S.LeagueId = L.LeagueId
		WHERE	 S.EventDate BETWEEN @FromDate AND @ToDate	
					AND (@ViewPermission = 0 OR BettypeGroup = @ViewPermission)
		GROUP BY L.LeagueId, L.LeagueName
		ORDER BY Margin ASC, WinLoss ASC, Turnover ASC

	END
END
GO
GRANT EXECUTE ON [dbo].[TGRS_Rpt_SummaryTopLoseLeague] TO [bodbTGRSNet]
GO

 