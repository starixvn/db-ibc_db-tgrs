SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE [dbo].[TGRS_SB_gen_bet_transactions]
    @TargetTableChoice INT, -- 1 for _bk, 2 for _14, 3 for live
    @TargetDate DATETIME,
    @MatchIdToUse INT,
    @NumberOfTransactions INT = 50,
    @BetTypeToGenerate INT = NULL -- Specific BetType to generate, if NULL, use random bet type from SBM
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @ErrorMessage NVARCHAR(MAX) = NULL;

    BEGIN TRY
        PRINT 'Starting bet transaction generation for MatchID: ' + CAST(@MatchIdToUse AS VARCHAR) + '...';
        
        DECLARE @SportType INT
        IF @TargetTableChoice = 1
        BEGIN
            SELECT @SportType = SportType
            FROM bodb02.dbo.match
            WHERE matchid = @MatchIdToUse;
        END
        ELSE IF @TargetTableChoice = 2
        BEGIN
            SELECT @SportType = SportType
            FROM bodb02.dbo.match14
            WHERE matchid = @MatchIdToUse;
        END
        ELSE IF @TargetTableChoice = 3
        BEGIN
            SELECT @SportType = SportType
            FROM bodb02.dbo.match
            WHERE matchid = @MatchIdToUse;
        END

        IF @SportType IS NULL
        BEGIN
            SET @ErrorMessage = 'SportType not found for MatchID: ' + CAST(@MatchIdToUse AS VARCHAR) 
            + ' in ' 
            + CASE WHEN @TargetTableChoice = 1 THEN 'bodb02.dbo.match' 
                WHEN @TargetTableChoice = 2 THEN 'bodb02.dbo.match14' 
                WHEN @TargetTableChoice = 3 THEN 'bodb02.dbo.match' 
                ELSE 'unknown' 
            END;
            THROW 51000, @ErrorMessage, 1;
            RETURN;
        END
        
        -- Initialize variables
        DECLARE @BaseRefNo BIGINT;
        DECLARE @BaseTransId BIGINT; -- To be set dynamically based on target table
        
        -- Determine BaseTransId based on target bettrans table
        IF @TargetTableChoice = 1
        BEGIN
            SELECT @BaseTransId = ISNULL(MAX(TransId), 0), @BaseRefNo = ISNULL(MAX(RefNo), 0)
            FROM bodb_Archive.dbo.bettrans_bk WITH (NOLOCK);

            PRINT 'Targeting bodb_Archive.dbo.bettrans_bk for transactions. Max TransId found: ' + ISNULL(CAST(@BaseTransId AS VARCHAR), 'NULL') + '. New TransIds will start from ' + CAST(@BaseTransId + 1 AS VARCHAR) + '.';
        END
        ELSE IF @TargetTableChoice = 2
        BEGIN
            SELECT @BaseTransId = ISNULL(MAX(TransId), 0), @BaseRefNo = ISNULL(MAX(RefNo), 0)
            FROM bodb02.dbo.bettrans14 WITH (NOLOCK);

            PRINT 'Targeting bodb02.dbo.bettrans14 for transactions. Max TransId found: ' + ISNULL(CAST(@BaseTransId AS VARCHAR), 'NULL') + '. New TransIds will start from ' + CAST(@BaseTransId + 1 AS VARCHAR) + '.';
        END
        ELSE -- @TargetTableChoice = 3
        BEGIN
            SELECT @BaseTransId = ISNULL(MAX(TransId), 0), @BaseRefNo = ISNULL(MAX(RefNo), 0)
            FROM bodb02.dbo.bettrans WITH (NOLOCK);

            PRINT 'Targeting bodb02.dbo.bettrans for transactions. Max TransId found: ' + ISNULL(CAST(@BaseTransId AS VARCHAR), 'NULL') + '. New TransIds will start from ' + CAST(@BaseTransId + 1 AS VARCHAR) + '.';
        END;

        -- Declare a table variable to store customer IDs
        DECLARE @CustomerList TABLE (
            RowID INT IDENTITY(1, 1) PRIMARY KEY,
            CustId INT
        );

        INSERT INTO @CustomerList (CustId)
        SELECT TOP 50 custid
        FROM bodb02.dbo.vw_customer
        ORDER BY NEWID();

        DECLARE @CustomerCount INT;

        SELECT @CustomerCount = COUNT(*)
        FROM @CustomerList;

        IF @CustomerCount = 0
        BEGIN
            SET @ErrorMessage = 'No customers found in bodb02.dbo.vw_customer for Soccer script. Cannot generate transactions.';
            THROW 51000, @ErrorMessage, 1;
            RETURN;
        END;

        -- Prepare temporary table for bet transactions
        IF OBJECT_ID('tempdb..#MockBetTransData') IS NOT NULL
            DROP TABLE #MockBetTransData;

        CREATE TABLE #MockBetTransData (
            TransId BIGINT,
            custid INT,
            transdate DATETIME,
            oddsid BIGINT,
            hdp1 DECIMAL(18, 2),
            hdp2 DECIMAL(18, 2),
            odds DECIMAL(18, 2),
            stake DECIMAL(18, 2),
            status VARCHAR(10),
            winlost DECIMAL(18, 2),
            awinlost DECIMAL(18, 2),
            mwinlost DECIMAL(18, 2),
            playercomm DECIMAL(18, 2),
            comm DECIMAL(18, 2),
            acomm DECIMAL(18, 2),
            apositiontaking DECIMAL(18, 2),
            mpositiontaking DECIMAL(18, 2),
            tpositiontaking DECIMAL(18, 2),
            playerdiscount DECIMAL(18, 2),
            discount DECIMAL(18, 2),
            adiscount DECIMAL(18, 2),
            livehomescore INT,
            liveawayscore INT,
            liveindicator INT,
            creator INT,
            refno BIGINT,
            comstatus INT,
            winlostdate DATETIME,
            betfrom VARCHAR(1),
            betcheck INT,
            checktime DATETIME,
            oddsspread DECIMAL(18, 2),
            actualrate DECIMAL(18, 2),
            matchid INT,
            recommend BIGINT,
            mrecommend BIGINT,
            ruben INT,
            betid BIGINT,
            statuswinlost INT,
            modds DECIMAL(18, 2),
            bettype INT,
            betdaqid INT,
            actual_stake DECIMAL(18, 2),
            currency INT,
            transdesc VARCHAR(MAX),
            sdiscount DECIMAL(18, 2),
            scomm DECIMAL(18, 2),
            spositiontaking DECIMAL(18, 2),
            swinlost DECIMAL(18, 2),
            srecommend BIGINT,
            virtualrate DECIMAL(18, 2),
            oddstype INT,
            statusID INT,
            currency2 INT,
            balance DECIMAL(18, 2),
            SecAcceptFlag VARCHAR(1),
            transid2 BIGINT,
            ExtraInfo VARCHAR(MAX),
            WalletType INT,
            BonusID BIGINT,
            RefCode VARCHAR(50),
            SettlementTime DATETIME,
            epositiontaking DECIMAL(18, 2),
            ReasonID INT,
            sort INT,
            betteam VARCHAR(10)
            );

        -- Generate transaction tickets
        WITH
            -- Fetch distinct bet types from the specified table
            _DistinctBetTypes
            AS
            (
                SELECT
                    BetType,
                    1 AS _row_num_for_cycle, -- Only one row, so row number is 1
                    1 AS _total_distinct_types -- Only one type if specified
                FROM (SELECT @BetTypeToGenerate AS BetType) AS SpecifiedBetType
                WHERE @BetTypeToGenerate IS NOT NULL

                UNION ALL

                SELECT
                    SourceTableBetTypes.BetType,
                    ROW_NUMBER() OVER (ORDER BY SourceTableBetTypes.BetType ASC) AS _row_num_for_cycle,
                    COUNT(*) OVER () AS _total_distinct_types -- Calculate total here for matrix case
                FROM (
                    SELECT DISTINCT
                        BetType
                    FROM bodb02.dbo.SportBettypeMatrix
                    WHERE SportType = @SportType
                ) AS SourceTableBetTypes
                WHERE @BetTypeToGenerate IS NULL
            ),
            _NumbersNeeded
            AS
            (
                SELECT TOP (@NumberOfTransactions)
                    ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS n
                FROM sys.objects n_gen_a
                CROSS JOIN sys.objects n_gen_b
            ),
            BetTypeData
            AS
            (
                SELECT
                    NN.n,
                    DBT.BetType AS bettype
                FROM _NumbersNeeded NN
                LEFT JOIN _DistinctBetTypes DBT
                    ON DBT._total_distinct_types > 0 
                    AND DBT._row_num_for_cycle = ((NN.n - 1) % DBT._total_distinct_types) + 1 
            ),
            BetTransDataCTE
            AS
            (
                SELECT
                    btd.n AS original_n_for_betteam,
                    btd.bettype,
                    raw.*
                FROM BetTypeData btd
                CROSS APPLY (
                    SELECT
                        @BaseTransId + btd.n AS TransId,
                        (
                            SELECT CL.CustId
                            FROM @CustomerList CL
                            WHERE CL.RowID = (btd.n - 1) % @CustomerCount + 1
                        ) AS custid,
                        @TargetDate AS transdate,
                        700000000 + btd.n AS oddsid,
                        CASE ((btd.n + ABS(CHECKSUM(NEWID()))) % 8)
                            WHEN 0 THEN 0.0
                            WHEN 1 THEN 0.25
                            WHEN 2 THEN 0.5
                            WHEN 3 THEN 0.75
                            WHEN 4 THEN 1.0
                            WHEN 5 THEN -0.25
                            WHEN 6 THEN -0.5
                            ELSE -0.75
                        END AS hdp1,
                        0 AS hdp2,
                        CASE WHEN btd.n % 2 = 0 THEN -1.10 ELSE 0.95 END AS odds,
                        100 + (btd.n * 50) % 500 AS stake,
                        CASE WHEN btd.n % 3 = 0 THEN 'WON' WHEN btd.n % 3 = 1 THEN 'LOSE' ELSE 'WON' END AS status,
                        CASE 
                            WHEN btd.n % 3 = 0 THEN (100 + (btd.n * 50) % 500) * ABS(CASE WHEN btd.n % 2 = 0 THEN -1.10 ELSE 0.95 END)
                            WHEN btd.n % 3 = 1 THEN 0
                            ELSE (100 + (btd.n * 50) % 500) * ABS(CASE WHEN btd.n % 2 = 0 THEN -1.10 ELSE 0.95 END) * 0.5
                        END AS winlost,
                        CASE WHEN btd.n % 3 = 0 THEN (100 + (btd.n * 50) % 500) * -0.4 ELSE (100 + (btd.n * 50) % 500) * 0.364 END AS awinlost,
                        CASE WHEN btd.n % 3 = 0 THEN (100 + (btd.n * 50) % 500) * -0.3 ELSE (100 + (btd.n * 50) % 500) * 0.273 END AS mwinlost,
                        10 AS playercomm,
                        8 AS comm,
                        5 AS acomm,
                        0.4 AS apositiontaking,
                        0.3 AS mpositiontaking,
                        0.9 AS tpositiontaking,
                        0.01 AS playerdiscount,
                        0.015 AS discount,
                        0.02 AS adiscount,
                        CASE WHEN btd.n % 5 = 0 THEN 1 ELSE 0 END AS livehomescore,
                        CASE WHEN btd.n % 6 = 0 THEN 1 ELSE 0 END AS liveawayscore,
                        CASE WHEN btd.n % 5 = 0 OR btd.n % 6 = 0 THEN 1 ELSE 0 END AS liveindicator,
                        8 AS creator,
                        @BaseRefNo + btd.n AS refno,
                        0 AS comstatus,
                        @TargetDate AS winlostdate,
                        'w' AS betfrom,
                        0 AS betcheck,
                        NULL AS checktime,
                        0 AS oddsspread,
                        0.2 AS actualrate,
                        @MatchIdToUse AS matchid,
                        10063439 AS recommend,
                        10063438 AS mrecommend,
                        1 AS ruben,
                        0 AS betid,
                        CASE WHEN btd.n % 3 = 0 THEN 2 WHEN btd.n % 3 = 1 THEN 4 ELSE 1 END AS statuswinlost,
                        CASE WHEN btd.n % 2 = 0 THEN -1.10 ELSE 0.95 END AS modds,
                        btd.bettype AS BetType_from_btd,
                        -1 AS betdaqid,
                        (100 + (btd.n * 50) % 500) AS actual_stake,
                        3 AS currency,
                        NULL AS transdesc,
                        0.02 AS sdiscount,
                        2.0 AS scomm,
                        0.2 AS spositiontaking,
                        CASE WHEN btd.n % 3 = 0 THEN -80 WHEN btd.n % 3 = 1 THEN 95 ELSE -40 END AS swinlost,
                        10063437 AS srecommend,
                        1 AS virtualrate,
                        4 AS oddstype,
                        CASE WHEN btd.n % 3 = 0 THEN 112 WHEN btd.n % 3 = 1 THEN 113 ELSE 112 END AS statusID,
                        NULL AS currency2,
                        NULL AS balance,
                        NULL AS SecAcceptFlag,
                        NULL AS transid2,
                        NULL AS ExtraInfo,
                        NULL AS WalletType,
                        NULL AS BonusID,
                        NULL AS RefCode,
                        CASE 
                            WHEN btd.n % 3 = 0 THEN DATEADD(MINUTE, -((ABS(CHECKSUM(NEWID())) % 60) + 1), GETDATE())
                            ELSE DATEADD(HOUR, -((ABS(CHECKSUM(NEWID())) % 3) + 1), @TargetDate)
                        END AS SettlementTime,
                        0 AS epositiontaking,
                        NULL AS ReasonID,
                        NULL AS sort
                    ) raw
            )
        INSERT INTO #MockBetTransData (
            TransId,
            custid,
            transdate,
            oddsid,
            hdp1,
            hdp2,
            odds,
            stake,
            status,
            winlost,
            awinlost,
            mwinlost,
            playercomm,
            comm,
            acomm,
            apositiontaking,
            mpositiontaking,
            tpositiontaking,
            playerdiscount,
            discount,
            adiscount,
            livehomescore,
            liveawayscore,
            liveindicator,
            creator,
            refno,
            comstatus,
            winlostdate,
            betfrom,
            betcheck,
            checktime,
            oddsspread,
            actualrate,
            matchid,
            recommend,
            mrecommend,
            ruben,
            betid,
            statuswinlost,
            modds,
            bettype,
            betdaqid,
            actual_stake,
            currency,
            transdesc,
            sdiscount,
            scomm,
            spositiontaking,
            swinlost,
            srecommend,
            virtualrate,
            oddstype,
            statusID,
            currency2,
            balance,
            SecAcceptFlag,
            transid2,
            ExtraInfo,
            WalletType,
            BonusID,
            RefCode,
            SettlementTime,
            epositiontaking,
            ReasonID,
            sort,
            betteam
            )
        SELECT
            cte.TransId,
            cte.custid,
            cte.transdate,
            cte.oddsid,
            cte.hdp1,
            cte.hdp2,
            cte.odds,
            cte.stake,
            cte.status,
            cte.winlost,
            cte.awinlost,
            cte.mwinlost,
            cte.playercomm,
            cte.comm,
            cte.acomm,
            cte.apositiontaking,
            cte.mpositiontaking,
            cte.tpositiontaking,
            cte.playerdiscount,
            cte.discount,
            cte.adiscount,
            cte.livehomescore,
            cte.liveawayscore,
            cte.liveindicator,
            cte.creator,
            cte.refno,
            cte.comstatus,
            cte.winlostdate,
            cte.betfrom,
            cte.betcheck,
            cte.checktime,
            cte.oddsspread,
            cte.actualrate,
            cte.matchid,
            cte.recommend,
            cte.mrecommend,
            cte.ruben,
            cte.betid,
            cte.statuswinlost,
            cte.modds,
            cte.bettype,
            cte.betdaqid,
            cte.actual_stake,
            cte.currency,
            cte.transdesc,
            cte.sdiscount,
            cte.scomm,
            cte.spositiontaking,
            cte.swinlost,
            cte.srecommend,
            cte.virtualrate,
            cte.oddstype,
            cte.statusID,
            cte.currency2,
            cte.balance,
            cte.SecAcceptFlag,
            cte.transid2,
            cte.ExtraInfo,
            cte.WalletType,
            cte.BonusID,
            cte.RefCode,
            cte.SettlementTime,
            cte.epositiontaking,
            cte.ReasonID,
            cte.sort,
            CASE 
                WHEN cte.bettype IN (1, 2, 7, 8, 12, 17, 25, 27, 123) THEN CASE (cte.original_n_for_betteam + ABS(CHECKSUM(NEWID()))) % 2 WHEN 0 THEN 'h' ELSE 'a' END
                WHEN cte.bettype IN (3, 5, 15, 22, 28, 121, 122) THEN CASE (cte.original_n_for_betteam + ABS(CHECKSUM(NEWID()))) % 3 WHEN 0 THEN 'h' WHEN 1 THEN 'a' ELSE 'x' END
                WHEN cte.bettype = 4 THEN CASE (cte.original_n_for_betteam + ABS(CHECKSUM(NEWID()))) % 31
                    WHEN 0 THEN '0:0' WHEN 1 THEN '0:1' WHEN 2 THEN '0:2' WHEN 3 THEN '0:3' WHEN 4 THEN '0:4' WHEN 5 THEN '0:5'
                    WHEN 6 THEN '1:0' WHEN 7 THEN '1:1' WHEN 8 THEN '1:2' WHEN 9 THEN '1:3' WHEN 10 THEN '1:4' WHEN 11 THEN '2:0'
                    WHEN 12 THEN '2:1' WHEN 13 THEN '2:2' WHEN 14 THEN '2:3' WHEN 15 THEN '2:4' WHEN 16 THEN '3:0' WHEN 17 THEN '3:1'
                    WHEN 18 THEN '3:2' WHEN 19 THEN '3:3' WHEN 20 THEN '3:4' WHEN 21 THEN '4:0' WHEN 22 THEN '4:1' WHEN 23 THEN '4:2'
                    WHEN 24 THEN '4:3' WHEN 25 THEN '4:4' WHEN 26 THEN '5:0' ELSE 'AOS'
                    END
                WHEN cte.bettype = 6 THEN CASE (cte.original_n_for_betteam + ABS(CHECKSUM(NEWID()))) % 4 WHEN 0 THEN '0-1' WHEN 1 THEN '2-3' WHEN 2 THEN '4-6' ELSE '7-Over' END
                WHEN cte.bettype = 13 THEN CASE (cte.original_n_for_betteam + ABS(CHECKSUM(NEWID()))) % 4 WHEN 0 THEN 'an' WHEN 1 THEN 'ay' WHEN 2 THEN 'hn' ELSE 'hy' END
                WHEN cte.bettype = 14 THEN CASE (cte.original_n_for_betteam + ABS(CHECKSUM(NEWID()))) % 5 WHEN 0 THEN '0:0' WHEN 1 THEN '1:1' WHEN 2 THEN '1:2' WHEN 3 THEN '2:1' ELSE '2:2' END
                WHEN cte.bettype = 16 THEN CASE (cte.original_n_for_betteam + ABS(CHECKSUM(NEWID()))) % 9
                    WHEN 0 THEN '0:0' WHEN 1 THEN '0:1' WHEN 2 THEN '0:2' WHEN 3 THEN '1:0' WHEN 4 THEN '1:1' WHEN 5 THEN '1:2'
                    WHEN 6 THEN '2:0' WHEN 7 THEN '2:1' ELSE '2:2'
                    END
                WHEN cte.bettype = 18 THEN CASE (cte.original_n_for_betteam + ABS(CHECKSUM(NEWID()))) % 2 WHEN 0 THEN 'o' ELSE 'u' END
                WHEN cte.bettype IN (143, 144) THEN CASE (cte.original_n_for_betteam + ABS(CHECKSUM(NEWID()))) % 6
                    WHEN 0 THEN 'ao' WHEN 1 THEN 'au' WHEN 2 THEN 'do' WHEN 3 THEN 'du' WHEN 4 THEN 'ho' ELSE 'hu'
                    END
                WHEN cte.bettype = 24 THEN CASE (cte.original_n_for_betteam + ABS(CHECKSUM(NEWID()))) % 3 WHEN 0 THEN '12' WHEN 1 THEN '1x' ELSE '2x' END
                WHEN cte.bettype = 26 THEN CASE (cte.original_n_for_betteam + ABS(CHECKSUM(NEWID()))) % 3 WHEN 0 THEN 'b' WHEN 1 THEN 'n' ELSE 'o' END
                WHEN cte.bettype = 30 THEN CASE (cte.original_n_for_betteam + ABS(CHECKSUM(NEWID()))) % 18
                    WHEN 0 THEN '0:0' WHEN 1 THEN '0:1' WHEN 2 THEN '0:2' WHEN 3 THEN '0:3' WHEN 4 THEN '0:4' WHEN 5 THEN '1:0'
                    WHEN 6 THEN '1:1' WHEN 7 THEN '1:2' WHEN 8 THEN '1:3' WHEN 9 THEN '2:0' WHEN 10 THEN '2:1' WHEN 11 THEN '2:2'
                    WHEN 12 THEN '2:3' WHEN 13 THEN '3:0' WHEN 14 THEN '3:1' WHEN 15 THEN '3:2' WHEN 16 THEN '3:3' ELSE '4:0'
                    END
                WHEN cte.bettype = 126 THEN CASE (cte.original_n_for_betteam + ABS(CHECKSUM(NEWID()))) % 4 WHEN 0 THEN '0-1' WHEN 1 THEN '2-3' WHEN 2 THEN '4&Over' ELSE '4-Over' END
                WHEN cte.bettype = 127 THEN CASE (cte.original_n_for_betteam + ABS(CHECKSUM(NEWID()))) % 5 WHEN 0 THEN '0:0' WHEN 1 THEN '1:1' WHEN 2 THEN '1:2' WHEN 3 THEN '2:1' ELSE '2:2' END
                WHEN cte.bettype = 128 THEN CASE (cte.original_n_for_betteam + ABS(CHECKSUM(NEWID()))) % 4 WHEN 0 THEN 'ee' WHEN 1 THEN 'eo' WHEN 2 THEN 'oe' ELSE 'oo' END
                WHEN cte.bettype = 129 THEN CASE (cte.original_n_for_betteam + ABS(CHECKSUM(NEWID()))) % 6
                    WHEN 0 THEN '0' WHEN 1 THEN '1' WHEN 2 THEN '2' WHEN 3 THEN '3' WHEN 4 THEN '4' ELSE '5&Over'
                    END
                WHEN cte.bettype = 130 THEN CASE (cte.original_n_for_betteam + ABS(CHECKSUM(NEWID()))) % 8
                    WHEN 0 THEN '0' WHEN 1 THEN '1' WHEN 2 THEN '2' WHEN 3 THEN '3' WHEN 4 THEN '4' WHEN 5 THEN '5'
                    WHEN 6 THEN '6' ELSE '7&Over'
                    END
                WHEN cte.bettype IN (131, 132) THEN CASE (cte.original_n_for_betteam + ABS(CHECKSUM(NEWID()))) % 3 WHEN 0 THEN '0-1' WHEN 1 THEN '2-3' ELSE '4&Over' END
                WHEN cte.bettype IN (136, 137, 138, 139) THEN CASE (cte.original_n_for_betteam + ABS(CHECKSUM(NEWID()))) % 2 WHEN 0 THEN 'e' ELSE 'o' END
                ELSE CASE (cte.original_n_for_betteam + ABS(CHECKSUM(NEWID()))) % 2 WHEN 0 THEN 'h' ELSE 'a' END
            END AS betteam
        FROM BetTransDataCTE cte
        OPTION (RECOMPILE);

        -- Conditionally insert from #MockBetTransData to the target bettrans table
        IF @TargetTableChoice = 1
        BEGIN
            INSERT INTO bodb_Archive.dbo.bettrans_bk (
                TransId,
                custid,
                transdate,
                oddsid,
                hdp1,
                hdp2,
                odds,
                stake,
                status,
                winlost,
                awinlost,
                mwinlost,
                playercomm,
                comm,
                acomm,
                apositiontaking,
                mpositiontaking,
                tpositiontaking,
                playerdiscount,
                discount,
                adiscount,
                livehomescore,
                liveawayscore,
                liveindicator,
                creator,
                refno,
                comstatus,
                winlostdate,
                betfrom,
                betcheck,
                checktime,
                oddsspread,
                actualrate,
                matchid,
                recommend,
                mrecommend,
                ruben,
                betid,
                statuswinlost,
                modds,
                bettype,
                betdaqid,
                actual_stake,
                currency,
                transdesc,
                sdiscount,
                scomm,
                spositiontaking,
                swinlost,
                srecommend,
                virtualrate,
                oddstype,
                statusID,
                currency2,
                balance,
                SecAcceptFlag,
                transid2,
                ExtraInfo,
                WalletType,
                BonusID,
                RefCode,
                SettlementTime,
                epositiontaking,
                ReasonID,
                sort,
                betteam
                )
            SELECT
                TransId,
                custid,
                transdate,
                oddsid,
                hdp1,
                hdp2,
                odds,
                stake,
                status,
                winlost,
                awinlost,
                mwinlost,
                playercomm,
                comm,
                acomm,
                apositiontaking,
                mpositiontaking,
                tpositiontaking,
                playerdiscount,
                discount,
                adiscount,
                livehomescore,
                liveawayscore,
                liveindicator,
                creator,
                refno,
                comstatus,
                winlostdate,
                betfrom,
                betcheck,
                checktime,
                oddsspread,
                actualrate,
                matchid,
                recommend,
                mrecommend,
                ruben,
                betid,
                statuswinlost,
                modds,
                bettype,
                betdaqid,
                actual_stake,
                currency,
                transdesc,
                sdiscount,
                scomm,
                spositiontaking,
                swinlost,
                srecommend,
                virtualrate,
                oddstype,
                statusID,
                currency2,
                balance,
                SecAcceptFlag,
                transid2,
                ExtraInfo,
                WalletType,
                BonusID,
                RefCode,
                SettlementTime,
                epositiontaking,
                ReasonID,
                sort,
                betteam
            FROM #MockBetTransData;

            PRINT 'Inserted ' + CAST(@@ROWCOUNT AS VARCHAR) + ' dummy Soccer transactions into bodb_Archive.dbo.bettrans_bk.';
        END
        ELSE IF @TargetTableChoice = 2
        BEGIN
            INSERT INTO bodb02.dbo.bettrans14 (
                TransId,
                custid,
                transdate,
                oddsid,
                hdp1,
                hdp2,
                odds,
                stake,
                status,
                winlost,
                awinlost,
                mwinlost,
                playercomm,
                comm,
                acomm,
                apositiontaking,
                mpositiontaking,
                tpositiontaking,
                playerdiscount,
                discount,
                adiscount,
                livehomescore,
                liveawayscore,
                liveindicator,
                creator,
                refno,
                comstatus,
                winlostdate,
                betfrom,
                betcheck,
                checktime,
                oddsspread,
                actualrate,
                matchid,
                recommend,
                mrecommend,
                ruben,
                betid,
                statuswinlost,
                modds,
                bettype,
                betdaqid,
                actual_stake,
                currency,
                transdesc,
                sdiscount,
                scomm,
                spositiontaking,
                swinlost,
                srecommend,
                virtualrate,
                oddstype,
                statusID,
                currency2,
                balance,
                SecAcceptFlag,
                transid2,
                ExtraInfo,
                WalletType,
                BonusID,
                RefCode,
                SettlementTime,
                epositiontaking,
                ReasonID,
                sort,
                betteam
                )
            SELECT
                TransId,
                custid,
                transdate,
                oddsid,
                hdp1,
                hdp2,
                odds,
                stake,
                status,
                winlost,
                awinlost,
                mwinlost,
                playercomm,
                comm,
                acomm,
                apositiontaking,
                mpositiontaking,
                tpositiontaking,
                playerdiscount,
                discount,
                adiscount,
                livehomescore,
                liveawayscore,
                liveindicator,
                creator,
                refno,
                comstatus,
                winlostdate,
                betfrom,
                betcheck,
                checktime,
                oddsspread,
                actualrate,
                matchid,
                recommend,
                mrecommend,
                ruben,
                betid,
                statuswinlost,
                modds,
                bettype,
                betdaqid,
                actual_stake,
                currency,
                transdesc,
                sdiscount,
                scomm,
                spositiontaking,
                swinlost,
                srecommend,
                virtualrate,
                oddstype,
                statusID,
                currency2,
                balance,
                SecAcceptFlag,
                transid2,
                ExtraInfo,
                WalletType,
                BonusID,
                RefCode,
                SettlementTime,
                epositiontaking,
                ReasonID,
                sort,
                betteam
            FROM #MockBetTransData;

            PRINT 'Inserted ' + CAST(@@ROWCOUNT AS VARCHAR) + ' dummy Soccer transactions into bodb02.dbo.bettrans14.';
        END
        ELSE IF @TargetTableChoice = 3
        BEGIN
            INSERT INTO bodb02.dbo.bettrans (
                TransId,
                custid,
                transdate,
                oddsid,
                hdp1,
                hdp2,
                odds,
                stake,
                status,
                winlost,
                awinlost,
                mwinlost,
                playercomm,
                comm,
                acomm,
                apositiontaking,
                mpositiontaking,
                tpositiontaking,
                playerdiscount,
                discount,
                adiscount,
                livehomescore,
                liveawayscore,
                liveindicator,
                creator,
                refno,
                comstatus,
                winlostdate,
                betfrom,
                betcheck,
                checktime,
                oddsspread,
                actualrate,
                matchid,
                recommend,
                mrecommend,
                ruben,
                betid,
                statuswinlost,
                modds,
                bettype,
                betdaqid,
                actual_stake,
                currency,
                transdesc,
                sdiscount,
                scomm,
                spositiontaking,
                swinlost,
                srecommend,
                virtualrate,
                oddstype,
                statusID,
                currency2,
                balance,
                SecAcceptFlag,
                transid2,
                ExtraInfo,
                WalletType,
                BonusID,
                RefCode,
                SettlementTime,
                epositiontaking,
                ReasonID,
                sort,
                betteam
                )
            SELECT
                TransId,
                custid,
                transdate,
                oddsid,
                hdp1,
                hdp2,
                odds,
                stake,
                status,
                winlost,
                awinlost,
                mwinlost,
                playercomm,
                comm,
                acomm,
                apositiontaking,
                mpositiontaking,
                tpositiontaking,
                playerdiscount,
                discount,
                adiscount,
                livehomescore,
                liveawayscore,
                liveindicator,
                creator,
                refno,
                comstatus,
                winlostdate,
                betfrom,
                betcheck,
                checktime,
                oddsspread,
                actualrate,
                matchid,
                recommend,
                mrecommend,
                ruben,
                betid,
                statuswinlost,
                modds,
                bettype,
                betdaqid,
                actual_stake,
                currency,
                transdesc,
                sdiscount,
                scomm,
                spositiontaking,
                swinlost,
                srecommend,
                virtualrate,
                oddstype,
                statusID,
                currency2,
                balance,
                SecAcceptFlag,
                transid2,
                ExtraInfo,
                WalletType,
                BonusID,
                RefCode,
                SettlementTime,
                epositiontaking,
                ReasonID,
                sort,
                betteam
            FROM #MockBetTransData;

            PRINT 'Inserted ' + CAST(@@ROWCOUNT AS VARCHAR) + ' dummy Soccer transactions into bodb02.dbo.bettrans.';
        END;

        -- Clean up temp table
        IF OBJECT_ID('tempdb..#MockBetTransData') IS NOT NULL
            DROP TABLE #MockBetTransData;

        PRINT 'Finished generating bet transactions for MatchID: ' + CAST(@MatchIdToUse AS VARCHAR);
    END TRY
    BEGIN CATCH
        PRINT 'Error in TGRS_SB_gen_bet_transactions: ' + ERROR_MESSAGE();
        
        -- Clean up temp table in case of error
        IF OBJECT_ID('tempdb..#MockBetTransData') IS NOT NULL
            DROP TABLE #MockBetTransData;
            
        THROW;
    END CATCH
END
GO 