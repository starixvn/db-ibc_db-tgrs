CREATE PROCEDURE [dbo].[TGRS_Basketball_BettypeSetting_GetBettypes]

/*
	Creator: 20200909@John.Ngo
	Task: Select bettype of basketball
	DB: DBTGRS.bodb_TGRS

	Revision:
		- 20200909@John.Ngo: [TGR] Basketball - Select bettype of basketball [Redmine: #140875]

	Param's Explanation:
				 = 1: Main bettypes
				 = 2: PH AIO bettypes
*/
AS
BEGIN
	
	SELECT b.BettypeId
		,	b.BettypeName
		,	b.GroupBettypeId
		,	CASE WHEN b.GroupBettypeId = 1 THEN 'Main'
				 ELSE 'PH AIO' END AS GroupBettypeName
	FROM dbo.OSBetType b WITH(NOLOCK)
	WHERE b.GroupBettypeId IN (1,2)
	ORDER BY b.GroupBettypeId ASC
		,	 b.BettypeId ASC;

END;

GO
/*<info serverAlias="DBTGRS-bodb_TGRS" executers="bodbTGRSNet" isFunction="0" isNested="0"></info>*/