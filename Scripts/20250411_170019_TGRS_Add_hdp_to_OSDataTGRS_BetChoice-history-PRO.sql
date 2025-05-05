/*<info serverAlias="DBTGRS-bodb_TGRS" executers="wsv_tgrs" isFunction="0" isNested="0"></info>*/
/*
	Creator:	20250411@Jaden.Tang
	Task:		Add hdp column to dbo.OSDataTGRS_BetChoice - [Redmine: #170019]
	Server:		DB06.bodb_TGRS
*/

-- https://nexdev.net/issues/170019

-- Re-gen data for a month
EXEC dbo.Task_StagingOSDataTGRS
    @Debug = 1, 
    @GenerateFromDate = '2025-04-01', 
    @GenerateToDate = '2025-05-05';