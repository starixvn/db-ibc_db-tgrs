SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

ALTER PROCEDURE	[dbo].[Task_StagingTraderPerformanceByDate]
					@Date DATE = NULL
AS
/*
	Created:	20140604@Tom.Vo
	Task :		Staging Data on TGRS DB By Date
	DB:			DBTGRS.bodb_TGRS
	Original:  
  
	Revisions:      
		- 20141203@Tom.Vo:	Staging data with new requirement
		- 20160307@Billy:	Add new field Spread for staging data - [Redmine: #53240]
   			
	Param's Explanation:  
	
	Exam: 

*/

SET NOCOUNT ON;

	DELETE [bodb_TGRS].[dbo].[TraderPerformance]	WHERE EventDate = @Date;

	INSERT INTO [dbo].[TraderPerformance]
           ([CustId]
           ,[MatchId]
		   ,[WorkShift]
		   ,[MatchCode]
           ,[EventDate]
           ,[SportType]
           ,[BetType]
           ,[LeagueId]
 		   ,[HomeId]
           ,[AwayId]
           ,[TeamId]
           ,[Grade]
           ,[Stake]
           ,[WinLost]
           ,[Comm]
           ,[BetCount]
		   ,[Spread]
           )
 
	SELECT [CustId]
           ,[MatchId]
		   ,[WorkShift]
		   ,[MatchCode]
           ,[EventDate]
           ,[SportType]
           ,[BetType]
           ,[LeagueId]
 		   ,[HomeId]
           ,[AwayId]
           ,[TeamId]
           ,[Grade]
           ,[Stake]
           ,[WinLost]
           ,[Comm]
           ,[BetCount]
		   ,[Spread]
	  FROM [dbo].[Staging_TraderPerformance] WITH(NOLOCK)
	  WHERE EventDate = @Date;
 
	DELETE [dbo].[SummaryByBetType_Daily]	WHERE EventDate = @Date;

	INSERT INTO [dbo].[SummaryByBetType_Daily]
		([EventDate]
		  ,[LeagueId]
		  ,[BetType]
		   ,[WorkShift]
		  ,[Stake]
		  ,[WinLost]
		  ,[Comm]
		  ,[BetCount]
		  ,[MatchCount]
		)
	SELECT @Date [EventDate]
		  ,[LeagueId]
		  ,[BetType]
		   ,[WorkShift]
		  ,SUM([Stake]) [Stake]
		  ,SUM([WinLost]) [WinLost]
		  ,SUM([Comm]) [Comm]
		  ,SUM([BetCount]) BetCount
		  ,COUNT(DISTINCT [MatchId])[MatchCount]
	  FROM [dbo].[Staging_TraderPerformance] WITH(NOLOCK)
	  WHERE EventDate = @Date
	  GROUP BY [LeagueId]
		  ,[BetType]
		   ,[WorkShift];

	DELETE [dbo].[SummaryByLeague_Daily]	WHERE EventDate = @Date;

	INSERT INTO [dbo].[SummaryByLeague_Daily]
		([EventDate]
		  ,[LeagueId]
		   ,[WorkShift]
		  ,[Stake]
		  ,[WinLost]
		  ,[Comm]
		  ,[BetCount]
		  ,[MatchCount]
		)
	SELECT @Date [EventDate]
		  ,[LeagueId]
		   ,[WorkShift]
		  ,SUM([Stake]) [Stake]
		  ,SUM([WinLost]) [WinLost]
		  ,SUM([Comm]) [Comm]
		  ,SUM([BetCount]) BetCount
		  ,COUNT(DISTINCT [MatchId])[MatchCount]
	  FROM [dbo].[Staging_TraderPerformance] WITH(NOLOCK)
	  WHERE EventDate = @Date
	  GROUP BY [LeagueId]
		   ,[WorkShift];

	DELETE [dbo].[SummaryByTeam_Daily]	WHERE EventDate = @Date;

	INSERT INTO [dbo].[SummaryByTeam_Daily]
		([EventDate]
		  ,[TeamId]
		   ,[WorkShift]
		  ,[Stake]
		  ,[WinLost]
		  ,[Comm]
		  ,[BetCount]
		  ,[MatchCount]
		)
	SELECT @Date [EventDate]
		  ,[TeamId]
		   ,[WorkShift]
		  ,SUM([Stake]) [Stake]
		  ,SUM([WinLost]) [WinLost]
		  ,SUM([Comm]) [Comm]
		  ,SUM([BetCount]) BetCount
		  ,COUNT(DISTINCT [MatchId])[MatchCount]
	  FROM [dbo].[Staging_TraderPerformance] WITH(NOLOCK)
	  WHERE EventDate = @Date
	  GROUP BY [TeamId]
		   ,[WorkShift];

GO

GRANT EXECUTE ON [dbo].[Task_StagingTraderPerformanceByDate] TO [bodbTGRSNet] AS [dbo];
GO