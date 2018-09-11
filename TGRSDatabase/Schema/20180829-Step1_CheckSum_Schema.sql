/*
	Creator:	20180829@Casey
	Task:		[Soccer] - Implement a feature to monitor data between NAP vs TGR - [Redmine: #89493]
	Server:		DB06.bodb_TGRS & DBTP.bodb_TGRS_UAT
*/

	CREATE TABLE [dbo].[TrackChangedMatch](
	[MatchId] [int] NOT NULL,
	[EventDate] [date] NOT NULL,
	[SportType] [smallint] NOT NULL,
	[BetType] [smallint] NOT NULL,
	[OldCapturedDate] [datetime] NULL,
	[OldTraderID] [int] NULL,
	[OldTurnOver] [money] NULL,
	[OldWinLost] [money] NULL,
	[OldBetCount] [int] NULL,
	[NewCapturedDate] [datetime] NULL,
	[NewTraderID] [int] NULL,
	[NewTurnOver] [money] NULL,
	[NewWinLost] [money] NULL,
	[NewBetCount] [int] NULL,
	[IsNotified] [int] NULL,
	) ON [DATA]
	
	CREATE CLUSTERED INDEX	CIX_TrackChangedMatch_MatchIdSportBettype ON TrackChangedMatch(
		MatchId		ASC
		, Bettype	ASC
	)ON [DATA];
	
	CREATE NONCLUSTERED INDEX	NIX_TrackChangedMatch_EventDate ON TrackChangedMatch(
		EventDate ASC
	)ON [DATA];
	
	CREATE NONCLUSTERED INDEX	NIX_TrackChangedMatch_OldCapturedDate ON TrackChangedMatch(
		OldCapturedDate ASC
	)ON [DATA];
	
	CREATE NONCLUSTERED INDEX	NIX_TrackChangedMatch_NewCapturedDate ON TrackChangedMatch(
		NewCapturedDate ASC
	)ON [DATA];
GO

CREATE TABLE [dbo].[TrackChangesOnMatches_Queue](
	[MatchId] [int] NOT NULL,
	[EventDate] [date] NOT NULL,
	[SportType] [smallint] NOT NULL,
	[BetType] [smallint] NOT NULL,
	[OldCapturedDate] [datetime] NULL,
	[OldTraderID] [int] NULL,
	[OldTurnOver] [money] NULL,
	[OldWinLost] [money] NULL,
	[OldBetCount] [int] NULL,
	) ON [DATA]
	
	CREATE CLUSTERED INDEX	CIX_TrackChangesOnMatches_Queue_MatchIdSportBettype ON TrackChangesOnMatches_Queue(
		MatchId		ASC
		, Bettype	ASC
	)ON [DATA];
	
	CREATE NONCLUSTERED INDEX	NIX_TrackChangesOnMatches_Queue_EventDate ON TrackChangesOnMatches_Queue(
		EventDate ASC
	)ON [DATA];
	
	CREATE NONCLUSTERED INDEX	NIX_TrackChangesOnMatches_Queue_OldCapturedDate ON TrackChangesOnMatches_Queue(
		OldCapturedDate ASC
	)ON [DATA];

GO
	CREATE TABLE	TracePerformanceScannedMatches (
			MatchId			INT NOT NULL
			, EventDate		DATETIME
			, KickOffTime	DATETIME
			, WorkShift		TINYINT
			, MatchCode		NVARCHAR(50)			
			, LeagueId		INT			
			, SportType		INT
			, HomeId		INT
			, AwayId		INT
			, LeagueName	NVARCHAR(100)
			, HomeName		NVARCHAR(100)
			, SpecialType	INT
			, fromSP		BIT	--1 Daily, 0 RealTime
			, CapturedDate		DATETIME		
	)ON [DATA];
	
	CREATE CLUSTERED INDEX	CIX_TracePerformanceScannedMatches_MatchId ON TracePerformanceScannedMatches(
		MatchId		ASC
	)ON [DATA];
	
	CREATE NONCLUSTERED INDEX NIX_TracePerformanceScannedMatches_EventDate ON TracePerformanceScannedMatches (
		EventDate	ASC
	)ON [DATA];
	
	CREATE NONCLUSTERED INDEX NIX_TracePerformanceScannedMatches_CapturedDate ON TracePerformanceScannedMatches (
		CapturedDate	ASC
	)ON [DATA];
GO
	CREATE TABLE	TraceScannedMatchesInfo (
			MatchId			INT NOT NULL
			, EventDate		DATETIME NOT NULL
			, Bettype		INT NOT NULL
			, LiveIndicator	BIT	NULL
			, BetCount INT NULL
			, SumStake MONEY NULL
			, SumVirtualRate FLOAT NULL
			, SumModds SMALLMONEY NULL
			, SumWinlost MONEY NULL
			, SumComm MONEY NULL
			, SumActualStake MONEY NULL
			, fromSP		BIT	--1 Daily, 0 RealTime
			, CapturedDate		DATETIME		
	);
	
	CREATE CLUSTERED INDEX	CIX_TraceScannedMatchesInfo_MatchId ON TraceScannedMatchesInfo(
		MatchId		ASC
		,Bettype		ASC
	)ON [DATA];
	
	CREATE NONCLUSTERED INDEX NIX_TraceScannedMatchesInfo_EventDate ON TraceScannedMatchesInfo (
		EventDate	ASC
	)ON [DATA];
	
	CREATE NONCLUSTERED INDEX NIX_TraceScannedMatchesInfo_CapturedDate ON TraceScannedMatchesInfo (
		CapturedDate	ASC
	)ON [DATA];
GO	
	CREATE TABLE TracePerformanceTrader (
			CustId				INT
		,	LeagueId			INT
		,	MatchId				INT
		,	EventDate			DATETIME
		,	Bettype				INT
		,	TraderBettype		INT
		,	OperatorType		INT
		,	MainDBBetType		INT
		,	TeamId				INT
		,	Grade				TINYINT
		,	fromSP				BIT	--1 Daily, 0 RealTime
		,	CapturedDate		DATETIME	
	)ON [DATA];

	CREATE CLUSTERED INDEX	 CIX_TracePerformanceTrader_CustIdMatchIdBettype ON TracePerformanceTrader (
			MatchId				ASC
		,	BetType				ASC
		,	CustId				ASC
	)ON [DATA];
	
	CREATE NONCLUSTERED INDEX NIX_TracePerformanceTrader_EventDate ON TracePerformanceTrader (
		EventDate	ASC
	)ON [DATA];

	CREATE NONCLUSTERED INDEX NIX_TracePerformanceTrader_CapturedDate ON TraceScannedMatchesInfo (
		CapturedDate	ASC
	)ON [DATA];