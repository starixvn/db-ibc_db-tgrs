ALTER PROCEDURE [dbo].[TGRS_Rpt_SummaryTraderPerformace]  
		@ReportType	 TINYINT = 1
	,	@FromDate	 DATE
	,	@ToDate		 DATE
	,	@ViewPermission SMALLINT
	,	@IsExcludeLeagues	BIT = 1
	,	@Market				SMALLINT = 1
AS    
/*  
 Created:	20140520@Sophia
 Task :		Summary report - Top Trader performace
 DB:		DBTGRS.bodb_TGRS
 Original:  
  
	Revisions:      
   		- 20171024@Simon: Add ViewPermission param	
		- 20171205@Simon: get only Live data & Bettypes are not disabled
		- 20180912@Simon: add league exclusion
		- 20190116@John: Fix excluding Leagues from report [Redmine ID: #108008]
		- 20190919@John.Ngo:	Support Nonlive Data [Redmine ID: 118959]
		- 20191023@John.Ngo:	Enhance performance [Redmine ID: 121268]

	Param's Explanation (filtered by):
		- @Market:	-1 All; 0 Nonlive; 1 Live
		- @ReportType = 1: by Date
			 = 2: By Month
			 = 3: By Year
			 
		- @ViewPermission = 0: all bet types
			 = 1: major bet types
			 = 2: PHAIO bet types
 Exam: 
	EXEC TGRS_Rpt_SummaryTraderPerformace @ReportType = 1, @FromDate = '2014-05-01', @ToDate = '2014-05-20'  
*/  
 
BEGIN 
	SET NOCOUNT ON;
	
	DECLARE @Top AS TABLE (CustId INT, Margin MONEY, IsLive BIT); 
	DECLARE @Bottom AS TABLE (CustId INT, Margin MONEY, IsLive BIT); 
	DECLARE @TopMinMargin MONEY, @TopMaxMargin MONEY, @BottomMinMargin MONEY, @BottomMaxMargin MONEY;

	IF @ReportType	= 1 --- By Date
		BEGIN 
			INSERT INTO @Top
			SELECT  TOP 10  P.CustId
				, CASE WHEN ISNULL(SUM(P.Stake),0) <> 0 THEN (ISNULL(SUM(P.WinLost),0) - ISNULL(SUM(P.Comm),0)) *100 /ISNULL(SUM(P.Stake),0)ELSE NULL END AS Margin
				, P.IsLive
			FROM dbo.TraderPerformance P WITH (NOLOCK)
				INNER JOIN dbo.Bettype bt WITH (NOLOCK) ON P.Bettype = bt.Bettype
				LEFT JOIN dbo.LeagueExclusion le WITH(NOLOCK) ON P.LeagueId = le.LeagueId
			WHERE EventDate BETWEEN @FromDate AND @ToDate
				AND (
						@ViewPermission = 0
						OR bt.BettypeGroup = @ViewPermission
					)
				AND bt.[Disabled] = 0
				AND (@Market = -1 OR P.IsLive = @Market)
				AND (@IsExcludeLeagues = 0 OR le.LeagueId IS NULL)
			GROUP BY P.CustId, P.IsLive
			ORDER BY Margin DESC;

			INSERT INTO @Bottom
			SELECT  TOP 10 P.CustId
				, CASE WHEN ISNULL(SUM(P.Stake),0) <> 0 THEN (ISNULL(SUM(P.WinLost),0) - ISNULL(SUM(P.Comm),0)) *100 /ISNULL(SUM(P.Stake),0)  ELSE NULL END AS Margin
				, P.IsLive
			FROM dbo.TraderPerformance P WITH (NOLOCK)			 
				INNER JOIN dbo.Bettype bt WITH (NOLOCK) ON P.Bettype = bt.Bettype
				LEFT JOIN dbo.LeagueExclusion le WITH(NOLOCK) ON P.LeagueId = le.LeagueId
			WHERE EventDate BETWEEN @FromDate AND @ToDate
				AND (
						@ViewPermission = 0
						OR bt.BettypeGroup = @ViewPermission
					)
				AND (@Market = -1 OR P.IsLive = @Market)
				AND bt.[Disabled] = 0
				AND (@IsExcludeLeagues = 0 OR le.LeagueId IS NULL)
			GROUP BY P.CustId, P.IsLive
			ORDER BY Margin ASC;
			
		END;
	ELSE  -- By Month, year
		BEGIN
			INSERT INTO @Top
			SELECT  TOP 10 sm.CustId
				, CASE WHEN ISNULL(SUM(sm.Stake),0) <> 0 THEN (ISNULL(SUM(sm.WinLost),0) - ISNULL(SUM(sm.Comm),0)) *100 /ISNULL(SUM(sm.Stake),0)  ELSE NULL END AS Margin
				, sm.IsLive
			FROM	dbo.SummaryByTrader_Monthly sm WITH (NOLOCK)
				LEFT JOIN dbo.LeagueExclusion le WITH(NOLOCK) ON sm.LeagueId = le.LeagueId		 
			WHERE 	sm.EventDate BETWEEN @FromDate AND @ToDate
				AND (@Market = -1 OR IsLive = @Market)
				AND (
						@ViewPermission = 0
						OR sm.BettypeGroup = @ViewPermission
					)
				AND (@IsExcludeLeagues = 0 OR le.LeagueId IS NULL)
			GROUP BY CustId, IsLive
			ORDER BY Margin DESC

			INSERT INTO @Bottom
			SELECT  TOP 10 sm.CustId
				, CASE WHEN ISNULL(SUM(sm.Stake),0) <> 0 THEN (ISNULL(SUM(sm.WinLost),0) - ISNULL(SUM(sm.Comm),0)) *100 /ISNULL(SUM(sm.Stake),0)  ELSE NULL END AS Margin
				, sm.IsLive
			FROM	dbo.SummaryByTrader_Monthly sm WITH (NOLOCK)
				LEFT JOIN dbo.LeagueExclusion le WITH(NOLOCK) ON sm.LeagueId = le.LeagueId		 
			WHERE 	sm.EventDate BETWEEN @FromDate AND @ToDate
				AND (@Market = -1 OR IsLive = @Market)
				AND (
						@ViewPermission = 0
						OR sm.BettypeGroup = @ViewPermission
					)
				AND (@IsExcludeLeagues = 0 OR le.LeagueId IS NULL)
			GROUP BY sm.CustId, sm.IsLive
			ORDER BY Margin ASC;
		END;

	SELECT @TopMinMargin = MIN(Margin), @TopMaxMargin = MAX(Margin) FROM @Top;
	SELECT @BottomMinMargin = MIN(Margin), @BottomMaxMargin = MAX(Margin) FROM @Bottom; 	
	SELECT @TopMinMargin AS TopMinMargin, @TopMaxMargin AS TopMaxMargin, @BottomMinMargin AS BottomMinMargin, @BottomMaxMargin AS BottomMaxMargin;
END;

GO
/*<info serverAlias="DBTGRS-bodb_TGRS" executers="bodbTGRSNet" isFunction="0" isNested="0"></info>*/