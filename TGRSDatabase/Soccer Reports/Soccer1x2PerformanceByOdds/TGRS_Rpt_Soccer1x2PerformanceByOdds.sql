/*<info serverAlias="DBWH-bodb_dwrs" executers="dwrs" isFunction="0" isNested="0"></info>*/
USE bodb_dwrs
GO
ALTER PROCEDURE [dbo].[Acc_Rpt_TGR_Soccer1x2PerformanceByOdds]
    @FromDate SMALLDATETIME,
    @ToDate SMALLDATETIME
AS
/*  
	Created:	20241112@Jaden (#213524)
	Task :		Adhoc Report
	DB:			DBWH.bodb_dwrs
  
	Revisions: 	
        - 20241112@Jaden: Init
*/
BEGIN
    CREATE TABLE [#source] (
        RptDate SMALLDATETIME,
        MatchID INT,
        BetType INT,
        BetCount INT,
        TurnoverIBC MONEY,
        WinlossIBC MONEY,
        Turnover1 MONEY,
        TurnoverX MONEY,
        Turnover2 MONEY,
        Winloss1 MONEY,
        WinlossX MONEY,
        Winloss2 MONEY,
        Odds1 FLOAT,
        OddsX FLOAT,
        Odds2 FLOAT,
        Favorite VARCHAR(10)
    )

    INSERT INTO [#source] (
        RptDate,
        MatchID,
        BetType,
        BetCount,
        TurnoverIBC,
        WinlossIBC,
        Odds1,
        OddsX,
        Odds2,
        Turnover1,
        TurnoverX,
        Turnover2,
        Winloss1,
        WinlossX,
        Winloss2,
        Favorite
    )
    SELECT 
        f.RptDate AS RptDate,
        f.MatchID,
        f.BetType,
        SUM(f.BetCount) AS BetCount,
        SUM(f.TurnoverIBC * c.Rate * IIF(f.TicketStatus IN (12, 13), 0.5, 1)) AS TurnoverIBC,
        SUM(f.WinlossIBC * c.Rate) AS WinlossIBC,
        MAX(soccer_odds.field_value_1) AS Odds1, --odds of Home (1)
        MAX(soccer_odds.field_value_2) AS OddsX, --odds of Draw (X)
        MAX(soccer_odds.field_value_3) AS Odds2, --odds of Away (2)
        SUM(CASE WHEN bc.BetChoiceName = 'Home' OR bc.BetChoiceName = 'FT Asian.1' THEN f.TurnoverIBC * c.Rate
            ELSE 0 END * IIF(f.TicketStatus IN (12, 13), 0.5, 1)) AS Turnover1,
        SUM(CASE WHEN bc.BetChoiceName = 'Draw' OR bc.BetChoiceName = 'FT Asian.X' THEN f.TurnoverIBC * c.Rate
            ELSE 0 END * IIF(f.TicketStatus IN (12, 13), 0.5, 1)) AS TurnoverX,
        SUM(CASE WHEN bc.BetChoiceName = 'Away' OR bc.BetChoiceName = 'FT Asian.2' THEN f.TurnoverIBC * c.Rate
            ELSE 0 END * IIF(f.TicketStatus IN (12, 13), 0.5, 1)) AS Turnover2,
        SUM(CASE WHEN bc.BetChoiceName = 'Home' OR bc.BetChoiceName = 'FT Asian.1' THEN f.WinlossIBC * c.Rate
            ELSE 0 END) AS Winloss1,
        SUM(CASE WHEN bc.BetChoiceName = 'Draw' OR bc.BetChoiceName = 'FT Asian.X' THEN f.WinlossIBC * c.Rate
            ELSE 0 END) AS WinlossX,
        SUM(CASE WHEN bc.BetChoiceName = 'Away' OR bc.BetChoiceName = 'FT Asian.2' THEN f.WinlossIBC * c.Rate
            ELSE 0 END) AS Winloss2,
        CASE WHEN MAX(soccer_odds.field_value_1) IS NULL OR MAX(soccer_odds.field_value_3) IS NULL THEN NULL
            WHEN MAX(soccer_odds.field_value_1) < MAX(soccer_odds.field_value_3) THEN 'Home'
            WHEN MAX(soccer_odds.field_value_3) < MAX(soccer_odds.field_value_1) THEN 'Away'
            ELSE 'Home' END AS Fav
    FROM bodb_Account.dbo.FactBetChoiceDaily f WITH (NOLOCK)
    LEFT JOIN bodb_Account.dbo.ibc_odds2 soccer_odds WITH (NOLOCK)
        ON f.MatchID = soccer_odds.match_id
            AND f.RptDate = soccer_odds.event_date
            AND f.bettype = soccer_odds.bet_type_id
            AND soccer_odds.is_live = 0
            AND soccer_odds.[type] = 'Last Odds'
    INNER JOIN bodb_Account.dbo.tbl_currency_daily c WITH (NOLOCK)
        ON f.CurrencyID = c.Currency
            AND f.RptDate = c.ExchangeDate
    INNER JOIN bodb_Account.dbo.DimBetChoice bc WITH (NOLOCK)
        ON f.BetChoiceID = bc.BetChoiceID
            AND f.BetType = bc.BetType
    WHERE f.bettype IN (5, 15, 458, 459)
        AND f.LiveStatus = 0
        AND f.CurrencyID <> 20
        AND f.TicketStatus IN (8, 4, 3, 12, 13)
        AND f.RptDate BETWEEN @FromDate AND @ToDate
        AND f.SportType = 1
    GROUP BY f.RptDate, 
        f.MatchID,
        f.BetType
    OPTION (RECOMPILE)

    CREATE TABLE #match (
        MatchID INT,
        MatchName NVARCHAR(1000),
        LeagueID INT,
        LeagueName NVARCHAR(500),
        LeagueGroup NVARCHAR(500),
        FTHomeScore INT,
        FTAwayScore INT,
        HTHomeScore INT,
        HTAwayScore INT
    )

    BEGIN
        INSERT INTO #match (
            MatchID,
            MatchName,
            LeagueID,
            LeagueName,
            LeagueGroup,
            FTHomeScore,
            FTAwayScore,
            HTHomeScore,
            HTAwayScore
        )
        SELECT m.MatchID,
            h.teamname + ' -vs- ' + a.teamname AS [MatchName],
            m.LeagueID,
            l.leaguename AS [LeagueName],
            ISNULL(lg.GroupName, 'Others') AS [LeagueGroup],
            m.finalhomescore,
            m.finalawayscore,
            m.hthomescore,
            m.htawayscore
        FROM bodb_Account.dbo.[match] m WITH (NOLOCK)
        INNER JOIN bodb_Account.dbo.Team h WITH (NOLOCK)
            ON m.homeid = h.teamid
        INNER JOIN bodb_Account.dbo.Team a WITH (NOLOCK)
            ON m.awayid = a.teamid
        INNER JOIN bodb02.dbo.[league] l WITH (NOLOCK)
            ON m.LeagueID = l.LeagueID
            AND l.LeagueGroupID <> 113 -- exclude SABA Pingoal
        LEFT JOIN bodb02.dbo.LeagueGroup lg WITH (NOLOCK)
            ON l.LeagueGroupID = lg.GroupID
        WHERE m.MatchID IN (SELECT MatchID FROM [#source])
            AND m.eventdate BETWEEN @FromDate AND @ToDate
        OPTION (RECOMPILE)

        INSERT INTO #match (
            MatchID,
            MatchName,
            LeagueID,
            LeagueName,
            LeagueGroup,
            FTHomeScore,
            FTAwayScore,
            HTHomeScore,
            HTAwayScore
        )
        SELECT m.MatchID,
            h.teamname + ' -vs- ' + a.teamname AS [MatchName],
            m.LeagueID,
            l.leaguename AS [LeagueName],
            ISNULL(lg.GroupName, 'Others') AS [LeagueGroup],
            m.finalhomescore,
            m.finalawayscore,
            m.hthomescore,
            m.htawayscore
        FROM bodb_archive.dbo.[match] m WITH (NOLOCK)
        INNER JOIN bodb_Account.dbo.Team h WITH (NOLOCK)
            ON m.homeid = h.teamid
        INNER JOIN bodb_Account.dbo.Team a WITH (NOLOCK)
            ON m.awayid = a.teamid
        INNER JOIN bodb02.dbo.[league] l WITH (NOLOCK)
            ON m.LeagueID = l.LeagueID
            AND l.LeagueGroupID <> 113 -- exclude SABA Pingoal
        LEFT JOIN bodb02.dbo.LeagueGroup lg WITH (NOLOCK)
            ON l.LeagueGroupID = lg.GroupID
        WHERE m.MatchID IN (SELECT MatchID FROM [#source])
            AND m.eventdate BETWEEN @FromDate AND @ToDate
            AND m.matchid NOT IN (SELECT matchid FROM [#match])
        OPTION (RECOMPILE)
    END
    
    SELECT
        FORMAT(s.RptDate, 'MMM') AS [Month],
        s.RptDate AS [Date],
        m.LeagueGroup AS [League Group],
        m.LeagueName AS [League],
        -- m.MatchID,
        m.MatchName AS [Match],
        --s.BetType,
        bt.typenamee AS [Bettype],
        s.BetCount AS [Bet Count],
        s.TurnoverIBC AS [Turnover],
        - s.WinlossIBC AS [Winloss],
        CASE WHEN s.TurnoverIBC = 0 THEN 0 ELSE s.WinlossIBC * 100 / s.TurnoverIBC END AS [Margin],
        s.Odds1 AS [Odds 1],
        s.OddsX AS [Odds X],
        s.Odds2 AS [Odds 2],
        s.Turnover1 AS [Turnover 1],
        s.TurnoverX AS [Turnover X],
        s.Turnover2 AS [Turnover 2],
        - s.Winloss1 AS [Winloss 1],
        - s.WinlossX AS [Winloss X],
        - s.Winloss2 AS [Winloss 2],
        m.FTHomeScore AS [Home],
        m.FTAwayScore AS [Away],
        m.HTHomeScore AS [1H Home],
        m.HTAwayScore AS [1H Away],
        s.Favorite AS [Fav],
        CASE WHEN m.FTHomeScore = m.FTAwayScore THEN 'Draw'
            WHEN m.FTHomeScore > m.FTAwayScore AND s.Favorite = 'Home' THEN 'Fav'
            WHEN m.FTHomeScore < m.FTAwayScore AND s.Favorite = 'Home' THEN 'Underdog'
            WHEN m.FTHomeScore > m.FTAwayScore AND s.Favorite = 'Away' THEN 'Underdog'
            WHEN m.FTHomeScore < m.FTAwayScore AND s.Favorite = 'Away' THEN 'Fav'
        END AS [FT Result],
        CASE WHEN m.HTHomeScore = m.HTAwayScore THEN 'Draw'
            WHEN m.HTHomeScore > m.HTAwayScore AND s.Favorite = 'Home' THEN 'Fav'
            WHEN m.HTHomeScore < m.HTAwayScore AND s.Favorite = 'Home' THEN 'Underdog'
            WHEN m.HTHomeScore > m.HTAwayScore AND s.Favorite = 'Away' THEN 'Underdog'
            WHEN m.HTHomeScore < m.HTAwayScore AND s.Favorite = 'Away' THEN 'Fav'
        END AS [HT Result]
    FROM [#source] s
    INNER JOIN [#match] m
        ON m.MatchID = s.MatchID
    INNER JOIN bodb02.dbo.bettype bt
        ON s.BetType = bt.typeid
END