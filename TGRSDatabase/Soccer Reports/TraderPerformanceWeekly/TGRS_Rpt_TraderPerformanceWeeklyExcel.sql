/*<info serverAlias="DBTGRS-bodb_TGRS" executers="wsv_tgrs" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[TGRS_Rpt_TraderPerformanceWeeklyExcel]
    @Year               INT
AS
/*
    Created:    20250507@Jaden.Tang
    Task:       Trader Performance Weekly report, aggregated daily data to weekly,
                with results grouped by month for display purposes.
    DB:         DBTGRS.bodb_TGRS
    Original:   TGRS_Rpt_TraderPerformanceMonthly

    Revisions:
        - 20250507@Jaden.Tang: Create New (#225623)
		- 20250523@Della: fix bug #228280

    Param's Explanation:
        @Year:                 Report Year (e.g., 2025)

    Example:
        EXEC dbo.TGRS_Rpt_TraderPerformanceWeeklyExcel @Year = 2025, @SelectedYearWeeks = NULL;

    Remarks:
        Return a single dataset for all three sheets. Web will not pass in the month and week parameters, 
        we returns all data at Date level for the whole @Year, web will do the filtering and grouping accordingly.
*/
BEGIN
    SET NOCOUNT ON;
    SET DATEFIRST 1; --Monday as the first day of the week

    DECLARE @FilterStartDate DATE;
    DECLARE @FilterEndDate DATE;
    DECLARE @StartDateOfYear DATE = DATEFROMPARTS(@Year, 1, 1);
    DECLARE @EndDateOfYear DATE = DATEFROMPARTS(@Year, 12, 31);

    -- Calculate the first day (Monday) of the ISO week for @StartDateOfYear.
    -- This is done by finding the number of full weeks from a reference Monday (1900-01-01)
    -- and adding that duration back to the reference Monday.
    SET @FilterStartDate = DATEADD(DAY, (DATEDIFF(DAY, '19000101', @StartDateOfYear) / 7) * 7, '19000101');
    -- Calculate the last day (Sunday) of the ISO week for @EndDateOfYear.
    -- This uses the same logic as above, then adds 6 days to get to Sunday.
    SET @FilterEndDate = DATEADD(DAY, (DATEDIFF(DAY, '19000101', @EndDateOfYear) / 7) * 7 + 6, '19000101');

    PRINT 'Filter range: ' + CAST(@FilterStartDate AS VARCHAR(10)) + ' to ' + CAST(@FilterEndDate AS VARCHAR(10));

    -- #region Trader Information
    IF OBJECT_ID('''tempdb..#tmpTraderInfo''') IS NOT NULL DROP TABLE #tmpTraderInfo;
    CREATE TABLE #tmpTraderInfo (
        TraderID        INT PRIMARY KEY,
        TraderName      VARCHAR(30),
        Grade           TINYINT,
        TeamName        NVARCHAR(50),
        Department      NVARCHAR(50)
    );

    INSERT INTO #tmpTraderInfo (TraderID, TraderName, Grade, TeamName, Department)
    SELECT
        t.CustId,
        t.Username AS TraderName,
        t.Grade,
        tm.TeamName,
        CASE
            -- CPH Department Rules (in order of precedence as per image)
            WHEN tm.TeamName = 'CPH'                                                       THEN 'CPH' -- Rule: CPH.1
            WHEN tm.TeamName = 'Support 1X2 Team' AND LEFT(ISNULL(vc.Username, ''), 3) = 'CPH' THEN 'CPH' -- Rule: CPH.2
            WHEN tm.TeamName = 'Support Team'     AND LEFT(ISNULL(vc.Username, ''), 3) = 'CPH' THEN 'CPH' -- Rule: CPH.3
            WHEN tm.TeamName = 'UnassignedTeam'                                            THEN 'CPH' -- Rule: CPH.4
            WHEN ISNULL(vc.Username, '') = 'CLAAye'                                        THEN 'CPH' -- Rule: CPH.5

            -- SPH Department Rules (in order of precedence)
            WHEN tm.TeamName = 'SPH'                                                       THEN 'SPH' -- Rule: SPH.1
            WHEN tm.TeamName = 'Support 1X2 Team' AND LEFT(ISNULL(vc.Username, ''), 3) = 'SPH' THEN 'SPH' -- Rule: SPH.2
            WHEN tm.TeamName = 'Support Team'     AND LEFT(ISNULL(vc.Username, ''), 3) = 'SPH' THEN 'SPH' -- Rule: SPH.3

            -- LG Department (Default for all others)
            ELSE 'LG'
        END AS Department
    FROM dbo.Trader t WITH(NOLOCK)
    LEFT JOIN dbo.Team tm WITH(NOLOCK) ON t.TeamId = tm.TeamId
    LEFT JOIN bodb02.dbo.customer vc WITH(NOLOCK) ON t.CustId = vc.custid;
    -- #endregion

	-- #temp table
	CREATE TABLE #tmpLeagueSABA (LeagueID INT, LeagueGroupID INT)  
	INSERT INTO #tmpLeagueSABA (LeagueID, LeagueGroupID)  
	SELECT LeagueID, LeagueGroupID  
	FROM bodb02.dbo.League WITH(NOLOCK)  
	WHERE Sporttype = 1 AND LeagueGroupID IN (42,74) AND (leaguename LIKE '%5 Mins Play%' OR leaguename LIKE '%6 Mins Play%' OR 
	leaguename LIKE '%15 Mins Play%' OR leaguename LIKE '%16 Mins Play%' OR leaguename LIKE '%20 Mins Play%')

    -- #region Aggregate Daily Performance Data
    IF OBJECT_ID('''tempdb..#tmpAggregatedData''') IS NOT NULL DROP TABLE #tmpAggregatedData;
    CREATE TABLE #tmpAggregatedData (
        TraderID        INT,
        EventDate       DATE,
        LeagueID        INT,
        Turnover        MONEY,
        NetWinLoss      MONEY,
        BetCount        INT,
        MatchCount      INT
        PRIMARY KEY (TraderID, EventDate, LeagueID)
    );

    --SET STATISTICS XML ON
    INSERT INTO #tmpAggregatedData (TraderID, EventDate, LeagueID, Turnover, NetWinLoss, BetCount, MatchCount)
    SELECT
        tp.CustId AS TraderID,
        tp.EventDate,
        tp.LeagueId,
        SUM(ISNULL(tp.Stake_Real, 0)) AS Turnover,
        SUM(ISNULL(tp.WinLost_Real, 0) - ISNULL(tp.Comm, 0)) AS NetWinLoss,
        SUM(ISNULL(tp.BetCount, 0)) AS BetCount,
        COUNT(DISTINCT tp.MatchId) AS MatchCount
    FROM dbo.TraderPerformance tp WITH(NOLOCK)
	INNER JOIN #tmpLeagueSABA ls WITH(NOLOCK) on tp.LeagueId=ls.LeagueID
    WHERE tp.EventDate >= @FilterStartDate AND tp.EventDate <= @FilterEndDate
	AND tp.BetType in (1,3,7,8)
    GROUP BY
        tp.CustId,
        tp.EventDate,
        tp.LeagueId
    OPTION (RECOMPILE);
    --SET STATISTICS XML OFF
    -- #endregion

    -- #region Final Output
    SELECT
        ti.TraderName,
        agg.EventDate,
        l.LeagueName,
        ti.Grade,
        ti.TeamName,
        ti.Department,
        ISNULL(agg.Turnover, 0) AS Turnover,
        ISNULL(agg.NetWinLoss, 0) AS NetWinLoss,
        CASE
            WHEN ISNULL(agg.Turnover, 0) = 0 THEN 0
            ELSE ISNULL(agg.NetWinLoss, 0) / agg.Turnover
        END AS Margin,
        ISNULL(agg.BetCount, 0) AS BetCount,
        ISNULL(agg.MatchCount, 0) AS MatchCount
    FROM #tmpAggregatedData agg 
    INNER JOIN #tmpTraderInfo ti ON ti.TraderID = agg.TraderID
    INNER JOIN bodb02.dbo.league l WITH(NOLOCK) ON agg.LeagueId = l.leagueid
    ORDER BY
        ti.TraderName,
        agg.EventDate;
    -- #endregion

    -- #region Cleanup Temp Tables
    IF OBJECT_ID('''tempdb..#tmpTraderInfo''') IS NOT NULL DROP TABLE #tmpTraderInfo;
    IF OBJECT_ID('''tempdb..#tmpAggregatedData''') IS NOT NULL DROP TABLE #tmpAggregatedData;
	DROP TABLE #tmpLeagueSABA
    -- #endregion

END;
GO 