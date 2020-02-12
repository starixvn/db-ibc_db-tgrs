ALTER PROCEDURE	[dbo].[Task_RobotTrading_SummaryByDate]
	@Date DATE = NULL
AS
/*
	Created:	20191224@Long.Luu
	Task :		Summary by Date for Data on TGRS DB
	DB:			DBTGRS.bodb_TGRS
	Original:
  
	Revisions:
		- 20191224@Long.Luu:	Created [Redmine ID: 118959]
		- 20200120@John.Ngo:	[TGR Soccer] RT3 Performance - Model Comparision Report [Redmine ID: 127208]
		- 20200210@John.Ngo:	[TGR Soccer] RT3 - Adding TA model into Robot Trading by Bettype and Month [Redmine ID: 128184]
   		
	Param's Explanation:

	Exam:

*/
BEGIN;
	SET NOCOUNT ON;
 
	-- [SummaryByBetType_Daily] table
	DELETE [dbo].[RobotTrading_BetTypeDaily] WITH(ROWLOCK)
	WHERE EventDate = @Date;

	INSERT INTO [dbo].[RobotTrading_BetTypeDaily]
	(
			[EventDate]
		,	[BetType]
		,	[LeagueId]
		,	[LeagueGroupId]
		,	[Is8RM]
		,	[Stake_VR]
		,	[WinLoss_VR]
		,	[Comm_VR]
		,	[Stake_AR]
		,	[WinLoss_AR]
		,	[Comm_AR]			
		,	[BetCount]	
		,	[MatchCount]
		,	[Type]
		,	[TypeSiteId]
	)
	SELECT	[EventDate]		= @Date 
		,	[BetType]		= t.[BetType]
		,	[LeagueId]		= t.[LeagueId]
		,	[LeagueGroupId] = t.[LeagueGroupId]
		,	[Is8RM]			= t.[Is8RM]
		,	[Stake_VR]		= SUM(t.[Stake_VR]) 
		,	[WinLoss_VR]	= SUM(t.[WinLoss_VR]) 
		,	[Comm_VR]		= SUM(t.[Comm_VR]) 
		,	[Stake_AR]		= SUM(t.[Stake_AR]) 
		,	[WinLoss_AR]	= SUM(t.[WinLoss_AR]) 
		,	[Comm_AR]		= SUM(t.[Comm_AR]) 
		,	[BetCount]		= SUM(t.[BetCount]) 
		,	[MatchCount]	= COUNT(DISTINCT [MatchId])
		,	[Type]			= t.[Type]
		,	[TypeSiteId]	= t.[TypeSiteId]
	FROM [dbo].[RobotTrading] AS t WITH(NOLOCK)
	WHERE t.EventDate = @Date
	GROUP BY t.[BetType]
		,	t.[LeagueId]
		,	t.[LeagueGroupId]
		,	t.[Is8RM]
		,	t.[Type]
		,	t.[TypeSiteId];
END;

GO
/*<info serverAlias="DBTGRS-bodb_TGRS" executers="bodbTGRSNet" isFunction="0" isNested="0"></info>*/