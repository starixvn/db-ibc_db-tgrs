
 UPDATE LogAction 
 SET Items = '<root><xml path="r/z" /><row item="LeagueId" alias="l" /><row item="BetType" alias="b" /><row item="Benchmark" alias="v" /><row item="WorkShift" alias="s" /></root>'
 WHERE SPNAME = 'TGRS_BenchmarkBetType_Update'

 --------------------------------
 INSERT INTO LogAction (
 ActionId,
ActionTypeId,
SPName,
ActionName,
Items,
SubItems,
IsInternal)

VALUES (
500,
5,
'TGRS_Setting_ScorePeriodUpd',
'Setting score period',
'<root><xml path="r/z" /><row item="BeginDay" alias="b" /><row item="EndDay" alias="e" /><row item="SelectedDay" alias="s" /></root>',
NULL,
0
) 
 
 --------------------------


 INSERT INTO SystemSettings (VName,VValue)
 VALUES ('BeginDay', '1900-01-01')

 

 INSERT INTO SystemSettings (VName,VValue)
 VALUES ('SelectedDay', '1900-06-30')

 

 INSERT INTO SystemSettings (VName,VValue)
 VALUES ('EndDay', '1900-12-31')

  
  -----------------

Update Benchmark_BetType 
SET	ModifiedDate = CreatedDate,
	ModifiedBy = CreatedBy
WHERE ModifiedDate IS NULL