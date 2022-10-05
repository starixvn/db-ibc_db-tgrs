/*
	Creator:	20221005@John.Ngo
	Task: 		Database - Wrong Company Balance Figure - [Redmine: #178737]
	Server:		DB061.bodb_TGRS

	Reviewer:   Patrick - Brice
*/
DECLARE @FDate	DATE = '20220915'
	,	@TDate	DATE = GETDATE();

---- GEN Data
EXECUTE dbo.Task_RegenerateTGRSData @Debug = 1, @FromDate	= @FDate, @ToDate = @TDate,	@Flagged = 0

/*<info serverAlias="DBTGRS-bodb_TGRS" executers="bodbTGRSNet" isFunction="0" isNested="0"></info>*/