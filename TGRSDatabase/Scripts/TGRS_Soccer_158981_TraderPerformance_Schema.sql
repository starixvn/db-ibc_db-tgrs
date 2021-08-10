/*
	Creator:	20210726@Adam.Tran
	Task:		Sports - Performance Real Figures - [Redmine: #158981]
	Server:		DB06.bodb_TGRS
*/

USE bodb_TGRS

ALTER TABLE [dbo].TraderPerformance DROP COLUMN
 [Is8RM], [Stake_Real], [WinLost_Real], [Stake_VAR], [WinLost_VAR], [Comm_VAR];

ALTER TABLE [dbo].TraderPerformance ADD	
	[Is8RM]			BIT NULL,
	[Stake_Real]	MONEY NULL,
	[WinLost_Real]	MONEY NULL,
	[Stake_VAR]		MONEY NULL,
	[WinLost_VAR]	MONEY NULL,
	[Comm_VAR]		MONEY NULL;

ALTER TABLE [dbo].TraderPerformance_BetChoice ADD	
	[Is8RM]			BIT NULL,
	[Stake_Real]	MONEY NULL,
	[WinLost_Real]	MONEY NULL,
	[Stake_VAR]		MONEY NULL,
	[WinLost_VAR]	MONEY NULL,
	[Comm_VAR]		MONEY NULL;

ALTER TABLE [dbo].TraderPerformance_Monthly ADD
	[Is8RM]			BIT NULL,
	[Stake_Real]	MONEY NULL,
	[WinLost_Real]	MONEY NULL,
	[Stake_VAR]		MONEY NULL,
	[WinLost_VAR]	MONEY NULL,
	[Comm_VAR]		MONEY NULL;

ALTER TABLE [dbo].TraderPerformance_Yearly ADD
	[Is8RM]			BIT NULL,
	[Stake_Real]	MONEY NULL,
	[WinLost_Real]	MONEY NULL,
	[Stake_VAR]		MONEY NULL,
	[WinLost_VAR]	MONEY NULL,
	[Comm_VAR]		MONEY NULL;

ALTER TABLE [dbo].SummaryByBetType_Daily ADD	
	[Is8RM]			BIT NULL,
	[Stake_Real]	MONEY NULL,
	[WinLost_Real]	MONEY NULL,
	[Stake_VAR]		MONEY NULL,
	[WinLost_VAR]	MONEY NULL,
	[Comm_VAR]		MONEY NULL;

ALTER TABLE [dbo].SummaryByLeague_Daily ADD	
	[Is8RM]			BIT NULL,
	[Stake_Real]	MONEY NULL,
	[WinLost_Real]	MONEY NULL,
	[Stake_VAR]		MONEY NULL,
	[WinLost_VAR]	MONEY NULL,
	[Comm_VAR]		MONEY NULL;
	
ALTER TABLE [dbo].SummaryByTeam_Daily ADD	
	[Is8RM]			BIT NULL,
	[Stake_Real]	MONEY NULL,
	[WinLost_Real]	MONEY NULL,
	[Stake_VAR]		MONEY NULL,
	[WinLost_VAR]	MONEY NULL,
	[Comm_VAR]		MONEY NULL;	

ALTER TABLE [dbo].SummaryByTrader_Monthly ADD
	[Is8RM]			BIT NULL,
	[Stake_Real]	MONEY NULL,
	[WinLost_Real]	MONEY NULL,
	[Stake_VAR]		MONEY NULL,
	[WinLost_VAR]	MONEY NULL,
	[Comm_VAR]		MONEY NULL;

ALTER TABLE [dbo].SummaryByLeague_Monthly ADD
	[Is8RM]			BIT NULL,
	[Stake_Real]	MONEY NULL,
	[WinLost_Real]	MONEY NULL,
	[Stake_VAR]		MONEY NULL,
	[WinLost_VAR]	MONEY NULL,
	[Comm_VAR]		MONEY NULL;

ALTER TABLE [dbo].SummaryByTeam_Monthly ADD
	[Is8RM]			BIT NULL,
	[Stake_Real]	MONEY NULL,
	[WinLost_Real]	MONEY NULL,
	[Stake_VAR]		MONEY NULL,
	[WinLost_VAR]	MONEY NULL,
	[Comm_VAR]		MONEY NULL;
	
ALTER TABLE [dbo].SummaryByBetType_Monthly ADD
	[Is8RM]			BIT NULL,
	[Stake_Real]	MONEY NULL,
	[WinLost_Real]	MONEY NULL,
	[Stake_VAR]		MONEY NULL,
	[WinLost_VAR]	MONEY NULL,
	[Comm_VAR]		MONEY NULL;

ALTER TABLE [dbo].OSDataTGRS ADD	
	[Is8RM]			BIT NULL,
	[Stake_Real]	MONEY NULL,
	[WinLost_Real]	MONEY NULL,
	[Stake_VAR]		MONEY NULL,
	[WinLost_VAR]	MONEY NULL,
	[Comm_VAR]		MONEY NULL;

ALTER TABLE [dbo].OSDataTGRS_BetChoice ADD
	[Is8RM]			BIT NULL,
	[Stake_Real]	MONEY NULL,
	[WinLost_Real]	MONEY NULL,
	[Stake_VAR]		MONEY NULL,
	[WinLost_VAR]	MONEY NULL,
	[Comm_VAR]		MONEY NULL;

ALTER TABLE [dbo].OSSummaryByTrader_Daily ADD	
	[Is8RM]			BIT NULL,
	[Stake_Real]	MONEY NULL,
	[WinLost_Real]	MONEY NULL,
	[Stake_VAR]		MONEY NULL,
	[WinLost_VAR]	MONEY NULL,
	[Comm_VAR]		MONEY NULL;

ALTER TABLE [dbo].OSSummaryByLeague_Monthly ADD	
	[Is8RM]			BIT NULL,
	[Stake_Real]	MONEY NULL,
	[WinLost_Real]	MONEY NULL,
	[Stake_VAR]		MONEY NULL,
	[WinLost_VAR]	MONEY NULL,
	[Comm_VAR]		MONEY NULL;
	
ALTER TABLE [dbo].OSSummaryByTrader_Monthly ADD	
	[Is8RM]			BIT NULL,
	[Stake_Real]	MONEY NULL,
	[WinLost_Real]	MONEY NULL,
	[Stake_VAR]		MONEY NULL,
	[WinLost_VAR]	MONEY NULL,
	[Comm_VAR]		MONEY NULL;

GO
