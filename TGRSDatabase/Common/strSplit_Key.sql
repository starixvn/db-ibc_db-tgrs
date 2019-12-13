ALTER FUNCTION  [dbo].[strSplit_Key] ( @string NVARCHAR(MAX), @splitter CHAR( 1) )
RETURNS @res TABLE ( id INT PRIMARY KEY, rank INT, val NVARCHAR(4000) )

AS
/*
	Created: Long.Luu
	Task : Split string
	DB:	DBTGRS.bodb_TGRS
	Original:

	Revisions:
		- 20191212@Long.Luu: Update Split string [Redmine: #118960]

	Param explanation:
*/

BEGIN
     IF SUBSTRING(@string, LEN(@string), 1) <> @splitter
          SET @string = @string + @splitter
     DECLARE @start INT, @word NVARCHAR(4000), @charindex INT, @i INT
     SET @i = 1
     SET @start = 1
     SET @charindex = CHARINDEX(@splitter, @string, @start)
     WHILE (@charindex <> 0)
	 BEGIN
          SET @word = SUBSTRING(@string, @start, @charindex - @start)
          SET @start = @charindex + 1
          SET @charindex = CHARINDEX(@splitter, @string, @start)
          INSERT INTO @res VALUES (@start, @i, @word)
          SET @i = @i + 1
     END
     RETURN
END

GO
/*<info serverAlias="DBTGRS-bodb_TGRS" executers="bodbTGRSNet" isFunction="1" isNested="0"></info>*/