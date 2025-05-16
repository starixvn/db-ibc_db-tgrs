/*<info serverAlias="DBTGRS-bodb_TGRS" executers="wsv_tgrs" isFunction="0" isNested="0"></info>*/

use bodb_tgrs;
GO

-- https://nexdev.net/issues/211090
-- note: AssignmentBettype is not used anymore, it can be null

INSERT INTO bodb_TGRS.dbo.GroupBettype (GroupBettypeId, GroupBettypeName)
VALUES (8, 'SMP')

INSERT INTO bodb_TGRS.dbo.Bettype (Bettype, TypeName, OrderId, IsDefault, MainDBBettype, OperatorType, AssignmentBettype, IsUsedForJuice, GroupBettypeId, IsBetChoiceDetail)
VALUES (38, 'Single Match Parlay', 38, 0, 38, 1, 38, 0, 8, 0)

