
SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

/****** Object:  Stored Procedure dbo.TGRS_OS_LeagueRegionUpdate    Script Date: 2/22/2017 10:52:57 AM ******/

CREATE PROCEDURE [dbo].[TGRS_OS_LeagueRegionUpdate] 
	 @LeagueId INT
	,@RegionId INT
	,@CreatorId INT
	
	,@ErrCode INT = 0 OUTPUT
	,@ErrMsg NVARCHAR(200) = '' OUTPUT
	
	/*
	Created: 20170217@Aaron
	Task : Insert new OS league region
	DB:  DBTGRS.bodb_TGRS

	Revisions:
	   
	*/
AS
BEGIN
	SET NOCOUNT ON

	IF NOT EXISTS (
			SELECT TOP 1 1
			FROM dbo.OSLeagueRegion WITH (NOLOCK)
			WHERE LeagueId = @LeagueId
			)
	BEGIN
		SELECT @ErrCode = 7201
			,@ErrMsg = 'The league ID not existed.'

		RETURN
	END

	UPDATE dbo.OSLeagueRegion WITH(ROWLOCK, UPDLOCK)
	SET RegionId = @RegionId
	WHERE LeagueId = @LeagueId

	IF @@error <> 0
	BEGIN
		SELECT @ErrMsg = 'Update league region failed. Please try again.'
			,@ErrCode = 7202

		RETURN
	END

	DECLARE @Details NVARCHAR(4000)
		,@SPName NVARCHAR(50)

	SELECT @SPName = OBJECT_NAME(@@ProcID)

	SELECT @Details = 'Update league region with 
	LeagueId=' + dbo.SPU_ToString(@LeagueId) + ',  
	RegionId=' + dbo.SPU_ToString(@RegionId) + ',  
	Creator=' + dbo.SPU_ToString(@CreatorId)

	EXEC [dbo].TGRS_OS_WriteLog 
		 @LogTypeId = 72
		,@CreatorId = @CreatorId
		,@SPName = @SPName
		,@Details = @Details
END

/*
GO
GRANT EXECUTE ON [dbo].[TGRS_OS_LeagueRegionUpdate] TO [bodbTGRSNet]
GO
GRANT VIEW DEFINITION ON [dbo].[TGRS_OS_LeagueRegionUpdate] TO [bodbTGRSNet]
GO
*/

GO

SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO


GO 
 GRANT EXECUTE ON [dbo].[TGRS_OS_LeagueRegionUpdate] TO [bodbTGRSNet]
GO 
 GRANT VIEW DEFINITION ON [dbo].[TGRS_OS_LeagueRegionUpdate] TO [bodbTGRSNet]
GO 
