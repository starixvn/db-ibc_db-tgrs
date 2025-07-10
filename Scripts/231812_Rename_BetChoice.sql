/*
	Creator:	20250710
	Task:		Rename BetChoice in BetChoiceMapping table - [Redmine: #231812]
	DB:			bodb_TGRS
*/

/*<info serverAlias="DBTGRS-bodb_TGRS" executers="bodbTGRSNet" isFunction="0" isNested="0"></info>*/

update BetChoiceMapping
set TGRSBetChoice = 'Fav'
where BetType in (select BetType from BetType where TypeName like '%1x2%')
and TGRSBetChoice in ('Home');

update BetChoiceMapping
set TGRSBetChoice = 'Und'
where BetType in (select BetType from BetType where TypeName like '%1x2%')
and TGRSBetChoice in ('Away');