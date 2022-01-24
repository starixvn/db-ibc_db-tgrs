/*
	Creator:	20220117@John.Ngo
	Task:		[TGR Soccer] Support view down for Total Goal, Time Machine and Corner bettype - [Redmine: #166679]
	DB:			DB06.bodb_TGRS_UAT & DB061.bodb_TGRS
	
	Reviewer: 	Brice
*/

GO
-- Fast Market
UPDATE bt WITH(ROWLOCK, UPDLOCK)
SET bt.IsBetChoiceDetail = 1
FROM [dbo].[BetType]  AS bt WHERE bt.Bettype in (221,222,223,224,225,226,227)

-- HDP level for Total Goals & Time Machine bettypes
UPDATE bt WITH(ROWLOCK, UPDLOCK)
SET bt.IsBetChoiceDetail = 1
FROM [dbo].[BetType]  AS bt WHERE bt.Bettype in (401,402,403,404,418,457,143,144,449,450,28,453,228,229)

-- Point level for Corners bettypes
UPDATE bt WITH(ROWLOCK, UPDLOCK)
SET bt.IsBetChoiceDetail = 1
FROM [dbo].[BetType]  AS bt WHERE bt.Bettype in (475,476,477,478,482,483,484,485,486,487)

GO
/*<info serverAlias="DBTGRS-bodb_TGRS" executers="bodbTGRSNet" isFunction="0" isNested="0"></info>*/