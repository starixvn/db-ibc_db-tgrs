
/****** Object:  Stored Procedure dbo.TGRS_Rpt_NewPerformanceDetail_Trader_Match    Script Date: 1/17/2017 11:20:01 AM ******/

/****** Object:  StoredProcedure [dbo].[TGRS_Rpt_NewPerformanceDetail_Trader_Match]    Script Date: 01/06/2017 13:22:33 ******/
CREATE PROCEDURE [dbo].[TGRS_Rpt_NewPerformanceDetail_Trader_Match] 
	@FromDate DATE
	,@ToDate DATE
	,@CustId INT
	,@Bettypes VARCHAR(200) = '1,3,7,8'
AS
/*  
    Created:    20170106@Long.Luu
    Task:       New Performance Detail Report - Trader - Match
    DB:         DBTGRS.bodb_TGRS
    Original:      
                
	Revisions:       
		- 20170316@Long: apply TO's Leftover
		- 20171205@Simon: get only Live data & Bettypes are not disabled
		
    Param's ExplanatiON:      
    
    Example: 
                EXECUTE [TGRS_Rpt_NewPerformanceDetail_Trader_Match] 
					@FromDate = '2014-01-01', 
					@ToDate= '2014-12-30',
					@CustID = 1530768  
*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @BettypeList AS TABLE (bettype SMALLINT);

	IF @Bettypes <> '0'
		INSERT INTO @BettypeList (bettype)
		SELECT bt.BetType
		FROM dbo.strSplit_Key(@Bettypes, ',') ssk			
			INNER JOIN dbo.BetType bt WITH (NOLOCK) ON bt.MainDBBetType = ssk.val;
	ELSE
		INSERT INTO @BettypeList (bettype)
		SELECT bt.BetType
		FROM dbo.BetType AS bt WITH (NOLOCK)
		WHERE bt.MainDBBetType IN (1,3,7,8);

	SELECT tp.MatchId
		,tp.LeagueId
		,tp.HomeId
		,tp.AwayId
		,tp.EventDate
		,ISNULL(SUM(tp.StakeMYR), 0) AS Turnover
		,ISNULL(SUM(tp.StakeMYRJuice), 0) AS TurnoverJuice
		,ISNULL(SUM(tp.Juice), 0) AS Juice
		,ISNULL(SUM(tp.WinLost), 0) - ISNULL(SUM(tp.Comm), 0) AS WinLoss
		,ISNULL(SUM(BetCount), 0) AS BetCount
	FROM dbo.TraderPerformance tp WITH (NOLOCK)
	WHERE tp.EventDate BETWEEN @FromDate
			AND @ToDate
		AND tp.CustId = @CustId
		AND tp.Bettype IN (
			SELECT bettype
			FROM @BettypeList
			)
		AND tp.IsLive = 1
	GROUP BY tp.MatchId
		,tp.LeagueId
		,tp.HomeId
		,tp.AwayId
		,tp.EventDate;
END

/*
GO
GRANT EXECUTE ON [dbo].[TGRS_Rpt_NewPerformanceDetail_Trader_Match] TO [bodbTGRSNet]
GO
GRANT VIEW DEFINITION ON [dbo].[TGRS_Rpt_NewPerformanceDetail_Trader_Match] TO [bodbTGRSNet]
GO
*/