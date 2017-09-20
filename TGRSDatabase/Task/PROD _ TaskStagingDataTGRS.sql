EXEC Task_StagingTraderSetting
-------------------------------------------------

EXEC  [dbo].Task_StagingDataTGRS	@debug = 1
-------------------------------------------------

DECLARE @EventDate DATE;
DECLARE db_cursor CURSOR FOR  
SELECT EventDate FROM [dbo].[Staging_TraderPerformance] WITH(NOLOCK) GROUP BY EventDate

OPEN db_cursor   
FETCH NEXT FROM db_cursor INTO @EventDate   

WHILE @@FETCH_STATUS = 0   
BEGIN   
       PRINT @EventDate
	   EXEC [dbo].[Task_StagingTraderPerformanceByDate]	@Date=@EventDate
       FETCH NEXT FROM db_cursor INTO @EventDate   
END   

CLOSE db_cursor   
DEALLOCATE db_cursor
-------------------------------------------------

DECLARE @Month DATE;
DECLARE db_cursor CURSOR FOR  

SELECT CONVERT(VARCHAR(8),EventDate) + '01'
FROM [dbo].[Staging_TraderPerformance] WITH(NOLOCK) 
GROUP BY CONVERT(VARCHAR(8),EventDate) + '01'

OPEN db_cursor   
FETCH NEXT FROM db_cursor INTO @Month   

WHILE @@FETCH_STATUS = 0   
BEGIN   
       PRINT @Month
	   EXEC [dbo].[Task_StagingTraderPerformanceByMonth]	@Month=@Month
       FETCH NEXT FROM db_cursor INTO @Month   
END   

CLOSE db_cursor   
DEALLOCATE db_cursor
-------------------------------------------------
 
EXEC dbo.Task_StagingJuice	@debug = 1
GO


