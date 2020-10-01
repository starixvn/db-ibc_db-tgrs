/*
	Creator: 20200909@John.Ngo
	Task: Support Live/Nonlive, Betchoice for OSData [Redmine ID: #140875]
	DB: DB06.bodb_TGRS_UAT & DB061.bodb_TGRS

	Reviewer: Partrick
*/

GO

ALTER TABLE [dbo].[OSBettype]
ADD	[GroupBettypeId] TINYINT NULL;

ALTER TABLE [dbo].[OSDataTGRS]
ADD	  Turnover_AR	MONEY NULL
	, WinLoss_AR	MONEY NULL
	, Comm_AR		MONEY NULL
	, StakeMYR_AR	MONEY NULL
	, Juice_AR		MONEY NULL
	, StakeMYRJuice_AR MONEY NULL
	, [IsLive]		BIT NULL


ALTER TABLE [dbo].[OSSummaryByLeague_Monthly]
ADD	  Turnover_AR	MONEY NULL
	, WinLoss_AR	MONEY NULL
	, Comm_AR		MONEY NULL
	, StakeMYR_AR	MONEY NULL
	, Juice_AR		MONEY NULL
	, StakeMYRJuice_AR MONEY NULL
	, [IsLive]		BIT NULL;

ALTER TABLE [dbo].[OSSummaryByTrader_Daily]
ADD	  Turnover_AR	MONEY NULL
	, WinLoss_AR	MONEY NULL
	, Comm_AR		MONEY NULL
	, StakeMYR_AR	MONEY NULL
	, Juice_AR		MONEY NULL
	, StakeMYRJuice_AR MONEY NULL
	, [IsLive]		BIT NULL;

ALTER TABLE [dbo].[OSSummaryByTrader_Monthly]
ADD	  Turnover_AR	MONEY NULL
	, WinLoss_AR	MONEY NULL
	, Comm_AR		MONEY NULL
	, StakeMYR_AR	MONEY NULL
	, Juice_AR		MONEY NULL
	, StakeMYRJuice_AR MONEY NULL
	, [IsLive]		BIT NULL;

CREATE TABLE [dbo].[OSDataTGRS_BetChoice](
	[TraderId]			INT NOT NULL,
	[SportId]			INT NOT NULL,
	[LeagueId]			INT NULL,
	[MatchId]			INT NOT NULL,
	[EventDate]			DATE NOT NULL,
	[BettypeId]			SMALLINT NOT NULL,
	[BetChoice]			NVARCHAR(10) NOT NULL,
	[Turnover]			MONEY NULL,
	[WinLoss]			MONEY NULL,
	[Comm]				MONEY NULL,
	[Turnover_AR]		MONEY NULL,
	[WinLoss_AR]		MONEY NULL,
	[Comm_AR]			MONEY NULL,
	[BetCount]			INT NULL,
	[IsLive]			BIT NOT NULL
) ON [DATA]
GO

CREATE CLUSTERED INDEX [CIX_OSDataTGRS_BetChoice_EventDate] ON [dbo].[OSDataTGRS_BetChoice]
(
	[EventDate]		ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [DATA]
GO

CREATE NONCLUSTERED INDEX [IX_OSDataTGRS_BetChoiceIdx] ON [dbo].[OSDataTGRS_BetChoice]
(
	[TraderId]		ASC,
	[SportId]		ASC,
	[LeagueId]		ASC,
	[MatchId]		ASC,
	[BettypeId]		ASC,
	[IsLive]		ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [DATA]
GO
