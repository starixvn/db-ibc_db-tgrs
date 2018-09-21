
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[TGRS_LeagueExclusion_Delete]
		@LeagueId		INT
	,	@UserId			INT

	,	@ErrCode		INT = 0 OUTPUT
    ,	@ErrMsg			NVARCHAR(200) = '' OUTPUT  
AS
/*
	Created:	20180905@Long.Luu
	Task :		Delete League for Exlusion
	DB:			DBTGRS.bodb_TGRS
	Original:
  
	Revisions:
		- 20180921@Long:	Adding meta data for SP
   		
	Param's Explanation:

	Exam:
	 
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

		DELETE FROM dbo.LeagueExclusion
		WHERE LeagueId = @LeagueId;

		DECLARE @EndRun DATETIME = GETDATE();
		DECLARE @Duration INT = DATEDIFF(MILLISECOND, @StartRun, @EndRun);
		DECLARE @NewData NVARCHAR(MAX) = REPLACE(CONVERT(NVARCHAR(MAX), @Xml), '" />', '"/"');

		EXEC	dbo.TGRS_WriteLog_RunSp
			@UserId		= @UserId,
			@SPName		= 'TGRS_LeagueExclusion_Delete',
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
END

GO
GRANT EXECUTE ON [dbo].[TGRS_LeagueExclusion_Delete] TO [bodbTGRSNet]
GO
GRANT VIEW DEFINITION ON [dbo].[TGRS_LeagueExclusion_Delete] TO [bodbTGRSNet]
GO
/*<info serverAlias="DBTGRS-bodb_TGRS" executers="bodbTGRSNet" isFunction="0" isNested="0"></info>*/