/*
	Creator:	20250707
	Task:		Add SiteId dimension to TraderPerformance tables - [Redmine: #231812]
	DB:			bodb_TGRS
	
	Description: This script adds a new dimension SiteId to 
	             TraderPerformance, TraderPerformance_BetChoice, and TraderPerformance_BetChoice_Detail tables.
*/

/*<info serverAlias="DBTGRS-bodb_TGRS" executers="bodbTGRSNet" isFunction="0" isNested="0"></info>*/

PRINT 'Adding SiteID column to TraderPerformance tables'

-- Add SiteID column to TraderPerformance table
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.TraderPerformance') AND name = 'SiteID')
BEGIN
    ALTER TABLE [dbo].[TraderPerformance] ADD
        [SiteID] INT NULL
    PRINT 'Added SiteID column to TraderPerformance table'
END
ELSE
BEGIN
    PRINT 'SiteID column already exists in TraderPerformance table'
END

-- Add SiteID column to TraderPerformance_BetChoice table
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.TraderPerformance_BetChoice') AND name = 'SiteID')
BEGIN
    ALTER TABLE [dbo].[TraderPerformance_BetChoice] ADD
        [SiteID] INT NULL
    PRINT 'Added SiteID column to TraderPerformance_BetChoice table'
END
ELSE
BEGIN
    PRINT 'SiteID column already exists in TraderPerformance_BetChoice table'
END

-- Add SiteID column to TraderPerformance_BetChoice_Detail table
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.TraderPerformance_BetChoice_Detail') AND name = 'SiteID')
BEGIN
    ALTER TABLE [dbo].[TraderPerformance_BetChoice_Detail] ADD
        [SiteID] INT NULL
    PRINT 'Added SiteID column to TraderPerformance_BetChoice_Detail table'
END
ELSE
BEGIN
    PRINT 'SiteID column already exists in TraderPerformance_BetChoice_Detail table'
END

PRINT 'Script execution completed'

GO 