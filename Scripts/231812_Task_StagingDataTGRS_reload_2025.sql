/*<info serverAlias="DBTGRS-bodb_TGRS" executers="bodbTGRSNet" isFunction="0" isNested="0"></info>*/

-- load 1 month to test first
EXEC dbo.Task_StagingDataTGRS_xtest @GenerateFromDate = '2025-01-01', @GenerateToDate = '2025-01-31'
    , @Debug = 1

-- then load the rest
EXEC dbo.Task_StagingDataTGRS_xtest @GenerateFromDate = '2025-02-01', @GenerateToDate = '2025-07-24'
    , @Debug = 1