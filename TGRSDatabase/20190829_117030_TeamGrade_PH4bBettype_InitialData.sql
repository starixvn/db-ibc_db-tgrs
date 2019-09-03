/*
	Creator:	20190827@John.Ngo
	Task:		Support bet choice details for PH4b bet types - [Redmine: #119276]
	Server:		DB06.bodb_TGRS
*/

USE bodb_TGRS

-- Update Grade & Team for UnassignedTrader
WHILE EXISTS (SELECT TOP(1) 1 FROM dbo.TraderPerformance AS tp WITH (NOLOCK) WHERE tp.CustId = 0 AND (tp.TeamId IS NULL OR tp.Grade IS NULL) )
BEGIN
	BEGIN TRANSACTION;

	;WITH CTE AS 
		( 
		SELECT DISTINCT TOP 10000 tp.MatchId FROM dbo.TraderPerformance AS tp WITH (NOLOCK)
		WHERE tp.CustId = 0 AND (tp.TeamId IS NULL OR tp.Grade IS NULL)
		) 
		UPDATE tp
		SET tp.TeamId = 200
			,	tp.Grade = 200
		FROM dbo.TraderPerformance AS tp
			INNER JOIN CTE t WITH (NOLOCK) ON tp.MatchId = t.MatchId
			WHERE tp.CustId = 0;

	COMMIT TRANSACTION;
END;

-- PH4b
GO
-- Corners Odd/Even/1H Corners Odd/Even (470,472)
INSERT [dbo].[BetChoiceMapping] ([BetType], [BetChoice], [TGRSBetChoice]) VALUES (470, N'O', N'Odd')
INSERT [dbo].[BetChoiceMapping] ([BetType], [BetChoice], [TGRSBetChoice]) VALUES (470, N'E', N'Even')
INSERT [dbo].[BetChoiceMapping] ([BetType], [BetChoice], [TGRSBetChoice]) VALUES (472, N'O', N'Odd')
INSERT [dbo].[BetChoiceMapping] ([BetType], [BetChoice], [TGRSBetChoice]) VALUES (472, N'E', N'Even')
GO
-- Total Corners
INSERT [dbo].[BetChoiceMapping] ([BetType], [BetChoice], [TGRSBetChoice]) VALUES (473, N'0-5', N'0-5')
INSERT [dbo].[BetChoiceMapping] ([BetType], [BetChoice], [TGRSBetChoice]) VALUES (473, N'6-8', N'6-8')
INSERT [dbo].[BetChoiceMapping] ([BetType], [BetChoice], [TGRSBetChoice]) VALUES (473, N'9-11', N'9-11')
INSERT [dbo].[BetChoiceMapping] ([BetType], [BetChoice], [TGRSBetChoice]) VALUES (473, N'12-14', N'12-14')
INSERT [dbo].[BetChoiceMapping] ([BetType], [BetChoice], [TGRSBetChoice]) VALUES (473, N'15+', N'15+')
GO
-- 1st Total Corners
INSERT [dbo].[BetChoiceMapping] ([BetType], [BetChoice], [TGRSBetChoice]) VALUES (474, N'0-2', N'0-2')
INSERT [dbo].[BetChoiceMapping] ([BetType], [BetChoice], [TGRSBetChoice]) VALUES (474, N'3-4', N'3-4')
INSERT [dbo].[BetChoiceMapping] ([BetType], [BetChoice], [TGRSBetChoice]) VALUES (474, N'5-6', N'5-6')
INSERT [dbo].[BetChoiceMapping] ([BetType], [BetChoice], [TGRSBetChoice]) VALUES (474, N'7+', N'7+')
GO
-- Alternative Corners/1st Alternative Corners
INSERT [dbo].[BetChoiceMapping] ([BetType], [BetChoice], [TGRSBetChoice]) VALUES (475, N'O', N'Over')
INSERT [dbo].[BetChoiceMapping] ([BetType], [BetChoice], [TGRSBetChoice]) VALUES (475, N'E', N'Exact')
INSERT [dbo].[BetChoiceMapping] ([BetType], [BetChoice], [TGRSBetChoice]) VALUES (475, N'U', N'Under')
INSERT [dbo].[BetChoiceMapping] ([BetType], [BetChoice], [TGRSBetChoice]) VALUES (476, N'O', N'Over')
INSERT [dbo].[BetChoiceMapping] ([BetType], [BetChoice], [TGRSBetChoice]) VALUES (476, N'E', N'Exact')
INSERT [dbo].[BetChoiceMapping] ([BetType], [BetChoice], [TGRSBetChoice]) VALUES (476, N'U', N'Under')
GO
-- Corner 3-Way Handicap/1st Corner 3-Way Handicap
INSERT [dbo].[BetChoiceMapping] ([BetType], [BetChoice], [TGRSBetChoice]) VALUES (477, N'1', N'Home')
INSERT [dbo].[BetChoiceMapping] ([BetType], [BetChoice], [TGRSBetChoice]) VALUES (477, N'X', N'Draw')
INSERT [dbo].[BetChoiceMapping] ([BetType], [BetChoice], [TGRSBetChoice]) VALUES (477, N'2', N'Away')
INSERT [dbo].[BetChoiceMapping] ([BetType], [BetChoice], [TGRSBetChoice]) VALUES (478, N'1', N'Home')
INSERT [dbo].[BetChoiceMapping] ([BetType], [BetChoice], [TGRSBetChoice]) VALUES (478, N'X', N'Draw')
INSERT [dbo].[BetChoiceMapping] ([BetType], [BetChoice], [TGRSBetChoice]) VALUES (478, N'2', N'Away')
GO
-- Time of First Corner/Time of 2H First Corner
INSERT [dbo].[BetChoiceMapping] ([BetType], [BetChoice], [TGRSBetChoice]) VALUES (479, N'Y', N'Corner Before')
INSERT [dbo].[BetChoiceMapping] ([BetType], [BetChoice], [TGRSBetChoice]) VALUES (479, N'N', N'No Corner Before')
INSERT [dbo].[BetChoiceMapping] ([BetType], [BetChoice], [TGRSBetChoice]) VALUES (481, N'Y', N'Corner Before')
INSERT [dbo].[BetChoiceMapping] ([BetType], [BetChoice], [TGRSBetChoice]) VALUES (481, N'N', N'No Corner Before')
GO
-- Home Team Over/Under Corners
INSERT [dbo].[BetChoiceMapping] ([BetType], [BetChoice], [TGRSBetChoice]) VALUES (482, N'O', N'Over')
INSERT [dbo].[BetChoiceMapping] ([BetType], [BetChoice], [TGRSBetChoice]) VALUES (482, N'U', N'Under')
-- Away Team Over/Under Corners
INSERT [dbo].[BetChoiceMapping] ([BetType], [BetChoice], [TGRSBetChoice]) VALUES (483, N'O', N'Over')
INSERT [dbo].[BetChoiceMapping] ([BetType], [BetChoice], [TGRSBetChoice]) VALUES (483, N'U', N'Under')
-- 1H Home Team Over/Under Corners
INSERT [dbo].[BetChoiceMapping] ([BetType], [BetChoice], [TGRSBetChoice]) VALUES (484, N'O', N'Over')
INSERT [dbo].[BetChoiceMapping] ([BetType], [BetChoice], [TGRSBetChoice]) VALUES (484, N'U', N'Under')
-- 1H Away Team Over/Under Corners
INSERT [dbo].[BetChoiceMapping] ([BetType], [BetChoice], [TGRSBetChoice]) VALUES (485, N'O', N'Over')
INSERT [dbo].[BetChoiceMapping] ([BetType], [BetChoice], [TGRSBetChoice]) VALUES (485, N'U', N'Under')
GO
-- Corners Race/1H Corners Race
INSERT [dbo].[BetChoiceMapping] ([BetType], [BetChoice], [TGRSBetChoice]) VALUES (486, N'H', N'Home')
INSERT [dbo].[BetChoiceMapping] ([BetType], [BetChoice], [TGRSBetChoice]) VALUES (486, N'A', N'Away')
INSERT [dbo].[BetChoiceMapping] ([BetType], [BetChoice], [TGRSBetChoice]) VALUES (486, N'N', N'Neither')
INSERT [dbo].[BetChoiceMapping] ([BetType], [BetChoice], [TGRSBetChoice]) VALUES (487, N'H', N'Home')
INSERT [dbo].[BetChoiceMapping] ([BetType], [BetChoice], [TGRSBetChoice]) VALUES (487, N'A', N'Away')
INSERT [dbo].[BetChoiceMapping] ([BetType], [BetChoice], [TGRSBetChoice]) VALUES (487, N'N', N'Neither')
GO
-- First Corner (own)
INSERT [dbo].[BetChoiceMapping] ([BetType], [BetChoice], [TGRSBetChoice]) VALUES (488, N'H', N'Home')
INSERT [dbo].[BetChoiceMapping] ([BetType], [BetChoice], [TGRSBetChoice]) VALUES (488, N'A', N'Away')
-- 1H First Corner (own)
INSERT [dbo].[BetChoiceMapping] ([BetType], [BetChoice], [TGRSBetChoice]) VALUES (489, N'H', N'Home')
INSERT [dbo].[BetChoiceMapping] ([BetType], [BetChoice], [TGRSBetChoice]) VALUES (489, N'A', N'Away')
-- 2H First Corner
INSERT [dbo].[BetChoiceMapping] ([BetType], [BetChoice], [TGRSBetChoice]) VALUES (490, N'H', N'Home')
INSERT [dbo].[BetChoiceMapping] ([BetType], [BetChoice], [TGRSBetChoice]) VALUES (490, N'A', N'Away')
-- Last Corner (own)
INSERT [dbo].[BetChoiceMapping] ([BetType], [BetChoice], [TGRSBetChoice]) VALUES (491, N'H', N'Home')
INSERT [dbo].[BetChoiceMapping] ([BetType], [BetChoice], [TGRSBetChoice]) VALUES (491, N'A', N'Away')
-- 1H Last Corner (own)
INSERT [dbo].[BetChoiceMapping] ([BetType], [BetChoice], [TGRSBetChoice]) VALUES (492, N'H', N'Home')
INSERT [dbo].[BetChoiceMapping] ([BetType], [BetChoice], [TGRSBetChoice]) VALUES (492, N'A', N'Away')
GO
-- Half Time/Full Time Total Corners
INSERT [dbo].[BetChoiceMapping] ([BetType], [BetChoice], [TGRSBetChoice]) VALUES (493, N'0/0', N'0/0')
INSERT [dbo].[BetChoiceMapping] ([BetType], [BetChoice], [TGRSBetChoice]) VALUES (493, N'0/1', N'0/1')
INSERT [dbo].[BetChoiceMapping] ([BetType], [BetChoice], [TGRSBetChoice]) VALUES (493, N'0/2', N'0/2')
INSERT [dbo].[BetChoiceMapping] ([BetType], [BetChoice], [TGRSBetChoice]) VALUES (493, N'0/3', N'0/3')
INSERT [dbo].[BetChoiceMapping] ([BetType], [BetChoice], [TGRSBetChoice]) VALUES (493, N'0/4', N'0/4')
INSERT [dbo].[BetChoiceMapping] ([BetType], [BetChoice], [TGRSBetChoice]) VALUES (493, N'0/5', N'0/5')
INSERT [dbo].[BetChoiceMapping] ([BetType], [BetChoice], [TGRSBetChoice]) VALUES (493, N'0/6', N'0/6')
INSERT [dbo].[BetChoiceMapping] ([BetType], [BetChoice], [TGRSBetChoice]) VALUES (493, N'0/7', N'0/7')
INSERT [dbo].[BetChoiceMapping] ([BetType], [BetChoice], [TGRSBetChoice]) VALUES (493, N'0/8+', N'0/8+')
GO
INSERT [dbo].[BetChoiceMapping] ([BetType], [BetChoice], [TGRSBetChoice]) VALUES (493, N'1/1', N'1/1')
INSERT [dbo].[BetChoiceMapping] ([BetType], [BetChoice], [TGRSBetChoice]) VALUES (493, N'1/2', N'1/2')
INSERT [dbo].[BetChoiceMapping] ([BetType], [BetChoice], [TGRSBetChoice]) VALUES (493, N'1/3', N'1/3')
INSERT [dbo].[BetChoiceMapping] ([BetType], [BetChoice], [TGRSBetChoice]) VALUES (493, N'1/4', N'1/4')
INSERT [dbo].[BetChoiceMapping] ([BetType], [BetChoice], [TGRSBetChoice]) VALUES (493, N'1/5', N'1/5')
INSERT [dbo].[BetChoiceMapping] ([BetType], [BetChoice], [TGRSBetChoice]) VALUES (493, N'1/6', N'1/6')
INSERT [dbo].[BetChoiceMapping] ([BetType], [BetChoice], [TGRSBetChoice]) VALUES (493, N'1/7', N'1/7')
INSERT [dbo].[BetChoiceMapping] ([BetType], [BetChoice], [TGRSBetChoice]) VALUES (493, N'1/8', N'1/8')
INSERT [dbo].[BetChoiceMapping] ([BetType], [BetChoice], [TGRSBetChoice]) VALUES (493, N'1/9+', N'1/9+')
GO
INSERT [dbo].[BetChoiceMapping] ([BetType], [BetChoice], [TGRSBetChoice]) VALUES (493, N'2/2', N'2/2')
INSERT [dbo].[BetChoiceMapping] ([BetType], [BetChoice], [TGRSBetChoice]) VALUES (493, N'2/3', N'2/3')
INSERT [dbo].[BetChoiceMapping] ([BetType], [BetChoice], [TGRSBetChoice]) VALUES (493, N'2/4', N'2/4')
INSERT [dbo].[BetChoiceMapping] ([BetType], [BetChoice], [TGRSBetChoice]) VALUES (493, N'2/5', N'2/5')
INSERT [dbo].[BetChoiceMapping] ([BetType], [BetChoice], [TGRSBetChoice]) VALUES (493, N'2/6', N'2/6')
INSERT [dbo].[BetChoiceMapping] ([BetType], [BetChoice], [TGRSBetChoice]) VALUES (493, N'2/7', N'2/7')
INSERT [dbo].[BetChoiceMapping] ([BetType], [BetChoice], [TGRSBetChoice]) VALUES (493, N'2/8', N'2/8')
INSERT [dbo].[BetChoiceMapping] ([BetType], [BetChoice], [TGRSBetChoice]) VALUES (493, N'2/9', N'2/9')
INSERT [dbo].[BetChoiceMapping] ([BetType], [BetChoice], [TGRSBetChoice]) VALUES (493, N'2/10+', N'2/10+')
GO
INSERT [dbo].[BetChoiceMapping] ([BetType], [BetChoice], [TGRSBetChoice]) VALUES (493, N'3/3', N'3/3')
INSERT [dbo].[BetChoiceMapping] ([BetType], [BetChoice], [TGRSBetChoice]) VALUES (493, N'3/4', N'3/4')
INSERT [dbo].[BetChoiceMapping] ([BetType], [BetChoice], [TGRSBetChoice]) VALUES (493, N'3/5', N'3/5')
INSERT [dbo].[BetChoiceMapping] ([BetType], [BetChoice], [TGRSBetChoice]) VALUES (493, N'3/6', N'3/6')
INSERT [dbo].[BetChoiceMapping] ([BetType], [BetChoice], [TGRSBetChoice]) VALUES (493, N'3/7', N'3/7')
INSERT [dbo].[BetChoiceMapping] ([BetType], [BetChoice], [TGRSBetChoice]) VALUES (493, N'3/8', N'3/8')
INSERT [dbo].[BetChoiceMapping] ([BetType], [BetChoice], [TGRSBetChoice]) VALUES (493, N'3/9', N'3/9')
INSERT [dbo].[BetChoiceMapping] ([BetType], [BetChoice], [TGRSBetChoice]) VALUES (493, N'3/10', N'3/10')
INSERT [dbo].[BetChoiceMapping] ([BetType], [BetChoice], [TGRSBetChoice]) VALUES (493, N'3/11+', N'3/11+')
GO
INSERT [dbo].[BetChoiceMapping] ([BetType], [BetChoice], [TGRSBetChoice]) VALUES (493, N'4/4', N'4/4')
INSERT [dbo].[BetChoiceMapping] ([BetType], [BetChoice], [TGRSBetChoice]) VALUES (493, N'4/5', N'4/5')
INSERT [dbo].[BetChoiceMapping] ([BetType], [BetChoice], [TGRSBetChoice]) VALUES (493, N'4/6', N'4/6')
INSERT [dbo].[BetChoiceMapping] ([BetType], [BetChoice], [TGRSBetChoice]) VALUES (493, N'4/7', N'4/7')
INSERT [dbo].[BetChoiceMapping] ([BetType], [BetChoice], [TGRSBetChoice]) VALUES (493, N'4/8', N'4/8')
INSERT [dbo].[BetChoiceMapping] ([BetType], [BetChoice], [TGRSBetChoice]) VALUES (493, N'4/9', N'4/9')
INSERT [dbo].[BetChoiceMapping] ([BetType], [BetChoice], [TGRSBetChoice]) VALUES (493, N'4/10', N'4/10')
INSERT [dbo].[BetChoiceMapping] ([BetType], [BetChoice], [TGRSBetChoice]) VALUES (493, N'4/11', N'4/11')
INSERT [dbo].[BetChoiceMapping] ([BetType], [BetChoice], [TGRSBetChoice]) VALUES (493, N'4/12+', N'4/12+')
GO
INSERT [dbo].[BetChoiceMapping] ([BetType], [BetChoice], [TGRSBetChoice]) VALUES (493, N'5/5', N'5/5')
INSERT [dbo].[BetChoiceMapping] ([BetType], [BetChoice], [TGRSBetChoice]) VALUES (493, N'5/6', N'5/6')
INSERT [dbo].[BetChoiceMapping] ([BetType], [BetChoice], [TGRSBetChoice]) VALUES (493, N'5/7', N'5/7')
INSERT [dbo].[BetChoiceMapping] ([BetType], [BetChoice], [TGRSBetChoice]) VALUES (493, N'5/8', N'5/8')
INSERT [dbo].[BetChoiceMapping] ([BetType], [BetChoice], [TGRSBetChoice]) VALUES (493, N'5/9', N'5/9')
INSERT [dbo].[BetChoiceMapping] ([BetType], [BetChoice], [TGRSBetChoice]) VALUES (493, N'5/10', N'5/10')
INSERT [dbo].[BetChoiceMapping] ([BetType], [BetChoice], [TGRSBetChoice]) VALUES (493, N'5/11', N'5/11')
INSERT [dbo].[BetChoiceMapping] ([BetType], [BetChoice], [TGRSBetChoice]) VALUES (493, N'5/12', N'5/12')
INSERT [dbo].[BetChoiceMapping] ([BetType], [BetChoice], [TGRSBetChoice]) VALUES (493, N'5/13+', N'5/13+')
GO
INSERT [dbo].[BetChoiceMapping] ([BetType], [BetChoice], [TGRSBetChoice]) VALUES (493, N'6/6', N'6/6')
INSERT [dbo].[BetChoiceMapping] ([BetType], [BetChoice], [TGRSBetChoice]) VALUES (493, N'6/7', N'6/7')
INSERT [dbo].[BetChoiceMapping] ([BetType], [BetChoice], [TGRSBetChoice]) VALUES (493, N'6/8', N'6/8')
INSERT [dbo].[BetChoiceMapping] ([BetType], [BetChoice], [TGRSBetChoice]) VALUES (493, N'6/9', N'6/9')
INSERT [dbo].[BetChoiceMapping] ([BetType], [BetChoice], [TGRSBetChoice]) VALUES (493, N'6/10', N'6/10')
INSERT [dbo].[BetChoiceMapping] ([BetType], [BetChoice], [TGRSBetChoice]) VALUES (493, N'6/11', N'6/11')
INSERT [dbo].[BetChoiceMapping] ([BetType], [BetChoice], [TGRSBetChoice]) VALUES (493, N'6/12', N'6/12')
INSERT [dbo].[BetChoiceMapping] ([BetType], [BetChoice], [TGRSBetChoice]) VALUES (493, N'6/13', N'6/13')
INSERT [dbo].[BetChoiceMapping] ([BetType], [BetChoice], [TGRSBetChoice]) VALUES (493, N'6/14+', N'6/14+')
GO
INSERT [dbo].[BetChoiceMapping] ([BetType], [BetChoice], [TGRSBetChoice]) VALUES (493, N'7/7', N'7/7')
INSERT [dbo].[BetChoiceMapping] ([BetType], [BetChoice], [TGRSBetChoice]) VALUES (493, N'7/8', N'7/8')
INSERT [dbo].[BetChoiceMapping] ([BetType], [BetChoice], [TGRSBetChoice]) VALUES (493, N'7/9', N'7/9')
INSERT [dbo].[BetChoiceMapping] ([BetType], [BetChoice], [TGRSBetChoice]) VALUES (493, N'7/10', N'7/10')
INSERT [dbo].[BetChoiceMapping] ([BetType], [BetChoice], [TGRSBetChoice]) VALUES (493, N'7/11', N'7/11')
INSERT [dbo].[BetChoiceMapping] ([BetType], [BetChoice], [TGRSBetChoice]) VALUES (493, N'7/12', N'7/12')
INSERT [dbo].[BetChoiceMapping] ([BetType], [BetChoice], [TGRSBetChoice]) VALUES (493, N'7/13', N'7/13')
INSERT [dbo].[BetChoiceMapping] ([BetType], [BetChoice], [TGRSBetChoice]) VALUES (493, N'7/14', N'7/14')
INSERT [dbo].[BetChoiceMapping] ([BetType], [BetChoice], [TGRSBetChoice]) VALUES (493, N'7/15+', N'7/15+')
GO
INSERT [dbo].[BetChoiceMapping] ([BetType], [BetChoice], [TGRSBetChoice]) VALUES (493, N'8/8', N'8/8')
INSERT [dbo].[BetChoiceMapping] ([BetType], [BetChoice], [TGRSBetChoice]) VALUES (493, N'8/9', N'8/9')
INSERT [dbo].[BetChoiceMapping] ([BetType], [BetChoice], [TGRSBetChoice]) VALUES (493, N'8/10', N'8/10')
INSERT [dbo].[BetChoiceMapping] ([BetType], [BetChoice], [TGRSBetChoice]) VALUES (493, N'8/11', N'8/11')
INSERT [dbo].[BetChoiceMapping] ([BetType], [BetChoice], [TGRSBetChoice]) VALUES (493, N'8/12', N'8/12')
INSERT [dbo].[BetChoiceMapping] ([BetType], [BetChoice], [TGRSBetChoice]) VALUES (493, N'8/13', N'8/13')
INSERT [dbo].[BetChoiceMapping] ([BetType], [BetChoice], [TGRSBetChoice]) VALUES (493, N'8/14', N'8/14')
INSERT [dbo].[BetChoiceMapping] ([BetType], [BetChoice], [TGRSBetChoice]) VALUES (493, N'8/15+', N'8/15+')
GO
INSERT [dbo].[BetChoiceMapping] ([BetType], [BetChoice], [TGRSBetChoice]) VALUES (493, N'9/9', N'9/9')
INSERT [dbo].[BetChoiceMapping] ([BetType], [BetChoice], [TGRSBetChoice]) VALUES (493, N'9/10', N'9/10')
INSERT [dbo].[BetChoiceMapping] ([BetType], [BetChoice], [TGRSBetChoice]) VALUES (493, N'9/11', N'9/11')
INSERT [dbo].[BetChoiceMapping] ([BetType], [BetChoice], [TGRSBetChoice]) VALUES (493, N'9/12', N'9/12')
INSERT [dbo].[BetChoiceMapping] ([BetType], [BetChoice], [TGRSBetChoice]) VALUES (493, N'9/13', N'9/13')
INSERT [dbo].[BetChoiceMapping] ([BetType], [BetChoice], [TGRSBetChoice]) VALUES (493, N'9/14', N'9/14')
INSERT [dbo].[BetChoiceMapping] ([BetType], [BetChoice], [TGRSBetChoice]) VALUES (493, N'9/15+', N'9/15+')
INSERT [dbo].[BetChoiceMapping] ([BetType], [BetChoice], [TGRSBetChoice]) VALUES (493, N'AOS', N'AOS')
GO
-- 1H Correct Corners
INSERT [dbo].[BetChoiceMapping] ([BetType], [BetChoice], [TGRSBetChoice]) VALUES (494, N'1-0', N'1-0 & 0-1')
INSERT [dbo].[BetChoiceMapping] ([BetType], [BetChoice], [TGRSBetChoice]) VALUES (494, N'0-1', N'1-0 & 0-1')
INSERT [dbo].[BetChoiceMapping] ([BetType], [BetChoice], [TGRSBetChoice]) VALUES (494, N'2-0', N'2-0 & 0-2')
INSERT [dbo].[BetChoiceMapping] ([BetType], [BetChoice], [TGRSBetChoice]) VALUES (494, N'0-2', N'2-0 & 0-2')
INSERT [dbo].[BetChoiceMapping] ([BetType], [BetChoice], [TGRSBetChoice]) VALUES (494, N'2-1', N'2-1 & 1-2')
INSERT [dbo].[BetChoiceMapping] ([BetType], [BetChoice], [TGRSBetChoice]) VALUES (494, N'1-2', N'2-1 & 1-2')
INSERT [dbo].[BetChoiceMapping] ([BetType], [BetChoice], [TGRSBetChoice]) VALUES (494, N'3-0', N'3-0 & 0-3')
INSERT [dbo].[BetChoiceMapping] ([BetType], [BetChoice], [TGRSBetChoice]) VALUES (494, N'0-3', N'3-0 & 0-3')
INSERT [dbo].[BetChoiceMapping] ([BetType], [BetChoice], [TGRSBetChoice]) VALUES (494, N'3-1', N'3-1 & 1-3')
INSERT [dbo].[BetChoiceMapping] ([BetType], [BetChoice], [TGRSBetChoice]) VALUES (494, N'1-3', N'3-1 & 1-3')
INSERT [dbo].[BetChoiceMapping] ([BetType], [BetChoice], [TGRSBetChoice]) VALUES (494, N'3-2', N'3-2 & 2-3')
INSERT [dbo].[BetChoiceMapping] ([BetType], [BetChoice], [TGRSBetChoice]) VALUES (494, N'2-3', N'3-2 & 2-3')
INSERT [dbo].[BetChoiceMapping] ([BetType], [BetChoice], [TGRSBetChoice]) VALUES (494, N'4-0', N'4-0 & 0-4')
INSERT [dbo].[BetChoiceMapping] ([BetType], [BetChoice], [TGRSBetChoice]) VALUES (494, N'0-4', N'4-0 & 0-4')
INSERT [dbo].[BetChoiceMapping] ([BetType], [BetChoice], [TGRSBetChoice]) VALUES (494, N'4-1', N'4-1 & 1-4')
INSERT [dbo].[BetChoiceMapping] ([BetType], [BetChoice], [TGRSBetChoice]) VALUES (494, N'1-4', N'4-1 & 1-4')
INSERT [dbo].[BetChoiceMapping] ([BetType], [BetChoice], [TGRSBetChoice]) VALUES (494, N'4-2', N'4-2 & 2-4')
INSERT [dbo].[BetChoiceMapping] ([BetType], [BetChoice], [TGRSBetChoice]) VALUES (494, N'2-4', N'4-2 & 2-4')
INSERT [dbo].[BetChoiceMapping] ([BetType], [BetChoice], [TGRSBetChoice]) VALUES (494, N'4-3', N'4-3 & 3-4')
INSERT [dbo].[BetChoiceMapping] ([BetType], [BetChoice], [TGRSBetChoice]) VALUES (494, N'3-4', N'4-3 & 3-4')
INSERT [dbo].[BetChoiceMapping] ([BetType], [BetChoice], [TGRSBetChoice]) VALUES (494, N'5-0', N'5-0 & 0-5')
INSERT [dbo].[BetChoiceMapping] ([BetType], [BetChoice], [TGRSBetChoice]) VALUES (494, N'0-5', N'5-0 & 0-5')
INSERT [dbo].[BetChoiceMapping] ([BetType], [BetChoice], [TGRSBetChoice]) VALUES (494, N'5-1', N'5-1 & 1-5')
INSERT [dbo].[BetChoiceMapping] ([BetType], [BetChoice], [TGRSBetChoice]) VALUES (494, N'1-5', N'5-1 & 1-5')
INSERT [dbo].[BetChoiceMapping] ([BetType], [BetChoice], [TGRSBetChoice]) VALUES (494, N'5-2', N'5-2 & 2-5')
INSERT [dbo].[BetChoiceMapping] ([BetType], [BetChoice], [TGRSBetChoice]) VALUES (494, N'2-5', N'5-2 & 2-5')
INSERT [dbo].[BetChoiceMapping] ([BetType], [BetChoice], [TGRSBetChoice]) VALUES (494, N'5-3', N'5-3 & 3-5')
INSERT [dbo].[BetChoiceMapping] ([BetType], [BetChoice], [TGRSBetChoice]) VALUES (494, N'3-5', N'5-3 & 3-5')
INSERT [dbo].[BetChoiceMapping] ([BetType], [BetChoice], [TGRSBetChoice]) VALUES (494, N'5-4', N'5-4 & 4-5')
INSERT [dbo].[BetChoiceMapping] ([BetType], [BetChoice], [TGRSBetChoice]) VALUES (494, N'4-5', N'5-4 & 4-5')
INSERT [dbo].[BetChoiceMapping] ([BetType], [BetChoice], [TGRSBetChoice]) VALUES (494, N'0-0', N'0-0')
INSERT [dbo].[BetChoiceMapping] ([BetType], [BetChoice], [TGRSBetChoice]) VALUES (494, N'1-1', N'1-1')
INSERT [dbo].[BetChoiceMapping] ([BetType], [BetChoice], [TGRSBetChoice]) VALUES (494, N'2-2', N'2-2')
INSERT [dbo].[BetChoiceMapping] ([BetType], [BetChoice], [TGRSBetChoice]) VALUES (494, N'3-3', N'3-3')
INSERT [dbo].[BetChoiceMapping] ([BetType], [BetChoice], [TGRSBetChoice]) VALUES (494, N'4-4', N'4-4')
INSERT [dbo].[BetChoiceMapping] ([BetType], [BetChoice], [TGRSBetChoice]) VALUES (494, N'AOS', N'AOS')
GO
-- 2H Correct Corners
INSERT [dbo].[BetChoiceMapping] ([BetType], [BetChoice], [TGRSBetChoice]) VALUES (495, N'1-0', N'1-0 & 0-1')
INSERT [dbo].[BetChoiceMapping] ([BetType], [BetChoice], [TGRSBetChoice]) VALUES (495, N'0-1', N'1-0 & 0-1')
INSERT [dbo].[BetChoiceMapping] ([BetType], [BetChoice], [TGRSBetChoice]) VALUES (495, N'2-0', N'2-0 & 0-2')
INSERT [dbo].[BetChoiceMapping] ([BetType], [BetChoice], [TGRSBetChoice]) VALUES (495, N'0-2', N'2-0 & 0-2')
INSERT [dbo].[BetChoiceMapping] ([BetType], [BetChoice], [TGRSBetChoice]) VALUES (495, N'2-1', N'2-1 & 1-2')
INSERT [dbo].[BetChoiceMapping] ([BetType], [BetChoice], [TGRSBetChoice]) VALUES (495, N'1-2', N'2-1 & 1-2')
INSERT [dbo].[BetChoiceMapping] ([BetType], [BetChoice], [TGRSBetChoice]) VALUES (495, N'3-0', N'3-0 & 0-3')
INSERT [dbo].[BetChoiceMapping] ([BetType], [BetChoice], [TGRSBetChoice]) VALUES (495, N'0-3', N'3-0 & 0-3')
INSERT [dbo].[BetChoiceMapping] ([BetType], [BetChoice], [TGRSBetChoice]) VALUES (495, N'3-1', N'3-1 & 1-3')
INSERT [dbo].[BetChoiceMapping] ([BetType], [BetChoice], [TGRSBetChoice]) VALUES (495, N'1-3', N'3-1 & 1-3')
INSERT [dbo].[BetChoiceMapping] ([BetType], [BetChoice], [TGRSBetChoice]) VALUES (495, N'3-2', N'3-2 & 2-3')
INSERT [dbo].[BetChoiceMapping] ([BetType], [BetChoice], [TGRSBetChoice]) VALUES (495, N'2-3', N'3-2 & 2-3')
INSERT [dbo].[BetChoiceMapping] ([BetType], [BetChoice], [TGRSBetChoice]) VALUES (495, N'4-0', N'4-0 & 0-4')
INSERT [dbo].[BetChoiceMapping] ([BetType], [BetChoice], [TGRSBetChoice]) VALUES (495, N'0-4', N'4-0 & 0-4')
INSERT [dbo].[BetChoiceMapping] ([BetType], [BetChoice], [TGRSBetChoice]) VALUES (495, N'4-1', N'4-1 & 1-4')
INSERT [dbo].[BetChoiceMapping] ([BetType], [BetChoice], [TGRSBetChoice]) VALUES (495, N'1-4', N'4-1 & 1-4')
INSERT [dbo].[BetChoiceMapping] ([BetType], [BetChoice], [TGRSBetChoice]) VALUES (495, N'4-2', N'4-2 & 2-4')
INSERT [dbo].[BetChoiceMapping] ([BetType], [BetChoice], [TGRSBetChoice]) VALUES (495, N'2-4', N'4-2 & 2-4')
INSERT [dbo].[BetChoiceMapping] ([BetType], [BetChoice], [TGRSBetChoice]) VALUES (495, N'4-3', N'4-3 & 3-4')
INSERT [dbo].[BetChoiceMapping] ([BetType], [BetChoice], [TGRSBetChoice]) VALUES (495, N'3-4', N'4-3 & 3-4')
INSERT [dbo].[BetChoiceMapping] ([BetType], [BetChoice], [TGRSBetChoice]) VALUES (495, N'5-0', N'5-0 & 0-5')
INSERT [dbo].[BetChoiceMapping] ([BetType], [BetChoice], [TGRSBetChoice]) VALUES (495, N'0-5', N'5-0 & 0-5')
INSERT [dbo].[BetChoiceMapping] ([BetType], [BetChoice], [TGRSBetChoice]) VALUES (495, N'5-1', N'5-1 & 1-5')
INSERT [dbo].[BetChoiceMapping] ([BetType], [BetChoice], [TGRSBetChoice]) VALUES (495, N'1-5', N'5-1 & 1-5')
INSERT [dbo].[BetChoiceMapping] ([BetType], [BetChoice], [TGRSBetChoice]) VALUES (495, N'5-2', N'5-2 & 2-5')
INSERT [dbo].[BetChoiceMapping] ([BetType], [BetChoice], [TGRSBetChoice]) VALUES (495, N'2-5', N'5-2 & 2-5')
INSERT [dbo].[BetChoiceMapping] ([BetType], [BetChoice], [TGRSBetChoice]) VALUES (495, N'5-3', N'5-3 & 3-5')
INSERT [dbo].[BetChoiceMapping] ([BetType], [BetChoice], [TGRSBetChoice]) VALUES (495, N'3-5', N'5-3 & 3-5')
INSERT [dbo].[BetChoiceMapping] ([BetType], [BetChoice], [TGRSBetChoice]) VALUES (495, N'5-4', N'5-4 & 4-5')
INSERT [dbo].[BetChoiceMapping] ([BetType], [BetChoice], [TGRSBetChoice]) VALUES (495, N'4-5', N'5-4 & 4-5')
INSERT [dbo].[BetChoiceMapping] ([BetType], [BetChoice], [TGRSBetChoice]) VALUES (495, N'0-0', N'0-0')
INSERT [dbo].[BetChoiceMapping] ([BetType], [BetChoice], [TGRSBetChoice]) VALUES (495, N'1-1', N'1-1')
INSERT [dbo].[BetChoiceMapping] ([BetType], [BetChoice], [TGRSBetChoice]) VALUES (495, N'2-2', N'2-2')
INSERT [dbo].[BetChoiceMapping] ([BetType], [BetChoice], [TGRSBetChoice]) VALUES (495, N'3-3', N'3-3')
INSERT [dbo].[BetChoiceMapping] ([BetType], [BetChoice], [TGRSBetChoice]) VALUES (495, N'4-4', N'4-4')
INSERT [dbo].[BetChoiceMapping] ([BetType], [BetChoice], [TGRSBetChoice]) VALUES (495, N'AOS', N'AOS')
GO
-- Corner Highest Scoring Half
INSERT [dbo].[BetChoiceMapping] ([BetType], [BetChoice], [TGRSBetChoice]) VALUES (496, N'1H', N'First Half')
INSERT [dbo].[BetChoiceMapping] ([BetType], [BetChoice], [TGRSBetChoice]) VALUES (496, N'2H', N'Second Half')
INSERT [dbo].[BetChoiceMapping] ([BetType], [BetChoice], [TGRSBetChoice]) VALUES (496, N'Tie', N'Tie')
GO
-- Corner Highest Scoring Half (2-Way)
INSERT [dbo].[BetChoiceMapping] ([BetType], [BetChoice], [TGRSBetChoice]) VALUES (497, N'1H', N'First Half')
INSERT [dbo].[BetChoiceMapping] ([BetType], [BetChoice], [TGRSBetChoice]) VALUES (497, N'2H', N'Second Half')