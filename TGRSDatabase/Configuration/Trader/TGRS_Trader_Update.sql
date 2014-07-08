USE [bodb_TGRS]
GO
/****** Object:  StoredProcedure [dbo].[TGRS_Trader_Update]    Script Date: 5/29/2014 10:24:41 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[TGRS_Trader_Update]
	@CustId			INT,	
	@NewTeamId		SMALLINT = NULL,
	@NewGrade		SMALLINT = NULL,
	@NewTeamEffectiveDate	DATE = NULL,
	@NewGradeEffectiveDate	DATE = NULL,
	@UserId			INT,
	@ErrCode		INT = 0 OUTPUT,
	@ErrMsg			NVARCHAR(200) = '' OUTPUT

/*
Created: 20140512@Sophia
Task : Update trader
DB:  DBTGRS.bodb_TGRS

Revisions:
   
*/ 

AS
BEGIN
	SET NOCOUNT ON 	

	--------------------------------------------------
	----------------Check valid--------------------
 	


	----- Get the lasted data of history table
	DECLARE @LastedTeamId SMALLINT, @LastedTeamEffectiveDate DATE,   
			@LastedGrade TINYINT, @LastedGradeEffectiveDate DATE, 
			@PreTeamId SMALLINT, @PreTeamEffectiveDate DATE,@PreTeamEndDate DATE,   
			@PreGrade TINYINT, @PreGradeEffectiveDate DATE, @PreGradeEndDate DATE,
			@Today DATE
	
	SELECT	@Today = GETDATE()	
	
	IF @NewTeamId IS NULL AND @NewTeamEffectiveDate IS NULL AND @NewGrade IS NULL AND @NewGradeEffectiveDate IS NULL
	BEGIN 
			SELECT @ErrCode = 311,
				   @ErrMsg = 'There is no change.'
			RETURN
	END

	IF @NewTeamId IS NOT NULL AND @NewTeamEffectiveDate IS NOT NULL
	BEGIN 
		---lasted info 
		SELECT 	TOP 1 
				@LastedTeamId = TeamId, 
				@LastedTeamEffectiveDate = BeginDate 
		FROM	dbo.TraderTeam_History WITH (NOLOCK)							
		WHERE	CustId = @CustId
		ORDER BY BeginDate DESC
				
		--- Previous lasted info
		SELECT 	TOP 1 
				@PreTeamId = TeamId, 
				@PreTeamEffectiveDate = BeginDate,
				@PreTeamEndDate = EndDate 
		FROM	dbo.TraderTeam_History WITH (NOLOCK)							
		WHERE	CustId = @CustId 
				AND EndDate IS NOT NULL
		ORDER BY EndDate DESC


		IF NOT EXISTS ( SELECT TOP 1 1 FROM dbo.Team WITH (NOLOCK) WHERE TeamId = @NewTeamId)
		BEGIN 
			SELECT  @ErrCode = 304,
					@ErrMsg = 'Team is invalid.'
			RETURN
		END 

		---- If @LastedTeamEffectiveDate < today (past) and @NewteamId (furture) = Lasted Team Name then not allow to update
		IF @LastedTeamEffectiveDate < @Today AND @NewTeamEffectiveDate >= @Today AND @NewTeamId = @LastedTeamId 
		BEGIN 
			SELECT @ErrCode = 309,
				   @ErrMsg = 'New team is the same with the previous team.'
			RETURN
		END
		
	END 

	IF @NewGrade IS NOT NULL AND @NewGradeEffectiveDate IS NOT NULL
		BEGIN 
			---lasted info 
			SELECT 	TOP 1 
					@LastedGrade = Grade, 
					@LastedGradeEffectiveDate = BeginDate
			FROM	dbo.TraderGrade_History WITH (NOLOCK)							
			WHERE	CustId = @CustId
			ORDER BY BeginDate DESC
				
			--- Previous lasted info
			SELECT 	TOP 1 
					@PreGrade = Grade, 
					@PreGradeEffectiveDate = BeginDate,
					@PreGradeEndDate =  EndDate 
			FROM	dbo.TraderGrade_History WITH (NOLOCK)							
			WHERE	CustId = @CustId 
					AND EndDate IS NOT NULL
			ORDER BY EndDate DESC

		
			---- If @LastedGradeEffectiveDate < today (past) and @NewGrade (furture) = Lasted Grade Name then not allow to update
			IF @LastedGradeEffectiveDate < @Today AND @NewGradeEffectiveDate >= @Today AND @NewGrade = @LastedGrade 
			BEGIN 
				SELECT @ErrCode = 310,
					   @ErrMsg = 'New grade is the same with the previous grade.'
				RETURN
			END
		
		END 
	----------------End of Check valid--------------------
	-------------------------------------------------------

	--Select  @LastedTeamId , @LastedTeamEffectiveDate ,   
	--		@LastedGrade , @LastedGradeEffectiveDate , 
	--		@PreTeamId , @PreTeamEffectiveDate ,@PreTeamEndDate ,   
	--		@PreGrade , @PreGradeEffectiveDate , @PreGradeEndDate 

	---- Get current data of trader
	DECLARE @Username		VARCHAR(30),
			@EmployeeId		NVARCHAR(20),
			@OldTeamId		INT,
			@OldGrade		INT,
			@OldTeamEffectiveDate DATE,
			@OldGradeEffectiveDate DATE			


	SELECT  @Username	= Username,
			@EmployeeId	= EmployeeId,
			@OldTeamId	= TeamId, 
			@OldGrade	= Grade,
			@OldTeamEffectiveDate = TeamEffectiveDate,
			@OldGradeEffectiveDate = GradeEffectiveDate			
	FROM	dbo.Trader WITH (NOLOCK)							
	WHERE	CustId = @CustId



	---------------------------------------------------	 
	----------------- For write log -------------------
	
	DECLARE 
		@StartRun					DATETIME,
		@EndRun						DATETIME,
		@Duration					INT,
		@LogTraderData				NVARCHAR(MAX),	
		@LogTraderOldData			NVARCHAR(MAX),	
		@Xml						XML		 

	SET @StartRun = GETDATE()

	-- write log before update				
	SET @xml = (
					SELECT  @CustId				AS '@c',
							@Username			AS '@n',
							@EmployeeId			AS '@e',
							@OldTeamId			AS '@t',
							@OldGrade			AS '@g',
							@OldTeamEffectiveDate	AS '@dt',					
							@OldGradeEffectiveDate	AS '@dg'
					FOR XML PATH('z'),ROOT('r')
				)	 

	SET @LogTraderOldData = REPLACE(CONVERT(VARCHAR(MAX), @xml), '" />', '"/"')
	
	----------------- End write log	-------------------
	--===============================================--
	
	----------------- For Update Team-------------------	
	IF @NewTeamId IS NOT NULL AND @NewTeamEffectiveDate IS NOT NULL
	BEGIN 
		
		------#1. If @LastedTeamEffectiveDate <= today (past) and @NewteamId (furture) <> Lasted Team Name then allow to update Team and add 1 row into History
		IF @LastedTeamEffectiveDate < @Today AND @NewTeamEffectiveDate >= @Today AND @NewTeamId <> @LastedTeamId  
		BEGIN 
 
			----a.Update trader
			UPDATE	dbo.Trader WITH (ROWLOCK, UPDLOCK) 
			SET		TeamId			= @NewTeamId,				
					TeamEffectiveDate = @NewTeamEffectiveDate,
					ModifiedDate	= Getdate(),
					ModifiedBy		= @UserId
			WHERE	CustId			= @CustId
				
				-- Check fail
				IF @@ERROR > 0
					BEGIN
						SELECT 
							@ErrCode = 312, 
							@ErrMsg = 'Failed to update trader [Username = ' + @Username +']'
						RETURN
					END

			----c.Update EndDate of the Last history
			UPDATE	dbo.TraderTeam_History WITH (ROWLOCK, UPDLOCK) 
			SET		EndDate = DATEADD (dd, -1, @NewTeamEffectiveDate)
			WHERE	CustId = @CustId
					AND BeginDate = @LastedTeamEffectiveDate


			----b.Insert trader-team history
			INSERT INTO	dbo.TraderTeam_History (
								CustId
								,TeamId							
								,BeginDate
								,EndDate
								)
						VALUES (
								 @CustId
								,@NewTeamId																	
								,@NewTeamEffectiveDate
								,NULL
								)			
									 
				-- Check fail
				IF @@ERROR > 0
					BEGIN
						---rollback
						UPDATE	dbo.Trader WITH (ROWLOCK, UPDLOCK) 
						SET		TeamId			= @OldTeamId,				
								TeamEffectiveDate = @OldTeamEffectiveDate,
								ModifiedDate	= Getdate(),
								ModifiedBy		= @UserId
						WHERE	CustId = @CustId					 
				
						SELECT 
							@ErrCode = 313, 
							@ErrMsg = 'Failed to add new trader-team history [Username = ' + @Username +']'
						RETURN
					END	
		END
	


		------#2. If @LastedTeamEffectiveDate > today (furture) and @NewteamId (furture) <> Previous Lasted Team Name then update Team and override the last row of History
		IF @LastedTeamEffectiveDate >= @Today AND @NewTeamEffectiveDate >= @Today AND @NewTeamId <> ISNULL(@PreTeamId,0)
		BEGIN 

			----a.Update trader				
			UPDATE	dbo.Trader WITH (ROWLOCK, UPDLOCK) 
			SET		TeamId			= @NewTeamId,				
					TeamEffectiveDate = @NewTeamEffectiveDate,
					ModifiedDate	= Getdate(),
					ModifiedBy		= @UserId
			WHERE	CustId			= @CustId
						
				-- Check fail
				IF @@ERROR > 0
					BEGIN
						SELECT 
							@ErrCode = 312, 
							@ErrMsg = 'Failed to update trader [Username = ' + @Username +']'
						RETURN
					END


		
			----c.Update EndDate of the previous history
			UPDATE	dbo.TraderTeam_History WITH (ROWLOCK, UPDLOCK) 
			SET		EndDate = DATEADD (dd, -1, @NewTeamEffectiveDate)
			WHERE	CustId = @CustId
					AND ISNULL(EndDate,'') = ISNULL(@PreTeamEndDate,'')
	

			----b.Update trader-team history
			UPDATE	dbo.TraderTeam_History WITH (ROWLOCK, UPDLOCK) 
			SET		TeamId = @NewTeamId,
					BeginDate = @NewTeamEffectiveDate,
					EndDate = NULL
			WHERE	CustId = @CustId
					AND BeginDate = @LastedTeamEffectiveDate 
	 									 
				-- Check fail
				IF @@ERROR > 0
					BEGIN
						---rollback
						UPDATE	dbo.Trader WITH (ROWLOCK, UPDLOCK) 
						SET		TeamId			= @OldTeamId,				
								TeamEffectiveDate = @OldTeamEffectiveDate,
								ModifiedDate	= Getdate(),
								ModifiedBy		= @UserId
						WHERE	CustId = @CustId					 
				
						SELECT 
							@ErrCode = 314, 
							@ErrMsg = 'Failed to update trader-team history [Username = ' + @Username +']'
						RETURN
					END		
		
		END

		------#3. If @LastedTeamEffectiveDate >= today (furture) and @NewteamId (furture) = Previous Lasted Team Name then update Team and delete the future row of History
		IF @LastedTeamEffectiveDate >= @Today AND @NewTeamEffectiveDate >= @Today AND @NewTeamId = ISNULL(@PreTeamId,0)
		BEGIN 
			----a.Update trader				
			UPDATE	dbo.Trader WITH (ROWLOCK, UPDLOCK) 
			SET		TeamId			= @NewTeamId,				
					TeamEffectiveDate = @PreTeamEffectiveDate,
					ModifiedDate	= Getdate(),
					ModifiedBy		= @UserId
			WHERE	CustId			= @CustId
						
				-- Check fail
				IF @@ERROR > 0
					BEGIN
						SELECT 
							@ErrCode = 312, 
							@ErrMsg = 'Failed to update trader [Username = ' + @Username +']'
						RETURN
					END

			----c.Update EndDate of the previous history
			UPDATE	dbo.TraderTeam_History WITH (ROWLOCK, UPDLOCK) 
			SET		EndDate = NULL
			WHERE	CustId = @CustId
					AND ISNULL(EndDate,'') = ISNULL(@PreTeamEndDate,'')			

			----b.Delete lasted trader-team history
			DELETE  dbo.TraderTeam_History WITH (ROWLOCK, UPDLOCK) 			
			WHERE	CustId = @CustId
					AND BeginDate = @LastedTeamEffectiveDate 
	 									 
				-- Check fail
				IF @@ERROR > 0
					BEGIN
						---rollback
						UPDATE	dbo.Trader WITH (ROWLOCK, UPDLOCK) 
						SET		TeamId			= @OldTeamId,				
								TeamEffectiveDate = @OldTeamEffectiveDate,
								ModifiedDate	= Getdate(),
								ModifiedBy		= @UserId
						WHERE	CustId = @CustId					 
				
						SELECT 
							@ErrCode = 315, 
							@ErrMsg = 'Failed to delete trader-team history [Username = ' + @Username +']'
						RETURN
					END
		 		
	
		END
	END
	-----------------End of update team -----------------------
	
	--##########################################################--	
	
	----------------- For Update Grade-------------------	
	IF @NewGrade IS NOT NULL AND @NewGradeEffectiveDate IS NOT NULL
	BEGIN 
	
		------#1. If @LastedGradeEffectiveDate < today (past) and @NewGrade (furture) <> Lasted Grade Name then allow to update Grade and add 1 row into History
		IF @LastedGradeEffectiveDate < @Today AND @NewGradeEffectiveDate >= @Today AND @NewGrade <> @LastedGrade 
		BEGIN 	 
			----a.Update trader
			UPDATE	dbo.Trader WITH (ROWLOCK, UPDLOCK) 
			SET		Grade			= @NewGrade,				
					GradeEffectiveDate = @NewGradeEffectiveDate,
					ModifiedDate	= Getdate(),
					ModifiedBy		= @UserId
			WHERE	CustId			= @CustId
				
				-- Check fail
				IF @@ERROR > 0
					BEGIN
						SELECT 
							@ErrCode = 312, 
							@ErrMsg = 'Failed to update trader [Username = ' + @Username +']'
						RETURN
					END

			----c.Update EndDate of the previous history
			UPDATE	dbo.TraderGrade_History WITH (ROWLOCK, UPDLOCK) 
			SET		EndDate = DATEADD (dd, -1, @NewGradeEffectiveDate)
			WHERE	CustId = @CustId
					AND ISNULL(EndDate,'') = ISNULL(@PreGradeEndDate,'')		


			----b.Insert trader-Grade history
			INSERT INTO	dbo.TraderGrade_History (
								CustId
								,Grade							
								,BeginDate
								,EndDate
								)
						VALUES (
								 @CustId
								,@NewGrade																	
								,@NewGradeEffectiveDate
								,NULL
								)			
									 
				-- Check fail
				IF @@ERROR > 0
					BEGIN
						---rollback
						UPDATE	dbo.Trader WITH (ROWLOCK, UPDLOCK) 
						SET		Grade			= @OldGrade,				
								GradeEffectiveDate = @OldGradeEffectiveDate,
								ModifiedDate	= Getdate(),
								ModifiedBy		= @UserId
						WHERE	CustId = @CustId					 
				
						SELECT 
							@ErrCode = 313, 
							@ErrMsg = 'Failed to add new trader-Grade history [Username = ' + @Username +']'
						RETURN
					END
		 
		END
	
		------#2. If @LastedGradeEffectiveDate >= today (furture) and @NewGrade (furture) <> Previous Lasted Grade Name then update Grade and override the last row of History
		IF @LastedGradeEffectiveDate >= @Today AND @NewGradeEffectiveDate >= @Today AND @NewGrade <> ISNULL(@PreGrade ,0)
		BEGIN 
			----a.Update trader				
			UPDATE	dbo.Trader WITH (ROWLOCK, UPDLOCK) 
			SET		Grade			= @NewGrade,				
					GradeEffectiveDate = @NewGradeEffectiveDate,
					ModifiedDate	= Getdate(),
					ModifiedBy		= @UserId
			WHERE	CustId			= @CustId
						
				-- Check fail
				IF @@ERROR > 0
					BEGIN
						SELECT 
							@ErrCode = 312, 
							@ErrMsg = 'Failed to update trader [Username = ' + @Username +']'
						RETURN
					END

			----c.Update EndDate of the previous history
			UPDATE	dbo.TraderGrade_History WITH (ROWLOCK, UPDLOCK) 
			SET		EndDate = DATEADD (dd, -1, @NewGradeEffectiveDate)
			WHERE	CustId = @CustId
					AND ISNULL(EndDate,'') = ISNULL(@PreGradeEndDate,'')
	
			----b.Update trader-Grade history
			UPDATE	dbo.TraderGrade_History WITH (ROWLOCK, UPDLOCK) 
			SET		Grade = @NewGrade,
					BeginDate = @NewGradeEffectiveDate,
					EndDate = NULL
			WHERE	CustId = @CustId
					AND BeginDate = @LastedGradeEffectiveDate 
	 									 
				-- Check fail
				IF @@ERROR > 0
					BEGIN
						---rollback
						UPDATE	dbo.Trader WITH (ROWLOCK, UPDLOCK) 
						SET		Grade			= @OldGrade,				
								GradeEffectiveDate = @OldGradeEffectiveDate,
								ModifiedDate	= Getdate(),
								ModifiedBy		= @UserId
						WHERE	CustId = @CustId					 
				
						SELECT 
							@ErrCode = 314, 
							@ErrMsg = 'Failed to update trader-grade history [Username = ' + @Username +']'
						RETURN
					END	
			
		END

		------#3. If @LastedGradeEffectiveDate >= today (furture) and @NewGrade (furture) = Previous Lasted Grade Name then update Grade and delete the future row of History
		IF @LastedGradeEffectiveDate >= @Today AND @NewGradeEffectiveDate >= @Today AND @NewGrade = ISNULL(@PreGrade ,0)
		BEGIN 
			----a.Update trader				
			UPDATE	dbo.Trader WITH (ROWLOCK, UPDLOCK) 
			SET		Grade			= @NewGrade,				
					GradeEffectiveDate = @PreGradeEffectiveDate,
					ModifiedDate	= Getdate(),
					ModifiedBy		= @UserId
			WHERE	CustId			= @CustId
						
				-- Check fail
				IF @@ERROR > 0
					BEGIN
						SELECT 
							@ErrCode = 312, 
							@ErrMsg = 'Failed to update trader [Username = ' + @Username +']'
						RETURN
					END

			----c.Update EndDate of the previous history
			UPDATE	dbo.TraderGrade_History WITH (ROWLOCK, UPDLOCK) 
			SET		EndDate = NULL
			WHERE	CustId = @CustId
					AND ISNULL(EndDate,'') = ISNULL(@PreGradeEndDate,'')					
	

			----b.Delete lasted trader-Grade history
			DELETE  dbo.TraderGrade_History WITH (ROWLOCK, UPDLOCK) 			
			WHERE	CustId = @CustId
					AND BeginDate = @LastedGradeEffectiveDate 
	 									 
				-- Check fail
				IF @@ERROR > 0
					BEGIN
						---rollback
						UPDATE	dbo.Trader WITH (ROWLOCK, UPDLOCK) 
						SET		Grade			= @OldGrade,				
								GradeEffectiveDate = @OldGradeEffectiveDate,
								ModifiedDate	= Getdate(),
								ModifiedBy		= @UserId
						WHERE	CustId = @CustId					 
				
						SELECT 
							@ErrCode = 315, 
							@ErrMsg = 'Failed to delete trader-grade history [Username = ' + @Username +']'
						RETURN
					END
			
		END
	END


-------------------------------------------------------------------------
	-- Write log after update			
	SET @xml = (
					SELECT
						@CustId				AS '@c',	
						@Username			AS '@n',
						@EmployeeId			AS '@e',
						@NewTeamId			AS '@t',
						@NewGrade			AS '@g',
						@NewTeamEffectiveDate AS '@dt',
						@NewGradeEffectiveDate AS '@dg'
					 FOR XML PATH('z'), ROOT('r')
				)

	SET @LogTraderData = REPLACE(CONVERT(NVARCHAR(MAX), @Xml), '" />', '"/"')

	SET @EndRun = GETDATE()
	SET @Duration = DATEDIFF(MILLISECOND, @StartRun, @EndRun) 
	
	EXEC	dbo.TGRS_WriteLog_RunSp
			@UserId		= @UserId,
			@SPName		= 'TGRS_Trader_Update',
			@LogDate	= @StartRun,
			@Duration	= @Duration,
			@ObjectId	= @CustId,
			@Data		= @LogTraderData,
			@OldData	= @LogTraderOldData

END
 

GO
GRANT EXECUTE ON [dbo].[TGRS_Trader_Update] TO [bodbTGRSNet]

