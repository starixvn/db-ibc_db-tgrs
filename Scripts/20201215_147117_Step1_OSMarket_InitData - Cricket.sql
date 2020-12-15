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

DECLARE @CurrentDate DATETIME = GETDATE();

SET IDENTITY_INSERT [dbo].[OSMarket] ON 
-- Cricket
INSERT [dbo].[OSMarket] ([SportId], [MarketId], [MarketName], [CreatedBy], [CreatedDate]) 
VALUES (27, 1, N'Batsman Runs', 20902509, @CurrentDate)
INSERT [dbo].[OSMarket] ([SportId], [MarketId], [MarketName], [CreatedBy], [CreatedDate]) 
VALUES (27, 2, N'Fall of Wicket', 20902509, @CurrentDate)
INSERT [dbo].[OSMarket] ([SportId], [MarketId], [MarketName], [CreatedBy], [CreatedDate]) 
VALUES (27, 3, N'Group Runs', 20902509, @CurrentDate)
INSERT [dbo].[OSMarket] ([SportId], [MarketId], [MarketName], [CreatedBy], [CreatedDate]) 
VALUES (27, 4, N'Highest Individual Score', 20902509, @CurrentDate)
INSERT [dbo].[OSMarket] ([SportId], [MarketId], [MarketName], [CreatedBy], [CreatedDate]) 
VALUES (27, 5, N'Highest Opening Partnership', 20902509, @CurrentDate)
INSERT [dbo].[OSMarket] ([SportId], [MarketId], [MarketName], [CreatedBy], [CreatedDate]) 
VALUES (27, 6, N'Highest Over Score', 20902509, @CurrentDate)
INSERT [dbo].[OSMarket] ([SportId], [MarketId], [MarketName], [CreatedBy], [CreatedDate]) 
VALUES (27, 7, N'Highest Score in Over 1', 20902509, @CurrentDate)
INSERT [dbo].[OSMarket] ([SportId], [MarketId], [MarketName], [CreatedBy], [CreatedDate]) 
VALUES (27, 8, N'Innings Runs', 20902509, @CurrentDate)
INSERT [dbo].[OSMarket] ([SportId], [MarketId], [MarketName], [CreatedBy], [CreatedDate]) 
VALUES (27, 9, N'Match Extras', 20902509, @CurrentDate)
INSERT [dbo].[OSMarket] ([SportId], [MarketId], [MarketName], [CreatedBy], [CreatedDate]) 
VALUES (27, 10, N'Match Fours', 20902509, @CurrentDate)
INSERT [dbo].[OSMarket] ([SportId], [MarketId], [MarketName], [CreatedBy], [CreatedDate]) 
VALUES (27, 11, N'Match Sixes', 20902509, @CurrentDate)
INSERT [dbo].[OSMarket] ([SportId], [MarketId], [MarketName], [CreatedBy], [CreatedDate])
VALUES (27, 12, N'Match Wickets', 20902509, @CurrentDate)
INSERT [dbo].[OSMarket] ([SportId], [MarketId], [MarketName], [CreatedBy], [CreatedDate]) 
VALUES (27, 13, N'Method of Dismissal', 20902509, @CurrentDate)
INSERT [dbo].[OSMarket] ([SportId], [MarketId], [MarketName], [CreatedBy], [CreatedDate]) 
VALUES (27, 14, N'Player Runs', 20902509, @CurrentDate)
INSERT [dbo].[OSMarket] ([SportId], [MarketId], [MarketName], [CreatedBy], [CreatedDate]) 
VALUES (27, 15, N'Score after Ball', 20902509, @CurrentDate)
INSERT [dbo].[OSMarket] ([SportId], [MarketId], [MarketName], [CreatedBy], [CreatedDate]) 
VALUES (27, 16, N'Score at End of Over', 20902509, @CurrentDate)
INSERT [dbo].[OSMarket] ([SportId], [MarketId], [MarketName], [CreatedBy], [CreatedDate]) 
VALUES (27, 17, N'Super Over Winner', 20902509, @CurrentDate)
INSERT [dbo].[OSMarket] ([SportId], [MarketId], [MarketName], [CreatedBy], [CreatedDate]) 
VALUES (27, 18, N'Total Tournament Duck', 20902509, @CurrentDate)
INSERT [dbo].[OSMarket] ([SportId], [MarketId], [MarketName], [CreatedBy], [CreatedDate]) 
VALUES (27, 19, N'Total Tournament Run-outs', 20902509, @CurrentDate)
INSERT [dbo].[OSMarket] ([SportId], [MarketId], [MarketName], [CreatedBy], [CreatedDate]) 
VALUES (27, 20, N'Total Tournament Sixes', 20902509, @CurrentDate)
INSERT [dbo].[OSMarket] ([SportId], [MarketId], [MarketName], [CreatedBy], [CreatedDate]) 
VALUES (27, 21, N'Total Tournament Wickets', 20902509, @CurrentDate)
INSERT [dbo].[OSMarket] ([SportId], [MarketId], [MarketName], [CreatedBy], [CreatedDate]) 
VALUES (27, 22, N'Tournament Highest Individual Score', 20902509, @CurrentDate)
INSERT [dbo].[OSMarket] ([SportId], [MarketId], [MarketName], [CreatedBy], [CreatedDate]) 
VALUES (27, 23, N'Tournament Highest Innings Score', 20902509, @CurrentDate)
INSERT [dbo].[OSMarket] ([SportId], [MarketId], [MarketName], [CreatedBy], [CreatedDate]) 
VALUES (27, 24, N'Tournament Highest Opening Partnership', 20902509, @CurrentDate)
INSERT [dbo].[OSMarket] ([SportId], [MarketId], [MarketName], [CreatedBy], [CreatedDate]) 
VALUES (27, 25, N'Tournament Highest Over Score', 20902509, @CurrentDate)
INSERT [dbo].[OSMarket] ([SportId], [MarketId], [MarketName], [CreatedBy], [CreatedDate]) 
VALUES (27, 26, N'Tournament Highest Score at End of Over 1', 20902509, @CurrentDate)
INSERT [dbo].[OSMarket] ([SportId], [MarketId], [MarketName], [CreatedBy], [CreatedDate]) 
VALUES (27, 27, N'Win Toss', 20902509, @CurrentDate)
INSERT [dbo].[OSMarket] ([SportId], [MarketId], [MarketName], [CreatedBy], [CreatedDate]) -- Offer Bettype
VALUES (27, 28, N'Outright', 20902509, @CurrentDate)
INSERT [dbo].[OSMarket] ([SportId], [MarketId], [MarketName], [CreatedBy], [CreatedDate]) -- Offer Bettype
VALUES (27, 29, N'Match Winner', 20902509, @CurrentDate)
INSERT [dbo].[OSMarket] ([SportId], [MarketId], [MarketName], [CreatedBy], [CreatedDate]) -- Offer Bettype
VALUES (27, 30, N'FT.1X2', 20902509, @CurrentDate)

-- Darts
UPDATE [dbo].[OSMarket] WITH(ROWLOCK)
SET MarketName = 'First Set Winner' WHERE SportId = 25 AND MarketId = 3;
UPDATE [dbo].[OSMarket] WITH(ROWLOCK)
SET MarketName = 'Winner' WHERE SportId = 25 AND MarketId = 4;
UPDATE [dbo].[OSMarket] WITH(ROWLOCK)
SET MarketName = 'Full Time' WHERE SportId = 25 AND MarketId = 5;

SET IDENTITY_INSERT [dbo].[OSMarket] OFF
