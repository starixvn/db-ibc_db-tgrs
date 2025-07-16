/*
	Creator:	20250409
	Task:		Add VarianceVR dimension to TraderPerformance tables - [Redmine: #213765]
	DB:			bodb_TGRS
	
	Description: This script adds a new dimension VarianceVR calculated as (virtualrate / actualrate - 1) to 
	             TraderPerformance, TraderPerformance_BetChoice, and TraderPerformance_BetChoice_Detail tables.
*/

/*<info serverAlias="DBTGRS-bodb_TGRS" executers="bodbTGRSNet" isFunction="0" isNested="0"></info>*/


PRINT 'Adding VarianceVR column to PRIMARY KEY indexes'

-- Drop and recreate primary key clustered index for TraderPerformance_BetChoice table
IF EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID('dbo.TraderPerformance_BetChoice') AND name = 'PK_TraderPerformance_BetChoice')
BEGIN
    ALTER TABLE [dbo].[TraderPerformance_BetChoice] DROP CONSTRAINT [PK_TraderPerformance_BetChoice]
    CREATE CLUSTERED INDEX [CIX_TraderPerformance_BetChoice] ON [dbo].[TraderPerformance_BetChoice]
    (
        [CustId] ASC,
        [MatchId] ASC,
        [EventDate] ASC,
        [SportType] ASC,
        [BetType] ASC,
        [BetChoice] ASC,
        [IsLive] ASC,
        [Is8RM] ASC,
        [VarianceVR] ASC
    ) ON [TraderPerformanceDetail_Table]
    PRINT 'Recreated primary key clustered index PK_TraderPerformance_BetChoice with VarianceVR column for TraderPerformance_BetChoice table'
END
ELSE
BEGIN
    PRINT 'Primary key clustered index PK_TraderPerformance_BetChoice does not exist in TraderPerformance_BetChoice table'
END

EXEC Task_StagingDataTGRS @Debug = 1, @GenerateFromDate = '2025-06-23', @GenerateToDate = '2025-07-01'