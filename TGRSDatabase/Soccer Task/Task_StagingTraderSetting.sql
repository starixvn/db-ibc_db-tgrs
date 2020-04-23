ALTER PROCEDURE [dbo].[Task_StagingTraderSetting]
AS 
/*  
 Created:	20140703@Tom.Vo
 Task :		Staging Trader Data on TGRS DB
 DB:		DBTGRS.bodb_TGRS
 Original:  
  
 Revisions:      
   		- 20140715@Tom.Vo:	  Filter Sport Type 1
   		- 20160314@Aaron.Cao: Added UPDATE Username
		- 20200331@John.Ngo:  Update new table [Dot_Admin_Assignment_Trader] [Redmine ID: 120634]
		- 20200422@John.Ngo:  Update logic for new table [Dot_Admin_Assignment_Trader] [Redmine ID: 131517]

 Param's Explanation:  
	 
 Exam: 

*/ 
BEGIN
	SET NOCOUNT ON;

	--Update Username when they were changed from the original data
	IF EXISTS (	SELECT TOP (1) 1 
				FROM dbo.Trader T WITH (NOLOCK)
				INNER JOIN bodb02.dbo.Customer ci WITH(NOLOCK) ON ci.custid = T.CustId 
				WHERE ci.username <> T.Username AND ci.RoleID > 4)
	BEGIN 
		UPDATE T
		SET T.Username = ci.username, T.ModifiedDate = GETDATE(), T.ModifiedBy = 8
		FROM dbo.Trader T WITH(ROWLOCK, UPDLOCK)
		INNER JOIN bodb02.dbo.Customer ci WITH(NOLOCK) ON ci.custid = T.CustId 
		WHERE ci.username <> T.Username AND ci.RoleID > 4;
	END;

	--Insert new trader
	IF OBJECT_ID('tempdb..#Trader') IS NOT NULL  
	BEGIN
		DROP TABLE #Trader;
	END;

	SELECT DISTINCT [CustId]		 = td.TraderID
		  ,		[Username]			 = ci.Username
		  ,		[EmployeeId]		 = '-'
		  ,		[TeamId]			 = 1 
		  ,		[Grade]				 = 10
		  ,		[CreatedDate]		 = ISNULL(ci.[creatdate],'2011-01-01')
		  ,		[CreatedBy]			 = 8 
		  ,		[ModifiedDate]		 = NULL
		  ,		[ModifiedBy]		 = NULL 
		  ,		[Disabled]			 = 0 
		  ,		[TeamEffectiveDate]  = CONVERT(NVARCHAR(10),ISNULL(ci.[creatdate],'2011-01-01'),20)
		  ,		[GradeEffectiveDate] = CONVERT(NVARCHAR(10),ISNULL(ci.[creatdate],'2011-01-01'),20)
	INTO #Trader
	FROM bodb02.dbo.Dot_Admin_Assignment_Trader td WITH(NOLOCK)  
		INNER JOIN  bodb02.dbo.Customer ci WITH (NOLOCK) ON td.TraderID = ci.custid 
		LEFT JOIN  dbo.Trader tr_h WITH (NOLOCK) ON tr_h.CustId = ci.custid 
		LEFT JOIN [bodb02].[dbo].[match] m WITH(NOLOCK) ON td.matchid = m.matchid	
	WHERE td.TraderID <> 0
		AND tr_h.CustId IS NULL
		AND m.sporttype = 1;
 
	 IF @@ROWCOUNT = 0
		BEGIN
			IF OBJECT_ID('tempdb..#Trader') IS NOT NULL  DROP TABLE #Trader
			RETURN;
		END;

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
	SELECT		[CustId]
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
	FROM #Trader;

	INSERT INTO [dbo].[TraderGrade_History](
			[CustId]
		,	[Grade]
	    ,	[BeginDate]
	    ,	[EndDate])
	SELECT  [CustId]    = td.CustId
		,	[Grade]	    = td.Grade
		,	[BeginDate] = td.GradeEffectiveDate
		,	[EndDate]   = NULL
	FROM #Trader td
		LEFT JOIN  dbo.[TraderGrade_History] trg_h WITH (NOLOCK) ON trg_h.CustId = td.custid 
	WHERE trg_h.CustId IS NULL;

	INSERT INTO [dbo].[TraderTeam_History](
			[CustId]
	   ,	[TeamId]
	   ,	[BeginDate]
	   ,	[EndDate])
	SELECT  [CustId]    = td.CustId
		,	[TeamId]	= td.TeamId
		,	[BeginDate] = td.[TeamEffectiveDate]
		,	[EndDate]   = NULL
	FROM #Trader td
	LEFT JOIN  dbo.[TraderTeam_History] trt_h WITH (NOLOCK) ON trt_h.CustId = td.custid
	WHERE trt_h.CustId IS NULL;
 
	TRUNCATE TABLE #Trader;

END;

GO
/*<info serverAlias="DBTGRS-bodb_TGRS" executers="bodbTGRSNet" isFunction="0" isNested="0"></info>*/
