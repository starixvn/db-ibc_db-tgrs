ALTER PROCEDURE [dbo].[TGRS_Bettype_ListUpd]
	@IsDefaultBettypes  VARCHAR(200) = '0'
/*
Created: 20141208@Sophia
Task : Update Default for filter
DB:  DBTGRS.bodb_TGRS

Revisions: 
   
*/ 

AS
BEGIN
	SET NOCOUNT ON 	
	 
	 DECLARE @BettypeList AS TABLE (bettype SMALLINT)
	 IF @IsDefaultBettypes <> '0'
		 INSERT INTO @BettypeList
		 SELECT val FROM dbo.strSplit_Key(@IsDefaultBettypes,',')
	 ELSE 
		 INSERT INTO @BettypeList
		 SELECT Bettype FROM dbo.Bettype WITH (NOLOCK)
		 		 

		UPDATE	dbo.BetType WITH (UPDLOCK, ROWLOCK)
		SET		IsDefault = 1
		WHERE   BetType IN (SELECT Bettype FROM @BettypeList)

		
		UPDATE	dbo.BetType WITH (UPDLOCK, ROWLOCK)
		SET		IsDefault = 0
		WHERE   BetType NOT IN (SELECT Bettype FROM @BettypeList)
		
END 
	
GO
GRANT EXECUTE ON [dbo].[TGRS_Bettype_ListUpd] TO [bodbTGRSNet]



