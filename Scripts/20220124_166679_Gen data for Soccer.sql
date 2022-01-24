/*
	Creator:	20220124@John.Ngo
	Task:		Support data drildown for Total Goal, Time Machine and Corner bettype [Redmine: #166679]
	Server:		DB06.bodb_TGRS_UAT Or DB061.bodb_TGRS

	Reviewer:   Brice
*/

USE bodb_TGRS_UAT

DECLARE @FDate	DATE = '20220101'
	,	@TDate	DATE = GETDATE();

---- GEN Data
EXECUTE dbo.Task_RegenerateTGRSData_xtest @Debug = 1, @FromDate	= @FDate, @ToDate = @TDate,	@Flagged = 1

/*<info serverAlias="DBTGRS-bodb_TGRS" executers="bodbTGRSNet" isFunction="0" isNested="0"></info>*/