ALTER PROCEDURE [dbo].[Task_StagingOSTraderSetting]
AS 
/*  
 Created:	20160810@Long.Luu
 Task :		Staging Trader Data for Other Sports on TGRS DB
 DB:		DBTGRS.bodb_TGRS
 Original:  
  
 Revisions:      

		- 20181205@John.Ngo: Adding 74 bettypes to OS's Settings [Redmine ID: #105513]
		- 20200417@John.Ngo: Update new table [Dot_Admin_Assignment_Trader] [Redmine ID: 131517]
 
 Param's Explanation: 

 Exam:	 
*/ 
BEGIN
	SET NOCOUNT ON 

	--Update Username when they were changed from the original data
	IF EXISTS (	SELECT TOP (1) 1 
				FROM dbo.OSTrader T WITH (NOLOCK)
					INNER JOIN bodb02.dbo.Customer ci WITH(NOLOCK) ON ci.custid = T.TraderId 
				WHERE ci.username <> T.TraderName AND ci.RoleID > 4)
	BEGIN 
		UPDATE T
		SET T.TraderName = ci.username, T.ModifiedDate = GETDATE(), T.ModifiedBy = 8
		FROM dbo.OSTrader T WITH(ROWLOCK, UPDLOCK)
			INNER JOIN bodb02.dbo.Customer ci WITH(NOLOCK) ON ci.custid = T.TraderId 
		WHERE ci.username <> T.TraderName AND ci.RoleID > 4;
	END;

	--Insert new trader
	IF OBJECT_ID('tempdb..#OSTrader') IS NOT NULL
		DROP TABLE #OSTrader

	SELECT DISTINCT [TraderId]	= td.TraderID
			,	[Username]		= ci.[Username]
			,	[EmployeeId]	= '-'
			,	[TeamId]		= 0
			,	[Grade]			= 0
			,	[CreatedDate]	= ISNULL(ci.[creatdate],'2011-01-01')
			,	[CreatedBy]		= 8
			,	[ModifiedDate]	= NULL
			,	[ModifiedBy]	= NULL
			,	[Disabled]		= 0
		INTO #OSTrader
	FROM bodb02.dbo.Dot_Admin_Assignment_Trader td WITH(NOLOCK)  
		INNER JOIN  bodb02.dbo.Customer ci WITH (NOLOCK) ON td.TraderID = ci.CustId 
		LEFT JOIN  dbo.OSTrader tr_h WITH (NOLOCK) 	ON tr_h.TraderId = ci.CustId 
		LEFT JOIN bodb02.dbo.[match] m WITH(NOLOCK) ON td.matchid = m.matchid	
	WHERE tr_h.TraderId IS NULL
		AND m.sporttype <> 1
		AND (td.bettype < 31
			OR td.bettype BETWEEN 121 AND 999
			OR td.bettype BETWEEN 1301 and 1399
			OR td.bettype BETWEEN 9001 AND 9074)
		AND td.bettype NOT BETWEEN 801 AND 806 -- metric gaming
		AND td.bettype NOT IN (901, 902, 903) -- bettrade
		AND td.TraderID <> 0;
 
	 IF @@ROWCOUNT = 0
		BEGIN
			IF OBJECT_ID('tempdb..#OSTrader') IS NOT NULL    
				DROP TABLE #OSTrader
			RETURN
		END;

	INSERT INTO [dbo].[OSTrader]
			   ([TraderId]
			   ,[TraderName]
			   ,[EmployeeId]
			   ,[TeamId]
			   ,[GradeId]
			   ,[FirstWorkingDate]
			   ,[CreatedDate]
			   ,[CreatedBy]
			   ,[ModifiedDate]
			   ,[ModifiedBy]
			   ,[Disabled])
	SELECT [CustId]
			   ,[Username]
			   ,[EmployeeId]
			   ,[TeamId]
			   ,[Grade]
			   ,[CreatedDate]
			   ,[CreatedDate]
			   ,[CreatedBy]
			   ,[ModifiedDate]
			   ,[ModifiedBy]
			   ,[Disabled]
	FROM #OSTrader

	IF OBJECT_ID('tempdb..#OSTrader') IS NOT NULL   
		DROP TABLE #OSTrader

END;
GO
/*<info serverAlias="DBTGRS-bodb_TGRS" executers="bodbTGRSNet" isFunction="0" isNested="0"></info>*/