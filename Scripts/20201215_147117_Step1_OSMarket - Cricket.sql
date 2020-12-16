/*
Creator: 20201215@John.Ngo
Task: [OS] Market Count - Init Data for OS Market - Cricket [Redmine ID: 147117]
Server:  DB06.bodb_TGRS_UAT & DB061.bodb_TGRS

Reviewer: Partrick
*/ 

--USE	bodb_TGRS;
--GO
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
SET NOCOUNT ON;

SET IDENTITY_INSERT [dbo].[OSMarket] ON 

-- Cricket
UPDATE [dbo].[OSMarket] WITH(ROWLOCK)
SET SportId = 50 WHERE SportId = 27;

SET IDENTITY_INSERT [dbo].[OSMarket] OFF

UPDATE [dbo].[OSMarketMapping] WITH(ROWLOCK)
SET SportId = 50 WHERE SportId = 27;
