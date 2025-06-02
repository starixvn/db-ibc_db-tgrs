/*<info serverAlias="DBTGRS-bodb_TGRS" executers="wsv_tgrs" isFunction="0" isNested="0"></info>*/
CREATE PROCEDURE [dbo].[TGRS_Basketball_BettypeSetting_GetBettypes]

/*
	Creator: 20200909@John.Ngo
	Task: Select bettype of basketball
	DB: DBTGRS.bodb_TGRS

	Revision:
		- 20200909@John.Ngo: [TGR] Basketball - Select bettype of basketball [Redmine: #140875]
		- 20250530@Della: [TGR OS] Automatically add the new bet types to Basketball Performance report (#197594)

	Param's Explanation:
				 = 1: Main bettypes
				 = 2: PH AIO bettypes
*/
AS
BEGIN
	
	SELECT b.typeid  
	, CASE WHEN ob.GroupBettypeId=1 then ob.BettypeName
		 ELSE b.typenamee END AS BettypeName
	, CASE WHEN ob.GroupBettypeId = 1 THEN 1 
	     ELSE 2 END AS GroupBettypeId  
	, CASE WHEN ob.GroupBettypeId = 1 THEN 'Main'  
		 ELSE 'PH AIO' END AS GroupBettypeName  
	FROM bodb02.dbo.bettype b WITH(NOLOCK)
	LEFT JOIN dbo.OSBetType ob WITH(NOLOCK) on b.typeid=ob.BettypeId
	WHERE b.typeid IN (SELECT bettype FROM bodb02.dbo.SportBettypeMatrix WITH (NOLOCK) WHERE SportType = 2 AND bettype NOT IN (9,10,29,38,911,912,913,914)) 
	ORDER BY GroupBettypeId ASC , typeid ASC;

END;

GO
/*<info serverAlias="DBTGRS-bodb_TGRS" executers="bodbTGRSNet" isFunction="0" isNested="0"></info>*/