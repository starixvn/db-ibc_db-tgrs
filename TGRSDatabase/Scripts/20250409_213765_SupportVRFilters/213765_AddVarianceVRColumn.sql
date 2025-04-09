/*
	Creator:	20250409
	Task:		Add VarianceVR dimension to TraderPerformance tables - [Redmine: #213765]
	DB:			bodb_TGRS
	
	Description: This script adds a new dimension VarianceVR calculated as (virtualrate / actualrate - 1) to 
	             TraderPerformance, TraderPerformance_BetChoice, and TraderPerformance_BetChoice_Detail tables.
*/

USE [bodb_TGRS]
GO

PRINT 'Adding VarianceVR column to TraderPerformance tables'

-- Add VarianceVR column to TraderPerformance table
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.TraderPerformance') AND name = 'VarianceVR')
BEGIN
    ALTER TABLE [dbo].[TraderPerformance] ADD
        [VarianceVR] DECIMAL(9,6) NULL
    PRINT 'Added VarianceVR column to TraderPerformance table'
END
ELSE
BEGIN
    PRINT 'VarianceVR column already exists in TraderPerformance table'
END

-- Add VarianceVR column to TraderPerformance_BetChoice table
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.TraderPerformance_BetChoice') AND name = 'VarianceVR')
BEGIN
    ALTER TABLE [dbo].[TraderPerformance_BetChoice] ADD
        [VarianceVR] DECIMAL(9,6) NULL
    PRINT 'Added VarianceVR column to TraderPerformance_BetChoice table'
END
ELSE
BEGIN
    PRINT 'VarianceVR column already exists in TraderPerformance_BetChoice table'
END

-- Add VarianceVR column to TraderPerformance_BetChoice_Detail table
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.TraderPerformance_BetChoice_Detail') AND name = 'VarianceVR')
BEGIN
    ALTER TABLE [dbo].[TraderPerformance_BetChoice_Detail] ADD
        [VarianceVR] DECIMAL(9,6) NULL
    PRINT 'Added VarianceVR column to TraderPerformance_BetChoice_Detail table'
END
ELSE
BEGIN
    PRINT 'VarianceVR column already exists in TraderPerformance_BetChoice_Detail table'
END

PRINT 'Script execution completed'

GO 