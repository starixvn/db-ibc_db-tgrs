/*
Creator: 20191224@LongLuu
Task:  Create tables for TGRS's Robot Trading
Server:  bodb_TGRS

Reviewer: Billy
*/ 

----===================A. DROP TABLES=========================
----==========================================================


----===================B. CREATE TABLES========================
----===========================================================
CREATE TABLE [dbo].[RobotTrading](
	[TraderId]			INT NOT NULL,
	[MatchId]			INT NOT NULL,
	[MatchCode]			VARCHAR(100) NULL,
	[EventDate]			DATE NOT NULL,
	[SportType]			SMALLINT NOT NULL,
	[BetType]			SMALLINT NOT NULL,
	[HomeId]			INT NOT NULL,
	[AwayId]			INT NOT NULL,
	[LeagueId]			INT NOT NULL,
	[LeagueGroupId]		SMALLINT NULL,
	[TeamId]			SMALLINT NULL,
	[Grade]				TINYINT NULL,
	[WorkShift]			TINYINT NULL,
	[Is8RM]				BIT NULL,
	[Stake_VR]			MONEY NULL,
	[WinLoss_VR]		MONEY NULL,
	[Comm_VR]			MONEY NULL,
	[Stake_AR]			MONEY NULL,
	[WinLoss_AR]		MONEY NULL,
	[Comm_AR]			MONEY NULL,
	[BetCount]			INT NULL
) ON [DATA]
GO

CREATE CLUSTERED INDEX CIX_RobotTrading_EventDateLeagueGroupId ON [dbo].[RobotTrading] (
	[EventDate]			ASC,
	[LeagueGroupId]		ASC
)
GO

CREATE NONCLUSTERED INDEX CIX_RobotTrading_EventDateIs8RMMatchId ON [dbo].[RobotTrading] (
	[EventDate]			ASC,
	[Is8RM]				ASC,
	[MatchId]			ASC
)
GO

CREATE TABLE [dbo].[RobotTrading_Monthly](
	[TraderId]			INT NOT NULL,
	[EventDate]			DATE NOT NULL,
	[LeagueId]			INT NOT NULL,
	[LeagueGroupId]		SMALLINT NULL,
	[Is8RM]				BIT NULL,
	[Stake_VR]			MONEY NULL,
	[WinLoss_VR]		MONEY NULL,
	[Comm_VR]			MONEY NULL,
	[Stake_AR]			MONEY NULL,
	[WinLoss_AR]		MONEY NULL,
	[Comm_AR]			MONEY NULL,
	[BetCount]			INT NULL,
	[MatchCount]		INT NULL
) ON [DATA]
GO

CREATE CLUSTERED INDEX CIX_RobotTrading_Monthly_EventDateLeagueGroupIdIs8RM ON [dbo].[RobotTrading_Monthly] (
	[EventDate]			ASC,
	[LeagueGroupId]		ASC,
	[Is8RM]				ASC
)
GO

CREATE TABLE [dbo].[RobotTrading_BetTypeDaily]
(
	[EventDate]			DATE NOT NULL,
	[BetType]			SMALLINT NOT NULL,
	[LeagueId]			INT NOT NULL,
	[LeagueGroupId]		SMALLINT NULL,
	[Is8RM]				BIT NULL,
	[Stake_VR]			MONEY NULL,
	[WinLoss_VR]		MONEY NULL,
	[Comm_VR]			MONEY NULL,
	[Stake_AR]			MONEY NULL,
	[WinLoss_AR]		MONEY NULL,
	[Comm_AR]			MONEY NULL,
	[BetCount]			INT NULL,
	[MatchCount]		INT NULL
)

CREATE CLUSTERED INDEX CIX_RobotTrading_BettypeDaily_EventDateBettype ON [dbo].[RobotTrading_BettypeDaily] (
	[EventDate]			ASC,
	[BetType]			ASC,
	[LeagueId]			ASC,
	[LeagueGroupId]		ASC,
	[Is8RM]				ASC
)
GO

CREATE TABLE [dbo].[RobotTrading_BetTypeMonthly]
(
	[EventDate]			DATE NOT NULL,
	[BetType]			SMALLINT NOT NULL,
	[LeagueId]			INT NOT NULL,
	[LeagueGroupId]		SMALLINT NULL,
	[Is8RM]				BIT NULL,
	[Stake_VR]			MONEY NULL,
	[WinLoss_VR]		MONEY NULL,
	[Comm_VR]			MONEY NULL,
	[Stake_AR]			MONEY NULL,
	[WinLoss_AR]		MONEY NULL,
	[Comm_AR]			MONEY NULL,
	[BetCount]			INT NULL,
	[MatchCount]		INT NULL
)

CREATE CLUSTERED INDEX CIX_RobotTrading_BettypeMonthly_EventDateBettype ON [dbo].[RobotTrading_BetTypeMonthly] (
	[EventDate]			ASC,
	[BetType]			ASC,
	[LeagueId]			ASC,
	[LeagueGroupId]		ASC,
	[Is8RM]				ASC
)
GO
----===================C. ALTER TABLES=========================
----===========================================================
CREATE TABLE [dbo].[RobotStaging_EventDate](
	[EventDate]			DATE NOT NULL
) ON [DATA]
GO

