/*
Creator: 20190128@LongLuu
Task:  Init Config Data for TGRS's League Exclusion
Server:  bodb_TGRS

Reviewer: Billy
*/ 

INSERT INTO dbo.SystemSettings(VName, VValue)
VALUES(N'ExcludeLeagues', N'True');

INSERT INTO dbo.LogAction(ActionId, ActionTypeId, SPName, ActionName, Items, SubItems, IsInternal)
VALUES(501, 5, 'TGRS_LeagueExclusion_UpdateConfig', N'Update League Exclusion Config', '<root><xml path="r/z" /><row item="ModifiedDate" alias="md" /><row item="NewValue" alias="v" /></root>', NULL, 0);
