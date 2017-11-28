CREATE PROCEDURE [dbo].[TGRS_Trader_Update]
	@CustId			INT,	
	@NewTeamId		SMALLINT = NULL,
	@NewGrade		SMALLINT = NULL,
	@NewTeamEffectiveDate	DATE = NULL,
	@NewGradeEffectiveDate	DATE = NULL,
	@NewShift INT = NULL,
	@NewShiftEffectiveDate DATE = NULL,
	@NewRemark NVARCHAR(4000),
	@UserId			INT,
	@ErrCode		INT = 0 OUTPUT,
	@ErrMsg			NVARCHAR(200) = '' OUTPUT

/*
Created: 20140512@Sophia
Task : Update trader
DB:  DBTGRS.bodb_TGRS

Revisions:
			- 20160325@Aaron: Bug fixes on updating Grade and refactor the SP.
			- 20171127@Simon: Add shift + remark parameter
*/ 

AS
BEGIN
	SET NOCOUNT ON;
	
	--GET CURRENT INFO
	DECLARE @Username		VARCHAR(30),
			@EmployeeId		NVARCHAR(20),
			@OldTeamId		INT,
			@OldGrade		INT,
			@OldTeamEffectiveDate DATE,
			@OldGradeEffectiveDate DATE,
			@OldShift INT,
			@OldShiftEffectiveDate DATE,
			@OldRemark NVARCHAR(4000)

	SELECT  @Username	= Username,
			@EmployeeId	= EmployeeId,
			@OldTeamId	= TeamId, 
			@OldGrade	= Grade,
			@OldTeamEffectiveDate = TeamEffectiveDate,
			@OldGradeEffectiveDate = GradeEffectiveDate,
			@OldShift = [Shift],
			@OldShiftEffectiveDate = ShiftEffectiveDate,
			@OldRemark = Remark
	FROM	dbo.Trader WITH (NOLOCK)
	WHERE	CustId = @CustId
	--END
	
	--CHECK WHAT IS UPDATING
	DECLARE @IsTeamUpdate BIT = 0, @IsGradeUpdate BIT = 0, @IsShiftUpdate BIT = 0, @Today DATE = GETDATE()
	
	IF @NewTeamId IS NOT NULL AND @NewTeamEffectiveDate IS NOT NULL
	BEGIN 
		SET @IsTeamUpdate = 1
	
		IF NOT EXISTS (SELECT TOP 1 1 FROM dbo.Team WITH (NOLOCK) WHERE TeamId = @NewTeamId)
		BEGIN 
			SELECT  @ErrCode = 304,
					@ErrMsg = 'Team is invalid.'
			RETURN
		END
		
		IF @OldTeamEffectiveDate < @Today AND @NewTeamId = @OldTeamId 
		BEGIN 
			SELECT @ErrCode = 309,
				   @ErrMsg = 'New team is the same with the previous team.'
			RETURN
		END
	END 

	IF @NewGrade IS NOT NULL AND @NewGradeEffectiveDate IS NOT NULL
	BEGIN 
		SET @IsGradeUpdate = 1
	
		IF @OldGradeEffectiveDate < @Today AND @NewGrade = @OldGrade 
		BEGIN 
			SELECT @ErrCode = 310,
				   @ErrMsg = 'New grade is the same with the previous grade.'
			RETURN
		END
	END 
	
	IF @NewShift IS NOT NULL AND @NewShiftEffectiveDate IS NOT NULL
		BEGIN 
			SET @IsShiftUpdate = 1
	
			IF NOT EXISTS (SELECT TOP 1 1 FROM dbo.[Shift] WITH (NOLOCK) WHERE ShiftId = @NewShift)
			BEGIN 
				SELECT  @ErrCode = 304,
						@ErrMsg = 'Shift is invalid.'
				RETURN
			END
		
			IF @OldShiftEffectiveDate < @Today AND @NewShift = @OldShift 
			BEGIN 
				SELECT @ErrCode = 309,
					   @ErrMsg = 'New shift is the same with the previous shift.'
				RETURN
			END
		END 

	IF @IsTeamUpdate = 0 AND @IsGradeUpdate = 0 AND @IsShiftUpdate = 0
	BEGIN 
		SELECT @ErrCode = 311,
			   @ErrMsg = 'There is no change.'
		RETURN
	END
	--END
	
	--WRITE LOG PURPOSE
	DECLARE 
		@StartRun					DATETIME,
		@EndRun						DATETIME,
		@Duration					INT,
		@LogTraderData				NVARCHAR(MAX),	
		@LogTraderOldData			NVARCHAR(MAX),	
		@Xml						XML		 

	SET @StartRun = GETDATE()
		
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
	--END
	
	--VARIABLES FOR CHECKING PURPOSE
	DECLARE @LatestTeamId SMALLINT, @LatestTeamEffectiveDate DATE,   
			@LatestGrade TINYINT, @LatestGradeEffectiveDate DATE, 
			@LatestShift INT, @LatestShiftEffectiveDate DATE,
			@PreTeamId SMALLINT, @PreTeamEffectiveDate DATE,@PreTeamEndDate DATE,   
			@PreGrade TINYINT, @PreGradeEffectiveDate DATE, @PreGradeEndDate DATE,
			@PreShift INT, @PreShiftEffectiveDate DATE, @PreShiftEndDate DATE
			
	-------------------------UPDATE------------------------------------------------
	
	--UPDATE TEAM - HISTORY
	IF @IsTeamUpdate = 1
	BEGIN 		
		---Latest info
		SELECT 	TOP 1 
				@LatestTeamId = TeamId, 
				@LatestTeamEffectiveDate = BeginDate 
		FROM	dbo.TraderTeam_History WITH (NOLOCK)
		WHERE	CustId = @CustId
		ORDER BY BeginDate DESC
				
		---Previous latest info
		SELECT 	TOP 1 
				@PreTeamId = TeamId, 
				@PreTeamEffectiveDate = BeginDate,
				@PreTeamEndDate = EndDate 
		FROM	dbo.TraderTeam_History WITH (NOLOCK)
		WHERE	CustId = @CustId 
				AND EndDate IS NOT NULL
		ORDER BY EndDate DESC
	
		IF @LatestTeamEffectiveDate < @Today AND @NewTeamId <> @LatestTeamId  
		BEGIN
			----Update EndDate of the Last history
			UPDATE	dbo.TraderTeam_History WITH (ROWLOCK, UPDLOCK) 
			SET		EndDate = DATEADD (dd, -1, @NewTeamEffectiveDate)
			WHERE	CustId = @CustId
					AND BeginDate = @LatestTeamEffectiveDate

			----Insert trader-team history
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
			----Error
			IF @@ERROR > 0
			BEGIN				
				SELECT 
					@ErrCode = 313, 
					@ErrMsg = 'Failed to add new trader-team history [Username = ' + @Username +']'
				RETURN
			END	
		END
		
		IF @LatestTeamEffectiveDate >= @Today AND @NewTeamId <> ISNULL(@PreTeamId,0)
		BEGIN 
			----Update EndDate of the previous history
			UPDATE	dbo.TraderTeam_History WITH (ROWLOCK, UPDLOCK) 
			SET		EndDate = DATEADD (dd, -1, @NewTeamEffectiveDate)
			WHERE	CustId = @CustId
					AND ISNULL(EndDate,'') = ISNULL(@PreTeamEndDate,'')
	
			----Update trader-team history
			UPDATE	dbo.TraderTeam_History WITH (ROWLOCK, UPDLOCK) 
			SET		TeamId = @NewTeamId,
					BeginDate = @NewTeamEffectiveDate,
					EndDate = NULL
			WHERE	CustId = @CustId
					AND BeginDate = @LatestTeamEffectiveDate 
	 									 
			----Error
			IF @@ERROR > 0
			BEGIN
				SELECT 
					@ErrCode = 314, 
					@ErrMsg = 'Failed to update trader-team history [Username = ' + @Username +']'
				RETURN
			END		
		
		END
		
		IF @LatestTeamEffectiveDate >= @Today AND @NewTeamId = ISNULL(@PreTeamId,0)
		BEGIN
			----Update EndDate of the previous history
			UPDATE	dbo.TraderTeam_History WITH (ROWLOCK, UPDLOCK) 
			SET		EndDate = NULL
			WHERE	CustId = @CustId
					AND ISNULL(EndDate,'') = ISNULL(@PreTeamEndDate,'')

			----Delete Latest trader-team history
			DELETE  dbo.TraderTeam_History WITH (ROWLOCK, UPDLOCK)
			WHERE	CustId = @CustId
					AND BeginDate = @LatestTeamEffectiveDate 
	 									 
			----Error
			IF @@ERROR > 0
			BEGIN
				SELECT 
					@ErrCode = 315, 
					@ErrMsg = 'Failed to delete trader-team history [Username = ' + @Username +']'
				RETURN
			END
			
			SET @NewTeamEffectiveDate = @PreTeamEffectiveDate
		END
	END 
	
	--UPDATE GRADE - HISTORY
	IF @IsGradeUpdate = 1
	BEGIN		
		---Latest info 
		SELECT 	TOP 1 
				@LatestGrade = Grade, 
				@LatestGradeEffectiveDate = BeginDate
		FROM	dbo.TraderGrade_History WITH (NOLOCK)
		WHERE	CustId = @CustId
		ORDER BY BeginDate DESC
			
		---Previous latest info
		SELECT 	TOP 1 
				@PreGrade = Grade, 
				@PreGradeEffectiveDate = BeginDate,
				@PreGradeEndDate =  EndDate 
		FROM	dbo.TraderGrade_History WITH (NOLOCK)
		WHERE	CustId = @CustId 
				AND EndDate IS NOT NULL
		ORDER BY EndDate DESC
		
		IF @LatestGradeEffectiveDate < @Today AND @NewGrade <> @LatestGrade 
		BEGIN
			---Update EndDate of the previous history
			UPDATE	dbo.TraderGrade_History WITH (ROWLOCK, UPDLOCK) 
			SET		EndDate = DATEADD (dd, -1, @NewGradeEffectiveDate)
			WHERE	CustId = @CustId
					AND BeginDate = @LatestGradeEffectiveDate

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
			IF @@ERROR > 0
			BEGIN		
				SELECT 
					@ErrCode = 313, 
					@ErrMsg = 'Failed to add new trader-Grade history [Username = ' + @Username +']'
				RETURN
			END
		END
	
		IF @LatestGradeEffectiveDate >= @Today AND @NewGrade <> ISNULL(@PreGrade ,0)
		BEGIN 
			----Update EndDate of the previous history
			UPDATE	dbo.TraderGrade_History WITH (ROWLOCK, UPDLOCK) 
			SET		EndDate = DATEADD (dd, -1, @NewGradeEffectiveDate)
			WHERE	CustId = @CustId
					AND ISNULL(EndDate,'') = ISNULL(@PreGradeEndDate,'')
	
			----Update trader-Grade history
			UPDATE	dbo.TraderGrade_History WITH (ROWLOCK, UPDLOCK) 
			SET		Grade = @NewGrade,
					BeginDate = @NewGradeEffectiveDate,
					EndDate = NULL
			WHERE	CustId = @CustId
					AND BeginDate = @LatestGradeEffectiveDate 
	 									 
			IF @@ERROR > 0
			BEGIN			
				SELECT 
					@ErrCode = 314, 
					@ErrMsg = 'Failed to update trader-grade history [Username = ' + @Username +']'
				RETURN
			END	
			
		END
		
		IF @LatestGradeEffectiveDate >= @Today AND @NewGrade = ISNULL(@PreGrade ,0)
		BEGIN			
			----Update EndDate of the previous history
			UPDATE	dbo.TraderGrade_History WITH (ROWLOCK, UPDLOCK) 
			SET		EndDate = NULL
			WHERE	CustId = @CustId
					AND ISNULL(EndDate,'') = ISNULL(@PreGradeEndDate,'')
	
			----Delete Latest trader-Grade history
			DELETE  dbo.TraderGrade_History WITH (ROWLOCK, UPDLOCK)
			WHERE	CustId = @CustId
					AND BeginDate = @LatestGradeEffectiveDate 

			IF @@ERROR > 0
			BEGIN				
				SELECT 
					@ErrCode = 315, 
					@ErrMsg = 'Failed to delete trader-grade history [Username = ' + @Username +']'
				RETURN
			END
			
			SET @NewGradeEffectiveDate = @PreGradeEffectiveDate
		END
	END

	--UPDATE SHIFT - HISTORY
	IF @IsShiftUpdate = 1
	BEGIN 		
		---Latest info
		SELECT 	TOP 1 
				@LatestShift = ShiftId, 
				@LatestShiftEffectiveDate = BeginDate 
		FROM	dbo.TraderShift_History WITH (NOLOCK)
		WHERE	CustId = @CustId
		ORDER BY BeginDate DESC
				
		---Previous latest info
		SELECT 	TOP 1 
				@PreShift = ShiftId, 
				@PreShiftEffectiveDate = BeginDate,
				@PreShiftEndDate = EndDate 
		FROM	dbo.TraderShift_History WITH (NOLOCK)
		WHERE	CustId = @CustId 
				AND EndDate IS NOT NULL
		ORDER BY EndDate DESC
		
		SELECT @LatestShift AS '1', @NewShift AS '2', @LatestShiftEffectiveDate AS '3'

		IF (@LatestShiftEffectiveDate < @Today OR @LatestShiftEffectiveDate IS NULL) AND @NewShift <> ISNULL(@LatestShift, 0)
		BEGIN
			----Update EndDate of the Last history
			UPDATE	dbo.TraderShift_History WITH (ROWLOCK, UPDLOCK) 
			SET		EndDate = DATEADD (dd, -1, @NewShiftEffectiveDate)
			WHERE	CustId = @CustId
					AND BeginDate = @LatestShiftEffectiveDate

			----Insert trader-shift history
			INSERT INTO	dbo.TraderShift_History (
								CustId
								,ShiftId
								,BeginDate
								,EndDate
								)
						VALUES (
								 @CustId
								,@NewShift	
								,@NewShiftEffectiveDate
								,NULL
								)			
			----Error
			IF @@ERROR > 0
			BEGIN				
				SELECT 
					@ErrCode = 313, 
					@ErrMsg = 'Failed to add new trader-shift history [Username = ' + @Username +']'
				RETURN
			END	
		END
		
		IF @LatestShiftEffectiveDate  >= @Today AND @NewShift <> ISNULL(@PreShift, 0)
		BEGIN 
			----Update EndDate of the previous history
			UPDATE	dbo.TraderShift_History WITH (ROWLOCK, UPDLOCK) 
			SET		EndDate = DATEADD (dd, -1, @NewShiftEffectiveDate)
			WHERE	CustId = @CustId
					AND ISNULL(EndDate,'') = ISNULL(@PreShiftEndDate,'')
	
			----Update trader-shift history
			UPDATE	dbo.TraderShift_History WITH (ROWLOCK, UPDLOCK) 
			SET		ShiftId = @NewShift,
					BeginDate = @NewShiftEffectiveDate,
					EndDate = NULL
			WHERE	CustId = @CustId
					AND BeginDate = @LatestShiftEffectiveDate 
	 									 
			----Error
			IF @@ERROR > 0
			BEGIN
				SELECT 
					@ErrCode = 314, 
					@ErrMsg = 'Failed to update trader-shift history [Username = ' + @Username +']'
				RETURN
			END		
		
		END
		
		IF @LatestShiftEffectiveDate  >= @Today AND @NewShift  = ISNULL(@PreShift,0)
		BEGIN
			----Update EndDate of the previous history
			UPDATE	dbo.TraderShift_History WITH (ROWLOCK, UPDLOCK) 
			SET		EndDate = NULL
			WHERE	CustId = @CustId
					AND ISNULL(EndDate,'') = ISNULL(@PreShiftEndDate,'')

			----Delete Latest trader-shift history
			DELETE  dbo.TraderShift_History WITH (ROWLOCK, UPDLOCK)
			WHERE	CustId = @CustId
					AND BeginDate = @LatestShiftEffectiveDate 
	 									 
			----Error
			IF @@ERROR > 0
			BEGIN
				SELECT 
					@ErrCode = 315, 
					@ErrMsg = 'Failed to delete trader-shift history [Username = ' + @Username +']'
				RETURN
			END
			
			SET @NewShiftEffectiveDate  = @PreShiftEffectiveDate
		END
	END 

	--UPDATE TRADER
	IF @IsTeamUpdate = 0
	BEGIN 
		SELECT	@NewTeamId = @OldTeamId,
				@NewTeamEffectiveDate = @OldTeamEffectiveDate
	END
	
	IF @IsGradeUpdate = 0
	BEGIN 
		SELECT	@NewGrade = @OldGrade,
				@NewGradeEffectiveDate = @OldGradeEffectiveDate
	END

	IF @IsShiftUpdate = 0
	BEGIN 
		SELECT	
				@NewShift  = @OldShift,
				@NewShiftEffectiveDate  = @OldShiftEffectiveDate
	END
	
	UPDATE	dbo.Trader WITH (ROWLOCK, UPDLOCK) 
	SET		TeamId			= @NewTeamId,
			TeamEffectiveDate = @NewTeamEffectiveDate,
			Grade = @NewGrade,
			GradeEffectiveDate = @NewGradeEffectiveDate,
			ModifiedDate	= Getdate(),
			ModifiedBy		= @UserId,
			[Shift] = @NewShift,
			ShiftEffectiveDate = @NewShiftEffectiveDate,
			Remark = @NewRemark
	WHERE	CustId			= @CustId
			
	IF @@ERROR > 0
	BEGIN
		SELECT 
			@ErrCode = 312, 
			@ErrMsg = 'Failed to update trader [Username = ' + @Username +']'
		RETURN
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
						@NewGradeEffectiveDate AS '@dg',
						@NewShift AS '@s',
						@NewShiftEffectiveDate AS '@ds',
						@NewRemark AS '@r'
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

/*
GO
GRANT EXECUTE ON [dbo].[TGRS_Trader_Update] TO [bodbTGRSNet]
GO
GRANT VIEW DEFINITION ON [dbo].[TGRS_Trader_Update] TO [bodbTGRSNet]
GO
*/