CREATE PROCEDURE dbo.Task_RegenerateTGRSData
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

	Param's Explanation (filtered by):
		@Flagged: 0 - All, 1 - For Soccer, 2 - For OS
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

		SELECT @StartDate = (SELECT TOP (1) DATEADD(DAY, 1 - DAY(EventDate), EventDate)
						FROM #EventDate AS ed WITH (NOLOCK) WHERE ed.isDone = 0 ORDER BY EventDate DESC);
		SELECT @EndDate = DATEADD(DD, -1 ,DATEADD(MM, 1, @StartDate));
	
		IF NOT EXISTS (SELECT TOP(1) ed.isDone FROM #EventDate AS ed WHERE ed.isDone = 0)
			BEGIN
				BREAK;
			END;
		ELSE
			BEGIN
				-- Step 1: Daily
				INSERT INTO	#EventDate (EventDate)
				SELECT EventDate FROM #EventDate WHERE EventDate BETWEEN @StartDate AND @EndDate;		
			
				IF @StartDate < @FromDate
					BEGIN
						SELECT @StartDate = @FromDate
					END;
			
				IF @EndDate > @ToDate
					BEGIN
						SELECT @EndDate = @ToDate
					END;

				IF	@Debug = 1
				BEGIN
					SELECT	@Msg = 'Run Job Task_StagingDataTGRS @GenerateFromDate = ' + CONVERT(NVARCHAR, @StartDate, 120) + N', @GenerateToDate  = ' + CONVERT(NVARCHAR, @EndDate, 120);
					RAISERROR(@Msg, 0, 0) WITH NOWAIT;
				END;

				EXECUTE dbo.Task_StagingDataTGRS @Debug = @Debug, @GenerateFromDate = @StartDate, @GenerateToDate = @EndDate;

				-- Step 2: Juice
				IF	@Debug = 1
				BEGIN
					SELECT	@Msg = 'Run Job Task_StagingJuice @GenerateFromDate = ' + CONVERT(NVARCHAR, @StartDate, 120) + N', @GenerateToDate  = ' + CONVERT(NVARCHAR, @EndDate, 120);
					RAISERROR(@Msg, 0, 0) WITH NOWAIT;
				END;
				
				EXECUTE dbo.Task_StagingJuice @Debug = @Debug, @GenerateFromDate = @StartDate, @GenerateToDate = @EndDate;

				UPDATE #EventDate SET isDone = 0
				WHERE EventDate BETWEEN @StartDate AND @EndDate;

				-- Step 3: Job Task_StagingTraderPerformanceByDate after calc daily & juice
				WHILE (1 = 1)
				BEGIN
					SELECT TOP(1) @EventDate = EventDate
					FROM #EventDate AS ed
					WHERE ed.isDone = 0 AND EventDate BETWEEN @StartDate AND @EndDate ORDER BY EventDate DESC;

					IF NOT EXISTS (SELECT TOP(1) ed.isDone FROM #EventDate AS ed WHERE ed.isDone = 0 AND EventDate BETWEEN @StartDate AND @EndDate)
						BEGIN
							BREAK;
						END;
					ELSE
						BEGIN
							IF	@Debug = 1
							BEGIN
								SELECT	@Msg = 'Run Job Task_StagingTraderPerformanceByDate @EventDate = ' + CONVERT(NVARCHAR, @EventDate, 120);
								RAISERROR(@Msg, 0, 0) WITH NOWAIT;
							END;
					
							EXECUTE dbo.Task_StagingTraderPerformanceByDate @Date = @EventDate
					
						END;

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

		UPDATE #EventDate SET isDone = 1
		WHERE DATEPART(MONTH, EventDate) = DATEPART(MONTH, @StartDate)
		  AND DATEPART(YEAR, EventDate) = DATEPART(YEAR, @StartDate);
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

		SELECT @StartDate = (SELECT TOP (1) DATEADD(DAY, 1 - DAY(EventDate), EventDate)
						FROM #EventDate AS ed WITH (NOLOCK) WHERE ed.isDone = 0 ORDER BY EventDate DESC);
		SELECT @EndDate = DATEADD(DD, -1 ,DATEADD(MM, 1, @StartDate));
	
		IF NOT EXISTS (SELECT TOP(1) ed.isDone FROM #EventDate AS ed WHERE ed.isDone = 0)
			BEGIN
				BREAK;
			END;
		ELSE
			BEGIN
				-- Step 1: Daily
				INSERT INTO	#EventDate (EventDate)
				SELECT EventDate FROM #EventDate WHERE EventDate BETWEEN @StartDate AND @EndDate;		
			
				IF @StartDate < @FromDate
					BEGIN
						SELECT @StartDate = @FromDate
					END;
			
				IF @EndDate > @ToDate
					BEGIN
						SELECT @EndDate = @ToDate
					END;

				IF	@Debug = 1
				BEGIN
					SELECT	@Msg = 'Run Job Task_StagingOSDataTGRS @GenerateFromDate = ' + CONVERT(NVARCHAR, @StartDate, 120) + N', @GenerateToDate  = ' + CONVERT(NVARCHAR, @EndDate, 120);
					RAISERROR(@Msg, 0, 0) WITH NOWAIT;
				END;
			
				EXECUTE dbo.Task_StagingOSDataTGRS @Debug = @Debug, @GenerateFromDate = @StartDate, @GenerateToDate = @EndDate;

				-- Step 2: Juice
				IF	@Debug = 1
				BEGIN
					SELECT	@Msg = 'Run Job Task_StagingOSJuice @GenerateFromDate = ' + CONVERT(NVARCHAR, @StartDate, 120) + N', @GenerateToDate  = ' + CONVERT(NVARCHAR, @EndDate, 120);
					RAISERROR(@Msg, 0, 0) WITH NOWAIT;
				END;

				EXECUTE dbo.Task_StagingOSJuice @Debug = @Debug, @GenerateFromDate = @StartDate, @GenerateToDate = @EndDate;

				UPDATE #EventDate SET isDone = 0
				WHERE EventDate BETWEEN @StartDate AND @EndDate;

				-- Step 3: Job Task_StagingTraderPerformanceByDate after calc daily & juice
				WHILE (1 = 1)
				BEGIN
					SELECT TOP(1) @EventDate = EventDate
					FROM #EventDate AS ed
					WHERE ed.isDone = 0 AND EventDate BETWEEN @StartDate AND @EndDate ORDER BY EventDate DESC;

					IF NOT EXISTS (SELECT TOP(1) ed.isDone FROM #EventDate AS ed WHERE ed.isDone = 0 AND EventDate BETWEEN @StartDate AND @EndDate)
						BEGIN
							BREAK;
						END;
					ELSE
						BEGIN
							IF	@Debug = 1
							BEGIN
								SELECT	@Msg = 'Run Job Task_StagingOSTraderPerformanceByDate @EventDate = ' + CONVERT(NVARCHAR, @EventDate, 120);
								RAISERROR(@Msg, 0, 0) WITH NOWAIT;
							END;

							EXECUTE dbo.Task_StagingOSTraderPerformanceByDate @Date = @EventDate
					
						END;

					UPDATE #EventDate SET isDone = 1
					WHERE EventDate = @EventDate AND isDone = 0;
				END;
		
			-- Step 4: Sum Monthly
			IF	@Debug = 1
			BEGIN
					SELECT	@Msg = 'Run Job Task_StagingOSTraderPerformanceMonthly @Month = ' + CONVERT(NVARCHAR, @StartDate, 120);
					RAISERROR(@Msg, 0, 0) WITH NOWAIT;
			END;

			EXECUTE dbo.Task_StagingOSTraderPerformanceMonthly @Month = @StartDate;
		
			END;

		UPDATE #EventDate SET isDone = 1
		WHERE DATEPART(MONTH, EventDate) = DATEPART(MONTH, @StartDate)
		  AND DATEPART(YEAR, EventDate) = DATEPART(YEAR, @StartDate);
	END;
END;
-- End Regenerate TGRS Data for OS

END;

GO
/*<info serverAlias="DBTGRS-bodb_TGRS" executers="bodbTGRSNet" isFunction="0" isNested="0"></info>*/