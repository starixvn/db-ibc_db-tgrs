
ALTER FUNCTION  [dbo].[strSplit_Key] (
	@string		NVARCHAR(4000), 
	@splitter	CHAR(1)
)
RETURNS @res TABLE (val INT PRIMARY KEY)
AS
/**
 * Created by	: Sophia
 * Date			: 20140526
 * Task			: 
 * DB			: DBTGRS.bodb_TGRS
 * Revisions	:
 *	•
 * Parameters:
 *  
 */
BEGIN
	SET @string = ISNULL(@string,'')
	IF SUBSTRING (@string, LEN(@string), 1) <> @splitter
		SET @string = @string + @splitter

	DECLARE 
		@start		INT,
		@word		NVARCHAR(4000), 
		@charindex	INT, 
		@i			INT

	SET @i = 1
	SET @start = 1
	SET @charindex = CHARINDEX(@splitter, @string, @start)

	WHILE (@charindex <> 0)
		 BEGIN
			SET @word = SUBSTRING(@string, @start, @charindex - @start)
			SET @start = @charindex + 1
			SET @charindex = CHARINDEX( @splitter, @string, @start)

			INSERT INTO @res VALUES (@word)

			SET @i = @i + 1
		 END

	RETURN
END

GO
GRANT EXECUTE ON [dbo].[strSplit_Key] TO [bodbTGRSNet]
GO

