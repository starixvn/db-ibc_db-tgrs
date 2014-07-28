ALTER PROCEDURE [dbo].[TGRS_BenchmarkLeague_Update]
	@LeagueId	INT,
	@Benchmark	MONEY,
	@UserId		INT,
	@ErrCode	INT = 0 OUTPUT,
	@ErrMsg		NVARCHAR(200) = '' OUTPUT
	 
/*
Created: 20140513@Sophia
Task : Update Benchmark By League
DB:  DBTGRS.bodb_TGRS

Revisions:
	- 20140728@Sophia: Convert Benchmark to decimal number before save
Explanation : 
	
   
*/ 

AS
BEGIN
	SET NOCOUNT ON 		

	--Check valid
	IF NOT EXISTS ( SELECT TOP 1 1 FROM bodb02.dbo.League WITH (NOLOCK) WHERE LeagueId = @LeagueId)
	BEGIN 
		SELECT  @ErrCode = 402,
				@ErrMsg = 'League is invalid.'
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

	IF NOT EXISTS (SELECT  TOP 1 1 FROM dbo.BenchMark_League WITH (NOLOCK) WHERE LeagueId = @LeagueId)
	BEGIN 
		INSERT INTO dbo.BenchMark_League (
					LeagueId
					,Benchmark
					,CreatedDate
					,CreatedBy
					)
			VALUES (
					@LeagueId
					,@Benchmark
					,GETDATE()
					,@UserId
					)

		-- Check fail
		IF @@ERROR > 0
			BEGIN
				SELECT 
					@ErrCode = 403, 
					@ErrMsg = 'Failed to insert benchmark by League [Benchmark = ' + CONVERT(VARCHAR(20),@Benchmark) +']'
				RETURN
			END

	 	
		-- Write log 
		SET @xml = (
						SELECT							
							@LeagueId			AS '@l',
							@Benchmark			AS '@v' 	
						 FOR XML PATH('z'), ROOT('r')
					)

		SET @LogBenchmarkData = REPLACE(CONVERT(NVARCHAR(MAX), @Xml), '" />', '"/"')

		SET @EndRun = GETDATE()
		SET @Duration = DATEDIFF(MILLISECOND, @StartRun, @EndRun) 
	
		EXEC	dbo.TGRS_WriteLog_RunSp
				@UserId		= @UserId,
				@SPName		= 'TGRS_BenchmarkLeague_Update',
				@LogDate	= @StartRun,
				@Duration	= @Duration,
				@ObjectId	= @LeagueId,
				@Data		= @LogBenchmarkData,
				@OldData	= NULL

	END
	ELSE
	BEGIN		

		-- write log before update				
		SET @xml = (
						SELECT  LeagueId	AS '@l',
								Benchmark	AS '@v' 		
						FROM	dbo.BenchMark_League WITH (NOLOCK)							
						WHERE	LeagueId = @LeagueId				
						FOR XML PATH('z'),ROOT('r')
					)	 

		SET @LogBenchmarkOldData = REPLACE(CONVERT(VARCHAR(MAX), @xml), '" />', '"/"')
		-- end write log					
		
		---update
		UPDATE  dbo.BenchMark_League WITH (ROWLOCK, UPDLOCK)
		SET		Benchmark		= @Benchmark,
				ModifiedDate	= Getdate(),
				ModifiedBy		= @UserId
		WHERE	LeagueId = @LeagueId

		-- Check fail
		IF @@ERROR > 0
			BEGIN
				SELECT 
					@ErrCode = 404, 
					@ErrMsg = 'Failed to update benchmark by League [Benchmark = ' + CONVERT(VARCHAR(20),@Benchmark) +']'
				RETURN
			END


		-- Write log after update			
		SET @xml = (	SELECT 	@LeagueId		AS '@l',
								@Benchmark		AS '@v' 			
						FOR XML PATH('z'), ROOT('r')
					)

		SET @LogBenchmarkData = REPLACE(CONVERT(NVARCHAR(MAX), @Xml), '" />', '"/"')

		SET @EndRun = GETDATE()
		SET @Duration = DATEDIFF(MILLISECOND, @StartRun, @EndRun) 
	
		EXEC	dbo.TGRS_WriteLog_RunSp
				@UserId		= @UserId,
				@SPName		= 'TGRS_BenchmarkLeague_Update',
				@LogDate	= @StartRun,
				@Duration	= @Duration,
				@ObjectId	= @LeagueId,
				@Data		= @LogBenchmarkData,
				@OldData	= @LogBenchmarkOldData

	END  

END
 
GO
GRANT EXECUTE ON [dbo].[TGRS_BenchmarkLeague_Update] TO [bodbTGRSNet]
GO
	
