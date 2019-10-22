CREATE PROCEDURE [dbo].[TGRS_BettypeManagement_Bettype_Update]
	@BettypeId INT,
	@NewBettypeId INT = NULL,
	@BettypeName VARCHAR(1000) = NULL,
	@Group INT = NULL,
	@OperatorType INT = NULL,
	@AssignmentBetType INT = NULL,
	@UsedForJuice BIT = NULL,
	@UserId INT,
	@Active BIT = NULL,
	@ErrCode INT = 0 OUTPUT,
	@ErrMsg NVARCHAR(200) = '' OUTPUT
/*
Created: 20171122@Simon
Task : update a bettype
DB:  DBTGRS.bodb_TGRS

*/ 
AS
BEGIN
	SET NOCOUNT ON

	BEGIN TRY
		DECLARE @xml XML =
			(
				SELECT 
					BetType AS '@b',
					TypeName AS '@bn',
					BettypeGroup AS '@g',
					OperatorType AS '@o',
					AssignmentBetType AS '@a',
					IsUsedForJuice AS '@j',
					1 - [Disabled] AS '@at'
				FROM BetType WITH(NOLOCK)
				WHERE BetType = @BettypeId
				FOR XML PATH('z'), ROOT('r')
			)

		DECLARE @OldData NVARCHAR(MAX) = REPLACE(CONVERT(NVARCHAR(MAX), @Xml), '" />', '"/"')
		DECLARE @StartRun DATETIME = GETDATE()

		UPDATE  BetType
			SET 
				BetType =  ISNULL(@NewBettypeId, BetType),
				TypeName = ISNULL(@BettypeName, TypeName),
				BettypeGroup = ISNULL(@Group, BettypeGroup),
				OperatorType = ISNULL(@OperatorType, OperatorType),
				AssignmentBetType = ISNULL(@AssignmentBetType, AssignmentBetType),
				IsUsedForJuice = ISNULL(@UsedForJuice, IsUsedForJuice),
				[Disabled] = ISNULL(1 - @Active, [Disabled])
		WHERE BetType = @BettypeId

		SET @xml  = 
			(
				SELECT 
					@BettypeId AS '@b',
					@BettypeName AS '@bn',
					@Group AS '@g',
					@OperatorType AS '@o',
					@AssignmentBetType AS '@a',
					@UsedForJuice	 AS '@j',
					@Active AS '@at'
				FOR XML PATH('z'), ROOT('r')
			)

		DECLARE @NewData NVARCHAR(MAX) = REPLACE(CONVERT(NVARCHAR(MAX), @Xml), '" />', '"/"')
		DECLARE @EndRun DATETIME = GETDATE()
		DECLARE @Duration INT = DATEDIFF(MILLISECOND, @StartRun, @EndRun)

		EXEC	dbo.TGRS_WriteLog_RunSp
			@UserId		= @UserId,
			@SPName		= 'TGRS_BettypeManagement_Bettype_Insert',
			@LogDate	= @StartRun,
			@Duration	= @Duration,
			@ObjectId	= @BettypeId,
			@Data		= @NewData,
			@OldData	= @OldData
	END TRY
	BEGIN CATCH
		SET @ErrCode = ERROR_NUMBER()
		SET @ErrMsg =  'There''s already another bet type with this id'
	END CATCH
END

/* 
GO
GRANT EXECUTE ON [dbo].[TGRS_BettypeManagement_Bettype_Update] TO [bodbTGRSNet]
GO
GRANT VIEW DEFINITION ON [dbo].[TGRS_BettypeManagement_Bettype_Update] TO [bodbTGRSNet]
GO
*/