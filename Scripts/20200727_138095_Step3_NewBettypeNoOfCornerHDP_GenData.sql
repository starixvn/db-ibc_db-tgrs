/*
Creator:	20200727@John.Ngo
Task:		New Negative Bettype No Of Corner HDP [Redmine ID: 138095]
Server:		bodb_TGRS

Reviewer:	Partrick
*/

--USE [bodb_TGRS]
--GO
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
SET NOCOUNT ON;

GO
EXECUTE Task_RegenerateTGRSData  @Debug = 1, @FromDate = '20190101' , @ToDate = '20200726' , @Flagged = 0
GO

GO
/*<info serverAlias="DBTGRS-bodb_TGRS"></info>*/