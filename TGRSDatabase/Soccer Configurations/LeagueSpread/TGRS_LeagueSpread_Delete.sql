ALTER PROCEDURE [dbo].[TGRS_LeagueSpread_Delete]
		@LeagueId		INT
	,	@UserId			INT

	,	@ErrCode		INT = 0 OUTPUT
    ,	@ErrMsg			NVARCHAR(200) = '' OUTPUT  
AS
/*
	Created:	20210604@Adam.Tran
	Task:		Automation Trading - Report Spread Live Performance
	DB:			DBTGRS.bodb_TGRS
	Original:
	
	Revisions:
		- 20210604@Adam.Tran: Created [Redmine ID: 156614]
		
	Param's Explanation:		
		
	Exam: EXECUTE dbo.TGRS_LeagueSpread_Delete
	 
*/
BEGIN
	SET NOCOUNT ON;

	BEGIN TRY
		DECLARE @StartRun DATETIME = GETDATE();

		DECLARE @xml XML = 
			(
				SELECT 
					@LeagueId AS '@l',
					@UserId AS '@cb',
					GETDATE() AS '@cd'
				FOR XML PATH('z'), ROOT('r')
			);

		DELETE FROM dbo.LeagueSpread
		WHERE LeagueId = @LeagueId;

		DECLARE @EndRun DATETIME = GETDATE();
		DECLARE @Duration INT = DATEDIFF(MILLISECOND, @StartRun, @EndRun);
		DECLARE @NewData NVARCHAR(MAX) = REPLACE(CONVERT(NVARCHAR(MAX), @Xml), '" />', '"/"');

		EXEC	dbo.TGRS_WriteLog_RunSp
			@UserId		= @UserId,
			@SPName		= 'TGRS_LeagueSpread_Delete',
			@LogDate	= @StartRun,
			@Duration	= @Duration,
			@ObjectId	= @LeagueId,
			@Data		= @NewData,
			@OldData	= NULL;
	END TRY
	BEGIN CATCH
		SET @ErrCode = ERROR_NUMBER();
		SET @ErrMsg = 'Something wrong happened. Contact admin for detailed info.';
	END CATCH
END;

/*<info serverAlias="DBTGRS-bodb_TGRS" executers="bodbTGRSNet" isFunction="0" isNested="0"></info>*/