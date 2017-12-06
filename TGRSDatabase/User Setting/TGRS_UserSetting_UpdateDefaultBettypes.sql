CREATE PROCEDURE [dbo].[TGRS_UserSetting_UpdateDefaultBettypes]
	@UserId INT,
	@IsDefaultBettypes NVARCHAR(4000),
	@ErrCode INT = 0 OUTPUT,  
    @ErrMsg NVARCHAR(200) = '' OUTPUT  
AS
/*
	Created: 20171127@Simon
	Task : Insert new bettype
	DB:  DBTGRS.bodb_TGRS

	Revision:
		- 20171205@Simon: get only Live data & Bettypes are not disabled
*/ 
BEGIN
	SET NOCOUNT ON;

	DECLARE @OldBettypes NVARCHAR(4000), @xml XML, @StartRun DATETIME = GETDATE(), @EndRun DATETIME, @Duration INT, @NewData NVARCHAR(MAX);

	SELECT @OldBettypes = BetTypes 
	FROM UserDefaultBettypes WITH(NOLOCK)
	WHERE CustId = @UserId;

	IF(@OldBettypes IS NOT NULL)
		BEGIN
			SET @xml =
				(
					SELECT 
						@UserId AS '@c',
						@OldBettypes AS '@bt'
					FOR XML PATH('z'), ROOT('r')
				)

			DECLARE @OldData NVARCHAR(MAX) = REPLACE(CONVERT(NVARCHAR(MAX), @xml), '" />', '"/"');

			UPDATE UserDefaultBettypes
			SET BetTypes = @IsDefaultBettypes
			WHERE CustId = @UserId;

			SET @xml =
				(
					SELECT 
						@UserId AS '@c',
						@IsDefaultBettypes AS '@bt'
					FOR XML PATH('z'), ROOT('r')
				)

			SET @NewData  = REPLACE(CONVERT(NVARCHAR(MAX), @xml), '" />', '"/"');
			SET @EndRun  = GETDATE();
			SET @Duration  = DATEDIFF(MILLISECOND, @StartRun, @EndRun);

			EXEC	dbo.TGRS_WriteLog_RunSp
				@UserId		= @UserId,
				@SPName		= 'TGRS_UserSetting_UpdateDefaultBettypes',
				@LogDate	= @StartRun,
				@Duration	= @Duration,
				@ObjectId	= @UserId,
				@Data		= @NewData,
				@OldData	= @OldData;
		END
	ELSE
		BEGIN
			INSERT INTO UserDefaultBettypes(CustId, BetTypes)
			VALUES (@UserId, @IsDefaultBettypes);

			SET @xml =
				(
					SELECT 
						@UserId AS '@c',
						@IsDefaultBettypes AS '@bt'
					FOR XML PATH('z'), ROOT('r')
				)

			SET @NewData = REPLACE(CONVERT(NVARCHAR(MAX), @xml), '" />', '"/"');
			SET @EndRun  = GETDATE();
			SET @Duration  = DATEDIFF(MILLISECOND, @StartRun, @EndRun);

			EXEC	dbo.TGRS_WriteLog_RunSp
				@UserId		= @UserId,
				@SPName		= 'TGRS_UserSetting_UpdateDefaultBettypes',
				@LogDate	= @StartRun,
				@Duration	= @Duration,
				@ObjectId	= @UserId,
				@Data		= @NewData,
				@OldData	= NULL;
		END
END

/* 
GO
GRANT EXECUTE ON [dbo].[TGRS_UserSetting_UpdateDefaultBettypes] TO [bodbTGRSNet]
GO
GRANT VIEW DEFINITION ON [dbo].[TGRS_UserSetting_UpdateDefaultBettypes] TO [bodbTGRSNet]
GO
*/