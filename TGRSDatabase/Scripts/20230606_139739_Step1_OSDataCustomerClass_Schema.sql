/*
	Created:	20230606@John.Ngo
	Task :		Staging Data for E-Sports/Basketball trader performance by class [Redmine ID: 187083]
	DB:			DBTGRS.bodb_TGRS

	Reviewer: Sol
*/ 

--USE	bodb_TGRS;
--GO
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
SET NOCOUNT ON;

----===================B. CREATE TABLES========================
----===========================================================
CREATE TABLE [dbo].[OSDataTGRS_CustomerClass] (
		[TraderId]			INT NOT NULL 
   ,	[CustomerClass]		SMALLINT NULL
   ,	[SportId]			INT NOT NULL
   ,	[LeagueId]			INT NOT NULL
   ,	[MatchId]			INT NOT NULL
   ,	[EventDate]			DATE NOT NULL
   ,	[BettypeId]			SMALLINT NOT NULL
   ,	[Turnover]			MONEY NULL
   ,	[Winloss]			MONEY NULL
   ,	[Comm]				MONEY NULL
   ,	[Turnover_AR]		MONEY NULL
   ,	[WinLoss_AR]		MONEY NULL
   ,	[Comm_AR]			MONEY NULL
   ,	[BetCount]			INT NULL
   ,	[IsLive]			BIT NULL
) ON [DATA]

CREATE CLUSTERED INDEX [CIX_OSDataCustomerClass_EventDate] ON [dbo].[OSDataTGRS_CustomerClass] (
		[EventDate]			ASC
) ON [DATA]

CREATE NONCLUSTERED INDEX [IX_OSDataCustomerClass_TraderIdIdx] ON [dbo].[OSDataTGRS_CustomerClass] (
		[TraderId]			ASC,
		[SportId]			ASC,
		[LeagueId]			ASC,
		[MatchId]			ASC,
		[BettypeId]			ASC
) ON [DATA];

GO
/*<info serverAlias="DBTGRS-bodb_TGRS"></info>*/