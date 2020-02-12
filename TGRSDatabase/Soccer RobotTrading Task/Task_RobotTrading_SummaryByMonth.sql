ALTER PROCEDURE [dbo].[Task_RobotTrading_SummaryByMonth]
		@Month					DATE = NULL
	,	@GenerateFromDate		DATE = NULL
	,	@GenerateToDate			DATE = NULL
AS

/*
	 Created:	20191224@Long.Luu
	Task :		Summary by Month for Data on TGRS DB
	DB:			DBTGRS.bodb_TGRS
	Original:
  
	Revisions:
		- 20191224@Long.Luu:	Created [Redmine ID: 118959]
		- 20200120@John.Ngo:	[TGR Soccer] RT3 Performance - Model Comparision Report [Redmine ID: 127208]
		- 20200210@John.Ngo:	[TGR Soccer] RT3 - Adding TA model into Robot Trading by Bettype and Month [Redmine ID: 128184]
   		
	Param's Explanation:

	Exam:
*/
BEGIN;
	SET NOCOUNT ON;
	
	DECLARE @StartDate		DATE
		,	@EndDate		DATE
		,	@WinlostDate	DATE;

	IF (@GenerateFromDate IS NULL AND @GenerateToDate IS NULL AND @Month IS NOT NULL)
	BEGIN

		SELECT @StartDate = DATEADD(DD, -DAY(@Month) + 1, @Month);
		SELECT @EndDate = DATEADD(DD, -1 ,DATEADD(MM, 1, @StartDate));
		SELECT @Month = @StartDate;		
 
		DELETE [dbo].[RobotTrading_BetTypeMonthly] WITH(ROWLOCK)
		WHERE EventDate = @Month;

		INSERT INTO [dbo].[RobotTrading_BetTypeMonthly]
		(
				[EventDate]
			,	[BetType]
			,	[LeagueId]
			,	[LeagueGroupId]
			,	[Is8RM]
			,	[Stake_VR]
			,	[WinLoss_VR]
			,	[Comm_VR]
			,	[Stake_AR]
			,	[WinLoss_AR]
			,	[Comm_AR]			
			,	[BetCount]	
			,	[MatchCount]
			,	[Type]
			,	[TypeSiteId]
		)
		SELECT	[EventDate]		= @Month 
			,	[BetType]		= t.[BetType]
			,	[LeagueId]		= t.[LeagueId]
			,	[LeagueGroupId] = t.[LeagueGroupId]
			,	[Is8RM]			= t.[Is8RM]
			,	[Stake_VR]		= SUM(t.[Stake_VR]) 
			,	[WinLoss_VR]	= SUM(t.[WinLoss_VR]) 
			,	[Comm_VR]		= SUM(t.[Comm_VR]) 
			,	[Stake_AR]		= SUM(t.[Stake_AR]) 
			,	[WinLoss_AR]	= SUM(t.[WinLoss_AR]) 
			,	[Comm_AR]		= SUM(t.[Comm_AR]) 
			,	[BetCount]		= SUM(t.[BetCount]) 
			,	[MatchCount]	= COUNT(DISTINCT t.[MatchId])
			,	[Type]			= t.[Type]
			,	[TypeSiteId]	= t.[TypeSiteId]
		 FROM [dbo].[RobotTrading] AS t WITH(NOLOCK)
		 WHERE t.EventDate BETWEEN @StartDate AND @EndDate
		 GROUP BY t.[BetType]
			,	t.[LeagueId]
			,	t.[LeagueGroupId]
			,	t.[Is8RM]
			,	t.[Type]
			,	t.[TypeSiteId];
 
		DELETE [dbo].[RobotTrading_Monthly] WITH(ROWLOCK)
		WHERE EventDate = @Month;

		INSERT INTO [dbo].[RobotTrading_Monthly]
		(
				[TraderId]
			,	[EventDate]
			,	[LeagueId]
			,	[LeagueGroupId]
			,	[Is8RM]
			,	[Stake_VR]
			,	[WinLoss_VR]
			,	[Comm_VR]
			,	[Stake_AR]
			,	[WinLoss_AR]
			,	[Comm_AR]			
			,	[BetCount]	
			,	[MatchCount]
			,	[Type]
			,	[TypeSiteId]
		)
		SELECT	[TraderId]		= t.TraderId
			,	[EventDate]		= @Month 
			,	[LeagueId]		= t.[LeagueId]
			,	[LeagueGroupId] = t.[LeagueGroupId]
			,	[Is8RM]			= t.[Is8RM]
			,	[Stake_VR]		= SUM(t.[Stake_VR]) 
			,	[WinLoss_VR]	= SUM(t.[WinLoss_VR]) 
			,	[Comm_VR]		= SUM(t.[Comm_VR]) 
			,	[Stake_AR]		= SUM(t.[Stake_AR]) 
			,	[WinLoss_AR]	= SUM(t.[WinLoss_AR]) 
			,	[Comm_AR]		= SUM(t.[Comm_AR]) 
			,	[BetCount]		= SUM(t.[BetCount]) 
			,	[MatchCount]	= COUNT(DISTINCT t.[MatchId])
			,	[Type]			= t.[Type]
			,	[TypeSiteId]	= t.[TypeSiteId]
		 FROM [dbo].[RobotTrading] AS t WITH(NOLOCK)
		 WHERE t.EventDate BETWEEN @StartDate AND @EndDate
		 GROUP BY t.TraderId
			,	t.[LeagueId]
			,	t.[LeagueGroupId]
			,	t.[Is8RM]
			,	t.[Type]
			,	t.[TypeSiteId];
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
 
			DELETE [dbo].[RobotTrading_BetTypeMonthly] WITH(ROWLOCK)
			WHERE EventDate = @WinLostDate;

			INSERT INTO [dbo].[RobotTrading_BetTypeMonthly]
			(
					[EventDate]
				,	[BetType]
				,	[LeagueId]
				,	[LeagueGroupId]
				,	[Is8RM]
				,	[Stake_VR]
				,	[WinLoss_VR]
				,	[Comm_VR]
				,	[Stake_AR]
				,	[WinLoss_AR]
				,	[Comm_AR]			
				,	[BetCount]	
				,	[MatchCount]
				,	[Type]
				,	[TypeSiteId]
			)
			SELECT	[EventDate]		= @WinLostDate 
				,	[BetType]		= t.[BetType]
				,	[LeagueId]		= t.[LeagueId]
				,	[LeagueGroupId] = t.[LeagueGroupId]
				,	[Is8RM]			= t.[Is8RM]
				,	[Stake_VR]		= SUM(t.[Stake_VR]) 
				,	[WinLoss_VR]	= SUM(t.[WinLoss_VR]) 
				,	[Comm_VR]		= SUM(t.[Comm_VR]) 
				,	[Stake_AR]		= SUM(t.[Stake_AR]) 
				,	[WinLoss_AR]	= SUM(t.[WinLoss_AR]) 
				,	[Comm_AR]		= SUM(t.[Comm_AR]) 
				,	[BetCount]		= SUM(t.[BetCount]) 
				,	[MatchCount]	= COUNT(DISTINCT t.[MatchId])
				,	[Type]			= t.[Type]
				,	[TypeSiteId]	= t.[TypeSiteId]
			 FROM [dbo].[RobotTrading] AS t WITH(NOLOCK)
			 WHERE t.EventDate BETWEEN @StartDate AND @EndDate
			 GROUP BY t.[BetType]
				,	t.[LeagueId]
				,	t.[LeagueGroupId]
				,	t.[Is8RM]
				,	t.[Type]
				,	t.[TypeSiteId];

			DELETE [dbo].[RobotTrading_Monthly] WITH(ROWLOCK)
			WHERE EventDate = @WinLostDate;

			INSERT INTO [dbo].[RobotTrading_Monthly]
			(
					[TraderId]
				,	[EventDate]
				,	[LeagueId]
				,	[LeagueGroupId]
				,	[Is8RM]
				,	[Stake_VR]
				,	[WinLoss_VR]
				,	[Comm_VR]
				,	[Stake_AR]
				,	[WinLoss_AR]
				,	[Comm_AR]			
				,	[BetCount]
				,	[MatchCount]
				,	[Type]
				,	[TypeSiteId]
			)
			SELECT	[TraderId]		= t.TraderId
				,	[EventDate]		= @WinLostDate 
				,	[LeagueId]		= t.[LeagueId]
				,	[LeagueGroupId] = t.[LeagueGroupId]
				,	[Is8RM]			= t.[Is8RM]
				,	[Stake_VR]		= SUM(t.[Stake_VR]) 
				,	[WinLoss_VR]	= SUM(t.[WinLoss_VR]) 
				,	[Comm_VR]		= SUM(t.[Comm_VR]) 
				,	[Stake_AR]		= SUM(t.[Stake_AR]) 
				,	[WinLoss_AR]	= SUM(t.[WinLoss_AR]) 
				,	[Comm_AR]		= SUM(t.[Comm_AR]) 
				,	[BetCount]		= SUM(t.[BetCount]) 
				,	[MatchCount]	= COUNT(DISTINCT t.[MatchId])
				,	[Type]			= t.[Type]
				,	[TypeSiteId]	= t.[TypeSiteId]
			 FROM [dbo].[RobotTrading] AS t WITH(NOLOCK)
			 WHERE t.EventDate BETWEEN @StartDate AND @EndDate
			 GROUP BY t.TraderId
				,	t.[LeagueId]
				,	t.[LeagueGroupId]
				,	t.[Is8RM]
				,	t.[Type]
				,	t.[TypeSiteId];

			DELETE	d
			FROM	#tmpWinlostDate AS d
			WHERE	d.winlostdate = @WinlostDate;
		END;
	END;
END;

GO
/*<info serverAlias="DBTGRS-bodb_TGRS" executers="bodbTGRSNet" isFunction="0" isNested="0"></info>*/
