ALTER PROCEDURE [dbo].[TGRS_LeagueSpread_SelectByName]
	@LeagueName		NVARCHAR(200) = ''
AS
/*
	Created:	20210604@Adam.Tran
	Task:		Automation Trading - Report Spread Live Performance
	DB:			DBTGRS.bodb_TGRS
	Original:
	
	Revisions:
		- 20210604@Adam.Tran: Created [Redmine ID: 156614]
		
	Param's Explanation:		
		
	Exam: EXECUTE dbo.TGRS_LeagueSpread_SelectByName
	 
*/
BEGIN
	SET NOCOUNT ON;

	SELECT	[LeagueId]		= l.leagueid
		,	[LeagueName]	= l.leaguename
		,	[Is8PeRcent]	= CASE WHEN e.LeagueId IS NULL THEN 0 ELSE 1 END 
	FROM bodb02.dbo.league AS l WITH(NOLOCK)
		LEFT JOIN dbo.LeagueSpread AS e WITH(NOLOCK) ON l.leagueid = e.LeagueId
	WHERE (@LeagueName = '' OR l.leaguename LIKE '%' + @LeagueName + '%')
	ORDER BY (CASE WHEN e.LeagueId IS NULL THEN 0 ELSE 1 END) DESC
		,	l.leaguename ASC;
END;

/*<info serverAlias="DBTGRS-bodb_TGRS" executers="bodbTGRSNet" isFunction="0" isNested="0"></info>*/