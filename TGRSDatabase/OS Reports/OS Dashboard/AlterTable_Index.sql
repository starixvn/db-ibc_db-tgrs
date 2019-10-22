
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- Table [OSDataTGRS]
CREATE TABLE [dbo].[OSDataTGRS](
	[TraderId] [int] NOT NULL,
	[SportId] [int] NOT NULL,
	[LeagueId] [int] NOT NULL,
	[BettypeId] [smallint] NOT NULL,
	[EventDate] [date] NOT NULL,
	[Turnover] [money] NOT NULL,
	[Winloss] [money] NOT NULL,
	[Comm] [money] NOT NULL,
	[BetCount] [int] NOT NULL,
	[Target] [decimal](18, 2) NOT NULL,
	[MatchId] [int] NOT NULL,
	[MatchCode] [nvarchar](100) NULL
) ON [PRIMARY]

GO

CREATE NONCLUSTERED INDEX [IX_EventDate] ON [dbo].[OSDataTGRS]
(
	[EventDate] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
GO

CREATE NONCLUSTERED INDEX [IX_Trader_SportId_LeagueId_BettypeId_MatchId] ON [dbo].[OSDataTGRS]
(
	[TraderId] ASC,
	[SportId] ASC,
	[LeagueId] ASC,
	[BettypeId] ASC,
	[MatchId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
GO
-- Table [OSStagingDataTGRS]
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- Table [OSDataTGRS]
CREATE TABLE [dbo].[OSStagingDataTGRS](
	[TraderId] [int] NOT NULL,
	[SportId] [int] NOT NULL,
	[LeagueId] [int] NOT NULL,
	[BettypeId] [smallint] NOT NULL,
	[EventDate] [date] NOT NULL,
	[Turnover] [money] NOT NULL,
	[Winloss] [money] NOT NULL,
	[Comm] [money] NOT NULL,
	[BetCount] [int] NOT NULL,
	[Target] [decimal](18, 2) NOT NULL,
	[MatchId] [int] NOT NULL,
	[MatchCode] [nvarchar](100) NULL
) ON [PRIMARY]

GO

CREATE NONCLUSTERED INDEX [IX_EventDate] ON [dbo].[OSStagingDataTGRS]
(
	[EventDate] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
GO

CREATE NONCLUSTERED INDEX [IX_Trader_SportId_LeagueId_BettypeId_MatchId] ON [dbo].[OSStagingDataTGRS]
(
	[TraderId] ASC,
	[SportId] ASC,
	[LeagueId] ASC,
	[BettypeId] ASC,
	[MatchId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
GO

-- Table [OSSummaryByLeague_Monthly]
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[OSSummaryByLeague_Monthly](
	[EventDate] [date] NOT NULL,
	[SportId] [int] NOT NULL,
	[LeagueId] [int] NOT NULL,
	[Turnover] [money] NOT NULL,
	[Winloss] [money] NOT NULL,
	[Comm] [money] NOT NULL,
	[BetCount] [int] NOT NULL,
	[Target] [decimal](18, 2) NOT NULL,
	[MatchCount] [int] NOT NULL
) ON [PRIMARY]

GO

CREATE NONCLUSTERED INDEX [IX_EventDate] ON [dbo].[OSSummaryByLeague_Monthly]
(
	[EventDate] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
GO

CREATE NONCLUSTERED INDEX [IX_SportId_LeagueId] ON [dbo].[OSSummaryByLeague_Monthly]
(
	[SportId] ASC,
	[LeagueId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
GO

-- Table [OSSummaryByTrader_Daily]
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[OSSummaryByTrader_Daily](
	[TraderId] [int] NOT NULL,
	[SportId] [int] NOT NULL,
	[LeagueId] [int] NOT NULL,
	[BettypeId] [smallint] NOT NULL,
	[EventDate] [date] NOT NULL,
	[Turnover] [money] NOT NULL,
	[Winloss] [money] NOT NULL,
	[Comm] [money] NOT NULL,
	[BetCount] [int] NOT NULL,
	[MatchCount] [int] NOT NULL,
	[Target] [decimal](18, 2) NOT NULL
) ON [PRIMARY]

GO

CREATE NONCLUSTERED INDEX [IX_EventDate] ON [dbo].[OSSummaryByTrader_Daily]
(
	[EventDate] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
GO

CREATE NONCLUSTERED INDEX [IX_Trader_SportId_LeagueId_BettypeId] ON [dbo].[OSSummaryByTrader_Daily]
(
	[TraderId] ASC,
	[SportId] ASC,
	[LeagueId] ASC,
	[BettypeId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
GO

-- Table [OSSummaryByTrader_Monthly]
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[OSSummaryByTrader_Monthly](
	[TraderId] [int] NOT NULL,
	[EventDate] [date] NOT NULL,
	[SportId] [int] NOT NULL,
	[LeagueId] [int] NOT NULL,
	[BettypeId] [smallint] NOT NULL,
	[Turnover] [money] NOT NULL,
	[Winloss] [money] NOT NULL,
	[Comm] [money] NOT NULL,
	[BetCount] [int] NOT NULL,
	[MatchCount] [int] NOT NULL,
	[Target] [decimal](18, 2) NOT NULL
) ON [PRIMARY]

GO

CREATE NONCLUSTERED INDEX [IX_EventDate] ON [dbo].[OSSummaryByTrader_Monthly]
(
	[EventDate] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
GO

CREATE NONCLUSTERED INDEX [IX_TraderId_SportId_LeagueId_BettypeId] ON [dbo].[OSSummaryByTrader_Monthly]
(
	[TraderId] ASC,
	[SportId] ASC,
	[LeagueId] ASC,
	[BettypeId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
GO
---------------------------------------------------------------------------------------------------
IF (EXISTS (SELECT * 
                 FROM INFORMATION_SCHEMA.TABLES 
                 WHERE TABLE_NAME = 'OSStagingTraderPerformance'))
BEGIN
    DROP table [dbo].[OSStagingTraderPerformance]
END
--
IF (EXISTS (SELECT * 
                 FROM INFORMATION_SCHEMA.TABLES 
                 WHERE TABLE_NAME = 'OSTraderPerformance'))
BEGIN
    DROP table [dbo].[OSTraderPerformance]
END
--
IF (EXISTS (SELECT * 
                 FROM INFORMATION_SCHEMA.TABLES 
                 WHERE TABLE_NAME = 'OSTraderPerformance_Monthly'))
BEGIN
    DROP table [dbo].[OSTraderPerformance_Monthly]
END
--
IF EXISTS (SELECT * FROM sys.objects WHERE type = 'P' AND name = 'TGRS_OS_Rpt_SummaryData')
DROP PROCEDURE [dbo].[TGRS_OS_Rpt_SummaryData]
GO
