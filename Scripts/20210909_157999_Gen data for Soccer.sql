/*
	Creator:	20210923@John.Ngo
	Task:		Add Fast Market Bettype - [Redmine: #157999]
	Server:		DB061.bodb_TGRS

	Reviewer:   Brice
*/

USE bodb_TGRS

DECLARE @FDate	DATE = '20210101'
	,	@TDate	DATE = GETDATE();

---- GEN Data

EXECUTE dbo.Task_RegenerateTGRSData @Debug = 1, @FromDate	= @FDate, @ToDate = @TDate,	@Flagged = 1

/*<info serverAlias="DBTGRS-bodb_TGRS" executers="bodbTGRSNet" isFunction="0" isNested="0"></info>*/