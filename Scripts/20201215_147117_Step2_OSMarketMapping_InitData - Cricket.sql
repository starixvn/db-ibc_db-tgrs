/*
Creator: 20201215@John.Ngo
Task: [OS] Market Count - Init Data for OSMarketMapping - Cricket [Redmine ID: 147117]
Server:  DB06.bodb_TGRS_UAT & DB061.bodb_TGRS

Reviewer: Partrick
*/ 

--USE	bodb_TGRS;
--GO
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
SET NOCOUNT ON;

DECLARE @CurrentDate DATETIME = GETDATE();

-- Cricket
INSERT INTO [OSMarketMapping](SportId, LeagueNameMarket, BetTypeId, MarketId, CreatedBy, CreatedDate)
VALUES(27,'Batsman Runs',NULL,1,20902509, @CurrentDate)
	 ,(27,'Fall of Wicket',NULL,2,20902509, @CurrentDate)
	 ,(27,'Group Runs',NULL,3,20902509, @CurrentDate)
	 ,(27,'Highest Individual Score',NULL,4,20902509, @CurrentDate)
	 ,(27,'Highest Opening Partnership',NULL,5,20902509, @CurrentDate)
	 ,(27,'Highest Over Score',NULL,6,20902509, @CurrentDate)
	 ,(27,'Highest Score in Over 1',NULL,7,20902509, @CurrentDate)
 	 ,(27,'Innings Runs',NULL,8,20902509, @CurrentDate)
	 ,(27,'Match Extras',NULL,9,20902509, @CurrentDate)
	 ,(27,'Match Fours',NULL,10,20902509, @CurrentDate)
	 ,(27,'Match Sixes',NULL,11,20902509, @CurrentDate)
	 ,(27,'Match Wickets',NULL,12,20902509, @CurrentDate)
	 ,(27,'Method of Dismissal',NULL,13,20902509, @CurrentDate)
	 ,(27,'Player Runs',NULL,14,20902509, @CurrentDate)
	 ,(27,'Score after Ball',NULL,15,20902509, @CurrentDate)
	 ,(27,'Score at End of Over',NULL,16,20902509, @CurrentDate)
	 ,(27,'Super Over Winner',NULL,17,20902509, @CurrentDate)
	 ,(27,'Total Tournament Duck',NULL,18,20902509, @CurrentDate)
	 ,(27,'Total Tournament Run-outs',NULL,19,20902509, @CurrentDate)
	 ,(27,'Total Tournament Sixes',NULL,20,20902509, @CurrentDate)
	 ,(27,'Total Tournament Wickets',NULL,21,20902509, @CurrentDate)
	 ,(27,'Tournament Highest Individual Score',NULL,22,20902509, @CurrentDate)
	 ,(27,'Tournament Highest Innings Score',NULL,23,20902509, @CurrentDate)
	 ,(27,'Tournament Highest Opening Partnership',NULL,24,20902509, @CurrentDate)
	 ,(27,'Tournament Highest Over Score',NULL,25,20902509, @CurrentDate)
	 ,(27,'Tournament Highest Score at End of Over 1',NULL,26,20902509, @CurrentDate)
	 ,(27,'Win Toss',NULL,27,20902509, @CurrentDate)
	 ,(27,NULL,10,28,20902509, @CurrentDate)
	 ,(27,NULL,501,29,20902509, @CurrentDate)
	 ,(27,NULL,5,30,20902509, @CurrentDate)
	 ,(27,NULL,NULL,0,20902509, @CurrentDate)

-- Darts
UPDATE [dbo].[OSMarketMapping] WITH(ROWLOCK)
SET LeagueNameMarket = 'Which Player to Score the First 180?' WHERE SportId = 25 AND MarketId = 2;
UPDATE [dbo].[OSMarketMapping] WITH(ROWLOCK)
SET LeagueNameMarket = '(First Set Winner)' WHERE SportId = 25 AND MarketId = 3;
UPDATE [dbo].[OSMarketMapping] WITH(ROWLOCK)
SET LeagueNameMarket = 'Winner' WHERE SportId = 25 AND MarketId = 4;
UPDATE [dbo].[OSMarketMapping] WITH(ROWLOCK)
SET LeagueNameMarket = NULL, BetTypeId = 1 WHERE SportId = 25 AND MarketId = 5;

INSERT INTO [OSMarketMapping](SportId, LeagueNameMarket, BetTypeId, MarketId, CreatedBy, CreatedDate)
VALUES(25,NULL,20,5,20902509, @CurrentDate)

-- Sepak Takraw
UPDATE [dbo].[OSMarketMapping] WITH(ROWLOCK)
SET LeagueNameMarket = NULL, BetTypeId = 20 WHERE SportId = 48 AND MarketId = 1;

-- Table Tennis
UPDATE [dbo].[OSMarketMapping] WITH(ROWLOCK)
SET LeagueNameMarket = NULL, BetTypeId = 1 WHERE SportId = 18 AND MarketId = 1;

INSERT INTO [OSMarketMapping](SportId, LeagueNameMarket, BetTypeId, MarketId, CreatedBy, CreatedDate)
VALUES(18,NULL,20,1,20902509, @CurrentDate)

GO
/*<info serverAlias="DBTGRS-bodb_TGRS"></info>*/