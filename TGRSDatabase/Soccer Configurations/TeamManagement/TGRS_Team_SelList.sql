ALTER PROCEDURE [dbo].[TGRS_Team_SelList]

/*
Created: 20140512@Sophia
Task : Select dropdown team 
DB:  DBTGRS.bodb_TGRS

Revisions:
   
*/ 

AS
BEGIN
	SET NOCOUNT ON 	
	
	SELECT	TeamId, TeamName
	FROM	dbo.Team WITH (NOLOCK)
	WHERE	ISNULL(Disabled,0) = 0
	ORDER BY TeamName
END 
	
GO
GRANT EXECUTE ON [dbo].[TGRS_Team_SelList] TO [bodbTGRSNet]



