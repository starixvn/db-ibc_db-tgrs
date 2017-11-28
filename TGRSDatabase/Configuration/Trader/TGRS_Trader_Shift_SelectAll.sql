CREATE PROCEDURE [dbo].[TGRS_Trader_Shift_SelectAll]
/*
Created: 20171128@Simon
Task : List of shift
DB:  DBTGRS.bodb_TGRS
   
*/ 
AS
BEGIN
	SET NOCOUNT ON 	

	SELECT ShiftId, ShiftName FROM [Shift] WITH(NOLOCK)
	WHERE [Disabled] = 0
END

/*
GO
GRANT EXECUTE ON [dbo].[TGRS_Trader_Shift_SelectAll] TO [bodbTGRSNet]
GO
GRANT VIEW DEFINITION ON [dbo].[TGRS_Trader_Shift_SelectAll] TO [bodbTGRSNet]
GO
*/