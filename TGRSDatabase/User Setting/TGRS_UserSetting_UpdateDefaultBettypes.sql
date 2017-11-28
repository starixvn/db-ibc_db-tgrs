CREATE PROCEDURE [dbo].[TGRS_UserSetting_UpdateDefaultBettypes]
	@UserId INT,
	@IsDefaultBettypes NVARCHAR(4000),
	@ErrCode INT = 0 OUTPUT,  
    @ErrMsg NVARCHAR(200) = '' OUTPUT  
/*
Created: 20171127@Simon
Task : Insert new bettype
DB:  DBTGRS.bodb_TGRS

*/ 
AS
BEGIN
	SET NOCOUNT ON

	IF(EXISTS (SELECT TOP(1) *  FROM UserDefaultBettypes WITH(NOLOCK)))
		BEGIN
			UPDATE UserDefaultBettypes
			SET BetTypes = @IsDefaultBettypes
			WHERE CustId = @UserId
		END
	ELSE
		BEGIN
			INSERT INTO UserDefaultBettypes(CustId, BetTypes)
			VALUES (@UserId, @IsDefaultBettypes)
		END
END

/* 
GO
GRANT EXECUTE ON [dbo].[TGRS_UserSetting_UpdateDefaultBettypes] TO [bodbTGRSNet]
GO
GRANT VIEW DEFINITION ON [dbo].[TGRS_UserSetting_UpdateDefaultBettypes] TO [bodbTGRSNet]
GO
*/