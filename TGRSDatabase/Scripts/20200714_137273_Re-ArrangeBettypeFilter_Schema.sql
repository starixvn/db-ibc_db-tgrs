/*
Creator: 20200714@John.Ngo
Task:  Init Data for Re-arrange bet type filter with parent-child [Redmine ID: 137273]
Server:  bodb_TGRS

Reviewer: Partrick
*/ 

--USE	bodb_TGRS;
--GO

----===================B. CREATE TABLES========================
----===========================================================
CREATE TABLE [dbo].[GroupBettype](
	[GroupBettypeId]		TINYINT NOT NULL,
	[GroupBettypeName]		NVARCHAR(100),
	[CreatedBy]				INT NULL,
	[CreatedDate]			DATETIME NULL,
CONSTRAINT [PK_GroupBettype] PRIMARY KEY CLUSTERED 
(
	[GroupBettypeId]			ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [DATA]
) ON [DATA]
GO

----===================C. ALTER TABLES=========================
----===========================================================

ALTER TABLE [dbo].[BetType]
ADD	[GroupBettypeId]		TINYINT NULL;
GO

CREATE NONCLUSTERED INDEX IX_BetType_GroupBettype ON [dbo].[BetType] (
	[GroupBettypeId]		ASC
)
GO
