
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[TGRS_Spread_Update]
	@CreatorId	INT = 0,   
	@SpreadDoc	VARCHAR(MAX),
	     
	@ErrCode	INT = 0 OUTPUT,    
	@ErrMsg		NVARCHAR(200) = '' OUTPUT    
/*
Created: 20150122@Long.Luu
Task : Update new Spread inputted from formatted Excel file
DB:  DBTGRS.bodb_TGRS

Revisions:   
*/ 

AS
BEGIN
	SET NOCOUNT ON 	
	
	DECLARE @RowsToProcess  INT
	DECLARE @CurrentRow     INT
	DECLARE @InputLeagueId  INT
	DECLARE @InputBettypeId SMALLINT
	DECLARE @InputSpread	SMALLINT
	
	DECLARE @tmpTableSpreadWithRowNum TABLE (RowIndex INT, LeagueId INT, BettypeId SMALLINT, Spread SMALLINT)
	DECLARE @tmpTableSpread TABLE (LeagueId INT, BettypeId SMALLINT, Spread SMALLINT)
	DECLARE @idoc INT

	EXEC sp_xml_preparedocument @idoc OUTPUT, @SpreadDoc
	
	INSERT INTO @tmpTableSpread(LeagueId, BettypeId, Spread)
	SELECT Data.LeagueId, Data.BettypeId, Data.Spread
	FROM OPENXML (@idoc, '/Root/Row', 2)
			WITH (LeagueId INT, BettypeId SMALLINT, Spread SMALLINT) AS Data
	SET @RowsToProcess = @@ROWCOUNT			
	
	INSERT INTO @tmpTableSpreadWithRowNum(RowIndex, LeagueId, BettypeId, Spread)
	SELECT temp.rownumber, temp.LeagueId, temp.BettypeId, temp.Spread
	FROM (
		SELECT ROW_NUMBER() OVER (ORDER BY tts.LeagueId ASC) AS rownumber, *
		FROM @tmpTableSpread tts) AS temp

	SET @CurrentRow = 0
	WHILE @CurrentRow < @RowsToProcess
	BEGIN
		SET @CurrentRow = @CurrentRow + 1
		SELECT @InputLeagueId = ttswr.LeagueId, @InputBettypeId = ttswr.BetTypeId, @InputSpread = ttswr.Spread
		FROM @tmpTableSpreadWithRowNum ttswr
		WHERE ttswr.RowIndex = @CurrentRow

		IF (SELECT COUNT(*) FROM dbo.Spread s WITH(NOLOCK) WHERE s.LeagueID = @InputLeagueId AND s.Bettype = @InputBettypeId) > 0
			BEGIN
				-- UPDATE SPREAD's VALUE
				EXEC TGRS_Spread_UpdateSingle  @CreatorId, @InputLeagueId, @InputBettypeId, @InputSpread, @ErrCode OUT, @ErrMsg OUT
			END
		ELSE
			BEGIN
				-- INSERT NEW SPREAD
				EXEC TGRS_Spread_InsertSingle @CreatorId, @InputLeagueId, @InputBettypeId, @InputSpread, @ErrCode OUT, @ErrMsg OUT
			END
	END
END
 
GO
GRANT EXECUTE ON [dbo].[TGRS_Spread_Update] TO [bodbTGRSNet]
GO
GRANT VIEW DEFINITION ON [dbo].[TGRS_Spread_Update] TO [bodbTGRSNet]
GO
 