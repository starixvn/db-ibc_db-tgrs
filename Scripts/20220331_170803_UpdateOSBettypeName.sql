/*
	Creator: 	20220331@john.ngo
	Task: 		Update OS Bettype Name [Redmine ID: #170803]
	DB: 		DB062.bodb_TGRS_UAT & DB062.bodb_TGRS

	Reviewer: 	Brice
*/

GO

-- BettypeName
UPDATE [dbo].[OSBettype] WITH(ROWLOCK)
SET BettypeName = '1H Winning Margin 13 Way' WHERE BettypeId = 608;

GO
/*<info serverAlias="DBTGRS-bodb_TGRS" executers="bodbTGRSNet" isFunction="0" isNested="0"></info>*/