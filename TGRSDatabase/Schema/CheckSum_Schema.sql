	CREATE TABLE [dbo].[TrackChangedMatch](
	[TrackChangeID] [bigint] IDENTITY(1,1) NOT NULL,
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
	 CONSTRAINT [PK_TrackChangedMatch] PRIMARY KEY CLUSTERED 
	(
		[TrackChangeID] ASC,
		[MatchId] ASC,
		[EventDate] ASC,
		[SportType] ASC,
		[BetType] ASC
	)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [DATA]
	) ON [DATA]

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
 CONSTRAINT [PK_TraceMatch] PRIMARY KEY CLUSTERED 
(
	[MatchId] ASC,
	[EventDate] ASC,
	[SportType] ASC,
	[BetType] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [DATA]
) ON [DATA]

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
		,EventDate		ASC
		,Bettype		ASC
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

	CREATE CLUSTERED INDEX	#CIX_TracePerformanceTraderIdx ON TracePerformanceTrader (
			CustId				ASC
		,	EventDate			ASC
		,	MatchId				ASC
		,	BetType				ASC
	)ON [DATA];

	
	