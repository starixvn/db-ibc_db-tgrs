/*
	Creator:	20211123@Adam.Tran
	Task:		Basketball - View report to Set X Game Y - [Redmine: #164165]
	DB:			DB06.bodb_TGRS_UAT & DB061.bodb_TGRS
*/

USE bodb_TGRS

ALTER TABLE [dbo].[OSDataTGRS_BetChoice] ADD	
	[betid]			BIGINT	NULL

CREATE TABLE [dbo].[OSBetChoice_QuarterMapping] (
	[BettypeId]			SMALLINT NOT NULL,
	[betid]				BIGINT	NOT NULL,
	[Quarter]			NVARCHAR(100) NOT NULL
)

CREATE CLUSTERED INDEX [CIX_OSBetChoice_QuarterMappingIdx] ON [dbo].[OSBetChoice_QuarterMapping]
(
	[BettypeId]	ASC,
	[betid]		ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [DATA]
	
GO

/*<info serverAlias="DBTGRS-bodb_TGRS" executers="bodbTGRSNet" isFunction="0" isNested="0"></info>*/
