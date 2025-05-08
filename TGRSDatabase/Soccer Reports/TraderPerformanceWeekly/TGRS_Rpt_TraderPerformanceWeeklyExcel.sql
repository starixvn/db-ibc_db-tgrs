/*<info serverAlias="DBTGRS-bodb_TGRS" executers="bodbTGRSNet" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[TGRS_Rpt_TraderPerformanceWeeklyExcel]
    @Year               INT,
    @SelectedYearWeeks  VARCHAR(MAX) = NULL  -- Default to NULL for entire year, comma-separated ISO week numbers e.g., "1,2,3,52"
AS
/*
    Created:    20250507@Jaden.Tang
    Task:       Trader Performance Weekly report, aggregated daily data to weekly,
                with results grouped by month for display purposes.
    DB:         DBTGRS.bodb_TGRS
    Original:   TGRS_Rpt_TraderPerformanceMonthly

    Revisions:
                - 20250507@Jaden.Tang: Create New

    Param's Explanation:
        @Year:                 Report Year (e.g., 2025)
        @SelectedYearWeeks:    Comma-separated string of ISO 8601 week numbers for the given @Year (e.g., "1,2,3,52").
                               If NULL, all weeks for the @Year will be processed.

    Example:
        EXEC dbo.TGRS_Rpt_TraderPerformanceWeeklyExcel @Year = 2025, @SelectedYearWeeks = NULL;
*/
BEGIN
    SET NOCOUNT ON;
    SET DATEFIRST 1; -- Ensure Monday is the first day of the week for DATENAME functions if used, though TVF is agnostic.

    -- #region Temporary Tables for Parameters
    IF OBJECT_ID('''tempdb..#tmpSelectedYearWeeks''') IS NOT NULL DROP TABLE #tmpSelectedYearWeeks;
    CREATE TABLE #tmpSelectedYearWeeks (YearWeekNumber INT PRIMARY KEY);

    IF @SelectedYearWeeks IS NULL
    BEGIN
        DECLARE @NumWeeksInYear INT;
        -- The 28th of December is always in the last ISO week of its year.
        -- This correctly gives 52 or 53.
        SET @NumWeeksInYear = DATEPART(isowk, DATEFROMPARTS(@Year, 12, 28));

        ;WITH AllYearWeeks AS (
            SELECT 1 AS WeekNum
            UNION ALL
            SELECT WeekNum + 1
            FROM AllYearWeeks
            WHERE WeekNum < @NumWeeksInYear
        )
        INSERT INTO #tmpSelectedYearWeeks (YearWeekNumber)
        SELECT WeekNum FROM AllYearWeeks
        OPTION (MAXRECURSION 53); -- Max 53 weeks in a year
    END
    ELSE
    BEGIN
        INSERT INTO #tmpSelectedYearWeeks (YearWeekNumber)
        SELECT DISTINCT LTRIM(RTRIM(value)) 
        FROM STRING_SPLIT(@SelectedYearWeeks, ',') 
        WHERE ISNUMERIC(LTRIM(RTRIM(value))) = 1 AND LTRIM(RTRIM(value)) <> '';
    END
    -- #endregion

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
            WHEN tm.TeamName IN ('Support Team', 'Support 1X2 Team') THEN
                CASE
                    WHEN vc.Username LIKE 'CPH%' THEN 'CPH team'
                    WHEN vc.Username LIKE 'SPH%' THEN 'SPH team'
                    ELSE 'LG'
                END
            WHEN tm.TeamName LIKE 'CPH%' THEN 'CPH team'
            WHEN tm.TeamName LIKE 'SPH%' THEN 'SPH team'
            WHEN tm.TeamName IN ('UnassignedTeam', 'CLAAye') THEN 'LG'
            ELSE 'LG' -- Default for other teams
        END AS Department
    FROM dbo.Trader t WITH(NOLOCK)
    LEFT JOIN dbo.Team tm WITH(NOLOCK) ON t.TeamId = tm.TeamId
    LEFT JOIN bodb02.dbo.vw_customer vc WITH(NOLOCK) ON t.CustId = vc.custid;
    -- #endregion

    -- #region Determine Date Ranges for Reportable Weeks
    IF OBJECT_ID('''tempdb..#tmpReportWeeks''') IS NOT NULL DROP TABLE #tmpReportWeeks;
    CREATE TABLE #tmpReportWeeks (
        YearWeekNumber  INT PRIMARY KEY,
        WeekStartDate   DATE,
        WeekEndDate     DATE,
        MonthOfMonday   INT
    );

    INSERT INTO #tmpReportWeeks (YearWeekNumber, WeekStartDate, WeekEndDate, MonthOfMonday)
    SELECT
        w.YearWeekNumber,
        fnw.WeekStartDate,
        fnw.WeekEndDate,
        MONTH(fnw.WeekStartDate) AS MonthOfMonday
    FROM #tmpSelectedYearWeeks w
    CROSS APPLY dbo.TGRS_FN_GetWeekDates(@Year, w.YearWeekNumber) fnw;
    -- #endregion

    -- #region Aggregate Daily Performance Data
    IF OBJECT_ID('''tempdb..#tmpAggregatedData''') IS NOT NULL DROP TABLE #tmpAggregatedData;
    CREATE TABLE #tmpAggregatedData (
        TraderID        INT,
        YearWeekNumber  INT,
        Turnover        MONEY,
        NetWinLoss      MONEY,
        BetCount        INT,
        MatchCount      INT,
        PRIMARY KEY (TraderID, YearWeekNumber)
    );

    INSERT INTO #tmpAggregatedData (TraderID, YearWeekNumber, Turnover, NetWinLoss, BetCount, MatchCount)
    SELECT
        tp.CustId AS TraderID,
        rw.YearWeekNumber,
        SUM(ISNULL(tp.Stake_Real, 0)) AS Turnover,
        SUM(ISNULL(tp.WinLost_Real, 0) - ISNULL(tp.Comm, 0)) AS NetWinLoss,
        SUM(ISNULL(tp.BetCount, 0)) AS BetCount,
        COUNT(DISTINCT tp.MatchId) AS MatchCount
    FROM dbo.TraderPerformance tp WITH(NOLOCK)
    INNER JOIN #tmpReportWeeks rw ON tp.EventDate BETWEEN rw.WeekStartDate AND rw.WeekEndDate
    WHERE EXISTS (SELECT 1 FROM #tmpTraderInfo ti WHERE ti.TraderID = tp.CustId) -- Ensure trader is in the selected trader pool
    GROUP BY
        tp.CustId,
        rw.YearWeekNumber;
    -- #endregion

    -- #region Final Output
    SELECT
        ti.TraderName,
        ti.Grade,
        ti.TeamName,
        ti.Department,
        @Year AS ReportYear,
        DATENAME(month, DATEFROMPARTS(@Year, rw.MonthOfMonday, 1)) + '-' + CAST(@Year AS VARCHAR(4)) AS MonthDisplayName,
        'Week ' + CAST(rw.YearWeekNumber AS VARCHAR(2)) AS WeekLabel,
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
    INNER JOIN #tmpReportWeeks rw ON rw.YearWeekNumber = agg.YearWeekNumber
    ORDER BY
        ti.TraderName,
        rw.MonthOfMonday,
        rw.YearWeekNumber;
    -- #endregion

    -- #region Cleanup Temp Tables
    IF OBJECT_ID('''tempdb..#tmpSelectedYearWeeks''') IS NOT NULL DROP TABLE #tmpSelectedYearWeeks;
    IF OBJECT_ID('''tempdb..#tmpTraderInfo''') IS NOT NULL DROP TABLE #tmpTraderInfo;
    IF OBJECT_ID('''tempdb..#tmpReportWeeks''') IS NOT NULL DROP TABLE #tmpReportWeeks;
    IF OBJECT_ID('''tempdb..#tmpAggregatedData''') IS NOT NULL DROP TABLE #tmpAggregatedData;
    -- #endregion

END;
GO 