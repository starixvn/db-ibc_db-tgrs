/*
	Creator:	20211116@John.Ngo
	Task:		[TGR Soccer] Support generate data for Real Performance - [Redmine: #164695]
	Server:		DB061.bodb_TGRS

	Reviewer:   Brice
*/

USE bodb_TGRS

DECLARE @FDate	DATE = '20200101'
	,	@TDate	DATE = '20201231';

---- GEN Data

EXECUTE dbo.Task_RegenerateTGRSData @Debug = 1, @FromDate	= @FDate, @ToDate = @TDate,	@Flagged = 1

/*<info serverAlias="DBTGRS-bodb_TGRS" executers="bodbTGRSNet" isFunction="0" isNested="0"></info>*/