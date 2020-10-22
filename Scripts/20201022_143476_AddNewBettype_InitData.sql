/*
Creator: 20201022@John.Ngo
Task:  Init Data for 'Bet Type group: Time Machine' [Redmine ID: 143476]
Server:  DB06.bodb_TGRS_UAT & DB061.bodb_TGRS

Reviewer: Partrick
*/ 

--USE	bodb_TGRS;
--GO
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
SET NOCOUNT ON;

DECLARE @CurrentDate DATETIME = GETDATE();

INSERT INTO dbo.GroupBettype(GroupBettypeId,GroupBettypeName,CreatedBy,CreatedDate)
VALUES(6, N'Time Machine', 20902509 ,@CurrentDate);

-- New bettype 'SABA OU Time Machine'
INSERT [dbo].[BetType] ([BetType], [TypeName], [OrderId], [IsDefault], [MainDBBetType], [OperatorType], [AssignmentBetType], [IsUsedForJuice], [BettypeGroup], [Disabled], [GroupBettypeId])
VALUES (228, N'SABA OU Time Machine', 999, 0, 228, NULL, NULL, 0, 2, 0, 6);

GO
/*<info serverAlias="DBTGRS-bodb_TGRS"></info>*/