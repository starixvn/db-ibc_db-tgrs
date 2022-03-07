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
		- 20220307@John.Ngo: Update Separate League Group for Virtual [Redmine: #161859]
		
	Param's Explanation:
		- @LeagueGroupIds = ''		: Get LeagueGroupName for filter 'League Group'
		- @LeagueGroupIds = '12'	: 'Other Groups'
		
	Exam: EXEC [TGRS_LeagueGroupSoccer_Get] @LeagueGroupIds = '12'
*/  
 
BEGIN
	SET NOCOUNT ON;

	DECLARE @OtherGroupsId		SMALLINT 		= 12
		,	@OtherGroupsName	VARCHAR(200)	= 'Other Groups'
		,	@VirtualGroupsId	SMALLINT		= 42
		,	@VirtualGroupsName	VARCHAR(200) 	= 'Virtual';
	
	IF	OBJECT_ID('tempdb..#LeagueGroups') IS NOT NULL
	BEGIN
		DROP TABLE	#LeagueGroups;
	END;

	CREATE TABLE #LeagueGroups (
			LeagueGroupId 		SMALLINT PRIMARY KEY CLUSTERED
		,	LeagueGroupName		VARCHAR(200)
	);
	
	IF @LeagueGroupIds = ''
	BEGIN
		SELECT @LeagueGroupIds = '1,2,3,4,5,6,7,8,9,10,11,12,42,113';
	END

	IF @LeagueGroupIds <> ''
	BEGIN
		INSERT INTO #LeagueGroups(LeagueGroupId)
		SELECT val 
		FROM dbo.strSplit_Key(@LeagueGroupIds,',');

		UPDATE gn WITH(ROWLOCK, UPDLOCK)
		SET gn.LeagueGroupName = lg.GroupName
		FROM #LeagueGroups AS gn
			INNER JOIN [bodb02].[dbo].[LeagueGroup] AS lg WITH(NOLOCK) ON gn.LeagueGroupID = lg.GroupID

		IF CHARINDEX('42', @LeagueGroupIds) > 0
		BEGIN
			DELETE FROM #LeagueGroups
			WHERE LeagueGroupId = 42;

			INSERT INTO #LeagueGroups(LeagueGroupId, LeagueGroupName)
			SELECT DISTINCT l.LeagueGroupID, @VirtualGroupsName
			FROM bodb02.dbo.league AS l WITH(NOLOCK)
				INNER JOIN [bodb02].[dbo].[LeagueGroup] AS lg WITH(NOLOCK) ON l.LeagueGroupID = lg.GroupID
			WHERE l.LeagueGroupID IN (42,74,108)
			AND	l.sporttype = 1
			AND l.LeagueGroupID <> 99
			ORDER BY l.LeagueGroupID ASC;
		END;

		IF CHARINDEX('12', @LeagueGroupIds) > 0
		BEGIN
			DELETE FROM #LeagueGroups
			WHERE LeagueGroupId = 12;

			INSERT INTO #LeagueGroups(LeagueGroupId, LeagueGroupName)
			SELECT DISTINCT l.LeagueGroupID, @OtherGroupsName
			FROM bodb02.dbo.league AS l WITH(NOLOCK)
				INNER JOIN [bodb02].[dbo].[LeagueGroup] AS lg WITH(NOLOCK) ON l.LeagueGroupID = lg.GroupID
			WHERE l.LeagueGroupID NOT IN (1,2,3,4,5,6,7,8,9,10,11,42,74,108,113)
			AND	l.sporttype = 1
			AND l.LeagueGroupID <> 99
			ORDER BY l.LeagueGroupID ASC;
		END;
	END;

	SELECT	LeagueGroupId
		,	LeagueGroupName
		,	CASE 
				WHEN LeagueGroupId IN (1,2,3,4,5,6,7,8,9,10,11,113) THEN LeagueGroupId
			    WHEN LeagueGroupId IN (42,74,108) THEN @VirtualGroupsId
				ELSE @OtherGroupsId
			END TargetLeagueGroupId
	FROM #LeagueGroups WITH(NOLOCK)
	ORDER BY TargetLeagueGroupId ASC, LeagueGroupId ASC;

END;

GO

/*<info serverAlias="DBTGRS-bodb_TGRS" executers="bodbTGRSNet" isFunction="0" isNested="1"></info>*/