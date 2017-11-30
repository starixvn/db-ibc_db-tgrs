SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Object:  Stored Procedure dbo.Task_StagingTraderPerformanceByDate    Script Date: 3/8/2016 2:46:20 PM ******/

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
		- 20171025@Long: Sum by BettypeGroup (Major, PH)
   			
	Param's Explanation:  
	
	Exam: 

*/

SET NOCOUNT ON;

	DELETE [dbo].[TraderPerformance]	WHERE EventDate = @Date;

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

	IF	OBJECT_ID('tempdb..#tmpBettypeGroup') IS NOT NULL
	BEGIN;
		DROP TABLE #tmpBettypeGroup;
	END;

	CREATE TABLE	#tmpBettypeGroup (
						BetType			SMALLINT
					,	BettypeGroup	TINYINT
					);

	CREATE CLUSTERED INDEX	#CIX_tmpBettypeGroupIdx ON #tmpBettypeGroup (
								BetType		ASC
							);
	INSERT INTO #tmpBettypeGroup(
		BetType
		, BettypeGroup)
	SELECT DISTINCT b.BetType
		, b.BettypeGroup
	FROM dbo.BetType b WITH(NOLOCK)

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
		  ,[BettypeGroup]
		)
	SELECT @Date [EventDate]
		  ,s.[LeagueId]
		  ,s.[WorkShift]
		  ,SUM(s.[Stake]) [Stake]
		  ,SUM(s.[WinLost]) [WinLost]
		  ,SUM(s.[Comm]) [Comm]
		  ,SUM(s.[BetCount]) BetCount
		  ,COUNT(DISTINCT s.[MatchId])[MatchCount]
		  ,g.[BettypeGroup]
	  FROM [dbo].[Staging_TraderPerformance] s WITH(NOLOCK)
		INNER JOIN #tmpBettypeGroup g WITH(NOLOCK) ON s.BetType = g.BetType
	  WHERE EventDate = @Date
	  GROUP BY [LeagueId]
		   ,s.[WorkShift]
		   ,[BettypeGroup];

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
		  ,[BettypeGroup]
		)
	SELECT @Date [EventDate]
		  ,s.[TeamId]
		  ,s.[WorkShift]
		  ,SUM(s.[Stake]) [Stake]
		  ,SUM(s.[WinLost]) [WinLost]
		  ,SUM(s.[Comm]) [Comm]
		  ,SUM(s.[BetCount]) BetCount
		  ,COUNT(DISTINCT s.[MatchId])[MatchCount]
		  ,g.[BettypeGroup]
	  FROM [dbo].[Staging_TraderPerformance] s WITH(NOLOCK)
		INNER JOIN #tmpBettypeGroup g WITH(NOLOCK) ON s.BetType = g.BetType
	  WHERE EventDate = @Date
	  GROUP BY [TeamId]
		   ,s.[WorkShift]
		   ,g.[BettypeGroup];

GO

GRANT EXECUTE ON [dbo].[Task_StagingTraderPerformanceByDate] TO [bodbTGRSNet] AS [dbo];
GO