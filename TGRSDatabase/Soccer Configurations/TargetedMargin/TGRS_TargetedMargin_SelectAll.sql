
GO


SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[TGRS_TargetedMargin_SelectAll]
/*
Created: 20160216@Long.Luu
Task : Get all Targeted Margin
DB:  DBTGRS.bodb_TGRS

Revisions:
		20160329@Aaron: added order by OrderId
*/ 

AS
BEGIN
	SET NOCOUNT ON
	SELECT tm.TargetedMarginID, 
		bt.TypeName BetType, 
		tm.Rate, 
		tm.WorkShift Shift
	FROM dbo.TargetedMargin tm WITH (NOLOCK) 
	INNER JOIN BetType bt  WITH (NOLOCK)ON tm.BetType=bt.BetType
	ORDER BY CASE WHEN bt.Bettype  > 0 THEN 0 ELSE 1 END
END
GO

