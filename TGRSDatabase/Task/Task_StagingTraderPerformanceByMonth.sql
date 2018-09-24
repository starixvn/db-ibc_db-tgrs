
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[Task_StagingTraderPerformanceByMonth]
		@Month					DATE = NULL
	,	@GenerateFromDate		DATE = NULL
	,	@GenerateToDate			DATE = NULL
AS

/*
 Created:	20140604@Tom.Vo
 Task :		Staging Data on TGRS DB By Month
 DB:		DBTGRS.bodb_TGRS
 Original:  
  
 Revisions:      
	- 20141203@Tom.Vo:	Staging data with new requirement
	- 20171025@Long:	Sum by BettypeGroup (Major, PH)
	- 20171127@Long:	Support Live Status
	- 20180911@Long:	Support excluding Leagues from report [Redmine ID: #100322]
   			
 Param's Explanation:  
	 
 Exam:

*/
BEGIN;
	SET NOCOUNT ON;
	
	DECLARE @StartDate		DATE
		,	@EndDate		DATE
		,	@WinlostDate	DATE;

	IF	OBJECT_ID('tempdb..#tmpBettypeGroup') IS NOT NULL
	BEGIN;
		DROP TABLE #tmpBettypeGroup;
	END;

	CREATE TABLE	#tmpBettypeGroup (
			BetType			SMALLINT
		,	BettypeGroup	TINYINT
	);

	CREATE CLUSTERED INDEX	#CIX_tmpBettypeGroupIdx ON #tmpBettypeGroup (
			BetType		ASC
	);

	INSERT INTO #tmpBettypeGroup(
			BetType
		,	BettypeGroup)
	SELECT DISTINCT b.BetType
		,	b.BettypeGroup
	FROM dbo.BetType b WITH(NOLOCK);

	IF (@GenerateFromDate IS NULL AND @GenerateToDate IS NULL AND @Month IS NOT NULL)
	BEGIN

		SELECT @StartDate = DATEADD(DD, -DAY(@Month) + 1, @Month);
		SELECT @EndDate = DATEADD(DD, -1 ,DATEADD(MM, 1, @StartDate));
		SELECT @Month = @StartDate;		
 
		-- [SummaryByTrader_Monthly] table
		DELETE [dbo].[SummaryByTrader_Monthly] WHERE EventDate = @Month;

		INSERT INTO [dbo].[SummaryByTrader_Monthly]
		(
				[Eventdate]
			,	[CustId]
			,	[LeagueId]
			,	[WorkShift]
			,	[Stake]
			,	[WinLost]
			,	[Comm]
			,	[BetCount]
			,	[MatchCount]
			,	[BettypeGroup]
		)
		SELECT	@Month [Eventdate]
			,	s.[CustId]
			,	s.[LeagueId]
			,	s.[WorkShift]
			,	SUM(s.[Stake]) [Stake]
			,	SUM(s.[WinLost]) [WinLost]
			,	SUM(s.[Comm]) [Comm]
			,	SUM(s.[BetCount]) [BetCount]
			,	COUNT(DISTINCT s.[MatchId])[MatchCount]
			,	g.[BettypeGroup]
		 FROM [dbo].[TraderPerformance] s WITH(NOLOCK)
			INNER JOIN #tmpBettypeGroup g WITH(NOLOCK) ON s.BetType = g.BetType
		 WHERE EventDate BETWEEN @StartDate AND @EndDate
			AND IsLive = 1
		 GROUP BY [CustId]
			,	s.[LeagueId]
			,	s.[WorkShift]
			,	g.[BettypeGroup];

		-- [SummaryByBetType_Monthly] table
		DELETE [dbo].[SummaryByBetType_Monthly]	WHERE EventDate = @Month

		INSERT INTO [dbo].[SummaryByBetType_Monthly]
		(
				[EventDate]
			,	[LeagueId]
			,	[BetType]
			,	[WorkShift]
			,	[Stake]
			,	[WinLost]
			,	[Comm]
			,	[BetCount]
			,	[MatchCount]
		)
		SELECT @Month [EventDate]
			,	[LeagueId]
			,	[BetType]
			,	[WorkShift]
			,	SUM([Stake]) [Stake]
			,	SUM([WinLost]) [WinLost]
			,	SUM([Comm]) [Comm]
			,	SUM([BetCount]) BetCount
			,	COUNT(DISTINCT [MatchId])[MatchCount]
		FROM [dbo].[TraderPerformance] WITH(NOLOCK)
		WHERE EventDate BETWEEN @StartDate AND @EndDate
			AND IsLive = 1
		GROUP BY [LeagueId]
			,	[BetType]
			,	[WorkShift]

		-- [SummaryByLeague_Monthly] table
		DELETE [dbo].SummaryByLeague_Monthly	WHERE EventDate = @Month

		INSERT INTO [dbo].[SummaryByLeague_Monthly]
		(
				[EventDate]
			,	[LeagueId]
			,	[WorkShift]
			,	[Stake]
			,	[WinLost]
			,	[Comm]
			,	[BetCount]
			,	[MatchCount]
			,	[BettypeGroup]
		)
		SELECT	@Month [EventDate]
			,	s.[LeagueId]
			,	s.[WorkShift]
			,	SUM(s.[Stake]) [Stake]
			,	SUM(s.[WinLost]) [WinLost]
			,	SUM(s.[Comm]) [Comm]
			,	SUM(s.[BetCount]) BetCount
			,	COUNT(DISTINCT s.[MatchId])[MatchCount]
			,	g.[BettypeGroup]
		FROM [dbo].[TraderPerformance] s WITH(NOLOCK)
			INNER JOIN #tmpBettypeGroup g WITH(NOLOCK) ON s.BetType = g.BetType
		WHERE EventDate BETWEEN @StartDate AND @EndDate
			AND IsLive = 1
		GROUP BY [LeagueId]
			,	s.[WorkShift]
			,	g.[BettypeGroup];

		-- [SummaryByTeam_Monthly] table
		DELETE [dbo].SummaryByTeam_Monthly	WHERE EventDate = @Month

		INSERT INTO [dbo].[SummaryByTeam_Monthly]
		(
				[EventDate]
			,	[TeamId]
			,	[LeagueId]
			,	[WorkShift]
			,	[Stake]
			,	[WinLost]
			,	[Comm]
			,	[BetCount]
			,	[MatchCount]
			,	[BettypeGroup]
		)
		SELECT @Month [EventDate]
			,	s.[TeamId]
			,	s.[LeagueId]
			,	s.[WorkShift]
			,	SUM(s.[Stake]) [Stake]
			,	SUM(s.[WinLost]) [WinLost]
			,	SUM(s.[Comm]) [Comm]
			,	SUM(s.[BetCount]) BetCount
			,	COUNT(DISTINCT s.[MatchId])[MatchCount]
			,	g.[BettypeGroup]
		FROM [dbo].[TraderPerformance] s WITH(NOLOCK)
			INNER JOIN #tmpBettypeGroup g WITH(NOLOCK) ON s.BetType = g.BetType
		WHERE EventDate BETWEEN @StartDate AND @EndDate
			AND IsLive = 1
		GROUP BY [TeamId]
			,	s.[LeagueId]
			,	s.[WorkShift]
			,	g.[BettypeGroup];
	END
	ELSE IF (@GenerateFromDate IS NOT NULL AND @GenerateToDate IS NOT NULL)
	BEGIN
		IF	OBJECT_ID('tempdb..#tmpWinlostDate') IS NOT NULL
		BEGIN;
			DROP TABLE	#tmpWinlostDate;
		END;

		CREATE TABLE	#tmpWinlostDate (
			winlostdate			DATE
		);

		INSERT INTO	#tmpWinlostDate (winlostdate)
		SELECT	tally.EventDate
		FROM	(
			SELECT	[NoMonths] = DATEDIFF(MONTH, @GenerateFromDate, @GenerateToDate) + 1
		) cnt
		CROSS APPLY	(
			SELECT	TOP(cnt.NoMonths)
					[EventDate] = DATEADD(MONTH, ROW_NUMBER() OVER(ORDER BY (SELECT NULL)) - 1, @GenerateFromDate)
			FROM		(VALUES (0), (0), (0), (0), (0), (0), (0), (0), (0), (0)) x10(n)
			CROSS APPLY	(VALUES (0), (0), (0), (0), (0), (0), (0), (0), (0), (0)) x100(n)
			CROSS APPLY	(VALUES (0), (0), (0), (0), (0), (0), (0), (0), (0), (0)) x1000(n)
		) tally;
		
		WHILE	EXISTS (SELECT 1 FROM #tmpWinlostDate)
		BEGIN;
			SELECT	TOP(1)
					@WinLostDate = d.winlostdate
			FROM	#tmpWinlostDate AS d;

			SELECT @StartDate = DATEADD(DD, -DAY(@WinLostDate) + 1, @WinLostDate);
			SELECT @EndDate = DATEADD(DD, -1 , DATEADD(MM, 1, @StartDate));
 
			-- [SummaryByTrader_Monthly] table
			DELETE [dbo].[SummaryByTrader_Monthly] WHERE EventDate = @WinLostDate;

			INSERT INTO [dbo].[SummaryByTrader_Monthly]
			(
					[Eventdate]
				,	[CustId]
				,	[LeagueId]
				,	[WorkShift]
				,	[Stake]
				,	[WinLost]
				,	[Comm]
				,	[BetCount]
				,	[MatchCount]
				,	[BettypeGroup]
			)
			SELECT	@WinLostDate [Eventdate]
				,	s.[CustId]
				,	s.[LeagueId]
				,	s.[WorkShift]
				,	SUM(s.[Stake]) [Stake]
				,	SUM(s.[WinLost]) [WinLost]
				,	SUM(s.[Comm]) [Comm]
				,	SUM(s.[BetCount]) [BetCount]
				,	COUNT(DISTINCT s.[MatchId])[MatchCount]
				,	g.[BettypeGroup]
			 FROM [dbo].[TraderPerformance] s WITH(NOLOCK)
				INNER JOIN #tmpBettypeGroup g WITH(NOLOCK) ON s.BetType = g.BetType
			 WHERE EventDate BETWEEN @StartDate AND @EndDate
				AND IsLive = 1
			 GROUP BY [CustId]
				,	s.[LeagueId]
				,	s.[WorkShift]
				,	g.[BettypeGroup];

			-- [SummaryByBetType_Monthly] table
			DELETE [dbo].[SummaryByBetType_Monthly]	WHERE EventDate = @WinLostDate;

			INSERT INTO [dbo].[SummaryByBetType_Monthly]
			(
					[EventDate]
				,	[LeagueId]
				,	[BetType]
				,	[WorkShift]
				,	[Stake]
				,	[WinLost]
				,	[Comm]
				,	[BetCount]
				,	[MatchCount]
			)
			SELECT @WinLostDate [EventDate]
				,	[LeagueId]
				,	[BetType]
				,	[WorkShift]
				,	SUM([Stake]) [Stake]
				,	SUM([WinLost]) [WinLost]
				,	SUM([Comm]) [Comm]
				,	SUM([BetCount]) BetCount
				,	COUNT(DISTINCT [MatchId])[MatchCount]
			FROM [dbo].[TraderPerformance] WITH(NOLOCK)
			WHERE EventDate BETWEEN @StartDate AND @EndDate
				AND IsLive = 1
			GROUP BY [LeagueId]
				,	[BetType]
				,	[WorkShift]

			-- [SummaryByLeague_Monthly] table
			DELETE [dbo].SummaryByLeague_Monthly	WHERE EventDate = @WinLostDate;

			INSERT INTO [dbo].[SummaryByLeague_Monthly]
			(
					[EventDate]
				,	[LeagueId]
				,	[WorkShift]
				,	[Stake]
				,	[WinLost]
				,	[Comm]
				,	[BetCount]
				,	[MatchCount]
				,	[BettypeGroup]
			)
			SELECT	@WinLostDate [EventDate]
				,	s.[LeagueId]
				,	s.[WorkShift]
				,	SUM(s.[Stake]) [Stake]
				,	SUM(s.[WinLost]) [WinLost]
				,	SUM(s.[Comm]) [Comm]
				,	SUM(s.[BetCount]) BetCount
				,	COUNT(DISTINCT s.[MatchId])[MatchCount]
				,	g.[BettypeGroup]
			FROM [dbo].[TraderPerformance] s WITH(NOLOCK)
				INNER JOIN #tmpBettypeGroup g WITH(NOLOCK) ON s.BetType = g.BetType
			WHERE EventDate BETWEEN @StartDate AND @EndDate
				AND IsLive = 1
			GROUP BY [LeagueId]
				,	s.[WorkShift]
				,	g.[BettypeGroup];

			-- [SummaryByTeam_Monthly] table
			DELETE [dbo].SummaryByTeam_Monthly	WHERE EventDate = @WinLostDate;

			INSERT INTO [dbo].[SummaryByTeam_Monthly]
			(
					[EventDate]
				,	[TeamId]
				,	[LeagueId]
				,	[WorkShift]
				,	[Stake]
				,	[WinLost]
				,	[Comm]
				,	[BetCount]
				,	[MatchCount]
				,	[BettypeGroup]
			)
			SELECT @WinLostDate [EventDate]
				,	s.[TeamId]
				,	s.[LeagueId]
				,	s.[WorkShift]
				,	SUM(s.[Stake]) [Stake]
				,	SUM(s.[WinLost]) [WinLost]
				,	SUM(s.[Comm]) [Comm]
				,	SUM(s.[BetCount]) BetCount
				,	COUNT(DISTINCT s.[MatchId])[MatchCount]
				,	g.[BettypeGroup]
			FROM [dbo].[TraderPerformance] s WITH(NOLOCK)
				INNER JOIN #tmpBettypeGroup g WITH(NOLOCK) ON s.BetType = g.BetType
			WHERE EventDate BETWEEN @StartDate AND @EndDate
				AND IsLive = 1
			GROUP BY [TeamId]
				,	s.[LeagueId]
				,	s.[WorkShift]
				,	g.[BettypeGroup];

			DELETE	d
			FROM	#tmpWinlostDate AS d
			WHERE	d.winlostdate = @WinlostDate;
		END;
	END;
END;

GO
/*<info serverAlias="DBTGRS-bodb_TGRS" executers="bodbTGRSNet" isFunction="0" isNested="0"></info>*/
