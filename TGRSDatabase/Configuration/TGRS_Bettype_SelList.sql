ALTER PROCEDURE [dbo].[TGRS_Bettype_SelList]

/*
Created: 20140512@Sophia
Task : Select dropdown bettype
DB:  DBTGRS.bodb_TGRS

Revisions:
   
*/ 

AS
BEGIN
	SET NOCOUNT ON 	
	
	SELECT	BetType, TypeName
	FROM	dbo.BetType WITH (NOLOCK)
	ORDER BY OrderId
END 
	
GO
GRANT EXECUTE ON [dbo].[TGRS_Bettype_SelList] TO [bodbTGRSNet]



