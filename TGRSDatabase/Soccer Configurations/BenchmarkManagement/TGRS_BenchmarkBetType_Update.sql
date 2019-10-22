ALTER PROCEDURE [dbo].[TGRS_BenchmarkBetType_Update]
	@LeagueId	INT,
	@BetType	SMALLINT,
	@Benchmark	MONEY ,
	@WorkShift	TINYINT ,
	@UserId		INT,
	@ErrCode	INT = 0 OUTPUT,
	@ErrMsg		NVARCHAR(200) = '' OUTPUT
	 
/*
Created: 20140513@Sophia
Task : Update Benchmark By League
DB:  DBTGRS.bodb_TGRS

Revisions:
	- 20140728@Sophia: Convert Benchmark to decimal number before save
	- 20141130: Update benchmark by workshift

Explanation : 	
	EXEC TGRS_BenchmarkBetType_Update_Xtest 	
		@LeagueId	= 3,
		@BetType	= -1,
		@Benchmark	= 40 ,
		@WorkShift	= 2 , 
		@UserID = 8
   
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
		@ModifiedDate				DATE,
		@StartRun					DATETIME,
		@EndRun						DATETIME,
		@Duration					INT,
		@LogBenchmarkData			NVARCHAR(MAX),	
		@LogBenchmarkOldData		NVARCHAR(MAX),	
		@Xml						XML 		 

	SET @StartRun = GETDATE()
	SET @ModifiedDate = GETDATE()
	
	SELECT @Benchmark = @Benchmark / 100

	IF NOT EXISTS (SELECT TOP 1 1 FROM dbo.BenchMark_BetType WITH (NOLOCK) WHERE LeagueId = @LeagueId AND BetType = @BetType AND WorkShift = @WorkShift)
	BEGIN 
		----1. insert into BenchMark_BetType
		INSERT INTO dbo.BenchMark_BetType(
					LeagueId
					,BetType
					,Benchmark
					,WorkShift
					,CreatedDate
					,CreatedBy
					,ModifiedDate
					,ModifiedBy
					)
			VALUES (
					@LeagueId
					,@BetType
					,@Benchmark
					,@WorkShift
					,@ModifiedDate
					,@UserId
					,@ModifiedDate
					,@UserId
					)

		-- Check fail
		IF @@ERROR > 0
			BEGIN
				SELECT 
					@ErrCode = 406, 
					@ErrMsg = 'Failed to insert benchmark by bet type [LeagueId = '+ CONVERT(VARCHAR(20),@LeagueId) +', Bettype = ' + CONVERT(VARCHAR(20),@BetType) +', WorkShift = ' + CONVERT(VARCHAR(20),@WorkShift)+']'
				RETURN
			END


		-----2. insert into history table
		IF NOT EXISTS (SELECT TOP 1 1 FROM dbo.Benchmark_BetType_History WITH (NOLOCK) WHERE LeagueId = @LeagueId AND BetType = @BetType AND WorkShift = @WorkShift AND ModifiedDate = @ModifiedDate)
		BEGIN 
			INSERT INTO dbo.Benchmark_BetType_History(
					LeagueId
					,BetType
					,Benchmark
					,WorkShift					
					,ModifiedDate
					,ModifiedBy
					)
			VALUES (
					@LeagueId
					,@BetType
					,@Benchmark
					,@WorkShift
					,@ModifiedDate
					,@UserId
					)

			-- Check fail
			IF @@ERROR > 0
				BEGIN
					SELECT 
						@ErrCode = 408, 
						@ErrMsg = 'Failed to insert benchmark by bet type history [LeagueId = '+ CONVERT(VARCHAR(20),@LeagueId) +', Bettype = ' + CONVERT(VARCHAR(20),@BetType) +', WorkShift = ' + CONVERT(VARCHAR(20),@WorkShift)+']'
					RETURN
				END
		END 
		ELSE 
		BEGIN 

			UPDATE dbo.Benchmark_BetType_History WITH (UPDLOCK, ROWLOCK)
			SET    LeagueId = @LeagueId				
					,BetType = @BetType
					,Benchmark = @Benchmark
					,WorkShift = @WorkShift				
					,ModifiedDate = @ModifiedDate
					,ModifiedBy = @UserId	
			WHERE  LeagueId = @LeagueId AND BetType = @BetType AND WorkShift = @WorkShift AND ModifiedDate = @ModifiedDate			

			-- Check fail
			IF @@ERROR > 0
				BEGIN
					SELECT 
						@ErrCode = 409, 
						@ErrMsg = 'Failed to update benchmark by bet type history [LeagueId = '+ CONVERT(VARCHAR(20),@LeagueId) +', Bettype = ' + CONVERT(VARCHAR(20),@BetType) +', WorkShift = ' + CONVERT(VARCHAR(20),@WorkShift)+']'
				END
		END
				
		----3. Write log 
		SET @xml = (
						SELECT							
							@LeagueId			AS '@l',
							@BetType			AS '@b',
							@Benchmark			AS '@v',
							@WorkShift			AS '@s'	 	
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
				@OldData	= NULL
	END 	
	ELSE
	BEGIN 
			-- 1. write log before update				
			SET @xml = (
							SELECT  LeagueId	AS '@l',
									BetType		AS '@b',
									Benchmark	AS '@v',
									WorkShift 	AS '@s'
							FROM	dbo.BenchMark_BetType WITH (NOLOCK)							
							WHERE	LeagueId = @LeagueId
									AND BetType = @BetType	
									AND WorkShift = @WorkShift			
							FOR XML PATH('z'),ROOT('r')
						)	 

			SET @LogBenchmarkOldData = REPLACE(CONVERT(VARCHAR(MAX), @xml), '" />', '"/"')
			-- end write log					
		 
			-----2. update to BenchMark_BetType

			UPDATE  dbo.BenchMark_BetType WITH (ROWLOCK, UPDLOCK)
			SET		Benchmark		= @Benchmark,
					ModifiedDate	= @ModifiedDate,
					ModifiedBy		= @UserId
			WHERE	LeagueId = @LeagueId
					AND BetType = @BetType
					AND WorkShift = @WorkShift

			-- Check fail
			IF @@ERROR > 0
				BEGIN
					SELECT 
						@ErrCode = 407, 
						@ErrMsg = 'Failed to update benchmark by bet type  [LeagueId = '+ CONVERT(VARCHAR(20),@LeagueId) +', Bettype = ' + CONVERT(VARCHAR(20),@BetType) +', WorkShift = ' + CONVERT(VARCHAR(20),@WorkShift)+']'
					RETURN
				END

			
			-----3. insert into history table
		IF NOT EXISTS (SELECT TOP 1 1 FROM dbo.Benchmark_BetType_History WITH (NOLOCK) WHERE LeagueId = @LeagueId AND BetType = @BetType AND WorkShift = @WorkShift AND ModifiedDate = @ModifiedDate)
		BEGIN 
			INSERT INTO dbo.Benchmark_BetType_History(
					LeagueId
					,BetType
					,Benchmark
					,WorkShift					
					,ModifiedDate
					,ModifiedBy
					)
			VALUES (
					@LeagueId
					,@BetType
					,@Benchmark
					,@WorkShift
					,@ModifiedDate
					,@UserId
					)

			-- Check fail
			IF @@ERROR > 0
				BEGIN
					SELECT 
						@ErrCode = 409, 
						@ErrMsg = 'Failed to update benchmark by bet type history [LeagueId = '+ CONVERT(VARCHAR(20),@LeagueId) +', Bettype = ' + CONVERT(VARCHAR(20),@BetType) +', WorkShift = ' + CONVERT(VARCHAR(20),@WorkShift)+']'
					RETURN
				END
		END 
		ELSE 
		BEGIN 

			UPDATE dbo.Benchmark_BetType_History WITH (ROWLOCK, UPDLOCK)
			SET    LeagueId = @LeagueId				
					,BetType = @BetType
					,Benchmark = @Benchmark
					,WorkShift = @WorkShift				
					,ModifiedDate = @ModifiedDate
					,ModifiedBy = @UserId	
			WHERE  LeagueId = @LeagueId AND BetType = @BetType AND WorkShift = @WorkShift AND ModifiedDate = @ModifiedDate

			-- Check fail
			IF @@ERROR > 0
				BEGIN
					SELECT 
						@ErrCode = 409, 
						@ErrMsg = 'Failed to update benchmark by bet type history [LeagueId = '+ CONVERT(VARCHAR(20),@LeagueId) +', Bettype = ' + CONVERT(VARCHAR(20),@BetType) +', WorkShift = ' + CONVERT(VARCHAR(20),@WorkShift)+']'
				END
		 END


			----4. Write log after update			
			SET @xml = (	SELECT 	@LeagueId		AS '@l',
									@BetType		AS '@b',
									@Benchmark		AS '@v',
									@WorkShift		AS '@s' 
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
	
