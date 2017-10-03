/*DROP TABLE	#PHAOI_Bettypes;
IF	OBJECT_ID('tempdb..#PHAOI_Bettypese') IS NOT NULL
BEGIN;
	DROP TABLE	#PHAOI_Bettypes;
END;

CREATE TABLE #PHAOI_Bettypes (
	BettypeId	INT
);

DECLARE @PHAOI_BettypesString VARCHAR(500) = '2, 4, 6, 12, 13, 16, 22, 24, 25, 26, 27, 28, 30, 121, 122, 123, 126, 129, 143, 144, 151, 159, 161, 162, 171, 191, 401, 402, 403, 404, 405, 406, 407, 408, 409, 410, 411, 412, 413, 414, 417, 418, 448, 449, 450, 451, 452, 458, 459, 461, 461, 463, 464';

INSERT INTO #PHAOI_Bettypes(BettypeId)
select val
from dbo.[SPU_StrSplit](@PHAOI_BettypesString, ', ')

SELECT 'VALUES(' + CONVERT(VARCHAR(3),ph.BettypeId) 
		+ ',$' + CONVERT(VARCHAR(100),b.typenamee)
		+ '$,999,0'
		+ ',' + CONVERT(VARCHAR(3),ph.BettypeId)
		+ ',1,37,0)'
	, b.typenamee
FROM #PHAOI_Bettypes ph
	INNER JOIN bodb02.dbo.bettype b WITH(NOLOCK) ON ph.BettypeId = b.typeid
*/
	-----------------------------------
--INSERT INTO [bodb_TGRS].[dbo].[BetType](BetType, TypeName, OrderId, IsDefault, MainDBBetType, OperatorType, AssignmentBetType, IsUsedForJuice)
--VALUES(2,'Odd/Even',999,0,2,1,37,0)
INSERT INTO [bodb_TGRS].[dbo].[BetType](BetType, TypeName, OrderId, IsDefault, MainDBBetType, OperatorType, AssignmentBetType, IsUsedForJuice)
VALUES(4,'Correct Score',999,0,4,1,37,0)
INSERT INTO [bodb_TGRS].[dbo].[BetType](BetType, TypeName, OrderId, IsDefault, MainDBBetType, OperatorType, AssignmentBetType, IsUsedForJuice)
VALUES(6,'Total Goal',999,0,6,1,37,0)
--INSERT INTO [bodb_TGRS].[dbo].[BetType](BetType, TypeName, OrderId, IsDefault, MainDBBetType, OperatorType, AssignmentBetType, IsUsedForJuice)
--VALUES(12,'1H Odd/Even',999,0,12,1,37,0)
INSERT INTO [bodb_TGRS].[dbo].[BetType](BetType, TypeName, OrderId, IsDefault, MainDBBetType, OperatorType, AssignmentBetType, IsUsedForJuice)
VALUES(13,'Clean Sheet',999,0,13,1,37,0)
INSERT INTO [bodb_TGRS].[dbo].[BetType](BetType, TypeName, OrderId, IsDefault, MainDBBetType, OperatorType, AssignmentBetType, IsUsedForJuice)
VALUES(16,'HT/FT',999,0,16,1,37,0)
INSERT INTO [bodb_TGRS].[dbo].[BetType](BetType, TypeName, OrderId, IsDefault, MainDBBetType, OperatorType, AssignmentBetType, IsUsedForJuice)
VALUES(22,'Next Goal',999,0,22,1,37,0)
INSERT INTO [bodb_TGRS].[dbo].[BetType](BetType, TypeName, OrderId, IsDefault, MainDBBetType, OperatorType, AssignmentBetType, IsUsedForJuice)
VALUES(24,'Double Chance',999,0,24,1,37,0)
INSERT INTO [bodb_TGRS].[dbo].[BetType](BetType, TypeName, OrderId, IsDefault, MainDBBetType, OperatorType, AssignmentBetType, IsUsedForJuice)
VALUES(25,'Draw No Bet',999,0,25,1,37,0)
INSERT INTO [bodb_TGRS].[dbo].[BetType](BetType, TypeName, OrderId, IsDefault, MainDBBetType, OperatorType, AssignmentBetType, IsUsedForJuice)
VALUES(26,'Both/One/Neither Team To Score',999,0,26,1,37,0)
INSERT INTO [bodb_TGRS].[dbo].[BetType](BetType, TypeName, OrderId, IsDefault, MainDBBetType, OperatorType, AssignmentBetType, IsUsedForJuice)
VALUES(27,'To Win To Nil',999,0,27,1,37,0)
INSERT INTO [bodb_TGRS].[dbo].[BetType](BetType, TypeName, OrderId, IsDefault, MainDBBetType, OperatorType, AssignmentBetType, IsUsedForJuice)
VALUES(28,'3-Way Handicap',999,0,28,1,37,0)
INSERT INTO [bodb_TGRS].[dbo].[BetType](BetType, TypeName, OrderId, IsDefault, MainDBBetType, OperatorType, AssignmentBetType, IsUsedForJuice)
VALUES(30,'1H Correct Score',999,0,30,1,37,0)
INSERT INTO [bodb_TGRS].[dbo].[BetType](BetType, TypeName, OrderId, IsDefault, MainDBBetType, OperatorType, AssignmentBetType, IsUsedForJuice)
VALUES(121,'Home No Bet',999,0,121,1,37,0)
INSERT INTO [bodb_TGRS].[dbo].[BetType](BetType, TypeName, OrderId, IsDefault, MainDBBetType, OperatorType, AssignmentBetType, IsUsedForJuice)
VALUES(122,'Away No Bet',999,0,122,1,37,0)
INSERT INTO [bodb_TGRS].[dbo].[BetType](BetType, TypeName, OrderId, IsDefault, MainDBBetType, OperatorType, AssignmentBetType, IsUsedForJuice)
VALUES(123,'Draw/No Draw',999,0,123,1,37,0)
INSERT INTO [bodb_TGRS].[dbo].[BetType](BetType, TypeName, OrderId, IsDefault, MainDBBetType, OperatorType, AssignmentBetType, IsUsedForJuice)
VALUES(126,'1H Total Goal',999,0,126,1,37,0)
INSERT INTO [bodb_TGRS].[dbo].[BetType](BetType, TypeName, OrderId, IsDefault, MainDBBetType, OperatorType, AssignmentBetType, IsUsedForJuice)
VALUES(129,'Exact 1H Goal',999,0,129,1,37,0)
INSERT INTO [bodb_TGRS].[dbo].[BetType](BetType, TypeName, OrderId, IsDefault, MainDBBetType, OperatorType, AssignmentBetType, IsUsedForJuice)
VALUES(143,'1H Result/Total Goals',999,0,143,1,37,0)
INSERT INTO [bodb_TGRS].[dbo].[BetType](BetType, TypeName, OrderId, IsDefault, MainDBBetType, OperatorType, AssignmentBetType, IsUsedForJuice)
VALUES(144,'Result/Total Goals',999,0,144,1,37,0)
INSERT INTO [bodb_TGRS].[dbo].[BetType](BetType, TypeName, OrderId, IsDefault, MainDBBetType, OperatorType, AssignmentBetType, IsUsedForJuice)
VALUES(151,'1H Double Chance',999,0,151,1,37,0)
INSERT INTO [bodb_TGRS].[dbo].[BetType](BetType, TypeName, OrderId, IsDefault, MainDBBetType, OperatorType, AssignmentBetType, IsUsedForJuice)
VALUES(159,'Exact Total Goals',999,0,159,1,37,0)
INSERT INTO [bodb_TGRS].[dbo].[BetType](BetType, TypeName, OrderId, IsDefault, MainDBBetType, OperatorType, AssignmentBetType, IsUsedForJuice)
VALUES(161,'Exact Home Team Goals',999,0,161,1,37,0)
INSERT INTO [bodb_TGRS].[dbo].[BetType](BetType, TypeName, OrderId, IsDefault, MainDBBetType, OperatorType, AssignmentBetType, IsUsedForJuice)
VALUES(162,'Exact Away Team Goals',999,0,162,1,37,0)
INSERT INTO [bodb_TGRS].[dbo].[BetType](BetType, TypeName, OrderId, IsDefault, MainDBBetType, OperatorType, AssignmentBetType, IsUsedForJuice)
VALUES(171,'Winning Margin',999,0,171,1,37,0)
INSERT INTO [bodb_TGRS].[dbo].[BetType](BetType, TypeName, OrderId, IsDefault, MainDBBetType, OperatorType, AssignmentBetType, IsUsedForJuice)
VALUES(191,'1H Draw No Bet',999,0,191,1,37,0)
--INSERT INTO [bodb_TGRS].[dbo].[BetType](BetType, TypeName, OrderId, IsDefault, MainDBBetType, OperatorType, AssignmentBetType, IsUsedForJuice)
--VALUES(401,'Home Team Over/Under',999,0,401,1,37,0)
--INSERT INTO [bodb_TGRS].[dbo].[BetType](BetType, TypeName, OrderId, IsDefault, MainDBBetType, OperatorType, AssignmentBetType, IsUsedForJuice)
--VALUES(402,'Away Team Over/Under',999,0,402,1,37,0)
--INSERT INTO [bodb_TGRS].[dbo].[BetType](BetType, TypeName, OrderId, IsDefault, MainDBBetType, OperatorType, AssignmentBetType, IsUsedForJuice)
--VALUES(403,'1H Home Team Over/Under',999,0,403,1,37,0)
--INSERT INTO [bodb_TGRS].[dbo].[BetType](BetType, TypeName, OrderId, IsDefault, MainDBBetType, OperatorType, AssignmentBetType, IsUsedForJuice)
--VALUES(404,'1H Away Team Over/Under',999,0,404,1,37,0)
INSERT INTO [bodb_TGRS].[dbo].[BetType](BetType, TypeName, OrderId, IsDefault, MainDBBetType, OperatorType, AssignmentBetType, IsUsedForJuice)
VALUES(405,'2H Correct Score',999,0,405,1,37,0)
INSERT INTO [bodb_TGRS].[dbo].[BetType](BetType, TypeName, OrderId, IsDefault, MainDBBetType, OperatorType, AssignmentBetType, IsUsedForJuice)
VALUES(406,'Exact Total Goals (own)',999,0,406,1,37,0)
INSERT INTO [bodb_TGRS].[dbo].[BetType](BetType, TypeName, OrderId, IsDefault, MainDBBetType, OperatorType, AssignmentBetType, IsUsedForJuice)
VALUES(407,'Exact Home Team Goals (own)',999,0,407,1,37,0)
INSERT INTO [bodb_TGRS].[dbo].[BetType](BetType, TypeName, OrderId, IsDefault, MainDBBetType, OperatorType, AssignmentBetType, IsUsedForJuice)
VALUES(408,'Winning Margin (own)',999,0,408,1,37,0)
INSERT INTO [bodb_TGRS].[dbo].[BetType](BetType, TypeName, OrderId, IsDefault, MainDBBetType, OperatorType, AssignmentBetType, IsUsedForJuice)
VALUES(409,'Exact Away Team Goals (own)',999,0,409,1,37,0)
INSERT INTO [bodb_TGRS].[dbo].[BetType](BetType, TypeName, OrderId, IsDefault, MainDBBetType, OperatorType, AssignmentBetType, IsUsedForJuice)
VALUES(410,'1H Double Chance (own)',999,0,410,1,37,0)
INSERT INTO [bodb_TGRS].[dbo].[BetType](BetType, TypeName, OrderId, IsDefault, MainDBBetType, OperatorType, AssignmentBetType, IsUsedForJuice)
VALUES(411,'1H Draw No Bet (own)',999,0,411,1,37,0)
INSERT INTO [bodb_TGRS].[dbo].[BetType](BetType, TypeName, OrderId, IsDefault, MainDBBetType, OperatorType, AssignmentBetType, IsUsedForJuice)
VALUES(412,'Exact 1H Goals',999,0,412,1,37,0)
INSERT INTO [bodb_TGRS].[dbo].[BetType](BetType, TypeName, OrderId, IsDefault, MainDBBetType, OperatorType, AssignmentBetType, IsUsedForJuice)
VALUES(413,'Correct Score (AOS)',999,0,413,1,37,0)
INSERT INTO [bodb_TGRS].[dbo].[BetType](BetType, TypeName, OrderId, IsDefault, MainDBBetType, OperatorType, AssignmentBetType, IsUsedForJuice)
VALUES(414,'1H Correct Score (AOS)',999,0,414,1,37,0)
INSERT INTO [bodb_TGRS].[dbo].[BetType](BetType, TypeName, OrderId, IsDefault, MainDBBetType, OperatorType, AssignmentBetType, IsUsedForJuice)
VALUES(417,'Both Teams To Score/Result',999,0,417,1,37,0)
INSERT INTO [bodb_TGRS].[dbo].[BetType](BetType, TypeName, OrderId, IsDefault, MainDBBetType, OperatorType, AssignmentBetType, IsUsedForJuice)
VALUES(418,'Both Teams To Score/Total Goal',999,0,418,1,37,0)
INSERT INTO [bodb_TGRS].[dbo].[BetType](BetType, TypeName, OrderId, IsDefault, MainDBBetType, OperatorType, AssignmentBetType, IsUsedForJuice)
VALUES(461,'Home Team Over/Under (dec)',999,0,461,1,37,0)
INSERT INTO [bodb_TGRS].[dbo].[BetType](BetType, TypeName, OrderId, IsDefault, MainDBBetType, OperatorType, AssignmentBetType, IsUsedForJuice)
VALUES(461,'Home Team Over/Under (dec)',999,0,461,1,37,0)
INSERT INTO [bodb_TGRS].[dbo].[BetType](BetType, TypeName, OrderId, IsDefault, MainDBBetType, OperatorType, AssignmentBetType, IsUsedForJuice)
VALUES(463,'1H Home Team Over/Under (dec)',999,0,463,1,37,0)
INSERT INTO [bodb_TGRS].[dbo].[BetType](BetType, TypeName, OrderId, IsDefault, MainDBBetType, OperatorType, AssignmentBetType, IsUsedForJuice)
VALUES(464,'1H Away Team Over/Under (dec)',999,0,464,1,37,0)

------------------------------------
UPDATE [bodb_TGRS].[dbo].[BetType]
SET OrderId = 999, AssignmentBetType = 37, OperatorType = 1
WHERE BetType IN (2, 4, 6, 12, 13, 16, 22, 24, 25, 26, 27, 28, 30, 121, 122, 123, 126, 129, 143, 144, 151, 159, 161, 162, 171, 191, 401, 402, 403, 404, 405, 406, 407, 408, 409, 410, 411, 412, 413, 414, 417, 418, 448, 449, 450, 451, 452, 458, 459, 461, 461, 463, 464)
	AND OperatorType <> 1

