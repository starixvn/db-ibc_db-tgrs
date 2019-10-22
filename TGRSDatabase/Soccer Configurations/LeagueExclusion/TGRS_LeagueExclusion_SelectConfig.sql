GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[TGRS_LeagueExclusion_SelectConfig]
AS
/*
	Created:	20190114@Long.Luu
	Task :		Get Excluded Leagues Config
	DB:			DBTGRS.bodb_TGRS
	Original:
  
	Revisions:
		- 20190114@Long:	Created [Redmine: #107809]
   		
	Param's Explanation:

	Exam:
	 
*/
BEGIN
	SET NOCOUNT ON;

	SELECT	[IsExcludeLeagues]	= c.VValue
	FROM dbo.SystemSettings AS c WITH(NOLOCK)
	WHERE c.VName = 'ExcludeLeagues';
END;


