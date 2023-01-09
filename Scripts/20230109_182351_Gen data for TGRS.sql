/*
	Creator:	20230109@John.Ngo
	Task:		Gen data for TGRS [Redmine ID: 182351]
	Server:		DB061.bodb_TGRS

	Reviewer:   Sol
*/

-- (3 Month 10/2022 - 12/2022 -> Today)
DECLARE @FDate	DATE = '20221001'
	,	@TDate	DATE = GETDATE();
---- GEN Data for OS
EXECUTE dbo.Task_RegenerateTGRSData @Debug = 1, @FromDate	= @FDate, @ToDate = @TDate,	@Flagged = 2
GO

DECLARE @FDate	DATE = '20221001'
	,	@TDate	DATE = GETDATE();
---- GEN Data for Socer
EXECUTE dbo.Task_RegenerateTGRSData @Debug = 1, @FromDate	= @FDate, @ToDate = @TDate,	@Flagged = 1
GO

DECLARE @FDate	DATE = '20221001'
	,	@TDate	DATE = GETDATE();
---- GEN Data for RobotTrading
EXECUTE dbo.Task_RegenerateTGRSData @Debug = 1, @FromDate	= @FDate, @ToDate = @TDate,	@Flagged = 3
GO

-- (7 Month 01/2022 - 09/2022)
DECLARE @FDate	DATE = '20220101'
	,	@TDate	DATE = '20220930';
---- GEN Data for OS
EXECUTE dbo.Task_RegenerateTGRSData @Debug = 1, @FromDate	= @FDate, @ToDate = @TDate,	@Flagged = 2
GO

DECLARE @FDate	DATE = '20220101'
	,	@TDate	DATE = '20220930';
---- GEN Data for Socer
EXECUTE dbo.Task_RegenerateTGRSData @Debug = 1, @FromDate	= @FDate, @ToDate = @TDate,	@Flagged = 1
GO

DECLARE @FDate	DATE = '20220101'
	,	@TDate	DATE = '20220930';
---- GEN Data for RobotTrading
EXECUTE dbo.Task_RegenerateTGRSData @Debug = 1, @FromDate	= @FDate, @ToDate = @TDate,	@Flagged = 3
GO
	
/*<info serverAlias="DBTGRS-bodb_TGRS" executers="bodbTGRSNet" isFunction="0" isNested="0"></info>*/