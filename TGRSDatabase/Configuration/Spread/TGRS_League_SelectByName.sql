
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[TGRS_League_SelectByName]
	@LeagueName		NVARCHAR(200) = ''
AS
/*
	Created:	20180905@Long.Luu
	Task :		Search Leagues for Exclusion
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
		,	[IsExcluded]	= CASE WHEN e.LeagueId IS NULL THEN 0 ELSE 1 END 
	FROM bodb02.dbo.league AS l WITH(NOLOCK)
		LEFT JOIN dbo.LeagueExclusion AS e WITH(NOLOCK) ON l.leagueid = e.LeagueId
	WHERE l.IsActive = 1
		AND e.LeagueId IS NULL
		AND (@LeagueName = '' OR l.leaguename LIKE '%' + @LeagueName + '%')
	ORDER BY (CASE WHEN e.LeagueId IS NULL THEN 0 ELSE 1 END) DESC
		,	l.leaguename ASC;
END;

GO
GRANT EXECUTE ON [dbo].[TGRS_League_SelectByName] TO [bodbTGRSNet]
GO
GRANT VIEW DEFINITION ON [dbo].[TGRS_League_SelectByName] TO [bodbTGRSNet]
GO
/*<info serverAlias="DBTGRS-bodb_TGRS" executers="bodbTGRSNet" isFunction="0" isNested="0"></info>*/