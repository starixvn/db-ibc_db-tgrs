
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[TGRS_Trader_TeamHistory]  
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
	 
	SELECT	H.TeamId, T.TeamName, H.BeginDate AS EffectiveDate
	FROM	TraderTeam_History H WITH (NOLOCK)
	INNER JOIN Team T WITH (NOLOCK) 
	 		ON T.TeamId = H.TeamId			
 	WHERE	H.CustId = @CustId
	ORDER BY H.BeginDate
 
END 


GO
GRANT EXECUTE ON [dbo].[TGRS_Trader_TeamHistory] TO [bodbTGRSNet]
GO
	