/*
	Creator:	20230109@John.Ngo
	Task:		Syn-data Setting TGRS & Gen data [Redmine ID: 182351]
	Server:		DB06.bodb_TGRS_UAT

	Reviewer:   Sol
*/

USE bodb_TGRS_UAT

DECLARE @FDate	DATE = '20221201'
	,	@TDate	DATE = GETDATE();

-- Soccer Setting	
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

-- OS Setting
TRUNCATE TABLE [OSTeam]
TRUNCATE TABLE [OSTrader]
TRUNCATE TABLE OSTraderTeamHistory
TRUNCATE TABLE OSTraderGradeHistory

SET IDENTITY_INSERT [OSTeam] ON
INSERT INTO [OSTeam]
SELECT * from DB061.bodb_TGRS.dbo.[OSTeam]
SET IDENTITY_INSERT Team OFF

SET IDENTITY_INSERT [OSTrader] ON
INSERT INTO [OSTrader]
SELECT * from DB061.bodb_TGRS.dbo.[OSTrader]
SET IDENTITY_INSERT Team OFF

INSERT INTO OSTraderTeamHistory
SELECT * FROM DB061.bodb_TGRS.dbo.OSTraderTeamHistory

INSERT INTO OSTraderGradeHistory
SELECT * FROM DB061.bodb_TGRS.dbo.OSTraderGradeHistory

---- GEN Data
EXECUTE dbo.Task_RegenerateTGRSData_xtest @Debug = 1, @FromDate	= @FDate, @ToDate = @TDate,	@Flagged = 0

/*<info serverAlias="DBTGRS-bodb_TGRS" executers="bodbTGRSNet" isFunction="0" isNested="0"></info>*/