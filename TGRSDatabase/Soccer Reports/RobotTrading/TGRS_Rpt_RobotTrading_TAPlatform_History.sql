ALTER PROCEDURE [dbo].[TGRS_Rpt_RobotTrading_TAPlatform_History]
		@IsLess8			BIT = 0	
	,	@IsMonitoringLeague	BIT = 0
	
AS
/*
	Created:	20210420@Adam.Tran
	Task:		Automation Trading - Report Spread 8% Live Performance
	DB:			DBTGRS.bodb_TGRS
	Original:
	
	Revisions:
		- 20210420@Adam.Tran: Created [Redmine ID: 152889]
		
	Param's Explanation:
		- @IsLess8
		- @IsLastWeek
		- @IsMonitoringLeague
		
	Exam: EXECUTE dbo.TGRS_Rpt_RobotTrading_TAPlatform_History @IsLess8 = 1, @IsLastWeek = 0, @IsMonitoringLeague = 0
*/

BEGIN	
	IF @IsMonitoringLeague = 1
	BEGIN		
		SELECT 	ph.Platform
			,	ph.FromDate
			,	ph.ToDate
			,	ph.IsLeagueGroup
			,	ph.LeagueGroupID as LeagueGroupIDHistory	
			,	ph.Event
			,	ph.LeagueID
			,	ph.MatchCount
			,	ph.VarianceTO
			,	ph.VarianceWL
			,	ph.VarianceHDPTO
			,	ph.VarianceHDPWL
			,	ph.VarianceOUTO
			,	ph.VarianceOUWL
			,	ph.Variance1HHDPTO
			,	ph.Variance1HHDPWL
			,	ph.Variance1HOUTO
			,	ph.Variance1HOUWL
			,	ph.VirtualTO
			,	ph.VirtualWL
			,	ph.VirtualHDPTO
			,	ph.VirtualHDPWL
			,	ph.VirtualOUTO
			,	ph.VirtualOUWL
			,	ph.Virtual1HHDPTO
			,	ph.Virtual1HHDPWL
			,	ph.Virtual1HOUTO
			,	ph.Virtual1HOUWL
			,	ph.RealEx8RMTO
			,	ph.RealEx8RMWL
			,	ph.RealEx8RMHDPTO
			,	ph.RealEx8RMHDPWL
			,	ph.RealEx8RMOUTO
			,	ph.RealEx8RMOUWL
			,	ph.RealEx8RM1HHDPTO
			,	ph.RealEx8RM1HHDPWL
			,	ph.RealEx8RM1HOUTO
			,	ph.RealEx8RM1HOUWL
			,	ph.BetCount		
		FROM dbo.TAPlatform_History AS ph WITH(NOLOCK)		
		WHERE ph.IsMonitoringLeague = 1
	END;	
	ELSE
	BEGIN		
		SELECT 	ph.Platform
			,	ph.FromDate
			,	ph.ToDate
			,	ph.IsLeagueGroup
			,	ph.LeagueGroupID as LeagueGroupIDHistory	
			,	ph.Event
			,	ph.LeagueID
			,	ph.MatchCount
			,	ph.VarianceTO
			,	ph.VarianceWL
			,	ph.VarianceHDPTO
			,	ph.VarianceHDPWL
			,	ph.VarianceOUTO
			,	ph.VarianceOUWL
			,	ph.Variance1HHDPTO
			,	ph.Variance1HHDPWL
			,	ph.Variance1HOUTO
			,	ph.Variance1HOUWL
			,	ph.VirtualTO
			,	ph.VirtualWL
			,	ph.VirtualHDPTO
			,	ph.VirtualHDPWL
			,	ph.VirtualOUTO
			,	ph.VirtualOUWL
			,	ph.Virtual1HHDPTO
			,	ph.Virtual1HHDPWL
			,	ph.Virtual1HOUTO
			,	ph.Virtual1HOUWL
			,	ph.RealEx8RMTO
			,	ph.RealEx8RMWL
			,	ph.RealEx8RMHDPTO
			,	ph.RealEx8RMHDPWL
			,	ph.RealEx8RMOUTO
			,	ph.RealEx8RMOUWL
			,	ph.RealEx8RM1HHDPTO
			,	ph.RealEx8RM1HHDPWL
			,	ph.RealEx8RM1HOUTO
			,	ph.RealEx8RM1HOUWL
			,	ph.BetCount		
		FROM dbo.TAPlatform_History AS ph WITH(NOLOCK)		
		WHERE ph.IsMonitoringLeague = 0 AND ph.IsLess8 = @IsLess8
	END;	
	
END;

GO
/*<info serverAlias="DBTGRS-bodb_TGRS" executers="bodbTGRSNet" isFunction="0" isNested="0"></info>*/