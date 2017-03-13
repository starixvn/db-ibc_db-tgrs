
SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

/****** Object:  Stored Procedure dbo.TGRS_OS_RegionInsert    Script Date: 2/22/2017 10:52:57 AM ******/

CREATE PROCEDURE [dbo].[TGRS_OS_RegionInsert] 
	 @RegionName NVARCHAR(50)
	,@UserId INT
	
	,@ErrCode INT = 0 OUTPUT
	,@ErrMsg NVARCHAR(200) = '' OUTPUT
	
	/*
	Created: 20170215@Aaron
	Task : Insert new OS region
	DB:  DBTGRS.bodb_TGRS

	Revisions:
	   
	*/
AS
BEGIN
	SET NOCOUNT ON

	IF EXISTS (
			SELECT TOP 1 1
			FROM dbo.OSRegion WITH (NOLOCK)
			WHERE RegionName = @RegionName
			)
	BEGIN
		SELECT @ErrCode = 6501
			,@ErrMsg = 'The region name already exists.'

		RETURN
	END

	INSERT INTO dbo.OSRegion (
		[RegionName]
		,[CreatedBy]
		,[CreatedDate]
		)
	VALUES (
		@RegionName
		,@UserId
		,GETDATE()
		)

	IF @@error <> 0
	BEGIN
		SELECT @ErrMsg = 'Insert new region failed. Please try again.'
			,@ErrCode = 6502

		DELETE
		FROM dbo.OSRegion WITH (ROWLOCK)
		WHERE RegionName = @RegionName

		RETURN
	END

	DECLARE @Details NVARCHAR(4000)
		,@SPName NVARCHAR(50)

	SELECT @SPName = OBJECT_NAME(@@ProcID)

	SELECT @Details = 'Add new region with 
	RegionName=' + dbo.SPU_ToString(@RegionName) + ',  
	Creator=' + dbo.SPU_ToString(@UserId)

	EXEC [dbo].TGRS_OS_WriteLog 
		 @LogTypeId = 65
		,@CreatorId = @UserId
		,@SPName = @SPName
		,@Details = @Details
END

/*
GO
GRANT EXECUTE ON [dbo].[TGRS_OS_RegionInsert] TO [bodbTGRSNet]
GO
GRANT VIEW DEFINITION ON [dbo].[TGRS_OS_RegionInsert] TO [bodbTGRSNet]
GO
*/

GO

SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO


GO 
 GRANT EXECUTE ON [dbo].[TGRS_OS_RegionInsert] TO [bodbTGRSNet]
GO 
 GRANT VIEW DEFINITION ON [dbo].[TGRS_OS_RegionInsert] TO [bodbTGRSNet]
GO 
