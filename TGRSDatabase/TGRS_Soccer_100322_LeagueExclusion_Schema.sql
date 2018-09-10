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
