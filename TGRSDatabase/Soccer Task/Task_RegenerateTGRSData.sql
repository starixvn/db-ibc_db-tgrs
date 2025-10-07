ALTER PROCEDURE dbo.Task_RegenerateTGRSData
				@Debug			BIT = 0
			,	@FromDate		DATETIME
			,	@ToDate			DATETIME
			,	@Flagged		TINYINT	= 0
AS
/*
	Created: 20190701@John.Ngo
	Task : Detect the changes within 7 days instead of 3 days [Redmine ID: 115780]
	DB: DB06.bodb_TGRS
	Original:

	Revisions:		
		- 20190627@John.Ngo: Void/Recover bet now support up to 7 days, so Data Daily & Summary need to regenerate data changes within 7 days as well [Redmine ID: 115780]
		- 20191018@John.Ngo: Update logic generate data [Redmine ID: 118959]
		- 20200106@John.Ngo: Update generate data for RT3 [Redmine ID: 123714]
		- 20200407@John.Ngo: Call xtest for SPs [Redmine ID: 120634]
		- 20230606@John.Ngo: Update generate data for E-Sports/Basketball trader performance by class [Redmine ID: 187083]
		- 20250915@Jaden.Tang: Updated Task_StagingJuice params [Redmine ID: #237899]

	Param's Explanation (filtered by):
		@Flagged: 0 - All, 1 - For Soccer, 2 - For OS, 3 - For RT3
*/
BEGIN SET NOCOUNT ON;

DECLARE @EventDate		DATE
	,   @Month			DATE
	,	@StartDate		DATE
	,	@EndDate		DATE
	,	@Msg			NVARCHAR(250)
	;

IF	OBJECT_ID('tempdb..#EventDate') IS NOT NULL
BEGIN
	DROP TABLE	#EventDate;
END;

CREATE TABLE	#EventDate (EventDate DATE, isDone BIT DEFAULT (0));

-- Start Regenerate TGRS Data for Soccer
IF (@Flagged = 0 OR @Flagged = 1)
BEGIN
	INSERT INTO	#EventDate (EventDate)
	SELECT	tally.EventDate
	FROM	(
		SELECT	[NoDays] = DATEDIFF(DAY, @FromDate, @ToDate) + 1
	) cnt
	CROSS APPLY	(
		SELECT	TOP(cnt.NoDays)
				[EventDate] = DATEADD(DAY, ROW_NUMBER() OVER(ORDER BY (SELECT NULL)) - 1, @FromDate)
		FROM		(VALUES (0), (0), (0), (0), (0), (0), (0), (0), (0), (0)) x10(n)
		CROSS APPLY	(VALUES (0), (0), (0), (0), (0), (0), (0), (0), (0), (0)) x100(n)
		CROSS APPLY	(VALUES (0), (0), (0), (0), (0), (0), (0), (0), (0), (0)) x1000(n)
	) tally;

	WHILE (1 = 1)
	BEGIN
		SELECT	TOP(1)
				@StartDate = DATEADD(DAY, 1 - DAY(EventDate), EventDate)
		FROM	#EventDate AS ed WITH (NOLOCK)
		WHERE	ed.isDone = 0
		ORDER BY EventDate DESC;

		SELECT @EndDate = DATEADD(DD, -1 ,DATEADD(MM, 1, @StartDate));

		IF NOT EXISTS (SELECT TOP(1) ed.isDone FROM #EventDate AS ed WHERE ed.isDone = 0)
			BREAK;

		WHILE (1 = 1)
		BEGIN
			SELECT TOP(1) @EventDate = EventDate
			FROM	#EventDate AS ed
			WHERE	ed.isDone = 0
				AND EventDate BETWEEN @StartDate AND @EndDate
			ORDER BY EventDate DESC;

			IF	@@ROWCOUNT = 0
				BREAK;

			-- Step 1: Daily
			IF	@Debug = 1
			BEGIN
				SELECT	@Msg = 'Run Job Task_StagingDataTGRS @GenerateFromDate = ' + CONVERT(NVARCHAR, @EventDate, 120) + N', @GenerateToDate  = ' + CONVERT(NVARCHAR, @EventDate, 120);
				RAISERROR(@Msg, 0, 0) WITH NOWAIT;
			END;

			EXECUTE dbo.Task_StagingDataTGRS @Debug = @Debug, @GenerateFromDate = @EventDate, @GenerateToDate = @EventDate;

			-- Step 2: Juice
			IF	@Debug = 1
			BEGIN
				SELECT	@Msg = 'Run Job Task_StagingJuice @GenerateFromDate = ' + CONVERT(NVARCHAR, @EventDate, 120) + N', @GenerateToDate  = ' + CONVERT(NVARCHAR, @EventDate, 120);
				RAISERROR(@Msg, 0, 0) WITH NOWAIT;
			END;

			EXECUTE dbo.Task_StagingJuice @GenerateFromDate = @EventDate, @GenerateToDate = @EventDate;

			-- Step 3: Job Task_StagingTraderPerformanceByDate after calc daily & juice
			IF	@Debug = 1
			BEGIN
				SELECT	@Msg = 'Run Job Task_StagingTraderPerformanceByDate @EventDate = ' + CONVERT(NVARCHAR, @EventDate, 120);
				RAISERROR(@Msg, 0, 0) WITH NOWAIT;
			END;

			EXECUTE dbo.Task_StagingTraderPerformanceByDate @Date = @EventDate

			UPDATE #EventDate SET isDone = 1
			WHERE EventDate = @EventDate AND isDone = 0;
		END;

		-- Step 4: Sum Monthly
		IF	@Debug = 1
		BEGIN
				SELECT	@Msg = 'Run Job Task_StagingTraderPerformanceByMonth @GenerateFromDate = ' + CONVERT(NVARCHAR, @StartDate, 120) + N', @GenerateToDate  = ' + CONVERT(NVARCHAR, @EndDate, 120);
				RAISERROR(@Msg, 0, 0) WITH NOWAIT;
		END;

		EXECUTE dbo.Task_StagingTraderPerformanceByMonth @GenerateFromDate = @StartDate, @GenerateToDate = @EndDate;

		IF	@Debug = 1
		BEGIN
				SELECT	@Msg = 'Run Job Task_StagingTraderPerformanceByMonth_WithLiveIndicator @GenerateFromDate = ' + CONVERT(NVARCHAR, @StartDate, 120) + N', @GenerateToDate  = ' + CONVERT(NVARCHAR, @EndDate, 120);
				RAISERROR(@Msg, 0, 0) WITH NOWAIT;
		END;

		EXECUTE	dbo.Task_StagingTraderPerformanceByMonth_WithLiveIndicator @GenerateFromDate = @StartDate, @GenerateToDate = @EndDate;
	END;

	-- Step 5: Sum Yearly
	IF	@Debug = 1
	BEGIN
		SELECT	@Msg = 'Run Job Task_StagingTraderPerformanceByYear_WithLiveIndicator @GenerateFromDate = ' + CONVERT(NVARCHAR, @FromDate, 120) + N', @GenerateToDate  = ' + CONVERT(NVARCHAR, @ToDate, 120);
		RAISERROR(@Msg, 0, 0) WITH NOWAIT;
	END;

	EXECUTE	dbo.Task_StagingTraderPerformanceByYear_WithLiveIndicator @GenerateFromDate = @FromDate, @GenerateToDate = @ToDate;

END;
-- End Regenerate TGRS Data for Soccer 

-- Start Regenerate TGRS Data for OS
IF (@Flagged = 0 OR @Flagged = 2)
BEGIN
	TRUNCATE TABLE #EventDate;
	INSERT INTO	#EventDate (EventDate)
	SELECT	tally.EventDate
	FROM	(
		SELECT	[NoDays] = DATEDIFF(DAY, @FromDate, @ToDate) + 1
	) cnt
	CROSS APPLY	(
		SELECT	TOP(cnt.NoDays)
				[EventDate] = DATEADD(DAY, ROW_NUMBER() OVER(ORDER BY (SELECT NULL)) - 1, @FromDate)
		FROM		(VALUES (0), (0), (0), (0), (0), (0), (0), (0), (0), (0)) x10(n)
		CROSS APPLY	(VALUES (0), (0), (0), (0), (0), (0), (0), (0), (0), (0)) x100(n)
		CROSS APPLY	(VALUES (0), (0), (0), (0), (0), (0), (0), (0), (0), (0)) x1000(n)
	) tally;

	WHILE (1 = 1)
	BEGIN
		SELECT	TOP(1)
				@StartDate = DATEADD(DAY, 1 - DAY(EventDate), EventDate)
		FROM	#EventDate AS ed WITH (NOLOCK)
		WHERE	ed.isDone = 0
		ORDER BY EventDate DESC;

		SELECT @EndDate = DATEADD(DD, -1 ,DATEADD(MM, 1, @StartDate));

		IF NOT EXISTS (SELECT TOP(1) ed.isDone FROM #EventDate AS ed WHERE ed.isDone = 0)
			BREAK;

		UPDATE	#EventDate
		SET		isDone = 0
		WHERE	EventDate BETWEEN @StartDate AND @EndDate;

		WHILE (1 = 1)
		BEGIN
			SELECT TOP(1) @EventDate = EventDate
			FROM #EventDate AS ed
			WHERE ed.isDone = 0 AND EventDate BETWEEN @StartDate AND @EndDate ORDER BY EventDate DESC;

			IF	@@ROWCOUNT = 0
				BREAK;
			
			-- Step 1: Daily
			IF	@Debug = 1
			BEGIN
				SELECT	@Msg = 'Run Job Task_StagingOSDataTGRS @GenerateFromDate = ' + CONVERT(NVARCHAR, @EventDate, 120) + N', @GenerateToDate  = ' + CONVERT(NVARCHAR, @EventDate, 120);
				RAISERROR(@Msg, 0, 0) WITH NOWAIT;
			END;

			EXECUTE dbo.Task_StagingOSDataTGRS @Debug = @Debug, @GenerateFromDate = @EventDate, @GenerateToDate = @EventDate;

			-- Step 2: Juice
			IF	@Debug = 1
			BEGIN
				SELECT	@Msg = 'Run Job Task_StagingOSJuice @GenerateFromDate = ' + CONVERT(NVARCHAR, @EventDate, 120) + N', @GenerateToDate  = ' + CONVERT(NVARCHAR, @EventDate, 120);
				RAISERROR(@Msg, 0, 0) WITH NOWAIT;
			END;

			EXECUTE dbo.Task_StagingOSJuice @Debug = @Debug, @GenerateFromDate =@EventDate, @GenerateToDate = @EventDate;
			
			-- 'Task_StagingOSDataCustomerClass' Daily 
			IF	@Debug = 1
			BEGIN
				SELECT	@Msg = 'Run Job Task_StagingOSDataCustomerClass @GenerateFromDate = ' + CONVERT(NVARCHAR, @EventDate, 120) + N', @GenerateToDate  = ' + CONVERT(NVARCHAR, @EventDate, 120);
				RAISERROR(@Msg, 0, 0) WITH NOWAIT;
			END;

			EXECUTE dbo.Task_StagingOSDataCustomerClass @Debug = @Debug, @GenerateFromDate =@EventDate, @GenerateToDate = @EventDate;
			
			-- Step 3: Sum Daily
			IF	@Debug = 1
			BEGIN
				SELECT	@Msg = 'Run Job Task_StagingOSTraderPerformanceByDate @EventDate = ' + CONVERT(NVARCHAR, @EventDate, 120);
				RAISERROR(@Msg, 0, 0) WITH NOWAIT;
			END;

			EXECUTE dbo.Task_StagingOSTraderPerformanceByDate @Date = @EventDate

			UPDATE	#EventDate
			SET		isDone = 1
			WHERE	EventDate = @EventDate 
				AND	isDone = 0;
		END;

		-- Step 4: Sum Monthly
		IF	@Debug = 1
		BEGIN
				SELECT	@Msg = 'Run Job Task_StagingOSTraderPerformanceMonthly @Month = ' + CONVERT(NVARCHAR, @StartDate, 120);
				RAISERROR(@Msg, 0, 0) WITH NOWAIT;
		END;

		EXECUTE dbo.Task_StagingOSTraderPerformanceMonthly @Month = @StartDate;
	END;
END;
-- End Regenerate TGRS Data for OS

-- Start Regenerate RT3 Data
IF (@Flagged = 0 OR @Flagged = 3)
BEGIN
	INSERT INTO	#EventDate (EventDate)
	SELECT	tally.EventDate
	FROM	(
		SELECT	[NoDays] = DATEDIFF(DAY, @FromDate, @ToDate) + 1
	) cnt
	CROSS APPLY	(
		SELECT	TOP(cnt.NoDays)
				[EventDate] = DATEADD(DAY, ROW_NUMBER() OVER(ORDER BY (SELECT NULL)) - 1, @FromDate)
		FROM		(VALUES (0), (0), (0), (0), (0), (0), (0), (0), (0), (0)) x10(n)
		CROSS APPLY	(VALUES (0), (0), (0), (0), (0), (0), (0), (0), (0), (0)) x100(n)
		CROSS APPLY	(VALUES (0), (0), (0), (0), (0), (0), (0), (0), (0), (0)) x1000(n)
	) tally;

	WHILE (1 = 1)
	BEGIN
		SELECT	TOP(1)
				@StartDate = DATEADD(DAY, 1 - DAY(EventDate), EventDate)
		FROM	#EventDate AS ed WITH (NOLOCK)
		WHERE	ed.isDone = 0
		ORDER BY EventDate DESC;

		SELECT @EndDate = DATEADD(DD, -1 ,DATEADD(MM, 1, @StartDate));

		IF NOT EXISTS (SELECT TOP(1) ed.isDone FROM #EventDate AS ed WHERE ed.isDone = 0)
			BREAK;

		WHILE (1 = 1)
		BEGIN
			SELECT TOP(1) @EventDate = EventDate
			FROM	#EventDate AS ed
			WHERE	ed.isDone = 0
				AND EventDate BETWEEN @StartDate AND @EndDate
			ORDER BY EventDate DESC;

			IF	@@ROWCOUNT = 0
				BREAK;

			-- Step 1: Daily
			IF	@Debug = 1
			BEGIN
				SELECT	@Msg = 'Run Job Task_RobotTrading_StagingData @GenerateFromDate = ' + CONVERT(NVARCHAR, @EventDate, 120) + N', @GenerateToDate  = ' + CONVERT(NVARCHAR, @EventDate, 120);
				RAISERROR(@Msg, 0, 0) WITH NOWAIT;
			END;

			EXECUTE dbo.Task_RobotTrading_StagingData @Debug = @Debug, @GenerateFromDate = @EventDate, @GenerateToDate = @EventDate;

			-- Step 2: Job Task_RobotTrading_SummaryByDate after calc daily
			IF	@Debug = 1
			BEGIN
				SELECT	@Msg = 'Run Job Task_RobotTrading_SummaryByDate @EventDate = ' + CONVERT(NVARCHAR, @EventDate, 120);
				RAISERROR(@Msg, 0, 0) WITH NOWAIT;
			END;

			EXECUTE dbo.Task_RobotTrading_SummaryByDate @Date = @EventDate

			UPDATE #EventDate SET isDone = 1
			WHERE EventDate = @EventDate AND isDone = 0;
		END;

		-- Step 3: Sum Monthly
		IF	@Debug = 1
		BEGIN
				SELECT	@Msg = 'Run Job Task_RobotTrading_SummaryByMonth @GenerateFromDate = ' + CONVERT(NVARCHAR, @StartDate, 120) + N', @GenerateToDate  = ' + CONVERT(NVARCHAR, @EndDate, 120);
				RAISERROR(@Msg, 0, 0) WITH NOWAIT;
		END;

		EXECUTE dbo.Task_RobotTrading_SummaryByMonth @GenerateFromDate = @StartDate, @GenerateToDate = @EndDate;

	END;

END;
-- End Regenerate RT3 Data

END;

GO
/*<info serverAlias="DBTGRS-bodb_TGRS" executers="wsv_tgrs" isFunction="0" isNested="0"></info>*/