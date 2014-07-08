 
ALTER PROCEDURE [dbo].[TGRS_Team_Update]
	@TeamId			SMALLINT,
	@TeamName		NVARCHAR (50),
	@Description	NVARCHAR(200) = '',
	@UserId			INT,
	@ErrCode		INT = 0 OUTPUT,
	@ErrMsg			NVARCHAR(200) = '' OUTPUT

/*
Created: 20140509@Sophia
Task : Update team
DB:  DBTGRS.bodb_TGRS

Revisions:
   
*/ 

AS
BEGIN
	SET NOCOUNT ON 	
	--Check valid
	IF EXISTS ( SELECT TOP 1 1 FROM dbo.Team WITH (NOLOCK) WHERE TeamName = @TeamName AND TeamId <> @TeamId)
	BEGIN 
		SELECT  @ErrCode = 100,
				@ErrMsg = 'Team name is existed.'
		RETURN
	END 
	 
	-- For write log
	DECLARE 
		@StartRun					DATETIME,
		@EndRun						DATETIME,
		@Duration					INT,
		@LogTeamData				NVARCHAR(MAX),	
		@LogTeamOldData				NVARCHAR(MAX),	
		@Xml						XML		 

	SET @StartRun = GETDATE()

	-- write log before update				
	SET @xml = (
					SELECT  TeamId		AS '@t',
							TeamName	AS '@n',
							Description AS '@d'
					FROM	dbo.Team WITH (NOLOCK)							
					WHERE	TeamId = @TeamId
					FOR XML PATH('z'),ROOT('r')
				)	 

	SET @LogTeamOldData = REPLACE(CONVERT(VARCHAR(MAX), @xml), '" />', '"/"')
	-- end write log					
		
	-- Update				
	UPDATE	dbo.Team WITH (ROWLOCK, UPDLOCK) 
	SET		TeamName		= @TeamName,
			Description		= @Description,
			ModifiedDate	= Getdate(),
			ModifiedBy		= @UserId
	WHERE	TeamId			= @TeamId
	
	-- Check fail
	IF @@ERROR > 0
		BEGIN
			SELECT 
				@ErrCode = 102, 
				@ErrMsg = 'Failed to update team [Team Name = ' + @TeamName +']'
			RETURN
		END

	-- Write log after update			
	SET @xml = (	 SELECT	
						@TeamId				AS '@t',
						@TeamName			AS '@n',
						@Description		AS '@d'			
					 FOR XML PATH('z'), ROOT('r')
				)

	SET @LogTeamData = REPLACE(CONVERT(NVARCHAR(MAX), @Xml), '" />', '"/"')

	SET @EndRun = GETDATE()
	SET @Duration = DATEDIFF(MILLISECOND, @StartRun, @EndRun) 
	
	EXEC	dbo.TGRS_WriteLog_RunSp
			@UserId		= @UserId,
			@SPName		= 'TGRS_Team_Update',
			@LogDate	= @StartRun,
			@Duration	= @Duration,
			@ObjectId	= @TeamId,
			@Data		= @LogTeamData,
			@OldData	= @LogTeamOldData

END
	
GO
GRANT EXECUTE ON [dbo].[TGRS_Team_Update] TO [bodbTGRSNet]



