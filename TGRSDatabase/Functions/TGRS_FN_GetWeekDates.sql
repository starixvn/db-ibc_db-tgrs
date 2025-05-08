/*<info serverAlias="DBTGRS-bodb_TGRS" executers="bodbTGRSNet" viewers="bodbTGRSNet" isFunction="1" isNested="1"></info>*/

CREATE FUNCTION [dbo].[TGRS_FN_GetWeekDates]
(
    @IsoYear INT,
    @IsoWeek INT
)
RETURNS TABLE
AS
/*
    Created:    20250507@Jaden.Tang
    Task:       Provide Start Date (Monday) and End Date (Sunday) for a given ISO Year and ISO Week.
                ISO 8601 weeks start on Monday. Week 1 is the week containing the first Thursday of the year (or Jan 4th).
                This function is DATEFIRST-agnostic.
    DB:         DBTGRS.bodb_TGRS
    Original:   N/A

    Revisions:
                - 20250507@Jaden.Tang: Create New
*/
RETURN
(
    WITH InitialDates AS (
        -- Jan 4th of the given ISO year is always in ISO Week 1
        SELECT
            DATEFROMPARTS(@IsoYear, 1, 4) AS Jan4th
    ),
    WeekCalculations AS (
        SELECT
            id.Jan4th,
            -- Calculate Day of Week for Jan4th (1=Monday, 2=Tuesday, ..., 7=Sunday)
            -- This formula is DATEFIRST-agnostic. DATEPART(weekday, date) returns 1 for Sunday, 2 for Monday, etc.
            (DATEPART(weekday, id.Jan4th) + 5) % 7 + 1 AS DayOfWeekJan4th_MonIs1
        FROM InitialDates id
    ),
    StartOfFirstIsoWeek AS (
        SELECT
            -- Calculate the Monday of the week that Jan4th falls into. This is the start of ISO Week 1.
            DATEADD(day, 1 - wc.DayOfWeekJan4th_MonIs1, wc.Jan4th) AS MondayOfFirstIsoWeek
        FROM WeekCalculations wc
    )
    SELECT
        -- Add (@IsoWeek - 1) weeks to the start of ISO Week 1 to get the start of the target ISO week.
        DATEADD(week, @IsoWeek - 1, sfiw.MondayOfFirstIsoWeek) AS WeekStartDate,
        -- The end of the week is 6 days after the start of the week.
        DATEADD(day, 6, DATEADD(week, @IsoWeek - 1, sfiw.MondayOfFirstIsoWeek)) AS WeekEndDate
    FROM StartOfFirstIsoWeek sfiw
)
GO

/*
Example Usage:
-- Ensure database context is correct if not already in bodb_TGRS
-- USE bodb_TGRS;
-- GO

SELECT * FROM dbo.TGRS_FN_GetWeekDates(2025, 1); -- Expected: 2024-12-30 to 2025-01-05
SELECT * FROM dbo.TGRS_FN_GetWeekDates(2025, 5); -- Expected: 2025-01-27 to 2025-02-02
SELECT * FROM dbo.TGRS_FN_GetWeekDates(2026, 1); -- Expected: 2025-12-29 to 2026-01-04
SELECT * FROM dbo.TGRS_FN_GetWeekDates(2024, 52); -- Expected: 2024-12-23 to 2024-12-29
SELECT * FROM dbo.TGRS_FN_GetWeekDates(2010, 1); -- Expected: 2010-01-04 to 2010-01-10
SELECT * FROM dbo.TGRS_FN_GetWeekDates(2009, 53); -- Expected: 2009-12-28 to 2010-01-03
*/ 