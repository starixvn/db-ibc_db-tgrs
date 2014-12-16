ALTER PROCEDURE [dbo].[TGRS_Setting_ScorePeriodSel]
AS
BEGIN 
	 SET NOCOUNT ON  
	 DECLARE @BeginDay VARCHAR(20),
			 @EndDay VARCHAR(20),
			 @SelectedDay VARCHAR(20)

	SELECT @BeginDay =  VValue	  							 		
	FROM   dbo.SystemSettings WITH (NOLOCK)							
	WHERE  VNAme = 'BeginDay'

	SELECT @EndDay =  VValue	  							 		
	FROM   dbo.SystemSettings WITH (NOLOCK)							
	WHERE  VNAme = 'EndDay'

	SELECT @SelectedDay =  VValue	  							 		
	FROM   dbo.SystemSettings WITH (NOLOCK)							
	WHERE  VNAme = 'SelectedDay'

	SELECT @BeginDay AS BeginDay , @EndDay AS EndDay, @SelectedDay AS SelectedDay

END
GO 
GRANT EXECUTE ON [dbo].[TGRS_Setting_ScorePeriodSel] TO [bodbTGRSNet] 
GO