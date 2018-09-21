
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[TGRS_LeagueExclusion_Insert]
		@LeagueId		INT
	,	@UserId			INT

	,	@ErrCode		INT = 0 OUTPUT
    ,	@ErrMsg			NVARCHAR(200) = '' OUTPUT  
AS
/*
	Created:	20180905@Long.Luu
	Task :		Insert League for Exlusion
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

		INSERT INTO dbo.LeagueExclusion(LeagueId, CreatedBy, CreatedDate)
		VALUES (@LeagueId, @UserId, GETDATE());

		DECLARE @EndRun DATETIME = GETDATE();
		DECLARE @Duration INT = DATEDIFF(MILLISECOND, @StartRun, @EndRun);
		DECLARE @NewData NVARCHAR(MAX) = REPLACE(CONVERT(NVARCHAR(MAX), @Xml), '" />', '"/"');

		EXEC	dbo.TGRS_WriteLog_RunSp
			@UserId		= @UserId,
			@SPName		= 'TGRS_LeagueExclusion_Insert',
			@LogDate	= @StartRun,
			@Duration	= @Duration,
			@ObjectId	= @LeagueId,
			@Data		= @NewData,
			@OldData	= NULL;
	END TRY
	BEGIN CATCH
		SET @ErrCode = ERROR_NUMBER();
		SET @ErrMsg = 'There''s already another League with this id';
	END CATCH
END

GO
GRANT EXECUTE ON [dbo].[TGRS_LeagueExclusion_Insert] TO [bodbTGRSNet]
GO
GRANT VIEW DEFINITION ON [dbo].[TGRS_LeagueExclusion_Insert] TO [bodbTGRSNet]
GO
/*<info serverAlias="DBTGRS-bodb_TGRS" executers="bodbTGRSNet" isFunction="0" isNested="0"></info>*/