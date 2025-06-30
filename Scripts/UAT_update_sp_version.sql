/*<info serverAlias="DBTGRS-bodb_TGRS_UAT" executers="wsv_tgrs" isFunction="0" isNested="0"></info>*/
/*
	Creator:	20250630@Jaden.Tang
	Task:		Beat the stupid Rocketor
*/

USE msdb;
GO

-- Update Job: TGRS-Staging Data Daily, Step: 02.Staging Data from IBC
EXEC dbo.sp_update_jobstep
    @job_name = N'TGRS-Staging Data Daily',
    @step_id = 2,
    @command = N'EXEC  [dbo].Task_StagingDataTGRS_xtest';
GO

-- Update Job: TGRS-Staging Data Hourly, Step: Today Realtime Staging
EXEC dbo.sp_update_jobstep
    @job_name = N'TGRS-Staging Data Hourly',
    @step_id = 1,
    @command = N'EXECUTE dbo.Task_StagingRealTimeTGRSDataForToday_xtest;';
GO