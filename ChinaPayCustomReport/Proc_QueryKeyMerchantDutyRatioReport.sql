if OBJECT_ID(N'Proc_QueryKeyMerchantDutyRatioReport', N'P') is not null
begin
	drop procedure Proc_QueryKeyMerchantDutyRatioReport;
end
go

create procedure Proc_QueryKeyMerchantDutyRatioReport
	@StartDate datetime = '2011-09-01',
	@PeriodUnit nchar(4) = N'月',
	@MeasureCategory nchar(10) = N'成功金额',
	@topnum int = 50
as
begin

--0.1 Prepare StartDate and EndDate
declare @CurrStartDate datetime;
declare @CurrEndDate datetime;

if(@PeriodUnit = N'周')
begin
	set @CurrStartDate = @StartDate;
	set @CurrEndDate = DATEADD(week, 1, @StartDate);
end
else if(@PeriodUnit = N'月')
begin
	set @CurrStartDate = @StartDate;
	set @CurrEndDate = DATEADD(MONTH, 1, @StartDate);
end
else if(@PeriodUnit = N'季度')
begin
	set @CurrStartDate = @StartDate;
	set @CurrEndDate = DATEADD(QUARTER, 1, @StartDate);
end
else if(@PeriodUnit = N'半年')
begin
	set @CurrStartDate = @StartDate;
	set @CurrEndDate = DATEADD(QUARTER, 2, @StartDate);
end
else if(@PeriodUnit = N'年')
begin
	set @CurrStartDate = @StartDate;
	set @CurrEndDate = DATEADD(YEAR, 1, @StartDate);
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
	
--4. Get all together
--4.1 Get Sum Value
create table #SumValue
(
	MerchantNo nchar(20) not null,
	CurrSumValue bigint not null
);
if @MeasureCategory = N'成功金额'
begin
	insert into #SumValue
	(

		MerchantNo,
		CurrSumValue
	)
	select
		CurrTrans.MerchantNo MerchantNo,
		sum(isnull(CurrTrans.SumSucceedAmount, 0)) CurrSumValue
	from
		#CurrTrans CurrTrans
        group by MerchantNo
end
else
begin
	insert into #SumValue
	(
		MerchantNo,
		CurrSumValue
	)
	select
		CurrTrans.MerchantNo MerchantNo,
		sum(isnull(CurrTrans.SumSucceedCount, 0)) CurrSumValue
	from
		#CurrTrans CurrTrans
        group by MerchantNo
end

--4.2 Add Dimension information to final result
select top(convert(int, @topnum)) 
	Table_MerInfo.MerchantName,
	SumValue.CurrSumValue
into
	#TopMerchant
from
	#SumValue SumValue
	inner join
	Table_MerInfo
	on
		SumValue.MerchantNo = Table_MerInfo.MerchantNo
order by
	SumValue.CurrSumValue DESC;

--4.3 Add N'其他' record
select
	MerchantName,
	CurrSumValue
from
	#TopMerchant
union all
select
	N'其他' as MerchantName,
	(select isnull(SUM(CurrSumValue),0) from #SumValue) - (select ISNULL(sum(CurrSumValue), 0) from #TopMerchant) as CurrSumValue;
		
--5 Clear all temp tables
drop table #SumValue;
drop table #CurrTrans;
drop table #TopMerchant;

End