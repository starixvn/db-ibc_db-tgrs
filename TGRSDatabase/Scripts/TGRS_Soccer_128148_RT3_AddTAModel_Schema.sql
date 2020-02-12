/*
Creator: 20200210@John.Ngo
Task:  Create tables for TGRS's RT3 - FilteredSite [Redmine ID: 128184]
Server:  bodb_TGRS

Reviewer: Billy
*/ 

----===================A. DROP TABLES=========================
----==========================================================


----===================B. CREATE TABLES========================
----===========================================================
CREATE TABLE [dbo].[FilteredSite](
		[SiteId]			INT NOT NULL
	,	[Site]				VARCHAR(20) NOT NULL
	,	[IsDeposite]		BIT NOT	NULL
	,	[TypeSiteDesc]		VARCHAR(20) NULL
	,	[TypeSiteId]		TINYINT NULL
	,	[IsActive]			BIT NOT NULL
	,	CONSTRAINT [PK_FilteredSite] PRIMARY KEY CLUSTERED 
	(
		[SiteId]			ASC
	)	WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [DATA]
) ON [DATA]
GO

CREATE NONCLUSTERED INDEX IX_FilteredSite_Site ON [dbo].[FilteredSite] (
	[Site]			ASC
)
GO

----===================C. ALTER TABLES=========================
----===========================================================

ALTER TABLE dbo.[RobotTrading]
ADD	  [TypeSiteId]		TINYINT NULL

DROP INDEX IX_RobotTrading_EventDateIs8RMTypeMatchId ON [dbo].[RobotTrading]
GO

CREATE NONCLUSTERED INDEX IX_RobotTrading_EventDateIdx ON [dbo].[RobotTrading] (
	[EventDate]			ASC,
	[Is8RM]				ASC,
	[Type]				ASC,
	[TypeSiteId]		ASC,
	[MatchId]			ASC
)
GO

ALTER TABLE dbo.[RobotTrading_Monthly]
ADD	  [TypeSiteId]		TINYINT NULL

DROP INDEX CIX_RobotTrading_Monthly_EventDateLeagueGroupIdIs8RMType ON [dbo].[RobotTrading_Monthly]
GO

CREATE CLUSTERED INDEX CIX_RobotTrading_Monthly_EventDateIdx ON [dbo].[RobotTrading_Monthly] (
	[EventDate]			ASC,
	[LeagueGroupId]		ASC,
	[Is8RM]				ASC,
	[Type]				ASC,
	[TypeSiteId]		ASC
)
GO

ALTER TABLE dbo.[RobotTrading_BetTypeDaily]
ADD	  [TypeSiteId]		TINYINT NULL

DROP INDEX IX_RobotTrading_BetTypeDaily_EventDateIs8RMType ON [dbo].[RobotTrading_BetTypeDaily]
GO

CREATE NONCLUSTERED INDEX IX_RobotTrading_BetTypeDaily_EventDateIdx ON [dbo].[RobotTrading_BetTypeDaily] (
	[EventDate]			ASC,
	[Is8RM]				ASC,
	[Type]				ASC,
	[TypeSiteId]		ASC
)
GO

ALTER TABLE dbo.[RobotTrading_BetTypeMonthly]
ADD	  [TypeSiteId]		TINYINT NULL

DROP INDEX IX_RobotTrading_BetTypeMonthly_EventDateIs8RMType ON [dbo].[RobotTrading_BetTypeMonthly]
GO

CREATE NONCLUSTERED INDEX IX_RobotTrading_BetTypeMonthly_EventDateIdx ON [dbo].[RobotTrading_BetTypeMonthly] (
	[EventDate]			ASC,
	[Is8RM]				ASC,
	[Type]				ASC,
	[TypeSiteId]		ASC
)
GO