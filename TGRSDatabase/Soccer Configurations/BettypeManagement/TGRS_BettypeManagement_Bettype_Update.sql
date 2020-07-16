ALTER PROCEDURE [dbo].[TGRS_BettypeManagement_Bettype_Update]
		@BettypeId			INT
	,	@NewBettypeId		INT = NULL
	,	@BettypeName		VARCHAR(100) = NULL
	,	@Group				INT = NULL
	,	@GroupBettypeId		INT = NULL
	,	@OperatorType		INT = NULL
	,	@AssignmentBetType  INT = NULL
	,	@UsedForJuice		BIT = NULL
	,	@Active				BIT = NULL
	,	@UserId				INT
	,	@ErrCode			INT = 0 OUTPUT
	,	@ErrMsg				NVARCHAR(200) = '' OUTPUT

/*
Created: 20171122@Simon
Task : update a bettype
DB:  DBTGRS.bodb_TGRS

	Revision:
		- 20200714@JohnNgo: [TGR] Soccer - Re-arrange bet type filter with parent-child [Redmine: #137273]

*/ 
AS
BEGIN
	SET NOCOUNT ON

	BEGIN TRY
		DECLARE @xml XML =
			(
				SELECT 
					BetType				AS '@b',
					TypeName			AS '@bn',
					BettypeGroup		AS '@g',
					GroupBettypeId		AS '@gb',
					OperatorType		AS '@o',
					AssignmentBetType	AS '@a',
					IsUsedForJuice		AS '@j',
					1 - [Disabled]		AS '@at'
				FROM dbo.BetType WITH(NOLOCK)
				WHERE BetType = @BettypeId
				FOR XML PATH('z'), ROOT('r')
			);

		DECLARE @OldData NVARCHAR(MAX) = REPLACE(CONVERT(NVARCHAR(MAX), @Xml), '" />', '"/"');
		DECLARE @StartRun DATETIME = GETDATE();

		UPDATE  dbo.BetType WITH (ROWLOCK)
			SET 
				BetType				= ISNULL(@NewBettypeId, BetType),
				TypeName			= ISNULL(@BettypeName, TypeName),
				BettypeGroup		= ISNULL(@Group, BettypeGroup),
				GroupBettypeId		= ISNULL(@GroupBettypeId, GroupBettypeId),
				OperatorType		= ISNULL(@OperatorType, OperatorType),
				AssignmentBetType	= ISNULL(@AssignmentBetType, AssignmentBetType),
				IsUsedForJuice		= ISNULL(@UsedForJuice, IsUsedForJuice),
				[Disabled]			= ISNULL(1 - @Active, [Disabled])
		WHERE BetType = @BettypeId;

		SET @xml  = 
			(
				SELECT 
					@NewBettypeId		AS '@b',
					@BettypeName		AS '@bn',
					@Group				AS '@g',
					@GroupBettypeId		AS '@gb',
					@OperatorType		AS '@o',
					@AssignmentBetType	AS '@a',
					@UsedForJuice		AS '@j',
					@Active				AS '@at'
				FOR XML PATH('z'), ROOT('r')
			);

		DECLARE @NewData	NVARCHAR(MAX)	= REPLACE(CONVERT(NVARCHAR(MAX), @Xml), '" />', '"/"');
		DECLARE @EndRun		DATETIME		= GETDATE();
		DECLARE @Duration	INT				= DATEDIFF(MILLISECOND, @StartRun, @EndRun);

		EXEC dbo.TGRS_WriteLog_RunSp
			@UserId		= @UserId,
			@SPName		= 'TGRS_BettypeManagement_Bettype_Update',
			@LogDate	= @StartRun,
			@Duration	= @Duration,
			@ObjectId	= @BettypeId,
			@Data		= @NewData,
			@OldData	= @OldData
	END TRY
	BEGIN CATCH
		SET @ErrCode = ERROR_NUMBER()
		SET @ErrMsg  =  'Something wrong happened. Contact admin for detailed info.'
	END CATCH
END;

GO
/*<info serverAlias="DBTGRS-bodb_TGRS" executers="bodbTGRSNet" isFunction="0" isNested="0"></info>*/