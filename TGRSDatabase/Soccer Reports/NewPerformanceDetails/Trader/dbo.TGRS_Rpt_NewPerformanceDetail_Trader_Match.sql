ALTER PROCEDURE [dbo].[TGRS_Rpt_NewPerformanceDetail_Trader_Match] 
		@FromDate			DATE
	,	@ToDate				DATE
	,	@CustId				INT
	,	@Bettypes			VARCHAR(200) = '1,3,7,8'
	,	@IsExcludeLeagues	BIT = 1
	,	@Market				SMALLINT = 1
AS
/*  
    Created:    20170106@Long.Luu
    Task:       New Performance Detail Report - Trader - Match
    DB:         DBTGRS.bodb_TGRS
    Original:      
                
	Revisions:       
		- 20170316@Long.Luu:	apply TO's Leftover
		- 20171205@Simon:		get only Live data & Bettypes are not disabled
		- 20180912@Simon:		add league exclusion
		- 20190919@Long.Luu:	Support Nonlive Data [Redmine ID: 118959]
		- 20191023@John.Ngo:	Enhance performance [Redmine ID: 121268]
		- 20250916@Jaden.Tang: Use new table TraderJuicePerformance [Redmine ID: 237899]
		
    Param's ExplanatiON:   
		- @Market: -1 All; 0 Nonlive; 1 Live   
    
    Example: 
        EXECUTE [TGRS_Rpt_NewPerformanceDetail_Trader_Match] 
			@FromDate = '2014-01-01', 
			@ToDate= '2014-12-30',
			@CustID = 1530768; 
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
		WHERE bt.MainDBBetType IN (1, 3, 7, 8);

	SELECT	tp.MatchId
		,	tp.LeagueId
		,	tp.HomeId
		,	tp.AwayId
		,	tp.EventDate
		,	tp.IsLive
		,	ISNULL(SUM(tp.StakeMYR), 0) AS Turnover
		,	ISNULL(SUM(tp.StakeMYRJuice), 0) AS TurnoverJuice
		,	ISNULL(SUM(tp.Juice), 0) AS Juice
		,	ISNULL(SUM(tp.WinLost), 0) - ISNULL(SUM(tp.Comm), 0) AS WinLoss
		,	ISNULL(SUM(BetCount), 0) AS BetCount
	FROM dbo.TraderJuicePerformance AS tp WITH (NOLOCK)
		LEFT JOIN dbo.LeagueExclusion le WITH(NOLOCK) ON tp.LeagueId = le.LeagueId
	WHERE tp.EventDate BETWEEN @FromDate AND @ToDate
		AND tp.CustId = @CustId
		AND tp.Bettype IN (SELECT bettype FROM @BettypeList)
		AND (@Market = -1 OR tp.IsLive = @Market)
		AND (@IsExcludeLeagues = 0 OR le.LeagueId IS NULL)
	GROUP BY tp.MatchId
		,	tp.LeagueId
		,	tp.HomeId
		,	tp.AwayId
		,	tp.EventDate
		,	tp.IsLive;
END;

GO
/*<info serverAlias="DBTGRS-bodb_TGRS" executers="wsv_tgrs" isFunction="0" isNested="0"></info>*/