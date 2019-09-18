
GO


SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[TGRS_Spread_UpdateSingle]
    @CreatorId		INT = 0,
    @LeagueId		INT = 0,
    @BetTypeId		SMALLINT = 0,
    @Spread			SMALLINT = 0,
    
    @ErrCode		INT = 0 OUTPUT,
    @ErrMsg			NVARCHAR(200) = '' OUTPUT

/*
Created: 20160122@Aaron
Task : Update Spread
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
    
    IF @OldSpread = @Spread
	   BEGIN
		SELECT	@ErrCode = 601
				,@ErrMsg = 'New spread equals old spread. Please try again.'
		RETURN
	   END
	   
    IF @OldSpread IS NULL
	   BEGIN
		  SELECT	@ErrCode = 602
				,@ErrMsg = 'Spread is not existed. Please try again.'
		  RETURN
	   END
    
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
		 SELECT	@ErrCode = 603
				,@ErrMsg = 'Update Spread failed. Please try again.'
		 RETURN
	  END
    -----------------------------------------------------------
    SET @EndRun = GETDATE()
    SET @Duration = DATEDIFF(MILLISECOND, @StartRun, @EndRun)
    
    SET @xml = (
				SELECT							
				    @LeagueId			AS '@l',
				    @BetTypeId			AS '@b',
				    @Spread				AS '@v' 	
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
		  @SPName		= 'TGRS_Spread_UpdateSingle',
		  @LogDate		= @StartRun,
		  @Duration		= @Duration,
		  @ObjectId		= @BetTypeId,
		  @Data			= @LogSpreadData,
		  @OldData		= @LogSpreadOldData
END
GO


GO
GRANT EXECUTE ON [dbo].[TGRS_Spread_UpdateSingle] TO [bodbTGRSNet]
GO
GRANT VIEW DEFINITION ON [dbo].[TGRS_Spread_UpdateSingle] TO [bodbTGRSNet]
GO
