ALTER PROCEDURE [dbo].[Task_StagingTraderPerformanceByYear_WithLiveIndicator]
		@GenerateFromDate		DATE = NULL
	,	@GenerateToDate			DATE = NULL
AS

/*
 Created:	20171127@Long
 Task :		Staging Data on TGRS DB By Year for Live & Non-Live tickets
 DB:		DBTGRS.bodb_TGRS
 Original:  
  
 Revisions:      
	- 20171127@Long:		Create new
	- 20180911@Long:		Support excluding Leagues from report [Redmine ID: #100322]
	- 20190304@Long:		Calc Actual-rate values for Soccer [Redmine ID: 108920]
	- 20190321@John:		Update Logic generating data [Redmine: #109599]
   	- 20210802@Adam.Tran: 	Sports - Performance Real Figures [Redmine: #158981]
 Param's Explanation:  
	 
 Exam:

*/
BEGIN;
	SET NOCOUNT ON
	
	DECLARE @CurrentYearStartDate		DATE
		,	@CurrentYearEndDate			DATE
		,	@LastYearStartDate			DATE
		,	@LastYearEndDate			DATE
		,	@WinlostDate				DATE
		,	@SumPreviousYear			BIT
		,	@Year						INT;

	IF (@GenerateFromDate IS NULL AND @GenerateToDate IS NULL)
	BEGIN
		SELECT @CurrentYearEndDate = GETDATE();
		SELECT @CurrentYearStartDate = DATEADD(YY, DATEDIFF(YY, 0, @CurrentYearEndDate), 0);
		SELECT @LastYearEndDate = DATEADD(DD, -1, @CurrentYearStartDate);
		SELECT @LastYearStartDate = DATEADD(YY, DATEDIFF(YY, 0, @LastYearEndDate), 0);
	 
		-- Update data for TraderPerformance Yearly
		SELECT @Year = YEAR(@CurrentYearEndDate);

		DELETE [dbo].[TraderPerformance_Yearly]	
		WHERE [Year] = @Year;

		INSERT INTO [dbo].[TraderPerformance_Yearly]
		(
				[CustId]
			,	[LeagueId]
			,	[Year]
			,	[SportType]
			,	[BetType]
			,	[IsLive]
			,	[Turnover]
			,	[WinLoss]
			,	[Comm]
			,	[Turnover_AR]
			,	[WinLoss_AR]
			,	[Comm_AR]
			,	[Is8RM]
			,	[Stake_Real]
			,	[WinLost_Real]
			,	[Stake_VAR]
			,	[WinLost_VAR]			
			,	[BetCount]
		)
		SELECT tpp.CustId
			,	tpp.LeagueId
			,	@Year AS [Year]
			,	tpp.SportType
			,	tpp.BetType
			,	tpp.IsLive
			,	SUM(tpp.Turnover) AS Turnover
			,	SUM(tpp.WinLoss) AS WinLoss
			,	SUM(tpp.Comm) AS Comm
			,	SUM(tpp.Turnover_AR) AS Turnover_AR
			,	SUM(tpp.WinLoss_AR) AS WinLoss_AR
			,	SUM(tpp.Comm_AR) AS Comm_AR
			,	tpp.Is8RM
			,	SUM(tpp.Stake_Real) AS Stake_Real
			,	SUM(tpp.WinLost_Real) AS WinLost_Real
			,	SUM(tpp.Stake_VAR) AS Stake_VAR
			,	SUM(tpp.WinLost_VAR) AS WinLost_VAR			
			,	SUM(tpp.BetCount) AS BetCount
		FROM [dbo].[TraderPerformance_Monthly] tpp WITH(NOLOCK)
		WHERE tpp.EventDate BETWEEN @CurrentYearStartDate AND @CurrentYearEndDate
		GROUP BY tpp.CustId
			,	tpp.LeagueId
			,	tpp.SportType
			,	tpp.BetType
			,	tpp.IsLive
			,	tpp.Is8RM;
		
		-- Update data for TraderMatchCount_Yearly	
		DELETE [dbo].[TraderMatchCount_Yearly]	
		WHERE [Year] = @Year;

		INSERT INTO dbo.[TraderMatchCount_Yearly]
		(
				[CustId]
			,	[LeagueId]
			,	[Year]
			,	[SportType]
			,	[BetType]
			,	[IsLive]
			,	[MatchCount]
		)
		SELECT	tp.CustId
			,	tp.LeagueId
			,	@Year AS [Year]
			,	tp.SportType
			,	tp.BetType
			,	tp.IsLive
			,	SUM(tp.MatchCount) AS MatchCount
		FROM TraderMatchCount_Monthly tp WITH(NOLOCK)
		WHERE tp.EventDate BETWEEN @CurrentYearStartDate AND @CurrentYearEndDate
		GROUP BY tp.CustId
			,	tp.LeagueId
			,	tp.SportType
			,	tp.BetType
			,	tp.IsLive;

		-- Check whether to re-sum data for the previous year
		IF (MONTH(@CurrentYearEndDate) = 1 AND DAY(@CurrentYearEndDate) < 14)
		BEGIN
			-- Update data for TraderPerformance Yearly
			SELECT @Year = YEAR(@LastYearEndDate);
			DELETE [dbo].[TraderPerformance_Yearly]	
			WHERE [Year] = @Year;

			INSERT INTO [dbo].[TraderPerformance_Yearly]
			(
					[CustId]
				,	[LeagueId]
				,	[Year]
				,	[SportType]
				,	[BetType]
				,	[IsLive]
				,	[Turnover]
				,	[WinLoss]
				,	[Comm]
				,	[Turnover_AR]
				,	[WinLoss_AR]
				,	[Comm_AR]
				,	[Is8RM]
				,	[Stake_Real]
				,	[WinLost_Real]
				,	[Stake_VAR]
				,	[WinLost_VAR]				
				,	[BetCount]
			)
			SELECT tpp.CustId
				,	tpp.LeagueId
				,	@Year AS [Year]
				,	tpp.SportType
				,	tpp.BetType
				,	tpp.IsLive
				,	SUM(tpp.Turnover) AS Turnover
				,	SUM(tpp.WinLoss) AS WinLoss
				,	SUM(tpp.Comm) AS Comm
				,	SUM(tpp.Turnover_AR) AS Turnover_AR
				,	SUM(tpp.WinLoss_AR) AS WinLoss_AR
				,	SUM(tpp.Comm_AR) AS Comm_AR
				,	tpp.Is8RM
				,	SUM(tpp.Stake_Real) AS Stake_Real
				,	SUM(tpp.WinLost_Real) AS WinLost_Real
				,	SUM(tpp.Stake_VAR) AS Stake_VAR
				,	SUM(tpp.WinLost_VAR) AS WinLost_VAR				
				,	SUM(tpp.BetCount) AS BetCount
			FROM [dbo].[TraderPerformance_Monthly] tpp WITH(NOLOCK)
			WHERE tpp.EventDate BETWEEN @LastYearStartDate AND @LastYearEndDate
			GROUP BY tpp.CustId
				,	tpp.LeagueId
				,	tpp.SportType
				,	tpp.BetType
				,	tpp.IsLive
				,	tpp.Is8RM;

			-- Update data for TraderMatchCount_Yearly
			DELETE [dbo].[TraderMatchCount_Yearly]	
			WHERE [Year] = @Year;

			INSERT INTO dbo.[TraderMatchCount_Yearly]
			(
					[CustId]
				,	[LeagueId]
				,	[Year]
				,	[SportType]
				,	[BetType]
				,	[IsLive]
				,	[MatchCount]
			)
			SELECT	tp.CustId
				,	tp.LeagueId
				,	@Year AS [Year]
				,	tp.SportType
				,	tp.BetType
				,	tp.IsLive
				,	SUM(tp.MatchCount) AS MatchCount
			FROM TraderMatchCount_Monthly tp WITH(NOLOCK)
			WHERE tp.EventDate BETWEEN @LastYearStartDate AND @LastYearEndDate
			GROUP BY tp.CustId
				,	tp.LeagueId
				,	tp.SportType
				,	tp.BetType
				,	tp.IsLive;
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
			SELECT	[NoYears] = DATEDIFF(YEAR, @GenerateFromDate, @GenerateToDate) + 1
		) cnt
		CROSS APPLY	(
			SELECT	TOP(cnt.NoYears)
					[EventDate] = DATEADD(YEAR, ROW_NUMBER() OVER(ORDER BY (SELECT NULL)) - 1, @GenerateFromDate)
			FROM		(VALUES (0), (0), (0), (0), (0), (0), (0), (0), (0), (0)) x10(n)
			CROSS APPLY	(VALUES (0), (0), (0), (0), (0), (0), (0), (0), (0), (0)) x100(n)
			CROSS APPLY	(VALUES (0), (0), (0), (0), (0), (0), (0), (0), (0), (0)) x1000(n)
		) tally;

		WHILE	EXISTS (SELECT 1 FROM #tmpWinlostDate)
		BEGIN;
			SELECT	TOP(1)
					@WinLostDate = d.winlostdate
			FROM	#tmpWinlostDate AS d;

			SELECT @CurrentYearStartDate = DATEADD(YY, DATEDIFF(YY, 0, @WinLostDate), 0);
			SELECT @CurrentYearEndDate = DATEADD(DD, -1 , DATEADD(YY, 1, @CurrentYearStartDate));
	 
			-- Update data for TraderPerformance Yearly
			SELECT @Year = YEAR(@CurrentYearStartDate);

			DELETE [dbo].[TraderPerformance_Yearly]	
			WHERE [Year] = @Year;

			INSERT INTO [dbo].[TraderPerformance_Yearly]
			(
					[CustId]
				,	[LeagueId]
				,	[Year]
				,	[SportType]
				,	[BetType]
				,	[IsLive]
				,	[Turnover]
				,	[WinLoss]
				,	[Comm]
				,	[Turnover_AR]
				,	[WinLoss_AR]
				,	[Comm_AR]
				,	[Is8RM]
				,	[Stake_Real]
				,	[WinLost_Real]
				,	[Stake_VAR]
				,	[WinLost_VAR]				
				,	[BetCount]
			)
			SELECT	tpp.CustId
				,	tpp.LeagueId
				,	@Year AS [Year]
				,	tpp.SportType
				,	tpp.BetType
				,	tpp.IsLive
				,	SUM(tpp.Turnover) AS Turnover
				,	SUM(tpp.WinLoss) AS WinLoss
				,	SUM(tpp.Comm) AS Comm
				,	SUM(tpp.Turnover_AR) AS Turnover_AR
				,	SUM(tpp.WinLoss_AR) AS WinLoss_AR
				,	SUM(tpp.Comm_AR) AS Comm_AR
				,	tpp.Is8RM
				,	SUM(tpp.Stake_Real) AS Stake_Real
				,	SUM(tpp.WinLost_Real) AS WinLost_Real
				,	SUM(tpp.Stake_VAR) AS Stake_VAR
				,	SUM(tpp.WinLost_VAR) AS WinLost_VAR				
				,	SUM(tpp.BetCount) AS BetCount
			FROM [dbo].[TraderPerformance_Monthly] tpp WITH(NOLOCK)
			WHERE tpp.EventDate BETWEEN @CurrentYearStartDate AND @CurrentYearEndDate
			GROUP BY tpp.CustId
				,	tpp.LeagueId
				,	tpp.SportType
				,	tpp.BetType
				,	tpp.IsLive
				,	tpp.Is8RM;
		
			-- Update data for TraderMatchCount_Yearly	
			DELETE [dbo].[TraderMatchCount_Yearly]	
			WHERE [Year] = @Year;

			INSERT INTO dbo.[TraderMatchCount_Yearly]
			(
					[CustId]
				,	[LeagueId]
				,	[Year]
				,	[SportType]
				,	[BetType]
				,	[IsLive]
				,	[MatchCount]
			)
			SELECT	tp.CustId
				,	tp.LeagueId
				,	@Year AS [Year]
				,	tp.SportType
				,	tp.BetType
				,	tp.IsLive
				,	SUM(tp.MatchCount) AS MatchCount
			FROM TraderMatchCount_Monthly tp WITH(NOLOCK)
			WHERE tp.EventDate BETWEEN @CurrentYearStartDate AND @CurrentYearEndDate
			GROUP BY tp.CustId
				,	tp.LeagueId
				,	tp.SportType
				,	tp.BetType
				,	tp.IsLive;

			DELETE	d
			FROM	#tmpWinlostDate AS d
			WHERE	d.winlostdate = @WinlostDate;
		END;
	END;
END;

