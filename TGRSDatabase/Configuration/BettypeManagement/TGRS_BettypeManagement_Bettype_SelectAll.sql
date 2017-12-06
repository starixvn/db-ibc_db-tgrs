CREATE PROCEDURE [dbo].[TGRS_BettypeManagement_Bettype_SelectAll]
/*
Created: 20171122@Simon
Task : Select all bettype
DB:  DBTGRS.bodb_TGRS

*/ 
AS
BEGIN
	SET NOCOUNT ON;

	SELECT 
		BetType AS BettypeId, 
		TypeName AS BettypeName, 
		OperatorType,
		AssignmentBetType,
		(
			CASE BettypeGroup
				WHEN 1 THEN 'Major'
				ELSE 'PH'
			END
		) AS [Group],
		[Disabled] As IsDisabled,
		IsUsedForJuice
	FROM dbo.BetType WITH(NOLOCK);
END

/* 
GO
GRANT EXECUTE ON[dbo].[TGRS_BettypeManagement_Bettype_SelectAll] TO [bodbTGRSNet]
GO
GRANT VIEW DEFINITION ON [dbo].[TGRS_BettypeManagement_Bettype_SelectAll] TO [bodbTGRSNet]
GO
*/