/*
Creator: 20200811@John.Ngo
Task:  Support Basketball Dashboard [Redmine ID: 138645]
Server:  bodb_TGRS

Reviewer: Partrick
*/ 

--USE	bodb_TGRS;
--GO
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
SET NOCOUNT ON;

USE [bodb02]
GO
GRANT SELECT ON [dbo].[LeagueGroup] TO [bodbTGRSNet]
GO

GO
/*<info serverAlias="DBTGRS-bodb_TGRS"></info>*/