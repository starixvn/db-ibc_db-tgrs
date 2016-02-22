ALTER FUNCTION	[f_TraderScoreCalculation] (
					@BetTypes	VARCHAR(200)	= '0'
				,	@FromDate	DATE
				,	@ToDate		DATE
				)
RETURNS @Score	TABLE (
						CustId		INT			PRIMARY KEY
					,	Grade		TINYINT
					,	TeamId		SMALLINT
					,	Score		MONEY
					)
AS
/*
	Created:	@20160218@Billy
	Task:		Apply new scoring formula - [Redmine: #50812]
	DB:			DBTGRS.bodb_TGRS

	Revisions:

	Parameters:

*/
BEGIN
	
	DECLARE	@BettypeList	TABLE (
								bettype			SMALLINT
							);

	IF	@Bettypes <> '0'
		 INSERT INTO @BettypeList
		 	(	bettype)
		 SELECT ssk.val
		 FROM	dbo.strSplit_Key(@Bettypes, ',') ssk;
	ELSE 
		 INSERT INTO @BettypeList
		 	(	bettype)
		 SELECT bt.BetType 
		 FROM	dbo.BetType AS bt WITH (NOLOCK);

    WITH ScoreDetail AS (
		SELECT	tp.CustId												AS CustId
			,	ISNULL(SUM(tp.WinLost), 0) - ISNULL(SUM(tp.Comm), 0)	AS WinLost
			,	ISNULL(SUM(tp.Stake * s.Spread * tm.Rate), 0)			AS SumCategory
		FROM		dbo.TraderPerformance AS tp WITH (NOLOCK)
		LEFT JOIN	dbo.Spread AS s WITH (NOLOCK)
				ON	s.LeagueId = tp.LeagueId
				AND	s.BetType = tp.BetType
		LEFT JOIN	dbo.TargetedMargin AS tm WITH (NOLOCK)
				ON	tm.BetType = tp.BetType
		INNER JOIN	@BettypeList AS bl
				ON	bl.bettype = tp.BetType
		WHERE	tp.EventDate BETWEEN @FromDate AND @ToDate
		GROUP BY tp.CustId
	)
	INSERT INTO @Score
		(	CustId   , Grade  , TeamId  , Score)
	SELECT	sd.CustId, t.Grade, t.TeamId, CASE WHEN sd.SumCategory = 0 THEN NULL ELSE sd.WinLost * 100 / sd.SumCategory END
	FROM		ScoreDetail sd
	INNER JOIN	dbo.Trader AS t WITH (NOLOCK)
			ON	t.CustId = sd.CustId;

	RETURN;
END;