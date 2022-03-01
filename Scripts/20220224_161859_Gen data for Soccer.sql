/*
	Creator:	20220224@John.Ngo
	Task:		[TGR Soccer] Add new bet type 461, 462, 463, 464 to support drilldown to HDP - [Redmine: #161859]
	Server:		DB06.bodb_TGRS_UAT Or DB061.bodb_TGRS

	Reviewer:   Brice
*/

USE DB06.bodb_TGRS

DECLARE @FDate	DATE = '20210101'
	,	@TDate	DATE = GETDATE();

---- GEN Data
EXECUTE dbo.Task_RegenerateTGRSData @Debug = 1, @FromDate	= @FDate, @ToDate = @TDate,	@Flagged = 1

/*<info serverAlias="DBTGRS-bodb_TGRS" executers="bodbTGRSNet" isFunction="0" isNested="0"></info>*/