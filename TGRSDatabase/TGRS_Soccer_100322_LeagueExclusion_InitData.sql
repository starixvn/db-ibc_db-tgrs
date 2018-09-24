/*
Creator: 20180905@LongLuu
Task:  Init Data for TGRS's League Exclusion
Server:  bodb_TGRS

Reviewer: Billy
*/ 

--USE	bodb_TGRS;
--GO

INSERT INTO dbo.LogActionType(ActionTypeId, ActionTypeName)
VALUES(8, N'League Exclusion Management');

INSERT INTO dbo.LogAction(ActionId, ActionTypeId, SPName, ActionName, Items, SubItems, IsInternal)
VALUES(800, 8, 'TGRS_LeagueExclusion_Insert', N'League Exclusion Management', '<root><xml path="r/z" /><row item="LeagueId" alias="l" /><row item="UserId" alias="cb" /><row item="ModifiedDate" alias="cd" /></root>', NULL, 0);


INSERT INTO dbo.LogAction(ActionId, ActionTypeId, SPName, ActionName, Items, SubItems, IsInternal)
VALUES(801, 8, 'TGRS_LeagueExclusion_Delete', N'League Exclusion Management', '<root><xml path="r/z" /><row item="LeagueId" alias="l" /><row item="UserId" alias="cb" /><row item="ModifiedDate" alias="cd" /></root>', NULL, 0);