ALTER PROCEDURE [dbo].[TGRS_Country_SelList]
AS
/*
	Created: Sophia
	Date: 20140514
	Task : Retrieve Country of league
	DB: DBTGRS/bodb_TGRS

	Revisions:

	Parameter's explaination:

	Original: NAP_SMATurnover_CountrySel
	
*/
SET NOCOUNT ON

SELECT	DISTINCT l.CountryCode
FROM	bodb02.dbo.league l WITH(NOLOCK) 
WHERE	l.IsActive = 1 
		AND l.CountryCode <> '0' 
		AND l.CountryCode IS NOT NULL 
		AND (l.sporttype < 99 OR l.sporttype = 154)
ORDER BY l.CountryCode

GO
GRANT EXECUTE ON [TGRS_Country_SelList] TO [bodbTGRSNet]
GO