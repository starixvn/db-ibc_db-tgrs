/*
	Creator:	20190903@John.Ngo
	Task:		Update bet types name for PH4b bet types - [Redmine: #119595]
	Server:		DB06.bodb_TGRS
*/

USE bodb_TGRS

-- PH4b
GO
-- 1H Corners Odd/Even (471)
INSERT [dbo].[BetChoiceMapping] ([BetType], [BetChoice], [TGRSBetChoice]) VALUES (471, N'O', N'Odd')
INSERT [dbo].[BetChoiceMapping] ([BetType], [BetChoice], [TGRSBetChoice]) VALUES (471, N'E', N'Even')
GO
-- Update Bettype Name
UPDATE dbo.BetType SET TypeName = 'First Corner (own)' WHERE BetType = 488
UPDATE dbo.BetType SET TypeName = '1H First Corner (own)' WHERE BetType = 489
UPDATE dbo.BetType SET TypeName = '2H First Corner' WHERE BetType = 490
UPDATE dbo.BetType SET TypeName = 'Last Corner (own)' WHERE BetType = 491
UPDATE dbo.BetType SET TypeName = '1H Last Corner (own)' WHERE BetType = 492