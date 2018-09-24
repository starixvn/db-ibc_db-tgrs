
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[TGRS_LeagueExclusion_SelectAll]
AS
/*
	Created:	20180905@Long.Luu
	Task :		Get Excluded Leagues
	DB:			DBTGRS.bodb_TGRS
	Original:
  
	Revisions:
		- 20180921@Long:	Adding meta data for SP
   		
	Param's Explanation:

	Exam:
	 
*/
BEGIN
	SET NOCOUNT ON;

	SELECT	[LeagueId]		= l.leagueid
		,	[LeagueName]	= l.leaguename
	FROM dbo.LeagueExclusion AS e WITH(NOLOCK)
		INNER JOIN bodb02.dbo.league AS l WITH(NOLOCK) ON l.leagueid = e.LeagueId
	WHERE l.IsActive = 1
	ORDER BY l.leaguename ASC;
END;

GO
GRANT EXECUTE ON [dbo].[TGRS_LeagueExclusion_SelectAll] TO [bodbTGRSNet]
GO
GRANT VIEW DEFINITION ON [dbo].[TGRS_LeagueExclusion_SelectAll] TO [bodbTGRSNet]
GO
/*<info serverAlias="DBTGRS-bodb_TGRS" executers="bodbTGRSNet" isFunction="0" isNested="0"></info>*/