
SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

/****** Object:  Stored Procedure dbo.Task_StagingOSDataTGRS_Regenerate    Script Date: 3/7/2017 3:10:48 PM ******/


CREATE PROCEDURE [dbo].[Task_StagingOSDataTGRS_Regenerate] 
	 @FromDate DATE
	,@ToDate DATE
AS
BEGIN
	SET NOCOUNT ON;

	IF OBJECT_ID('tempdb..#tmpOSTrader') IS NOT NULL
		DROP TABLE #tmpOSTrader;

	CREATE TABLE #tmpOSTrader (
		CustId INT
		,matchid INT
		,SportType INT
		,EventDate DATETIME
		,BetType SMALLINT
		,OSTarget DECIMAL(18, 2)
		);

	TRUNCATE TABLE dbo.OSStagingDataTGRS;

	INSERT INTO #tmpOSTrader (
		CustId
		,matchid
		,SportType
		,EventDate
		,BetType
		,OSTarget
		)
	SELECT DISTINCT a.OperatorID AS CustId
		,m.matchid
		,m.sporttype AS SportType
		,m.EventDate
		,a.BetType AS BetType
		,dbo.f_GetOSTargetBySportLeagueBettype(m.sporttype, m.leagueid, a.bettype, m.eventdate) AS OSTarget
	FROM [bodb_archive].[dbo].[Dot_Admin_Assignment_Operator_bk] a WITH (NOLOCK)
	INNER JOIN [bodb_archive].[dbo].match_bk m WITH (NOLOCK) ON a.matchid = m.matchid
	WHERE m.EventDate BETWEEN @FromDate
			AND @ToDate
		AND a.OperatorType < 3
		AND m.MatchCode NOT LIKE '%hedge%'
		AND m.sporttype <> 1
		AND (
			a.bettype < 31
			OR a.bettype BETWEEN 121
				AND 999
			OR a.bettype BETWEEN 1301
				AND 1399
			)
		AND a.bettype NOT BETWEEN 801
			AND 806 -- metric gaming
		AND a.bettype NOT IN (
			901
			,902
			,903
			) -- bettrade

	INSERT INTO [dbo].OSStagingDataTGRS (
		[TraderId]
		,[MatchId]
		,[MatchCode]
		,[EventDate]
		,[SportId]
		,[LeagueId]
		,[BettypeId]
		,[Turnover]
		,[WinLoss]
		,[Comm]
		,[BetCount]
		,[Target]
		)
	SELECT t.Custid
		,m.matchid
		,m.matchcode
		,t.EventDate
		,t.SportType
		,m.LeagueId
		,b.BetType AS BetType
		,SUM((
				CASE 
					WHEN b.modds = 0.25
						OR b.modds = - 0.25
						THEN ABS(b.stake) / 2
					ELSE ABS(b.stake)
					END
				) * (1 - b.tpositiontaking) * b.virtualrate) AS Turnover --turn over
		,- SUM((winlost - actual_stake + awinlost + mwinlost + swinlost) * b.virtualrate) AS WinLoss
		,SUM(scomm * b.virtualrate) AS Comm --Commission
		,SUM(1) AS BetCount --Live BetCount				
		,t.OSTarget AS Target
	FROM [bodb_archive].[dbo].bettrans_bk b WITH (NOLOCK)
	INNER JOIN [bodb_archive].[dbo].match_bk m WITH (NOLOCK) ON b.matchid = m.matchid
	INNER JOIN #tmpOSTrader t --WITH (NOLOCK)
		ON m.matchid = t.matchid
		AND b.LiveIndicator = 1
	WHERE b.statusID IN (
			112
			,113
			)
		AND b.Currency NOT IN (
			20
			,27
			,28
			)
	GROUP BY t.Custid
		,m.matchid
		,m.matchcode
		,t.EventDate
		,t.SportType
		,m.LeagueId
		,b.BetType
		,t.OSTarget;
		
	DROP TABLE #tmpOSTrader;		
END;


GO

SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO


GO 
