ALTER PROCEDURE [dbo].[TGRS_Rpt_SummaryTopWinLeague]  
	@ReportType	 TINYINT = 1,
	@FromDate	 DATE,
	@ToDate		 DATE	   
AS    
/*  
 Created:	20140520@Sophia
 Task :		Summary report - Top 5 Winning Leagues
 DB:		DBTGRS.bodb_TGRS
 Original:  
  
 Revisions:      
   			
 Param's Explanation:  
	@ReportType = 1: by Date
			 = 2: By Month
			 = 3: By Year

 Exam: 
	EXEC TGRS_Rpt_SummaryTopWinLeague @FromDate = '2014-05-01', @ToDate = '2014-05-20' 
  
*/  
 
BEGIN 
	SET NOCOUNT ON  
	IF @ReportType	= 1 --- by date
	BEGIN 	
		SELECT  TOP 5 L.LeagueId, L.LeagueName, SUM(Stake) AS Turnover , SUM(WinLost)-  SUM(Comm) AS WinLost, CASE WHEN SUM(Stake) <> 0 THEN (SUM(WinLost)-SUM(Comm))/SUM(Stake) ELSE NULL END AS Margin
		FROM	dbo.SummaryByLeague_Daily S WITH (NOLOCK)
			INNER JOIN	bodb02.dbo.League L WITH (NOLOCK) 
					ON	S.LeagueId = L.LeagueId
		WHERE	 S.EventDate BETWEEN @FromDate AND @ToDate				  
		GROUP BY L.LeagueId, L.LeagueName
		ORDER BY Margin DESC, WinLost DESC, Turnover DESC
	END
	ELSE
	BEGIN 
		SELECT  TOP 5 L.LeagueId, L.LeagueName, SUM(Stake) AS Turnover , SUM(WinLost)-  SUM(Comm) AS WinLost, CASE WHEN SUM(Stake) <> 0 THEN (SUM(WinLost)-SUM(Comm))/SUM(Stake) ELSE NULL END AS Margin
		FROM	dbo.SummaryByLeague_Monthly S WITH (NOLOCK)
			INNER JOIN	bodb02.dbo.League L WITH (NOLOCK) 
					ON	S.LeagueId = L.LeagueId
		WHERE	 S.EventDate BETWEEN @FromDate AND @ToDate
		GROUP BY L.LeagueId, L.LeagueName
		ORDER BY Margin DESC, WinLost DESC, Turnover DESC

	END

END 
GO
GRANT EXECUTE ON [dbo].[TGRS_Rpt_SummaryTopWinLeague] TO [bodbTGRSNet]
GO

 