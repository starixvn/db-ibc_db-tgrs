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
	
DECLARE @fromdate DATE,@todate DATE

SELECT @fromdate ='2014-01-01 00:00:00'
	,@todate =CONVERT(NVARCHAR(20),GETDATE(),101)
 
DELETE [dbo].[SummaryByTrader_Monthly] WHERE EventDate BETWEEN @fromdate AND @todate

INSERT INTO [dbo].[SummaryByTrader_Monthly](
	[Eventdate]
		,[CustId]
		,WorkShift
		,[Stake]
		,[WinLost]
		,[Comm]
		,[BetCount]
		,[MatchCount]
		)
SELECT CONVERT(NVARCHAR(10),YEAR([Eventdate])) + '/'+CONVERT(NVARCHAR(10),MONTH([Eventdate])) + '/01' [Eventdate]
		,[CustId]
		,WorkShift
		,SUM([Stake]) [Stake]
		,SUM([WinLost]) [WinLost]
		,SUM([Comm]) [Comm]
		,SUM([BetCount]) [BetCount]
		,COUNT(DISTINCT [MatchId])[MatchCount]
	FROM [dbo].[TraderPerformance] WITH(NOLOCK)
	WHERE EventDate BETWEEN @fromdate AND @todate
	GROUP BY CONVERT(NVARCHAR(10),YEAR([Eventdate])) + '/'+CONVERT(NVARCHAR(10),MONTH([Eventdate])) + '/01' ,[CustId],WorkShift

DELETE [dbo].[SummaryByBetType_Monthly]	WHERE EventDate BETWEEN @fromdate AND @todate

INSERT INTO [dbo].[SummaryByBetType_Monthly]
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
SELECT CONVERT(NVARCHAR(10),YEAR([Eventdate])) + '/'+CONVERT(NVARCHAR(10),MONTH([Eventdate]))+ '/01' [EventDate]
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
	GROUP BY CONVERT(NVARCHAR(10),YEAR([Eventdate])) + '/'+CONVERT(NVARCHAR(10),MONTH([Eventdate])) + '/01',[LeagueId],WorkShift
	,[BetType]

DELETE [dbo].SummaryByLeague_Monthly	WHERE EventDate BETWEEN @fromdate AND @todate

INSERT INTO [dbo].SummaryByLeague_Monthly
	([EventDate]
		,[LeagueId]
		,WorkShift
		,[Stake]
		,[WinLost]
		,[Comm]
		,[BetCount]
		,[MatchCount]
	)
SELECT CONVERT(NVARCHAR(10),YEAR([Eventdate])) + '/'+CONVERT(NVARCHAR(10),MONTH([Eventdate])) + '/01' [EventDate]
		,[LeagueId]
		,WorkShift
		,SUM([Stake]) [Stake]
		,SUM([WinLost]) [WinLost]
		,SUM([Comm]) [Comm]
		,SUM([BetCount]) BetCount
		,COUNT(DISTINCT [MatchId])[MatchCount]
	FROM [dbo].[TraderPerformance] WITH(NOLOCK)
	WHERE EventDate BETWEEN @fromdate AND @todate
	GROUP BY CONVERT(NVARCHAR(10),YEAR([Eventdate])) + '/'+CONVERT(NVARCHAR(10),MONTH([Eventdate])) + '/01',[LeagueId],WorkShift

DELETE [dbo].SummaryByTeam_Monthly	WHERE EventDate BETWEEN @fromdate AND @todate

INSERT INTO [dbo].SummaryByTeam_Monthly
	([EventDate]
	,[TeamId]
	,WorkShift
	,[Stake]
	,[WinLost]
	,[Comm]
	,[BetCount]
	,[MatchCount]
	)
SELECT CONVERT(NVARCHAR(10),YEAR([Eventdate])) + '/'+CONVERT(NVARCHAR(10),MONTH([Eventdate])) + '/01' [EventDate]
		,[TeamId]
		,WorkShift
		,SUM([Stake]) [Stake]
		,SUM([WinLost]) [WinLost]
		,SUM([Comm]) [Comm]
		,SUM([BetCount]) BetCount
		,COUNT(DISTINCT [MatchId])[MatchCount]
	FROM [dbo].[TraderPerformance] WITH(NOLOCK)
	WHERE EventDate BETWEEN @fromdate AND @todate
	GROUP BY CONVERT(NVARCHAR(10),YEAR([Eventdate])) + '/'+CONVERT(NVARCHAR(10),MONTH([Eventdate])) + '/01',[TeamId],WorkShift