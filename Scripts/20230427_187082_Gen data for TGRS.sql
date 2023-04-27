/*
	Creator:	20230427@John.Ngo
	Task:		Gen data for TGRS [Redmine ID: 187082]
	Server:		DB061.bodb_TGRS

	Reviewer:   Sol
*/

---- GEN Data for Socer (2020 -> 2023)
-- (4 Month 01/2023 - 04/2023 -> Today)
DECLARE @FDate	DATE = '20230101'
	,	@TDate	DATE = GETDATE();
EXECUTE dbo.Task_RegenerateTGRSData @Debug = 1, @FromDate	= @FDate, @ToDate = @TDate,	@Flagged = 1
GO

-- (12 Month 01/2022 -> 12/2022)
DECLARE @FDate	DATE = '20220101'
	,	@TDate	DATE = '20221231';
EXECUTE dbo.Task_RegenerateTGRSData @Debug = 1, @FromDate	= @FDate, @ToDate = @TDate,	@Flagged = 1
GO

-- (12 Month 01/2021 -> 12/2021)
DECLARE @FDate	DATE = '20210101'
	,	@TDate	DATE = '20211231';
EXECUTE dbo.Task_RegenerateTGRSData @Debug = 1, @FromDate	= @FDate, @ToDate = @TDate,	@Flagged = 1
GO

-- (12 Month 01/2020 -> 12/2020)
DECLARE @FDate	DATE = '20200101'
	,	@TDate	DATE = '20201231';
EXECUTE dbo.Task_RegenerateTGRSData @Debug = 1, @FromDate	= @FDate, @ToDate = @TDate,	@Flagged = 1
GO

---- GEN Data for OS (2020 -> 2023)
-- (4 Month 01/2023 - 04/2023 -> Today)
DECLARE @FDate	DATE = '20230101'
	,	@TDate	DATE = GETDATE();
EXECUTE dbo.Task_RegenerateTGRSData @Debug = 1, @FromDate	= @FDate, @ToDate = @TDate,	@Flagged = 2
GO

-- (12 Month 01/2022 -> 12/2022)
DECLARE @FDate	DATE = '20220101'
	,	@TDate	DATE = '20221231';
EXECUTE dbo.Task_RegenerateTGRSData @Debug = 1, @FromDate	= @FDate, @ToDate = @TDate,	@Flagged = 2
GO

-- (12 Month 01/2021 -> 12/2021)
DECLARE @FDate	DATE = '20210101'
	,	@TDate	DATE = '20211231';
EXECUTE dbo.Task_RegenerateTGRSData @Debug = 1, @FromDate	= @FDate, @ToDate = @TDate,	@Flagged = 2
GO

-- (12 Month 01/2020 -> 12/2020)
DECLARE @FDate	DATE = '20200101'
	,	@TDate	DATE = '20201231';
EXECUTE dbo.Task_RegenerateTGRSData @Debug = 1, @FromDate	= @FDate, @ToDate = @TDate,	@Flagged = 2
GO
	
/*<info serverAlias="DBTGRS-bodb_TGRS" executers="bodbTGRSNet" isFunction="0" isNested="0"></info>*/