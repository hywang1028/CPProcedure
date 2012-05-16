if OBJECT_ID(N'Proc_QueryGateSucceedTransReport', N'P') is not null
begin
	drop procedure Proc_QueryGateSucceedTransReport;
end
go

create procedure Proc_QueryGateSucceedTransReport
	@StartDate datetime = '2011-09-01',
	@PeriodUnit nchar(4) = N'年',
	@EndDate datetime = '2011-10-01',
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

if (@PeriodUnit = N'自定义' and @EndDate is null)
begin
	raiserror('@EndDate cannot be empty.', 16, 1);
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
else if(@PeriodUnit = N'自定义')
begin
	set @CurrStartDate = @StartDate;
    set @CurrEndDate = DateAdd(day,1,@EndDate);
    set @PrevStartDate = DATEADD(DAY, -1*datediff(day,@CurrStartDate,@CurrEndDate), @CurrStartDate);
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
	#CurrPayTrans
from
	FactDailyTrans
where
	DailyTransDate >= @CurrStartDate
	and
	DailyTransDate < @CurrEndDate
group by
	GateNo,
	MerchantNo;

select
	BankSettingID as GateNo,
	MerchantNo,
	sum(TransCount) SumSucceedCount,
	sum(TransAmount) SumSucceedAmount
into
	#CurrOraTrans
from
	Table_OraTransSum
where
	CPDate >= @CurrStartDate
	and
	CPDate < @CurrEndDate
group by
	BankSettingID,
	MerchantNo;
	
--2. Get previous period trade count/amount
select
	GateNo,
	MerchantNo,
	sum(SucceedTransCount) SumSucceedCount,
	sum(SucceedTransAmount) SumSucceedAmount
into
	#PrevPayTrans
from
	FactDailyTrans
where
	DailyTransDate >= @PrevStartDate
	and
	DailyTransDate < @PrevEndDate
group by
	GateNo,
	MerchantNo;

select
	BankSettingID as GateNo,
	MerchantNo,
	sum(TransCount) SumSucceedCount,
	sum(TransAmount) SumSucceedAmount
into
	#PrevOraTrans
from
	Table_OraTransSum
where
	CPDate >= @PrevStartDate
	and
	CPDate < @PrevEndDate
group by
	BankSettingID,
	MerchantNo;
--3. Get last year same period trade count/amount
select
	GateNo,
	MerchantNo,
	sum(SucceedTransCount) SumSucceedCount,
	sum(SucceedTransAmount) SumSucceedAmount
into
	#LastYearPayTrans
from
	FactDailyTrans
where
	DailyTransDate >= @LastYearStartDate
	and
	DailyTransDate < @LastYearEndDate
group by
	GateNo,
	MerchantNo;

select
	BankSettingID as GateNo,
	MerchantNo,
	sum(TransCount) SumSucceedCount,
	sum(TransAmount) SumSucceedAmount
into
	#LastYearOraTrans
from
	Table_OraTransSum
where
	CPDate >= @LastYearStartDate
	and
	CPDate < @LastYearEndDate
group by
	BankSettingID,
	MerchantNo;
--4. Get all together
--4.1 Get Sum Value
if @MeasureCategory = N'成功金额'
begin
	create table #SumValue
	(
		TypeName char(4) not null,
		GateNo char(10) not null,
		MerchantNo nchar(20) not null,
		CurrSumValue Decimal(15,4) not null,
		PrevSumValue Decimal(15,4) not null,
		LastYearSumValue Decimal(15,4) not null
	);

	insert into #SumValue
	(
		TypeName,
		GateNo,
		MerchantNo,
		CurrSumValue,
		PrevSumValue,
		LastYearSumValue
	)
	select
		N'Pay' as TypeName,
		coalesce(CurrTrans.GateNo, PrevTrans.GateNo, LastYearTrans.GateNo) GateNo,
		coalesce(CurrTrans.MerchantNo, PrevTrans.MerchantNo, LastYearTrans.MerchantNo) MerchantNo,
		(Convert(Decimal,ISNULL(CurrTrans.SumSucceedAmount, 0))/1000000) CurrSumValue,
		(Convert(Decimal,ISNULL(PrevTrans.SumSucceedAmount, 0))/1000000) PrevSumValue,
		(Convert(Decimal,ISNULL(LastYearTrans.SumSucceedAmount, 0))/1000000) LastYearSumValue
	from
		#CurrPayTrans CurrTrans
		full outer join
		#PrevPayTrans PrevTrans
		on
			CurrTrans.GateNo = PrevTrans.GateNo
			and
			CurrTrans.MerchantNo = PrevTrans.MerchantNo
		full outer join
		#LastYearPayTrans LastYearTrans
		on
			coalesce(CurrTrans.GateNo, PrevTrans.GateNo) = LastYearTrans.GateNo
			and
			coalesce(CurrTrans.MerchantNo, PrevTrans.MerchantNo) = LastYearTrans.MerchantNo
	union all
	select
		N'Ora' as TypeName,
		coalesce(CurrTrans.GateNo, PrevTrans.GateNo, LastYearTrans.GateNo) GateNo,
		coalesce(CurrTrans.MerchantNo, PrevTrans.MerchantNo, LastYearTrans.MerchantNo) MerchantNo,
		(Convert(Decimal,ISNULL(CurrTrans.SumSucceedAmount, 0))/1000000) CurrSumValue,
		(Convert(Decimal,ISNULL(PrevTrans.SumSucceedAmount, 0))/1000000) PrevSumValue,
		(Convert(Decimal,ISNULL(LastYearTrans.SumSucceedAmount, 0))/1000000) LastYearSumValue
	from
		#CurrOraTrans CurrTrans
		full outer join
		#PrevOraTrans PrevTrans
		on
			CurrTrans.GateNo = PrevTrans.GateNo
			and
			CurrTrans.MerchantNo = PrevTrans.MerchantNo
		full outer join
		#LastYearOraTrans LastYearTrans
		on
			coalesce(CurrTrans.GateNo, PrevTrans.GateNo) = LastYearTrans.GateNo
			and
			coalesce(CurrTrans.MerchantNo, PrevTrans.MerchantNo) = LastYearTrans.MerchantNo;

	select
		Mer.MerchantName,
		SumValue.MerchantNo,
		ISNULL(case when Gate.GateCategory1 = '#N/A' then NULL else Gate.GateCategory1 End,N'其他') GateCategory,
		SumValue.GateNo,
		SumValue.CurrSumValue,
		SumValue.PrevSumValue,
		SumValue.LastYearSumValue
	from
		#SumValue SumValue
		left join
		Table_GateCategory Gate
		on
			SumValue.GateNo = Gate.GateNo
		left join
		Table_MerInfo Mer
		on
			SumValue.MerchantNo = Mer.MerchantNo
	where
		TypeName = N'Pay'
	union all
	select
		Mer.MerchantName,
		SumValue.MerchantNo,
		N'代付' as GateCategory,
		Gate.BankName,
		ISNULL(SUM(SumValue.CurrSumValue),0) CurrSumValue,
		ISNULL(SUM(SumValue.PrevSumValue),0) PrevSumValue,
		ISNULL(SUM(SumValue.LastYearSumValue),0) LastYearSumValue
	from
		#SumValue SumValue
		left join
		Table_OraBankSetting Gate
		on
			SumValue.GateNo = Gate.BankSettingID
		left join
		Table_OraMerchants Mer
		on
			SumValue.MerchantNo = Mer.MerchantNo
	where
		TypeName = N'Ora'
	group by
		Mer.MerchantName,
		SumValue.MerchantNo,
		Gate.BankName;

	drop table #SumValue;
end
else
begin
	create table #SumCount
	(
		TypeName char(4) not null,
		GateNo char(10) not null,
		MerchantNo nchar(20) not null,
		CurrSumValue Decimal(15,4) not null,
		PrevSumValue Decimal(15,4) not null,
		LastYearSumValue Decimal(15,4) not null
	);
	insert into #SumCount
	(
		TypeName,
		GateNo,
		MerchantNo,
		CurrSumValue,
		PrevSumValue,
		LastYearSumValue
	)
	select
		N'Pay' as TypeName,
		coalesce(CurrTrans.GateNo, PrevTrans.GateNo, LastYearTrans.GateNo) GateNo,
		coalesce(CurrTrans.MerchantNo, PrevTrans.MerchantNo, LastYearTrans.MerchantNo) MerchantNo,
		(Convert(Decimal,isnull(CurrTrans.SumSucceedCount, 0))/10000) CurrSumValue,
		(Convert(Decimal,isnull(PrevTrans.SumSucceedCount, 0))/10000) PrevSumValue,
		(Convert(Decimal,ISNULL(LastYearTrans.SumSucceedCount, 0))/10000) LastYearSumValue
	from
		#CurrPayTrans CurrTrans
		full outer join
		#PrevPayTrans PrevTrans
		on
			CurrTrans.GateNo = PrevTrans.GateNo
			and
			CurrTrans.MerchantNo = PrevTrans.MerchantNo
		full outer join
		#LastYearPayTrans LastYearTrans
		on
			coalesce(CurrTrans.GateNo, PrevTrans.GateNo) = LastYearTrans.GateNo
			and
			coalesce(CurrTrans.MerchantNo, PrevTrans.MerchantNo) = LastYearTrans.MerchantNo
	union all
	select
		N'Ora' as TypeName,
		coalesce(CurrTrans.GateNo, PrevTrans.GateNo, LastYearTrans.GateNo) GateNo,
		coalesce(CurrTrans.MerchantNo, PrevTrans.MerchantNo, LastYearTrans.MerchantNo) MerchantNo,
		(Convert(Decimal,ISNULL(CurrTrans.SumSucceedCount, 0))/10000) CurrSumValue,
		(Convert(Decimal,ISNULL(PrevTrans.SumSucceedCount, 0))/10000) PrevSumValue,
		(Convert(Decimal,ISNULL(LastYearTrans.SumSucceedCount, 0))/10000) LastYearSumValue
	from
		#CurrOraTrans CurrTrans
		full outer join
		#PrevOraTrans PrevTrans
		on
			CurrTrans.GateNo = PrevTrans.GateNo
			and
			CurrTrans.MerchantNo = PrevTrans.MerchantNo
		full outer join
		#LastYearOraTrans LastYearTrans
		on
			coalesce(CurrTrans.GateNo, PrevTrans.GateNo) = LastYearTrans.GateNo
			and
			coalesce(CurrTrans.MerchantNo, PrevTrans.MerchantNo) = LastYearTrans.MerchantNo;
	select
		Mer.MerchantName,
		SumCount.MerchantNo,
		ISNULL(case when Gate.GateCategory1 = '#N/A' then NULL else Gate.GateCategory1 End,N'其他') GateCategory,
		SumCount.GateNo,
		SumCount.CurrSumValue,
		SumCount.PrevSumValue,
		SumCount.LastYearSumValue
	from
		#SumCount SumCount
		left join
		Table_GateCategory Gate
		on
			SumCount.GateNo = Gate.GateNo
		left join
		Table_MerInfo Mer
		on
			SumCount.MerchantNo = Mer.MerchantNo
	where
		TypeName = N'Pay'
	union all
	select
		Mer.MerchantName,
		SumCount.MerchantNo,
		N'代付' as GateCategory,
		Gate.BankName,
		ISNULL(SUM(SumCount.CurrSumValue),0) CurrSumValue,
		ISNULL(SUM(SumCount.PrevSumValue),0) PrevSumValue,
		ISNULL(SUM(SumCount.LastYearSumValue),0) LastYearSumValue
	from
		#SumCount SumCount
		left join
		Table_OraBankSetting Gate
		on
			SumCount.GateNo = Gate.BankSettingID
		left join
		Table_OraMerchants Mer
		on
			SumCount.MerchantNo = Mer.MerchantNo
	where
		TypeName = N'Ora'
	group by
		Mer.MerchantName,
		SumCount.MerchantNo,
		Gate.BankName;

	drop table #SumCount;
end

--4.1 Add Dimension information to final result

		
--5 Clear all temp tables
drop table #LastYearPayTrans;
drop table #PrevPayTrans;
drop table #CurrPayTrans;
drop table #LastYearOraTrans;
drop table #PrevOraTrans;
drop table #CurrOraTrans;

End