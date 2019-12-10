
ALTER FUNCTION  [dbo].[strSplit_Key] ( @string NVARCHAR(MAX), @splitter CHAR( 1) )
RETURNS TABLE
WITH SCHEMABINDING
AS
/*
	Created: Unknow
	Task : Split string
	DB: DBCUST.CustDB

	Original:

	Revisions:
		- 20191001@Patrick: Change to use xml instead temp # [Redmine: #118117]

	Param explanation:
*/

RETURN 
(  
    SELECT val = y.i.value('(./text())[1]', 'nvarchar(max)')
    FROM 
    ( 
    SELECT x = CONVERT(XML, '<i>' 
        + REPLACE(@string, @splitter, '</i><i>') 
        + '</i>').query('.')
    ) AS a CROSS APPLY x.nodes('i') AS y(i)
);

GO
/*<info serverAlias="DBTGRS-bodb_TGRS" executers="bodbTGRSNet" isFunction="1" isNested="0"></info>*/