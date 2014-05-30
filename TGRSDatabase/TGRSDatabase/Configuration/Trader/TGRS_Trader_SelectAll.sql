 
ALTER PROCEDURE [dbo].[TGRS_Trader_SelectAll]
	@Username		VARCHAR(30) = '',
	@EmployeeId		NVARCHAR(20) ='',
	@TeamId			SMALLINT = 0,
	@Grade		SMALLINT = 0

/*
Created: 20140512@Sophia
Task : List of Trader
DB:  DBTGRS.bodb_TGRS

Revisions:

Explanation :
	@TeamId = 0 :All team 
	@GradeId = 0: All grade
	
   
*/ 

AS
BEGIN
	SET NOCOUNT ON 	
	
	SELECT		TR.CustId, TR.Username, TR.EmployeeId, T.TeamName, TR.Grade, TR.CreatedDate, TR.CreatedBy, C.Username AS CreatedUsername, TR.TeamEffectiveDate, TR.GradeEffectiveDate
	FROM		dbo.Trader TR WITH (NOLOCK)
		INNER JOIN  dbo.Team T WITH (NOLOCK) 
				ON	T.TeamId = TR.TeamId
		LEFT JOIN bodb02.dbo.CustInfo C WITH (NOLOCK)
				ON C.CustID = TR.CreatedBy
	WHERE	TR.Username LIKE '%' + @Username +'%'
			AND TR.EmployeeId LIKE '%' + @EmployeeId +'%'
			AND TR.TeamId = CASE WHEN @TeamId <> 0 THEN @TeamId ELSE TR.TeamId END 
			AND TR.Grade = CASE WHEN @Grade <> 0 THEN @Grade ELSE TR.Grade END 
	ORDER BY	TR.Username
		

END

GO
GRANT EXECUTE ON [dbo].[TGRS_Trader_SelectAll] TO [bodbTGRSNet]
GO
	
