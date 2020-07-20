/*
Creator: 20200714@John.Ngo
Task:  Init Data for Re-arrange bet type filter with parent-child [Redmine ID: 137273]
Server:  bodb_TGRS

Reviewer: Partrick
*/ 

--USE	bodb_TGRS;
--GO
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
SET NOCOUNT ON;

DECLARE @CurrentDate DATETIME = GETDATE();

INSERT INTO dbo.GroupBettype(GroupBettypeId,GroupBettypeName,CreatedBy,CreatedDate)
VALUES(1, N'Major', 20902509 ,@CurrentDate);
INSERT INTO dbo.GroupBettype(GroupBettypeId,GroupBettypeName,CreatedBy,CreatedDate)
VALUES(2, N'1X2', 20902509 ,@CurrentDate);
INSERT INTO dbo.GroupBettype(GroupBettypeId,GroupBettypeName,CreatedBy,CreatedDate)
VALUES(3, N'Corner AIO', 20902509 ,@CurrentDate);
INSERT INTO dbo.GroupBettype(GroupBettypeId,GroupBettypeName,CreatedBy,CreatedDate)
VALUES(4, N'ET&PEN AIO', 20902509 ,@CurrentDate);
INSERT INTO dbo.GroupBettype(GroupBettypeId,GroupBettypeName,CreatedBy,CreatedDate)
VALUES(5, N'PH AIO', 20902509 ,@CurrentDate);

--Major Bet Types
UPDATE dbo.BetType WITH(ROWLOCK) SET GroupBettypeId = 1 WHERE BetType NOT IN (5,15,458,459,
470,471,472,473,474,475,476,477,478,479,481,482,483,484,485,486,487,488,489,490,491,492,493,494,495,496,497,
381,382,383,384,385,386,387,388,389,390,391,392,393,394,395,396,397,398,399,400,
2,4,6,12,13,14,16,17,18,22,24,25,26,27,28,30,121,122,123,126,127,128,129,130,131,132,136,137,138,139,143,144,401,402,403,404,405,406,407,408,409,410,411,412,413,414,415,416,417,418,419,420,421,422,423,424,425,426,427,428,429,430,431,432,433,434,435,436,437,438,439,440,441,442,443,444,445,446,447,448,449,450,451,452,453,454,455,456,457,460,461,462,463,464,467,468,469);

-- SELECT TOP (1000) * FROM [bodb_TGRS].[dbo].[BetType] WHERE TypeName IN ('1x2','1st 1x2','Asian 1X2','1H Asian 1X2')
--1X2
UPDATE dbo.BetType WITH(ROWLOCK) SET GroupBettypeId = 2 WHERE BetType IN (5,15,458,459);

/*
SELECT TOP (1000) * FROM [bodb_TGRS].[dbo].[BetType] WHERE TypeName IN (
'Corners Odd/Even (own)',
'1H Corners Odd/Even (own)',
'2H Corners Odd/Even',
'Total Corners',
'1H Total Corners (own)',
'Alternative Corners',
'1H Alternative Corners',
'Corner 3-Way Handicap',
'1H Corner 3-Way Handicap',
'Time Of First Corner',
'Time Of 2H First Corner',
'Home Team Corners Over/Under',
'Away Team Corners Over/Under',
'1H Home Team Corners Over/Under',
'1H Away Team Corners Over/Under',
'Corners Race',
'1H Corners Race',
'First Corner (own)',
'1H First Corner (own)',
'2H First Corner',
'Last Corner (own)',
'1H Last Corner (own)',
'HT/FT Total Corners',
'1H Correct Corners',
'2H Correct Corners',
'Corner Highest Scoring Half',
'Corner Highest Scoring Half (2-Way)')
*/
--Corner AIO
UPDATE dbo.BetType WITH(ROWLOCK) SET GroupBettypeId = 3 WHERE BetType IN (470,471,472,473,474,475,476,477,478,479,481,482,483,484,485,486,487,488,489,490,491,492,493,494,495,496,497);

/*
SELECT TOP (1000) * FROM [bodb_TGRS].[dbo].[BetType] WHERE TypeName IN (
'Away Penalty Shootout - Round X',
'Home Penalty Shootout - Round X',
'Penalty Shootout Woodwork - Round X',
'Penalty Shootout Both/One/Neither - Round X',
'Penalty Shootout 1X2 - Round X',
'Away Penalty Shootout Over/Under (First 10)',
'Home Penalty Shootout Over/Under (First 10)',
'Away Penalty Shootout Over/Under (Final Result)',
'Home Penalty Shootout Over/Under (Final Result)',
'Penalty Shootout to Go to Sudden Death',
'Penalty Shootout Exact Total Goals (First 10)',
'Penalty Shootout Correct Score',
'Penalty Shootout Odd/Even (First 10)',
'Penalty Shootout Odd/Even (Final Result)',
'Extra Time Next Goal Method',
'Extra Time Next Goal (own)',
'Extra Time Winning Margin',
'Extra Time Double Chance',
'Extra Time Correct Score (own)',
'Extra Time Odd/Even')
*/
--ET&PEN AIO
UPDATE dbo.BetType WITH(ROWLOCK) SET GroupBettypeId = 4 WHERE BetType IN (381,382,383,384,385,386,387,388,389,390,391,392,393,394,395,396,397,398,399,400);

/*
SELECT TOP (1000) * FROM [bodb_TGRS].[dbo].[BetType] WHERE TypeName IN (
'O/E',
'Correct Score',
'Total Goal',
'1st O/E',
'Clean Sheet',
'First Goal/Last Goal',
'HT/FT',
'2H Handicap',
'2H Over/Under',
'Next Goal',
'Double Chance',
'Draw No Bet',
'Both/One/Neither Team To Score',
'To Win To Nil',
'3-Way Handicap',
'1H Correct Score',
'Home No Bet',
'Away No Bet',
'Draw/No Draw',
'1H Total Goal',
'1H First Goal/Last Goal',
'HT/FT Odd/Even',
'Exact 1H Goal',
'Exact Goal',
'Home Team Total Goal',
'Away Team Total Goal',
'1H Home Team Odd/Even',
'Home Team Odd/Even',
'1H Away Team Odd/Even',
'Away Team Odd/Even',
'1H Result/Total Goals',
'Result/Total Goals',
'Home Team Over/Under',
'Away Team Over/Under',
'1H Home Team Over/Under',
'1H Away Team Over/Under',
'2H Correct Score',
'Exact Total Goals (own)',
'Exact Home Team Goals (own)',
'Winning Margin (own)',
'Exact Away Team Goals (own)',
'1H Double Chance (own)',
'1H Draw No Bet (own)',
'Exact 1H Goals',
'Correct Score (AOS)',
'1H Correct Score (AOS)',
'Result and First Team To Score (own)',
'Half Time/Full Time Correct Score (AOS)',
'Both Teams To Score/Result',
'Both Teams To Score/Total Goal',
'Which Half First Goal',
'Home Team Which Half First Goal',
'Away Team Which Half First Goal',
'First Team 2 Goals',
'First Team 3 Goals',
'First Goal Method',
'To Win From Behind',
'1H Winning Margin',
'1H Both Teams To Score (own)',
'2H Odd/Even (own)',
'Exact 2H Goals',
'2H 1X2 (own)',
'2H Double Chance (own)',
'2H Draw No Bet (own)',
'2H Both Teams To Score (own)',
'Both Halves Over 1.5 Yes/No (own)',
'Both Halves Under 1.5 Yes/No (own)',
'Home To Score In Both Halves (own)',
'Away To Score In Both Halves (own)',
'Home To Win Both Halves (own)',
'Away To Win Both Halves (own)',
'Home To Win Either Half (own)',
'Away To Win Either Half (own)',
'Highest Scoring Half (own)',
'Highest Scoring Half Home Team (own)',
'Highest Scoring Half Away Team (own)',
'Both Teams To Score In 1H/2H',
'Home 1H To Score/2H To Score',
'Away 1H To Score/2H To Score',
'Last Team To Score',
'Double Chance & Total Goals',
'Odd/Even & Total Goals',
'Both Teams to Score / Double Chance',
'Highest Scoring Half (2 Way)',
'1H 3-Way Handicap',
'Double Chance & First Team To Score',
'Time of First Goal',
'1H Both Teams To Score / Result',
'1H Both Teams To Score / Total Goals',
'Which Team Will Win By 5+ Goals',
'Home Team Over/Under (dec)',
'Away Team Over/Under (dec)',
'1H Home Team Over/Under (dec)',
'1H Away Team Over/Under (dec)',
'Half Time/Full Time Exact Total Goals',
'Score Box Handicap',
'Score Box Over/Under')
*/
--PH AIO
UPDATE dbo.BetType WITH(ROWLOCK) SET GroupBettypeId = 5 WHERE BetType IN (2,4,6,12,13,14,16,17,18,22,24,25,26,27,28,30,121,122,123,126,127,128,129,130,131,132,136,137,138,139,143,144,401,402,403,404,405,406,407,408,409,410,411,412,413,414,415,416,417,418,419,420,421,422,423,424,425,426,427,428,429,430,431,432,433,434,435,436,437,438,439,440,441,442,443,444,445,446,447,448,449,450,451,452,453,454,455,456,457,460,461,462,463,464,467,468,469);

-- LogActionType & LogAction
INSERT INTO dbo.LogActionType(ActionTypeId, ActionTypeName)
VALUES(9, N'Bet Type Management');

INSERT INTO dbo.LogAction(ActionId, ActionTypeId, SPName, ActionName, Items, SubItems, IsInternal)
VALUES(900, 9, 'TGRS_BettypeManagement_Bettype_Insert', N'Bet Type Management', '<root><xml path="r/z" /><row item="BettypeId" alias="b" /><row item="BettypeName" alias="bn" /><row item="Group" alias="g" /><row item="GroupBettypeId" alias="gb" /><row item="OperatorType" alias="o" /><row item="AssignmentType" alias="a" /><row item="IsUsedForJuice" alias="j" /><row item="Active" alias="at" /></root>', NULL, 0);

INSERT INTO dbo.LogAction(ActionId, ActionTypeId, SPName, ActionName, Items, SubItems, IsInternal)
VALUES(901, 9, 'TGRS_BettypeManagement_Bettype_Update', N'Bet Type Management', '<root><xml path="r/z" /><row item="BettypeId" alias="b" /><row item="BettypeName" alias="bn" /><row item="Group" alias="g" /><row item="GroupBettypeId" alias="gb" /><row item="OperatorType" alias="o" /><row item="AssignmentType" alias="a" /><row item="IsUsedForJuice" alias="j" /><row item="Active" alias="at" /></root>', NULL, 0);

GO
/*<info serverAlias="DBTGRS-bodb_TGRS"></info>*/