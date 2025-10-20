/*<info serverAlias="DBTGRS-bodb_TGRS" executers="wsv_tgrs" isFunction="0" isNested="0"></info>*/

-- =============================================
-- Script: Upgrade SportType Columns from TINYINT to INT
-- Database: bodb_tgrs
-- Purpose: Upgrade SportType columns in TraderPerformance and TraderPerformance_BK tables
-- Date: 2025-01-20
-- =============================================

SET NOCOUNT ON;

PRINT '============================================='
PRINT 'Starting SportType Column Upgrade Process'
PRINT 'From TINYINT to INT'
PRINT '============================================='

-- Check current state before changes
PRINT ''
PRINT 'BEFORE: Current SportType column data types:'
SELECT 
    TABLE_NAME,
    COLUMN_NAME,
    DATA_TYPE,
    IS_NULLABLE
FROM INFORMATION_SCHEMA.COLUMNS 
WHERE TABLE_NAME IN ('TraderPerformance', 'TraderPerformance_BK')
    AND COLUMN_NAME = 'SportType'
ORDER BY TABLE_NAME ASC;

PRINT ''
PRINT '============================================='
PRINT 'Step 1: Upgrading TraderPerformance.SportType'
PRINT '============================================='

BEGIN TRY
    -- Check if column exists and is TINYINT
    IF EXISTS (
        SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS 
        WHERE TABLE_NAME = 'TraderPerformance' 
            AND COLUMN_NAME = 'SportType' 
            AND DATA_TYPE = 'tinyint'
    )
    BEGIN
        PRINT 'Altering TraderPerformance.SportType from TINYINT to INT...'
        
        ALTER TABLE dbo.TraderPerformance 
        ALTER COLUMN SportType INT NULL;
        
        PRINT 'SUCCESS: TraderPerformance.SportType upgraded to INT'
    END
    ELSE
    BEGIN
        PRINT 'INFO: TraderPerformance.SportType is not TINYINT or does not exist - skipping'
    END
END TRY
BEGIN CATCH
    PRINT 'ERROR upgrading TraderPerformance.SportType:'
    PRINT ERROR_MESSAGE()
END CATCH

PRINT ''
PRINT '============================================='
PRINT 'Step 2: Upgrading TraderPerformance_BK.SportType'
PRINT '============================================='

BEGIN TRY
    -- Check if column exists and is TINYINT
    IF EXISTS (
        SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS 
        WHERE TABLE_NAME = 'TraderPerformance_BK' 
            AND COLUMN_NAME = 'SportType' 
            AND DATA_TYPE = 'tinyint'
    )
    BEGIN
        PRINT 'Altering TraderPerformance_BK.SportType from TINYINT to INT...'
        
        ALTER TABLE dbo.TraderPerformance_BK 
        ALTER COLUMN SportType INT NULL;
        
        PRINT 'SUCCESS: TraderPerformance_BK.SportType upgraded to INT'
    END
    ELSE
    BEGIN
        PRINT 'INFO: TraderPerformance_BK.SportType is not TINYINT or does not exist - skipping'
    END
END TRY
BEGIN CATCH
    PRINT 'ERROR upgrading TraderPerformance_BK.SportType:'
    PRINT ERROR_MESSAGE()
END CATCH

PRINT ''
PRINT '============================================='
PRINT 'Step 3: Verification - Check Updated Data Types'
PRINT '============================================='

-- Verify the changes
PRINT 'AFTER: Updated SportType column data types:'
SELECT 
    TABLE_NAME,
    COLUMN_NAME,
    DATA_TYPE,
    IS_NULLABLE,
    CASE 
        WHEN DATA_TYPE = 'int' THEN 'UPGRADED ✓'
        WHEN DATA_TYPE = 'tinyint' THEN 'NEEDS UPGRADE ✗'
        ELSE 'UNKNOWN'
    END AS Status
FROM INFORMATION_SCHEMA.COLUMNS 
WHERE TABLE_NAME IN ('TraderPerformance', 'TraderPerformance_BK')
    AND COLUMN_NAME = 'SportType'
ORDER BY TABLE_NAME ASC;

PRINT ''
PRINT '============================================='
PRINT 'Step 4: Data Validation'
PRINT '============================================='

-- Check for any data that might be affected
BEGIN TRY
    IF OBJECT_ID('dbo.TraderPerformance') IS NOT NULL
    BEGIN
        DECLARE @MinSportType INT, @MaxSportType INT, @RecordCount INT;
        
        SELECT 
            @MinSportType = MIN(SportType),
            @MaxSportType = MAX(SportType),
            @RecordCount = COUNT(*)
        FROM dbo.TraderPerformance 
        WHERE SportType IS NOT NULL;
        
        PRINT 'TraderPerformance data validation:'
        PRINT '  - Total records with SportType: ' + CAST(ISNULL(@RecordCount, 0) AS VARCHAR(20))
        PRINT '  - Min SportType value: ' + CAST(ISNULL(@MinSportType, 0) AS VARCHAR(20))
        PRINT '  - Max SportType value: ' + CAST(ISNULL(@MaxSportType, 0) AS VARCHAR(20))
    END
    
    IF OBJECT_ID('dbo.TraderPerformance_BK') IS NOT NULL
    BEGIN
        SELECT 
            @MinSportType = MIN(SportType),
            @MaxSportType = MAX(SportType),
            @RecordCount = COUNT(*)
        FROM dbo.TraderPerformance_BK 
        WHERE SportType IS NOT NULL;
        
        PRINT 'TraderPerformance_BK data validation:'
        PRINT '  - Total records with SportType: ' + CAST(ISNULL(@RecordCount, 0) AS VARCHAR(20))
        PRINT '  - Min SportType value: ' + CAST(ISNULL(@MinSportType, 0) AS VARCHAR(20))
        PRINT '  - Max SportType value: ' + CAST(ISNULL(@MaxSportType, 0) AS VARCHAR(20))
    END
END TRY
BEGIN CATCH
    PRINT 'Warning: Could not validate data - ' + ERROR_MESSAGE()
END CATCH

PRINT ''
PRINT '============================================='
PRINT 'SportType Column Upgrade Process Complete!'
PRINT '============================================='
PRINT 'Summary:'
PRINT '- TraderPerformance.SportType: TINYINT → INT'
PRINT '- TraderPerformance_BK.SportType: TINYINT → INT'
PRINT ''
PRINT 'Next Steps:'
PRINT '1. Update any stored procedures that declare SportType as TINYINT'
PRINT '2. Test applications that use these tables'
PRINT '3. Update documentation to reflect the new data type'
PRINT '============================================='

GO
