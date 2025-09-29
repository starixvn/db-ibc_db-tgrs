use bodb_TGRS;

-- deploy AFTER new code updates for Task_StagingJuice

--december 2024 - for testing and comparing data
exec dbo.Task_StagingJuice @GenerateFromDate = '2025-12-01', @GenerateToDate = '2025-12-10';
exec dbo.Task_StagingJuice @GenerateFromDate = '2025-12-11', @GenerateToDate = '2025-12-20';
exec dbo.Task_StagingJuice @GenerateFromDate = '2025-12-21', @GenerateToDate = '2025-12-31';

/*<info serverAlias="DBTGRS-bodb_TGRS" executers="bodbTGRSNet" isFunction="0" isNested="0"></info>*/
