
SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

/****** Object:  Stored Procedure dbo.Task_StagingOSDataTGRS    Script Date: 3/7/2017 3:10:47 PM ******/

CREATE PROCEDURE	[dbo].[Task_StagingOSDataTGRS]
	@Debug				BIT	= 0,
	@BeforeMoveBetsDay	BIT	= 1
AS    
/*  
	Created:	20160810@Long.Luu
	Task :		Staging Data for Other Sports on TGRS DB
	DB:			DBTGRS.bodb_TGRS
	Original:
  
	Revisions:  
				- 20170227@Aaron: Added MatchCount
				- 20170306@John: Change table OSDataTGRS
   		
	Param's Explanation:
		
	Exam:
	 
*/  
BEGIN
	SET NOCOUNT ON;

	DECLARE @Begin DATETIME = GETDATE(), @RowCount INT;

	DECLARE @BalanceUpDay SMALLDATETIME, @MoveBetsDay SMALLDATETIME, @Yesterday SMALLDATETIME;

	SELECT	@BalanceUpDay = MIN(winlostdate),
			@MoveBetsDay  = MAX(winlostdate),
			@Yesterday    = CONVERT(DATE,GETDATE()-1)
	FROM	bodb02.dbo.bettrans14 WITH(NOLOCK);

	IF @BeforeMoveBetsDay <> 1	
		SELECT @BalanceUpDay = @MoveBetsDay+1;

	IF @Debug = 1
		SELECT @BalanceUpDay AS BalanceUpDay, @MoveBetsDay AS MoveBetsDay, @Yesterday AS Yesterday;

	IF OBJECT_ID('tempdb..#tmpOSTrader') IS NOT NULL DROP TABLE #tmpOSTrader;

	CREATE TABLE #tmpOSTrader (
		CustId				INT 
		,matchid			INT
		,SportType			INT
		,EventDate			DATETIME
		,BetType			SMALLINT
		,OSTarget			DECIMAL(18,2)
		);

	TRUNCATE TABLE dbo.OSStagingDataTGRS;

	IF @BeforeMoveBetsDay = 1
	BEGIN
		INSERT INTO #tmpOSTrader(CustId,matchid,SportType,EventDate,BetType,OSTarget)
		SELECT DISTINCT  
			a.OperatorID AS CustId
			,m.matchid
			,m.sporttype AS SportType
			,m.EventDate
			,a.BetType AS BetType
			,dbo.f_GetOSTargetBySportLeagueBettype(m.sporttype, m.leagueid, a.bettype, m.eventdate) AS OSTarget
		FROM [bodb_archive].[dbo].[Dot_Admin_Assignment_Operator_bk] a WITH (NOLOCK)
			INNER JOIN bodb02.dbo.Match14 m WITH (NOLOCK) ON a.matchid=m.matchid
		WHERE	m.EventDate BETWEEN @BalanceUpDay AND @MoveBetsDay				
			AND a.OperatorType < 3
			AND m.MatchCode not like '%hedge%'
			AND m.sporttype <> 1
			AND (a.bettype < 31
				OR a.bettype BETWEEN 121 AND 999
				OR a.bettype BETWEEN 1301 and 1399)
			AND a.bettype NOT BETWEEN 801 AND 806 -- metric gaming
			AND a.bettype NOT IN (901, 902, 903) -- bettrade

		IF @Debug = 1
			SELECT 'Insert #[Dot_Admin_Assignment_Operator_bk]' Step, DATEDIFF(millisecond,@Begin,GETDATE()) Duration;
		 
		INSERT INTO [dbo].[OSStagingDataTGRS]
				   ([TraderId]
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

			SELECT	t.Custid
					,m.matchid
					,m.matchcode
					,t.EventDate 
					,t.SportType 
					,m.LeagueId 
					,b.BetType AS BetType				
					,SUM ((CASE WHEN b.modds = 0.25 OR b.modds = -0.25 THEN ABS(b.stake)/2 ELSE ABS(b.stake) END)*(1-b.tpositiontaking)*b.virtualrate) AS Turnover	--turn over
					,-SUM ((winlost - actual_stake + awinlost + mwinlost + swinlost) * b.virtualrate) AS WinLoss
					,SUM (scomm * b.virtualrate) AS Comm --Commission
					,SUM (1) AS BetCount		--Live BetCount				
					,t.OSTarget AS Target
			FROM	bodb02.dbo.bettrans14 b WITH (NOLOCK)
				INNER JOIN bodb02.dbo.match14 m WITH (NOLOCK)
					ON b.matchid = m.matchid
				INNER JOIN	#tmpOSTrader t --WITH (NOLOCK)
					ON m.matchid = t.matchid 
						AND	b.LiveIndicator = 1
			WHERE	b.statusID IN (112,113) 			
					AND b.Currency NOT IN (20,27,28)
			GROUP BY t.Custid
					,m.matchid
					,m.matchcode
					,t.EventDate 
					,t.SportType 
					,m.LeagueId
					,b.BetType
					,t.OSTarget;

		IF @Debug = 1
			SELECT 'Insert #bettrans14' Step, DATEDIFF(millisecond,@Begin,GETDATE()) Duration;
	END;

	TRUNCATE TABLE #tmpOSTrader;

	INSERT INTO #tmpOSTrader(CustId,matchid,SportType,EventDate,BetType,OSTarget)
	SELECT  DISTINCT  a.OperatorID AS CustId
			,m.matchid
			,m.sporttype as SportType
			,m.EventDate
			,a.BetType AS BetType
			,dbo.f_GetOSTargetBySportLeagueBettype(m.sporttype, m.leagueid, a.bettype, m.eventdate) AS OSTarget
	FROM bodb02.dbo.Dot_admin_Assignment_Operator a WITH (NOLOCK)
		INNER JOIN bodb02.dbo.Match m WITH (NOLOCK) ON a.matchid=m.matchid
	WHERE	m.EventDate BETWEEN @MoveBetsDay+1 AND @Yesterday
			AND m.EventStatus='completed'
			AND a.OperatorType < 3
			AND m.MatchCode not like '%hedge%'
			AND m.sporttype <> 1
			AND (a.bettype < 31
				OR a.bettype BETWEEN 121 AND 999
				OR a.bettype BETWEEN 1301 and 1399)
			AND a.bettype NOT BETWEEN 801 AND 806 -- metric gaming
			AND a.bettype NOT IN (901, 902, 903) -- bettrade

	IF @Debug = 1
		SELECT 'Insert #Dot_admin_Assignment_Operator' Step, DATEDIFF(millisecond,@Begin,GETDATE()) Duration;
 
	INSERT INTO [dbo].[OSStagingDataTGRS]
			   ([TraderId]
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

		SELECT	t.Custid
				,m.matchid
				,m.matchcode
				,t.EventDate 
				,t.SportType 
				,m.LeagueId
				,b.BetType			
				,SUM ((CASE WHEN b.modds = 0.25 OR b.modds = -0.25 THEN ABS(b.stake)/2 ELSE ABS(b.stake) END)*(1-b.tpositiontaking)*b.virtualrate) AS Turnover	--turn over
				,-SUM ((winlost - actual_stake + awinlost + mwinlost+ swinlost) * b.virtualrate) AS WinLoss	--Winloss
				,SUM (scomm * b.virtualrate) AS Comm --Commission
				,SUM (1) AS BetCount			--Live BetCount	
				,t.OSTarget AS Target
		FROM	bodb02.dbo.bettrans b WITH (NOLOCK)
			INNER JOIN bodb02.dbo.match m WITH (NOLOCK)
					ON b.matchid = m.matchid 		
			INNER JOIN	#tmpOSTrader t 
				ON m.matchid = t.matchid 
					AND	b.LiveIndicator = 1
		WHERE	b.statusID IN (112,113) 
				AND b.ruben = 1
				AND b.Currency NOT IN (20,27,28)
		GROUP BY t.Custid
				,m.matchid
				,m.matchcode
				,t.EventDate
				,t.SportType
				,m.LeagueId
				,b.BetType
				,t.OSTarget;

	IF @Debug = 1
		SELECT 'Insert #bettrans' Step, DATEDIFF(millisecond,@Begin,GETDATE()) Duration;

	IF OBJECT_ID('tempdb..#tmpOSTrader') IS NOT NULL DROP TABLE #tmpOSTrader;

	IF OBJECT_ID('tempdb..#tmpOSDataTGRS') IS NOT NULL DROP TABLE tmpOSDataTGRS;

	CREATE TABLE #tmpOSDataTGRS(
		[TraderId] [int] NULL,
		[MatchId] [int] NOT NULL,
		[MatchCode] NCHAR(100) NULL,
		[EventDate] [date] NULL,
		[SportId] [tinyint] NULL,
		[BettypeId] [smallint] NULL,
		[LeagueId] [int] NULL,
		[Stake] [money] NULL,
		[WinLost] [money] NULL,
		[Comm] [money] NULL,
		[BetCount] [int] NULL,
		[Target] [decimal] (18,2) NULL
	);  

	INSERT INTO #tmpOSDataTGRS(
			[TraderId]
			,[MatchId]
			,[MatchCode]
			,[EventDate]
			,[SportId]
			,[LeagueId]
			,[BettypeId]		
			,[Stake]
			,[WinLost]
			,[Comm]
			,[BetCount]
			,[Target]
			)

	SELECT  [TraderId]
			,[MatchId]
			,[MatchCode]
			,[EventDate]
			,[SportId]
			,[LeagueId]
			,[BettypeId]
			,FLOOR(SUM([Turnover])) [Stake]
			,FLOOR(SUM([WinLoss])) [WinLoss]
			,FLOOR(SUM([Comm])) [Comm]
			,FLOOR(SUM([BetCount])) [BetCount]
			,[Target]
	FROM  [dbo].OSDataTGRS  WITH(NOLOCK)
	WHERE [EventDate] BETWEEN @BalanceUpDay AND @Yesterday
	GROUP BY [TraderId]   
			,[MatchId]
			,[MatchCode]
			,[EventDate]
			,[SportId]     
			,[LeagueId]
			,[BettypeId]
			,[Target]

	SET @RowCount = @@ROWCOUNT;

	IF @Debug = 1
		SELECT 'Insert #OSDataTGRS' Step, DATEDIFF(millisecond,@Begin,GETDATE()) Duration,@RowCount  [RowCount];

	IF OBJECT_ID('tempdb..#tmpEventDate') IS NOT NULL    DROP TABLE #tmpEventDate;

	CREATE TABLE #tmpEventDate([EventDate] DATE);

	INSERT INTO #tmpEventDate([EventDate])
	SELECT [EventDate]
	FROM
		(
			SELECT [TraderId]
					,[MatchId]
					,[MatchCode]     
					,[EventDate]
					,[SportId]
					,[LeagueId]
					,[BettypeId]
					,[Target]
					,FLOOR(SUM([Turnover])) [Stake]
					,FLOOR(SUM([WinLoss])) [WinLoss]
					,FLOOR(SUM([Comm])) [Comm]
					,FLOOR(SUM([BetCount])) [BetCount]
			FROM  [dbo].OSStagingDataTGRS WITH(NOLOCK)
			GROUP BY [TraderId] 
					,[MatchId]
					,[MatchCode]   
					,[EventDate]
					,[SportId]
					,[LeagueId]
					,[BettypeId]
					,[Target]
			EXCEPT
			SELECT [TraderId]
					,[MatchId]
					,[MatchCode]
					,[EventDate]
					,[SportId]
					,[LeagueId]
					,[BettypeId]
					,[Target]
					,[Stake]
					,[WinLost]
					,[Comm]
					,[BetCount]
			FROM  #tmpOSDataTGRS
		)tmp
	GROUP BY [EventDate];

	SET @RowCount = @@ROWCOUNT;

	IF @Debug = 1
		SELECT 'Insert ##tmpEventDate EXCEPT OSStagingDataTGRS' Step, DATEDIFF(millisecond,@Begin,GETDATE()) Duration,@RowCount  [RowCount];

	INSERT INTO #tmpEventDate([EventDate])
	SELECT [EventDate]
	FROM
		(
			SELECT [TraderId]
					,[MatchId]
					,[MatchCode]
					,[EventDate]
					,[SportId]
					,[LeagueId]
					,[BettypeId]
					,[Target]
					,[Stake]
					,[WinLost]
					,[Comm]
					,[BetCount]
			FROM  #tmpOSDataTGRS
			EXCEPT
			SELECT [TraderId]     
					,[MatchId]
					,[MatchCode]
					,[EventDate]
					,[SportId]
					,[LeagueId]
					,[BettypeId]	
					,[Target]			
					,FLOOR(SUM([Turnover])) [Stake]
					,FLOOR(SUM([WinLoss])) [WinLoss]
					,FLOOR(SUM([Comm])) [Comm]
					,FLOOR(SUM([BetCount])) [BetCount]
			FROM  [dbo].OSStagingDataTGRS WITH(NOLOCK)
			GROUP BY [TraderId]   
					,[MatchId]
					,[MatchCode]  
					,[EventDate]
					,[SportId]      
					,[LeagueId]
					,[BettypeId]
					,[Target]
		)tmp
	GROUP BY [EventDate];

	SET @RowCount = @@ROWCOUNT;

	IF @Debug = 1
		SELECT 'Insert ##tmpEventDate EXCEPT Staging' Step, DATEDIFF(millisecond,@Begin,GETDATE()) Duration,@RowCount  [RowCount];

	IF OBJECT_ID('tempdb..##tmpOSDataTGRS') IS NOT NULL DROP TABLE #tmpOSDataTGRS;

	DELETE	FROM  [dbo].OSStagingDataTGRS 
	WHERE [EventDate] NOT IN(SELECT [EventDate] FROM #tmpEventDate WHERE [EventDate] IS NOT  NULL);

	SET @RowCount = @@ROWCOUNT;

	IF @Debug = 1
		SELECT 'DELETE OSStagingDataTGRS' Step, DATEDIFF(millisecond,@Begin,GETDATE()) Duration,@RowCount  [RowCount];

	IF @Debug = 1
		SELECT * FROM #tmpEventDate;
	IF OBJECT_ID('tempdb..#tmpEventDate') IS NOT NULL    DROP TABLE #tmpEventDate;

END;



GO

SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO


GO 
