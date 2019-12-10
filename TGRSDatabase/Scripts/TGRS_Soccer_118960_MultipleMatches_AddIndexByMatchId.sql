/*
Creator: 201912115@LongLuu
Task:  Adding Index by MatchId for TraderPerformance table
Server:  bodb_TGRS

Reviewer: Billy
*/ 

----===================A. DROP TABLES=========================
----==========================================================

----===================B. CREATE TABLES========================
----===========================================================

----===================C. ALTER TABLES=========================
----===========================================================

CREATE NONCLUSTERED INDEX IX_TraderPerformance_MatchId ON [dbo].[TraderPerformance] (
	[MatchId]               ASC
)
GO