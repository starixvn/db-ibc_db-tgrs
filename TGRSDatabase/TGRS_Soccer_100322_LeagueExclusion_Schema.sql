/*
Creator: 20180905@LongLuu
Task:  Create tables for TGRS's League Exclusion
Server:  bodb_TGRS

Reviewer: Billy
*/ 

--USE	bodb_TGRS;
--GO


----===================A. DROP TABLES=========================
----==========================================================


----===================B. CREATE TABLES========================
----===========================================================
CREATE TABLE [dbo].[LeagueExclusion](
	[LeagueId]			INT NOT NULL,
	[CreatedBy]			INT NULL,
	[CreatedDate]		DATETIME NULL,
CONSTRAINT [PK_LeagueExclusion] PRIMARY KEY CLUSTERED 
(
	[LeagueId]			ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [DATA]
) ON [DATA]
GO

----===================C. ALTER TABLES=========================
----===========================================================
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