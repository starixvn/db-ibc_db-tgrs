/*
	Creator:	20190911@Long.Luu
	Task:		Support Non-live Data - [Redmine: #118959]
	Server:		DB06.bodb_TGRS
*/

USE bodb_TGRS

SET IDENTITY_INSERT [dbo].[Team] ON

INSERT INTO [dbo].[Team](TeamId,TeamName,[Description],CreatedDate,CreatedBy,ModifiedDate,ModifiedBy,[Disabled])
VALUES(255,'NonLiveUnassignedTeam','Default Team for Non Live Unassigned Trader',GETDATE(),8,NULL,NULL,0);

SET IDENTITY_INSERT [dbo].[Team] OFF
GO

INSERT INTO [dbo].[Trader](CustId,Username,EmployeeId,TeamId,Grade,CreatedDate,CreatedBy,ModifiedDate,ModifiedBy,[Disabled],TeamEffectiveDate,GradeEffectiveDate,Remark,Shift,ShiftEffectiveDate)
VALUES(-1,'NonLiveUnassignedTrader','NonLiveUnassigned',255,255,GETDATE(),8,GETDATE(),8,0,GETDATE(),GETDATE(),NULL,8,GETDATE());
GO

UPDATE tp WITH(ROWLOCK, UPDLOCK)
SET tp.CustId = -1
FROM [dbo].[TraderPerformance] AS tp
WHERE tp.IsLive = 0;

