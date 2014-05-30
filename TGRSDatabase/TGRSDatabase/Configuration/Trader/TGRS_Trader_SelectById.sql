
ALTER PROCEDURE [dbo].[TGRS_Trader_SelectById]
	@CustId INT

/*
Created: 20140512@Sophia
Task : Select Trader by Id
DB:  DBTGRS.bodb_TGRS

Revisions:
   
*/ 

AS
BEGIN
	SET NOCOUNT ON 	
	
	SELECT	T.CustId, T.Username, T.EmployeeId, T.TeamId, T.Grade, T.EffectiveDate
	FROM	dbo.Trader T WITH (NOLOCK)
	WHERE	T.CustId = @CustId		

END
	
GO
GRANT EXECUTE ON [dbo].[TGRS_Trader_SelectById] TO [bodbTGRSNet]
GO


