ALTER PROCEDURE [dbo].[TGRS_Rpt_ScoreDetail]
	@FromDate DATE
	,@ToDate DATE
	,@CustId INT
	,@MatchId INT
	,@Bettypes VARCHAR(200) = '0'

AS    
/*  
 Created:	20140725@Sophia
 Task :		Detail report Team Performance - Detail Bettype 
 DB:		DBTGRS.bodb_TGRS
 Original:  
  
 Revisions:      
   			
 Param's Explanation:  	

 Exam: 
	EXEC [TGRS_Rpt_ScoreDetail]  @FromDate='2014-11-23 00:00:00', @CustId=4244272,@Bettypes='0',@MatchId=11146182,@ToDate='2014-12-07 00:00:00' 
	   
*/  
 
BEGIN 
	SET NOCOUNT ON  
	
	DECLARE @Detail AS TABLE (LeagueId INT, BetType SMALLINT, WorkShift TINYINT, Benchmark MONEY, ModifiedDate DATE, Margin MONEY ,FromDate DATE, ToDate DATE)
	DECLARE @BenchMark AS TABLE (LeagueId INT, BetType SMALLINT, WorkShift TINYINT, Benchmark MONEY)	

	DECLARE @BettypeList AS TABLE (bettype SMALLINT)
	 IF @Bettypes <> '0'
		 INSERT INTO @BettypeList
		 SELECT val FROM dbo.strSplit_Key(@Bettypes,',')
	 ELSE 
		 INSERT INTO @BettypeList
		 SELECT Bettype FROM dbo.Bettype WITH (NOLOCK)


	 --- Get Setting Period
	DECLARE 
		 @BeginDay VARCHAR(20)
		,@EndDay VARCHAR(20)
		,@SelectedDay VARCHAR(20)
		,@DateB DATE
		,@DateE DATE
		,@D1 DATE
		,@D2 DATE
			
		,@i INT
		,@M INT
		,@P1 INT
		,@P2 INT
			 

	DECLARE @Period AS TABLE (PointDate DATE)
	DECLARE @CurPeriod AS TABLE (ID INT IDENTITY (1,1), PointDate DATE)

	SELECT @BeginDay = STUFF(CONVERT(VARCHAR(20),VValue,120),1,5,'') 	  							 		
	FROM   dbo.SystemSettings WITH (NOLOCK)							
	WHERE  VNAme = 'BeginDay'

	SELECT @EndDay = STUFF(CONVERT(VARCHAR(20),VValue,120),1,5,'') 	  							 		
	FROM   dbo.SystemSettings WITH (NOLOCK)							
	WHERE  VNAme = 'EndDay'

	SELECT @SelectedDay = STUFF(CONVERT(VARCHAR(20),VValue,120),1,5,'') 	  							 		
	FROM   dbo.SystemSettings WITH (NOLOCK)							
	WHERE  VNAme = 'SelectedDay'
	
	-----------------------------------------------

	SELECT @P1 = CONVERT(VARCHAR(4),YEAR(@FromDate) - 1) 
	SELECT @P2 = CONVERT(VARCHAR(4),YEAR(@ToDate) + 1) 
	 
	SELECT @i = @P1	
	WHILE (@i <= @P2)
	BEGIN 		
		INSERT INTO @Period (PointDate)
		SELECT CONVERT(VARCHAR(4),@i) + '-' + @BeginDay

		INSERT INTO @Period (PointDate)
		SELECT DATEADD (DD, 1, CONVERT(DATE, (CONVERT(VARCHAR(4),@i) + '-' + @SelectedDay)))

		--INSERT INTO @Period (PointDate)
		--SELECT CONVERT(VARCHAR(4),@i) + '-' + @EndDay

		SELECT @i = @i + 1
	END 


	SELECT  @D1 = MAX (PointDate)
	FROM	@Period
	WHERE   PointDate < = @FromDate 
	
	SELECT  @D2 = MIN (PointDate)
	FROM	@Period
	WHERE   PointDate >= @ToDate 

	DELETE @Period 
	WHERE  PointDate NOT BETWEEN @D1 AND @D2


	---- Insert
	INSERT INTO @CurPeriod (PointDate)
	SELECT PointDate 
	FROM @Period
	ORDER BY PointDate ASC

	SELECT	@M = MAX(ID) 
	FROM	@CurPeriod	
	 
	 
	-----------------------------------------------
	 

	SELECT	@i = 1
	WHILE	(@i < @M)
	BEGIN 
		SELECT	@DateB = PointDate
		FROM	@CurPeriod
		WHERE	ID = @i

		SELECT	@DateE = DATEADD (DD, -1 ,PointDate)
		FROM	@CurPeriod
		WHERE	ID = @i + 1

		DELETE  @BenchMark

		INSERT	INTO @BenchMark
		SELECT	B.LeagueId, B.BetType, B.WorkShift, B.Benchmark		
		FROM	dbo.Benchmark_BetType_History B WITH (NOLOCK)
		INNER JOIN (
						SELECT MAX(ModifiedDate) AS ModifiedDate, LeagueId, BetType, WorkShift
						FROM ( 
								SELECT MAX(ModifiedDate) AS ModifiedDate, B.LeagueId, B.BetType, B.WorkShift 
								FROM   dbo.Benchmark_BetType_History B WITH (NOLOCK)		
								WHERE  B.ModifiedDate BETWEEN @DateB AND @DateE
									   AND B.Bettype IN (SELECT Bettype FROM @BettypeList)	
								GROUP BY  B.LeagueId, B.BetType, B.WorkShift
								UNION 
								SELECT MAX(ModifiedDate) AS ModifiedDate, B.LeagueId, B.BetType, B.WorkShift
								FROM   dbo.Benchmark_BetType_History B WITH (NOLOCK)		
								WHERE  B.ModifiedDate < @DateB
									   AND B.Bettype IN (SELECT Bettype FROM @BettypeList)	
								GROUP BY  B.LeagueId, B.BetType, B.WorkShift	
								) B
						GROUP BY  B.LeagueId, B.BetType, B.WorkShift	
					) M
			ON  M.LeagueId = B.LeagueId
				AND M.BetType = B.BetType
				AND M.WorkShift = B.WorkShift
				AND M.ModifiedDate = B.ModifiedDate
			WHERE 	M.Bettype IN (SELECT Bettype FROM @BettypeList)	
			

		INSERT INTO @Detail (LeagueId, BetType, WorkShift, Benchmark, Margin, FromDate, ToDate)	 	
		SELECT  P.LeagueId, P.BetType, P.WorkShift,  
				CASE WHEN B.Benchmark IS NOT NULL THEN B.Benchmark ELSE NULL END AS Benchmark,	
				(CASE WHEN ISNULL(SUM(P.Stake),0) <> 0 THEN ((ISNULL(SUM(P.WinLost),0) - ISNULL(SUM(P.Comm),0)) * 100/ ISNULL(SUM(P.Stake),0))  ELSE NULL END) AS Margin,
				@DateB, @DateE
		FROM	TraderPerformance P WITH (NOLOCK)
		LEFT JOIN @BenchMark B  
				ON B.LeagueId = P.LeagueId
					AND B.BetType = P.BetType 
					AND B.WorkShift = P.WorkShift
		WHERE   P.EventDate BETWEEN @FromDate AND @ToDate
				AND P.EventDate BETWEEN @DateB AND @DateE
				AND P.CustId = @CustId
				AND P.MatchId = @MatchId	
				AND P.Bettype IN (SELECT Bettype FROM @BettypeList)	
		GROUP BY  P.LeagueId, P.BetType, P.WorkShift, B.Benchmark

		 
		SELECT @i = @i + 1
	END		
			  
	 
	----------------------------------------------
	SELECT	BetType, FromDate, ToDate, CASE WHEN SUM(ISNULL(Benchmark,0)) <> 0 THEN SUM(Margin) * 50 / SUM(Benchmark) ELSE 0 END AS Score
	FROM	@Detail
	GROUP BY BetType, FromDate, ToDate
	ORDER BY FromDate

		 

END 
GO
GRANT EXECUTE ON [dbo].[TGRS_Rpt_ScoreDetail] TO [bodbTGRSNet]
GO

