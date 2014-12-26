-----1. TABLE [dbo].[SummaryByBetType_Daily] TO SummaryByBetType_Daily_BK
-----2. TABLE [dbo].[SummaryByBetType_Monthly] TO SummaryByBetType_Monthly_BK
-----3. TABLE [dbo].[SummaryByLeague_Daily] TO SummaryByLeague_Daily_BK
-----4. TABLE [dbo].[SummaryByLeague_Monthly] TO SummaryByLeague_Monthly_BK
-----5. TABLE [dbo].[SummaryByTeam_Daily] TO SummaryByTeam_Daily_BK
-----6. TABLE [dbo].[SummaryByTeam_Monthly] TO SummaryByTeam_Monthly_BK
-----7. TABLE [dbo].[SummaryByTrader_Monthly] TO SummaryByTrader_Monthly_BK

DECLARE @WorkShift TINYINT
SET @WorkShift = 3

---1.
INSERT INTO SummaryByBetType_Daily  (
		EventDate,
		LeagueId,
		WorkShift,
		BetType,
		Stake,
		WinLost,
		Comm,
		BetCount,
		MatchCount
		)
SELECT	EventDate,
		LeagueId,
		@WorkShift ,
		BetType,
		Stake,
		WinLost,
		Comm,
		BetCount,
		MatchCount
FROM	dbo.SummaryByBetType_Daily_BK 

-----2.
INSERT INTO SummaryByBetType_Monthly(
		EventDate,
		LeagueId,
		WorkShift,
		BetType,
		Stake,
		WinLost,
		Comm,
		BetCount,
		MatchCount)
SELECT	EventDate,
		LeagueId,
		@WorkShift,
		BetType,
		Stake,
		WinLost,
		Comm,
		BetCount,
		MatchCount
FROM    dbo.SummaryByBetType_Monthly_BK


-----3. 
INSERT INTO SummaryByLeague_Daily (
		EventDate,
		LeagueId,
		WorkShift,
		Stake,
		WinLost,
		Comm,
		BetCount,
		MatchCount)
SELECT  EventDate,
		LeagueId,
		@WorkShift,
		Stake,
		WinLost,
		Comm,
		BetCount,
		MatchCount
FROM	dbo.SummaryByLeague_Daily_BK 

-----4. TABLE [dbo].[SummaryByLeague_Monthly] TO SummaryByLeague_Monthly_BK

INSERT INTO SummaryByLeague_Monthly (
		EventDate,
		LeagueId,
		WorkShift,
		Stake,
		WinLost,
		Comm,
		BetCount,
		MatchCount)

SELECT	EventDate,
		LeagueId,
		@WorkShift,
		Stake,
		WinLost,
		Comm,
		BetCount,
		MatchCount
FROM	dbo.SummaryByLeague_Monthly_BK


-----5. TABLE [dbo].[SummaryByTeam_Daily] TO SummaryByTeam_Daily_BK
INSERT INTO SummaryByTeam_Daily (
		EventDate,
		TeamId,
		WorkShift,
		Stake,
		WinLost,
		Comm,
		BetCount,
		MatchCount
		)
SELECT	EventDate,
		TeamId,
		@WorkShift,
		Stake,
		WinLost,
		Comm,
		BetCount,
		MatchCount
FROM	dbo.SummaryByTeam_Daily_BK


-----6. TABLE [dbo].[SummaryByTeam_Monthly] TO SummaryByTeam_Monthly_BK
INSERT INTO SummaryByTeam_Monthly (
		EventDate,
		TeamId,
		WorkShift,
		Stake,
		WinLost,
		Comm,
		BetCount,
		MatchCount)
SELECT  EventDate,
		TeamId,
		@WorkShift,
		Stake,
		WinLost,
		Comm,
		BetCount,
		MatchCount
FROM    dbo.SummaryByTeam_Monthly_BK


-----7. TABLE [dbo].[SummaryByTrader_Monthly] TO SummaryByTrader_Monthly_BK
INSERT INTO SummaryByTrader_Monthly (
		Eventdate,
		CustId,
		WorkShift,
		Stake,
		WinLost,
		Comm,
		BetCount,
		MatchCount)
SELECT  Eventdate,
		CustId,
		@WorkShift,
		Stake,
		WinLost,
		Comm,
		BetCount,
		MatchCount
FROM	dbo.SummaryByTrader_Monthly_BK