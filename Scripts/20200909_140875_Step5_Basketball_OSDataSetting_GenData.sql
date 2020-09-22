/*
	Creator: 20200909@John.Ngo
	Task: Initial IsLive of OSDataTGRS, OSBettype of Basketball [Redmine ID: #140875]
	DB: DB06.bodb_TGRS_UAT

	Reviewer: Partrick
*/

SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
SET NOCOUNT ON;

GO
DECLARE @FDate		DATE = '2020-08-01'
	,	@TDate		DATE = DATEADD(DD, -1 ,DATEADD(DD, 1, GETDATE()));

EXECUTE Task_RegenerateTGRSData_xtest  @Debug = 1, @FromDate = @FDate , @ToDate = @TDate , @Flagged = 2
GO

GO
/*<info serverAlias=" DB06-bodb_TGRS_UAT"></info>*/