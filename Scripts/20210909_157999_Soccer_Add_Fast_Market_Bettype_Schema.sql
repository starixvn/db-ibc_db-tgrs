/*
	Creator:	20210909@Adam.Tran
	Task:		Add Fast Market Bettype - [Redmine: #157999]
	DB:			DB06.bodb_TGRS_UAT & DB061.bodb_TGRS
*/

USE bodb_TGRS

ALTER TABLE [dbo].[TraderPerformance_BetChoice] DROP CONSTRAINT PK_TraderPerformance_BetChoice;

ALTER TABLE [dbo].[TraderPerformance_BetChoice] ADD	
	[hdp1]			SMALLMONEY NULL,
	[hdp2]			SMALLMONEY NULL;
	
DROP INDEX [dbo].[TraderPerformance_BetChoice];

CREATE CLUSTERED INDEX [CIX_TraderPerformance_BetChoice_EventDateBettype] ON [dbo].[TraderPerformance_BetChoice]
(
	[EventDate] ASC,
	[BetType] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [DATA]

CREATE NONCLUSTERED INDEX [IX_TraderPerformance_BetChoice_LeagueId] ON [dbo].[TraderPerformance_BetChoice]
(
	[LeagueId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [DATA]

CREATE TABLE [dbo].[BetChoice_FastMarketMapping](
	[BetType]			SMALLINT NOT NULL,
	[hdp1]				SMALLMONEY NULL,
	[hdp2]				SMALLMONEY NULL,	
	[BetTeam]			SMALLMONEY NULL,
	[BetOption]			NVARCHAR(50) NULL,
	[Interval]			NVARCHAR(50) NULL,
	[oddsspread]		MONEY NULL
)

CREATE CLUSTERED INDEX [CIX_BetChoice_FastMarketMapping_BetType] ON [dbo].[BetChoice_FastMarketMapping]
(
	[BetType]	ASC	
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [DATA]

CREATE NONCLUSTERED INDEX [IX_BetChoice_FastMarketMapping_BetTypehdp1] ON [dbo].[BetChoice_FastMarketMapping]
(
	[BetType]	ASC,
	[hdp1] 		ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [DATA]

CREATE NONCLUSTERED INDEX [IX_BetChoice_FastMarketMapping_BetTypehdp2BetTeam] ON [dbo].[BetChoice_FastMarketMapping]
(
	[BetType]	ASC,
	[hdp2] 		ASC,
	[BetTeam]	ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [DATA]

GO

/*<info serverAlias="DBTGRS-bodb_TGRS" executers="bodbTGRSNet" isFunction="0" isNested="0"></info>*/
