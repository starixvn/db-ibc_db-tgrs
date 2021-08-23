/*
	Creator:	20210823@John.Ngo
	Task:		Sports - Performance Real Figures - [Redmine: #158981]
	Server:		DB06.bodb_TGRS_UAT

	Reviewer:   Brice
*/

USE bodb_TGRS_UAT

DECLARE @FDate	DATE = '20210701'
	,	@TDate	DATE = GETDATE();
	
TRUNCATE TABLE [Trader]
TRUNCATE TABLE Team
TRUNCATE TABLE Bettype
TRUNCATE TABLE TraderGrade_History
TRUNCATE TABLE TraderTeam_History
TRUNCATE TABLE Spread
TRUNCATE TABLE Spread_History
TRUNCATE TABLE Shift
TRUNCATE TABLE TraderShift_History

INSERT INTO [Trader]
SELECT * FROM DB061.bodb_TGRS.dbo.[Trader] WITH(NOLOCK)

SET IDENTITY_INSERT Team ON
INSERT INTO Team (TeamId, TeamName, Description, CreatedDate, CreatedBy, ModifiedDate, ModifiedBy, Disabled)
SELECT TeamId, TeamName, Description, CreatedDate, CreatedBy, ModifiedDate, ModifiedBy, Disabled FROM DB061.bodb_TGRS.dbo.Team WITH(NOLOCK)
SET IDENTITY_INSERT Team OFF

INSERT INTO Bettype
SELECT * FROM DB061.bodb_TGRS.dbo.Bettype WITH(NOLOCK)

INSERT INTO TraderGrade_History
SELECT * FROM DB061.bodb_TGRS.dbo.TraderGrade_History WITH(NOLOCK)

INSERT INTO TraderTeam_History
SELECT * FROM DB061.bodb_TGRS.dbo.TraderTeam_History WITH(NOLOCK)

INSERT INTO Spread
SELECT * FROM DB061.bodb_TGRS.dbo.Spread WITH(NOLOCK)

INSERT INTO Spread_History
SELECT * FROM DB061.bodb_TGRS.dbo.Spread_History WITH(NOLOCK)

SET IDENTITY_INSERT Shift ON
INSERT INTO Shift (ShiftId, ShiftName, Description, CreatedDate, CreatedBy, ModifiedDate, ModifiedBy, Disabled)
SELECT ShiftId, ShiftName, Description, CreatedDate, CreatedBy, ModifiedDate, ModifiedBy, Disabled from DB061.bodb_TGRS.dbo.Shift
SET IDENTITY_INSERT Shift OFF

INSERT INTO TraderShift_History
SELECT * FROM DB061.bodb_TGRS.dbo.TraderShift_History WITH(NOLOCK)

---- GEN Data

EXECUTE dbo.Task_RegenerateTGRSData_xtest @Debug = 1, @FromDate	= @FDate, @ToDate = @TDate,	@Flagged = 1

/*<info serverAlias="DB06-bodb_TGRS_UAT" executers="bodbTGRSNet" isFunction="0" isNested="0"></info>*/