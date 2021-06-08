ALTER PROCEDURE [dbo].[TGRS_LeagueSpread_SelectAll]
AS
/*
	Created:	20210604@Adam.Tran
	Task:		Automation Trading - Report Spread Live Performance
	DB:			DBTGRS.bodb_TGRS
	Original:
	
	Revisions:
		- 20210604@Adam.Tran: Created [Redmine ID: 156614]
		
	Param's Explanation:		
		
	Exam: EXECUTE dbo.TGRS_LeagueSpread_SelectAll
	 
*/
BEGIN
	SET NOCOUNT ON;

	SELECT	[LeagueId]		= l.leagueid
		,	[LeagueName]	= l.leaguename
	FROM dbo.LeagueSpread AS e WITH(NOLOCK)
		INNER JOIN bodb02.dbo.league AS l WITH(NOLOCK) ON l.leagueid = e.LeagueId
	ORDER BY l.leaguename ASC;
END;

/*<info serverAlias="DBTGRS-bodb_TGRS" executers="bodbTGRSNet" isFunction="0" isNested="0"></info>*/