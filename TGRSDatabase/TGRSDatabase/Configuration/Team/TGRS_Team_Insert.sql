
ALTER PROCEDURE [dbo].[TGRS_Team_Insert]
	@TeamName		NVARCHAR (50),
	@Description	NVARCHAR(200) = '',
	@UserId			INT,
	@ErrCode		INT = 0 OUTPUT,
	@ErrMsg			NVARCHAR(200) = '' OUTPUT

/*
Created: 20140509@Sophia
Task : Insert new team
DB:  DBTGRS.bodb_TGRS

Revisions:
   
*/ 

AS
BEGIN
	SET NOCOUNT ON 	

	--Check valid
	IF EXISTS ( SELECT TOP 1 1 FROM dbo.Team WITH (NOLOCK) WHERE TeamName = @TeamName)
	BEGIN 
		SELECT  @ErrCode = 100,
				@ErrMsg = 'Team name already exists.'
		RETURN
	END 
	 	 
	-- For write log
	DECLARE 
		@StartRun					DATETIME,
		@EndRun						DATETIME,
		@Duration					INT,
		@LogTeamData				NVARCHAR(MAX),	
		@Xml						XML,		
		@TeamId						SMALLINT

	SET @StartRun = GETDATE()

	-- Insert team 
	INSERT INTO	dbo.Team (
					TeamName
					,Description
					,CreatedDate
					,CreatedBy
					)
			VALUES (
					@TeamName
					,@Description
					,GETDATE()
					,@UserId
					)

	-- Check fail
	IF @@ERROR > 0
		BEGIN
			SELECT 
				@ErrCode = 101, 
				@ErrMsg = 'Failed to add new team [Team Name = ' + @TeamName +']'
			RETURN
		END
		 
	SELECT @TeamId = @@IDENTITY
		
	-- Write log 
	SET @xml = (
					SELECT	
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
			@SPName		= 'TGRS_Team_Insert',
			@LogDate	= @StartRun,
			@Duration	= @Duration,
			@ObjectId	= @TeamId,
			@Data		= @LogTeamData,
			@OldData	= NULL

		
END
	
GO
GRANT EXECUTE ON [dbo].[TGRS_Team_Insert] TO [bodbTGRSNet]



