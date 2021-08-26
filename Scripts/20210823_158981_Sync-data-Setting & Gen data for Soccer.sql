/*
	Creator:	20210823@John.Ngo
	Task:		Sports - Performance Real Figures - [Redmine: #158981]
	Server:		DB06.bodb_TGRS_UAT & DB061.bodb_TGRS

	Reviewer:   Brice
*/

USE bodb_TGRS_UAT

DECLARE @FDate	DATE = '20210601'
	,	@TDate	DATE = GETDATE();

---- GEN Data

EXECUTE dbo.Task_RegenerateTGRSData @Debug = 1, @FromDate	= @FDate, @ToDate = @TDate,	@Flagged = 1

/*<info serverAlias="DBTGRS-bodb_TGRS" executers="bodbTGRSNet" isFunction="0" isNested="0"></info>*/