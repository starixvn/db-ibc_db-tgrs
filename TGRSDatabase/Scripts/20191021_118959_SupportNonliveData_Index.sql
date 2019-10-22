/*
	Creator:	20191021@Long.Luu
	Task:		Support Non-live Data - [Redmine: #118959]
	Server:		DB06.bodb_TGRS
*/

USE bodb_TGRS

CREATE NONCLUSTERED INDEX IX_TraderPerformance_EventDate_IsLive ON [dbo].TraderPerformance (
	EventDate				ASC,
	[IsLive]				ASC
)
GO













