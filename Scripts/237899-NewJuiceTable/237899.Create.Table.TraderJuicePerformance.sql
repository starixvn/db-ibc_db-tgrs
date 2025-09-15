use bodb_tgrs;
GO

ALTER DATABASE bodb_tgrs ADD FILEGROUP TraderJuicePerformance_Table;

ALTER DATABASE bodb_tgrs ADD FILE (
    NAME = TraderJuicePerformance_Table, 
    FILENAME = '/mnt/DiskG/bodb_tgrs/TraderJuicePerformance_Table.ndf', SIZE = 5MB, MAXSIZE = UNLIMITED, FILEGROWTH = 32MB) 
TO FILEGROUP TraderJuicePerformance_Table;

DROP TABLE IF EXISTS dbo.TraderJuicePerformance;

CREATE TABLE dbo.TraderJuicePerformance (
    EventDate DATE,
    MatchId INT,
    BetType SMALLINT,
    TraderId INT,
    Is8RM BIT,
    Juice MONEY,
    StakeMYR MONEY,
    StakeMYRJuice MONEY,
    Juice_AR MONEY,
    StakeMYR_AR MONEY,
    StakeMYRJuice_AR MONEY
) ON TraderJuicePerformance_Table;

CREATE UNIQUE CLUSTERED INDEX CLUSTERED_TraderJuicePerformance_Table 
ON dbo.TraderJuicePerformance (EventDate, MatchId, BetType, TraderId)
ON TraderJuicePerformance_Table;

/*<info serverAlias="DBTGRS-bodb_TGRS" executers="bodbTGRSNet" isFunction="0" isNested="0"></info>*/
