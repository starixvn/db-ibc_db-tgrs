/*
	Creator:	20220224@John.Ngo
	Task:		[TGR Soccer] Add new bet type 461, 462, 463, 464 to support drilldown to HDP - [Redmine: #161859]
	DB:			DB06.bodb_TGRS_UAT & DB061.bodb_TGRS
	
	Reviewer: 	Brice
*/

GO

-- HDP level for '461, 462, 463, 464'
UPDATE bt WITH(ROWLOCK, UPDLOCK)
SET bt.IsBetChoiceDetail = 1
FROM [dbo].[BetType]  AS bt WHERE bt.Bettype in (461,462,463,464)

GO
/*<info serverAlias="DBTGRS-bodb_TGRS" executers="bodbTGRSNet" isFunction="0" isNested="0"></info>*/