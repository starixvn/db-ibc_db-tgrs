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
		- 20141203@Tom.Vo:		Staging data with new requirement
		- 20171025@Long.Luu:	Sum by BettypeGroup (Major, PH)
		- 20171127@Long.Luu:	Support Live Status
		- 20180911@Long.Luu:	Support excluding Leagues from report [Redmine ID: #100322]
		- 20190304@Long.Luu:	Calc Actual-rate values for Soccer [Redmine ID: 108920]
		- 20190822@Long.Luu:	Suppport Non-Live Data [Redmine ID: 118959]
   			
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
			,	[BettypeGroup]
			,	[IsLive]
			,	[Stake]
			,	[WinLost]
			,	[Comm]
			,	[Stake_AR]
			,	[WinLost_AR]
			,	[Comm_AR]
			,	[BetCount]
			,	[MatchCount]
		)
		SELECT	[Eventdate]		= @Month 
			,	[CustId]		= s.[CustId]
			,	[LeagueId]		= s.[LeagueId]
			,	[WorkShift]		= s.[WorkShift]
			,	[BettypeGroup]	= g.[BettypeGroup]
			,	[IsLive]		= s.[IsLive]
			,	[Stake]			= SUM(s.[Stake])
			,	[WinLost]		= SUM(s.[WinLost]) 
			,	[Comm]			= SUM(s.[Comm])
			,	[Stake_AR]		= SUM(s.[Stake_AR]) 
			,	[WinLost_AR]	= SUM(s.[WinLost_AR]) 
			,	[Comm_AR]		= SUM(s.[Comm_AR]) 
			,	[BetCount]		= SUM(s.[BetCount]) 
			,	[MatchCount]	= COUNT(DISTINCT s.[MatchId])
		 FROM [dbo].[TraderPerformance] s WITH(NOLOCK)
			INNER JOIN #tmpBettypeGroup g WITH(NOLOCK) ON s.BetType = g.BetType
		 WHERE s.EventDate BETWEEN @StartDate AND @EndDate
		 GROUP BY s.[CustId]
			,	s.[LeagueId]
			,	s.[WorkShift]
			,	g.[BettypeGroup]
			,	s.[IsLive];

		-- [SummaryByBetType_Monthly] table
		DELETE [dbo].[SummaryByBetType_Monthly]	WHERE EventDate = @Month

		INSERT INTO [dbo].[SummaryByBetType_Monthly]
		(
				[EventDate]
			,	[LeagueId]
			,	[BetType]
			,	[WorkShift]
			,	[IsLive]
			,	[Stake]
			,	[WinLost]
			,	[Comm]
			,	[Stake_AR]
			,	[WinLost_AR]
			,	[Comm_AR]
			,	[BetCount]
			,	[MatchCount]
		)
		SELECT	[EventDate]		= @Month 
			,	[LeagueId]		= s.[LeagueId]
			,	[BetType]		= s.[BetType]
			,	[WorkShift]		= s.[WorkShift]
			,	[IsLive]		= s.[IsLive]
			,	[Stake]			= SUM(s.[Stake])
			,	[WinLost]		= SUM(s.[WinLost]) 
			,	[Comm]			= SUM(s.[Comm])
			,	[Stake_AR]		= SUM(s.[Stake_AR]) 
			,	[WinLost_AR]	= SUM(s.[WinLost_AR]) 
			,	[Comm_AR]		= SUM(s.[Comm_AR]) 
			,	[BetCount]		= SUM(s.[BetCount]) 
			,	[MatchCount]	= COUNT(DISTINCT s.[MatchId])
		FROM [dbo].[TraderPerformance] AS s WITH(NOLOCK)
		WHERE s.EventDate BETWEEN @StartDate AND @EndDate
		GROUP BY s.[LeagueId]
			,	s.[BetType]
			,	s.[WorkShift]
			,	s.[IsLive];

		-- [SummaryByLeague_Monthly] table
		DELETE [dbo].SummaryByLeague_Monthly	WHERE EventDate = @Month

		INSERT INTO [dbo].[SummaryByLeague_Monthly]
		(
				[EventDate]
			,	[LeagueId]
			,	[WorkShift]
			,	[BettypeGroup]
			,	[IsLive]
			,	[Stake]
			,	[WinLost]
			,	[Comm]
			,	[Stake_AR]
			,	[WinLost_AR]
			,	[Comm_AR]
			,	[BetCount]
			,	[MatchCount]
		)
		SELECT	[EventDate]		= @Month
			,	[LeagueId]		= s.[LeagueId]
			,	[WorkShift]		= s.[WorkShift]
			,	[BettypeGroup]	= g.[BettypeGroup]
			,	[IsLive]		= s.[IsLive]
			,	[Stake]			= SUM(s.[Stake])
			,	[WinLost]		= SUM(s.[WinLost]) 
			,	[Comm]			= SUM(s.[Comm])
			,	[Stake_AR]		= SUM(s.[Stake_AR]) 
			,	[WinLost_AR]	= SUM(s.[WinLost_AR]) 
			,	[Comm_AR]		= SUM(s.[Comm_AR]) 
			,	[BetCount]		= SUM(s.[BetCount]) 
			,	[MatchCount]	= COUNT(DISTINCT s.[MatchId])
		FROM [dbo].[TraderPerformance] s WITH(NOLOCK)
			INNER JOIN #tmpBettypeGroup g WITH(NOLOCK) ON s.BetType = g.BetType
		WHERE s.EventDate BETWEEN @StartDate AND @EndDate
		GROUP BY s.[LeagueId]
			,	s.[WorkShift]
			,	g.[BettypeGroup]
			,	s.[IsLive];

		-- [SummaryByTeam_Monthly] table
		DELETE [dbo].SummaryByTeam_Monthly	WHERE EventDate = @Month

		INSERT INTO [dbo].[SummaryByTeam_Monthly]
		(
				[EventDate]
			,	[TeamId]
			,	[LeagueId]
			,	[WorkShift]
			,	[BettypeGroup]
			,	[IsLive]
			,	[Stake]
			,	[WinLost]
			,	[Comm]
			,	[Stake_AR]
			,	[WinLost_AR]
			,	[Comm_AR]
			,	[BetCount]
			,	[MatchCount]
		)
		SELECT  [EventDate]		= @Month 
			,	[TeamId]		= s.[TeamId]
			,	[LeagueId]		= s.[LeagueId]
			,	[WorkShift]		= s.[WorkShift]
			,	[BettypeGroup]	= g.[BettypeGroup]
			,	[IsLive]		= s.[IsLive]
			,	[Stake]			= SUM(s.[Stake])
			,	[WinLost]		= SUM(s.[WinLost]) 
			,	[Comm]			= SUM(s.[Comm])
			,	[Stake_AR]		= SUM(s.[Stake_AR]) 
			,	[WinLost_AR]	= SUM(s.[WinLost_AR]) 
			,	[Comm_AR]		= SUM(s.[Comm_AR]) 
			,	[BetCount]		= SUM(s.[BetCount]) 
			,	[MatchCount]	= COUNT(DISTINCT s.[MatchId])
		FROM [dbo].[TraderPerformance] s WITH(NOLOCK)
			INNER JOIN #tmpBettypeGroup g WITH(NOLOCK) ON s.BetType = g.BetType
		WHERE s.EventDate BETWEEN @StartDate AND @EndDate
		GROUP BY s.[TeamId]
			,	s.[LeagueId]
			,	s.[WorkShift]
			,	g.[BettypeGroup]
			,	s.[IsLive];
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
				,	[BettypeGroup]
				,	[IsLive]
				,	[Stake]
				,	[WinLost]
				,	[Comm]
				,	[Stake_AR]
				,	[WinLost_AR]
				,	[Comm_AR]
				,	[BetCount]
				,	[MatchCount]
			)
			SELECT	[Eventdate]		= @WinLostDate 
				,	[CustId]		= s.[CustId]
				,	[LeagueId]		= s.[LeagueId]
				,	[WorkShift]		= s.[WorkShift]
				,	[BettypeGroup]	= g.[BettypeGroup]
				,	[IsLive]		= s.[IsLive]
				,	[Stake]			= SUM(s.[Stake])
				,	[WinLost]		= SUM(s.[WinLost]) 
				,	[Comm]			= SUM(s.[Comm])
				,	[Stake_AR]		= SUM(s.[Stake_AR]) 
				,	[WinLost_AR]	= SUM(s.[WinLost_AR]) 
				,	[Comm_AR]		= SUM(s.[Comm_AR]) 
				,	[BetCount]		= SUM(s.[BetCount]) 
				,	[MatchCount]	= COUNT(DISTINCT s.[MatchId])
			 FROM [dbo].[TraderPerformance] s WITH(NOLOCK)
				INNER JOIN #tmpBettypeGroup g WITH(NOLOCK) ON s.BetType = g.BetType
			 WHERE s.EventDate BETWEEN @StartDate AND @EndDate
			 GROUP BY s.[CustId]
				,	s.[LeagueId]
				,	s.[WorkShift]
				,	g.[BettypeGroup]
				,	s.[IsLive];

			-- [SummaryByBetType_Monthly] table
			DELETE [dbo].[SummaryByBetType_Monthly]	WHERE EventDate = @WinLostDate;

			INSERT INTO [dbo].[SummaryByBetType_Monthly]
			(
					[EventDate]
				,	[LeagueId]
				,	[BetType]
				,	[WorkShift]
				,	[IsLive]
				,	[Stake]
				,	[WinLost]
				,	[Comm]
				,	[Stake_AR]
				,	[WinLost_AR]
				,	[Comm_AR]
				,	[BetCount]
				,	[MatchCount]
			)
			SELECT	[EventDate]		= @WinLostDate 
				,	[LeagueId]		= s.[LeagueId]
				,	[BetType]		= s.[BetType]
				,	[WorkShift]		= s.[WorkShift]
				,	[IsLive]		= s.[IsLive]
				,	[Stake]			= SUM(s.[Stake])
				,	[WinLost]		= SUM(s.[WinLost]) 
				,	[Comm]			= SUM(s.[Comm])
				,	[Stake_AR]		= SUM(s.[Stake_AR]) 
				,	[WinLost_AR]	= SUM(s.[WinLost_AR]) 
				,	[Comm_AR]		= SUM(s.[Comm_AR]) 
				,	[BetCount]		= SUM(s.[BetCount]) 
				,	[MatchCount]	= COUNT(DISTINCT s.[MatchId])
			FROM [dbo].[TraderPerformance] AS s WITH(NOLOCK)
			WHERE s.EventDate BETWEEN @StartDate AND @EndDate
			GROUP BY s.[LeagueId]
				,	s.[BetType]
				,	s.[WorkShift]
				,	s.[IsLive];

			-- [SummaryByLeague_Monthly] table
			DELETE [dbo].SummaryByLeague_Monthly	WHERE EventDate = @WinLostDate;

			INSERT INTO [dbo].[SummaryByLeague_Monthly]
			(
					[EventDate]
				,	[LeagueId]
				,	[WorkShift]
				,	[BettypeGroup]
				,	[IsLive]
				,	[Stake]
				,	[WinLost]
				,	[Comm]	
				,	[Stake_AR]
				,	[WinLost_AR]
				,	[Comm_AR]
				,	[BetCount]
				,	[MatchCount]
			)
			SELECT	[EventDate]		= @WinLostDate 
				,	[LeagueId]		= s.[LeagueId]
				,	[WorkShift]		= s.[WorkShift]
				,	[BettypeGroup]	= g.[BettypeGroup]
				,	[IsLive]		= s.[IsLive]
				,	[Stake]			= SUM(s.[Stake])
				,	[WinLost]		= SUM(s.[WinLost]) 
				,	[Comm]			= SUM(s.[Comm])
				,	[Stake_AR]		= SUM(s.[Stake_AR]) 
				,	[WinLost_AR]	= SUM(s.[WinLost_AR]) 
				,	[Comm_AR]		= SUM(s.[Comm_AR]) 
				,	[BetCount]		= SUM(s.[BetCount]) 
				,	[MatchCount]	= COUNT(DISTINCT s.[MatchId])
			FROM [dbo].[TraderPerformance] s WITH(NOLOCK)
				INNER JOIN #tmpBettypeGroup g WITH(NOLOCK) ON s.BetType = g.BetType
			WHERE s.EventDate BETWEEN @StartDate AND @EndDate
			GROUP BY s.[LeagueId]
				,	s.[WorkShift]
				,	g.[BettypeGroup]
				,	s.[IsLive];

			-- [SummaryByTeam_Monthly] table
			DELETE [dbo].SummaryByTeam_Monthly	WHERE EventDate = @WinLostDate;

			INSERT INTO [dbo].[SummaryByTeam_Monthly]
			(
					[EventDate]
				,	[TeamId]
				,	[LeagueId]
				,	[WorkShift]
				,	[BettypeGroup]
				,	[IsLive]
				,	[Stake]
				,	[WinLost]
				,	[Comm]
				,	[Stake_AR]
				,	[WinLost_AR]
				,	[Comm_AR]
				,	[BetCount]
				,	[MatchCount]
			)
			SELECT	[EventDate]		= @WinLostDate 
				,	[TeamId]		= s.[TeamId]
				,	[LeagueId]		= s.[LeagueId]
				,	[WorkShift]		= s.[WorkShift]
				,	[BettypeGroup]	= g.[BettypeGroup]
				,	[IsLive]		= s.[IsLive]
				,	[Stake]			= SUM(s.[Stake])
				,	[WinLost]		= SUM(s.[WinLost]) 
				,	[Comm]			= SUM(s.[Comm])
				,	[Stake_AR]		= SUM(s.[Stake_AR]) 
				,	[WinLost_AR]	= SUM(s.[WinLost_AR]) 
				,	[Comm_AR]		= SUM(s.[Comm_AR]) 
				,	[BetCount]		= SUM(s.[BetCount]) 
				,	[MatchCount]	= COUNT(DISTINCT s.[MatchId])
			FROM [dbo].[TraderPerformance] s WITH(NOLOCK)
				INNER JOIN #tmpBettypeGroup g WITH(NOLOCK) ON s.BetType = g.BetType
			WHERE s.EventDate BETWEEN @StartDate AND @EndDate
			GROUP BY s.[TeamId]
				,	s.[LeagueId]
				,	s.[WorkShift]
				,	g.[BettypeGroup]
				,	s.[IsLive];

			DELETE	d
			FROM	#tmpWinlostDate AS d
			WHERE	d.winlostdate = @WinlostDate;
		END;
	END;
END;

GO
/*<info serverAlias="DBTGRS-bodb_TGRS" executers="bodbTGRSNet" isFunction="0" isNested="0"></info>*/
