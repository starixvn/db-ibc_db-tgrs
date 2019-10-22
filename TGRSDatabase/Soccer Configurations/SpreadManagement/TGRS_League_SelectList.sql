
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[TGRS_League_SelectList]

/*
Created: 20150122@Long.Luu
Task : Select all leagues
DB:  DBTGRS.bodb_TGRS

Revisions:
   
*/ 

AS
BEGIN
	SET NOCOUNT ON 	
	
	SELECT	l.leagueid, l.leaguename
	FROM	bodb02.dbo.league l WITH (NOLOCK)
	WHERE l.sporttype <= 99
	ORDER BY l.leagueid
END

 
GO
GRANT EXECUTE ON [dbo].[TGRS_League_SelectList] TO [bodbTGRSNet]
GO
GRANT VIEW DEFINITION ON [dbo].[TGRS_League_SelectList] TO [bodbTGRSNet]
GO