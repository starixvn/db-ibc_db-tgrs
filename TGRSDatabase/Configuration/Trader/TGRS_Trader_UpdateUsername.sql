
ALTER PROCEDURE [dbo].[TGRS_Trader_UpdateUsername]
	@CustId			INT,
	@NewUserName	VARCHAR(30),
	@UserId			INT,
	@ErrCode		INT = 0 OUTPUT,
	@ErrMsg			NVARCHAR(200) = '' OUTPUT

/*
Created: 20140513@Sophia
Task : Update Trader Username 
DB:  DBTGRS.bodb_TGRS

Revisions:
   
*/ 

AS
BEGIN
	SET NOCOUNT ON 	
	DECLARE @CustInfoId INT 

	--Check valid
	SELECT @CustInfoId = CustId FROM bodb02.dbo.CustInfo WITH (NOLOCK) WHERE Username = @NewUsername AND RoleID > 4
	IF ISNULL(@CustInfoId,0) <> @CustId
	BEGIN 
		SELECT  @ErrCode = 301,
				@ErrMsg = 'Username is invalid.'
		RETURN
	END 

	IF EXISTS ( SELECT TOP 1 1 FROM dbo.Trader WITH (NOLOCK) WHERE Username = @NewUsername AND CustId <> @CustID)
	BEGIN 
		SELECT  @ErrCode = 300,
				@ErrMsg = 'Username already exists.'
		RETURN
	END 
	
		 
	-- For write log
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
					SELECT  CustId				AS '@c',
							Username			AS '@n'					
					FROM	dbo.Trader WITH (NOLOCK)							
					WHERE	CustId = @CustId
					FOR XML PATH('z'),ROOT('r')
				)	 

	SET @LogTraderOldData = REPLACE(CONVERT(VARCHAR(MAX), @xml), '" />', '"/"')
	-- end write log					
		
	-- Update				
	UPDATE	dbo.Trader WITH (ROWLOCK, UPDLOCK) 
	SET		Username		= @NewUserName,			
			ModifiedDate	= Getdate(),
			ModifiedBy		= @UserId
	WHERE	CustId			= @CustId
	
	-- Check fail
	IF @@ERROR > 0
		BEGIN
			SELECT 
				@ErrCode = 308, 
				@ErrMsg = 'Failed to update trader username [Username = ' + @NewUserName +']'
			RETURN
		END


	-- Write log after update			
	SET @xml = (
					SELECT
						@CustId				AS '@c',	
						@NewUserName		AS '@n'						
					 FOR XML PATH('z'), ROOT('r')
				)

	SET @LogTraderData = REPLACE(CONVERT(NVARCHAR(MAX), @Xml), '" />', '"/"')

	SET @EndRun = GETDATE()
	SET @Duration = DATEDIFF(MILLISECOND, @StartRun, @EndRun) 
	
	EXEC	dbo.TGRS_WriteLog_RunSp
			@UserId		= @UserId,
			@SPName		= 'TGRS_Trader_UpdateUsername',
			@LogDate	= @StartRun,
			@Duration	= @Duration,
			@ObjectId	= @CustId,
			@Data		= @LogTraderData,
			@OldData	= @LogTraderOldData


END 
	
	
GO
GRANT EXECUTE ON [dbo].[TGRS_Trader_UpdateUsername] TO [bodbTGRSNet]



