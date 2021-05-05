/*
Creator: 20210423@Adam.Tran
Task:  Create tables for TGRS's League Spread
Server:  bodb_TGRS

Reviewer: 
*/ 

--USE	bodb_TGRS;
--GO

CREATE TABLE [dbo].[LeagueSpread](
	[LeagueId]			INT NOT NULL,
	[Is8Percent]		TINYINT NOT NULL,
	[CreatedBy]			INT NULL,
	[CreatedDate]		DATETIME NULL,
	CONSTRAINT [PK_LeagueSpread] PRIMARY KEY CLUSTERED(
		[LeagueId]		ASC
	)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [DATA]
) ON [DATA]
GO