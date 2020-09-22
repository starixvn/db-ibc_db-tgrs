ALTER PROCEDURE [dbo].[TGRS_LeagueGroup_GetBySportId]
		@SportId		INT = 2
AS
/*  
	Created:	20200918@John.Ngo
	Task :		Select League Group by Sportid
	DB:			DBTGRS.bodb_TGRS
	Original:  
  
	Revisions: 	
   		- 20200918@John.Ngo: Created [Redmine ID: 140875]

	Param's Explanation:
	
	Exam:
*/  
 
BEGIN
	SET NOCOUNT ON;

	SELECT DISTINCT l.LeagueGroupID
				,	lg.GroupName AS LeagueGroupName
	FROM bodb02.dbo.league AS l WITH(NOLOCK)
		INNER JOIN [bodb02].[dbo].[LeagueGroup] AS lg WITH(NOLOCK) ON l.LeagueGroupID = lg.GroupID
	WHERE	l.sporttype = @SportId
		AND l.LeagueGroupID <> 99
	ORDER BY lg.GroupName ASC;

END;

GO
/*<info serverAlias="DBTGRS-bodb_TGRS" executers="bodbTGRSNet" isFunction="0" isNested="1"></info>*/