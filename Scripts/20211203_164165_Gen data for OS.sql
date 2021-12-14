/*
	Creator:	20211203@Adam.Tran
	Task:		Basketball - View report to Set X Game Y - [Redmine: #164165]
	Server:		DB06.bodb_TGRS		
	Reviewer:   Brice
*/

USE bodb_TGRS

DECLARE @FDate	DATE = '20210101'
	,	@TDate	DATE = GETDATE();

---- GEN Data

EXECUTE dbo.Task_RegenerateTGRSData @Debug = 1, @FromDate	= @FDate, @ToDate = @TDate,	@Flagged = 2

/*<info serverAlias="DBTGRS-bodb_TGRS" executers="bodbTGRSNet" isFunction="0" isNested="0"></info>*/