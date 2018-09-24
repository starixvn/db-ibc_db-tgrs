/****** Object:  Stored Procedure dbo.TGRS_Rpt_PerformanceDetail_League    Script Date: 2/24/2016 2:51:26 PM ******/
ALTER PROCEDURE [dbo].[TGRS_Rpt_PerformanceDetail_League]  	
	@FromDate		DATE,
	@ToDate			DATE,
	@LeagueName		NVARCHAR(100)= '',
	@Turnover		MONEY = NULL,
	@WinLoss		MONEY = NULL,
	@MarginFrom		MONEY = NULL,
	@MarginTo		MONEY = NULL,
	@Bettypes		VARCHAR(2000) =  '0',
	@IsExcludeLeagues	BIT = 1
AS    
/*  
 Created:	20160216@Long.Luu
 Task :		Detail report - League Performance
 DB:		DBTGRS.bodb_TGRS
 Original:  
 
 Revisions:      	
 	- 20171019@Simon: Change VARCHAR(200) to VARCHAR(2000)
	- 20171205@Simon: get only Live data & Bettypes are not disabled
	- 20180912@Simon: add league exclusion

 Param's Explanation:  	

 Exam: 
	  	  EXEC  TGRS_Rpt_PerformanceDetail_League @FromDate = '2014-01-01', @ToDate= '2014-05-30' 
  
*/  
 
BEGIN 
	SET NOCOUNT ON;

	DECLARE @BettypeList AS TABLE (bettype SMALLINT);

	IF @Bettypes <> '0'
		INSERT INTO @BettypeList
		SELECT val 
		FROM dbo.strSplit_Key(@Bettypes,',');
	ELSE 
		INSERT INTO @BettypeList
		SELECT Bettype 
		FROM dbo.Bettype WITH (NOLOCK);
	
	IF (@LeagueName IS NULL OR @LeagueName = '')
		BEGIN
			SELECT *, CASE WHEN p.Turnover <> 0  THEN  p.WinLoss * 100 /p.Turnover ELSE NULL END  as margin
			FROM 
				(SELECT P.LeagueId , 
						L.LeagueName, 
						ISNULL(COUNT(DISTINCT P.CustId),0) AS TraderCount, 
						ISNULL(COUNT(DISTINCT P.MatchId),0) AS MatchCount, 
						ISNULL(SUM(P.Stake),0) AS Turnover, 
						ISNULL(SUM(P.WinLost),0) - ISNULL(SUM (P.Comm),0) AS WinLoss, 
						ISNULL(SUM (BetCount),0) AS BetCount
					FROM dbo.TraderPerformance P WITH (NOLOCK)
						INNER JOIN bodb02.dbo.League L WITH (NOLOCK) ON P.LeagueId = L.LeagueId
					WHERE P.EventDate BETWEEN @FromDate AND @ToDate
						AND P.Bettype IN (SELECT Bettype FROM @BettypeList)
						AND P.IsLive = 1
						AND (@IsExcludeLeagues = 0 OR (L.LeagueId NOT IN (SELECT le.LeagueId FROM dbo.LeagueExclusion le WITH(NOLOCK))))
					GROUP BY P.LeagueId , L.LeagueName 
				) AS p 
			WHERE  (@WinLoss IS NULL  OR P.WinLoss >= @WinLoss)
				AND ( @Turnover IS NULL OR p.Turnover >= @Turnover)
				AND ( @MarginFrom IS NULL  OR (Turnover <> 0 and  p.WinLoss * 100 /p.Turnover  >= @MarginFrom))
				AND ( @MarginTo IS NULL OR (Turnover <> 0 and  p.WinLoss * 100 /p.Turnover <= @MarginTo))
			ORDER BY Margin DESC, P.LeagueName ASC;
		END;
	ELSE
		BEGIN
			SELECT *, CASE WHEN p.Turnover <> 0  THEN  p.WinLoss * 100 /p.Turnover ELSE NULL END  as margin
			FROM 
				(SELECT P.LeagueId , 
						L.LeagueName, 
						ISNULL(COUNT(DISTINCT P.CustId),0) AS TraderCount, 
						ISNULL(COUNT(DISTINCT P.MatchId),0) AS MatchCount, 
						ISNULL(SUM(P.Stake),0) AS Turnover, 
						ISNULL(SUM(P.WinLost),0) - ISNULL(SUM (P.Comm),0) AS WinLoss, 
						ISNULL(SUM (BetCount),0) AS BetCount
					FROM dbo.TraderPerformance P WITH (NOLOCK)
						INNER JOIN bodb02.dbo.League L WITH (NOLOCK) ON P.LeagueId = L.LeagueId
					WHERE P.EventDate BETWEEN @FromDate AND @ToDate
						AND P.Bettype IN (SELECT Bettype FROM @BettypeList)
						AND L.LeagueName LIKE '%' + @LeagueName + '%'
						AND P.IsLive = 1
						AND (@IsExcludeLeagues = 0 OR (L.LeagueId NOT IN (SELECT le.LeagueId FROM dbo.LeagueExclusion le WITH(NOLOCK))))
					GROUP BY P.LeagueId , L.LeagueName 
				) AS p 
			WHERE  (@WinLoss IS NULL  OR P.WinLoss >= @WinLoss)
				AND ( @Turnover IS NULL OR p.Turnover >= @Turnover)
				AND ( @MarginFrom IS NULL  OR (Turnover <> 0 and  p.WinLoss * 100 /p.Turnover  >= @MarginFrom))
				AND ( @MarginTo IS NULL OR (Turnover <> 0 and  p.WinLoss * 100 /p.Turnover <= @MarginTo))
			ORDER BY Margin DESC, P.LeagueName ASC;
		END;
END;

GO
/*<info serverAlias="DBTGRS-bodb_TGRS" executers="bodbTGRSNet" isFunction="0" isNested="0"></info>*/