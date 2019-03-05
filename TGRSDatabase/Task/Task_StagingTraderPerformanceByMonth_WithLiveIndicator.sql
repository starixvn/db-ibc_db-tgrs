ALTER PROCEDURE [dbo].[Task_StagingTraderPerformanceByMonth_WithLiveIndicator]
		@GenerateFromDate		DATE = NULL
	,	@GenerateToDate			DATE = NULL
AS

/*
 Created:	20171127@Long
 Task :		Staging Data on TGRS DB By Month for Live & Non-Live tickets
 DB:		DBTGRS.bodb_TGRS
 Original:  
  
 Revisions:      
	- 20171127@Long:	Create new
	- 20180911@Long:	Support excluding Leagues from report [Redmine ID: #100322]
	- 20190111@Long:	Change the way to sum Monthly & Yearly for bettypes [Redmine ID: 107602]
	- 20190304@Long:	Calc Actual-rate values for Soccer [Redmine ID: 108920]
   			
 Param's Explanation:  
	 
 Exam:

*/
BEGIN;
	SET NOCOUNT ON
	
	DECLARE @CurrentMonthStartDate		DATE
		,	@CurrentMonthEndDate		DATE
		,	@LastMonthStartDate			DATE
		,	@LastMonthEndDate			DATE
		,	@DataStartDate				DATE
		,	@WinLostDate				DATE;

	
	-- Create table TraderPerformance
	IF	OBJECT_ID('tempdb..#tmpTraderPerformance') IS NOT NULL
	BEGIN;
		DROP TABLE #tmpTraderPerformance;
	END;

	CREATE TABLE #tmpTraderPerformance(
			[CustId]		INT NOT NULL,
			[MatchId]		INT NOT NULL,
			[EventDate]		DATE NOT NULL,
			[SportType]		SMALLINT NULL,
			[BetType]		SMALLINT NOT NULL,
			[IsLive]		SMALLINT NOT NULL,
			[LeagueId]		INT NULL,
			[TeamId]		SMALLINT NULL,
			[Grade]			TINYINT NULL,
			[Stake]			MONEY NULL,
			[WinLost]		MONEY NULL,
			[Comm]			MONEY NULL,
			[Stake_AR]		MONEY NULL,
			[WinLost_AR]	MONEY NULL,
			[Comm_AR]		MONEY NULL,
			[BetCount]		INT NULL,
			[HomeId]		INT NULL,
			[AwayId]		INT NULL,
			[MatchCode]		VARCHAR(100) NULL,
			[WorkShift]		TINYINT NULL,
			[Spread]		MONEY NULL,
			[Juice]			MONEY NULL,
			[StakeMYR]		MONEY NULL,
			[StakeMYRJuice] MONEY NULL,
			[Juice_AR]		MONEY NULL,
			[StakeMYR_AR]	MONEY NULL,
			[StakeMYRJuice_AR] MONEY NULL
	);

	CREATE CLUSTERED INDEX	#CIX_tmpTraderPerformanceIdx ON #tmpTraderPerformance (
			[CustId]		ASC
		,	[EventDate]		DESC
		,	[MatchId]		ASC
		,	[SportType]		ASC
		,	[BetType]		ASC
		,	[IsLive]		ASC
	);

	IF (@GenerateFromDate IS NULL AND @GenerateToDate IS NULL)
	BEGIN
		SELECT	@CurrentMonthEndDate =		GETDATE();
		SELECT	@CurrentMonthStartDate =	DATEADD(DD, -DAY(@CurrentMonthEndDate) + 1, @CurrentMonthEndDate);
		SELECT	@LastMonthEndDate =			DATEADD(DD, -1, @CurrentMonthStartDate);
		SELECT	@LastMonthStartDate =		DATEADD(DD, -DAY(@LastMonthEndDate) + 1, @LastMonthEndDate);
		SELECT	@DataStartDate = CASE 
									WHEN DAY(@CurrentMonthEndDate) < 14 
										THEN @LastMonthStartDate
									ELSE @CurrentMonthStartDate
								END;
	
		-- Insert tickets
		INSERT INTO #tmpTraderPerformance(
				[CustId],
				[MatchId],
				[EventDate],
				[SportType],
				[BetType],
				[LeagueId],
				[TeamId],
				[Grade],
				[Stake],
				[WinLost],
				[Comm],
				[Stake_AR],
				[WinLost_AR],
				[Comm_AR],
				[BetCount],
				[HomeId],
				[AwayId],
				[MatchCode],
				[WorkShift],
				[Spread],
				[IsLive]
		)
		SELECT  tp.[CustId],
				tp.[MatchId],
				tp.[EventDate],
				tp.[SportType],
				tp.[BetType],
				tp.[LeagueId],
				tp.[TeamId],
				tp.[Grade],
				tp.[Stake],
				tp.[WinLost],
				tp.[Comm],
				tp.[Stake_AR],
				tp.[WinLost_AR],
				tp.[Comm_AR],
				tp.[BetCount],
				tp.[HomeId],
				tp.[AwayId],
				tp.[MatchCode],
				tp.[WorkShift],
				tp.[Spread],
				tp.[IsLive]
		FROM dbo.[TraderPerformance] tp WITH(NOLOCK)
			INNER JOIN dbo.BetType bt WITH (NOLOCK) ON tp.Bettype = bt.Bettype
		WHERE tp.EventDate BETWEEN @DataStartDate AND @CurrentMonthEndDate;

		-- Insert data for TraderPerformance Monthly
		DELETE [dbo].[TraderPerformance_Monthly]	
		WHERE EventDate = @CurrentMonthStartDate;

		INSERT INTO [dbo].[TraderPerformance_Monthly]
		(
				[CustId]
			,	[LeagueId]
			,	[EventDate]
			,	[SportType]
			,	[BetType]
			,	[IsLive]
			,	[Turnover]
			,	[WinLoss]
			,	[Comm]
			,	[Turnover_AR]
			,	[WinLoss_AR]
			,	[Comm_AR]
			,	[BetCount]
		)
		SELECT tpp.CustId
			,	tpp.LeagueId
			,	@CurrentMonthStartDate AS EventDate
			,	tpp.SportType
			,	tpp.BetType
			,	tpp.IsLive
			,	SUM(tpp.Stake) AS Turnover
			,	SUM(tpp.WinLost) AS WinLoss
			,	SUM(tpp.Comm) AS Comm
			,	SUM(tpp.Stake_AR) AS Turnover_AR
			,	SUM(tpp.WinLost_AR) AS WinLoss_AR
			,	SUM(tpp.Comm_AR) AS Comm_AR
			,	SUM(tpp.BetCount) AS BetCount
		FROM #tmpTraderPerformance tpp WITH(NOLOCK)
		WHERE tpp.EventDate BETWEEN @CurrentMonthStartDate AND @CurrentMonthEndDate
		GROUP BY tpp.CustId
			,	tpp.LeagueId
			,	tpp.SportType
			,	tpp.BetType
			,	tpp.IsLive;

		INSERT INTO [dbo].[TraderPerformance_Monthly]
		(
				[CustId]
			,	[LeagueId]
			,	[EventDate]
			,	[SportType]
			,	[BetType]
			,	[IsLive]
			,	[Turnover]
			,	[WinLoss]
			,	[Comm]
			,	[Turnover_AR]
			,	[WinLoss_AR]
			,	[Comm_AR]
			,	[BetCount]
		)
		SELECT tpp.CustId
			,	tpp.LeagueId
			,	@CurrentMonthStartDate AS EventDate
			,	tpp.SportType
			,	tpp.BetType
			,	-1 AS IsLive
			,	SUM(tpp.Stake) AS Turnover
			,	SUM(tpp.WinLost) AS WinLoss
			,	SUM(tpp.Comm) AS Comm
			,	SUM(tpp.Stake_AR) AS Turnover_AR
			,	SUM(tpp.WinLost_AR) AS WinLoss_AR
			,	SUM(tpp.Comm_AR) AS Comm_AR
			,	SUM(tpp.BetCount) AS BetCount
		FROM #tmpTraderPerformance tpp WITH(NOLOCK)
		WHERE tpp.EventDate BETWEEN @CurrentMonthStartDate AND @CurrentMonthEndDate
		GROUP BY tpp.CustId
			,	tpp.LeagueId
			,	tpp.SportType
			,	tpp.BetType;

		INSERT INTO [dbo].[TraderPerformance_Monthly]
		(
				[CustId]
			,	[LeagueId]
			,	[EventDate]
			,	[SportType]
			,	[BetType]
			,	[IsLive]
			,	[Turnover]
			,	[WinLoss]
			,	[Comm]
			,	[Turnover_AR]
			,	[WinLoss_AR]
			,	[Comm_AR]
			,	[BetCount]
		)
		SELECT tpp.CustId
			,	tpp.LeagueId
			,	@CurrentMonthStartDate AS EventDate
			,	tpp.SportType
			,	-1 AS BetType
			,	tpp.IsLive
			,	SUM(tpp.Stake) AS Turnover
			,	SUM(tpp.WinLost) AS WinLoss
			,	SUM(tpp.Comm) AS Comm
			,	SUM(tpp.Stake_AR) AS Turnover_AR
			,	SUM(tpp.WinLost_AR) AS WinLoss_AR
			,	SUM(tpp.Comm_AR) AS Comm_AR
			,	SUM(tpp.BetCount) AS BetCount
		FROM #tmpTraderPerformance tpp WITH(NOLOCK)
		WHERE tpp.EventDate BETWEEN @CurrentMonthStartDate AND @CurrentMonthEndDate
		GROUP BY tpp.CustId
			,	tpp.LeagueId
			,	tpp.SportType
			,	tpp.IsLive;

		INSERT INTO [dbo].[TraderPerformance_Monthly]
		(
				[CustId]
			,	[LeagueId]
			,	[EventDate]
			,	[SportType]
			,	[BetType]
			,	[IsLive]
			,	[Turnover]
			,	[WinLoss]
			,	[Comm]
			,	[Turnover_AR]
			,	[WinLoss_AR]
			,	[Comm_AR]
			,	[BetCount]
		)
		SELECT tpp.CustId
			,	tpp.LeagueId
			,	@CurrentMonthStartDate AS EventDate
			,	tpp.SportType
			,	-1 AS BetType
			,	-1 AS IsLive
			,	SUM(tpp.Stake) AS Turnover
			,	SUM(tpp.WinLost) AS WinLoss
			,	SUM(tpp.Comm) AS Comm
			,	SUM(tpp.Stake_AR) AS Turnover_AR
			,	SUM(tpp.WinLost_AR) AS WinLoss_AR
			,	SUM(tpp.Comm_AR) AS Comm_AR
			,	SUM(tpp.BetCount) AS BetCount
		FROM #tmpTraderPerformance tpp WITH(NOLOCK)
		WHERE tpp.EventDate BETWEEN @CurrentMonthStartDate AND @CurrentMonthEndDate
		GROUP BY tpp.CustId
			,	tpp.LeagueId
			,	tpp.SportType;

		-- Insert data for TraderMatchCount_Monthly table	
		DELETE [dbo].[TraderMatchCount_Monthly]	
		WHERE EventDate = @CurrentMonthStartDate;

		INSERT INTO dbo.TraderMatchCount_Monthly
		(
				[CustId]
			,	[LeagueId]
			,	[EventDate]
			,	[SportType]
			,	[BetType]
			,	[IsLive]
			,	[MatchCount]
		)
		SELECT	tp.CustId
			,	tp.LeagueId
			,	@CurrentMonthStartDate AS EventDate
			,	tp.SportType
			,	tp.BetType
			,	tp.IsLive
			,	COUNT(DISTINCT tp.MatchId) AS MatchCount
		FROM #tmpTraderPerformance tp WITH(NOLOCK)
		WHERE tp.EventDate BETWEEN @CurrentMonthStartDate AND @CurrentMonthEndDate
		GROUP BY tp.CustId
			,	tp.LeagueId
			,	tp.SportType
			,	tp.BetType
			,	tp.IsLive;

		INSERT INTO dbo.TraderMatchCount_Monthly
		(
				[CustId]
			,	[LeagueId]
			,	[EventDate]
			,	[SportType]
			,	[BetType]
			,	[IsLive]
			,	[MatchCount]
		)
		SELECT	tp.CustId
			,	tp.LeagueId
			,	@CurrentMonthStartDate AS EventDate
			,	tp.SportType
			,	tp.BetType
			,	-1 AS IsLive
			,	COUNT(DISTINCT tp.MatchId) AS MatchCount
		FROM #tmpTraderPerformance tp WITH(NOLOCK)
		WHERE tp.EventDate BETWEEN @CurrentMonthStartDate AND @CurrentMonthEndDate
		GROUP BY tp.CustId
			,	tp.LeagueId
			,	tp.SportType
			,	tp.BetType;

		INSERT INTO dbo.TraderMatchCount_Monthly
		(
				[CustId]
			,	[LeagueId]
			,	[EventDate]
			,	[SportType]
			,	[BetType]
			,	[IsLive]
			,	[MatchCount]
		)
		SELECT	tp.CustId
			,	tp.LeagueId
			,	@CurrentMonthStartDate AS EventDate
			,	tp.SportType
			,	-1 AS BetType
			,	tp.IsLive
			,	COUNT(DISTINCT tp.MatchId) AS MatchCount
		FROM #tmpTraderPerformance tp WITH(NOLOCK)
		WHERE tp.EventDate BETWEEN @CurrentMonthStartDate AND @CurrentMonthEndDate
		GROUP BY tp.CustId
			,	tp.LeagueId
			,	tp.SportType
			,	tp.IsLive;

		INSERT INTO dbo.TraderMatchCount_Monthly
		(
				[CustId]
			,	[LeagueId]
			,	[EventDate]
			,	[SportType]
			,	[BetType]
			,	[IsLive]
			,	[MatchCount]
		)
		SELECT	tp.CustId
			,	tp.LeagueId
			,	@CurrentMonthStartDate AS EventDate
			,	tp.SportType
			,	-1 AS BetType
			,	-1 AS IsLive
			,	COUNT(DISTINCT tp.MatchId) AS MatchCount
		FROM #tmpTraderPerformance tp WITH(NOLOCK)
		WHERE tp.EventDate BETWEEN @CurrentMonthStartDate AND @CurrentMonthEndDate
		GROUP BY tp.CustId
			,	tp.LeagueId
			,	tp.SportType;

		 -- Check whether to re-sum data for the previous month
		IF (DAY(@CurrentMonthEndDate) < 14)
		BEGIN		
			-- Insert data for TraderPerformance Monthly
			DELETE [dbo].[TraderPerformance_Monthly]	
			WHERE EventDate = @LastMonthStartDate;

			INSERT INTO [dbo].[TraderPerformance_Monthly]
			(
					[CustId]
				,	[LeagueId]
				,	[EventDate]
				,	[SportType]
				,	[BetType]
				,	[IsLive]
				,	[Turnover]
				,	[WinLoss]
				,	[Comm]
				,	[Turnover_AR]
				,	[WinLoss_AR]
				,	[Comm_AR]
				,	[BetCount]
			)
			SELECT tpp.CustId
				,	tpp.LeagueId
				,	@LastMonthStartDate AS EventDate
				,	tpp.SportType
				,	tpp.BetType
				,	tpp.IsLive
				,	SUM(tpp.Stake) AS Turnover
				,	SUM(tpp.WinLost) AS WinLoss
				,	SUM(tpp.Comm) AS Comm
				,	SUM(tpp.Stake_AR) AS Turnover_AR
				,	SUM(tpp.WinLost_AR) AS WinLoss_AR
				,	SUM(tpp.Comm_AR) AS Comm_AR
				,	SUM(tpp.BetCount) AS BetCount
			FROM #tmpTraderPerformance tpp WITH(NOLOCK)
			WHERE tpp.EventDate BETWEEN @LastMonthStartDate AND @LastMonthEndDate
			GROUP BY tpp.CustId
				,	tpp.LeagueId
				,	tpp.SportType
				,	tpp.BetType
				,	tpp.IsLive;

			INSERT INTO [dbo].[TraderPerformance_Monthly]
			(
					[CustId]
				,	[LeagueId]
				,	[EventDate]
				,	[SportType]
				,	[BetType]
				,	[IsLive]
				,	[Turnover]
				,	[WinLoss]
				,	[Comm]
				,	[Turnover_AR]
				,	[WinLoss_AR]
				,	[Comm_AR]
				,	[BetCount]
			)
			SELECT tpp.CustId
				,	tpp.LeagueId
				,	@LastMonthStartDate AS EventDate
				,	tpp.SportType
				,	tpp.BetType
				,	-1 AS IsLive
				,	SUM(tpp.Stake) AS Turnover
				,	SUM(tpp.WinLost) AS WinLoss
				,	SUM(tpp.Comm) AS Comm
				,	SUM(tpp.Stake_AR) AS Turnover_AR
				,	SUM(tpp.WinLost_AR) AS WinLoss_AR
				,	SUM(tpp.Comm_AR) AS Comm_AR
				,	SUM(tpp.BetCount) AS BetCount
			FROM #tmpTraderPerformance tpp WITH(NOLOCK)
			WHERE tpp.EventDate BETWEEN @LastMonthStartDate AND @LastMonthEndDate
			GROUP BY tpp.CustId
				,	tpp.LeagueId
				,	tpp.SportType
				,	tpp.BetType;
			
			INSERT INTO [dbo].[TraderPerformance_Monthly]
			(
					[CustId]
				,	[LeagueId]
				,	[EventDate]
				,	[SportType]
				,	[BetType]
				,	[IsLive]
				,	[Turnover]
				,	[WinLoss]
				,	[Comm]
				,	[Turnover_AR]
				,	[WinLoss_AR]
				,	[Comm_AR]
				,	[BetCount]
			)
			SELECT tpp.CustId
				,	tpp.LeagueId
				,	@LastMonthStartDate AS EventDate
				,	tpp.SportType
				,	-1 AS BetType
				,	tpp.IsLive
				,	SUM(tpp.Stake) AS Turnover
				,	SUM(tpp.WinLost) AS WinLoss
				,	SUM(tpp.Comm) AS Comm
				,	SUM(tpp.Stake_AR) AS Turnover_AR
				,	SUM(tpp.WinLost_AR) AS WinLoss_AR
				,	SUM(tpp.Comm_AR) AS Comm_AR
				,	SUM(tpp.BetCount) AS BetCount
			FROM #tmpTraderPerformance tpp WITH(NOLOCK)
			WHERE tpp.EventDate BETWEEN @LastMonthStartDate AND @LastMonthEndDate
			GROUP BY tpp.CustId
				,	tpp.LeagueId
				,	tpp.SportType
				,	tpp.IsLive;
			
			INSERT INTO [dbo].[TraderPerformance_Monthly]
			(
					[CustId]
				,	[LeagueId]
				,	[EventDate]
				,	[SportType]
				,	[BetType]
				,	[IsLive]
				,	[Turnover]
				,	[WinLoss]
				,	[Comm]
				,	[Turnover_AR]
				,	[WinLoss_AR]
				,	[Comm_AR]
				,	[BetCount]
			)
			SELECT tpp.CustId
				,	tpp.LeagueId
				,	@LastMonthStartDate AS EventDate
				,	tpp.SportType
				,	-1 AS BetType
				,	-1 AS IsLive
				,	SUM(tpp.Stake) AS Turnover
				,	SUM(tpp.WinLost) AS WinLoss
				,	SUM(tpp.Comm) AS Comm
				,	SUM(tpp.Stake_AR) AS Turnover_AR
				,	SUM(tpp.WinLost_AR) AS WinLoss_AR
				,	SUM(tpp.Comm_AR) AS Comm_AR
				,	SUM(tpp.BetCount) AS BetCount
			FROM #tmpTraderPerformance tpp WITH(NOLOCK)
			WHERE tpp.EventDate BETWEEN @LastMonthStartDate AND @LastMonthEndDate
			GROUP BY tpp.CustId
				,	tpp.LeagueId
				,	tpp.SportType;

			-- Insert data for TraderMatchCount_Monthly table	
			DELETE [dbo].[TraderMatchCount_Monthly]	
			WHERE EventDate = @LastMonthStartDate;

			INSERT INTO dbo.TraderMatchCount_Monthly
			(
					[CustId]
				,	[LeagueId]
				,	[EventDate]
				,	[SportType]
				,	[BetType]
				,	[IsLive]
				,	[MatchCount]
			)
			SELECT	tp.CustId
				,	tp.LeagueId
				,	@LastMonthStartDate AS EventDate
				,	tp.SportType
				,	tp.BetType
				,	tp.IsLive
				,	COUNT(DISTINCT tp.MatchId) AS MatchCount
			FROM #tmpTraderPerformance tp WITH(NOLOCK)
			WHERE tp.EventDate BETWEEN @LastMonthStartDate AND @LastMonthEndDate
			GROUP BY tp.CustId
				,	tp.LeagueId
				,	tp.SportType
				,	tp.BetType
				,	tp.IsLive;

			INSERT INTO dbo.TraderMatchCount_Monthly
			(
					[CustId]
				,	[LeagueId]
				,	[EventDate]
				,	[SportType]
				,	[BetType]
				,	[IsLive]
				,	[MatchCount]
			)
			SELECT	tp.CustId
				,	tp.LeagueId
				,	@LastMonthStartDate AS EventDate
				,	tp.SportType
				,	tp.BetType
				,	-1 AS IsLive
				,	COUNT(DISTINCT tp.MatchId) AS MatchCount
			FROM #tmpTraderPerformance tp WITH(NOLOCK)
			WHERE tp.EventDate BETWEEN @LastMonthStartDate AND @LastMonthEndDate
			GROUP BY tp.CustId
				,	tp.LeagueId
				,	tp.SportType
				,	tp.BetType;

			INSERT INTO dbo.TraderMatchCount_Monthly
			(
					[CustId]
				,	[LeagueId]
				,	[EventDate]
				,	[SportType]
				,	[BetType]
				,	[IsLive]
				,	[MatchCount]
			)
			SELECT	tp.CustId
				,	tp.LeagueId
				,	@LastMonthStartDate AS EventDate
				,	tp.SportType
				,	-1 AS BetType
				,	tp.IsLive
				,	COUNT(DISTINCT tp.MatchId) AS MatchCount
			FROM #tmpTraderPerformance tp WITH(NOLOCK)
			WHERE tp.EventDate BETWEEN @LastMonthStartDate AND @LastMonthEndDate
			GROUP BY tp.CustId
				,	tp.LeagueId
				,	tp.SportType
				,	tp.IsLive;

			INSERT INTO dbo.TraderMatchCount_Monthly
			(
					[CustId]
				,	[LeagueId]
				,	[EventDate]
				,	[SportType]
				,	[BetType]
				,	[IsLive]
				,	[MatchCount]
			)
			SELECT	tp.CustId
				,	tp.LeagueId
				,	@LastMonthStartDate AS EventDate
				,	tp.SportType
				,	-1 AS BetType
				,	-1 AS IsLive
				,	COUNT(DISTINCT tp.MatchId) AS MatchCount
			FROM #tmpTraderPerformance tp WITH(NOLOCK)
			WHERE tp.EventDate BETWEEN @LastMonthStartDate AND @LastMonthEndDate
			GROUP BY tp.CustId
				,	tp.LeagueId
				,	tp.SportType;
		END;	
	END;
	ELSE
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

			SELECT	@CurrentMonthStartDate =	DATEADD(DD, -DAY(@WinLostDate) + 1, @WinLostDate);
			SELECT	@CurrentMonthEndDate =		DATEADD(DD, -1 , DATEADD(MM, 1, @CurrentMonthStartDate));
		
			-- Insert tickets
			INSERT INTO #tmpTraderPerformance(
					[CustId],
					[MatchId],
					[EventDate],
					[SportType],
					[BetType],
					[LeagueId],
					[TeamId],
					[Grade],
					[Stake],
					[WinLost],
					[Comm],
					[Stake_AR],
					[WinLost_AR],
					[Comm_AR],
					[BetCount],
					[HomeId],
					[AwayId],
					[MatchCode],
					[WorkShift],
					[Spread],
					[IsLive]
			)
			SELECT  tp.[CustId],
					tp.[MatchId],
					tp.[EventDate],
					tp.[SportType],
					tp.[BetType],
					tp.[LeagueId],
					tp.[TeamId],
					tp.[Grade],
					tp.[Stake],
					tp.[WinLost],
					tp.[Comm],
					tp.[Stake_AR],
					tp.[WinLost_AR],
					tp.[Comm_AR],
					tp.[BetCount],
					tp.[HomeId],
					tp.[AwayId],
					tp.[MatchCode],
					tp.[WorkShift],
					tp.[Spread],
					tp.[IsLive]
			FROM dbo.[TraderPerformance] tp WITH(NOLOCK)
				INNER JOIN dbo.BetType bt WITH (NOLOCK) ON tp.Bettype = bt.Bettype
			WHERE tp.EventDate BETWEEN @CurrentMonthStartDate AND @CurrentMonthEndDate;

			-- Insert data for TraderPerformance Monthly
			DELETE [dbo].[TraderPerformance_Monthly]	
			WHERE EventDate = @CurrentMonthStartDate;

			INSERT INTO [dbo].[TraderPerformance_Monthly]
			(
					[CustId]
				,	[LeagueId]
				,	[EventDate]
				,	[SportType]
				,	[BetType]
				,	[IsLive]
				,	[Turnover]
				,	[WinLoss]
				,	[Comm]
				,	[Turnover_AR]
				,	[WinLoss_AR]
				,	[Comm_AR]
				,	[BetCount]
			)
			SELECT tpp.CustId
				,	tpp.LeagueId
				,	@CurrentMonthStartDate AS EventDate
				,	tpp.SportType
				,	tpp.BetType
				,	tpp.IsLive
				,	SUM(tpp.Stake) AS Turnover
				,	SUM(tpp.WinLost) AS WinLoss
				,	SUM(tpp.Comm) AS Comm
				,	SUM(tpp.Stake_AR) AS Turnover_AR
				,	SUM(tpp.WinLost_AR) AS WinLoss_AR
				,	SUM(tpp.Comm_AR) AS Comm_AR
				,	SUM(tpp.BetCount) AS BetCount
			FROM #tmpTraderPerformance tpp WITH(NOLOCK)
			GROUP BY tpp.CustId
				,	tpp.LeagueId
				,	tpp.SportType
				,	tpp.BetType
				,	tpp.IsLive;

			INSERT INTO [dbo].[TraderPerformance_Monthly]
			(
					[CustId]
				,	[LeagueId]
				,	[EventDate]
				,	[SportType]
				,	[BetType]
				,	[IsLive]
				,	[Turnover]
				,	[WinLoss]
				,	[Comm]
				,	[Turnover_AR]
				,	[WinLoss_AR]
				,	[Comm_AR]
				,	[BetCount]
			)
			SELECT tpp.CustId
				,	tpp.LeagueId
				,	@CurrentMonthStartDate AS EventDate
				,	tpp.SportType
				,	tpp.BetType
				,	-1 AS IsLive
				,	SUM(tpp.Stake) AS Turnover
				,	SUM(tpp.WinLost) AS WinLoss
				,	SUM(tpp.Comm) AS Comm
				,	SUM(tpp.Stake_AR) AS Turnover_AR
				,	SUM(tpp.WinLost_AR) AS WinLoss_AR
				,	SUM(tpp.Comm_AR) AS Comm_AR
				,	SUM(tpp.BetCount) AS BetCount
			FROM #tmpTraderPerformance tpp WITH(NOLOCK)
			GROUP BY tpp.CustId
				,	tpp.LeagueId
				,	tpp.SportType
				,	tpp.BetType;

			INSERT INTO [dbo].[TraderPerformance_Monthly]
			(
					[CustId]
				,	[LeagueId]
				,	[EventDate]
				,	[SportType]
				,	[BetType]
				,	[IsLive]
				,	[Turnover]
				,	[WinLoss]
				,	[Comm]
				,	[Turnover_AR]
				,	[WinLoss_AR]
				,	[Comm_AR]
				,	[BetCount]
			)
			SELECT tpp.CustId
				,	tpp.LeagueId
				,	@CurrentMonthStartDate AS EventDate
				,	tpp.SportType
				,	-1 AS BetType
				,	tpp.IsLive
				,	SUM(tpp.Stake) AS Turnover
				,	SUM(tpp.WinLost) AS WinLoss
				,	SUM(tpp.Comm) AS Comm
				,	SUM(tpp.Stake_AR) AS Turnover_AR
				,	SUM(tpp.WinLost_AR) AS WinLoss_AR
				,	SUM(tpp.Comm_AR) AS Comm_AR
				,	SUM(tpp.BetCount) AS BetCount
			FROM #tmpTraderPerformance tpp WITH(NOLOCK)
			GROUP BY tpp.CustId
				,	tpp.LeagueId
				,	tpp.SportType
				,	tpp.IsLive;

			INSERT INTO [dbo].[TraderPerformance_Monthly]
			(
					[CustId]
				,	[LeagueId]
				,	[EventDate]
				,	[SportType]
				,	[BetType]
				,	[IsLive]
				,	[Turnover]
				,	[WinLoss]
				,	[Comm]
				,	[Turnover_AR]
				,	[WinLoss_AR]
				,	[Comm_AR]
				,	[BetCount]
			)
			SELECT tpp.CustId
				,	tpp.LeagueId
				,	@CurrentMonthStartDate AS EventDate
				,	tpp.SportType
				,	-1 AS BetType
				,	-1 AS IsLive
				,	SUM(tpp.Stake) AS Turnover
				,	SUM(tpp.WinLost) AS WinLoss
				,	SUM(tpp.Comm) AS Comm
				,	SUM(tpp.Stake_AR) AS Turnover_AR
				,	SUM(tpp.WinLost_AR) AS WinLoss_AR
				,	SUM(tpp.Comm_AR) AS Comm_AR
				,	SUM(tpp.BetCount) AS BetCount
			FROM #tmpTraderPerformance tpp WITH(NOLOCK)
			GROUP BY tpp.CustId
				,	tpp.LeagueId
				,	tpp.SportType;

			-- Insert data for TraderMatchCount_Monthly table	
			DELETE [dbo].[TraderMatchCount_Monthly]	
			WHERE EventDate = @CurrentMonthStartDate;

			INSERT INTO dbo.TraderMatchCount_Monthly
			(
					[CustId]
				,	[LeagueId]
				,	[EventDate]
				,	[SportType]
				,	[BetType]
				,	[IsLive]
				,	[MatchCount]
			)
			SELECT	tp.CustId
				,	tp.LeagueId
				,	@CurrentMonthStartDate AS EventDate
				,	tp.SportType
				,	tp.BetType
				,	tp.IsLive
				,	COUNT(DISTINCT tp.MatchId) AS MatchCount
			FROM #tmpTraderPerformance tp WITH(NOLOCK)
			GROUP BY tp.CustId
				,	tp.LeagueId
				,	tp.SportType
				,	tp.BetType
				,	tp.IsLive;

			INSERT INTO dbo.TraderMatchCount_Monthly
			(
					[CustId]
				,	[LeagueId]
				,	[EventDate]
				,	[SportType]
				,	[BetType]
				,	[IsLive]
				,	[MatchCount]
			)
			SELECT	tp.CustId
				,	tp.LeagueId
				,	@CurrentMonthStartDate AS EventDate
				,	tp.SportType
				,	tp.BetType
				,	-1 AS IsLive
				,	COUNT(DISTINCT tp.MatchId) AS MatchCount
			FROM #tmpTraderPerformance tp WITH(NOLOCK)
			GROUP BY tp.CustId
				,	tp.LeagueId
				,	tp.SportType
				,	tp.BetType;

			INSERT INTO dbo.TraderMatchCount_Monthly
			(
					[CustId]
				,	[LeagueId]
				,	[EventDate]
				,	[SportType]
				,	[BetType]
				,	[IsLive]
				,	[MatchCount]
			)
			SELECT	tp.CustId
				,	tp.LeagueId
				,	@CurrentMonthStartDate AS EventDate
				,	tp.SportType
				,	-1 AS BetType
				,	tp.IsLive
				,	COUNT(DISTINCT tp.MatchId) AS MatchCount
			FROM #tmpTraderPerformance tp WITH(NOLOCK)
			GROUP BY tp.CustId
				,	tp.LeagueId
				,	tp.SportType
				,	tp.IsLive;

			INSERT INTO dbo.TraderMatchCount_Monthly
			(
					[CustId]
				,	[LeagueId]
				,	[EventDate]
				,	[SportType]
				,	[BetType]
				,	[IsLive]
				,	[MatchCount]
			)
			SELECT	tp.CustId
				,	tp.LeagueId
				,	@CurrentMonthStartDate AS EventDate
				,	tp.SportType
				,	-1 AS BetType
				,	-1 AS IsLive
				,	COUNT(DISTINCT tp.MatchId) AS MatchCount
			FROM #tmpTraderPerformance tp WITH(NOLOCK)
			GROUP BY tp.CustId
				,	tp.LeagueId
				,	tp.SportType;

			DELETE	d
			FROM	#tmpWinlostDate AS d
			WHERE	d.winlostdate = @WinlostDate;

			TRUNCATE TABLE #tmpTraderPerformance;
		END;
	END;
END;

GO
/*<info serverAlias="DBTGRS-bodb_TGRS" executers="bodbTGRSNet"  isFunction="0" isNested="0"></info>*/
