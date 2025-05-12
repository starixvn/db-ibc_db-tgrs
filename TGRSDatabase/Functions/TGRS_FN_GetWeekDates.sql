/*<info serverAlias="DBTGRS-bodb_TGRS" viewers="wsv_tgrs" isFunction="1" isNested="1"></info>*/

ALTER FUNCTION [dbo].[TGRS_FN_GetWeekDates]
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
    WITH Anchor AS (
        -- January 4th is always in the first ISO week
        SELECT DATEFROMPARTS(@IsoYear, 1, 4) AS Jan4
    ),
    DayOfWeekCalc AS (
        SELECT 
            Jan4,
            -- Get the day of week for Jan 4th (0 = Sunday, 1 = Monday, ..., 6 = Saturday)
            -- This formula is DATEFIRST-independent
            (DATEDIFF(DAY, CAST('17530101' AS DATE), Jan4) + 1) % 7 AS DOW
        FROM Anchor
    ),
    FirstWeekStart AS (
        SELECT 
            -- Calculate Monday of the week containing Jan 4th
            -- If DOW=1 (Monday), then Jan4 is already the Monday of week 1
            -- If DOW=0 (Sunday), then go back 6 days to find Monday
            -- If DOW=2 (Tuesday), then go back 1 day, etc.
            DATEADD(DAY, 
                CASE
                    WHEN DOW = 0 THEN -6  -- Sunday, go back 6 days
                    WHEN DOW = 1 THEN 0   -- Monday, stay here
                    ELSE -(DOW - 1)       -- Other days, go back to Monday
                END,
            Jan4) AS WeekOneStart
        FROM DayOfWeekCalc
    )
    SELECT 
        DATEADD(WEEK, @IsoWeek - 1, WeekOneStart) AS WeekStartDate,
        DATEADD(DAY, 6, DATEADD(WEEK, @IsoWeek - 1, WeekOneStart)) AS WeekEndDate
    FROM FirstWeekStart
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