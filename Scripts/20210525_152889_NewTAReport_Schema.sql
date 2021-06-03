/*
Creator: 20200714@John.Ngo
Task:  Init Data for Re-arrange bet type filter with parent-child [Redmine ID: 137273]
Server:  DB06.bodb_TGRS_UAT & DB061.bodb_TGRS

Reviewer: Partrick
*/ 

--USE	bodb_TGRS;
--GO
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
SET NOCOUNT ON;

CREATE TABLE [dbo].[TAPlatform_History](
	HistoryID	BIGINT IDENTITY(1,1) PRIMARY KEY,
	IsLess8 [bit] DEFAULT 1,
	IsMonitoringLeague [bit] DEFAULT 0,
	Platform [varchar](50),
	FromDate DATE,
	ToDate DATE,
	IsLeagueGroup [bit] DEFAULT 1,
	LeagueGroupID [int] DEFAULT -1,
	Event [varchar](200),
	LeagueID [int] DEFAULT -1,
	MatchCount [bigint] NULL,

	VarianceTO [money] NULL,
	VarianceWL [money] NULL,
	VarianceHDPTO [money] NULL,
	VarianceHDPWL [money] NULL,
	VarianceOUTO [money] NULL,
	VarianceOUWL [money] NULL,
	Variance1HHDPTO [money] NULL,
	Variance1HHDPWL [money] NULL,
	Variance1HOUTO [money] NULL,
	Variance1HOUWL [money] NULL,

	VirtualTO [money] NULL,
	VirtualWL [money] NULL,
	VirtualHDPTO [money] NULL,
	VirtualHDPWL [money] NULL,
	VirtualOUTO [money] NULL,
	VirtualOUWL [money] NULL,
	Virtual1HHDPTO [money] NULL,
	Virtual1HHDPWL [money] NULL,
	Virtual1HOUTO [money] NULL,
	Virtual1HOUWL [money] NULL,

	RealEx8RMTO [money] NULL,
	RealEx8RMWL [money] NULL,
	RealEx8RMHDPTO [money] NULL,
	RealEx8RMHDPWL [money] NULL,
	RealEx8RMOUTO [money] NULL,
	RealEx8RMOUWL [money] NULL,
	RealEx8RM1HHDPTO [money] NULL,
	RealEx8RM1HHDPWL [money] NULL,
	RealEx8RM1HOUTO [money] NULL,
	RealEx8RM1HOUWL [money] NULL,

	BetCount BIGINT NULL
) ON [TraderPerformanceDetail_Table]
GO

CREATE NONCLUSTERED INDEX [IX_TAPlatform_History] ON [dbo].[TAPlatform_History]
	(
		IsLess8 ASC,
		IsMonitoringLeague ASC,
		Platform DESC
	);

GO
