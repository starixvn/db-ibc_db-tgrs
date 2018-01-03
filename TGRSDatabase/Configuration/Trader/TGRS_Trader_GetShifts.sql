CREATE PROCEDURE [dbo].[TGRS_Trader_GetShifts]
/*
Created: 20171128@Simon
Task : List of shift
DB:  DBTGRS.bodb_TGRS
   
*/ 
AS
BEGIN
	SET NOCOUNT ON 	

	SELECT ShiftId, ShiftName FROM [Shift] WITH(NOLOCK)
END

GO
GRANT EXECUTE ON [dbo].[TGRS_Trader_GetShifts] TO [bodbTGRSNet]
GO