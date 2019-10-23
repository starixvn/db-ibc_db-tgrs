/*
	Creator:	20190911@Long.Luu
	Task:		Support Non-live Data - [Redmine: #118959]
	Server:		DB06.bodb_TGRS
*/

USE [bodb_TGRS]
GO

-- Bettype
INSERT [dbo].[BetType] ([BetType], [TypeName], [OrderId], [IsDefault], [MainDBBetType], [OperatorType], [AssignmentBetType], [IsUsedForJuice], [BettypeGroup], [Disabled])
VALUES (468, N'Score Box Handicap', 999, 0, 468, 1, 37, 0, 2, 0)
GO

INSERT [dbo].[BetType] ([BetType], [TypeName], [OrderId], [IsDefault], [MainDBBetType], [OperatorType], [AssignmentBetType], [IsUsedForJuice], [BettypeGroup], [Disabled])
VALUES (469, N'Score Box Over/Under', 999, 0, 469, 1, 37, 0, 2, 0)
GO

-- Betchoice Mapping
INSERT [dbo].[BetChoiceMapping] ([BetType], [BetChoice], [TGRSBetChoice]) VALUES (-37, N'a', N'Away')
INSERT [dbo].[BetChoiceMapping] ([BetType], [BetChoice], [TGRSBetChoice]) VALUES (-37, N'h', N'Home')
GO