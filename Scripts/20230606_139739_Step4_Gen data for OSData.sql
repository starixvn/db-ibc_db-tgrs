/*
	Created:	20230606@John.Ngo
	Task :		Staging Data for E-Sports/Basketball trader performance by class [Redmine ID: 187083]
	DB:			DBTGRS.bodb_TGRS

	Reviewer: Sol
*/ 

---- GEN Data for OS (2022 -> 2023)
-- (01/2023 -> Today)
DECLARE @FDate	DATE = '20230101'
	,	@TDate	DATE = GETDATE();
EXECUTE dbo.Task_RegenerateTGRSData @Debug = 1, @FromDate	= @FDate, @ToDate = @TDate,	@Flagged = 2
GO

-- (12 Month 01/2022 -> 12/2022)
DECLARE @FDate	DATE = '20220101'
	,	@TDate	DATE = '20221231';
EXECUTE dbo.Task_RegenerateTGRSData @Debug = 1, @FromDate	= @FDate, @ToDate = @TDate,	@Flagged = 2
GO
	
/*<info serverAlias="DBTGRS-bodb_TGRS" executers="bodbTGRSNet" isFunction="0" isNested="0"></info>*/