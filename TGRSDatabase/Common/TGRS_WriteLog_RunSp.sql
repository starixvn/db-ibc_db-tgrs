
GO


SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[TGRS_WriteLog_RunSp]
	@UserId		INT,
	@SPName		VARCHAR(50) = NULL,
	@LogDate	DATETIME = NULL,
	@Duration	INT = NULL,
	@ObjectId	INT = NULL,
	@Data		NVARCHAR(MAX) = NULL,
	@OldData	NVARCHAR(MAX) = NULL

/*
Created: 20140509@Sophia
Task : Write log user run store procedure
DB:  DBTGRS.bodb_TGRS

Revisions:
   
*/ 

AS
BEGIN 
SET NOCOUNT ON 

INSERT INTO dbo.UserLog_RunSp(
			 UserId
			,SPName
			,LogDate
			,ObjectID
			,ActionID
			,Duration
			,Data
			,OldData)
	SELECT	 @UserId
			,@SPName
			,@LogDate
			,@ObjectID
			,ActionID
			,@Duration
			,@Data
			,@OldData			
	FROM	dbo.LogAction WITH (NOLOCK)
	WHERE	SPName = @SPName

END
GO 
GRANT EXECUTE ON [dbo].[TGRS_WriteLog_RunSp] TO [bodbTGRSNet]
GO


