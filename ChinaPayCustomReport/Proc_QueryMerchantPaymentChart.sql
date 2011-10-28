if OBJECT_ID(N'Proc_QueryMerchantPaymentChart', N'P') is not null
begin
	drop procedure Proc_QueryMerchantPaymentChart;
end
go

create procedure Proc_QueryMerchantPaymentChart
	@StartDate datetime = '2011-09-01',
	@PeriodUnit nchar(4) = N'月',
	@MeasureCategory nchar(10) = N'成功金额',
	@SubjectCategory nchar(10) = N'环比增量',
	@topnum int = 10
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
	MerchantNo;

--2. Get previous period trade count/amount
select
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
	MerchantNo;

--3. Get last year same period trade count/amount
select
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
	MerchantNo;

--4. Get all together
--4.1 Get Sum Value
create table #SumValue
(
	MerchantNo nchar(20) not null,
	CurrSumValue Decimal(12,1) not null,
	PrevSumValue Decimal(12,1) not null,
	LastYearSumValue Decimal(12,1) not null
);
if @MeasureCategory = N'成功金额'
begin
	insert into #SumValue
	(
		MerchantNo,
		CurrSumValue,
		PrevSumValue,
		LastYearSumValue
	)
	select
		coalesce(CurrTrans.MerchantNo, PrevTrans.MerchantNo, LastYearTrans.MerchantNo) MerchantNo,
		(Convert(Decimal,isnull(CurrTrans.SumSucceedAmount, 0))/1000000) CurrSumValue,
		(Convert(Decimal,isnull(PrevTrans.SumSucceedAmount, 0))/1000000) PrevSumValue,
		(Convert(Decimal,ISNULL(LastYearTrans.SumSucceedAmount, 0))/1000000) LastYearSumValue
	from
		#CurrTrans CurrTrans
		full outer join
		#PrevTrans PrevTrans
		on
			CurrTrans.MerchantNo = PrevTrans.MerchantNo
		full outer join
		#LastYearTrans LastYearTrans
		on
			coalesce(CurrTrans.MerchantNo,PrevTrans.MerchantNo) = LastYearTrans.MerchantNo;
end
else
begin
	insert into #SumValue
	(
		MerchantNo,
		CurrSumValue,
		PrevSumValue,
		LastYearSumValue
	)
	select
		coalesce(CurrTrans.MerchantNo, PrevTrans.MerchantNo, LastYearTrans.MerchantNo) MerchantNo,
		(Convert(Decimal,isnull(CurrTrans.SumSucceedCount, 0))/1000) CurrSumValue,
		(Convert(Decimal,isnull(PrevTrans.SumSucceedCount, 0))/1000) PrevSumValue,
		(Convert(Decimal,ISNULL(LastYearTrans.SumSucceedCount, 0))/1000) LastYearSumValue
	from
		#CurrTrans CurrTrans
		full outer join
		#PrevTrans PrevTrans
		on
			CurrTrans.MerchantNo = PrevTrans.MerchantNo
		full outer join
		#LastYearTrans LastYearTrans
		on
			coalesce(CurrTrans.MerchantNo,PrevTrans.MerchantNo) = LastYearTrans.MerchantNo;
end

--4.1 Add the Differ to the temp table
Create table #DifferSum
(
	MerchantNo nchar(20) not null,
	PrevSumValue bigint not null,
	LastYearSumValue bigint not null
);
insert into #DifferSum
select 
	MerchantNo,
	(SumValue.CurrSumValue-SumValue.PrevSumValue) AS PrevSumValue,
	(SumValue.CurrSumValue-SumValue.LastYearSumValue) AS LastYearSumValue
from
	#SumValue SumValue;

if @SubjectCategory = '环比增量' 
begin
	select top (Convert(int,@topnum))
		Table_MerInfo.MerchantName,
		DifferSum.PrevSumValue AS SumValue
	from
		#DifferSum DifferSum
		inner join
		Table_MerInfo
		on
			DifferSum.MerchantNo = Table_MerInfo.MerchantNo
	where 
		DifferSum.PrevSumValue > 0
	order by 
		SumValue desc
end
else if  @SubjectCategory = '环比减量' 
begin 
	select top (Convert(int,@topnum))
		Table_MerInfo.MerchantName,
		DifferSum.PrevSumValue AS SumValue
	from
		#DifferSum DifferSum
		inner join
		Table_MerInfo
		on
			DifferSum.MerchantNo = Table_MerInfo.MerchantNo
	where 
		DifferSum.PrevSumValue < 0
	order by
		SumValue
end	
else if  @SubjectCategory = '同比增量' 
begin 
	select top (Convert(int,@topnum))
		Table_MerInfo.MerchantName,
		DifferSum.LastYearSumValue AS SumValue
	from
		#DifferSum DifferSum
		inner join 
		Table_MerInfo
		on
			DifferSum.MerchantNo = Table_MerInfo.MerchantNo
	where 
		DifferSum.LastYearSumValue > 0
	order by 
		SumValue DESC
end	
else if  @SubjectCategory = '同比减量' 
begin 
	select top (Convert(int,@topnum))
		Table_MerInfo.MerchantName,
		DifferSum.LastYearSumValue AS SumValue
	from
		#DifferSum DifferSum
		inner join 
		Table_MerInfo
		on
			DifferSum.MerchantNo = Table_MerInfo.MerchantNo
	where 
		DifferSum.LastYearSumValue < 0
	order by 
		SumValue
end		
--5 Clear all temp tables
drop table #SumValue;
drop table #LastYearTrans;
drop table #PrevTrans;
drop table #CurrTrans;
drop table #DifferSum;

End