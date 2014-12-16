ALTER PROCEDURE [dbo].[TGRS_Bettype_SelList]

/*
Created: 20140512@Sophia
Task : Select dropdown bettype
DB:  DBTGRS.bodb_TGRS

Revisions:
	- 20141208@Sophia: get IsDefault
   
*/ 

AS
BEGIN
	SET NOCOUNT ON 	
	
	SELECT	BetType, TypeName, IsDefault
	FROM	dbo.BetType WITH (NOLOCK)
	ORDER BY OrderId
END 
	
GO
GRANT EXECUTE ON [dbo].[TGRS_Bettype_SelList] TO [bodbTGRSNet]



