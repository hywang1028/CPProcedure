if OBJECT_ID(N'Proc_QueryBranchChannelMerchantReport', N'P') is not null
begin
	drop procedure Proc_QueryBranchChannelMerchantReport;
end
go

create procedure Proc_QueryBranchChannelMerchantReport
	@StartDate datetime = '2011-09-01',
	@PeriodUnit nchar(4) = N'月',
	@ChannelName nchar(10) = N'银联',
	@MeasureCategory nchar(10) = N'成功金额'
as
begin

--0.0 Check Input
IF (isnull(@PeriodUnit, N'') = N'') 
BEGIN 
	RAISERROR ('@PeriodUnit cannot be empty.', 16, 1); 
END 
IF (@StartDate IS NULL) 
BEGIN 
RAISERROR ('@StartDate cannot be empty.', 16, 1); 
END 
IF (@ChannelName IS NULL) 
BEGIN 
RAISERROR ('@ChannelName cannot be empty.', 16, 1); 
END 
IF (@MeasureCategory IS NULL) 
BEGIN 
RAISERROR ('@MeasureCategory cannot be empty.', 16, 1); 
END 

--0.1 Prepare StartDate and EndDate
DECLARE @CurrStartDate datetime; 
DECLARE @CurrEndDate datetime; 
DECLARE @PrevStartDate datetime; 
DECLARE @PrevEndDate datetime; 
DECLARE @LastYearStartDate datetime; 
DECLARE @LastYearEndDate datetime; 
IF (@PeriodUnit = N'周') 
BEGIN
	SET @CurrStartDate = @StartDate;
	SET @CurrEndDate = DATEADD(week, 1, @StartDate);
	SET @PrevStartDate = DATEADD(week, - 1, @CurrStartDate);
	SET @PrevEndDate = @CurrStartDate;
	SET @LastYearStartDate = DATEADD(year, - 1, @CurrStartDate);
	SET @LastYearEndDate = DATEADD(year, - 1, @CurrEndDate); 
END 
ELSE IF (@PeriodUnit = N'月') 
BEGIN
	SET @CurrStartDate = @StartDate;
	SET @CurrEndDate = DATEADD(MONTH, 1, @StartDate);
	SET @PrevStartDate = DATEADD(MONTH, - 1, @CurrStartDate);
	SET @PrevEndDate = @CurrStartDate;
	SET @LastYearStartDate = DATEADD(year, - 1, @CurrStartDate);
	SET @LastYearEndDate = DATEADD(year, - 1, @CurrEndDate); 
END 
ELSE IF (@PeriodUnit = N'季度') 
BEGIN
	SET @CurrStartDate = @StartDate;
	SET @CurrEndDate = DATEADD(QUARTER, 1, @StartDate);
	SET @PrevStartDate = DATEADD(QUARTER, - 1, @CurrStartDate);
	SET @PrevEndDate = @CurrStartDate;
	SET @LastYearStartDate = DATEADD(year, - 1, @CurrStartDate);
	SET @LastYearEndDate = DATEADD(year, - 1, @CurrEndDate); 
END 
ELSE IF (@PeriodUnit = N'半年') 
BEGIN
	SET @CurrStartDate = @StartDate;
	SET @CurrEndDate = DATEADD(QUARTER, 2, @StartDate);
	SET @PrevStartDate = DATEADD(QUARTER, - 2, @CurrStartDate);
	SET @PrevEndDate = @CurrStartDate;
	SET @LastYearStartDate = DATEADD(year, - 1, @CurrStartDate);
	SET @LastYearEndDate = DATEADD(year, - 1, @CurrEndDate); 
END 
ELSE IF (@PeriodUnit = N'年') 
BEGIN
	SET @CurrStartDate = @StartDate;
	SET @CurrEndDate = DATEADD(YEAR, 1, @StartDate);
	SET @PrevStartDate = DATEADD(YEAR, - 1, @CurrStartDate);
	SET @PrevEndDate = @CurrStartDate;
	SET @LastYearStartDate = DATEADD(year, - 1, @CurrStartDate);
	SET @LastYearEndDate = DATEADD(year, - 1, @CurrEndDate); 
END

--1. Get this period trade count/amount
SELECT 
	GateNo,
	MerchantNo, 
    sum(SucceedTransCount) SumSucceedCount, 
    sum(SucceedTransAmount) SumSucceedAmount
INTO 
	#CurrTrans
FROM 
	FactDailyTrans
WHERE 
	DailyTransDate >= @CurrStartDate 
	AND 
    DailyTransDate < @CurrEndDate
GROUP BY 
	GateNo,
	MerchantNo;
        
--2. Get previous period trade count/amount
SELECT 
	GateNo,
	MerchantNo, 
	sum(SucceedTransCount) SumSucceedCount, 
	sum(SucceedTransAmount) SumSucceedAmount
INTO 
	#PrevTrans
FROM 
	FactDailyTrans
WHERE 
	DailyTransDate >= @PrevStartDate 
	AND 
    DailyTransDate < @PrevEndDate
GROUP BY 
	GateNo,
	MerchantNo;
					
--3. Get last year same period trade count/amount
SELECT 
	GateNo,
	MerchantNo,
    sum(SucceedTransCount) SumSucceedCount, 
    sum(SucceedTransAmount) SumSucceedAmount
INTO 
	#LastYearTrans
FROM 
	FactDailyTrans
WHERE 
	DailyTransDate >= @LastYearStartDate 
	AND 
    DailyTransDate < @LastYearEndDate
GROUP BY 
	GateNo,
	MerchantNo; 
                        
--4.1 Get Sum Value	   
IF @MeasureCategory = N'成功金额' 
BEGIN
CREATE TABLE #SumValue(
  GateNo char(4) NOT NULL, 
  MerchantNo char(20) NOT NULL, 
  CurrSumValue Decimal(12,6) NOT NULL, 
  PrevSumValue Decimal(12,6) NOT NULL, 
  LastYearSumValue Decimal(12,6) NOT NULL
  );	
  
INSERT INTO #SumValue(
  GateNo, 
  MerchantNo, 
  CurrSumValue, 
  PrevSumValue, 
  LastYearSumValue
  )
SELECT 
	COALESCE (CurrTrans.GateNo, PrevTrans.GateNo, LastYearTrans.GateNo) GateNo, 
	COALESCE (CurrTrans.MerchantNo, PrevTrans.MerchantNo, LastYearTrans.MerchantNo) MerchantNo, 
	(Convert(Decimal,isnull(CurrTrans.SumSucceedAmount, 0))/1000000) CurrSumValue, 
	(Convert(Decimal,isnull(PrevTrans.SumSucceedAmount, 0))/1000000) PrevSumValue, 
	(Convert(Decimal,ISNULL(LastYearTrans.SumSucceedAmount, 0))/1000000) LastYearSumValue
FROM 
	#CurrTrans CurrTrans 
	FULL OUTER JOIN
	  #PrevTrans PrevTrans 
	  ON 
		CurrTrans.GateNo = PrevTrans.GateNo 
		AND 
	    CurrTrans.MerchantNo = PrevTrans.MerchantNo 
	FULL OUTER JOIN
	  #LastYearTrans LastYearTrans 
	  ON 
		coalesce(CurrTrans.GateNo, PrevTrans.GateNo) = LastYearTrans.GateNo 
		AND 
	    coalesce(CurrTrans.MerchantNo, PrevTrans.MerchantNo) = LastYearTrans.MerchantNo;
	    
SELECT
   BranchChannel.Area SubChannel,
   BranchChannel.BranchOffice,
   BranchChannel.MerchantName,
   BranchChannel.MerchantNo, 
   DimGate.BankName, 
   DimGate.GateNo, 
   SumValue.CurrSumValue, 
   SumValue.PrevSumValue, 
   SumValue.LastYearSumValue
FROM 
	#SumValue SumValue 
	INNER JOIN 
	Table_BizDeptBranchChannel BranchChannel
	on
		SumValue.MerchantNo = BranchChannel.MerchantNo
	inner join
	DimGate
	on
		SumValue.GateNo = DimGate.GateNo
WHERE
	BranchChannel.Channel = @ChannelName; 

DROP TABLE #SumValue; 
END 
ELSE 
	BEGIN
	CREATE TABLE #SumCount(
	  GateNo char(4) NOT NULL, 
	  MerchantNo char(20) NOT NULL, 
	  CurrSumValue Decimal(12,3) NOT NULL, 
	  PrevSumValue Decimal(12,3) NOT NULL, 
	  LastYearSumValue Decimal(12,3) NOT NULL
	  );
	  
	INSERT INTO #SumCount(
		GateNo, 
		MerchantNo, 
		CurrSumValue, 
		PrevSumValue, 
		LastYearSumValue)
		
	SELECT 
			COALESCE (CurrTrans.GateNo, PrevTrans.GateNo,  LastYearTrans.GateNo) GateNo, 
			COALESCE (CurrTrans.MerchantNo,PrevTrans.MerchantNo, LastYearTrans.MerchantNo) MerchantNo, 
			(Convert(Decimal,isnull(CurrTrans.SumSucceedCount,0))/1000) CurrSumValue, 
			(Convert(Decimal,isnull(PrevTrans.SumSucceedCount,0))/1000) PrevSumValue, 
			(Convert(Decimal,ISNULL(LastYearTrans.SumSucceedCount,0))/1000) LastYearSumValue
	FROM 
			#CurrTrans CurrTrans 
		FULL OUTER JOIN
			#PrevTrans PrevTrans 
		ON 
				CurrTrans.GateNo = PrevTrans.GateNo
				AND 
				CurrTrans.MerchantNo = PrevTrans.MerchantNo
		FULL OUTER JOIN
			#LastYearTrans LastYearTrans 
		ON
				coalesce(CurrTrans.GateNo, PrevTrans.GateNo) = LastYearTrans.GateNo
				AND 
				coalesce(CurrTrans.MerchantNo, PrevTrans.MerchantNo) = LastYearTrans.MerchantNo;
	
	SELECT
	   BranchChannel.Area SubChannel,
	   BranchChannel.BranchOffice,
	   BranchChannel.MerchantName,
	   BranchChannel.MerchantNo, 
	   DimGate.BankName, 
	   DimGate.GateNo, 
	   SumCount.CurrSumValue, 
	   SumCount.PrevSumValue, 
	   SumCount.LastYearSumValue
  FROM 
		#SumCount SumCount 
		INNER JOIN 
		Table_BizDeptBranchChannel BranchChannel
		on
			SumCount.MerchantNo = BranchChannel.MerchantNo
		inner join
		DimGate
		on
			SumCount.GateNo = DimGate.GateNo
	WHERE 
		BranchChannel.Channel = @ChannelName; 
	
	DROP TABLE #SumCount;
	END
		
--4.1 Add Dimension information to final result
	  
--5 Clear all temp tables
DROP TABLE #LastYearTrans;
DROP TABLE #PrevTrans; 
DROP TABLE #CurrTrans;

End