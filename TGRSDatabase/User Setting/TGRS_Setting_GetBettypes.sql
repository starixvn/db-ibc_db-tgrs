CREATE PROCEDURE [dbo].[TGRS_UserSetting_GetBettypes]
	@UserId INT,
	@BettypePermission INT
/*
	Creator: Simon
	Date: 2017-11-27
	Task: Trader Report - League Performance
	DB: DBTGRS.bodb_TGRS

	Revision:
		- 20171205@Simon: get only Live data & Bettypes are not disabled
	Param's Explanation:
		@ViewPermission = 0: all bet types
				 = 1: major bet types
				 = 2: PHAIO bet types
*/
AS
BEGIN
	DECLARE @Bettypes NVARCHAR(4000);

	CREATE TABLE #DefaultBettypes 
	(
		BettypeId INT PRIMARY KEY
	);

	SELECT @Bettypes = BetTypes 
	FROM UserDefaultBettypes WITH(NOLOCK)
	WHERE CustId = @UserId;

	
	INSERT INTO #DefaultBettypes
	SELECT * 
	FROM dbo.strSplit_Key(@Bettypes, ',');

	SELECT 
		BetType,
		TypeName,
		ISNULL(BettypeId, 0) AS IsDefault
	FROM BetType WITH(NOLOCK)
		LEFT JOIN #DefaultBettypes WITH(NOLOCK) ON BetType = BettypeId
	WHERE (@BettypePermission = 0 OR @BettypePermission = BettypeGroup)
		AND [Disabled] = 0;

	DROP TABLE #DefaultBettypes;
END

/* 
GO
GRANT EXECUTE ON [dbo].[TGRS_UserSetting_GetBettypes] TO [bodbTGRSNet]
GO
GRANT VIEW DEFINITION ON [dbo].[TGRS_UserSetting_GetBettypes] TO [bodbTGRSNet]
GO
*/