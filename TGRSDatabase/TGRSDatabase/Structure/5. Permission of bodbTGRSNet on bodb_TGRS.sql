Use [bodb_TGRS]
GO

/****** Object:  User [bodbTGRSNet]    Script Date: 6/20/2014 12:58:16 PM ******/
CREATE USER [bodbTGRSNet] FOR LOGIN [bodbTGRSNet] WITH DEFAULT_SCHEMA=[dbo]
GO

GRANT CONNECT ON DATABASE::[bodb_TGRS] TO [bodbTGRSNet];
GRANT EXECUTE ON OBJECT::[dbo].[TGRS_Team_SelList] TO [bodbTGRSNet];
GRANT EXECUTE ON OBJECT::[dbo].[TGRS_Trader_SelectById] TO [bodbTGRSNet];
GRANT EXECUTE ON OBJECT::[dbo].[TGRS_Trader_SelectAll] TO [bodbTGRSNet];
GRANT EXECUTE ON OBJECT::[dbo].[TGRS_Trader_UpdateUsername] TO [bodbTGRSNet];
GRANT EXECUTE ON OBJECT::[dbo].[TGRS_BenchmarkTeam_SelectAll] TO [bodbTGRSNet];
GRANT EXECUTE ON OBJECT::[dbo].[TGRS_Rpt_DetailBetTypePerformance] TO [bodbTGRSNet];
GRANT EXECUTE ON OBJECT::[dbo].[TGRS_BenchmarkTeam_Update] TO [bodbTGRSNet];
GRANT EXECUTE ON OBJECT::[dbo].[TGRS_BenchmarkTeam_ProfitMargin] TO [bodbTGRSNet];
GRANT EXECUTE ON OBJECT::[dbo].[TGRS_SpecialLeague_SelList] TO [bodbTGRSNet];
GRANT EXECUTE ON OBJECT::[dbo].[TGRS_Country_SelList] TO [bodbTGRSNet];
GRANT EXECUTE ON OBJECT::[dbo].[TGRS_BenchmarkLeague_SelectAll] TO [bodbTGRSNet];
GRANT EXECUTE ON OBJECT::[dbo].[TGRS_BenchmarkLeague_ProfitMargin] TO [bodbTGRSNet];
GRANT EXECUTE ON OBJECT::[dbo].[TGRS_BenchmarkLeague_Update] TO [bodbTGRSNet];
GRANT EXECUTE ON OBJECT::[dbo].[TGRS_BenchmarkBetType_SelectAll] TO [bodbTGRSNet];
GRANT EXECUTE ON OBJECT::[dbo].[TGRS_BenchmarkBetType_ProfitMargin] TO [bodbTGRSNet];
GRANT EXECUTE ON OBJECT::[dbo].[TGRS_BenchmarkBetType_Update] TO [bodbTGRSNet];
GRANT EXECUTE ON OBJECT::[dbo].[TGRS_Rpt_SummaryGeneralInfo] TO [bodbTGRSNet];
GRANT EXECUTE ON OBJECT::[dbo].[TGRS_Rpt_SummaryTeamPerformance] TO [bodbTGRSNet];
GRANT EXECUTE ON OBJECT::[dbo].[TGRS_Rpt_SummaryBetTypePerformance] TO [bodbTGRSNet];
GRANT EXECUTE ON OBJECT::[dbo].[TGRS_Rpt_SummaryTopWinLeague] TO [bodbTGRSNet];
GRANT EXECUTE ON OBJECT::[dbo].[TGRS_Rpt_SummaryTopLoseLeague] TO [bodbTGRSNet];
GRANT EXECUTE ON OBJECT::[dbo].[TGRS_Rpt_SummaryTopTrader] TO [bodbTGRSNet];
GRANT EXECUTE ON OBJECT::[dbo].[TGRS_Rpt_SummaryTraderPerformace] TO [bodbTGRSNet];
GRANT EXECUTE ON OBJECT::[dbo].[TGRS_Bettype_SelList] TO [bodbTGRSNet];
GRANT EXECUTE ON OBJECT::[dbo].[TGRS_Rpt_Detail_TeamHistory] TO [bodbTGRSNet];
GRANT EXECUTE ON OBJECT::[dbo].[TGRS_Rpt_Detail_GradeHistory] TO [bodbTGRSNet];
GRANT EXECUTE ON OBJECT::[dbo].[TGRS_Rpt_DetailBetType_Trader] TO [bodbTGRSNet];
GRANT EXECUTE ON OBJECT::[dbo].[TGRS_Rpt_DetailBetType_Match] TO [bodbTGRSNet];
GRANT EXECUTE ON OBJECT::[dbo].[TGRS_Rpt_DetailBetType_League] TO [bodbTGRSNet];
GRANT EXECUTE ON OBJECT::[dbo].[TGRS_Rpt_DetailBetType_TraderByLeague] TO [bodbTGRSNet];
GRANT EXECUTE ON OBJECT::[dbo].[TGRS_Rpt_DetailBetType_MatchByTraderLeague] TO [bodbTGRSNet];
GRANT EXECUTE ON OBJECT::[dbo].[TGRS_Rpt_GradeHistory] TO [bodbTGRSNet];
GRANT EXECUTE ON OBJECT::[dbo].[TGRS_Trader_GradeHistory] TO [bodbTGRSNet];
GRANT EXECUTE ON OBJECT::[dbo].[TGRS_Trader_TeamHistory] TO [bodbTGRSNet];
GRANT EXECUTE ON OBJECT::[dbo].[TGRS_Rpt_DetailLeague_Match] TO [bodbTGRSNet];
GRANT EXECUTE ON OBJECT::[dbo].[TGRS_Rpt_DetailLeague_Trader] TO [bodbTGRSNet];
GRANT EXECUTE ON OBJECT::[dbo].[TGRS_Rpt_DetailLeaguePerformance] TO [bodbTGRSNet];
GRANT EXECUTE ON OBJECT::[dbo].[TGRS_Team_Insert] TO [bodbTGRSNet];
GRANT EXECUTE ON OBJECT::[dbo].[TGRS_Team_SelectAll] TO [bodbTGRSNet];
GRANT EXECUTE ON OBJECT::[dbo].[TGRS_Team_SelectById] TO [bodbTGRSNet];
GRANT EXECUTE ON OBJECT::[dbo].[TGRS_Team_Update] TO [bodbTGRSNet];
GRANT EXECUTE ON OBJECT::[dbo].[TGRS_WriteLog_RunSp] TO [bodbTGRSNet];
GRANT EXECUTE ON OBJECT::[dbo].[TGRS_Rpt_DetailTrader_Match] TO [bodbTGRSNet];
GRANT EXECUTE ON OBJECT::[dbo].[TGRS_Rpt_DetailTraderPerformance] TO [bodbTGRSNet];
GRANT EXECUTE ON OBJECT::[dbo].[TGRS_Rpt_DetailGradePerformance] TO [bodbTGRSNet];
GRANT EXECUTE ON OBJECT::[dbo].[TGRS_Rpt_DetailGrade_Trader] TO [bodbTGRSNet];
GRANT EXECUTE ON OBJECT::[dbo].[TGRS_Rpt_DetailGrade_Match] TO [bodbTGRSNet];
GRANT EXECUTE ON OBJECT::[dbo].[TGRS_Rpt_DetailTeamPerformance] TO [bodbTGRSNet];
GRANT EXECUTE ON OBJECT::[dbo].[TGRS_Rpt_DetailTeam_Trader] TO [bodbTGRSNet];
GRANT EXECUTE ON OBJECT::[dbo].[TGRS_Trader_Insert] TO [bodbTGRSNet];
GRANT EXECUTE ON OBJECT::[dbo].[TGRS_Rpt_DetailTeam_Match] TO [bodbTGRSNet];
GRANT EXECUTE ON OBJECT::[dbo].[TGRS_Trader_Update] TO [bodbTGRSNet];
