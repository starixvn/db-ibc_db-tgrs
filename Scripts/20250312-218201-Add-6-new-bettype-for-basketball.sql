/*<info serverAlias="DBTGRS-bodb_TGRS" executers="wsv_tgrs" isFunction="0" isNested="0"></info>*/

use bodb_TGRS

-- https://nexdev.net/projects/sportsbook/wiki/202501_Basketball_New_Bet_Types_with_Decimal_Odds_Only
-- note: AssignmentBettype is not used anymore, it can be null

INSERT INTO bodb_TGRS.dbo.OSBettype (BettypeId, BettypeName, OrderId, IsDefault, MainDBBettype, OperatorType, AssignmentBettype, IsUsedForJuice, GroupBettypeId)
VALUES (651, 'Quarter X Home Team Over/Under (dec)', 615, 0, 651, 1, 29, 0, 2)

INSERT INTO bodb_TGRS.dbo.OSBettype (BettypeId, BettypeName, OrderId, IsDefault, MainDBBettype, OperatorType, AssignmentBettype, IsUsedForJuice, GroupBettypeId)
VALUES (652, 'Quarter X Away Team Over/Under (dec)', 616, 0, 652, 1, 30, 0, 2)

INSERT INTO bodb_TGRS.dbo.OSBettype (BettypeId, BettypeName, OrderId, IsDefault, MainDBBettype, OperatorType, AssignmentBettype, IsUsedForJuice, GroupBettypeId)
VALUES (461, 'Home Team Over/Under (dec)', 0, 0, 461, 1, 14, 0, 2)

INSERT INTO bodb_TGRS.dbo.OSBettype (BettypeId, BettypeName, OrderId, IsDefault, MainDBBettype, OperatorType, AssignmentBettype, IsUsedForJuice, GroupBettypeId)
VALUES (462, 'Away Team Over/Under (dec)', 0, 0, 462, 1, 15, 0, 2)

INSERT INTO bodb_TGRS.dbo.OSBettype (BettypeId, BettypeName, OrderId, IsDefault, MainDBBettype, OperatorType, AssignmentBettype, IsUsedForJuice, GroupBettypeId)
VALUES (463, '1H Home Team Over/Under (dec)', 0, 0, 463, 1, 16, 0, 2)

INSERT INTO bodb_TGRS.dbo.OSBettype (BettypeId, BettypeName, OrderId, IsDefault, MainDBBettype, OperatorType, AssignmentBettype, IsUsedForJuice, GroupBettypeId)
VALUES (464, '1H Away Team Over/Under (dec)', 0, 0, 464, 1, 17, 0, 2)


