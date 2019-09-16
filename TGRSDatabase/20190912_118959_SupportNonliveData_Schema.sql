/*
	Creator:	20190911@Long.Luu
	Task:		Support Non-live Data - [Redmine: #118959]
	Server:		DB06.bodb_TGRS
*/

USE bodb_TGRS

ALTER TABLE [dbo].SummaryByBetType_Daily
ADD	[IsLive]		BIT NULL;
GO

DROP INDEX CIX_EventDate ON [dbo].SummaryByBetType_Daily
GO

CREATE CLUSTERED INDEX CIX_EventDate_IsLive ON [dbo].SummaryByBetType_Daily (
	EventDate				ASC,
	[IsLive]				ASC
)
GO

---------------------------
ALTER TABLE [dbo].SummaryByBetType_Monthly
ADD	[IsLive]		BIT NULL;
GO

DROP INDEX CIX_EventDate ON [dbo].SummaryByBetType_Monthly
GO

CREATE CLUSTERED INDEX CIX_EventDate_IsLive ON [dbo].SummaryByBetType_Monthly (
	EventDate				ASC,
	[IsLive]				ASC
)
GO

---------------------------
ALTER TABLE [dbo].SummaryByLeague_Daily
ADD	[IsLive]		BIT NULL;
GO

DROP INDEX CIX_EventDate ON [dbo].SummaryByLeague_Daily
GO

CREATE CLUSTERED INDEX CIX_EventDate_IsLive ON [dbo].SummaryByLeague_Daily (
	EventDate				ASC,
	[IsLive]				ASC
)
GO

---------------------------
ALTER TABLE [dbo].SummaryByLeague_Monthly
ADD	[IsLive]		BIT NULL;
GO

DROP INDEX CIX_EventDate ON [dbo].SummaryByLeague_Monthly
GO

CREATE CLUSTERED INDEX CIX_EventDate_IsLive ON [dbo].SummaryByLeague_Monthly (
	EventDate				ASC,
	[IsLive]				ASC
)
GO

---------------------------
ALTER TABLE [dbo].SummaryByTeam_Daily
ADD	[IsLive]		BIT NULL;
GO

DROP INDEX CIX_EventDate ON [dbo].SummaryByTeam_Daily
GO

CREATE CLUSTERED INDEX CIX_EventDate_IsLive ON [dbo].SummaryByTeam_Daily (
	EventDate				ASC,
	[IsLive]				ASC
)
GO

---------------------------
ALTER TABLE [dbo].SummaryByTeam_Monthly
ADD	[IsLive]		BIT NULL;
GO

DROP INDEX CIX_EventDate ON [dbo].SummaryByTeam_Monthly
GO

CREATE CLUSTERED INDEX CIX_EventDate_IsLive ON [dbo].SummaryByTeam_Monthly (
	EventDate				ASC,
	[IsLive]				ASC
)
GO

---------------------------
ALTER TABLE [dbo].SummaryByTrader_Monthly
ADD	[IsLive]		BIT NULL;
GO















CREATE INDEX CIX_SummaryByTrader_Monthly_LeagueId ON [dbo].[SummaryByTrader_Monthly] (
	[LeagueId]               ASC
)
GO

ALTER TABLE [dbo].[SummaryByTrader_Monthly]
ADD	[LeagueId]				INT NULL;
GO

CREATE INDEX CIX_SummaryByTrader_Monthly_LeagueId ON [dbo].[SummaryByTrader_Monthly] (
	[LeagueId]               ASC
)
GO

ALTER TABLE [dbo].[SummaryByTeam_Daily]
ADD	[LeagueId]				INT NULL;
GO

CREATE INDEX CIX_SummaryByTeam_Daily_LeagueId ON [dbo].[SummaryByTeam_Daily] (
	[LeagueId]               ASC
)
GO

ALTER TABLE [dbo].[SummaryByTeam_Monthly]
ADD	[LeagueId]				INT NULL;
GO

CREATE INDEX CIX_SummaryByTeam_Monthly_LeagueId ON [dbo].[SummaryByTeam_Monthly] (
	[LeagueId]               ASC
)
GO

ALTER TABLE [dbo].[TraderMatchCount_Monthly]
ADD	[LeagueId]				INT NULL;
GO

ALTER TABLE [TraderMatchCount_Monthly]
DROP CONSTRAINT PK_TraderMatchCount_Monthly
GO

CREATE CLUSTERED INDEX CIX_TraderMatchCount_Monthly ON [dbo].[TraderMatchCount_Monthly] (
	[CustId]				ASC,
	[EventDate]				ASC,
	[LeagueId]				ASC,
	[SportType]				ASC,
	[BetType]				ASC,
	[IsLive]				ASC
)
GO

ALTER TABLE [dbo].[TraderMatchCount_Yearly]
ADD	[LeagueId]				INT NULL;
GO

ALTER TABLE [TraderMatchCount_Yearly]
DROP CONSTRAINT PK_TraderMatchCount_Yearly
GO

CREATE CLUSTERED INDEX CIX_TraderMatchCount_Yearly ON [dbo].[TraderMatchCount_Yearly] (
	[CustId]				ASC,
	[Year]					ASC,
	[LeagueId]				ASC,
	[SportType]				ASC,
	[BetType]				ASC,
	[IsLive]				ASC
)
GO

ALTER TABLE [dbo].[TraderPerformance_Monthly]
ADD	[LeagueId]				INT NULL;
GO

ALTER TABLE [TraderPerformance_Monthly]
DROP CONSTRAINT PK_TraderPerformance_Monthly
GO

CREATE CLUSTERED INDEX CIX_TraderPerformance_Monthly ON [dbo].[TraderPerformance_Monthly] (
	[CustId]				ASC,
	[EventDate]				ASC,
	[LeagueId]				ASC,
	[SportType]				ASC,
	[BetType]				ASC,
	[IsLive]				ASC
)
GO

ALTER TABLE [dbo].[TraderPerformance_Yearly]
ADD	[LeagueId]				INT NULL;
GO

ALTER TABLE [TraderPerformance_Yearly]
DROP CONSTRAINT PK_TraderPerformance_Yearly
GO

CREATE CLUSTERED INDEX CIX_TraderPerformance_Yearly ON [dbo].[TraderPerformance_Yearly] (
	[CustId]				ASC,
	[Year]					ASC,
	[LeagueId]				ASC,
	[SportType]				ASC,
	[BetType]				ASC,
	[IsLive]				ASC
)
GO