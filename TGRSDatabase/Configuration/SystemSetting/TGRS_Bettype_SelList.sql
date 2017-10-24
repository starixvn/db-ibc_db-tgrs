ALTER PROCEDURE [dbo].[TGRS_Bettype_SelList]
	@ViewPermission SMALLINT
/*
Created: 20140512@Sophia
Task : Select dropdown bettype
DB:  DBTGRS.bodb_TGRS

Revisions:
	- 20141208@Sophia: get IsDefault
    -  20171016@Simon: add permission checking
   
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
		OR (@ViewPermission = 1 AND (OrderId <> 999 OR OrderId IS NULL))
		OR (@ViewPermission = 2 AND OrderId = 999)
	ORDER BY OrderId
END 
	
GO
GRANT EXECUTE ON [dbo].[TGRS_Bettype_SelList] TO [bodbTGRSNet]
