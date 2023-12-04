/*
	Creator:	20231204@John.Ngo
	Task:		[TGR OS] Add 4 new bettypes in basketball performance - [Redmine: #197478]
	DB:			DB062.bodb_TGRS_UAT & DB061.bodb_TGRS
	
	Reviewer: 	Sol
*/

GO
-- OSBettype
INSERT [dbo].[OSBettype] ([BettypeId], [BettypeName], [OrderId], [IsDefault], [MainDBBettype], [OperatorType], [AssignmentBettype], [IsUsedForJuice],GroupBettypeId)
VALUES (647, N'Ending Game', 0, 0, NULL, NULL, NULL, 0, 2)
	, (648, N'1H Ending Game', 0, 0, NULL, NULL, NULL, 0, 2)
	, (649, N'2H Ending Game', 0, 0, NULL, NULL, NULL, 0, 2)
	, (650, N'Quarter X Ending Game', 0, 0, NULL, NULL, NULL, 0, 2)

GO
/*<info serverAlias="DBTGRS-bodb_TGRS" executers="bodbTGRSNet" isFunction="0" isNested="0"></info>*/