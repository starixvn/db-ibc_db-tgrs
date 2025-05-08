use bodb_archive;
create user wsv_tgrs from login wsv_tgrs;
grant select on match_bk to wsv_tgrs;

use bodb02;

grant select on team to wsv_tgrs;
grant select on leaguegroup to wsv_tgrs;
grant select on league to wsv_tgrs;
grant select on Acc_GroupExtraPTSetting to wsv_tgrs;
grant select on MatchMaxbet14 to wsv_tgrs;
grant select on MatchMaxbet to wsv_tgrs;

/*<info serverAlias="DBTGRS-bodb_TGRS" executers="wsv_tgrs"></info>*/
