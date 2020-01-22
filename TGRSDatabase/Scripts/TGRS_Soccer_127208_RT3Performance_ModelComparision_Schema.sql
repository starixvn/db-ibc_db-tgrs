/*
	Creator:	20200120@John
	Task:		[TGR Soccer] RT3 Performance - Model Comparision Report [Redmine ID: 127208]
	Server:		DBTGRS.bodb_TGRS

	Reviewer: Billy
*/

ALTER TABLE dbo.[RobotTrading]
ADD	  [Type] TINYINT NULL

ALTER TABLE dbo.[RobotTrading_Monthly]
ADD	  [Type] TINYINT NULL

ALTER TABLE dbo.[RobotTrading_BetTypeDaily]
ADD	  [Type] TINYINT NULL

ALTER TABLE dbo.[RobotTrading_BetTypeMonthly]
ADD	  [Type] TINYINT NULL
