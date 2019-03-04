/*
	Creator:	20190304@John
	Task:		[TGR Soccer] Add new report to view Real Performance [Redmine ID: 108920]
	Server:		DB06.bodb_TGRS & DBTP.bodb_TGRS_UAT

	Reviewer: Billy
*/

ALTER TABLE dbo.TraderPerformance
ADD	  Stake_AR MONEY NULL
	, WinLost_AR MONEY NULL
	, Comm_AR MONEY NULL
	, Juice_AR MONEY NULL
	, StakeMYR_AR MONEY NULL
	, StakeMYRJuice_AR MONEY NULL

ALTER TABLE dbo.TraderPerformance_BetChoice
ADD	  Stake_AR MONEY NULL
	, WinLost_AR MONEY NULL
	, Comm_AR MONEY NULL

ALTER TABLE dbo.SummaryByBetType_Daily
ADD	  Stake_AR MONEY NULL
	, WinLost_AR MONEY NULL
	, Comm_AR MONEY NULL

ALTER TABLE dbo.SummaryByBetType_Monthly
ADD	  Stake_AR MONEY NULL
	, WinLost_AR MONEY NULL
	, Comm_AR MONEY NULL

ALTER TABLE dbo.SummaryByLeague_Daily
ADD	  Stake_AR MONEY NULL
	, WinLost_AR MONEY NULL
	, Comm_AR MONEY NULL

ALTER TABLE dbo.SummaryByLeague_Monthly
ADD	  Stake_AR MONEY NULL
	, WinLost_AR MONEY NULL
	, Comm_AR MONEY NULL

ALTER TABLE dbo.SummaryByTeam_Daily
ADD	  Stake_AR MONEY NULL
	, WinLost_AR MONEY NULL
	, Comm_AR MONEY NULL

ALTER TABLE dbo.SummaryByTeam_Monthly
ADD	  Stake_AR MONEY NULL
	, WinLost_AR MONEY NULL
	, Comm_AR MONEY NULL

ALTER TABLE dbo.SummaryByTrader_Monthly
ADD	  Stake_AR MONEY NULL
	, WinLost_AR MONEY NULL
	, Comm_AR MONEY NULL

ALTER TABLE dbo.TraderPerformance_Monthly
ADD	  Turnover_AR MONEY NULL
	, WinLoss_AR MONEY NULL
	, Comm_AR MONEY NULL

ALTER TABLE dbo.TraderPerformance_Yearly
ADD	  Turnover_AR MONEY NULL
	, WinLoss_AR MONEY NULL
	, Comm_AR MONEY NULL
