/*
	Creator:	20211123@Adam.Tran
	Task:		Basketball - View report to Set X Game Y - [Redmine: #164165]
	DB:			DB06.bodb_TGRS_UAT & DB061.bodb_TGRS
*/

USE bodb_TGRS

ALTER TABLE [dbo].[OSDataTGRS_BetChoice] ADD	
	[betid]			BIGINT	NULL
	
GO

/*<info serverAlias="DBTGRS-bodb_TGRS" executers="bodbTGRSNet" isFunction="0" isNested="0"></info>*/
