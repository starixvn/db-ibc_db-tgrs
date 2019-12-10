ALTER PROCEDURE [dbo].[TGRS_Rpt_MultipleMatches_Match_Bettype]
		@CustId				INT
	,	@MatchId			INT
	,	@Bettypes			VARCHAR(2000) = '1,3,7,8'
	,	@IsExcludeLeagues	BIT			  = 1
	,	@Market				SMALLINT	  = 1
AS    
/*  
	Created:	20191204@Long.Luu
	Task :		Multiple Matches Report - drill down to Match-Bettype
	DB:			DBTGRS.bodb_TGRS
	Original:  
  
	Revisions: 	
   		- 20191204@Long.Luu:	Created [Remine Id: 118960]

	Param's Explanation:  	

	Exam:   
*/  
 
BEGIN 
	SET NOCOUNT ON;

	DECLARE	@BettypeList TABLE (
			BetType			SMALLINT PRIMARY KEY
	);

	IF	@Bettypes <> ''
		 INSERT INTO @BettypeList (Bettype)
		 SELECT ssk.val FROM dbo.strSplit_Key(@Bettypes, ',') ssk;
	ELSE 
		 INSERT INTO @BettypeList (bettype)
		 SELECT bt.BetType FROM	dbo.BetType AS bt WITH (NOLOCK) WHERE bt.BetType IN (1,3,7,8);

	SELECT	tp.BetType
		,	ISNULL(SUM(tp.Stake), 0)								AS Turnover
		,	ISNULL(SUM(tp.WinLost), 0) - ISNULL(SUM(tp.Comm), 0)	AS WinLoss
		,	ISNULL(SUM(tp.BetCount), 0)								AS BetCount
		,	(ISNULL(SUM(tp.WinLost), 0) - ISNULL(SUM(tp.Comm), 0)) * 100 / ISNULL(SUM(tp.Stake), 0) AS Margin
	FROM dbo.TraderPerformance AS tp WITH(NOLOCK)
		LEFT JOIN dbo.LeagueExclusion le WITH(NOLOCK) ON tp.LeagueId = le.LeagueId
		INNER JOIN @BettypeList AS b ON b.Bettype = tp.BetType
	WHERE tp.CustId = @CustId
		AND tp.MatchId = @MatchId
		AND (@IsExcludeLeagues = 0 OR le.LeagueId IS NULL)
		AND (@Market = -1 OR tp.IsLive = @Market)
		AND tp.CustId <> 0
	GROUP BY tp.BetType;

END;

GO
/*<info serverAlias="DBTGRS-bodb_TGRS" executers="bodbTGRSNet" isFunction="0" isNested="0"></info>*/