if OBJECT_ID(N'Proc_QueryUnusualMerchantReport', N'P') is not null
begin
	drop procedure Proc_QueryUnusualMerchantReport;	
end
go

create procedure Proc_QueryUnusualMerchantReport
	@StartDate as datetime = '2011-01-01',
	@PeriodUnit as nchar(2) = N'周',
	@MonthPeriod as tinyint = 2,
	@TopNum as smallint	 = 120
as
begin

--1. Check input
if (@StartDate is null or ISNULL(@PeriodUnit, N'') = N'' or @TopNum is null or @MonthPeriod is null)
begin
	raiserror(N'Input params cannot be empty in Proc_QueryUnusualMerchantReport', 16, 1);
end;

--2. Prepare Unusual Merchant list
With CandidateUnusualMerchant as
(
	select
		MerchantNo,
		SUM(SucceedTransAmount) SumSucceedAmount
	from
		FactDailyTrans
	where
		GateNo not in ('0044', '0045')
		and
		DailyTransDate >= dateadd(month, -1 * @MonthPeriod, convert(char, YEAR(@StartDate)) + '-' + CONVERT(char, MONTH(@StartDate)) + '-01')
		and
		DailyTransDate < convert(char, YEAR(@StartDate)) + '-' + CONVERT(char, MONTH(@StartDate)) + '-01'
		and
		MerchantNo not in (select MerchantNo from Table_FacilityMerchantRelation where FacilityNo = '000020100816001')
	group by
		MerchantNo
)
select top(@TopNum)
	MerchantNo
into
	#UnusualMerchantList
from
	CandidateUnusualMerchant
order by
	SumSucceedAmount desc;

--3. Prepare StartDate and EndDate
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

--4. Get Current Period SucceedCount and SucceedAmount
select
	MerchantNo,
	SUM(SucceedTransCount) CurrSumCount,
	SUM(SucceedTransAmount) CurrSumAmount
into
	#CurrSumValue
from
	FactDailyTrans
where
	DailyTransDate >= @CurrStartDate
	and
	DailyTransDate < @CurrEndDate
group by
	MerchantNo;
	
--5. Get Previous Period SucceedCount and SucceedAmount
select
	MerchantNo,
	SUM(SucceedTransCount) PrevSumCount,
	SUM(SucceedTransAmount) PrevSumAmount
into
	#PrevSumValue
from
	FactDailyTrans
where
	DailyTransDate >= @PrevStartDate
	and
	DailyTransDate < @PrevEndDate
group by
	MerchantNo;

--6. Get Last Year same period SucceedCount and SucceedAmount
select
	MerchantNo,
	SUM(SucceedTransCount) LastYearSumCount,
	SUM(SucceedTransAmount) LastYearSumAmount
into
	#LastYearSumValue
from
	FactDailyTrans
where
	DailyTransDate >= @LastYearStartDate
	and
	DailyTransDate < @LastYearEndDate
group by
	MerchantNo;

--7. Query result
select
	UnusualMerchant.MerchantNo,
	ISNULL(DimMerchant.MerchantName, N'') as MerchantName,
	convert(decimal, ISNULL(CurrSum.CurrSumAmount, 0))/100 as CurrSumAmount,
	ISNULL(CurrSum.CurrSumCount, 0) as CurrSumCount,
	convert(decimal, ISNULL(PrevSum.PrevSumAmount, 0))/100 as PrevSumAmount,
	ISNULL(PrevSum.PrevSumCount, 0) as PrevSumCount,
	convert(decimal, ISNULL(LastYearSum.LastYearSumAmount, 0))/100 as LastYearAmount,
	ISNULL(LastYearSum.LastYearSumCount, 0) as LastYearCount,
	convert(decimal, ISNULL(CurrSum.CurrSumAmount, 0) - ISNULL(PrevSum.PrevSumAmount, 0))/100 as AnnulusIncrementalAmount,
	ISNULL(CurrSum.CurrSumCount, 0) - ISNULL(PrevSum.PrevSumCount, 0) as AnnulusIncrementalCount,
	convert(decimal, ISNULL(CurrSum.CurrSumAmount, 0) - ISNULL(LastYearSum.LastYearSumAmount, 0))/100 as YearIncrementalAmount,
	ISNULL(CurrSum.CurrSumCount, 0) - ISNULL(LastYearSum.LastYearSumCount, 0) as YearIncrementalCount
from
	#UnusualMerchantList UnusualMerchant
	left join
	#CurrSumValue CurrSum
	on
		UnusualMerchant.MerchantNo = CurrSum.MerchantNo
	left join
	#PrevSumValue PrevSum
	on
		UnusualMerchant.MerchantNo = PrevSum.MerchantNo
	left join
	#LastYearSumValue LastYearSum
	on
		UnusualMerchant.MerchantNo = LastYearSum.MerchantNo
	left join
	DimMerchant
	on
		UnusualMerchant.MerchantNo = DimMerchant.MerchantNo;
		
--8. Clear temp tables
drop table #UnusualMerchantList;
drop table #CurrSumValue;
drop table #PrevSumValue;
drop table #LastYearSumValue;

end