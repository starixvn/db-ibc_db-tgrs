ALTER PROCEDURE [dbo].[TGRS_Rpt_LeagueSpread_Get]
	@Is8Percent			BIT = 0

AS
/*
	Created:	20210423@Adam.Tran
	Task:		Automation Trading - Report Spread 8% Live Performance
	DB:			DBTGRS.bodb_TGRS
	Original:
	
	Revisions:
		- 20210420@Adam.Tran: Created [Redmine ID: 152889]
		
	Param's Explanation:		
		
	Exam: EXECUTE dbo.TGRS_Rpt_LeagueSpread_Get
*/

BEGIN
	BEGIN		
		SELECT 	ls.LeagueId			
		FROM dbo.LeagueSpread AS ls WITH(NOLOCK)
			INNER JOIN bodb02.dbo.league AS lg WITH(NOLOCK) ON lg.LeagueId = ls.LeagueId
		WHERE lg.sporttype = 1 AND ls.Is8Percent = @Is8Percent
	END;
END;

GO
/*<info serverAlias="DBTGRS-bodb_TGRS" executers="bodbTGRSNet" isFunction="0" isNested="0"></info>*/