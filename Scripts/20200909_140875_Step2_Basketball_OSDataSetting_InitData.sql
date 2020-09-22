/*
	Creator: 20200909@John.Ngo
	Task: Initial OSBettype of Basketball [Redmine ID: #140875]
	DB: DB06.bodb_TGRS_UAT & DB061.bodb_TGRS

	Reviewer: Partrick
*/

GO
-- OSBettype
INSERT [dbo].[OSBettype] ([BettypeId], [BettypeName], [OrderId], [IsDefault], [MainDBBettype], [OperatorType], [AssignmentBettype], [IsUsedForJuice])
VALUES (618, N'Last Digit Score', 0, 0, NULL, NULL, NULL, 0)
	, (619, N'Home Team Last Digit Score', 0, 0, NULL, NULL, NULL, 0)
	, (620, N'Away Team Last Digit Scoree', 0, 0, NULL, NULL, NULL, 0)
	, (621, N'1H Last Digit Score', 0, 0, NULL, NULL, NULL, 0)
	, (622, N'1H Home Team Last Digit Score', 0, 0, NULL, NULL, NULL, 0)
	, (623, N'1H Away Team Last Digit Score', 0, 0, NULL, NULL, NULL, 0)
	, (624, N'2H Last Digit Score', 0, 0, NULL, NULL, NULL, 0)
	, (625, N'2H Home Team Last Digit Score', 0, 0, NULL, NULL, NULL, 0)
	, (626, N'2H Away Team Last Digit Score', 0, 0, NULL, NULL, NULL, 0)
	, (627, N'Quarter X Last Digit Score', 0, 0, NULL, NULL, NULL, 0)
	, (628, N'Quarter X Home Team Last Digit Score', 0, 0, NULL, NULL, NULL, 0)
	, (629, N'Quarter X Away Team Last Digit Score', 0, 0, NULL, NULL, NULL, 0)
	, (630, N'Quarter X 1X2', 0, 0, NULL, NULL, NULL, 0)
	, (631, N'Quarter X Double Chance', 0, 0, NULL, NULL, NULL, 0)
	, (632, N'Correct Quarter Odd/Even', 0, 0, NULL, NULL, NULL, 0)
	, (633, N'Quarter 1/Quarter 2 Result', 0, 0, NULL, NULL, NULL, 0)
	, (634, N'Quarter 3/Quarter 4 Result', 0, 0, NULL, NULL, NULL, 0)
	, (635, N'Quarter To Win To Nil', 0, 0, NULL, NULL, NULL, 0)
	, (636, N'Quarter To Win From Behind', 0, 0, NULL, NULL, NULL, 0)
	, (637, N'Quarters Winners Handicap', 0, 0, NULL, NULL, NULL, 0)
	, (638, N'Home Team Quarters Win Over/Under', 0, 0, NULL, NULL, NULL, 0)
	, (639, N'Away Team Quarters Win Over/Under', 0, 0, NULL, NULL, NULL, 0)
	, (640, N'Exact Quarter Draw', 0, 0, NULL, NULL, NULL, 0)
	, (641, N'Quarter Draw Over/Under', 0, 0, NULL, NULL, NULL, 0)
	, (642, N'Double Quarter Winner', 0, 0, NULL, NULL, NULL, 0)
	, (643, N'Highest Scoring Quarter', 0, 0, NULL, NULL, NULL, 0)
	, (644, N'Quarter Correct Score', 0, 0, NULL, NULL, NULL, 0)
	, (645, N'1st Half/2nd Half Result', 0, 0, NULL, NULL, NULL, 0)
	, (646, N'Match Handicap & Total', 0, 0, NULL, NULL, NULL, 0)

GO
-- Initial column [GroupBettypeId]
-- Main
UPDATE [dbo].[OSBettype] WITH(ROWLOCK)
SET [GroupBettypeId] = 1 WHERE BettypeId IN (1,2,3,7,8,12,20,21,609,610,611,612);

-- PH AIO
UPDATE [dbo].[OSBettype] WITH(ROWLOCK)
SET [GroupBettypeId] = 2 WHERE BettypeId IN (401,402,403,404,601,602,603,604,605,606,607,608,613,614,615,616,617,618,619,620,621,622,623,624,625,626,627,628,629,630,631,632,633,634,635,636,637,638,639,640,641,642,643,644,645,646);

-- BettypeName
UPDATE [dbo].[OSBettype] WITH(ROWLOCK)
SET BettypeName = '1H Winning Margin 12 Way' WHERE BettypeId = 608;

GO
/*<info serverAlias="DBTGRS-bodb_TGRS"></info>*/