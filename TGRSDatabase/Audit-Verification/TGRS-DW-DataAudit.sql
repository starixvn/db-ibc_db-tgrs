/*  
    Created: Dominic@20170731 
    Description: Juice and Leftover WL - Check data between DW and TGRS
    Input Param (Already Input From SSIS Package): 
				
			 --Declaration for Unit Testing
			 DECLARE @FDate DATE = '20170725'
			 DECLARE @TDate DATE = '20170730'
						
    Output Param (Already Input From SSIS Package): 
				
			 --Declaration for Unit Testing
			 DECLARE @Passed BIT = 0
			 DECLARE @ErrMsg NVARCHAR(max) = ''

	Database:	DBDW2.bodb_Account

    Revision:

*/
SET NOCOUNT ON;

DECLARE	@FDate		DATE			= '20170601'
	,	@TDate		DATE			= '20170630'
	;
		
--Declaration for Unit Testing
DECLARE	@Passed		BIT = 0
	,	@ErrMsg		NVARCHAR(MAX)	= ''
	;

SELECT	@Passed		= 1
	,	@ErrMsg		= ''
	;

DECLARE	@_Date		DATE			= @FDate
	;

/*
--check from balance-up date to before yesterday
SELECT TOP 1 @_Date = Winlostdate
FROM DBACC.bodb02.dbo.Bettrans WITH (NOLOCK)
WHERE bettype = 20000 AND matchid = 0 AND custid = 3
*/

IF	OBJECT_ID('tempdb..#Data') IS NOT NULL
	DROP TABLE	#Data;

CREATE TABLE	#Data (
					Source			VARCHAR(50)
				,	DimensionID		INT
				,	HouseWL			DECIMAL(19,6)
				,	HouseWL_Virtual	DECIMAL(19,6)
				);

IF	OBJECT_ID('tempdb..#Juice') IS NOT NULL
	DROP TABLE	#Juice;

CREATE TABLE	#Juice (
					Source			VARCHAR(50)
				,	DimensionID		INT
				,	JuiceWL			MONEY
				,	JuiceTO			MONEY
				,	IBC_TO_MY		MONEY
				,	CompanyIncome	MONEY
				);
				
IF	OBJECT_ID('tempdb..#ExtraPT') IS NOT NULL
	DROP TABLE	#ExtraPT;

CREATE TABLE	#ExtraPT (
					DimensionID		INT
				,	ExtraWL			DECIMAL(19,6)
				,	ExtraWL_Virtual	DECIMAL(19,6)
				);


WHILE	@_Date <= @TDate
BEGIN;
	PRINT	@_Date;

    -- Check duplicated trader assignments - START --
    IF	EXISTS (
		   SELECT	t.matchid, map.TicketBettype
		   FROM			bodb02.dbo.Dot_Admin_Assignment_Operator AS t WITH (NOLOCK)
		   INNER JOIN	bodb_Account.dbo.TradingBettypeMapping AS map WITH (NOLOCK)
					ON	t.OperatorType = map.OperatorType
					AND	CASE WHEN t.bettype=23 THEN 1 ELSE t.bettype END = map.TradingBettype
		   WHERE	t.OperatorID > 3
				AND	t.matchid IN (SELECT t.matchid FROM bodb_staging.dbo.match WITH (NOLOCK) WHERE eventdate = CAST(@_Date AS DATETIME))
		   GROUP BY t.matchid, map.TicketBettype
		   HAVING	COUNT(1) > 1 
			--AND	MIN(operatorID) <> MAX(operatorID)
		)
    BEGIN;
		SELECT	@ErrMsg = @ErrMsg + N'- There are duplicated trader assignments.(' + CAST(@_Date AS NVARCHAR(15)) + ')</br>'
			,	@Passed = 0
			;
    END;

	RAISERROR('	Check duplicated trader assignments.', 0, 0) WITH NOWAIT;
    -- Check duplicated trader assignments - END --


    -- Check JuiceWL By by TraderID - START --
	INSERT INTO	#Juice
		(	  Source, DimensionID, JuiceWL     , JuiceTO             , IBC_TO_MY      , CompanyIncome          )
	SELECT	t.Source, t.custid   , SUM(t.Juice), SUM(t.StakeMYRJuice), SUM(t.StakeMYR), SUM(t.WinLost - t.Comm)
	FROM	(
		SELECT	'Source' = 'TGRS', 'custid' = CASE WHEN t.custid=0 THEN -1 ELSE t.custid END, t.Juice, t.StakeMYRJuice, t.StakeMYR, t.WinLost, t.Comm
		FROM	DBACC.bodb_TGRS.dbo.TraderPerformance AS t WITH (NOLOCK)
		WHERE	t.EventDate = @_Date
			AND	t.Juice IS NOT NULL
		UNION ALL
		SELECT	'Source' = 'TGRS', 'custid' = t.TraderId, t.Juice, t.StakeMYRJuice, t.StakeMYR, t.Winloss, t.Comm 
		FROM	DBACC.bodb_TGRS.dbo.OSDataTGRS AS t WITH (NOLOCK)
		WHERE	t.EventDate = @_Date
			AND	t.Juice IS NOT NULL
	) AS t
	GROUP BY t.Source, t.custid;

	INSERT INTO	#Juice
		(	Source, DimensionID, JuiceWL             , JuiceTO                , IBC_TO_MY                  , CompanyIncome                            )
	SELECT 'DW'   , t.TraderID , SUM(JuiceWL_Virtual), SUM(JuiceTO_MY_Virtual), SUM(TurnoverIBC_MY_Virtual), SUM(JuiceWL_Virtual + LeftoverWL_Virtual)
	FROM	bodb_Account.dbo.rptJuiceLeftover AS t WITH (NOLOCK)
	WHERE	rptdate = CAST(@_Date AS DATETIME)
		AND	islive = 1 
		AND	(TraderID <> -1 OR (Sporttype = 1 AND Bettype IN (1,3,7,8)))
		AND	1 = CASE WHEN t.sporttype = 1 AND bettype IN (2,12) THEN 0 ELSE 1 END
		AND	t.BetType IN (1, 3, 7, 8, 2, 12)
	GROUP BY t.TraderID;

	IF	EXISTS (
			SELECT	1 
			FROM	#Juice
			GROUP BY DimensionID
			HAVING	MAX(JuiceTO) - MIN(JuiceTO) > 0.05
				OR	MAX(IBC_TO_MY) - MIN(IBC_TO_MY) > 0.05
				OR	ABS(MAX(JuiceWL) + MIN(JuiceWL)) > 0.05
				--OR	ABS(MAX(CompanyIncome) + MIN(CompanyIncome)) > 0.7
				OR	COUNT(1) < 2
		)
	BEGIN;
		SELECT	@ErrMsg = @ErrMsg + N'- JuiceWL/JuiceTO/IBC_TO_MY By TraderID is different between <b>DW</b> AND <b>TGRS</b>.(' + CAST(@_Date AS NVARCHAR(15)) + ')</br>'
			,	@Passed = 0
			;
	END;

	RAISERROR('	Check JuiceWL By by TraderID.', 0, 0) WITH NOWAIT;
    -- Check JuiceWL By by TraderID - END --


    TRUNCATE TABLE #Juice;

    -- Check JuiceWL By by matchID - START --
	INSERT INTO #Juice
		(	  Source, DimensionID, JuiceWL     , JuiceTO             , IBC_TO_MY      , CompanyIncome          )
	SELECT	t.Source, t.matchid  , SUM(t.Juice), SUM(t.StakeMYRJuice), SUM(t.StakeMYR), SUM(t.WinLost - t.Comm)
	FROM	(
		SELECT	'Source' = 'TGRS', 'matchid' = t.matchid, t.Juice, t.StakeMYRJuice, t.StakeMYR, t.WinLost, t.Comm
		FROM	DBACC.bodb_TGRS.dbo.TraderPerformance AS t WITH (NOLOCK)
		WHERE	t.EventDate = @_Date
			AND	t.Juice IS NOT NULL
		UNION ALL
		SELECT	'Source' = 'TGRS', 'matchid' = t.matchid, t.Juice, t.StakeMYRJuice, t.StakeMYR, t.Winloss, t.Comm 
		FROM	DBACC.bodb_TGRS.dbo.OSDataTGRS AS t WITH (NOLOCK)
		WHERE	t.EventDate = @_Date
			AND t.Juice IS NOT NULL
	) AS t
	GROUP BY t.Source, t.matchid;

	INSERT INTO #Juice
		(	Source, DimensionID, JuiceWL             , JuiceTO                , IBC_TO_MY                  , CompanyIncome                           )
	SELECT 'DW'   , t.matchid  , SUM(JuiceWL_Virtual), SUM(JuiceTO_MY_Virtual), SUM(TurnoverIBC_MY_Virtual),SUM(JuiceWL_Virtual + LeftoverWL_Virtual)
	FROM	bodb_Account.dbo.rptJuiceLeftover AS t WITH (NOLOCK)
	WHERE	rptdate = CAST(@_Date AS DATETIME)
		AND	islive = 1 
		AND	(TraderID <> -1 OR (Sporttype = 1 AND Bettype IN (1, 3, 7, 8)))
		AND	1 = CASE WHEN t.sporttype = 1 AND bettype IN (2, 12) THEN 0 ELSE 1 END
		AND	t.BetType IN (1, 3, 7, 8, 2, 12)
	GROUP BY t.matchid;

	IF	EXISTS (
			SELECT	1 
			FROM	#Juice
			GROUP BY DimensionID
			HAVING	MAX(JuiceTO) - MIN(JuiceTO) > 0.05
				OR	MAX(IBC_TO_MY) - MIN(IBC_TO_MY) > 0.05
				OR	ABS(MAX(JuiceWL) + MIN(JuiceWL)) > 0.05
				--OR	ABS(MAX(CompanyIncome) + MIN(CompanyIncome)) > 0.7
				OR	COUNT(1) < 2
		)
	BEGIN;
		SELECT	@ErrMsg = @ErrMsg + N'- JuiceWL/JuiceTO/IBC_TO_MY By MatchID is different between <b>DW</b> AND <b>TGRS</b>.(' + CAST(@_Date AS NVARCHAR(15)) + ')</br>'
			,	@Passed = 0
			;
	END;
	
	RAISERROR('	Check JuiceWL By by matchID.', 0, 0) WITH NOWAIT;
    -- Check JuiceWL By by matchID - END --
			

    TRUNCATE TABLE #Juice;
	
    -- Check JuiceWL By by sporttype - START 
	INSERT INTO		#Juice
		(	  Source, DimensionID, JuiceWL     , JuiceTO             , IBC_TO_MY      , CompanyIncome          )
	SELECT	t.Source, t.sporttype, SUM(t.Juice), SUM(t.StakeMYRJuice), SUM(t.StakeMYR), SUM(t.WinLost - t.Comm)
	FROM	(
		SELECT	'Source' = 'TGRS', 'sporttype' = t.sporttype, t.Juice, t.StakeMYRJuice, t.StakeMYR, t.WinLost, t.Comm
		FROM	DBACC.bodb_TGRS.dbo.TraderPerformance AS t WITH (NOLOCK)
		WHERE	t.EventDate = @_Date
			AND	t.Juice IS NOT NULL
		UNION ALL
		SELECT	'Source' = 'TGRS', 'sporttype' = t.SportId, t.Juice, t.StakeMYRJuice, t.StakeMYR, t.Winloss, t.Comm 
		FROM	DBACC.bodb_TGRS.dbo.OSDataTGRS AS t WITH (NOLOCK)
		WHERE	t.EventDate = @_Date
			AND	t.Juice IS NOT NULL
	) AS t
	GROUP BY t.Source,t.sporttype;

	INSERT INTO #Juice
		(	Source, DimensionID, JuiceWL             , JuiceTO                , IBC_TO_MY                  , CompanyIncome                            )
	SELECT 'DW'   , t.sporttype, SUM(JuiceWL_Virtual), SUM(JuiceTO_MY_Virtual), SUM(TurnoverIBC_MY_Virtual), SUM(JuiceWL_Virtual + LeftoverWL_Virtual)
	FROM	bodb_Account.dbo.rptJuiceLeftover AS t WITH (NOLOCK)
	WHERE	rptdate = CAST(@_Date AS DATETIME)
		AND	islive = 1 
		AND	(TraderID <> -1 OR (Sporttype = 1 AND Bettype IN (1, 3, 7, 8)))
		AND	1 = CASE WHEN t.sporttype = 1 AND bettype IN (2, 12) THEN 0 ELSE 1 END
		AND	t.BetType IN (1, 3, 7, 8, 2, 12)
	GROUP BY t.sporttype;

	IF	EXISTS (
			SELECT	1 
			FROM	#Juice
			GROUP BY DimensionID
			HAVING	MAX(JuiceTO) - MIN(JuiceTO) > 0.6
				OR	MAX(IBC_TO_MY) - MIN(IBC_TO_MY) > 0.5
				OR	ABS(MAX(JuiceWL) + MIN(JuiceWL)) > 0.5
				--OR	ABS(MAX(CompanyIncome) + MIN(CompanyIncome)) > 0.7
				OR	COUNT(1) < 2
		)
	BEGIN;
		SELECT	@ErrMsg = @ErrMsg + N'- JuiceWL/JuiceTO/IBC_TO_MY By sporttype is different between <b>DW</b> AND <b>TGRS</b>.(' + CAST(@_Date AS NVARCHAR(15)) + ')</br>'
			,	@Passed = 0
			;
	END;
	
	RAISERROR('	Check JuiceWL By by sporttype.', 0, 0) WITH NOWAIT;
    -- Check JuiceWL By by sporttype - END --
			

    -- Check House Net Income By by matchID - START --
	INSERT INTO #Data
		(	Source       , DimensionID, HouseWL                                       , HouseWL_Virtual                                 )
	SELECT	'mcsitedaily', matchid    , -SUM((b.WinlossIBC + b.CommissionS) * ex.rate), -SUM(b.WinlossIBCVirtual + b.CommissionSVirtual) 
	FROM		bodb_Account.dbo.mcSiteDaily AS b WITH (NOLOCK)
	INNER JOIN	bodb_Account.dbo.tbl_Currency_Daily AS ex WITH (NOLOCK)
			ON	ex.Currency = b.CurrencyID
			AND	ex.exchangedate = b.rptdate
	WHERE	b.rptdate = CAST(@_Date AS DATETIME)
		AND	bettype IN (1, 3, 7, 8, 2, 12)
		AND	currency NOT IN (20, 27, 28)
		AND	status IN (4, 8, 12, 13)
	GROUP BY matchid;

	INSERT INTO	#ExtraPT
		(	DimensionID, ExtraWL                  , ExtraWL_Virtual               )
	SELECT	MatchId    , -SUM(ExtraWLAfterComm_RM), -SUM(ExtraWLAfterComm_Virtual)
	FROM	bodb_Account.dbo.rptExtraShare AS b WITH (NOLOCK)
	WHERE	b.rptdate = @_Date
		AND bettype IN (1, 3, 7, 8, 2, 12)
		AND currency NOT IN (20, 27, 28)
		AND statusid IN (4, 8, 12, 13)
	GROUP BY matchid;

	UPDATE	main
	SET		main.HouseWL			= main.HouseWL - ISNULL(ExtraWL, 0)
		,	main.HouseWL_Virtual	= main.HouseWL_Virtual - ISNULL(ExtraWL_Virtual, 0)
	FROM		#Data AS main
	LEFT JOIN	#ExtraPT AS ex
			ON	main.DimensionID = ex.DimensionID;

	INSERT INTO	#Data
		(	Source            , DimensionID, HouseWL                         , HouseWL_Virtual                           )
	SELECT	'rptJuiceLeftover', matchid    , -SUM(JuiceWL_RM + LeftoverWL_RM), -SUM(JuiceWL_Virtual + LeftoverWL_Virtual) 
	FROM	bodb_Account.dbo.rptJuiceLeftover WITH (NOLOCK)
	WHERE	rptdate = @_Date
	GROUP BY Matchid;

	IF	EXISTS (
			SELECT	1 
			FROM	#Data
			GROUP BY DimensionID
			HAVING	ABS(MAX(HouseWL) - MIN(HouseWL)) > 0.05
				--OR	ABS(MAX(HouseWL_Virtual) - MIN(HouseWL_Virtual)) > 0.7
				OR	COUNT(1) < 2
		)
	BEGIN;
		SELECT	@ErrMsg = @ErrMsg + N'- House Net Income By MatchID is different between <b>rptJuiceLeftover</b> AND <b>mcsitedaily</b>.(' + CAST(@_Date AS NVARCHAR(15)) + ')</br>'
			,	@Passed = 0;
	END;
	
	RAISERROR('	Check House Net Income By by matchID.', 0, 0) WITH NOWAIT;
    -- Check House Net Income By by matchID - END --
			

    TRUNCATE TABLE	#Data;	
    TRUNCATE TABLE	#ExtraPT;

    -- Check House Net Income By by Bettype - START --
	INSERT INTO	#Data
		(	Source      , DimensionID, HouseWL                                       , HouseWL_Virtual								   )
	SELECT 'mcsitedaily', bettype    , -SUM((b.WinlossIBC + b.CommissionS) * ex.rate), -SUM(b.WinlossIBCVirtual + b.CommissionSVirtual) 
	FROM		bodb_Account.dbo.mcSiteDaily AS b WITH (NOLOCK)
	INNER JOIN	bodb_Account.dbo.tbl_Currency_Daily AS ex WITH (NOLOCK)
			ON	ex.Currency = b.CurrencyID
			AND	ex.exchangedate = b.rptdate
	WHERE	b.rptdate = CAST(@_Date AS DATETIME)
		AND	bettype IN (1, 3, 7, 8, 2, 12)
		AND	currency NOT IN (20, 27, 28)
		AND	status IN (4, 8, 12, 13)
	GROUP BY bettype;

	INSERT INTO	#ExtraPT
		(	DimensionID, ExtraWL                  , ExtraWL_Virtual               )
	SELECT	bettype    , -SUM(ExtraWLAfterComm_RM), -SUM(ExtraWLAfterComm_Virtual)
	FROM	bodb_Account.dbo.rptExtraShare AS b WITH (NOLOCK)
	WHERE	b.rptdate = @_Date
		AND	bettype IN (1, 3, 7, 8, 2, 12)
		AND	currency NOT IN (20, 27, 28)
		AND	statusid IN (4, 8, 12, 13)
	GROUP BY bettype;

	UPDATE	main
	SET		main.HouseWL			= main.HouseWL - ISNULL(ExtraWL, 0)
		,	main.HouseWL_Virtual	= main.HouseWL_Virtual - ISNULL(ExtraWL_Virtual, 0)
	FROM		#Data AS main
	LEFT JOIN	#ExtraPT AS ex
			ON	main.DimensionID = ex.DimensionID;

	INSERT INTO	#Data
		(	Source            , DimensionID, HouseWL                         , HouseWL_Virtual                           )
	SELECT	'rptJuiceLeftover', bettype    , -SUM(JuiceWL_RM + LeftoverWL_RM), -SUM(JuiceWL_Virtual + LeftoverWL_Virtual) 
	FROM	bodb_Account.dbo.rptJuiceLeftover WITH (NOLOCK)
	WHERE	rptdate = @_Date
	GROUP BY bettype;

	IF	EXISTS (
			SELECT	1 
			FROM	#Data
			GROUP BY DimensionID
			HAVING	ABS(MAX(HouseWL) - MIN(HouseWL)) > 0.5
					--OR	ABS(MAX(HouseWL_Virtual) - MIN(HouseWL_Virtual)) > 5
				OR	COUNT(1) < 2
		)
	BEGIN;
		SELECT	@ErrMsg = @ErrMsg + N'- House Net Income By Bettype is different between <b>rptJuiceLeftover</b> AND <b>mcsitedaily</b>.(' + CAST(@_Date AS NVARCHAR(15)) + ')</br>'
			,	@Passed = 0;
	END;
	
	RAISERROR('	Check House Net Income By by Bettype.', 0, 0) WITH NOWAIT;
    -- Check House Net Income By by Bettype - END --
		

    SELECT	@_Date = DATEADD(DAY, 1, @_Date);
	
    TRUNCATE TABLE	#Data;
    TRUNCATE TABLE	#Juice;	
    TRUNCATE TABLE	#ExtraPT;

	IF	@Passed = 1
		RAISERROR('OK!', 0, 0) WITH NOWAIT;
	ELSE
		RAISERROR('~~ NG! ~~', 0, 0) WITH NOWAIT;
END;

DROP TABLE	#Data;
DROP TABLE	#Juice;
DROP TABLE	#ExtraPT;	

SELECT	'@Passed' = @Passed
	,	'@ErrMsg' = @ErrMsg
	;