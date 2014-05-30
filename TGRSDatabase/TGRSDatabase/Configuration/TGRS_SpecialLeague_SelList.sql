CREATE  PROCEDURE [dbo].[TGRS_SpecialLeague_SelList]
AS  
/*
	Created: Sophia
	Date: 20140514
	Task : Retrieve Special league
	DB: DBTGRS/bodb_TGRS

	Revisions:

	Parameter's explaination:

	Original: NAP_SMATurnover_SpecialLeagueSel
	
*/
BEGIN
	SET NOCOUNT ON
		
		SELECT	l.displaymode, l.ProgramID
		FROM	bodb02.dbo.league l WITH (NOLOCK)
			INNER JOIN bodb02.dbo.Dot_Admin_LeagueDisplayMode ldm WITH (NOLOCK)
					ON ldm.LDisplayMode = l.[displaymode]
		WHERE	l.ProgramID IS NOT NULL
				AND ldm.[Enabled] = 1
				AND l.IsActive = 1
		GROUP BY l.displaymode, l.ProgramID
		ORDER BY l.displaymode, l.ProgramID

END
GO
GRANT EXECUTE ON [TGRS_SpecialLeague_SelList] TO [bodbTGRSNet]

