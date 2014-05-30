ALTER PROCEDURE [dbo].[TGRS_BenchmarkBetType_Update]
	@LeagueId	INT,
	@BetType	SMALLINT,
	@Benchmark	MONEY,
	@UserId		INT,
	@ErrCode	INT = 0 OUTPUT,
	@ErrMsg		NVARCHAR(200) = '' OUTPUT
	 
/*
Created: 20140513@Sophia
Task : Update Benchmark By League
DB:  DBTGRS.bodb_TGRS

Revisions:

Explanation : 
	
   
*/ 

AS
BEGIN
	SET NOCOUNT ON 		

	--Check valid
	IF NOT EXISTS ( SELECT TOP 1 1 FROM dbo.BetType WITH (NOLOCK) WHERE BetType = @BetType)
	BEGIN 
		SELECT  @ErrCode = 405,
				@ErrMsg = 'Bet type is invalid.'
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
	
	IF NOT EXISTS (SELECT  TOP 1 1 FROM dbo.BenchMark_BetType WITH (NOLOCK) WHERE LeagueId = @LeagueId AND BetType = @BetType)
	BEGIN 
		INSERT INTO dbo.BenchMark_BetType(
					LeagueId
					,BetType
					,Benchmark
					,CreatedDate
					,CreatedBy
					)
			VALUES (
					@LeagueId
					,@BetType
					,@Benchmark
					,GETDATE()
					,@UserId
					)

		-- Check fail
		IF @@ERROR > 0
			BEGIN
				SELECT 
					@ErrCode = 406, 
					@ErrMsg = 'Failed to insert benchmark by bet type [Benchmark = ' + CONVERT(VARCHAR(20),@Benchmark) +']'
				RETURN
			END

	 	
		-- Write log 
		SET @xml = (
						SELECT							
							@LeagueId			AS '@l',
							@BetType			AS '@b',
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
				@ObjectId	= @BetType,
				@Data		= @LogBenchmarkData,
				@OldData	= NULL

	END
	ELSE
	BEGIN		

		-- write log before update				
		SET @xml = (
						SELECT  LeagueId	AS '@l',
								BetType		AS '@b',
								Benchmark	AS '@v' 		
						FROM	dbo.BenchMark_BetType WITH (NOLOCK)							
						WHERE	LeagueId = @LeagueId
								AND BetType = @BetType				
						FOR XML PATH('z'),ROOT('r')
					)	 

		SET @LogBenchmarkOldData = REPLACE(CONVERT(VARCHAR(MAX), @xml), '" />', '"/"')
		-- end write log					
		
		---update
		UPDATE  dbo.BenchMark_BetType WITH (ROWLOCK, UPDLOCK)
		SET		Benchmark		= @Benchmark,
				ModifiedDate	= Getdate(),
				ModifiedBy		= @UserId
		WHERE	LeagueId = @LeagueId
				AND BetType = @BetType

		-- Check fail
		IF @@ERROR > 0
			BEGIN
				SELECT 
					@ErrCode = 407, 
					@ErrMsg = 'Failed to update benchmark by bet type [Benchmark = ' + CONVERT(VARCHAR(20),@Benchmark) +']'
				RETURN
			END


		-- Write log after update			
		SET @xml = (	SELECT 	@LeagueId		AS '@l',
								@BetType		AS '@b',
								@Benchmark		AS '@v' 			
						FOR XML PATH('z'), ROOT('r')
					)

		SET @LogBenchmarkData = REPLACE(CONVERT(NVARCHAR(MAX), @Xml), '" />', '"/"')

		SET @EndRun = GETDATE()
		SET @Duration = DATEDIFF(MILLISECOND, @StartRun, @EndRun) 
	
		EXEC	dbo.TGRS_WriteLog_RunSp
				@UserId		= @UserId,
				@SPName		= 'TGRS_BenchmarkBetType_Update',
				@LogDate	= @StartRun,
				@Duration	= @Duration,
				@ObjectId	= @BetType,
				@Data		= @LogBenchmarkData,
				@OldData	= @LogBenchmarkOldData

	END  

END
 
GO
GRANT EXECUTE ON [dbo].[TGRS_BenchmarkBetType_Update] TO [bodbTGRSNet]
GO
	
