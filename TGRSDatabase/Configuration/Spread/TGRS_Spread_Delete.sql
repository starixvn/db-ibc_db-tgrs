
GO


SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[TGRS_Spread_Delete]
    @CreatorId		INT = 0,
    @LeagueId		BIGINT = 0,
    @BetTypeId		SMALLINT = 0,
    
    @ErrCode		INT = 0 OUTPUT,
    @ErrMsg		NVARCHAR(200) = '' OUTPUT

/*
Created: 20160122@Aaron
Task : Update Spread to Zero
DB:  DBTGRS.bodb_TGRS

Revisions:
*/ 

AS
BEGIN
    SET NOCOUNT ON
    
    DECLARE 
	   @StartRun					DATETIME,
	   @EndRun						DATETIME,
	   @Duration					INT,
	   @LogSpreadData				NVARCHAR(MAX),
	   @LogSpreadOldData			NVARCHAR(MAX),	
	   @Xml							XML 		 

    SET @StartRun = GETDATE()
    -----------------------------------------------------------
    DECLARE @OldSpread SMALLINT = 0
    
    SELECT @OldSpread = s.Spread FROM dbo.Spread s WITH(NOLOCK)
    WHERE s.LeagueId = @LeagueId AND s.BetType = @BetTypeId
	   
    IF @OldSpread IS NULL
	   BEGIN
		SELECT	@ErrCode = 601
				,@ErrMsg = 'Spread is not existed. Please try again.'
		RETURN
	   END
    
    UPDATE dbo.Spread
    SET Spread = 0
    WHERE LeagueId = @LeagueId AND BetType = @BetTypeId
        
    INSERT INTO Spread_History (
			LeagueId,
			BetType,
			OldSpread,
			ModifiedDate,
			ModifiedBy)
    VALUES (
			@LeagueId,
			@BetTypeId,
			@OldSpread,
			GETDATE(),
			@CreatorId)
			
    IF @@ERROR > 0
	   BEGIN
		   SELECT	    @ErrCode = 603
				    ,@ErrMsg = 'Delete Spread failed. Please try again.'
		   RETURN
	   END
    -----------------------------------------------------------
    SET @EndRun = GETDATE()
    SET @Duration = DATEDIFF(MILLISECOND, @StartRun, @EndRun)
    
    SET @xml = (
				SELECT							
				    @LeagueId			AS '@l',
				    @BetTypeId			AS '@b',
				    0					AS '@v' 	
				    FOR XML PATH('z'), ROOT('r')
			 )

    SET @LogSpreadData = REPLACE(CONVERT(NVARCHAR(MAX), @Xml), '" />', '"/"')
    
    SET @xml = (
				SELECT							
				    @LeagueId			AS '@l',
				    @BetTypeId			AS '@b',
				    @OldSpread			AS '@v' 	
				    FOR XML PATH('z'), ROOT('r')
			 )

    SET @LogSpreadOldData = REPLACE(CONVERT(NVARCHAR(MAX), @Xml), '" />', '"/"')
	 
    EXEC	dbo.TGRS_WriteLog_RunSp
		  @UserId		= @CreatorId,
		  @SPName		= 'TGRS_Spread_Delete',
		  @LogDate		= @StartRun,
		  @Duration		= @Duration,
		  @ObjectId		= @BetTypeId,
		  @Data			= @LogSpreadData,
		  @OldData		= @LogSpreadOldData			 
END
GO

GO
GRANT EXECUTE ON [dbo].[TGRS_Spread_Delete] TO [bodbTGRSNet]
GO
GRANT VIEW DEFINITION ON [dbo].[TGRS_Spread_Delete] TO [bodbTGRSNet]
GO

