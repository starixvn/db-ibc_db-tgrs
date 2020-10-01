/*
	Creator: 20201001@John.Ngo
	Task: Initial IsLive of OSDataTGRS of Basketball [Redmine ID: #140875]
	DB: DB061.bodb_TGRS

	Reviewer: Partrick
*/

GO
-- IsLive

DECLARE	@EventDate	DATE;

CREATE TABLE	#tmpEventDate (
	[EventDate]			DATE NULL
);

CREATE CLUSTERED INDEX	#CIX_tmpEventDate_EventDate ON #tmpEventDate (
	[EventDate]					ASC
);
		
INSERT INTO #tmpEventDate(EventDate)
SELECT DISTINCT r.EventDate
FROM dbo.[OSDataTGRS] AS r WITH(NOLOCK) WHERE r.IsLive IS NULL;

WHILE	EXISTS (SELECT 1 FROM #tmpEventDate WITH (NOLOCK))
	BEGIN
		
		SELECT TOP(1) @EventDate = ed.EventDate
		FROM #tmpEventDate AS ed WITH(NOLOCK) ORDER BY ed.EventDate DESC;

		UPDATE [dbo].[OSDataTGRS] WITH(ROWLOCK)
		SET	[IsLive] = 1 WHERE EventDate = @EventDate

		DELETE	ed
		FROM	#tmpEventDate AS ed WITH (ROWLOCK)
		WHERE	ed.EventDate = @EventDate;

	END;

UPDATE [dbo].[OSSummaryByLeague_Monthly] WITH(ROWLOCK)
SET	[IsLive] = 1;

UPDATE [dbo].[OSSummaryByTrader_Daily] WITH(ROWLOCK)
SET	[IsLive] = 1;

UPDATE [dbo].[OSSummaryByTrader_Monthly] WITH(ROWLOCK)
SET	[IsLive] = 1;

GO
/*<info serverAlias=" DB061-bodb_TGRS"></info>*/