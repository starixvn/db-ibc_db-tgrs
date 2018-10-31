GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[TGRS_OS_BettypeGetAll]  
AS  
/*  
	Created: 20160809@Simon.Huynh  
	Task : Get all OS Special Target  
	DB:  DBTGRS.bodb_TGRS  
	  
	Revisions:
		- 20181031@Long: Adding 74 bettypes to OS's Settings [Redmine ID: #104017]

	Param's Explanation (filtered by):
*/  
BEGIN  
	SET NOCOUNT ON;
  
	SELECT   
		b.typeid AS [BettypeId],  
		b.typenamee AS [BettypeName]  
	FROM bodb02.dbo.bettype AS b  WITH(NOLOCK) 
	WHERE (b.typeid < 31
		OR b.typeid BETWEEN 121 AND 999
		OR b.typeid BETWEEN 1301 AND 1399
		OR b.typeid BETWEEN 9001 AND 9074)
		AND b.typeid NOT BETWEEN 801 AND 806 -- metric gaming
		AND b.typeid NOT IN (901, 902, 903) -- bettrade
    
END;
 /*   
GO  
GRANT EXECUTE ON [dbo].[TGRS_OS_BettypeGetAll] TO [bodbTGRSNet]  
GO  
GRANT VIEW DEFINITION ON [dbo].[TGRS_OS_BettypeGetAll] TO [bodbTGRSNet]  
GO  
*/
GO
/*<info serverAlias="DBTGRS-bodb_TGRS" executers="bodbTGRSNet"  isFunction="0" isNested="0"></info>*/
