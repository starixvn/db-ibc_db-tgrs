ALTER PROCEDURE [dbo].[TGRS_BenchmarkTeam_Update]
	@TeamId		INT,
	@Benchmark	MONEY,
	@UserId		INT,
	@ErrCode	INT = 0 OUTPUT,
	@ErrMsg		NVARCHAR(200) = '' OUTPUT
	 
/*
Created: 20140513@Sophia
Task : Update Benchmark By Team
DB:  DBTGRS.bodb_TGRS

Revisions:
	- 20140728@Sophia: Convert Benchmark to decimal number before save
Explanation : 
	
   
*/ 

AS
BEGIN
	SET NOCOUNT ON 		

	--Check valid
	IF NOT EXISTS ( SELECT TOP 1 1 FROM dbo.Team WITH (NOLOCK) WHERE TeamId = @TeamId)
	BEGIN 
		SELECT  @ErrCode = 304,
				@ErrMsg = 'Team is invalid.'
		RETURN
	END 

	-- For write log
	DECLARE 
		@StartRun					DATETIME,
		@EndRun						DATETIME,
		@Duration					INT,
		@LogBenchmarkData			NVARCHAR(MAX),	
		@LogBenchmarkOldData		NVARCHAR(MAX),	
		@Xml						XML 		 

	SET @StartRun = GETDATE()

	SELECT @Benchmark = @Benchmark / 100
	
	IF NOT EXISTS (SELECT  TOP 1 1 FROM dbo.BenchMark_Team WITH (NOLOCK) WHERE TeamId = @TeamId)
	BEGIN 
		INSERT INTO dbo.BenchMark_Team (
					TeamId
					,Benchmark
					,CreatedDate
					,CreatedBy
					)
			VALUES (
					@TeamId
					,@Benchmark
					,GETDATE()
					,@UserId
					)

		-- Check fail
		IF @@ERROR > 0
			BEGIN
				SELECT 
					@ErrCode = 400, 
					@ErrMsg = 'Failed to insert benchmark by team [Benchmark = ' + CONVERT(VARCHAR(20),@Benchmark) +']'
				RETURN
			END

	 	
		-- Write log 
		SET @xml = (
						SELECT							
							@TeamId				AS '@t',
							@Benchmark			AS '@v' 	
						 FOR XML PATH('z'), ROOT('r')
					)

		SET @LogBenchmarkData = REPLACE(CONVERT(NVARCHAR(MAX), @Xml), '" />', '"/"')

		SET @EndRun = GETDATE()
		SET @Duration = DATEDIFF(MILLISECOND, @StartRun, @EndRun) 
	
		EXEC	dbo.TGRS_WriteLog_RunSp
				@UserId		= @UserId,
				@SPName		= 'TGRS_BenchmarkTeam_Update',
				@LogDate	= @StartRun,
				@Duration	= @Duration,
				@ObjectId	= @TeamId,
				@Data		= @LogBenchmarkData,
				@OldData	= NULL

	END
	ELSE
	BEGIN		

		-- write log before update				
		SET @xml = (
						SELECT  TeamId		AS '@t',
								Benchmark	AS '@v' 		
						FROM	dbo.BenchMark_Team WITH (NOLOCK)							
						WHERE	TeamId = @TeamId				
						FOR XML PATH('z'),ROOT('r')
					)	 

		SET @LogBenchmarkOldData = REPLACE(CONVERT(VARCHAR(MAX), @xml), '" />', '"/"')
		-- end write log					
		
		---update
		UPDATE  dbo.BenchMark_Team WITH (ROWLOCK, UPDLOCK)
		SET		Benchmark		= @Benchmark,
				ModifiedDate	= Getdate(),
				ModifiedBy		= @UserId
		WHERE	TeamId = @TeamId

		-- Check fail
		IF @@ERROR > 0
			BEGIN
				SELECT 
					@ErrCode = 401, 
					@ErrMsg = 'Failed to update benchmark by team [Benchmark = ' + CONVERT(VARCHAR(20),@Benchmark) +']'
				RETURN
			END


		-- Write log after update			
		SET @xml = (	SELECT 	@TeamId			AS '@t',
								@Benchmark		AS '@v' 			
						FOR XML PATH('z'), ROOT('r')
					)

		SET @LogBenchmarkData = REPLACE(CONVERT(NVARCHAR(MAX), @Xml), '" />', '"/"')

		SET @EndRun = GETDATE()
		SET @Duration = DATEDIFF(MILLISECOND, @StartRun, @EndRun) 
	
		EXEC	dbo.TGRS_WriteLog_RunSp
				@UserId		= @UserId,
				@SPName		= 'TGRS_BenchmarkTeam_Update',
				@LogDate	= @StartRun,
				@Duration	= @Duration,
				@ObjectId	= @TeamId,
				@Data		= @LogBenchmarkData,
				@OldData	= @LogBenchmarkOldData

	END  

END
 
GO
GRANT EXECUTE ON [dbo].[TGRS_BenchmarkTeam_Update] TO [bodbTGRSNet]
GO
	
