ALTER PROCEDURE [dbo].[TGRS_Bettype_SelList]
	@ViewPermission SMALLINT
/*
Created: 20140512@Sophia
Task : Select dropdown bettype
DB:  DBTGRS.bodb_TGRS

Revisions:
	- 20141208@Sophia: get IsDefault
    - 20171016@Simon: add permission checking
	- 20171101@Simon: change permission checking method
	
Param Explaination:
	@ViewPermission:
		0: All
		1: Major bet types
		2: PHAIO bet types
*/ 

AS
BEGIN
	SET NOCOUNT ON 	
	
	SELECT	BetType, TypeName, IsDefault
	FROM	dbo.BetType WITH (NOLOCK)
	WHERE
		@ViewPermission = 0
		OR BettypeGroup = @ViewPermission
	ORDER BY OrderId
END 
	
GO
GRANT EXECUTE ON [dbo].[TGRS_Bettype_SelList] TO [bodbTGRSNet]
