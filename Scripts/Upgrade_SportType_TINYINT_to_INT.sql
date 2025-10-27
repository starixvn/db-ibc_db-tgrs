/*<info serverAlias="DBTGRS-bodb_TGRS" executers="wsv_tgrs" isFunction="0" isNested="0"></info>*/

-- =============================================
-- Script: Upgrade SportType Columns from TINYINT to INT
-- =============================================

SET NOCOUNT ON;

PRINT '============================================='
PRINT 'Starting Zero-Downtime SportType Column Upgrade'
PRINT 'Method: ADD → BATCH UPDATE → DROP → RENAME'
PRINT 'Batch Size: 10000 rows per batch'
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
    AND COLUMN_NAME LIKE '%SportType%'
ORDER BY TABLE_NAME ASC, COLUMN_NAME ASC;

-- =============================================
-- PART 1: TraderPerformance Table - ADD COLUMN
-- =============================================
PRINT ''
PRINT '============================================='
PRINT 'PART 1: Upgrading TraderPerformance.SportType'
PRINT '============================================='

-- Step 1.1: Add new column
IF EXISTS (
    SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS 
    WHERE TABLE_NAME = 'TraderPerformance' 
        AND COLUMN_NAME = 'SportType'
) AND NOT EXISTS (
    SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS 
    WHERE TABLE_NAME = 'TraderPerformance' 
        AND COLUMN_NAME = 'SportType_New'
)
BEGIN
    PRINT 'Step 1.1: Adding new SportType_New column (INT)...'
    ALTER TABLE dbo.TraderPerformance ADD SportType_New INT NULL;
    PRINT 'SUCCESS: Added SportType_New column'
END

GO

-- Step 1.2: Update data in batches
IF EXISTS (
    SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS 
    WHERE TABLE_NAME = 'TraderPerformance' 
        AND COLUMN_NAME = 'SportType' 
        AND DATA_TYPE = 'tinyint'
) AND EXISTS (
    SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS 
    WHERE TABLE_NAME = 'TraderPerformance' 
        AND COLUMN_NAME = 'SportType_New'
)
BEGIN
    DECLARE @BatchSize INT = 10000;
    DECLARE @RowsUpdated INT;
    DECLARE @TotalRows INT;
    
    PRINT 'Step 1.2: Batch updating data from SportType to SportType_New...'
    
    -- Get total row count
    SELECT @TotalRows = COUNT(*) FROM dbo.TraderPerformance WHERE SportType IS NOT NULL;
    PRINT 'Total rows to update: ' + CAST(@TotalRows AS VARCHAR(20))
    
    -- Batch update in chunks to minimize locking
    SET @RowsUpdated = 0;
    WHILE @RowsUpdated < @TotalRows
    BEGIN
        UPDATE TOP (@BatchSize) dbo.TraderPerformance 
        SET SportType_New = CAST(SportType AS INT)
        WHERE SportType IS NOT NULL 
            AND SportType_New IS NULL;
        
        SET @RowsUpdated = @RowsUpdated + @@ROWCOUNT;
        PRINT 'Updated ' + CAST(@RowsUpdated AS VARCHAR(20)) + ' / ' + CAST(@TotalRows AS VARCHAR(20)) + ' rows';
        
        -- Small delay to prevent blocking
        WAITFOR DELAY '00:00:01';
        
        IF @@ROWCOUNT = 0 BREAK; -- No more rows to update
    END
    
    PRINT 'Step 1.3: Dropping old SportType column...'
    ALTER TABLE dbo.TraderPerformance DROP COLUMN SportType;
    
    PRINT 'Step 1.4: Renaming SportType_New to SportType...'
    EXEC sp_rename 'dbo.TraderPerformance.SportType_New', 'SportType', 'COLUMN';
    
    PRINT 'SUCCESS: TraderPerformance.SportType upgraded to INT'
END
ELSE
BEGIN
    PRINT 'INFO: TraderPerformance upgrade conditions not met - skipping'
END

GO

-- =============================================
-- PART 2: TraderPerformance_BK Table - ADD COLUMN
-- =============================================
PRINT ''
PRINT '============================================='
PRINT 'PART 2: Upgrading TraderPerformance_BK.SportType'
PRINT '============================================='

-- Step 2.1: Add new column
IF EXISTS (
    SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS 
    WHERE TABLE_NAME = 'TraderPerformance_BK' 
        AND COLUMN_NAME = 'SportType' 
) AND NOT EXISTS (
    SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS 
    WHERE TABLE_NAME = 'TraderPerformance_BK' 
        AND COLUMN_NAME = 'SportType_New'
)
BEGIN
    PRINT 'Step 2.1: Adding new SportType_New column (INT)...'
    ALTER TABLE dbo.TraderPerformance_BK ADD SportType_New INT NULL;
    PRINT 'SUCCESS: Added SportType_New column'
END

GO

-- Step 2.2: Update data in batches
IF EXISTS (
    SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS 
    WHERE TABLE_NAME = 'TraderPerformance_BK' 
        AND COLUMN_NAME = 'SportType' 
        AND DATA_TYPE = 'tinyint'
) AND EXISTS (
    SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS 
    WHERE TABLE_NAME = 'TraderPerformance_BK' 
        AND COLUMN_NAME = 'SportType_New'
)
BEGIN
    DECLARE @BatchSize INT = 10000;
    DECLARE @RowsUpdated INT;
    DECLARE @TotalRows INT;
    
    PRINT 'Step 2.2: Batch updating data from SportType to SportType_New...'
    
    -- Get total row count
    SELECT @TotalRows = COUNT(*) FROM dbo.TraderPerformance_BK WHERE SportType IS NOT NULL;
    PRINT 'Total rows to update: ' + CAST(@TotalRows AS VARCHAR(20))
    
    -- Batch update in chunks to minimize locking
    SET @RowsUpdated = 0;
    WHILE @RowsUpdated < @TotalRows
    BEGIN
        UPDATE TOP (@BatchSize) dbo.TraderPerformance_BK 
        SET SportType_New = CAST(SportType AS INT)
        WHERE SportType IS NOT NULL 
            AND SportType_New IS NULL;
        
        SET @RowsUpdated = @RowsUpdated + @@ROWCOUNT;
        PRINT 'Updated ' + CAST(@RowsUpdated AS VARCHAR(20)) + ' / ' + CAST(@TotalRows AS VARCHAR(20)) + ' rows';
        
        -- Small delay to prevent blocking
        WAITFOR DELAY '00:00:01';
        
        IF @@ROWCOUNT = 0 BREAK; -- No more rows to update
    END
    
    PRINT 'Step 2.3: Dropping old SportType column...'
    ALTER TABLE dbo.TraderPerformance_BK DROP COLUMN SportType;
    
    PRINT 'Step 2.4: Renaming SportType_New to SportType...'
    EXEC sp_rename 'dbo.TraderPerformance_BK.SportType_New', 'SportType', 'COLUMN';
    
    PRINT 'SUCCESS: TraderPerformance_BK.SportType upgraded to INT'
END
ELSE
BEGIN
    PRINT 'INFO: TraderPerformance_BK upgrade conditions not met - skipping'
END

GO

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
        WHEN DATA_TYPE = 'smallint' THEN 'UPGRADED ✓'
        WHEN DATA_TYPE = 'tinyint' THEN 'NEEDS UPGRADE ✗'
        ELSE 'UNKNOWN'
    END AS Status
FROM INFORMATION_SCHEMA.COLUMNS 
WHERE TABLE_NAME IN ('TraderPerformance', 'TraderPerformance_BK')
    AND COLUMN_NAME = 'SportType'
ORDER BY TABLE_NAME ASC;

PRINT ''
PRINT '============================================='
PRINT 'SportType Column Upgrade Process Complete!'
PRINT '============================================='
PRINT 'Summary:'
PRINT '- TraderPerformance.SportType: TINYINT → INT'
PRINT '- TraderPerformance_BK.SportType: TINYINT → INT'
PRINT '============================================='

GO
