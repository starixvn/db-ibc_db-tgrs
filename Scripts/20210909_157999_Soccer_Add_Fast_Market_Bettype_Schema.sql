/*
	Creator:	20210916@John.Ngo
	Task:		Add Fast Market Bettype - [Redmine: #157999]
	DB:			DB06.bodb_TGRS_UAT & DB061.bodb_TGRS
*/

USE [bodb_TGRS]
GO

CREATE TABLE [dbo].[TraderPerformance_FastMarketBetChoice](
	[CustId]		INT NOT NULL,
	[MatchId]		INT NOT NULL,
	[LeagueId]		INT NULL,
	[EventDate]		DATE NOT NULL,
	[SportType]		SMALLINT NOT NULL,
	[BetType]		SMALLINT NOT NULL,
	[IsLive]		BIT NOT NULL,
	[Is8RM]			BIT DEFAULT ((0)) NOT NULL,
	[hdp1]			SMALLMONEY NULL,
	[hdp2]			SMALLMONEY NULL,
	[betteam]		NVARCHAR(10) NOT NULL,
	[oddsspread]	MONEY NULL,
	[Stake]			MONEY NULL,
	[WinLost]		MONEY NULL,
	[Comm]			MONEY NULL,
	[BetCount]		INT	NULL,
	[Stake_AR]		MONEY NULL,
	[WinLost_AR]	MONEY NULL,
	[Comm_AR]		MONEY NULL,
	[Stake_Real]	MONEY NULL,
	[WinLost_Real]	MONEY NULL,
	[Stake_VAR]		MONEY NULL,
	[WinLost_VAR]	MONEY NULL
) ON [DATA]

GO
CREATE CLUSTERED INDEX [CIX_TraderPerformance_FastMarketBetChoice_EventDateBettype] ON [dbo].[TraderPerformance_FastMarketBetChoice]
(
	[EventDate] ASC,
	[BetType]	ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [DATA]

CREATE NONCLUSTERED INDEX [IX_TraderPerformance_FastMarketBetChoice_LeagueId] ON [dbo].[TraderPerformance_FastMarketBetChoice]
(
	[LeagueId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [DATA]
GO

CREATE TABLE [dbo].[BetChoice_FastMarketMapping](
	[BetType]		SMALLINT NOT NULL,
	[hdp1]			SMALLMONEY NULL,
	[hdp2]			SMALLMONEY NULL,	
	[betteam]		SMALLMONEY NULL,
	[BetOption]		NVARCHAR(100) NULL,
	[Interval]		NVARCHAR(100) NULL
)

CREATE CLUSTERED INDEX [CIX_BetChoice_FastMarketMapping_BetType] ON [dbo].[BetChoice_FastMarketMapping]
(
	[BetType]	ASC	
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [DATA]
GO

/*<info serverAlias="DBTGRS-bodb_TGRS" executers="bodbTGRSNet" isFunction="0" isNested="0"></info>*/
