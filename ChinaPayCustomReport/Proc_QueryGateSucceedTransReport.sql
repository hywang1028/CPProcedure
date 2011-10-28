if OBJECT_ID(N'Proc_QueryGateSucceedTransReport', N'P') is not null
begin
	drop procedure Proc_QueryGateSucceedTransReport;
end
go

create procedure Proc_QueryGateSucceedTransReport
	@StartDate datetime = '2011-09-01',
	@PeriodUnit nchar(4) = N'月',
	@MeasureCategory nchar(10) = N'成功金额'
as
begin
--0. Check input params
if (isnull(@PeriodUnit, N'') = N'')
begin
	raiserror('@PeriodUnit cannot be empty.',16,1);	
end

if (@StartDate is null)
begin
	raiserror('@StartDate cannot be empty.', 16, 1);
end

if (ISNULL(@MeasureCategory, N'') = N'')
begin
	raiserror('@MeasureCategory cannot be empty.', 16, 1);
end

--0.1 Prepare StartDate and EndDate
declare @CurrStartDate datetime;
declare @CurrEndDate datetime;
declare @PrevStartDate datetime;
declare @PrevEndDate datetime;
declare @LastYearStartDate datetime;
declare @LastYearEndDate datetime;

if(@PeriodUnit = N'周')
begin
	set @CurrStartDate = @StartDate;
	set @CurrEndDate = DATEADD(week, 1, @StartDate);
	set @PrevStartDate = DATEADD(week, -1, @CurrStartDate);
	set @PrevEndDate = @CurrStartDate;
	set @LastYearStartDate = DATEADD(year, -1, @CurrStartDate);	
	set @LastYearEndDate = DATEADD(year, -1, @CurrEndDate);
end
else if(@PeriodUnit = N'月')
begin
	set @CurrStartDate = @StartDate;
	set @CurrEndDate = DATEADD(MONTH, 1, @StartDate);
	set @PrevStartDate = DATEADD(MONTH, -1, @CurrStartDate);
	set @PrevEndDate = @CurrStartDate;
	set @LastYearStartDate = DATEADD(year, -1, @CurrStartDate);	
	set @LastYearEndDate = DATEADD(year, -1, @CurrEndDate);
end
else if(@PeriodUnit = N'季度')
begin
	set @CurrStartDate = @StartDate;
	set @CurrEndDate = DATEADD(QUARTER, 1, @StartDate);
	set @PrevStartDate = DATEADD(QUARTER, -1, @CurrStartDate);
	set @PrevEndDate = @CurrStartDate;
	set @LastYearStartDate = DATEADD(year, -1, @CurrStartDate);	
	set @LastYearEndDate = DATEADD(year, -1, @CurrEndDate);
end
else if(@PeriodUnit = N'半年')
begin
	set @CurrStartDate = @StartDate;
	set @CurrEndDate = DATEADD(QUARTER, 2, @StartDate);
	set @PrevStartDate = DATEADD(QUARTER, -2, @CurrStartDate);
	set @PrevEndDate = @CurrStartDate;
	set @LastYearStartDate = DATEADD(year, -1, @CurrStartDate);	
	set @LastYearEndDate = DATEADD(year, -1, @CurrEndDate);
end
else if(@PeriodUnit = N'年')
begin
	set @CurrStartDate = @StartDate;
	set @CurrEndDate = DATEADD(YEAR, 1, @StartDate);
	set @PrevStartDate = DATEADD(YEAR, -1, @CurrStartDate);
	set @PrevEndDate = @CurrStartDate;
	set @LastYearStartDate = DATEADD(year, -1, @CurrStartDate);	
	set @LastYearEndDate = DATEADD(year, -1, @CurrEndDate);
end

--1. Get this period trade count/amount
select
	GateNo,
	MerchantNo,
	sum(SucceedTransCount) SumSucceedCount,
	sum(SucceedTransAmount) SumSucceedAmount
into
	#CurrTrans
from
	FactDailyTrans
where
	DailyTransDate >= @CurrStartDate
	and
	DailyTransDate < @CurrEndDate
group by
	GateNo,
	MerchantNo;

--2. Get previous period trade count/amount
select
	GateNo,
	MerchantNo,
	sum(SucceedTransCount) SumSucceedCount,
	sum(SucceedTransAmount) SumSucceedAmount
into
	#PrevTrans
from
	FactDailyTrans
where
	DailyTransDate >= @PrevStartDate
	and
	DailyTransDate < @PrevEndDate
group by
	GateNo,
	MerchantNo;

--3. Get last year same period trade count/amount
select
	GateNo,
	MerchantNo,
	sum(SucceedTransCount) SumSucceedCount,
	sum(SucceedTransAmount) SumSucceedAmount
into
	#LastYearTrans
from
	FactDailyTrans
where
	DailyTransDate >= @LastYearStartDate
	and
	DailyTransDate < @LastYearEndDate
group by
	GateNo,
	MerchantNo;

--4. Get all together
--4.1 Get Sum Value

if @MeasureCategory = N'成功金额'
begin
	create table #SumValue
	(
	GateNo char(4) not null,
	MerchantNo nchar(20) not null,
	CurrSumValue Decimal(12,6) not null,
	PrevSumValue Decimal(12,6) not null,
	LastYearSumValue Decimal(12,6) not null
	);

	insert into #SumValue
	(
		GateNo,
		MerchantNo,
		CurrSumValue,
		PrevSumValue,
		LastYearSumValue
	)
	select
		coalesce(CurrTrans.GateNo, PrevTrans.GateNo, LastYearTrans.GateNo) GateNo,
		coalesce(CurrTrans.MerchantNo, PrevTrans.MerchantNo, LastYearTrans.MerchantNo) MerchantNo,
		(Convert(Decimal,isnull(CurrTrans.SumSucceedAmount, 0))/1000000) CurrSumValue,
		(Convert(Decimal,isnull(PrevTrans.SumSucceedAmount, 0))/1000000) PrevSumValue,
		(Convert(Decimal,ISNULL(LastYearTrans.SumSucceedAmount, 0))/1000000) LastYearSumValue
	from
		#CurrTrans CurrTrans
		full outer join
		#PrevTrans PrevTrans
		on
			CurrTrans.GateNo = PrevTrans.GateNo
			and
			CurrTrans.MerchantNo = PrevTrans.MerchantNo
		full outer join
		#LastYearTrans LastYearTrans
		on
			coalesce(CurrTrans.GateNo, PrevTrans.GateNo) = LastYearTrans.GateNo
			and
			coalesce(CurrTrans.MerchantNo, PrevTrans.MerchantNo) = LastYearTrans.MerchantNo;

select
	DimMerchant.MerchantGroup,
	DimMerchant.MerchantName,
	DimMerchant.MerchantNo,
	DimGate.BankName,
	DimGate.GateNo,
	SumValue.CurrSumValue,
	SumValue.PrevSumValue,
	SumValue.LastYearSumValue
from
	#SumValue SumValue
	inner join
	DimGate
	on
		SumValue.GateNo = DimGate.GateNo
	inner join
	DimMerchant
	on
		SumValue.MerchantNo = DimMerchant.MerchantNo;

	drop table #SumValue;
end
else
begin
	create table #SumCount
	(
	GateNo char(4) not null,
	MerchantNo nchar(20) not null,
	CurrSumValue Decimal(12,3) not null,
	PrevSumValue Decimal(12,3) not null,
	LastYearSumValue Decimal(12,3) not null
	);
	insert into #SumCount
	(
		GateNo,
		MerchantNo,
		CurrSumValue,
		PrevSumValue,
		LastYearSumValue
	)
	select
		coalesce(CurrTrans.GateNo, PrevTrans.GateNo, LastYearTrans.GateNo) GateNo,
		coalesce(CurrTrans.MerchantNo, PrevTrans.MerchantNo, LastYearTrans.MerchantNo) MerchantNo,
		(Convert(Decimal,isnull(CurrTrans.SumSucceedCount, 0))/1000) CurrSumValue,
		(Convert(Decimal,isnull(PrevTrans.SumSucceedCount, 0))/1000) PrevSumValue,
		(Convert(Decimal,ISNULL(LastYearTrans.SumSucceedCount, 0))/1000) LastYearSumValue
	from
		#CurrTrans CurrTrans
		full outer join
		#PrevTrans PrevTrans
		on
			CurrTrans.GateNo = PrevTrans.GateNo
			and
			CurrTrans.MerchantNo = PrevTrans.MerchantNo
		full outer join
		#LastYearTrans LastYearTrans
		on
			coalesce(CurrTrans.GateNo, PrevTrans.GateNo) = LastYearTrans.GateNo
			and
			coalesce(CurrTrans.MerchantNo, PrevTrans.MerchantNo) = LastYearTrans.MerchantNo;
select
	DimMerchant.MerchantGroup,
	DimMerchant.MerchantName,
	DimMerchant.MerchantNo,
	DimGate.BankName,
	DimGate.GateNo,
	SumCount.CurrSumValue,
	SumCount.PrevSumValue,
	SumCount.LastYearSumValue
from
	#SumCount SumCount
	inner join
	DimGate
	on
		SumCount.GateNo = DimGate.GateNo
	inner join
	DimMerchant
	on
		SumCount.MerchantNo = DimMerchant.MerchantNo;

	drop table #SumCount;
end

--4.1 Add Dimension information to final result

		
--5 Clear all temp tables

drop table #LastYearTrans;
drop table #PrevTrans;
drop table #CurrTrans;

End