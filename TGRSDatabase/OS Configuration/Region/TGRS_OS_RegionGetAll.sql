SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

/****** Object:  Stored Procedure dbo.TGRS_OS_RegionGetAll    Script Date: 2/22/2017 10:52:57 AM ******/

CREATE PROCEDURE [dbo].[TGRS_OS_RegionGetAll]

/*
Created: 20170215@Aaron
Task : Get all OS regions
DB:  DBTGRS.bodb_TGRS

Revisions: 
*/

AS
BEGIN
	SET NOCOUNT ON

	SELECT r.RegionId
		,r.RegionName
		,COUNT(lr.LeagueId) AS LeagueCount
		,r.CreatedDate
		,c.Username AS CreatedBy
	FROM dbo.OSRegion r WITH (NOLOCK)
	LEFT JOIN dbo.OSLeagueRegion lr WITH (NOLOCK) ON lr.RegionId = r.RegionId
	LEFT JOIN bodb02.dbo.CustInfo c WITH (NOLOCK) ON c.CustID = r.CreatedBy
	GROUP BY r.RegionId
		,r.RegionName
		,r.CreatedDate
		,r.CreatedBy
		,c.Username
	ORDER BY r.RegionId
END
/* 
GO
GRANT EXECUTE ON [dbo].[TGRS_OS_RegionGetAll] TO [bodbTGRSNet]
GO
GRANT VIEW DEFINITION ON [dbo].[TGRS_OS_RegionGetAll] TO [bodbTGRSNet]
GO
*/
GO

SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO


GO 
 GRANT EXECUTE ON [dbo].[TGRS_OS_RegionGetAll] TO [bodbTGRSNet]
GO 
 GRANT VIEW DEFINITION ON [dbo].[TGRS_OS_RegionGetAll] TO [bodbTGRSNet]
GO 
