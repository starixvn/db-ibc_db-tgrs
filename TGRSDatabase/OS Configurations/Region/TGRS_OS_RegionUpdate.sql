
SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

/****** Object:  Stored Procedure dbo.TGRS_OS_RegionUpdate    Script Date: 2/22/2017 10:52:57 AM ******/

CREATE PROCEDURE [dbo].[TGRS_OS_RegionUpdate] 
	 @RegionId INT
	,@RegionName NVARCHAR(50)
	,@UserId INT
	
	,@ErrCode INT = 0 OUTPUT
	,@ErrMsg NVARCHAR(200) = '' OUTPUT
	
	/*
	Created: 20170215@Aaron
	Task : Update OS region
	DB:  DBTGRS.bodb_TGRS

	Revisions:	   
	*/
AS
BEGIN
	SET NOCOUNT ON
	
	IF EXISTS (
			SELECT TOP 1 1
			FROM dbo.OSRegion WITH (NOLOCK)
			WHERE RegionId = @RegionId AND RegionName = @RegionName
			)
	BEGIN
		SELECT @ErrCode = 0
			,@ErrMsg = 'There is no change!'

		RETURN
	END

	IF NOT EXISTS (
			SELECT TOP 1 1
			FROM dbo.OSRegion WITH (NOLOCK)
			WHERE RegionId = @RegionId
			)
	BEGIN
		SELECT @ErrCode = 6601
			,@ErrMsg = 'The region not existed. Please choose another one!'

		RETURN
	END
	
	IF EXISTS (
		SELECT TOP 1 1
		FROM dbo.OSRegion WITH (NOLOCK)
		WHERE RegionName = @RegionName
			AND RegionId <> @RegionId
		)
	BEGIN
		SELECT @ErrCode = 6602
			,@ErrMsg = 'Region name existed.'

		RETURN
	END
 
	UPDATE dbo.OSRegion WITH (ROWLOCK, UPDLOCK)
	SET [RegionName] = @RegionName
		,[ModifiedDate] = GETDATE()
		,[ModifiedBy] = @UserId
	WHERE RegionId = @RegionId

	IF @@error <> 0
	BEGIN
		SELECT @ErrMsg = 'Update region failed. Please try again.'
			,@ErrCode = 6603

		RETURN
	END

	DECLARE @Details NVARCHAR(4000)
		,@SPName NVARCHAR(50)

	SELECT @SPName = OBJECT_NAME(@@ProcID)

	SELECT @Details = 'Update region with 
	RegionId=' + dbo.SPU_ToString(@RegionId) + ',
	RegionName=' + dbo.SPU_ToString(@RegionName) + ',  
	Creator=' + dbo.SPU_ToString(@UserId)

	EXEC [dbo].TGRS_OS_WriteLog 
		 @LogTypeId = 66
		,@CreatorId = @UserId
		,@SPName = @SPName
		,@Details = @Details
END

/*
GO
GRANT EXECUTE ON [dbo].[TGRS_OS_RegionUpdate] TO [bodbTGRSNet]
GO
GRANT VIEW DEFINITION ON [dbo].[TGRS_OS_RegionUpdate] TO [bodbTGRSNet]
GO
*/
GO

SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO


GO 
 GRANT EXECUTE ON [dbo].[TGRS_OS_RegionUpdate] TO [bodbTGRSNet]
GO 
 GRANT VIEW DEFINITION ON [dbo].[TGRS_OS_RegionUpdate] TO [bodbTGRSNet]
GO 
