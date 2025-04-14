/*<info serverAlias="DBTGRS-bodb_TGRS" executers="wsv_tgrs" isFunction="0" isNested="0"></info>*/
/*
	Creator:	20250411@Jaden.Tang
	Task:		Add hdp column to dbo.OSDataTGRS_BetChoice - [Redmine: #170019]
	Server:		DB06.bodb_TGRS
*/

-- https://nexdev.net/issues/170019

use bodb_tgrs;
GO

-- Add hdp column to dbo.OSDataTGRS_BetChoice
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE Name = N'hdp' AND Object_ID = Object_ID(N'dbo.OSDataTGRS_BetChoice'))
BEGIN
    ALTER TABLE dbo.OSDataTGRS_BetChoice
    ADD hdp SMALLMONEY NULL;
    PRINT 'Column [hdp] added to table [dbo.OSDataTGRS_BetChoice].'
END
ELSE
BEGIN
    PRINT 'Column [hdp] already exists in table [dbo.OSDataTGRS_BetChoice].'
END
GO 