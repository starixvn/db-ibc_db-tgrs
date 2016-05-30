--DB06

/*  
 Created:	20141202@Tom.Vo
 Task :		GeneralDataFromDW Archive
 DB:		DBPRO.bodb_TGRS
 Original:  
  
 Revisions:      
   			
 Param's Explanation:  
	 
 Exam: 

	 
*/

IF @@SERVERNAME NOT IN ('DB06', 'DBPRO','DB215')
BEGIN
	SELECT 1000 ErrCode
		,'Wrong Server Name' ErrorMsg

	RETURN
END

USE [bodb_TGRS]
GO

SET NOCOUNT ON

DECLARE @fromdate datetime,@todate datetime

SELECT @fromdate ='2014-01-01 00:00:00'
	,@todate =CONVERT(NVARCHAR(20),GETDATE(),101)
 
DELETE [dbo].[SummaryByBetType_Daily]	WHERE EventDate BETWEEN @fromdate AND @todate 

INSERT INTO [dbo].[SummaryByBetType_Daily]
	([EventDate]
		,[LeagueId]
		,[BetType]
		,WorkShift
		,[Stake]
		,[WinLost]
		,[Comm]
		,[BetCount]
		,[MatchCount]
	)
SELECT [EventDate]
		,[LeagueId]
		,[BetType]
		,WorkShift
		,SUM([Stake]) [Stake]
		,SUM([WinLost]) [WinLost]
		,SUM([Comm]) [Comm]
		,SUM([BetCount]) BetCount
		,COUNT(DISTINCT [MatchId])[MatchCount]
	FROM [dbo].[TraderPerformance] WITH(NOLOCK)
	WHERE EventDate BETWEEN @fromdate AND @todate 
	GROUP BY [EventDate],
		[LeagueId],
		[BetType]
		,WorkShift

DELETE [dbo].[SummaryByLeague_Daily]	WHERE EventDate BETWEEN @fromdate AND @todate 

INSERT INTO [dbo].[SummaryByLeague_Daily]
	([EventDate]
		,[LeagueId]
		,WorkShift
		,[Stake]
		,[WinLost]
		,[Comm]
		,[BetCount]
		,[MatchCount]
	)
SELECT [EventDate]
		,[LeagueId]
		,WorkShift
		,SUM([Stake]) [Stake]
		,SUM([WinLost]) [WinLost]
		,SUM([Comm]) [Comm]
		,SUM([BetCount]) BetCount
		,COUNT(DISTINCT [MatchId])[MatchCount]
	FROM [dbo].[TraderPerformance] WITH(NOLOCK)
	WHERE EventDate BETWEEN @fromdate AND @todate 
	GROUP BY [EventDate],[LeagueId],WorkShift

DELETE [dbo].[SummaryByTeam_Daily]	WHERE EventDate BETWEEN @fromdate AND @todate 

INSERT INTO [dbo].[SummaryByTeam_Daily]
	([EventDate]
		,[TeamId]
		,WorkShift
		,[Stake]
		,[WinLost]
		,[Comm]
		,[BetCount]
		,[MatchCount]
	)
SELECT [EventDate]
		,[TeamId]
		,WorkShift
		,SUM([Stake]) [Stake]
		,SUM([WinLost]) [WinLost]
		,SUM([Comm]) [Comm]
		,SUM([BetCount]) BetCount
		,COUNT(DISTINCT [MatchId])[MatchCount]
	FROM [dbo].[TraderPerformance] WITH(NOLOCK)
	WHERE EventDate BETWEEN @fromdate AND @todate 
	GROUP BY [EventDate],[TeamId],WorkShift
