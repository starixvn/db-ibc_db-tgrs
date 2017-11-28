CREATE PROCEDURE [dbo].[TGRS_Trader_Insert]
	@Username		VARCHAR (30),
	@EmployeeId		NVARCHAR(20),
	@TeamId			SMALLINT,
	@Grade			SMALLINT,
	@Shift INT,
	@Remark NVARCHAR(4000),
	@UserId			INT,
	@ErrCode		INT = 0 OUTPUT,
	@ErrMsg			NVARCHAR(200) = '' OUTPUT

/*
Created: 20140512@Sophia
Task : Insert new trader
DB:  DBTGRS.bodb_TGRS

Revisions:
   - 20171129@Simon: add shift + remark parameter
*/ 

AS
BEGIN
	SET NOCOUNT ON 	
	DECLARE @CustId INT, @CreatedDate DATETIME

	--Check valid
	IF EXISTS ( SELECT TOP 1 1 FROM dbo.Trader WITH (NOLOCK) WHERE Username = @Username)
	BEGIN 
		SELECT  @ErrCode = 300,
				@ErrMsg = 'Username already exists.'
		RETURN
	END 

	SELECT @CustId = CustId FROM bodb02.dbo.CustInfo WITH (NOLOCK) WHERE Username = @Username AND RoleID > 4
	IF ISNULL(@CustID,0) = 0
	BEGIN 
		SELECT  @ErrCode = 301,
				@ErrMsg = 'Username is invalid.'
		RETURN
	END 

	IF EXISTS ( SELECT TOP 1 1 FROM dbo.Trader WITH (NOLOCK) WHERE EmployeeId = @EmployeeId)
	BEGIN 
		SELECT  @ErrCode = 302,
				@ErrMsg = 'Employee Id already exists.'
		RETURN
	END 
	 
	IF @Username = ''
	BEGIN 
		SELECT  @ErrCode = 303,
				@ErrMsg = 'Employee Id is invalid.'
		RETURN
	END 
		 	 
	
	IF NOT EXISTS ( SELECT TOP 1 1 FROM dbo.Team WITH (NOLOCK) WHERE TeamId = @TeamId)
	BEGIN 
		SELECT  @ErrCode = 304,
				@ErrMsg = 'Team is invalid.'
		RETURN
	END 


	-- For write log
	DECLARE 
		@StartRun					DATETIME,
		@EndRun						DATETIME,
		@Duration					INT,
		@LogTraderData				NVARCHAR(MAX),	
		@Xml						XML 

	SET @StartRun = GETDATE()

	SET @CreatedDate = GETDATE()

	-- Insert trader 
	INSERT INTO	dbo.Trader (
							 CustId
							,Username
							,EmployeeId
							,TeamId
							,Grade
							,CreatedDate
							,CreatedBy
							,ModifiedDate
							,ModifiedBy
							,TeamEffectiveDate
							,GradeEffectiveDate
							,[Shift]
							,ShiftEffectiveDate
							,Remark
							)
					VALUES (
							 @CustId
							,@Username
							,@EmployeeId
							,@TeamId
							,@Grade
							,@CreatedDate
							,@UserId
							,NULL
							,NULL							
							,@CreatedDate
							,@CreatedDate
							,@Shift
							,@CreatedDate
							,@Remark
							)

	-- Check fail
	IF @@ERROR > 0
		BEGIN
			SELECT 
				@ErrCode = 305, 
				@ErrMsg = 'Failed to add new trader [Username = ' + @Username +']'
			RETURN
		END


	-- Insert trader_team history
	INSERT INTO	dbo.TraderTeam_History (
							CustId
							,TeamId							
							,BeginDate
							,EndDate
							)
					VALUES (
							 @CustId
							,@TeamId											
							,@CreatedDate
							,NULL
							)	

	-- Check fail
	IF @@ERROR > 0
		BEGIN
			SELECT 
				@ErrCode = 306, 
				@ErrMsg = 'Failed to add new trader-team history [Username = ' + @Username +']'
			RETURN
		END
		 
	
	-- Insert trader_rade history
	INSERT INTO	dbo.TraderGrade_History (
							CustId
							,Grade							
							,BeginDate
							,EndDate
							)
					VALUES (
							 @CustId
							,@Grade										
							,@CreatedDate
							,NULL
							)	

	-- Check fail
	IF @@ERROR > 0
		BEGIN
			SELECT 
				@ErrCode = 307, 
				@ErrMsg = 'Failed to add new trader-grade history [Username = ' + @Username +']'
			RETURN
		END

	-- Insert trader_shift history
	INSERT INTO	dbo.TraderShift_History(
							CustId
							,ShiftId							
							,BeginDate
							,EndDate
							)
					VALUES (
							 @CustId
							,@Shift											
							,@CreatedDate
							,NULL
							)	

	-- Check fail
	IF @@ERROR > 0
		BEGIN
			SELECT 
				@ErrCode = 307, 
				@ErrMsg = 'Failed to add new trader-shift history [Username = ' + @Username +']'
			RETURN
		END
	-- Write log 
	SET @xml = (
					SELECT
						@CustId				AS '@c',	
						@Username			AS '@n',
						@EmployeeId			AS '@e',
						@TeamId				AS '@t',
						@Grade				AS '@g',
						@CreatedDate		AS '@dt',
						@CreatedDate		AS '@dg',
						@Shift AS 's',
						@CreatedDate AS 'ds',
						@Remark AS 'r'
					 FOR XML PATH('z'), ROOT('r')
				)

	SET @LogTraderData = REPLACE(CONVERT(NVARCHAR(MAX), @Xml), '" />', '"/"')

	SET @EndRun = GETDATE()
	SET @Duration = DATEDIFF(MILLISECOND, @StartRun, @EndRun) 

	
	EXEC	dbo.TGRS_WriteLog_RunSp
			@UserId		= @UserId,
			@SPName		= 'TGRS_Trader_Insert',
			@LogDate	= @StartRun,
			@Duration	= @Duration,
			@ObjectId	= @CustId,
			@Data		= @LogTraderData,
			@OldData	= NULL

		
END

/*
GO
GRANT EXECUTE ON [dbo].[TGRS_Trader_Insert] TO [bodbTGRSNet]
GO
GRANT VIEW DEFINITION ON [dbo].[TGRS_Trader_Insert] TO [bodbTGRSNet]
GO
*/