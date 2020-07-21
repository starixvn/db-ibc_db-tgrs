ALTER PROCEDURE [dbo].[TGRS_UserSetting_GetBettypes]
		@UserId				INT
	, 	@BettypePermission	INT
/*
	Creator: Simon
	Date: 2017-11-27
	Task: Trader Report - League Performance
	DB: DBTGRS.bodb_TGRS

	Revision:
		- 20171205@Simon: get only Live data & Bettypes are not disabled
		- 20191212@JohnNgo: Update strSplit_Key [Redmine: #118960]
		- 20200714@JohnNgo: [TGR] Soccer - Re-arrange bet type filter with parent-child [Redmine: #137273]

	Param's Explanation:
		@ViewPermission = 0: All bet types
				 = 1: Major bet types
				 = 2: PHAIO bet types
*/
AS
BEGIN
	DECLARE @Bettypes NVARCHAR(4000);

	IF	OBJECT_ID('tempdb..#DefaultBettypes') IS NOT NULL
		DROP TABLE	#DefaultBettypes;

	CREATE TABLE #DefaultBettypes 
	(
		BettypeId INT PRIMARY KEY
	);

	IF(NOT EXISTS(SELECT 1 FROM UserDefaultBettypes WITH(NOLOCK) WHERE CustId = @UserId))
	BEGIN
		INSERT INTO UserDefaultBettypes(CustId, BetTypes)
		VALUES(@UserId, '1,3,5,7,8,15')
	END

	SELECT @Bettypes = BetTypes 
	FROM UserDefaultBettypes WITH(NOLOCK)
	WHERE CustId = @UserId;

	
	INSERT INTO #DefaultBettypes
	SELECT val 
	FROM dbo.strSplit_Key(@Bettypes, ',');

	SELECT 
		b.BetType,
		b.TypeName,
		CASE WHEN db.BettypeId <> 0 
			THEN 1
			ELSE 0 END AS IsDefault,
		b.GroupBettypeId,
		gb.GroupBettypeName
	FROM dbo.BetType b WITH(NOLOCK)
		INNER JOIN dbo.GroupBettype gb WITH(NOLOCK) ON b.GroupBettypeId = gb.GroupBettypeId
		LEFT JOIN #DefaultBettypes db WITH(NOLOCK) ON b.BetType = db.BettypeId
	WHERE (@BettypePermission = 0 OR @BettypePermission = b.BettypeGroup)
		AND b.[Disabled] = 0
	ORDER BY gb.GroupBettypeId ASC, b.OrderId ASC, b.BetType ASC;

	DROP TABLE #DefaultBettypes;
END;

GO
/*<info serverAlias="DBTGRS-bodb_TGRS" executers="bodbTGRSNet" isFunction="0" isNested="0"></info>*/