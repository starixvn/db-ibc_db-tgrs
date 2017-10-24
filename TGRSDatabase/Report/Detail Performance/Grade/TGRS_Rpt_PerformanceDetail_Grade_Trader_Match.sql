USE [bodb_TGRS]
GO

/****** Object:  StoredProcedure [dbo].[TGRS_Rpt_PerformanceDetail_Grade_Trader_Match]    Script Date: 03/28/2016 16:22:27 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[TGRS_Rpt_PerformanceDetail_Grade_Trader_Match]  	
					@FromDate	DATE
				,	@ToDate		DATE
				,	@CustId		INT
				,	@Bettypes	VARCHAR(2000) =  '0'
AS    
/*  
	Created:	20160328@Aaron
	Task:		Detail report Grade Performance - Detail Match
	DB:			DBTGRS.bodb_TGRS
	Original:      
	  			
	Param's Explanation:  	
	
	Example: 
		EXEC [TGRS_Rpt_PerformanceDetail_Grade_Trader_Match] @FromDate = '2016-03-01', @ToDate= '2016-03-30', @Bettypes = '0', @CustID = 2457, @Grade = 1
  
*/  
 
BEGIN 
    SET NOCOUNT ON;

    DECLARE @BettypeList TABLE (BetType SMALLINT);
				
    IF @Bettypes <> '0'
	   INSERT INTO @BettypeList (BetType)
	   SELECT ssk.val
	   FROM	dbo.strSplit_Key(@Bettypes, ',') ssk;
    ELSE 
	    INSERT INTO @BettypeList (BetType)
	    SELECT bt.BetType 
    FROM	dbo.BetType AS bt WITH (NOLOCK);
	   
   SELECT P.MatchId, P.LeagueId, P.HomeId, P.AwayId, P.EventDate,
			ISNULL(SUM(P.Stake),0) AS Turnover, 
			ISNULL(SUM(P.WinLost),0) - ISNULL(SUM(P.Comm),0) AS WinLoss, 
			ISNULL(SUM(P.BetCount),0) as BetCount,
			CASE WHEN ISNULL(SUM(P.Stake),0) <> 0 THEN (ISNULL(SUM(P.WinLost),0)- ISNULL(SUM(P.Comm),0)) * 100/ISNULL(SUM(P.Stake),0) ELSE NULL END AS Margin	
	 FROM	dbo.TraderPerformance P WITH (NOLOCK)	 
	 WHERE	P.EventDate BETWEEN @FromDate AND @ToDate
			AND P.CustId = @CustId
			AND P.BetType IN (SELECT Bettype FROM @BettypeList)
	GROUP BY P.MatchId, P.LeagueId, P.HomeId, P.AwayId, P.EventDate			
	ORDER BY P.LeagueId ASC,Margin DESC, P.EventDate ASC
END;

/*
GO
GRANT EXECUTE ON [dbo].[TGRS_Rpt_PerformanceDetail_Grade_Trader_Match] TO [bodbTGRSNet]
GO
GRANT VIEW DEFINITION ON [dbo].[TGRS_Rpt_PerformanceDetail_Grade_Trader_Match] TO [bodbTGRSNet ]
GO
*/


GO

