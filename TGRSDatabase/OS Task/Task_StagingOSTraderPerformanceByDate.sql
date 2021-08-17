ALTER PROCEDURE	[dbo].[Task_StagingOSTraderPerformanceByDate]
	@Date DATE = NULL
AS
/*
	Created:	20160810@Long.Luu
	Task :		Staging Data for Other Sports on TGRS DB By Date
	DB:			DBTGRS.bodb_TGRS
	Original:  
  
	Revisions:
				- 20170227@Aaron: Added MatchCount 
				- 20170404@Long: Apply Juice
				- 20170706@Billy: Fix bug duplicated data - [Redmine: #79615]
				- 20190108@John:  Exclude Cashout tickets from Betcount figures in TGR reports [Redmine ID: 107602]
				- 20200914@John.Ngo: Support AR, Live/Nonlive for OSDataTGRS [Redmine ID: 140875]
   			
	Param's Explanation:  
	
	Exam: 

*/
BEGIN
	SET NOCOUNT ON;
	    
	DELETE [dbo].OSSummaryByTrader_Daily WHERE EventDate = @Date;

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
           ,[StakeMYR]
           ,[Juice]
           ,[StakeMYRJuice]
		   ,[Turnover_AR]
           ,[WinLoss_AR]
           ,[Comm_AR]
		   ,[StakeMYR_AR]
           ,[Juice_AR]
           ,[StakeMYRJuice_AR]
		   ,[IsLive]
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
		   ,SUM([StakeMYR])
		   ,SUM([Juice])
		   ,SUM([StakeMYRJuice])
		   ,SUM([Turnover_AR])
		   ,SUM([WinLoss_AR])
		   ,SUM([Comm_AR])
		   ,SUM([StakeMYR_AR])
		   ,SUM([Juice_AR])
		   ,SUM([StakeMYRJuice_AR])
		   ,[IsLive]
    FROM [dbo].OSDataTGRS WITH(NOLOCK)
    WHERE EventDate = @Date
	GROUP BY [TraderId]
		   ,[EventDate]
           ,[SportId]
           ,[BettypeId]
           ,[LeagueId]
		   ,[Target]
		   ,[IsLive];
END;

GO
/*<info serverAlias="DBTGRS-bodb_TGRS" executers="bodbTGRSNet" isFunction="0" isNested="0"></info>*/