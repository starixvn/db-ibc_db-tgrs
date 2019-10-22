
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[TGRS_TargetedMargin_Update]
    @CreatorId				INT = 0,
    @TargetedMarginId		INT = 0,
    @Rate					MONEY = 0,
    
    @ErrCode				INT = 0 OUTPUT,
    @ErrMsg					NVARCHAR(200) = '' OUTPUT

/*
Created: 20160216@Long.Luu
Task : Update Targeted Margin Value
DB:  DBTGRS.bodb_TGRS

Revisions:
*/ 

AS
BEGIN
    SET NOCOUNT ON
    
    DECLARE 
	   @StartRun						DATETIME,
	   @EndRun							DATETIME,
	   @Duration						INT,
	   @LogTargetedMarginData			NVARCHAR(MAX),
	   @LogTargetedMarginOldData		NVARCHAR(MAX),	
	   @Xml								XML 		 

    SET @StartRun = GETDATE()
    -----------------------------------------------------------
    DECLARE @BettypeId		INT = 0
    DECLARE @OldRate		MONEY = 0

    SELECT @BettypeId = tm.BetType, @OldRate = tm.Rate
    FROM dbo.TargetedMargin tm WITH(NOLOCK)
    WHERE tm.TargetedMarginId = @TargetedMarginId
    	   
    IF @BettypeId = 0
	   BEGIN
		  SELECT	@ErrCode = 701
				,@ErrMsg = 'Targeted Margin is not existed. Please try again.'
		  RETURN
	   END
	
	UPDATE dbo.TargetedMargin
	SET Rate = @Rate
	WHERE TargetedMarginId = @TargetedMarginId
    
    INSERT INTO dbo.TargetedMargin_History (
			    TargetedMarginId,
			    BetType,
			    OldRate,
			    ModifiedDate,
			    ModifiedBy)
		 VALUES (
			    @TargetedMarginId,
			    @BettypeId,
			    @OldRate,
			    GETDATE(),
			    @CreatorId)
				
    IF @@ERROR > 0
	  BEGIN
		 SELECT	@ErrCode = 702
				,@ErrMsg = 'Update Targeted Margin value failed. Please try again.'
		 RETURN
	  END
    -----------------------------------------------------------
    SET @EndRun = GETDATE()
    SET @Duration = DATEDIFF(MILLISECOND, @StartRun, @EndRun)
    
    SET @xml = (
				SELECT							
				    @TargetedMarginId		AS '@l',
				    @BetTypeId				AS '@b',
				    @OldRate				AS '@v' 	
				    FOR XML PATH('z'), ROOT('r')
			 )

    SET @LogTargetedMarginData = REPLACE(CONVERT(NVARCHAR(MAX), @Xml), '" />', '"/"')
    
    SET @xml = (
				SELECT							
				    @TargetedMarginId		AS '@l',
				    @BetTypeId				AS '@b',
				    @Rate					AS '@v' 	
				    FOR XML PATH('z'), ROOT('r')
			 )

    SET @LogTargetedMarginOldData = REPLACE(CONVERT(NVARCHAR(MAX), @Xml), '" />', '"/"')
	 

    EXEC	dbo.TGRS_WriteLog_RunSp
		  @UserId		= @CreatorId,
		  @SPName		= 'TGRS_TargetedMargin_Update',
		  @LogDate		= @StartRun,
		  @Duration		= @Duration,
		  @ObjectId		= @TargetedMarginId,
		  @Data			= @LogTargetedMarginData,
		  @OldData		= @LogTargetedMarginOldData
END

