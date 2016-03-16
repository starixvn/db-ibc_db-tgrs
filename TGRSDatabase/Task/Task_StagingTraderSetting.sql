USE [bodb_TGRS]
GO

/****** Object:  StoredProcedure [dbo].[Task_StagingTraderSetting]    Script Date: 03/14/2016 15:42:22 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[Task_StagingTraderSetting]
AS 
/*  
 Created:	20140703@Tom.Vo
 Task :		Staging Trader Data on TGRS DB
 DB:		DBTGRS.bodb_TGRS
 Original:  
  
 Revisions:      
   		20140715@Tom.Vo: Filter Sport Type 1
   		20160314@Aaron.Cao: Added UPDATE Username
 Param's Explanation:  
	 
 Exam: 

	 
*/ 
SET NOCOUNT ON 

--Update Username when they were changed from the original data
IF EXISTS (	SELECT TOP 1 1 
			FROM Trader T WITH (NOLOCK)
			INNER JOIN bodb02.dbo.Customer ci WITH(NOLOCK) ON ci.custid = T.CustId 
			WHERE ci.username <> T.Username AND ci.RoleID > 4)
BEGIN 
	UPDATE T
	SET T.Username = ci.username, T.ModifiedDate = GETDATE(), T.ModifiedBy = 8
	FROM Trader T WITH(ROWLOCK, UPDLOCK)
	INNER JOIN bodb02.dbo.Customer ci WITH(NOLOCK) ON ci.custid = T.CustId 
	WHERE ci.username <> T.Username AND ci.RoleID > 4;
END

--Insert new trader
IF OBJECT_ID('tempdb..#Trader') IS NOT NULL    DROP TABLE #Trader

SELECT DISTINCT td.OperatorID custid
	  ,ci.[Username]
      ,'-' [EmployeeId]
      ,1 [TeamId]
      ,10 [Grade]
      ,ISNULL(ci.[creatdate],'2011-01-01') [CreatedDate]
      ,8 AS [CreatedBy]
      ,NULL [ModifiedDate]
      ,NULL [ModifiedBy]
      ,0 [Disabled]
      ,CONVERT(NVARCHAR(10),ISNULL(ci.[creatdate],'2011-01-01'),20) [TeamEffectiveDate]
      ,CONVERT(NVARCHAR(10),ISNULL(ci.[creatdate],'2011-01-01'),20) [GradeEffectiveDate]
	INTO #Trader
  FROM [bodb02].[dbo].[Dot_Admin_Assignment_Operator] td WITH(NOLOCK)  
	INNER JOIN  bodb02.dbo.Customer ci WITH (NOLOCK)			ON td.OperatorID = ci.custid 
	LEFT JOIN  [bodb_TGRS].dbo.[Trader] tr_h WITH (NOLOCK) 	ON tr_h.CustId = ci.custid 
	LEFT JOIN [bodb02].[dbo].match m WITH(NOLOCK) ON td.matchid = m.matchid	
  WHERE td.OperatorType <3 AND tr_h.CustId IS NULL
		AND m.sporttype = 1
 
 IF @@ROWCOUNT = 0
	BEGIN
		IF OBJECT_ID('tempdb..#Trader') IS NOT NULL    DROP TABLE #Trader
		RETURN
	END

INSERT INTO [dbo].[Trader]
           ([CustId]
           ,[Username]
           ,[EmployeeId]
           ,[TeamId]
           ,[Grade]
           ,[CreatedDate]
           ,[CreatedBy]
           ,[ModifiedDate]
           ,[ModifiedBy]
           ,[Disabled]
           ,[TeamEffectiveDate]
           ,[GradeEffectiveDate])
SELECT [CustId]
           ,[Username]
           ,[EmployeeId]
           ,[TeamId]
           ,[Grade]
           ,[CreatedDate]
           ,[CreatedBy]
           ,[ModifiedDate]
           ,[ModifiedBy]
           ,[Disabled]
           ,[TeamEffectiveDate]
           ,[GradeEffectiveDate] 
FROM #Trader

INSERT INTO [bodb_TGRS].[dbo].[TraderGrade_History]
           ([CustId]
           ,[Grade]
           ,[BeginDate]
           ,[EndDate])
	SELECT td.[CustId]
		  ,td.[Grade] [Grade]
		  ,td.[GradeEffectiveDate] [BeginDate]
		  ,NULL [EndDate]
	FROM #Trader td
		LEFT JOIN  [bodb_TGRS].dbo.[TraderGrade_History] trg_h WITH (NOLOCK) 	ON trg_h.CustId = td.custid 
	  WHERE trg_h.CustId IS NULL

INSERT INTO [bodb_TGRS].[dbo].[TraderTeam_History]
           ([CustId]
           ,[TeamId]
           ,[BeginDate]
           ,[EndDate])
	SELECT td.[CustId]
		  ,td.TeamId
		  ,td.[TeamEffectiveDate] [BeginDate]
		  ,NULL [EndDate]
	  FROM #Trader td
	  LEFT JOIN  [bodb_TGRS].dbo.[TraderTeam_History] trt_h WITH (NOLOCK) 		ON trt_h.CustId = td.custid
	  WHERE trt_h.CustId IS NULL 
 
IF OBJECT_ID('tempdb..#Trader') IS NOT NULL    DROP TABLE #Trader

GO

GRANT EXECUTE ON [dbo].Task_StagingTraderSetting TO [bodbTGRSNet]
