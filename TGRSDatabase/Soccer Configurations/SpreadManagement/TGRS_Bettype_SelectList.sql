
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[TGRS_Bettype_SelectList]

/*
Created: 20160122@Long.Luu
Task : Select dropdown bettype
DB:  DBTGRS.bodb_TGRS

Revisions:   
*/ 

AS
BEGIN
	SET NOCOUNT ON 	
	
	SELECT	BetType, TypeName, IsDefault
	FROM	dbo.BetType WITH (NOLOCK)
	ORDER BY BetType
END

GO 
GRANT EXECUTE ON [dbo].[TGRS_Bettype_SelectList] TO [bodbTGRSNet]
GO
GRANT VIEW DEFINITION ON [dbo].[TGRS_Bettype_SelectList] TO [bodbTGRSNet]
GO