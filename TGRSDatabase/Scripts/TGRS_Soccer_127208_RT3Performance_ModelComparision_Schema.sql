/*
	Creator:	20200120@John
	Task:		[TGR Soccer] RT3 Performance - Model Comparision Report [Redmine ID: 127208]
	Server:		DBTGRS.bodb_TGRS

	Reviewer: Billy
*/

ALTER TABLE dbo.[RobotTrading]
ADD	  [Type] TINYINT NULL

DROP INDEX CIX_RobotTrading_EventDateIs8RMMatchId ON [dbo].[RobotTrading]
GO

CREATE NONCLUSTERED INDEX IX_RobotTrading_EventDateIs8RMTypeMatchId ON [dbo].[RobotTrading] (
	[EventDate]			ASC,
	[Is8RM]				ASC,
	[Type]				ASC,
	[MatchId]			ASC
)
GO

ALTER TABLE dbo.[RobotTrading_Monthly]
ADD	  [Type] TINYINT NULL

DROP INDEX CIX_RobotTrading_Monthly_EventDateLeagueGroupIdIs8RM ON [dbo].[RobotTrading_Monthly]
GO

CREATE CLUSTERED INDEX CIX_RobotTrading_Monthly_EventDateLeagueGroupIdIs8RMType ON [dbo].[RobotTrading_Monthly] (
	[EventDate]			ASC,
	[LeagueGroupId]		ASC,
	[Is8RM]				ASC,
	[Type]				ASC
)
GO

ALTER TABLE dbo.[RobotTrading_BetTypeDaily]
ADD	  [Type] TINYINT NULL

CREATE NONCLUSTERED INDEX IX_RobotTrading_BetTypeDaily_EventDateIs8RMType ON [dbo].[RobotTrading_BetTypeDaily] (
	[EventDate]			ASC,
	[Is8RM]				ASC,
	[Type]				ASC
)
GO

ALTER TABLE dbo.[RobotTrading_BetTypeMonthly]
ADD	  [Type] TINYINT NULL

CREATE NONCLUSTERED INDEX IX_RobotTrading_BetTypeMonthly_EventDateIs8RMType ON [dbo].[RobotTrading_BetTypeMonthly] (
	[EventDate]			ASC,
	[Is8RM]				ASC,
	[Type]				ASC
)
GO