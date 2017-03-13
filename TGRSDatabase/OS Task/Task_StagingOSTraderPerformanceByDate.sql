
SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

/****** Object:  Stored Procedure dbo.Task_StagingOSTraderPerformanceByDate    Script Date: 3/7/2017 3:10:47 PM ******/


CREATE PROCEDURE	[dbo].[Task_StagingOSTraderPerformanceByDate]
	@Date DATE = NULL
AS
/*
	Created:	20160810@Long.Luu
	Task :		Staging Data for Other Sports on TGRS DB By Date
	DB:			DBTGRS.bodb_TGRS
	Original:  
  
	Revisions:
				- 20170227@Aaron: Added MatchCount 
   			
	Param's Explanation:  
	
	Exam: 

*/

SET NOCOUNT ON;

	DELETE [bodb_TGRS].[dbo].OSDataTGRS	WHERE EventDate = @Date;

	INSERT INTO [dbo].OSDataTGRS
           ([TraderId]
		   ,[MatchId]
		   ,[MatchCode]
           ,[EventDate]
           ,[SportId]
           ,[BettypeId]
           ,[LeagueId]
           ,[Turnover]
           ,[WinLoss]
           ,[Comm]
           ,[BetCount]
           ,[Target]
           )
 
	SELECT [TraderId]
		   ,[MatchId]
		   ,[MatchCode]
           ,[EventDate]
           ,[SportId]
           ,[BettypeId]
           ,[LeagueId]
           ,[Turnover]
           ,[WinLoss]
           ,[Comm]
           ,[BetCount]
		   ,[Target]
    FROM [dbo].OSStagingDataTGRS WITH(NOLOCK)
    WHERE EventDate = @Date;

	DELETE [bodb_TGRS].[dbo].OSSummaryByTrader_Daily WHERE EventDate = @Date;

	INSERT INTO [dbo].OSSummaryByTrader_Daily
           ([TraderId]
           ,[EventDate]
           ,[SportId]
           ,[BettypeId]
           ,[LeagueId]
           ,[Turnover]
           ,[WinLoss]
           ,[Comm]
           ,[BetCount]
		   ,[MatchCount]
           ,[Target]
           )
 
	SELECT [TraderId]
		   ,[EventDate]
           ,[SportId]
           ,[BettypeId]
           ,[LeagueId]
           ,SUM([Turnover])
           ,SUM([WinLoss])
           ,SUM([Comm])
           ,SUM([BetCount])
		   ,COUNT(DISTINCT MatchId)
		   ,[Target]
    FROM [dbo].OSStagingDataTGRS WITH(NOLOCK)
    WHERE EventDate = @Date
	GROUP BY [TraderId]
		   ,[EventDate]
           ,[SportId]
           ,[BettypeId]
           ,[LeagueId]
		   ,[Target];



GO

SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO


GO 
