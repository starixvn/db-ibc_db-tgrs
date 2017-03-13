
SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

/****** Object:  Stored Procedure dbo.TGRS_OS_LeagueRegionGet    Script Date: 2/22/2017 10:52:57 AM ******/

CREATE PROCEDURE [dbo].[TGRS_OS_LeagueRegionGet]
	 @LeagueName NVARCHAR(200)
	,@RegionId INT
	,@SportId INT

/*
Created: 20170217@Aaron
Task : Get all OS league regions
DB:  DBTGRS.bodb_TGRS

Revisions: 
*/

AS
BEGIN
	SET NOCOUNT ON;

	SELECT l.leagueid
		,l.leaguename
		,lr.RegionId
		,r.RegionName
	FROM [bodb02].[dbo].[league] l WITH (NOLOCK)
	LEFT JOIN dbo.OSLeagueRegion lr WITH (NOLOCK) ON lr.LeagueId = l.leagueid
	LEFT JOIN dbo.OSRegion r WITH (NOLOCK) ON r.RegionId = lr.RegionId
	WHERE (ISNULL(@LeagueName, '')='' OR l.leaguename LIKE '%' + @LeagueName + '%')
		AND l.sporttype <> 0
		AND l.sporttype <> 154
		AND l.sporttype = @SportId
		AND (@RegionId = - 1 OR r.RegionId = @RegionId)
		AND l.IsActive = 1
	ORDER BY l.leaguename
END

/* 
GO
GRANT EXECUTE ON [dbo].[TGRS_OS_LeagueRegionGet] TO [bodbTGRSNet]
GO
GRANT VIEW DEFINITION ON [dbo].[TGRS_OS_LeagueRegionGet] TO [bodbTGRSNet]
GO
*/
GO

SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO


GO 
 GRANT EXECUTE ON [dbo].[TGRS_OS_LeagueRegionGet] TO [bodbTGRSNet]
GO 
 GRANT VIEW DEFINITION ON [dbo].[TGRS_OS_LeagueRegionGet] TO [bodbTGRSNet]
GO 
