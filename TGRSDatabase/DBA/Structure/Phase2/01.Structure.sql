USE [bodb_TGRS]
GO

-------------------------------
-- RENAME MANUALLY
-----1. TABLE [dbo].[SummaryByBetType_Daily] TO SummaryByBetType_Daily_BK
-----2. TABLE [dbo].[SummaryByBetType_Monthly] TO SummaryByBetType_Monthly_BK
-----3. TABLE [dbo].[SummaryByLeague_Daily] TO SummaryByLeague_Daily_BK
-----4. TABLE [dbo].[SummaryByLeague_Monthly] TO SummaryByLeague_Monthly_BK
-----5. TABLE [dbo].[SummaryByTeam_Daily] TO SummaryByTeam_Daily_BK
-----6. TABLE [dbo].[SummaryByTeam_Monthly] TO SummaryByTeam_Monthly_BK
-----7. TABLE [dbo].[SummaryByTrader_Monthly] TO SummaryByTrader_Monthly_BK
 
 
 --------------------------------

/****** Object:  Table [dbo].[SummaryByBetType_Daily]    Script Date: 11/28/2014 10:55:35 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [dbo].[SummaryByBetType_Daily](
	[EventDate] [date] NULL,
	[LeagueId] [int] NULL,
	[WorkShift] [tinyint] NULL,
	[BetType] [smallint] NULL,
	[Stake] [money] NULL,
	[WinLost] [money] NULL,
	[Comm] [money] NULL,
	[BetCount] [int] NULL,
	[MatchCount] [int] NULL
) ON [TraderPerformanceSummary_Table]

GO

/****** Object:  Index [CIX_EventDate]    Script Date: 11/28/2014 10:55:53 AM ******/
CREATE UNIQUE CLUSTERED INDEX [CIX_EventDate] ON [dbo].[SummaryByBetType_Daily]
(
	[EventDate] ASC,
	[LeagueId] ASC,
	[BetType] ASC,
	[WorkShift] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [TraderPerformanceSummary_Table]
GO

 --------------------------------


/****** Object:  Table [dbo].[SummaryByBetType_Monthly]    Script Date: 11/28/2014 10:56:35 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [dbo].[SummaryByBetType_Monthly](
	[EventDate] [date] NULL,
	[LeagueId] [int] NULL,
	[WorkShift] [tinyint] NULL,
	[BetType] [smallint] NULL,
	[Stake] [money] NULL,
	[WinLost] [money] NULL,
	[Comm] [money] NULL,
	[BetCount] [int] NULL,
	[MatchCount] [int] NULL
) ON [TraderPerformanceSummary_Table]

GO
 

/****** Object:  Index [CIX_EventDate]    Script Date: 11/28/2014 10:56:43 AM ******/
CREATE UNIQUE CLUSTERED INDEX [CIX_EventDate] ON [dbo].[SummaryByBetType_Monthly]
(
	[EventDate] ASC,
	[LeagueId] ASC,
	[BetType] ASC,
	[WorkShift] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [TraderPerformanceSummary_Table]
GO

----------------------------------


/****** Object:  Table [dbo].[SummaryByLeague_Daily]    Script Date: 11/28/2014 10:57:39 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [dbo].[SummaryByLeague_Daily](
	[EventDate] [date] NULL,
	[LeagueId] [int] NULL,
	[WorkShift] [tinyint] NULL,
	[Stake] [money] NULL,
	[WinLost] [money] NULL,
	[Comm] [money] NULL,
	[BetCount] [int] NULL,
	[MatchCount] [int] NULL
) ON [TraderPerformanceSummary_Table]

GO



/****** Object:  Index [CIX_EventDate]    Script Date: 11/28/2014 10:57:52 AM ******/
CREATE UNIQUE CLUSTERED INDEX [CIX_EventDate] ON [dbo].[SummaryByLeague_Daily]
(
	[EventDate] ASC,
	[LeagueId] ASC,
	[WorkShift] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [TraderPerformanceSummary_Table]
GO


---------------


/****** Object:  Table [dbo].[SummaryByLeague_Monthly]    Script Date: 11/28/2014 10:58:13 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [dbo].[SummaryByLeague_Monthly](
	[EventDate] [date] NULL,
	[LeagueId] [int] NULL,
	[WorkShift] [tinyint] NULL,
	[Stake] [money] NULL,
	[WinLost] [money] NULL,
	[Comm] [money] NULL,
	[BetCount] [int] NULL,
	[MatchCount] [int] NULL
) ON [TraderPerformanceSummary_Table]

GO


CREATE UNIQUE CLUSTERED INDEX [CIX_EventDate] ON [dbo].[SummaryByLeague_Monthly]
(
	[EventDate] ASC,
	[LeagueId] ASC,
	[WorkShift] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [TraderPerformanceSummary_Table]
GO


-------------------------


/****** Object:  Table [dbo].[SummaryByTeam_Daily]    Script Date: 11/28/2014 10:59:42 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [dbo].[SummaryByTeam_Daily](
	[EventDate] [date] NULL,
	[TeamId] [smallint] NULL,
	[WorkShift] [tinyint] NULL,
	[Stake] [money] NULL,
	[WinLost] [money] NULL,
	[Comm] [money] NULL,
	[BetCount] [int] NULL,
	[MatchCount] [int] NULL
) ON [TraderPerformanceSummary_Table]

GO



/****** Object:  Index [CIX_EventDate]    Script Date: 11/28/2014 10:59:54 AM ******/
CREATE UNIQUE CLUSTERED INDEX [CIX_EventDate] ON [dbo].[SummaryByTeam_Daily]
(
	[EventDate] ASC,
	[TeamId] ASC,
	[WorkShift] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [TraderPerformanceSummary_Table]
GO


-------------------------


/****** Object:  Table [dbo].[SummaryByTeam_Monthly]    Script Date: 11/28/2014 11:00:19 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [dbo].[SummaryByTeam_Monthly](
	[EventDate] [date] NULL,
	[TeamId] [int] NULL,
	[WorkShift] [tinyint] NULL,
	[Stake] [money] NULL,
	[WinLost] [money] NULL,
	[Comm] [money] NULL,
	[BetCount] [int] NULL,
	[MatchCount] [int] NULL
) ON [TraderPerformanceSummary_Table]

GO


GO

/****** Object:  Index [CIX_EventDate]    Script Date: 11/28/2014 11:00:30 AM ******/
CREATE UNIQUE CLUSTERED INDEX [CIX_EventDate] ON [dbo].[SummaryByTeam_Monthly]
(
	[EventDate] ASC,
	[TeamId] ASC,
	[WorkShift] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [TraderPerformanceSummary_Table]
GO


--------------------------



/****** Object:  Table [dbo].[SummaryByTrader_Monthly]    Script Date: 11/28/2014 11:00:48 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [dbo].[SummaryByTrader_Monthly](
	[Eventdate] [date] NULL,
	[CustId] [int] NULL,
	[WorkShift] [tinyint] NULL,
	[Stake] [money] NULL,
	[WinLost] [money] NULL,
	[Comm] [money] NULL,
	[BetCount] [int] NULL,
	[MatchCount] [int] NULL
) ON [TraderPerformanceSummary_Table]

GO



/****** Object:  Index [CIX_EventDate]    Script Date: 11/28/2014 11:01:10 AM ******/
CREATE UNIQUE CLUSTERED INDEX [CIX_EventDate] ON [dbo].[SummaryByTrader_Monthly]
(
	[Eventdate] ASC,
	[CustId] ASC,
	[WorkShift] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [TraderPerformanceSummary_Table]
GO


---------------- 
CREATE TABLE Benchmark_BetType_History	
(   LeagueId	Int,
	BetType	Smallint,
	Benchmark Money,
	WorkShift Tinyint,
	ModifiedDate	Date,
	ModifiedBy	Int
	
) ON [DATA]

GO

ALTER TABLE [dbo].[Benchmark_BetType_History] ADD  CONSTRAINT [DF_Benchmark_BetType_History_ModifiedDate]  DEFAULT (getdate()) FOR [ModifiedDate]
GO


/****** Object:  Index [IX_ModifiedDate_Bettype]    Script Date: 12/25/2014 4:18:09 PM ******/
CREATE NONCLUSTERED INDEX [IX_ModifiedDate_Bettype] ON [dbo].[Benchmark_BetType_History]
(
	[ModifiedDate] ASC,
	[BetType] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [DATA]
GO


/****** Object:  Index [CIX_LeagueId]    Script Date: 12/25/2014 4:18:14 PM ******/
CREATE UNIQUE CLUSTERED INDEX [CIX_LeagueId] ON [dbo].[Benchmark_BetType_History]
(
	[LeagueId] ASC,
	[BetType] ASC,
	[WorkShift] ASC,
	[ModifiedDate] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [DATA]
GO




----------------		

 
 
CREATE TABLE [dbo].[SystemSettings](
	[VID] [int] IDENTITY(1,1) NOT NULL,
	[VName] [varchar](50) NOT NULL,
	[VValue] [varchar](200) NULL,
 CONSTRAINT [PK_SystemSettings] PRIMARY KEY CLUSTERED 
(
	[VName] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [DATA]
) ON [DATA]

----------------------------------


ALTER TABLE [dbo].[Staging_TraderPerformance]
ADD WorkShift TINYINT
GO 


ALTER TABLE [dbo].[TraderPerformance]
ADD WorkShift TINYINT
GO 


ALTER TABLE [dbo].[TraderPerformance_BK]
ADD WorkShift TINYINT
GO 


ALTER TABLE [dbo].[Benchmark_BetType]
ADD WorkShift TINYINT
GO 


/****** Object:  Index [CIX_LeagueId_BetType]    Script Date: 12/3/2014 4:20:24 PM ******/
DROP INDEX [CIX_LeagueId_BetType] ON [dbo].[Benchmark_BetType] WITH ( ONLINE = OFF )
GO


/****** Object:  Index [CIX_LeagueId_BetType]    Script Date: 12/3/2014 4:20:24 PM ******/
CREATE UNIQUE CLUSTERED INDEX [CIX_LeagueId] ON [dbo].[Benchmark_BetType]
(
	[LeagueId] ASC,
	[BetType] ASC,
	[WorkShift] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [DATA]
GO

------------------------------------------

ALTER TABLE [dbo].[BetType]
ADD IsDefault BIT 
ALTER TABLE [dbo].[BetType] ADD  CONSTRAINT [DF_BetType_IsDefault]  DEFAULT (0) FOR IsDefault
GO
  