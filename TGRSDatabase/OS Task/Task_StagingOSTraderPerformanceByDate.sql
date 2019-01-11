SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

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
				- 20190108@John:  Exclude Cashout tickets from Betcount figures in TGR reports [Redmine ID: 107602]
   			
	Param's Explanation:
	Exam:
*/

SET NOCOUNT ON;

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
    FROM [dbo].OSDataTGRS WITH(NOLOCK)
    WHERE EventDate = @Date
	GROUP BY [TraderId]
		   ,[EventDate]
           ,[SportId]
           ,[BettypeId]
           ,[LeagueId]
		   ,[Target];

GO
/*<info serverAlias="DBTGRS-bodb_TGRS" executers="bodbTGRSNet" isFunction="0" isNested="0"></info>*/