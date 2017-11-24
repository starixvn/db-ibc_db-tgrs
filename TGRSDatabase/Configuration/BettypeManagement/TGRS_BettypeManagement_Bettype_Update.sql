CREATE PROCEDURE [dbo].[TGRS_BettypeManagement_Bettype_Update]
	@BettypeId INT,
	@NewBettypeId INT = NULL,
	@BettypeName VARCHAR(1000) = NULL,
	@Group INT = NULL,
	@OperatorType INT = NULL,
	@AssignmentBetType INT = NULL,
	@UsedForJuice BIT = NULL,
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