ALTER PROCEDURE [dbo].[TGRS_BettypeManagement_Bettype_Insert]
		@BettypeId			INT
	,	@BettypeName		NVARCHAR(100)
	,	@Group				INT
	,	@GroupBettypeId		INT
	,	@OperatorType		INT
	,	@AssignmentType		INT
	,	@IsUsedForJuice		BIT
	,	@Active				BIT
	,	@UserId				INT
	,	@ErrCode			INT = 0 OUTPUT
    ,	@ErrMsg				NVARCHAR(200) = '' OUTPUT  
/*
Created: 20171122@Simon
Task : Insert new bettype
DB:  DBTGRS.bodb_TGRS

	Revision:
		- 20200714@JohnNgo: [TGR] Soccer - Re-arrange bet type filter with parent-child [Redmine: #137273]

*/ 
AS
BEGIN
	SET NOCOUNT ON;

	BEGIN TRY
		DECLARE @StartRun DATETIME = GETDATE();

		DECLARE @xml XML = 
			(
				SELECT 
					@BettypeId			AS '@b',
					@BettypeName		AS '@bn',
					@Group				AS '@g',
					@GroupBettypeId		AS '@gb',
					@OperatorType		AS '@o',
					@AssignmentType		AS '@a',
					@IsUsedForJuice		AS '@j',
					@Active				AS '@at'
				FOR XML PATH('z'), ROOT('r')
			);

		INSERT INTO dbo.BetType(BetType, TypeName, OrderId, BettypeGroup, GroupBettypeId, OperatorType, AssignmentBetType, IsUsedForJuice, [Disabled])
		VALUES (@BettypeId, @BettypeName, 999, @Group, @GroupBettypeId, @OperatorType, @AssignmentType, @IsUsedForJuice, 1 - @Active);

		DECLARE @EndRun		DATETIME		= GETDATE();
		DECLARE @Duration	INT				= DATEDIFF(MILLISECOND, @StartRun, @EndRun);
		DECLARE @NewData	NVARCHAR(MAX)	= REPLACE(CONVERT(NVARCHAR(MAX), @Xml), '" />', '"/"');

		EXEC dbo.TGRS_WriteLog_RunSp
			@UserId		= @UserId,
			@SPName		= 'TGRS_BettypeManagement_Bettype_Insert',
			@LogDate	= @StartRun,
			@Duration	= @Duration,
			@ObjectId	= @BettypeId,
			@Data		= @NewData,
			@OldData	= NULL;
	END TRY
	BEGIN CATCH
		SET @ErrCode = ERROR_NUMBER();
		SET @ErrMsg  = 'There''s already another bet type with this id';
	END CATCH
END;

GO
/*<info serverAlias="DBTGRS-bodb_TGRS" executers="bodbTGRSNet" isFunction="0" isNested="0"></info>*/