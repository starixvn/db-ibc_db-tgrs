
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[TGRS_Spread_SelectAll]
	@LeagueName			  NVARCHAR(200) = '',
	@PageSize			  int = 50,  
	@PageIndex			  int = 1,  
	
	@PageCount			  int = 0 OUTPUT,  
	@RowCount			  int = 0 OUTPUT

/*
Created: 20160122@Aaron
Task : Get all Spread
DB:  DBTGRS.bodb_TGRS

Revisions:
*/ 

AS
BEGIN
    SET NOCOUNT ON
    
    IF @LeagueName IS NULL
    BEGIN
	   SET @LeagueName = ''
    END
    
    DECLARE @tempSpread TABLE (
						  LeagueId BIGINT,
						  LeagueName NVARCHAR(200),
						  BetTypeId SMALLINT,
						  BetTypeName NVARCHAR(100),
						  Spread SMALLINT)
    INSERT INTO @tempSpread
	   SELECT  s.LeagueId,
			 l.leaguename AS LeagueName,
			 s.BetType AS BetTypeId,
			 bt.TypeName AS BetTypeName,
			 s.Spread
	   FROM Spread s WITH(NOLOCK)
	   INNER JOIN BetType bt WITH(NOLOCK) ON bt.BetType = s.BetType 
	   INNER JOIN	bodb02.dbo.league l WITH(NOLOCK) ON l.leagueid = s.LeagueId
	   WHERE l.leaguename LIKE '%' + @LeagueName + '%' AND l.sporttype <= 99 AND s.Spread > 0
    
    SELECT @RowCount = count(1)   
    FROM @tempSpread

    SELECT @PageCount=@RowCount/@PageSize + case when @RowCount%@PageSize>0 then 1 else 0 end;  
	  
    WITH Results AS  
	( 
	 SELECT top (@PageSize*@PageIndex) ROW_NUMBER() OVER (ORDER BY LeagueId ASC) AS Row
			,ts.LeagueId, ts.LeagueName, ts.BetTypeId, ts.BetTypeName, ts.Spread
	 FROM @tempSpread ts
	)

    SELECT  [Row], LeagueId, LeagueName, BetTypeId, BetTypeName, Spread
    FROM Results  
    WHERE  [Row] BETWEEN @PageSize * (@PageIndex-1) + 1 and @PageIndex*@PageSize  
    ORDER BY [Row]
END

 
GO
GRANT EXECUTE ON [dbo].[TGRS_Spread_SelectAll] TO [bodbTGRSNet ]
GO
GRANT VIEW DEFINITION ON [dbo].[TGRS_Spread_SelectAll] TO [bodbTGRSNet ]
GO
 