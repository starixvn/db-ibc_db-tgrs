USE msdb;
GO

BEGIN TRANSACTION;
DECLARE @ReturnCode INT = 0;

/********************************************************************
-- JOB INFO
********************************************************************/
DECLARE @jobId BINARY(16);
DECLARE @jobName NVARCHAR(128) = N'TGRS - Staging RealTime OS Data (Frequent)';
DECLARE @jobEnabled BIT = 1;
DECLARE @jobDescription NVARCHAR(512) = N'Runs dbo.Task_StagingRealTimeOSData_WithSummaries frequently to update OS data, avoiding collision with the daily OS job.';
DECLARE @jobCategoryName NVARCHAR(128) = N'TGRS';
DECLARE @jobOwnerLoginName NVARCHAR(128) = N'sa'; -- Change if needed

-- Delete existing job with the same name if it exists
SELECT @jobId = job_id FROM msdb.dbo.sysjobs WHERE name = @jobName;
IF (@jobId IS NOT NULL)
BEGIN
    EXEC msdb.dbo.sp_delete_job @job_name = @jobName;
    SELECT @jobId = NULL;
END;

-- Add the job
EXEC @ReturnCode = msdb.dbo.sp_add_job
    @job_name = @jobName,
    @enabled = @jobEnabled,
    @notify_level_eventlog = 0,
    @notify_level_email = 0,
    @notify_level_netsend = 0,
    @notify_level_page = 0,
    @delete_level = 0,
    @description = @jobDescription,
    @category_name = @jobCategoryName,
    @owner_login_name = @jobOwnerLoginName,
    @job_id = @jobId OUTPUT;

IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback;

/********************************************************************
-- JOB STEP
********************************************************************/
DECLARE @stepName NVARCHAR(128) = N'Run Task_StagingRealTimeOSData_WithSummaries with Collision Check';
DECLARE @stepSubsystem NVARCHAR(40) = N'TSQL';
DECLARE @stepCommand NVARCHAR(MAX);
DECLARE @stepDatabaseName NVARCHAR(128) = N'bodb_TGRS'; -- Database where your SP exists
DECLARE @dailyJobNameToCheck NVARCHAR(128) = N'TGRS-Staging OS Data Daily';

SET @stepCommand = N'
DECLARE @IsDailyJobRunning BIT = 0;
DECLARE @DailyJobIdToCheck UNIQUEIDENTIFIER;
DECLARE @DailyJobName NVARCHAR(128) = N''' + REPLACE(@dailyJobNameToCheck, N'''', N'''''') + N'''; -- Handle potential quotes in job name

-- Get the job_id for the daily job by its name
SELECT @DailyJobIdToCheck = job_id
FROM msdb.dbo.sysjobs
WHERE name = @DailyJobName;

IF @DailyJobIdToCheck IS NULL
BEGIN
    PRINT N''Warning: Daily OS Staging Job named '''''' + @DailyJobName + N'''''' not found. This frequent job will run without collision check against it.'';
    -- Decide if you want to proceed or fail if the daily job isn''t found.
    -- For now, it proceeds. To fail, you could RAISERROR or RETURN with an error code.
END
ELSE
BEGIN
    -- Check if the daily job is currently running using its retrieved job_id
    IF EXISTS (
        SELECT 1
        FROM msdb.dbo.sysjobactivity ja
        WHERE ja.job_id = @DailyJobIdToCheck
          AND ja.start_execution_date IS NOT NULL -- Job has started
          AND ja.stop_execution_date IS NULL    -- Job has not stopped
          AND ja.session_id = (SELECT MAX(session_id) FROM msdb.dbo.sysjobactivity WHERE job_id = @DailyJobIdToCheck) -- Current or most recent session
    )
    BEGIN
        SET @IsDailyJobRunning = 1;
    END
END

IF @IsDailyJobRunning = 1
BEGIN
    PRINT N''Daily OS Staging Job (Name: '''''' + @DailyJobName + N'''''' / ID: '' + CAST(@DailyJobIdToCheck AS NVARCHAR(36)) + N'') is currently running. Skipping this execution.'';
    RETURN; -- Exit gracefully
END
ELSE
BEGIN
    PRINT N''Daily OS Staging Job (Name: '''''' + @DailyJobName + N'''''') is not running or not found. Proceeding with Task_StagingRealTimeOSData_WithSummaries.'';
    EXEC bodb_tgrs.dbo.Task_StagingRealTimeOSData_WithSummaries @Debug = 0;
END';

EXEC @ReturnCode = msdb.dbo.sp_add_jobstep
    @job_id = @jobId,
    @step_name = @stepName,
    @step_id = 1,
    @cmdexec_success_code = 0,
    @on_success_action = 1, -- Quit with success
    @on_success_step_id = 0,
    @on_fail_action = 2,    -- Quit with failure
    @on_fail_step_id = 0,
    @retry_attempts = 0,
    @retry_interval = 0,
    @os_run_priority = 0,
    @subsystem = @stepSubsystem,
    @command = @stepCommand,
    @database_name = @stepDatabaseName,
    @flags = 0;

IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback;

/********************************************************************
-- JOB SCHEDULE
********************************************************************/
DECLARE @scheduleName NVARCHAR(128) = N'Run Every 5 Minutes';
DECLARE @scheduleEnabled BIT = 1;
DECLARE @freqType INT = 4;         -- 4 = Daily
DECLARE @freqInterval INT = 1;     -- Every 1 day
DECLARE @freqSubdayType INT = 4;   -- 4 = Minutes
DECLARE @freqSubdayInterval INT = 5; -- Every 5 minutes
DECLARE @activeStartTime INT = 0;  -- 00:00:00
DECLARE @activeEndTime INT = 235959; -- 23:59:59

EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule
    @job_id = @jobId,
    @name = @scheduleName,
    @enabled = @scheduleEnabled,
    @freq_type = @freqType,
    @freq_interval = @freqInterval,
    @freq_subday_type = @freqSubdayType,
    @freq_subday_interval = @freqSubdayInterval,
    @active_start_date = NULL, -- Default to today
    @active_end_date = 99991231, -- No end date
    @active_start_time = @activeStartTime,
    @active_end_time = @activeEndTime;
    --@schedule_uid = @schedule_uid OUTPUT; -- If you need to capture it

IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback;

/********************************************************************
-- JOB SERVER
********************************************************************/
EXEC @ReturnCode = msdb.dbo.sp_add_jobserver
    @job_id = @jobId;

IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback;

COMMIT TRANSACTION;
PRINT N'Job ''' + @jobName + N''' created successfully.';
GOTO EndSave;

QuitWithRollback:
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION;
    PRINT N'Failed to create Job ''' + @jobName + N'''. Rolled back transaction.';
    -- RAISERROR (N'Failed to create Job.', 16, 1) -- Optional: uncomment to make script fail in SSMS messages
EndSave:
GO

/*<info serverAlias="DBTGRS-bodb_TGRS" executers="wsv_tgrs" isFunction="0" isNested="0"></info>*/
