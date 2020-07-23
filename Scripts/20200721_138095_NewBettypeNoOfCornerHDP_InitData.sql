/*
Creator:	20200721@John.Ngo
Task:		New Negative Bettype No Of Corner HDP [Redmine ID: 138095]
Server:		bodb_TGRS & bodb_TGRS_UAT

Reviewer:	Partrick
*/

--USE [bodb_TGRS]
--GO
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
SET NOCOUNT ON;

GO
UPDATE [dbo].[BetType] WITH(ROWLOCK) SET TypeName = '1st No. of Corners O/U', OrderId = 29 WHERE BetType = -12;
UPDATE [dbo].[BetType] WITH(ROWLOCK) SET TypeName = 'No. of Corners O/U', OrderId = 31 WHERE BetType = -13;
UPDATE [dbo].[BetType] WITH(ROWLOCK) SET TypeName = 'No. of Corners 15mins O/U' WHERE BetType = -7;

INSERT [dbo].[BetType] ([BetType], [TypeName], [OrderId], [IsDefault], [MainDBBetType], [OperatorType], [AssignmentBetType], [IsUsedForJuice], [BettypeGroup], [Disabled], [GroupBettypeId])
VALUES (-40, N'1st No. of Corners HDP', 28, 1, 7, NULL, NULL, 1, 1, 0, 1);

INSERT [dbo].[BetType] ([BetType], [TypeName], [OrderId], [IsDefault], [MainDBBetType], [OperatorType], [AssignmentBetType], [IsUsedForJuice], [BettypeGroup], [Disabled], [GroupBettypeId])
VALUES (-41, N'No. of Corners HDP', 30, 1, 1, NULL, NULL, 1, 1, 0, 1);

INSERT [dbo].[BetType] ([BetType], [TypeName], [OrderId], [IsDefault], [MainDBBetType], [OperatorType], [AssignmentBetType], [IsUsedForJuice], [BettypeGroup], [Disabled], [GroupBettypeId])
VALUES (-39, N'No. of Corners 15mins HDP', 32, 1, 1, NULL, NULL, 1, 1, 0, 1);
GO

GO
/*<info serverAlias="DBTGRS-bodb_TGRS"></info>*/