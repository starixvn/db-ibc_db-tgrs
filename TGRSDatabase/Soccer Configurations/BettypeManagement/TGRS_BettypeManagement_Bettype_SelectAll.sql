ALTER PROCEDURE [dbo].[TGRS_BettypeManagement_Bettype_SelectAll]
/*
Created: 20171122@Simon
Task : Select all bettype
DB:  DBTGRS.bodb_TGRS

	Revision:
		- 20200714@JohnNgo: [TGR] Soccer - Re-arrange bet type filter with parent-child [Redmine: #137273]

*/ 
AS
BEGIN
	SET NOCOUNT ON;

	SELECT  b.BetType AS BettypeId, 
			b.TypeName AS BettypeName,
			(
				CASE b.BettypeGroup
					WHEN 1 THEN 'Major'
					ELSE 'PH'
				END
			) AS [Group],
			gb.GroupBettypeName,
			b.OperatorType,
			b.AssignmentBetType,
			b.IsUsedForJuice,
			b.[Disabled] As IsDisabled
	FROM dbo.BetType b WITH(NOLOCK)
		INNER JOIN dbo.GroupBettype gb WITH(NOLOCK) ON b.GroupBettypeId = gb.GroupBettypeId
	ORDER BY b.BetType ASC;

	SELECT  gb.GroupBettypeId,
		    gb.GroupBettypeName
	FROM dbo.GroupBettype gb WITH(NOLOCK);

END;

GO
/*<info serverAlias="DBTGRS-bodb_TGRS" executers="bodbTGRSNet" isFunction="0" isNested="0"></info>*/