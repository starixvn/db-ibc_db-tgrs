/*
	Creator: 20201215@John.Ngo
	Task: [OS] Market Count - Init Data for OS Market - Cricket [Redmine ID: 147117]
	Server:  DB06.bodb_TGRS_UAT

	Reviewer: Partrick
*/

SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
SET NOCOUNT ON;

GO
DECLARE @FDate		DATE = '2020-11-01'
	,	@TDate		DATE = DATEADD(DD, -1 ,DATEADD(DD, 1, GETDATE()));

DECLARE	@PrevFDate	DATE = DATEADD(YYYY, -1, @FDate)
	,	@PrevTDate  DATE = DATEADD(YYYY, -1, @TDate);

EXECUTE dbo.Task_OS_Market_StagingData_xtest  @Debug = 1, @GenerateFromDate = @FDate , @GenerateToDate = @TDate

EXECUTE dbo.Task_OS_Market_StagingData_xtest  @Debug = 1, @GenerateFromDate = @PrevFDate , @GenerateToDate = @PrevTDate

GO
/*<info serverAlias="DBTGRS-bodb_TGRS_UAT"></info>*/