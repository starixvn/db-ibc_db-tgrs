USE [bodb_TGRS]
GO
/****** Object:  StoredProcedure [dbo].[TGRS_Team_SelectAll]    Script Date: 5/9/2014 4:38:23 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
 
ALTER PROCEDURE [dbo].[TGRS_Team_SelectAll]

/*
Created: 20140509@Sophia
Task : List of Team
DB:  DBTGRS.bodb_TGRS

Revisions:
   
*/ 

AS
BEGIN
	SET NOCOUNT ON 	
	
	SELECT	T.TeamId, T.TeamName, T.Description, COUNT(TH.CustId) as TraderCount, AVG(ISNULL(TG.Grade,0)) as AvgGrade, T.CreatedDate, T.CreatedBy , C.Username AS CreatedUsername
	FROM	Team T WITH (NOLOCK)
		LEFT JOIN (		 
					SELECT	TH.CustId, TH.TeamId, MAX(TH.BeginDate) AS BeginDate
					FROM	dbo.TraderTeam_History TH WITH (NOLOCK)
					WHERE	TH.BeginDate <= Getdate()
					GROUP BY  TH.CustId, TH.TeamId
				   ) TH
				ON  TH.TeamId = T.TeamId
		LEFT JOIN ( SELECT	TG.CustId, CONVERT(MONEY,TG.Grade) AS Grade, MAX(TG.BeginDate) AS BeginDate
					FROM	dbo.TraderGrade_History TG WITH (NOLOCK)
					WHERE	TG.BeginDate <= Getdate()
					GROUP BY  TG.CustId, TG.Grade					
					) TG
				ON TG.CustId = TH.CustId
		LEFT JOIN	bodb02.dbo.CustInfo C WITH (NOLOCK)
				ON	C.CustID = T.CreatedBy
	GROUP BY T.TeamId, T.TeamName, T.Description, T.CreatedDate, T.CreatedBy ,C.Username
	ORDER BY T.TeamName
	
END
GO

GRANT EXECUTE ON [dbo].[TGRS_Team_SelectAll] TO [bodbTGRSNet]
GO