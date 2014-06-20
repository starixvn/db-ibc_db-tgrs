USE [bodb02]
GO

/****** Object:  User [bodbTGRSNet]    Script Date: 6/20/2014 12:58:16 PM ******/
CREATE USER [bodbTGRSNet] FOR LOGIN [bodbTGRSNet] WITH DEFAULT_SCHEMA=[dbo]
GO

GRANT SELECT ON OBJECT::[dbo].[League] TO [bodbTGRSNet];
GRANT SELECT ON OBJECT::[dbo].[custInfo] TO [bodbTGRSNet];
GRANT SELECT ON OBJECT::[dbo].[Dot_Admin_LeagueDisplayMode] TO [bodbTGRSNet];
GRANT CONNECT ON DATABASE::[bodb02] TO [bodbTGRSNet];