ALTER PROCEDURE [dbo].[TGRS_LeagueGroupSoccer_Get]
		@LeagueGroupIds		VARCHAR(2000) = ''
AS
/*  
	Created:	20220222@John.Ngo
	Task :		Select League Group
	DB:			DBTGRS.bodb_TGRS
	Original:  
  
	Revisions: 	
   		- 20220222@John.Ngo: Created [Redmine ID: 161859]

	Param's Explanation:
		- @LeagueGroupIds = ''		: Get LeagueGroupName for filter 'League Group'
		- @LeagueGroupIds = '12'	: 'Other Groups'
		
	Exam: EXEC [TGRS_LeagueGroupSoccer_Get] @LeagueGroupIds = '12'
*/  
 
BEGIN
	SET NOCOUNT ON;

	IF	OBJECT_ID('tempdb..#LeagueGroups') IS NOT NULL
	BEGIN
		DROP TABLE	#LeagueGroups;
	END;

	CREATE TABLE #LeagueGroups (
			LeagueGroupId 		SMALLINT PRIMARY KEY CLUSTERED
		,	LeagueGroupName		VARCHAR(200)
	);
	
	IF @LeagueGroupIds <> ''
	BEGIN
		INSERT INTO #LeagueGroups(LeagueGroupId)
		SELECT val 
		FROM dbo.strSplit_Key(@LeagueGroupIds,',');

		UPDATE gn WITH(ROWLOCK, UPDLOCK)
		SET gn.LeagueGroupName = lg.GroupName
		FROM #LeagueGroups AS gn
			INNER JOIN [bodb02].[dbo].[LeagueGroup] AS lg WITH(NOLOCK) ON gn.LeagueGroupID = lg.GroupID

		IF CHARINDEX('12', @LeagueGroupIds) > 0
		BEGIN
			DELETE FROM #LeagueGroups
			WHERE LeagueGroupId = 12;

			INSERT INTO #LeagueGroups(LeagueGroupId, LeagueGroupName)
			SELECT DISTINCT l.LeagueGroupID, lg.GroupName
			FROM bodb02.dbo.league AS l WITH(NOLOCK)
				INNER JOIN [bodb02].[dbo].[LeagueGroup] AS lg WITH(NOLOCK) ON l.LeagueGroupID = lg.GroupID
			WHERE l.LeagueGroupID NOT IN (1,2,3,4,5,6,7,8,9,10,11,42,113)
			AND	l.sporttype = 1
			AND l.LeagueGroupID <> 99
			ORDER BY l.LeagueGroupID ASC;
		END;
	END;

	IF @LeagueGroupIds = ''
	BEGIN
		SELECT @LeagueGroupIds = '1,2,3,4,5,6,7,8,9,10,11,42,113,12';
	
		INSERT INTO #LeagueGroups(LeagueGroupId)
		SELECT val 
		FROM dbo.strSplit_Key(@LeagueGroupIds,',');

		UPDATE gn WITH(ROWLOCK, UPDLOCK)
		SET gn.LeagueGroupName = CASE WHEN gn.LeagueGroupID = 12 THEN 'Other Groups' 
									  ELSE lg.GroupName END 
		FROM #LeagueGroups AS gn
			INNER JOIN [bodb02].[dbo].[LeagueGroup] AS lg WITH(NOLOCK) ON gn.LeagueGroupID = lg.GroupID

	END;

	SELECT	LeagueGroupId
		,	LeagueGroupName
		,	CASE 
				WHEN LeagueGroupId IN (1,2,3,4,5,6,7,8,9,10,11,42,113,12) THEN LeagueGroupId 
				ELSE 12 
			END TargetLeagueGroupId
	FROM #LeagueGroups WITH(NOLOCK);

END;

GO

/*<info serverAlias="DBTGRS-bodb_TGRS" executers="bodbTGRSNet" isFunction="0" isNested="1"></info>*/