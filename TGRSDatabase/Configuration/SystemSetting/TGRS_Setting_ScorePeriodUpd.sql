ALTER PROCEDURE [dbo].[TGRS_Setting_ScorePeriodUpd]
(
	@BeginDay		VARCHAR(20) = NULL
	,@EndDay		VARCHAR(20)  = NULL
	,@SelectedDay	VARCHAR(20) = NULL
	,@UserId		INT
	,@ErrCode		INT = 0 OUTPUT
	,@ErrMsg		NVARCHAR(200) = '' OUTPUT
)

/*
Created: 20141203@Sophia
Task : Update Setting Score Period
DB:  DBTGRS/bodb_TGRS

Revisions:
	 
Explanation : 
	 
	EXEC TGRS_Setting_ScorePeriodUpd @BeginDay = '1900-01-02', @EndDay = '1900-01-01', @SelectedDay = '1900-07-25', @UserId = 8
   
*/ 

AS
BEGIN 
	SET NOCOUNT ON 

	IF ISNULL(@BeginDay,'') = ''		
	BEGIN 		
		-- Check fail
		IF @@ERROR > 0
			BEGIN
				SELECT 
					@ErrCode = 500, 
					@ErrMsg = 'Invalid BeginDay [' +@BeginDay +']'
				RETURN
			END

	END 
	IF ISNULL(@EndDay,'') = '' 
		BEGIN 			
			-- Check fail
			IF @@ERROR > 0
				BEGIN
					SELECT 
						@ErrCode = 501, 
						@ErrMsg = 'Invalid EndDay [' +@EndDay +']'
					RETURN
				END

		END 

	IF ISNULL(@SelectedDay,'') ='' 
		BEGIN 				
			-- Check fail
			IF @@ERROR > 0
				BEGIN
					SELECT 
						@ErrCode = 502, 
						@ErrMsg = 'Invalid SelectedDay [' +@SelectedDay +']'
					RETURN
				END

		END 
	 
	 ---------------------------------
	IF ISNULL(@BeginDay,'') <> '' 
		BEGIN 		
			SELECT @BeginDay = CONVERT(DATE , @BeginDay, 120)
			-- Check fail
			IF @@ERROR > 0
				BEGIN
					SELECT 
						@ErrCode = 500, 
						@ErrMsg = 'Invalid BeginDay [' +@BeginDay +']'
					RETURN
				END

		END 

	IF ISNULL(@EndDay,'') <> '' 
		BEGIN 		
			SELECT @EndDay = CONVERT(DATE , @EndDay, 120)
			-- Check fail
			IF @@ERROR > 0
				BEGIN
					SELECT 
						@ErrCode = 501, 
						@ErrMsg = 'Invalid EndDay [' +@EndDay +']'
					RETURN
				END

		END 

	IF ISNULL(@SelectedDay,'') <> '' 
		BEGIN 		
			SELECT @SelectedDay = CONVERT(DATE , @SelectedDay, 120)
			-- Check fail
			IF @@ERROR > 0
				BEGIN
					SELECT 
						@ErrCode = 502, 
						@ErrMsg = 'Invalid SelectedDay [' +@SelectedDay +']'
					RETURN
				END

		END 
	 
	------------------------------
	IF @SelectedDay	= @BeginDay OR @SelectedDay = @EndDay 
		BEGIN 				
			SELECT 
					@ErrCode = 502, 
					@ErrMsg = 'Selected day must be different with Begin Day and End Day '
			RETURN
				

		END 

	IF @BeginDay  = @EndDay 
		BEGIN
			SELECT 
					@ErrCode = 501, 
					@ErrMsg = 'Invalid EndDay'
			RETURN
		END 


	-- For write log
	DECLARE 
		@StartRun					DATETIME,
		@EndRun						DATETIME,
		@Duration					INT,
		@LogSettingData				NVARCHAR(MAX),	
		@LogSettingOldData			NVARCHAR(MAX),	
		@Xml						XML 	
		
	DECLARE @OldBeginDay VARCHAR(20),
			@OldEndDay VARCHAR(20),
			@OldSelectedDay VARCHAR(20)

	SET @StartRun = GETDATE()
		
		SELECT @OldBeginDay =  VValue	  							 		
		FROM   dbo.SystemSettings WITH (NOLOCK)							
		WHERE  VNAme = 'BeginDay'

		SELECT @OldEndDay =  VValue	  							 		
		FROM   dbo.SystemSettings WITH (NOLOCK)							
		WHERE  VNAme = 'EndDay'

		SELECT @OldSelectedDay =  VValue	  							 		
		FROM   dbo.SystemSettings WITH (NOLOCK)							
		WHERE  VNAme = 'SelectedDay'


	-- write log before update				
	SET @xml =	(
					SELECT	@OldBeginDay	AS '@b',
							@OldEndDay		AS '@e',
							@OldSelectedDay AS '@s'		
					FOR XML PATH('z'),ROOT('r')
				)	 

	SET @LogSettingOldData = REPLACE(CONVERT(VARCHAR(MAX), @xml), '" />', '"/"')
	-- end write log	



	IF ISNULL(@BeginDay,'') <> ''
	BEGIN
		UPDATE	dbo.SystemSettings WITH (UPDLOCK, ROWLOCK)
		SET		VValue = @BeginDay	
		WHERE	VNAme = 'BeginDay'

		-- Check fail
		IF @@ERROR > 0
			BEGIN
				SELECT 
					@ErrCode = 503, 
					@ErrMsg = 'Failed to update Score Period [BeginDay = ' +  @BeginDay  +']'
				RETURN
			END
	END 

	
	IF ISNULL(@EndDay,'') <> ''
	BEGIN
		UPDATE	dbo.SystemSettings WITH (UPDLOCK, ROWLOCK)
		SET		VValue = @EndDay	
		WHERE	VNAme = 'EndDay'

		-- Check fail
		IF @@ERROR > 0
			BEGIN
				SELECT 
					@ErrCode = 504, 
					@ErrMsg = 'Failed to update Score Period [EndDay = ' +  @EndDay  +']'
				RETURN
			END
	END 

	
	IF ISNULL(@SelectedDay,'') <> ''
	BEGIN
		UPDATE	dbo.SystemSettings WITH (UPDLOCK, ROWLOCK) 
		SET		VValue = @SelectedDay	
		WHERE	VNAme = 'SelectedDay'

		-- Check fail
		IF @@ERROR > 0
			BEGIN
				SELECT 
					@ErrCode = 505, 
					@ErrMsg = 'Failed to update Score Period [SelectedDay = ' +  @SelectedDay  +']'
				RETURN
			END
	END 
	
	-- write log after update				
	SET @xml =	(
					SELECT	CASE WHEN ISNULL(@BeginDay,'') <> '' THEN @BeginDay ELSE @OldBeginDay END AS '@b',
							CASE WHEN ISNULL(@EndDay,'') <> '' THEN @EndDay ELSE @OldEndDay END AS '@e',
							CASE WHEN ISNULL(@SelectedDay,'') <> '' THEN @SelectedDay ELSE @OldSelectedDay END AS '@s'		
					FOR XML PATH('z'),ROOT('r')
				)	 

	SET @LogSettingData = REPLACE(CONVERT(VARCHAR(MAX), @xml), '" />', '"/"')
	-- end write log	
	
	SET @EndRun = GETDATE()
	SET @Duration = DATEDIFF(MILLISECOND, @StartRun, @EndRun) 
	
	EXEC	dbo.TGRS_WriteLog_RunSp
			@UserId		= @UserId,
			@SPName		= 'TGRS_Setting_ScorePeriodUpd',
			@LogDate	= @StartRun,
			@Duration	= @Duration,
			@ObjectId	= NULL,
			@Data		= @LogSettingData,
			@OldData	= @LogSettingOldData


END
GO
GRANT EXECUTE ON [dbo].[TGRS_Setting_ScorePeriodUpd] TO [bodbTGRSNet] 

GO
