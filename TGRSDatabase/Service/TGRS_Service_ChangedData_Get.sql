CREATE PROCEDURE [dbo].[TGRS_Service_ChangedData_Get]
AS
/*
	Created: 20180411@Simon
	Task : Get changed data for report
	DB: bodb_TGRS
	Original: EXEC [TGRS_Service_ChangedData_Get]
	Revisions:
		- 20180503@John: Add more condition to remove old data on ChangedMatches 
*/
BEGIN
	SET NOCOUNT ON

	SELECT ch.MatchId
		,m.homeid
		,m.awayid
		,tr.Username
		,bt.TypeName [BetType]
		,bt.BetType [BetTypeId]
		,ch.PreviousTurnover [OldTurnover]
		,ch.PreviousWinloss [OldWinLoss]
		,ch.PreviousBetCount [OldBetCount]
		,ch.Turnover [NewTurnover]
		,ch.Winloss [NewWinLoss]
		,ch.BetCount [NewBetCount]
	FROM dbo.ChangedMatches ch WITH (NOLOCK)
	INNER JOIN dbo.Trader tr WITH (NOLOCK) ON tr.CustId = ch.CustId
	INNER JOIN bodb02.dbo.[match14] m WITH (NOLOCK) ON m.matchid = ch.MatchId
	INNER JOIN dbo.BetType bt WITH (NOLOCK) ON bt.BetType = ch.BetType
	WHERE (ch.IsNotified = 0 OR ch.IsNotified IS NULL)
	      AND ch.CapturedDate <> '1999-01-01'

	SELECT ch.MatchId
		,m.homeid
		,m.awayid
		,tr.Username
		,bt.TypeName [BetType]
		,bt.BetType [BetTypeId]
		,ch.PreviousTurnover [OldTurnover]
		,ch.PreviousWinloss [OldWinLoss]
		,ch.PreviousBetCount [OldBetCount]
		,ch.Turnover [NewTurnover]
		,ch.Winloss [NewWinLoss]
		,ch.BetCount [NewBetCount]
	FROM dbo.ChangedMatches ch WITH (NOLOCK)
	INNER JOIN dbo.Trader tr WITH (NOLOCK) ON tr.CustId = ch.CustId
	INNER JOIN bodb02.dbo.[match] m WITH (NOLOCK) ON m.matchid = ch.MatchId
	INNER JOIN dbo.BetType bt WITH (NOLOCK) ON bt.BetType = ch.BetType
	WHERE ch.IsNotified = 0 OR ch.IsNotified IS NULL
		  AND ch.CapturedDate <> '1999-01-01'

	UPDATE dbo.ChangedMatches
	WITH (UPDLOCK,ROWLOCK)
	SET IsNotified = 1
	WHERE CapturedDate <> '1999-01-01'

END

/* 
GO
GRANT EXECUTE ON [dbo].[TGRS_Service_ChangedData_Get] TO [bodbTGRSNet]
GO
GRANT VIEW DEFINITION ON [dbo].[TGRS_Service_ChangedData_Get] TO [bodbTGRSNet]
GO
*/