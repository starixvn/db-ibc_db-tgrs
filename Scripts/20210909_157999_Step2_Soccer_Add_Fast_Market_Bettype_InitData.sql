/*
	Creator:	20210909@Adam.Tran
	Task:		Add Fast Market Bettype - [Redmine: #157999]
	DB:			DB06.bodb_TGRS_UAT & DB061.bodb_TGRS
*/

USE bodb_TGRS

INSERT INTO [dbo].[GroupBettype]([GroupBettypeId],[GroupBettypeName] ,[CreatedBy],[CreatedDate])
VALUES(7,'Fast Market', 20902509, GETDATE())

UPDATE bt WITH(ROWLOCK, UPDLOCK)
SET bt.GroupBettypeId = 7
FROM [dbo].[BetType]  AS bt WHERE bt.Bettype in (221,222,223,224,225,226,227)

INSERT INTO [dbo].[BetChoice_FastMarketMapping](BetType, hdp2, betteam, BetOption, IntervalGroupId) VALUES(221, 2, 2, 'Goal-Yes', 1);
INSERT INTO [dbo].[BetChoice_FastMarketMapping](BetType, hdp2, betteam, BetOption, IntervalGroupId) VALUES(221, 4, 4, 'Corner-Yes', 1);
INSERT INTO [dbo].[BetChoice_FastMarketMapping](BetType, hdp2, betteam, BetOption, IntervalGroupId) VALUES(221, 8, 8, 'Free Kick-Yes', 1);
INSERT INTO [dbo].[BetChoice_FastMarketMapping](BetType, hdp2, betteam, BetOption, IntervalGroupId) VALUES(221, 16, 16, 'Goal Kick-Yes', 1);
INSERT INTO [dbo].[BetChoice_FastMarketMapping](BetType, hdp2, betteam, BetOption, IntervalGroupId) VALUES(221, 32, 32, 'Throw In-Yes', 1);
INSERT INTO [dbo].[BetChoice_FastMarketMapping](BetType, hdp2, betteam, BetOption, IntervalGroupId) VALUES(221, 2, 0, 'Goal - No', 1);
INSERT INTO [dbo].[BetChoice_FastMarketMapping](BetType, hdp2, betteam, BetOption, IntervalGroupId) VALUES(221, 4, 0, 'Corner - No', 1);
INSERT INTO [dbo].[BetChoice_FastMarketMapping](BetType, hdp2, betteam, BetOption, IntervalGroupId) VALUES(221, 8, 0, 'Free Kick - No', 1);
INSERT INTO [dbo].[BetChoice_FastMarketMapping](BetType, hdp2, betteam, BetOption, IntervalGroupId) VALUES(221, 16, 0, 'Goal Kick - No', 1);
INSERT INTO [dbo].[BetChoice_FastMarketMapping](BetType, hdp2, betteam, BetOption, IntervalGroupId) VALUES(221, 32, 0, 'Throw In - No', 1);

INSERT INTO [dbo].[BetChoice_FastMarketMapping](BetType, hdp2, betteam, BetOption, IntervalGroupId) VALUES(222, 2, 2, 'Goal-Yes', 2);
INSERT INTO [dbo].[BetChoice_FastMarketMapping](BetType, hdp2, betteam, BetOption, IntervalGroupId) VALUES(222, 2, 0, 'Goal-No', 2);
INSERT INTO [dbo].[BetChoice_FastMarketMapping](BetType, hdp2, betteam, BetOption, IntervalGroupId) VALUES(222, 4, 4, 'Corner-Yes', 2);
INSERT INTO [dbo].[BetChoice_FastMarketMapping](BetType, hdp2, betteam, BetOption, IntervalGroupId) VALUES(222, 4, 0, 'Corner-No', 2);
INSERT INTO [dbo].[BetChoice_FastMarketMapping](BetType, hdp2, betteam, BetOption, IntervalGroupId) VALUES(222, 128, 128, 'Penalty-Yes', 2);
INSERT INTO [dbo].[BetChoice_FastMarketMapping](BetType, hdp2, betteam, BetOption, IntervalGroupId) VALUES(222, 128, 0, 'Penalty-No', 2);
INSERT INTO [dbo].[BetChoice_FastMarketMapping](BetType, hdp2, betteam, BetOption, IntervalGroupId) VALUES(222, 8, 8, 'Free Kick - Yes', 2);
INSERT INTO [dbo].[BetChoice_FastMarketMapping](BetType, hdp2, betteam, BetOption, IntervalGroupId) VALUES(222, 8, 0, 'Free Kick - No', 2);
INSERT INTO [dbo].[BetChoice_FastMarketMapping](BetType, hdp2, betteam, BetOption, IntervalGroupId) VALUES(222, 16, 16, 'Goal Kick - Yes', 2);
INSERT INTO [dbo].[BetChoice_FastMarketMapping](BetType, hdp2, betteam, BetOption, IntervalGroupId) VALUES(222, 16, 0, 'Goal Kick - No', 2);
INSERT INTO [dbo].[BetChoice_FastMarketMapping](BetType, hdp2, betteam, BetOption, IntervalGroupId) VALUES(222, 32, 32, 'Throw In - Yes', 2);
INSERT INTO [dbo].[BetChoice_FastMarketMapping](BetType, hdp2, betteam, BetOption, IntervalGroupId) VALUES(222, 32, 0, 'Throw In - No', 2);

INSERT INTO [dbo].[BetChoice_FastMarketMapping](BetType, hdp2, betteam, BetOption, IntervalGroupId) VALUES(223, 1, 1, 'None', 1);
INSERT INTO [dbo].[BetChoice_FastMarketMapping](BetType, hdp2, betteam, BetOption, IntervalGroupId) VALUES(223, 2, 2, 'Goal', 1);
INSERT INTO [dbo].[BetChoice_FastMarketMapping](BetType, hdp2, betteam, BetOption, IntervalGroupId) VALUES(223, 4, 4, 'Corner', 1);
INSERT INTO [dbo].[BetChoice_FastMarketMapping](BetType, hdp2, betteam, BetOption, IntervalGroupId) VALUES(223, 8, 8, 'Free Kick', 1);
INSERT INTO [dbo].[BetChoice_FastMarketMapping](BetType, hdp2, betteam, BetOption, IntervalGroupId) VALUES(223, 16, 16, 'Goal Kick', 1);
INSERT INTO [dbo].[BetChoice_FastMarketMapping](BetType, hdp2, betteam, BetOption, IntervalGroupId) VALUES(223, 32, 32, 'Throw In', 1);

INSERT INTO [dbo].[BetChoice_FastMarketMapping](BetType, hdp2, betteam, BetOption, IntervalGroupId) VALUES(224, 1, 1, 'None', 2);
INSERT INTO [dbo].[BetChoice_FastMarketMapping](BetType, hdp2, betteam, BetOption, IntervalGroupId) VALUES(224, 2, 2, 'Goal', 2);
INSERT INTO [dbo].[BetChoice_FastMarketMapping](BetType, hdp2, betteam, BetOption, IntervalGroupId) VALUES(224, 4, 4, 'Corner', 2);
INSERT INTO [dbo].[BetChoice_FastMarketMapping](BetType, hdp2, betteam, BetOption, IntervalGroupId) VALUES(224, 64, 64, 'Booking', 2);
INSERT INTO [dbo].[BetChoice_FastMarketMapping](BetType, hdp2, betteam, BetOption, IntervalGroupId) VALUES(224, 128, 128, 'Penalty', 2);

INSERT INTO [dbo].[BetChoice_FastMarketMapping](BetType, hdp2, betteam, BetOption, IntervalGroupId) VALUES(225, 1, 1, 'Set Piece-No', 1);
INSERT INTO [dbo].[BetChoice_FastMarketMapping](BetType, hdp2, betteam, BetOption, IntervalGroupId) VALUES(225, 44, 44, 'Set Piece-Yes', 1);

INSERT INTO [dbo].[BetChoice_FastMarketMapping](BetType, hdp2, betteam, BetOption, IntervalGroupId) VALUES(226, 1, 1, 'None', 1);
INSERT INTO [dbo].[BetChoice_FastMarketMapping](BetType, hdp2, betteam, BetOption, IntervalGroupId) VALUES(226, 26, 26, 'Goal / Free Kick / Goal Kick', 1);
INSERT INTO [dbo].[BetChoice_FastMarketMapping](BetType, hdp2, betteam, BetOption, IntervalGroupId) VALUES(226, 36, 36, 'Corner / Throw In', 1);

INSERT INTO [dbo].[BetChoice_FastMarketMapping](BetType, hdp2, betteam, BetOption, IntervalGroupId) VALUES(227, 1, 1, 'None', 2);
INSERT INTO [dbo].[BetChoice_FastMarketMapping](BetType, hdp2, betteam, BetOption, IntervalGroupId) VALUES(227, 4, 4, 'Corner', 2);
INSERT INTO [dbo].[BetChoice_FastMarketMapping](BetType, hdp2, betteam, BetOption, IntervalGroupId) VALUES(227, 194, 194, 'Goal / Booking / Penalty', 2);

INSERT INTO [dbo].[FastMarket_IntervalGroup](IntervalGroupId, hdp1, Interval) VALUES(1, 0, '00:00-00:59');
INSERT INTO [dbo].[FastMarket_IntervalGroup](IntervalGroupId, hdp1, Interval) VALUES(1, 1, '01:00-01:59');
INSERT INTO [dbo].[FastMarket_IntervalGroup](IntervalGroupId, hdp1, Interval) VALUES(1, 2, '02:00-02:59');
INSERT INTO [dbo].[FastMarket_IntervalGroup](IntervalGroupId, hdp1, Interval) VALUES(1, 3, '03:00-03:59');
INSERT INTO [dbo].[FastMarket_IntervalGroup](IntervalGroupId, hdp1, Interval) VALUES(1, 4, '04:00-04:59');
INSERT INTO [dbo].[FastMarket_IntervalGroup](IntervalGroupId, hdp1, Interval) VALUES(1, 5, '05:00-05:59');
INSERT INTO [dbo].[FastMarket_IntervalGroup](IntervalGroupId, hdp1, Interval) VALUES(1, 6, '06:00-06:59');
INSERT INTO [dbo].[FastMarket_IntervalGroup](IntervalGroupId, hdp1, Interval) VALUES(1, 7, '07:00-07:59');
INSERT INTO [dbo].[FastMarket_IntervalGroup](IntervalGroupId, hdp1, Interval) VALUES(1, 8, '08:00-08:59');
INSERT INTO [dbo].[FastMarket_IntervalGroup](IntervalGroupId, hdp1, Interval) VALUES(1, 9, '09:00-09:59');
INSERT INTO [dbo].[FastMarket_IntervalGroup](IntervalGroupId, hdp1, Interval) VALUES(1, 10, '10:00-10:59');
INSERT INTO [dbo].[FastMarket_IntervalGroup](IntervalGroupId, hdp1, Interval) VALUES(1, 11, '11:00-11:59');
INSERT INTO [dbo].[FastMarket_IntervalGroup](IntervalGroupId, hdp1, Interval) VALUES(1, 12, '12:00-12:59');
INSERT INTO [dbo].[FastMarket_IntervalGroup](IntervalGroupId, hdp1, Interval) VALUES(1, 13, '13:00-13:59');
INSERT INTO [dbo].[FastMarket_IntervalGroup](IntervalGroupId, hdp1, Interval) VALUES(1, 14, '14:00-14:59');
INSERT INTO [dbo].[FastMarket_IntervalGroup](IntervalGroupId, hdp1, Interval) VALUES(1, 15, '15:00-15:59');
INSERT INTO [dbo].[FastMarket_IntervalGroup](IntervalGroupId, hdp1, Interval) VALUES(1, 16, '16:00-16:59');
INSERT INTO [dbo].[FastMarket_IntervalGroup](IntervalGroupId, hdp1, Interval) VALUES(1, 17, '17:00-17:59');
INSERT INTO [dbo].[FastMarket_IntervalGroup](IntervalGroupId, hdp1, Interval) VALUES(1, 18, '18:00-18:59');
INSERT INTO [dbo].[FastMarket_IntervalGroup](IntervalGroupId, hdp1, Interval) VALUES(1, 19, '19:00-19:59');
INSERT INTO [dbo].[FastMarket_IntervalGroup](IntervalGroupId, hdp1, Interval) VALUES(1, 20, '20:00-20:59');
INSERT INTO [dbo].[FastMarket_IntervalGroup](IntervalGroupId, hdp1, Interval) VALUES(1, 21, '21:00-21:59');
INSERT INTO [dbo].[FastMarket_IntervalGroup](IntervalGroupId, hdp1, Interval) VALUES(1, 22, '22:00-22:59');
INSERT INTO [dbo].[FastMarket_IntervalGroup](IntervalGroupId, hdp1, Interval) VALUES(1, 23, '23:00-23:59');
INSERT INTO [dbo].[FastMarket_IntervalGroup](IntervalGroupId, hdp1, Interval) VALUES(1, 24, '24:00-24:59');
INSERT INTO [dbo].[FastMarket_IntervalGroup](IntervalGroupId, hdp1, Interval) VALUES(1, 25, '25:00-25:59');
INSERT INTO [dbo].[FastMarket_IntervalGroup](IntervalGroupId, hdp1, Interval) VALUES(1, 26, '26:00-26:59');
INSERT INTO [dbo].[FastMarket_IntervalGroup](IntervalGroupId, hdp1, Interval) VALUES(1, 27, '27:00-27:59');
INSERT INTO [dbo].[FastMarket_IntervalGroup](IntervalGroupId, hdp1, Interval) VALUES(1, 28, '28:00-28:59');
INSERT INTO [dbo].[FastMarket_IntervalGroup](IntervalGroupId, hdp1, Interval) VALUES(1, 29, '29:00-29:59');
INSERT INTO [dbo].[FastMarket_IntervalGroup](IntervalGroupId, hdp1, Interval) VALUES(1, 30, '30:00-30:59');
INSERT INTO [dbo].[FastMarket_IntervalGroup](IntervalGroupId, hdp1, Interval) VALUES(1, 31, '31:00-31:59');
INSERT INTO [dbo].[FastMarket_IntervalGroup](IntervalGroupId, hdp1, Interval) VALUES(1, 32, '32:00-32:59');
INSERT INTO [dbo].[FastMarket_IntervalGroup](IntervalGroupId, hdp1, Interval) VALUES(1, 33, '33:00-33:59');
INSERT INTO [dbo].[FastMarket_IntervalGroup](IntervalGroupId, hdp1, Interval) VALUES(1, 34, '34:00-34:59');
INSERT INTO [dbo].[FastMarket_IntervalGroup](IntervalGroupId, hdp1, Interval) VALUES(1, 35, '35:00-35:59');
INSERT INTO [dbo].[FastMarket_IntervalGroup](IntervalGroupId, hdp1, Interval) VALUES(1, 36, '36:00-36:59');
INSERT INTO [dbo].[FastMarket_IntervalGroup](IntervalGroupId, hdp1, Interval) VALUES(1, 37, '37:00-37:59');
INSERT INTO [dbo].[FastMarket_IntervalGroup](IntervalGroupId, hdp1, Interval) VALUES(1, 38, '38:00-38:59');
INSERT INTO [dbo].[FastMarket_IntervalGroup](IntervalGroupId, hdp1, Interval) VALUES(1, 39, '39:00-39:59');
INSERT INTO [dbo].[FastMarket_IntervalGroup](IntervalGroupId, hdp1, Interval) VALUES(1, 40, '40:00-40:59');
INSERT INTO [dbo].[FastMarket_IntervalGroup](IntervalGroupId, hdp1, Interval) VALUES(1, 41, '41:00-41:59');
INSERT INTO [dbo].[FastMarket_IntervalGroup](IntervalGroupId, hdp1, Interval) VALUES(1, 42, '42:00-42:59');
INSERT INTO [dbo].[FastMarket_IntervalGroup](IntervalGroupId, hdp1, Interval) VALUES(1, 43, '43:00-43:59');
INSERT INTO [dbo].[FastMarket_IntervalGroup](IntervalGroupId, hdp1, Interval) VALUES(1, 44, '44:00-44:59');
INSERT INTO [dbo].[FastMarket_IntervalGroup](IntervalGroupId, hdp1, Interval) VALUES(1, 45, '45:00-45:59');
INSERT INTO [dbo].[FastMarket_IntervalGroup](IntervalGroupId, hdp1, Interval) VALUES(1, 46, '46:00-46:59');
INSERT INTO [dbo].[FastMarket_IntervalGroup](IntervalGroupId, hdp1, Interval) VALUES(1, 47, '47:00-47:59');
INSERT INTO [dbo].[FastMarket_IntervalGroup](IntervalGroupId, hdp1, Interval) VALUES(1, 48, '48:00-48:59');
INSERT INTO [dbo].[FastMarket_IntervalGroup](IntervalGroupId, hdp1, Interval) VALUES(1, 49, '49:00-49:59');
INSERT INTO [dbo].[FastMarket_IntervalGroup](IntervalGroupId, hdp1, Interval) VALUES(1, 50, '50:00-50:59');
INSERT INTO [dbo].[FastMarket_IntervalGroup](IntervalGroupId, hdp1, Interval) VALUES(1, 51, '51:00-51:59');
INSERT INTO [dbo].[FastMarket_IntervalGroup](IntervalGroupId, hdp1, Interval) VALUES(1, 52, '52:00-52:59');
INSERT INTO [dbo].[FastMarket_IntervalGroup](IntervalGroupId, hdp1, Interval) VALUES(1, 53, '53:00-53:59');
INSERT INTO [dbo].[FastMarket_IntervalGroup](IntervalGroupId, hdp1, Interval) VALUES(1, 54, '54:00-54:59');
INSERT INTO [dbo].[FastMarket_IntervalGroup](IntervalGroupId, hdp1, Interval) VALUES(1, 55, '55:00-55:59');
INSERT INTO [dbo].[FastMarket_IntervalGroup](IntervalGroupId, hdp1, Interval) VALUES(1, 56, '56:00-56:59');
INSERT INTO [dbo].[FastMarket_IntervalGroup](IntervalGroupId, hdp1, Interval) VALUES(1, 57, '57:00-57:59');
INSERT INTO [dbo].[FastMarket_IntervalGroup](IntervalGroupId, hdp1, Interval) VALUES(1, 58, '58:00-58:59');
INSERT INTO [dbo].[FastMarket_IntervalGroup](IntervalGroupId, hdp1, Interval) VALUES(1, 59, '59:00-59:59');
INSERT INTO [dbo].[FastMarket_IntervalGroup](IntervalGroupId, hdp1, Interval) VALUES(1, 60, '60:00-60:59');
INSERT INTO [dbo].[FastMarket_IntervalGroup](IntervalGroupId, hdp1, Interval) VALUES(1, 61, '61:00-61:59');
INSERT INTO [dbo].[FastMarket_IntervalGroup](IntervalGroupId, hdp1, Interval) VALUES(1, 62, '62:00-62:59');
INSERT INTO [dbo].[FastMarket_IntervalGroup](IntervalGroupId, hdp1, Interval) VALUES(1, 63, '63:00-63:59');
INSERT INTO [dbo].[FastMarket_IntervalGroup](IntervalGroupId, hdp1, Interval) VALUES(1, 64, '64:00-64:59');
INSERT INTO [dbo].[FastMarket_IntervalGroup](IntervalGroupId, hdp1, Interval) VALUES(1, 65, '65:00-65:59');
INSERT INTO [dbo].[FastMarket_IntervalGroup](IntervalGroupId, hdp1, Interval) VALUES(1, 66, '66:00-66:59');
INSERT INTO [dbo].[FastMarket_IntervalGroup](IntervalGroupId, hdp1, Interval) VALUES(1, 67, '67:00-67:59');
INSERT INTO [dbo].[FastMarket_IntervalGroup](IntervalGroupId, hdp1, Interval) VALUES(1, 68, '68:00-68:59');
INSERT INTO [dbo].[FastMarket_IntervalGroup](IntervalGroupId, hdp1, Interval) VALUES(1, 69, '69:00-69:59');
INSERT INTO [dbo].[FastMarket_IntervalGroup](IntervalGroupId, hdp1, Interval) VALUES(1, 70, '70:00-70:59');
INSERT INTO [dbo].[FastMarket_IntervalGroup](IntervalGroupId, hdp1, Interval) VALUES(1, 71, '71:00-71:59');
INSERT INTO [dbo].[FastMarket_IntervalGroup](IntervalGroupId, hdp1, Interval) VALUES(1, 72, '72:00-72:59');
INSERT INTO [dbo].[FastMarket_IntervalGroup](IntervalGroupId, hdp1, Interval) VALUES(1, 73, '73:00-73:59');
INSERT INTO [dbo].[FastMarket_IntervalGroup](IntervalGroupId, hdp1, Interval) VALUES(1, 74, '74:00-74:59');
INSERT INTO [dbo].[FastMarket_IntervalGroup](IntervalGroupId, hdp1, Interval) VALUES(1, 75, '75:00-75:59');
INSERT INTO [dbo].[FastMarket_IntervalGroup](IntervalGroupId, hdp1, Interval) VALUES(1, 76, '76:00-76:59');
INSERT INTO [dbo].[FastMarket_IntervalGroup](IntervalGroupId, hdp1, Interval) VALUES(1, 77, '77:00-77:59');
INSERT INTO [dbo].[FastMarket_IntervalGroup](IntervalGroupId, hdp1, Interval) VALUES(1, 78, '78:00-78:59');
INSERT INTO [dbo].[FastMarket_IntervalGroup](IntervalGroupId, hdp1, Interval) VALUES(1, 79, '79:00-79:59');
INSERT INTO [dbo].[FastMarket_IntervalGroup](IntervalGroupId, hdp1, Interval) VALUES(1, 80, '80:00-80:59');
INSERT INTO [dbo].[FastMarket_IntervalGroup](IntervalGroupId, hdp1, Interval) VALUES(1, 81, '81:00-81:59');
INSERT INTO [dbo].[FastMarket_IntervalGroup](IntervalGroupId, hdp1, Interval) VALUES(1, 82, '82:00-82:59');
INSERT INTO [dbo].[FastMarket_IntervalGroup](IntervalGroupId, hdp1, Interval) VALUES(1, 83, '83:00-83:59');
INSERT INTO [dbo].[FastMarket_IntervalGroup](IntervalGroupId, hdp1, Interval) VALUES(1, 84, '84:00-84:59');
INSERT INTO [dbo].[FastMarket_IntervalGroup](IntervalGroupId, hdp1, Interval) VALUES(1, 85, '85:00-85:59');
INSERT INTO [dbo].[FastMarket_IntervalGroup](IntervalGroupId, hdp1, Interval) VALUES(1, 86, '86:00-86:59');
INSERT INTO [dbo].[FastMarket_IntervalGroup](IntervalGroupId, hdp1, Interval) VALUES(1, 87, '87:00-87:59');
INSERT INTO [dbo].[FastMarket_IntervalGroup](IntervalGroupId, hdp1, Interval) VALUES(1, 88, '88:00-88:59');
INSERT INTO [dbo].[FastMarket_IntervalGroup](IntervalGroupId, hdp1, Interval) VALUES(1, 89, '89:00-89:59');

INSERT INTO [dbo].[FastMarket_IntervalGroup](IntervalGroupId, hdp1, Interval) VALUES(2, 0, '00:00-04:59');
INSERT INTO [dbo].[FastMarket_IntervalGroup](IntervalGroupId, hdp1, Interval) VALUES(2, 1, '01:00-05:59');
INSERT INTO [dbo].[FastMarket_IntervalGroup](IntervalGroupId, hdp1, Interval) VALUES(2, 2, '02:00-06:59');
INSERT INTO [dbo].[FastMarket_IntervalGroup](IntervalGroupId, hdp1, Interval) VALUES(2, 3, '03:00-07:59');
INSERT INTO [dbo].[FastMarket_IntervalGroup](IntervalGroupId, hdp1, Interval) VALUES(2, 4, '04:00-08:59');
INSERT INTO [dbo].[FastMarket_IntervalGroup](IntervalGroupId, hdp1, Interval) VALUES(2, 5, '05:00-09:59');
INSERT INTO [dbo].[FastMarket_IntervalGroup](IntervalGroupId, hdp1, Interval) VALUES(2, 6, '06:00-10:59');
INSERT INTO [dbo].[FastMarket_IntervalGroup](IntervalGroupId, hdp1, Interval) VALUES(2, 7, '07:00-11:59');
INSERT INTO [dbo].[FastMarket_IntervalGroup](IntervalGroupId, hdp1, Interval) VALUES(2, 8, '08:00-12:59');
INSERT INTO [dbo].[FastMarket_IntervalGroup](IntervalGroupId, hdp1, Interval) VALUES(2, 9, '09:00-13:59');
INSERT INTO [dbo].[FastMarket_IntervalGroup](IntervalGroupId, hdp1, Interval) VALUES(2, 10, '10:00-14:59');
INSERT INTO [dbo].[FastMarket_IntervalGroup](IntervalGroupId, hdp1, Interval) VALUES(2, 11, '11:00-15:59');
INSERT INTO [dbo].[FastMarket_IntervalGroup](IntervalGroupId, hdp1, Interval) VALUES(2, 12, '12:00-16:59');
INSERT INTO [dbo].[FastMarket_IntervalGroup](IntervalGroupId, hdp1, Interval) VALUES(2, 13, '13:00-17:59');
INSERT INTO [dbo].[FastMarket_IntervalGroup](IntervalGroupId, hdp1, Interval) VALUES(2, 14, '14:00-18:59');
INSERT INTO [dbo].[FastMarket_IntervalGroup](IntervalGroupId, hdp1, Interval) VALUES(2, 15, '15:00-19:59');
INSERT INTO [dbo].[FastMarket_IntervalGroup](IntervalGroupId, hdp1, Interval) VALUES(2, 16, '16:00-20:59');
INSERT INTO [dbo].[FastMarket_IntervalGroup](IntervalGroupId, hdp1, Interval) VALUES(2, 17, '17:00-21:59');
INSERT INTO [dbo].[FastMarket_IntervalGroup](IntervalGroupId, hdp1, Interval) VALUES(2, 18, '18:00-22:59');
INSERT INTO [dbo].[FastMarket_IntervalGroup](IntervalGroupId, hdp1, Interval) VALUES(2, 19, '19:00-23:59');
INSERT INTO [dbo].[FastMarket_IntervalGroup](IntervalGroupId, hdp1, Interval) VALUES(2, 20, '20:00-24:59');
INSERT INTO [dbo].[FastMarket_IntervalGroup](IntervalGroupId, hdp1, Interval) VALUES(2, 21, '21:00-25:59');
INSERT INTO [dbo].[FastMarket_IntervalGroup](IntervalGroupId, hdp1, Interval) VALUES(2, 22, '22:00-26:59');
INSERT INTO [dbo].[FastMarket_IntervalGroup](IntervalGroupId, hdp1, Interval) VALUES(2, 23, '23:00-27:59');
INSERT INTO [dbo].[FastMarket_IntervalGroup](IntervalGroupId, hdp1, Interval) VALUES(2, 24, '24:00-28:59');
INSERT INTO [dbo].[FastMarket_IntervalGroup](IntervalGroupId, hdp1, Interval) VALUES(2, 25, '25:00-29:59');
INSERT INTO [dbo].[FastMarket_IntervalGroup](IntervalGroupId, hdp1, Interval) VALUES(2, 26, '26:00-30:59');
INSERT INTO [dbo].[FastMarket_IntervalGroup](IntervalGroupId, hdp1, Interval) VALUES(2, 27, '27:00-31:59');
INSERT INTO [dbo].[FastMarket_IntervalGroup](IntervalGroupId, hdp1, Interval) VALUES(2, 28, '28:00-32:59');
INSERT INTO [dbo].[FastMarket_IntervalGroup](IntervalGroupId, hdp1, Interval) VALUES(2, 29, '29:00-33:59');
INSERT INTO [dbo].[FastMarket_IntervalGroup](IntervalGroupId, hdp1, Interval) VALUES(2, 30, '30:00-34:59');
INSERT INTO [dbo].[FastMarket_IntervalGroup](IntervalGroupId, hdp1, Interval) VALUES(2, 31, '31:00-35:59');
INSERT INTO [dbo].[FastMarket_IntervalGroup](IntervalGroupId, hdp1, Interval) VALUES(2, 32, '32:00-36:59');
INSERT INTO [dbo].[FastMarket_IntervalGroup](IntervalGroupId, hdp1, Interval) VALUES(2, 33, '33:00-37:59');
INSERT INTO [dbo].[FastMarket_IntervalGroup](IntervalGroupId, hdp1, Interval) VALUES(2, 34, '34:00-38:59');
INSERT INTO [dbo].[FastMarket_IntervalGroup](IntervalGroupId, hdp1, Interval) VALUES(2, 35, '35:00-39:59');
INSERT INTO [dbo].[FastMarket_IntervalGroup](IntervalGroupId, hdp1, Interval) VALUES(2, 36, '36:00-40:59');
INSERT INTO [dbo].[FastMarket_IntervalGroup](IntervalGroupId, hdp1, Interval) VALUES(2, 37, '37:00-41:59');
INSERT INTO [dbo].[FastMarket_IntervalGroup](IntervalGroupId, hdp1, Interval) VALUES(2, 38, '38:00-42:59');
INSERT INTO [dbo].[FastMarket_IntervalGroup](IntervalGroupId, hdp1, Interval) VALUES(2, 39, '39:00-43:59');
INSERT INTO [dbo].[FastMarket_IntervalGroup](IntervalGroupId, hdp1, Interval) VALUES(2, 40, '40:00-44:59');
INSERT INTO [dbo].[FastMarket_IntervalGroup](IntervalGroupId, hdp1, Interval) VALUES(2, 41, '41:00-45:59');
INSERT INTO [dbo].[FastMarket_IntervalGroup](IntervalGroupId, hdp1, Interval) VALUES(2, 42, '42:00-46:59');
INSERT INTO [dbo].[FastMarket_IntervalGroup](IntervalGroupId, hdp1, Interval) VALUES(2, 43, '43:00-47:59');
INSERT INTO [dbo].[FastMarket_IntervalGroup](IntervalGroupId, hdp1, Interval) VALUES(2, 44, '44:00-48:59');
INSERT INTO [dbo].[FastMarket_IntervalGroup](IntervalGroupId, hdp1, Interval) VALUES(2, 45, '45:00-49:59');
INSERT INTO [dbo].[FastMarket_IntervalGroup](IntervalGroupId, hdp1, Interval) VALUES(2, 46, '46:00-50:59');
INSERT INTO [dbo].[FastMarket_IntervalGroup](IntervalGroupId, hdp1, Interval) VALUES(2, 47, '47:00-51:59');
INSERT INTO [dbo].[FastMarket_IntervalGroup](IntervalGroupId, hdp1, Interval) VALUES(2, 48, '48:00-52:59');
INSERT INTO [dbo].[FastMarket_IntervalGroup](IntervalGroupId, hdp1, Interval) VALUES(2, 49, '49:00-53:59');
INSERT INTO [dbo].[FastMarket_IntervalGroup](IntervalGroupId, hdp1, Interval) VALUES(2, 50, '50:00-54:59');
INSERT INTO [dbo].[FastMarket_IntervalGroup](IntervalGroupId, hdp1, Interval) VALUES(2, 51, '51:00-55:59');
INSERT INTO [dbo].[FastMarket_IntervalGroup](IntervalGroupId, hdp1, Interval) VALUES(2, 52, '52:00-56:59');
INSERT INTO [dbo].[FastMarket_IntervalGroup](IntervalGroupId, hdp1, Interval) VALUES(2, 53, '53:00-57:59');
INSERT INTO [dbo].[FastMarket_IntervalGroup](IntervalGroupId, hdp1, Interval) VALUES(2, 54, '54:00-58:59');
INSERT INTO [dbo].[FastMarket_IntervalGroup](IntervalGroupId, hdp1, Interval) VALUES(2, 55, '55:00-59:59');
INSERT INTO [dbo].[FastMarket_IntervalGroup](IntervalGroupId, hdp1, Interval) VALUES(2, 56, '56:00-60:59');
INSERT INTO [dbo].[FastMarket_IntervalGroup](IntervalGroupId, hdp1, Interval) VALUES(2, 57, '57:00-61:59');
INSERT INTO [dbo].[FastMarket_IntervalGroup](IntervalGroupId, hdp1, Interval) VALUES(2, 58, '58:00-62:59');
INSERT INTO [dbo].[FastMarket_IntervalGroup](IntervalGroupId, hdp1, Interval) VALUES(2, 59, '59:00-63:59');
INSERT INTO [dbo].[FastMarket_IntervalGroup](IntervalGroupId, hdp1, Interval) VALUES(2, 60, '60:00-64:59');
INSERT INTO [dbo].[FastMarket_IntervalGroup](IntervalGroupId, hdp1, Interval) VALUES(2, 61, '61:00-65:59');
INSERT INTO [dbo].[FastMarket_IntervalGroup](IntervalGroupId, hdp1, Interval) VALUES(2, 62, '62:00-66:59');
INSERT INTO [dbo].[FastMarket_IntervalGroup](IntervalGroupId, hdp1, Interval) VALUES(2, 63, '63:00-67:59');
INSERT INTO [dbo].[FastMarket_IntervalGroup](IntervalGroupId, hdp1, Interval) VALUES(2, 64, '64:00-68:59');
INSERT INTO [dbo].[FastMarket_IntervalGroup](IntervalGroupId, hdp1, Interval) VALUES(2, 65, '65:00-69:59');
INSERT INTO [dbo].[FastMarket_IntervalGroup](IntervalGroupId, hdp1, Interval) VALUES(2, 66, '66:00-70:59');
INSERT INTO [dbo].[FastMarket_IntervalGroup](IntervalGroupId, hdp1, Interval) VALUES(2, 67, '67:00-71:59');
INSERT INTO [dbo].[FastMarket_IntervalGroup](IntervalGroupId, hdp1, Interval) VALUES(2, 68, '68:00-72:59');
INSERT INTO [dbo].[FastMarket_IntervalGroup](IntervalGroupId, hdp1, Interval) VALUES(2, 69, '69:00-73:59');
INSERT INTO [dbo].[FastMarket_IntervalGroup](IntervalGroupId, hdp1, Interval) VALUES(2, 70, '70:00-74:59');
INSERT INTO [dbo].[FastMarket_IntervalGroup](IntervalGroupId, hdp1, Interval) VALUES(2, 71, '71:00-75:59');
INSERT INTO [dbo].[FastMarket_IntervalGroup](IntervalGroupId, hdp1, Interval) VALUES(2, 72, '72:00-76:59');
INSERT INTO [dbo].[FastMarket_IntervalGroup](IntervalGroupId, hdp1, Interval) VALUES(2, 73, '73:00-77:59');
INSERT INTO [dbo].[FastMarket_IntervalGroup](IntervalGroupId, hdp1, Interval) VALUES(2, 74, '74:00-78:59');
INSERT INTO [dbo].[FastMarket_IntervalGroup](IntervalGroupId, hdp1, Interval) VALUES(2, 75, '75:00-79:59');
INSERT INTO [dbo].[FastMarket_IntervalGroup](IntervalGroupId, hdp1, Interval) VALUES(2, 76, '76:00-80:59');
INSERT INTO [dbo].[FastMarket_IntervalGroup](IntervalGroupId, hdp1, Interval) VALUES(2, 77, '77:00-81:59');
INSERT INTO [dbo].[FastMarket_IntervalGroup](IntervalGroupId, hdp1, Interval) VALUES(2, 78, '78:00-82:59');
INSERT INTO [dbo].[FastMarket_IntervalGroup](IntervalGroupId, hdp1, Interval) VALUES(2, 79, '79:00-83:59');
INSERT INTO [dbo].[FastMarket_IntervalGroup](IntervalGroupId, hdp1, Interval) VALUES(2, 80, '80:00-84:59');
INSERT INTO [dbo].[FastMarket_IntervalGroup](IntervalGroupId, hdp1, Interval) VALUES(2, 81, '81:00-85:59');
INSERT INTO [dbo].[FastMarket_IntervalGroup](IntervalGroupId, hdp1, Interval) VALUES(2, 82, '82:00-86:59');
INSERT INTO [dbo].[FastMarket_IntervalGroup](IntervalGroupId, hdp1, Interval) VALUES(2, 83, '83:00-87:59');
INSERT INTO [dbo].[FastMarket_IntervalGroup](IntervalGroupId, hdp1, Interval) VALUES(2, 84, '84:00-88:59');
INSERT INTO [dbo].[FastMarket_IntervalGroup](IntervalGroupId, hdp1, Interval) VALUES(2, 85, '85:00-89:59');

GO

/*<info serverAlias="DBTGRS-bodb_TGRS" executers="bodbTGRSNet" isFunction="0" isNested="0"></info>*/
