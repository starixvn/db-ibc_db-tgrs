
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[TGRS_Trader_GradeHistory]  
	@CustId		 INT 
AS    
/*  
 Created:	20140523@Sophia
 Task :		History change team of trader
 DB:		DBTGRS.bodb_TGRS
 Original:  
  
 Revisions:      
   			
 Param's Explanation:  
	 
 Exam: 

	 
*/  
 
BEGIN 
	SET NOCOUNT ON 
	 
	SELECT	H.Grade, H.BeginDate AS EffectiveDate
	FROM	TraderGrade_History H WITH (NOLOCK)		
 	WHERE	H.CustId = @CustId
	ORDER BY H.BeginDate
 
END 


GO
GRANT EXECUTE ON [dbo].[TGRS_Trader_GradeHistory] TO [bodbTGRSNet]
GO
	