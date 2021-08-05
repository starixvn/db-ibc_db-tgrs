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
				- 20200914@John.Ngo: Support AR, Live/Nonlive for OSDataTGRS [Redmine ID: 140875]
				- 20210802@Adam.Tran: Sports - Performance Real Figures [Redmine: #158981]
	Param's Explanation:  
	
	Exam:

*/
BEGIN
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
		   ,[Turnover_AR]
           ,[WinLoss_AR]
           ,[Comm_AR]
		   ,[StakeMYR_AR]
           ,[Juice_AR]
           ,[StakeMYRJuice_AR]
		   ,[Is8RM]
		   ,[Stake_Real]
		   ,[WinLost_Real]
		   ,[Stake_VAR]
		   ,[WinLost_VAR]
		   ,[Comm_VAR]
		   ,[IsLive]
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
		   ,SUM([Turnover_AR])
		   ,SUM([WinLoss_AR])
		   ,SUM([Comm_AR])
		   ,SUM([StakeMYR_AR])
		   ,SUM([Juice_AR])
		   ,SUM([StakeMYRJuice_AR])
		   ,[Is8RM]
		   ,SUM([Stake_Real])
		   ,SUM([WinLost_Real])
		   ,SUM([Stake_VAR])
		   ,SUM([WinLost_VAR])
		   ,SUM([Comm_VAR])
		   ,[IsLive]
	 FROM [dbo].OSDataTGRS WITH(NOLOCK)
	 WHERE EventDate BETWEEN @StartDate AND @EndDate
	 GROUP BY [TraderId]
           ,[SportId]
           ,[BettypeId]
           ,[LeagueId]
		   ,[Target]
		   ,[IsLive]
		   ,[Is8RM];

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
		   ,[Turnover_AR]
           ,[WinLoss_AR]
           ,[Comm_AR]
		   ,[StakeMYR_AR]
           ,[Juice_AR]
           ,[StakeMYRJuice_AR]
		   ,[Is8RM]
		   ,[Stake_Real]
		   ,[WinLost_Real]
		   ,[Stake_VAR]
		   ,[WinLost_VAR]
		   ,[Comm_VAR]
		   ,[IsLive]
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
		   ,SUM([Turnover_AR])
		   ,SUM([WinLoss_AR])
		   ,SUM([Comm_AR])
		   ,SUM([StakeMYR_AR])
		   ,SUM([Juice_AR])
		   ,SUM([StakeMYRJuice_AR])
		   ,[Is8RM]
		   ,SUM([Stake_Real])
		   ,SUM([WinLost_Real])
		   ,SUM([Stake_VAR])
		   ,SUM([WinLost_VAR])
		   ,SUM([Comm_VAR])
		   ,[IsLive]
	 FROM [dbo].OSDataTGRS WITH(NOLOCK)
	 WHERE EventDate BETWEEN @StartDate AND @EndDate
	 GROUP BY [SportId]
           ,[LeagueId]
		   ,[Target]
		   ,[IsLive]
		   ,[Is8RM];
END;

GO
/*<info serverAlias="DBTGRS-bodb_TGRS" executers="bodbTGRSNet" isFunction="0" isNested="0"></info>*/