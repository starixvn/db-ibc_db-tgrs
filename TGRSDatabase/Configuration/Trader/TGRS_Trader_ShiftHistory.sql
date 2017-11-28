CREATE PROCEDURE [dbo].[TGRS_Trader_ShiftHistory]
	@CustId INT
/*
 Created:	20171128@Simon
 Task :		History change shift of trader
 DB:		DBTGRS.bodb_TGRS
*/
AS
BEGIN
	SELECT 
		S.ShiftName,
		H.BeginDate
	FROM 
		TraderShift_History AS H WITH(NOLOCK)
		INNER JOIN [Shift] AS S WITH(NOLOCK) ON H.ShiftId = S.ShiftId
	WHERE H.CustId = @CustId
	ORDER BY H.BeginDate
END

/*
GO
GRANT EXECUTE ON [dbo].[TGRS_Trader_ShiftHistory] TO [bodbTGRSNet]
GO
GRANT VIEW DEFINITION ON [dbo].[TGRS_Trader_ShiftHistory] TO [bodbTGRSNet]
GO
*/