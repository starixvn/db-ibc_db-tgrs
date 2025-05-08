-- Script to create a dummy basketball match and generate transactions
DECLARE @TargetDate DATETIME = '2025-02-01';
DECLARE @SportType INT = 2;

DECLARE @BaseRefNo BIGINT = 2025040900001;
DECLARE @BaseTransId BIGINT = (SELECT MAX(TransId) FROM bodb02.dbo.bettrans);

-- First create a new basketball match with eventdate exactly matching our target date
DECLARE @NewMatchId INT;
DECLARE @RandomLeagueId INT;
DECLARE @RandomHomeId INT;
DECLARE @RandomAwayId INT;

-- Get a random Basketball league ID (sporttype=2) from TESTDB061
SELECT TOP 1 @RandomLeagueId = leagueid
FROM bodb02.dbo.league
WHERE sporttype = @SportType
ORDER BY NEWID();

IF @RandomLeagueId IS NULL
BEGIN
    PRINT 'No active basketball leagues found';
    RETURN;
END

SELECT TOP 2 @RandomHomeId = CASE WHEN T.RowNum = 1 THEN T.teamid ELSE @RandomHomeId END,
             @RandomAwayId = CASE WHEN T.RowNum = 2 THEN T.teamid ELSE @RandomAwayId END
FROM (
    SELECT teamid, ROW_NUMBER() OVER (ORDER BY NEWID()) AS RowNum
    FROM bodb02.dbo.team
    WHERE SportType = 2
) AS T
WHERE T.RowNum <= 2;

IF @RandomHomeId IS NULL OR @RandomAwayId IS NULL
BEGIN
    PRINT 'No active basketball teams found';
    RETURN;
END

-- Create new match record with sporttype=2 (basketball)
INSERT INTO bodb02.dbo.match (
    leagueid, homeid, awayid, eventdate, eventstatus, betstatus, 
    creator, matchcode, sporttype, homeid2, awayid2, DisplayMode, 
    LeaguePatternID, HomeDisplayPatternID, AwayDisplayPatternID, IsNeutral
)
VALUES (
    @RandomLeagueId, -- leagueid (randomly selected basketball league)
    @RandomHomeId, -- homeid (randomly selected basketball team)
    @RandomAwayId, -- awayid (randomly selected different basketball team)
    @TargetDate, -- eventdate (IMPORTANT: matches our target date)
    'completed', -- eventstatus
    '24-27,25-34,35-38,41-15', -- betstatus
    2929, -- creator
    'BASKET_' + CONVERT(VARCHAR, @TargetDate, 112), -- matchcode
    2, -- sporttype (basketball)
    0, -- homeid2
    0, -- awayid2
    0, -- DisplayMode
    0, -- LeaguePatternID
    0, -- HomeDisplayPatternID
    0, -- AwayDisplayPatternID
    0  -- IsNeutral
);

-- Get the newly created match ID
SET @NewMatchId = SCOPE_IDENTITY();

-- Declare a table variable to store customer IDs from TESTDB061
DECLARE @CustomerList TABLE (
    RowID INT IDENTITY(1,1) PRIMARY KEY,
    CustId INT
);

-- Populate the table variable with up to 50 distinct random customer IDs
INSERT INTO @CustomerList (CustId)
SELECT TOP 50 custid
FROM bodb02.dbo.vw_customer
ORDER BY NEWID();

-- Get the count of fetched customers
DECLARE @CustomerCount INT;
SELECT @CustomerCount = COUNT(*) FROM @CustomerList;

-- Check if any customers were fetched
IF @CustomerCount = 0
BEGIN
    PRINT 'No customers found in TESTDB061.bodb02.dbo.vw_customer. Cannot generate transactions.';
    RETURN;
END

-- Enable IDENTITY_INSERT to allow explicit TransId values
--SET IDENTITY_INSERT bodb02.dbo.bettrans ON;

-- Generate 50 transaction tickets for our new basketball match
;WITH nums AS (
    SELECT TOP 50 ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS n
    FROM sys.objects a CROSS JOIN sys.objects b
)
INSERT INTO bodb02.dbo.bettrans (
    TransId, custid, transdate, oddsid, hdp1, hdp2, odds, stake, status, winlost, awinlost, 
    mwinlost, playercomm, comm, acomm, apositiontaking, mpositiontaking, tpositiontaking, 
    playerdiscount, discount, adiscount, livehomescore, liveawayscore, liveindicator, betteam, 
    creator, refno, comstatus, winlostdate, betfrom, betcheck, checktime, oddsspread, actualrate, 
    matchid, recommend, mrecommend, ruben, betid, statuswinlost, modds, bettype, betdaqid, 
    actual_stake, currency, transdesc, sdiscount, scomm, spositiontaking, swinlost, srecommend, 
    Username, CurrencyName, virtualrate, oddstype, statusID, currency2, balance, SecAcceptFlag, 
    transid2, RecommDate, ExtraInfo, WalletType, BonusID, RefCode, SettlementTime, epositiontaking, 
    ReasonID, sort, BetSiteID, SiteDBGroupID
)
SELECT 
    -- Identity column
    @BaseTransId + n AS TransId,
    
    -- Basic transaction info
    (SELECT CL.CustId FROM @CustomerList CL WHERE CL.RowID = (n - 1) % @CustomerCount + 1) AS custid,
    @TargetDate AS transdate,
    600000000 + n AS oddsid,
    CASE WHEN n % 3 = 0 THEN 5.5 WHEN n % 3 = 1 THEN 7.5 ELSE 0 END AS hdp1,
    0 AS hdp2,
    CASE WHEN n % 2 = 0 THEN -0.91 ELSE 0.96 END AS odds,
    1000 + (n * 100) % 1000 AS stake,
    CASE WHEN n % 3 = 0 THEN 'WON' WHEN n % 3 = 1 THEN 'LOSE' ELSE 'HALF-WON' END AS status,
    CASE 
        WHEN n % 3 = 0 THEN (1000 + (n * 100) % 1000) * 0.91 -- WON
        WHEN n % 3 = 1 THEN 0 -- LOSE
        ELSE (1000 + (n * 100) % 1000) * 0.91 * 0.5 -- HALF-WON
    END AS winlost,
    CASE WHEN n % 3 = 0 THEN (1000 + (n * 100) % 1000) * -0.4 ELSE (1000 + (n * 100) % 1000) * 0.364 END AS awinlost,
    CASE WHEN n % 3 = 0 THEN (1000 + (n * 100) % 1000) * -0.3 ELSE (1000 + (n * 100) % 1000) * 0.273 END AS mwinlost,
    20 AS playercomm, 15 AS comm, 9 AS acomm,
    0.4 AS apositiontaking, 0.3 AS mpositiontaking, 0.9 AS tpositiontaking,
    0.02 AS playerdiscount, 0.025 AS discount, 0.03 AS adiscount,
    0 AS livehomescore, 0 AS liveawayscore, 0 AS liveindicator,
    -- betteam: assign based on bettype mapping variety
    CASE 
        -- BetType 1, 7, 20, 21: 'h' (Home) or 'a' (Away)
        WHEN (CASE 
                WHEN n % 13 = 0 THEN 1
                WHEN n % 13 = 3 THEN 7
                WHEN n % 13 = 6 THEN 20
                WHEN n % 13 = 7 THEN 21
                ELSE NULL END) IS NOT NULL 
            THEN CASE WHEN (n + ABS(CHECKSUM(NEWID()))) % 2 = 0 THEN 'h' ELSE 'a' END
        -- BetType 2, 12: 'h' (Odd) or 'a' (Even)
        WHEN (CASE 
                WHEN n % 13 = 1 THEN 2
                WHEN n % 13 = 5 THEN 12
                ELSE NULL END) IS NOT NULL 
            THEN CASE WHEN (n + ABS(CHECKSUM(NEWID()))) % 2 = 0 THEN 'h' ELSE 'a' END
        -- BetType 3, 8: 'h' (Over) or 'a' (Under)
        WHEN (CASE 
                WHEN n % 13 = 2 THEN 3
                WHEN n % 13 = 4 THEN 8
                ELSE NULL END) IS NOT NULL 
            THEN CASE WHEN (n + ABS(CHECKSUM(NEWID()))) % 2 = 0 THEN 'h' ELSE 'a' END
        -- BetType 401, 402, 403, 404, 461, 462, 463, 464: 'o' (Over) or 'u' (Under)
        WHEN (CASE 
                WHEN n % 13 = 9 THEN 401
                WHEN n % 13 = 10 THEN 402
                WHEN n % 13 = 11 THEN 403
                WHEN n % 13 = 12 THEN 404
                ELSE NULL END) IS NOT NULL 
            THEN CASE WHEN (n + ABS(CHECKSUM(NEWID()))) % 2 = 0 THEN 'o' ELSE 'u' END
        -- Default fallback
        ELSE CASE WHEN (n + ABS(CHECKSUM(NEWID()))) % 2 = 0 THEN 'h' ELSE 'a' END
    END AS betteam,
    8 AS creator, @BaseRefNo + n AS refno, 0 AS comstatus,
    @TargetDate AS winlostdate, -- IMPORTANT: Matches eventdate
    'i' AS betfrom, 0 AS betcheck, NULL AS checktime,
    0 AS oddsspread, 0.2 AS actualrate,
    @NewMatchId AS matchid, -- Use our new match ID
    10063439 AS recommend, 10063438 AS mrecommend, 1 AS ruben, 0 AS betid,
    CASE WHEN n % 3 = 0 THEN 2 WHEN n % 3 = 1 THEN 4 ELSE 1 END AS statuswinlost,
    CASE WHEN n % 2 = 0 THEN -1.0 ELSE 1.0 END AS modds,
    
    -- Bettype - Use a broader set of real OSBettype IDs for basketball
    CASE 
        WHEN n % 40 = 0 THEN 1    -- HDP
        WHEN n % 40 = 1 THEN 2    -- O/E
        WHEN n % 40 = 2 THEN 3    -- O/U
        WHEN n % 40 = 3 THEN 5    -- 1x2
        WHEN n % 40 = 4 THEN 7    -- 1st HDP
        WHEN n % 40 = 5 THEN 8    -- 1st O/U
        WHEN n % 40 = 6 THEN 12   -- 1st O/E
        WHEN n % 40 = 7 THEN 15   -- 1st 1x2
        WHEN n % 40 = 8 THEN 20   -- Money Line
        WHEN n % 40 = 9 THEN 21   -- 1H Moneyline
        WHEN n % 40 = 10 THEN 401 -- Home Team Over/Under
        WHEN n % 40 = 11 THEN 402 -- Away Team Over/Under
        WHEN n % 40 = 12 THEN 403 -- 1H Home Team Over/Under
        WHEN n % 40 = 13 THEN 404 -- 1H Away Team Over/Under
        WHEN n % 40 = 14 THEN 602 -- Winning Margin 12 Way
        WHEN n % 40 = 15 THEN 603 -- Which Team To Score The Highest Quarter
        WHEN n % 40 = 16 THEN 604 -- Which Team To Score The First Basket
        WHEN n % 40 = 17 THEN 605 -- Which Team To Score The Last Basket
        WHEN n % 40 = 18 THEN 606 -- 1H Race To X Points
        WHEN n % 40 = 19 THEN 607 -- 2H Race To X Points
        WHEN n % 40 = 20 THEN 608 -- 1H Winning Margin 13 Way
        WHEN n % 40 = 21 THEN 609 -- Quarter X Handicap
        WHEN n % 40 = 22 THEN 610 -- Quarter X Over/Under
        WHEN n % 40 = 23 THEN 611 -- Quarter X Odd/Even
        WHEN n % 40 = 24 THEN 612 -- Quarter X Moneyline
        WHEN n % 40 = 25 THEN 613 -- Quarter X Race To Y Points
        WHEN n % 40 = 26 THEN 614 -- Quarter X Winning Margin 7 Way
        WHEN n % 40 = 27 THEN 615 -- Quarter X Home Team Over/Under
        WHEN n % 40 = 28 THEN 616 -- Quarter X Away Team Over/Under
        WHEN n % 40 = 29 THEN 617 -- Quarter X Which Team To Score The Last Basket
        WHEN n % 40 = 30 THEN 153 -- Game Handicap
        WHEN n % 40 = 31 THEN 154 -- Set X Winner
        WHEN n % 40 = 32 THEN 155 -- Set X Game Handicap
        WHEN n % 40 = 33 THEN 156 -- Set X Total Game Over/Under
        WHEN n % 40 = 34 THEN 218 -- Point Handicap
        WHEN n % 40 = 35 THEN 219 -- Set X Point Handicap
        WHEN n % 40 = 36 THEN 220 -- Set X Point Over/Under
        WHEN n % 40 = 37 THEN 458 -- Full Time Asian 1X2
        WHEN n % 40 = 38 THEN 459 -- Half Time Asian 1X2
        WHEN n % 40 = 39 THEN 501 -- Match Winner
        ELSE 610 -- fallback: Quarter X Over/Under
    END AS bettype,
    
    -1 AS betdaqid, (1000 + (n * 100) % 1000) AS actual_stake, 3 AS currency, NULL AS transdesc,
    0.04 AS sdiscount, 4.0 AS scomm, 0.2 AS spositiontaking,
    CASE 
        WHEN n % 3 = 0 THEN -200 -- WON
        WHEN n % 3 = 1 THEN 182 -- LOSE
        ELSE -100 -- HALF-WON
    END AS swinlost,
    10063437 AS srecommend, 'TestUser' + CAST(n AS VARCHAR) AS Username, 'UUS' AS CurrencyName,
    1 AS virtualrate, 4 AS oddstype,
    CASE WHEN n % 3 = 0 THEN 112 WHEN n % 3 = 1 THEN 113 ELSE 111 END AS statusID,
    NULL AS currency2, NULL AS balance, NULL AS SecAcceptFlag, NULL AS transid2,
    NULL AS RecommDate, NULL AS ExtraInfo, NULL AS WalletType, NULL AS BonusID, NULL AS RefCode,
    CASE 
        WHEN n % 3 = 0 THEN DATEADD(MINUTE, -( (ABS(CHECKSUM(NEWID())) % 60) + 1 ), GETDATE()) -- current time minus 1 to 60 minutes
        ELSE DATEADD(HOUR, -( (ABS(CHECKSUM(NEWID())) % 3) + 1 ), @TargetDate)
    END AS SettlementTime, 
    0 AS epositiontaking,
    NULL AS ReasonID, NULL AS sort, NULL AS BetSiteID, 1 AS SiteDBGroupID
FROM nums;

-- Turn off IDENTITY_INSERT when done
--SET IDENTITY_INSERT bodb02.dbo.bettrans OFF;

-- Execute the stored procedure to populate the data
EXEC bodb_tgrs.dbo.Task_StagingOSDataTGRS 
    @Debug = 1, 
    @GenerateFromDate = @TargetDate, 
    @GenerateToDate = @TargetDate;

-- Verify data was populated into the destination table
/*
SELECT TOP 50 *
FROM bodb_tgrs.dbo.OSDataTGRS_BetChoice
WHERE EventDate = '2025-04-13';

*/