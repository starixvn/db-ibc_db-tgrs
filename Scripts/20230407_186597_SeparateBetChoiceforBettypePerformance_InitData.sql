/*
	Creator:	20230407@John.Ngo
	Task:		[TGR] Separate bet choice performance on Performance Detail Report - [Redmine: #186597]
	DB:			DB06.bodb_TGRS_UAT & DB061.bodb_TGRS
	
	Reviewer: 	Sol
*/

GO
-- Remove Mapping for 2H Correct Score, Correct Score (AOS), 1H Correct Score (AOS)
DELETE b WITH(ROWLOCK) 
FROM dbo.BetChoiceMapping AS b 
WHERE b.BetType IN (405,413,414);

GO
/*<info serverAlias="DBTGRS-bodb_TGRS" executers="bodbTGRSNet" isFunction="0" isNested="0"></info>*/