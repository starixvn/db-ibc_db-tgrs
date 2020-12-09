/*
Creator: 20201124@John.Ngo
Task: [OS] Market Count [Redmine ID: 145990]
Server:  DB06.bodb_TGRS_UAT & DB061.bodb_TGRS

Reviewer: Partrick
*/ 

--USE	bodb_TGRS;
--GO
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
SET NOCOUNT ON;

----===================B. CREATE TABLES========================
----===========================================================
CREATE TABLE [dbo].[OSMarket](
		[SportId]			INT				NOT NULL
	,	[MarketId]			INT IDENTITY(0,1)
	,	[MarketName]		NVARCHAR(200)	NULL
	,	[CreatedBy]			INT				NULL
	,	[CreatedDate]		DATETIME		NULL,
CONSTRAINT [PK_OSMarket] PRIMARY KEY CLUSTERED 
(	
		[SportId]			ASC
	,	[MarketId]			ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [DATA]
) ON [DATA]
GO

CREATE TABLE [dbo].[OSMarketMapping](
		SportId				INT			NOT NULL
	,	LeagueNameMarket	VARCHAR(200) NULL
	,	BetTypeId			INT			NULL
	,	MarketId			INT			NULL
	,	CreatedBy			INT			NULL
	,	CreatedDate			DATETIME	NULL
	) ON [DATA];

CREATE CLUSTERED INDEX	CIX_OSMarketMapping_SportIdBettypeId ON [dbo].[OSMarketMapping] (
		SportId				ASC
	,	BetTypeId			ASC
)ON [DATA];
GO

CREATE TABLE [dbo].[OSSummaryMarket](
	[MatchId]			INT			NOT NULL,
	[EventDate]			DATE		NOT NULL,
	[SportId]			SMALLINT	NOT NULL,
	[LeagueId]			INT			NULL,
	[HomeId]			INT			NULL,
	[AwayId]			INT			NULL,
	[BettypeId]			SMALLINT	NULL,
	[MarketId]			INT			NULL,
	[BetCount]			INT			NULL,
	[IsLive]			BIT			NULL
) ON [DATA]

CREATE CLUSTERED INDEX [CIX_OSSummaryMarket_EventDate] ON [dbo].[OSSummaryMarket]
(
	[EventDate]		ASC
) ON [DATA]

CREATE NONCLUSTERED INDEX [IX_OSSummaryMarketIdx] ON [dbo].[OSSummaryMarket]
(
	[SportId]		ASC,
	[LeagueId]		ASC,
	[MatchId]		ASC,
	[BettypeId]		ASC,
	[MarketId]		ASC
) ON [DATA]
GO

GO
/*<info serverAlias="DBTGRS-bodb_TGRS"></info>*/