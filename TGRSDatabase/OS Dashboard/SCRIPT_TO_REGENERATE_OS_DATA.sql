--truncate table [bodb_TGRS].[dbo].[OSDataTGRS]
--truncate table [bodb_TGRS].[dbo].[OSStagingDataTGRS]  
--truncate table  [bodb_TGRS].[dbo].[OSSummaryByTrader_Daily]
--truncate table  [bodb_TGRS].[dbo].[OSSummaryByTrader_Monthly]
--truncate table  [bodb_TGRS].[dbo].[OSSummaryByLeague_Monthly]

EXEC Task_StagingOSDataTGRS_Regenerate '20160101', '20170301'

DECLARE @EventDate DATE;
DECLARE db_cursor CURSOR FOR
SELECT EventDate FROM [dbo].OSStagingDataTGRS WITH(NOLOCK) GROUP BY EventDate

OPEN db_cursor   
FETCH NEXT FROM db_cursor INTO @EventDate   

WHILE @@FETCH_STATUS = 0   
BEGIN   
       PRINT @EventDate
             EXEC [dbo].[Task_StagingOSTraderPerformanceByDate] @Date=@EventDate
       FETCH NEXT FROM db_cursor INTO @EventDate   
END   

CLOSE db_cursor   
DEALLOCATE db_cursor

DECLARE @Month DATE;
DECLARE db_cursor CURSOR FOR  

SELECT CONVERT(VARCHAR(8),EventDate) + '01'
FROM [dbo].OSStagingDataTGRS WITH(NOLOCK) 
GROUP BY CONVERT(VARCHAR(8),EventDate) + '01'

OPEN db_cursor   
FETCH NEXT FROM db_cursor INTO @Month   

WHILE @@FETCH_STATUS = 0   
BEGIN   
       PRINT @Month
			 EXEC [dbo].[Task_StagingOSTraderPerformanceMonthly] @Month=@Month
       FETCH NEXT FROM db_cursor INTO @Month   
END   

CLOSE db_cursor   
DEALLOCATE db_cursor