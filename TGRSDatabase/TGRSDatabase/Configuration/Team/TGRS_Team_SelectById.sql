
ALTER PROCEDURE [dbo].[TGRS_Team_SelectById]
	@TeamId SMALLINT

/*
Created: 20140509@Sophia
Task : Select team by Id
DB:  DBTGRS.bodb_TGRS

Revisions:
   
*/ 

AS
BEGIN
	SET NOCOUNT ON 	
	
	SELECT	T.TeamId, T.TeamName, T.Description 
	FROM	dbo.Team T WITH (NOLOCK)
	WHERE	T.TeamId = @TeamId
		

END
	
GO
GRANT EXECUTE ON [dbo].[TGRS_Team_SelectById] TO [bodbTGRSNet]
GO


