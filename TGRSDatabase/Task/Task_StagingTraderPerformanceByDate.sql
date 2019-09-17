ALTER PROCEDURE	[dbo].[Task_StagingTraderPerformanceByDate]
	@Date DATE = NULL
AS
/*
	Created:	20140604@Tom.Vo
	Task :		Staging Data on TGRS DB By Date
	DB:			DBTGRS.bodb_TGRS
	Original:  
  
	Revisions:      
		- 20141203@Tom:			Staging data with new requirement
		- 20160307@Billy:		Add new field Spread for staging data - [Redmine: #53240]
		- 20171025@Long.Luu:	Sum by BettypeGroup (Major, PH)
		- 20171127@Long.Luu:	Support Live Status
		- 20180119@John:		Update Logic generating data [Redmine: #87861]
		- 20190116@John:		Support excluding Leagues from report [Redmine ID: #108008]
		- 20190304@Long.Luu:	Calc Actual-rate values for Soccer [Redmine ID: 108920]
		- 20190822@Long.Luu:	Suppport Non-Live Data [Redmine ID: 118959]
   			
	Param's Explanation:  
	
	Exam: 

*/
BEGIN;
	SET NOCOUNT ON;
	
	-- Manage Bettype Group
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
		,	BettypeGroup
	)
	SELECT DISTINCT b.BetType
		,	b.BettypeGroup
	FROM dbo.BetType b WITH(NOLOCK);
 
	-- [SummaryByBetType_Daily] table
	DELETE [dbo].[SummaryByBetType_Daily]	WHERE EventDate = @Date;

	INSERT INTO [dbo].[SummaryByBetType_Daily]
	(
			[EventDate]
		,	[LeagueId]
		,	[BetType]
		,	[WorkShift]
		,	[IsLive]
		,	[Stake]
		,	[WinLost]
		,	[Comm]
		,	[Stake_AR]
		,	[WinLost_AR]
		,	[Comm_AR]
		,	[BetCount]
		,	[MatchCount]
	)
	SELECT	[EventDate]		= @Date 
		,	[LeagueId]		= t.[LeagueId]
		,	[BetType]		= t.[BetType]
		,	[WorkShift]		= t.[WorkShift]
		,	[IsLive]		= t.[IsLive]
		,	[Stake]			= SUM(t.[Stake]) 
		,	[WinLost]		= SUM(t.[WinLost]) 
		,	[Comm]			= SUM(t.[Comm]) 
		,	[Stake_AR]		= SUM(t.[Stake_AR]) 
		,	[WinLost_AR]	= SUM(t.[WinLost_AR]) 
		,	[Comm_AR]		= SUM(t.[Comm_AR]) 
		,	[BetCount]		= SUM(t.[BetCount]) 
		,	[MatchCount]	= COUNT(DISTINCT [MatchId])
	FROM [dbo].[TraderPerformance] AS t WITH(NOLOCK)
	WHERE t.EventDate = @Date
	GROUP BY t.[LeagueId]
		,	t.[BetType]
		,	t.[WorkShift]
		,	t.[IsLive];

	-- [SummaryByLeague_Daily] table
	DELETE [dbo].[SummaryByLeague_Daily]	WHERE EventDate = @Date;

	INSERT INTO [dbo].[SummaryByLeague_Daily]
	(
			[EventDate]
		,	[LeagueId]
		,	[WorkShift]
		,	[BettypeGroup]
		,	[IsLive]
		,	[Stake]
		,	[WinLost]
		,	[Comm]
		,	[Stake_AR]
		,	[WinLost_AR]
		,	[Comm_AR]
		,	[BetCount]
		,	[MatchCount]
	)
	SELECT	[EventDate]		= @Date 
		,	[LeagueId]		= s.[LeagueId]
		,	[WorkShift]		= s.[WorkShift]
		,	[BettypeGroup]	= g.[BettypeGroup]
		,	[IsLive]		= s.[IsLive]
		,	[Stake]			= SUM(s.[Stake])
		,	[WinLost]		= SUM(s.[WinLost]) 
		,	[Comm]			= SUM(s.[Comm]) 
		,	[Stake_AR]		= SUM(s.[Stake_AR]) 
		,	[WinLost_AR]	= SUM(s.[WinLost_AR]) 
		,	[Comm_AR]		= SUM(s.[Comm_AR]) 
		,	[BetCount]		= SUM(s.[BetCount]) 
		,	[MatchCount]	= COUNT(DISTINCT s.[MatchId])
	FROM [dbo].[TraderPerformance] s WITH(NOLOCK)
		INNER JOIN #tmpBettypeGroup g WITH(NOLOCK) ON s.BetType = g.BetType
	WHERE EventDate = @Date
	GROUP BY s.[LeagueId]
		,	s.[WorkShift]
		,	g.[BettypeGroup]
		,	s.[IsLive];

	-- [SummaryByTeam_Daily] table
	DELETE [dbo].[SummaryByTeam_Daily]	WHERE EventDate = @Date;

	INSERT INTO [dbo].[SummaryByTeam_Daily]
	(
			[EventDate]
		,	[TeamId]
		,	[LeagueId]
		,	[WorkShift]
		,	[BettypeGroup]
		,	[IsLive]
		,	[Stake]
		,	[WinLost]
		,	[Comm]
		,	[Stake_AR]
		,	[WinLost_AR]
		,	[Comm_AR]
		,	[BetCount]
		,	[MatchCount]
	)
	SELECT	[EventDate]		= @Date 
		,	[TeamId]		= s.[TeamId]
		,	[LeagueId]		= s.[LeagueId]
		,	[WorkShift]		= s.[WorkShift]
		,	[BettypeGroup]	= g.[BettypeGroup]
		,	[IsLive]		= s.[IsLive]
		,	[Stake]			= SUM(s.[Stake]) 
		,	[WinLost]		= SUM(s.[WinLost])
		,	[Comm]			= SUM(s.[Comm]) 
		,	[Stake_AR]		= SUM(s.[Stake_AR]) 
		,	[WinLost_AR]	= SUM(s.[WinLost_AR]) 
		,	[Comm_AR]		= SUM(s.[Comm_AR]) 
		,	[BetCount]		= SUM(s.[BetCount]) 
		,	[MatchCount]	= COUNT(DISTINCT s.[MatchId])
	FROM [dbo].[TraderPerformance] s WITH(NOLOCK)
		INNER JOIN #tmpBettypeGroup g WITH(NOLOCK) ON s.BetType = g.BetType
	WHERE s.EventDate = @Date
	GROUP BY s.[TeamId]
		,	s.[LeagueId]
		,	s.[WorkShift]
		,	g.[BettypeGroup]
		,	s.[IsLive];
END;

GO
/*<info serverAlias="DBTGRS-bodb_TGRS" executers="bodbTGRSNet" isFunction="0" isNested="0"></info>*/