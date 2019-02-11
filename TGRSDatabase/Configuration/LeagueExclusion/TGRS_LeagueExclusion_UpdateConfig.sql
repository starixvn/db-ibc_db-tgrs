GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[TGRS_LeagueExclusion_UpdateConfig] 
		@UserId			INT
	,	@OnOffValue		NVARCHAR(50)
	
	,	@ErrCode		INT = 0 OUTPUT
	,	@ErrMsg			NVARCHAR(200) = '' OUTPUT
AS
/*
	Created:	20190114@Long.Luu
	Task :		Get Excluded Leagues Config
	DB:			DBTGRS.bodb_TGRS
	Original:
  
	Revisions:
		- 20190114@Long:	Created [Redmine: #107809]
   		
	Param's Explanation:

	Exam:	 
*/
BEGIN
	SET NOCOUNT ON;

	-- For write log
	DECLARE 
		@StartRun					DATETIME,
		@EndRun						DATETIME,
		@Duration					INT,
		@LogLeagueExclusionData		NVARCHAR(MAX),	
		@Xml						XML;		 

	SET @StartRun = GETDATE()

	UPDATE dbo.SystemSettings WITH (ROWLOCK, UPDLOCK)
	SET [VValue] = @OnOffValue
	WHERE VName = 'ExcludeLeagues';

	IF @@error <> 0
	BEGIN
		SELECT	@ErrMsg = 'Update IsExcludeLeague failed. Please try again.'
			,	@ErrCode = 501

		RETURN
	END;

	-- Write log 
	SET @xml =	(
					SELECT							
						GETDATE()			AS '@md',
						@OnOffValue			AS '@v' 	
						FOR XML PATH('z'), ROOT('r')
				);

	SET @LogLeagueExclusionData = REPLACE(CONVERT(NVARCHAR(MAX), @Xml), '" />', '"/"');

	SET @EndRun = GETDATE();
	SET @Duration = DATEDIFF(MILLISECOND, @StartRun, @EndRun);
	
	EXEC	dbo.TGRS_WriteLog_RunSp
			@UserId		= @UserId,
			@SPName		= 'TGRS_LeagueExclusion_UpdateConfig',
			@LogDate	= @StartRun,
			@Duration	= @Duration,
			@ObjectId	= 2209,
			@Data		= @LogLeagueExclusionData,
			@OldData	= NULL;
END;

GO
/*<info serverAlias="DBTGRS-bodb_TGRS" executers="bodbTGRSNet"  isFunction="0" isNested="0"></info>*/
