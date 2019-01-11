USE [bodb_TGRS]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE	[dbo].[Task_StagingOSTraderPerformanceMonthly]
	@Month DATE = NULL
AS
/*
	Created:	20160810@Long.Luu
	Task :		Staging Data for Other Sports on TGRS DB By Month
	DB:			DBTGRS.bodb_TGRS
	Original:  
  
	Revisions:
				- 20170227@Aaron: Added MatchCount, EventDate; removed Rptyear, RptMonth				
				- 20170404@Long: Apply Juice
   			
	Param's Explanation:  
	
	Exam:

*/

SET NOCOUNT ON;

	DECLARE @StartDate DATE, @EndDate DATE;

	SELECT @StartDate = DATEADD(DD, - DAY(@Month) + 1, @Month);

	SELECT @EndDate = DATEADD(DD, - 1, DATEADD(MM, 1, @StartDate));

	SELECT @Month = @StartDate;
 
	DELETE [dbo].OSSummaryByTrader_Monthly WHERE EventDate = @Month;

	INSERT INTO [dbo].OSSummaryByTrader_Monthly(		
		  [TraderId]
           ,[SportId]
           ,[LeagueId]
           ,[BettypeId]
           ,[Turnover]
           ,[WinLoss]
           ,[Comm]
           ,[BetCount]
           ,[Target]
		   ,[MatchCount]
		   ,[EventDate]
           ,[StakeMYR]
           ,[Juice]
           ,[StakeMYRJuice]
		  )
	SELECT [TraderId]
           ,[SportId]
           ,[LeagueId]
           ,[BettypeId]
		   ,SUM([Turnover]) [Turnover]
		   ,SUM([WinLoss]) [WinLoss]
		   ,SUM([Comm]) [Comm]
		   ,SUM([BetCount]) [BetCount]
		   ,[Target]
		   ,COUNT(DISTINCT MatchId)
		   ,@Month AS [EventDate]
		   ,SUM([StakeMYR])
		   ,SUM([Juice])
		   ,SUM([StakeMYRJuice])
	 FROM [dbo].OSDataTGRS WITH(NOLOCK)
	 WHERE EventDate BETWEEN @StartDate AND @EndDate
	 GROUP BY [TraderId]
           ,[SportId]
           ,[BettypeId]
           ,[LeagueId]
		   ,[Target]

	DELETE [dbo].OSSummaryByLeague_Monthly WHERE EventDate = @Month;

	INSERT INTO [dbo].OSSummaryByLeague_Monthly(		
		    [SportId]
           ,[LeagueId]
           ,[Turnover]
           ,[WinLoss]
           ,[Comm]
           ,[BetCount]
           ,[Target]
		   ,[MatchCount]
		   ,[EventDate]
           ,[StakeMYR]
           ,[Juice]
           ,[StakeMYRJuice]
		  )
	SELECT  [SportId]
           ,[LeagueId]
           ,SUM([Turnover]) [Turnover]
		   ,SUM([WinLoss]) [WinLoss]
		   ,SUM([Comm]) [Comm]
		   ,SUM([BetCount]) [BetCount]
		   ,[Target]
		   ,COUNT(DISTINCT MatchId)
		   ,@Month AS [EventDate]
		   ,SUM([StakeMYR])
		   ,SUM([Juice])
		   ,SUM([StakeMYRJuice])
	 FROM [dbo].OSDataTGRS WITH(NOLOCK)
	 WHERE EventDate BETWEEN @StartDate AND @EndDate
	 GROUP BY [SportId]
           ,[LeagueId]
		   ,[Target]