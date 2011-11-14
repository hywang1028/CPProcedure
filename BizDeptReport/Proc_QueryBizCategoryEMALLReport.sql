if OBJECT_ID(N'Proc_QueryBizCategoryEMALLReport', N'P') is not null
begin
	drop procedure Proc_QueryBizCategoryEMALLReport;
end
go

create procedure Proc_QueryBizCategoryEMALLReport
	@StartDate datetime = '2011-09-01',
	@PeriodUnit nchar(4) = N'月',
	@EndDate datetime = '2011-09-30'
as
begin

--1. Check input
if (@StartDate is null or ISNULL(@PeriodUnit, N'') = N'' or (@PeriodUnit = N'自定义' and @EndDate is null))
begin
	raiserror(N'Input params cannot be empty in Proc_QueryBizCategoryEMALLReport', 16, 1);
end

--2. Prepare date period
declare @CurrStartDate datetime;
declare @CurrEndDate datetime;
declare @PrevStartDate datetime;
declare @PrevEndDate datetime;
declare @LastYearStartDate datetime;
declare @LastYearEndDate datetime;
declare @ThisYearRunningStartDate datetime;
declare @ThisYearRunningEndDate datetime;

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
set @ThisYearRunningStartDate = convert(char(4), YEAR(@CurrStartDate)) + '-01-01';
set @ThisYearRunningEndDate = @CurrEndDate;

--3. Get Current period data
select
	MerchantNo,
	sum(SucceedTransCount) as SucceedCount,
	sum(SucceedTransAmount) as SucceedAmount
into
	#CurrData
from
	Table_EmallTransSum
where
	TransDate >= @CurrStartDate
	and
	TransDate  < @CurrEndDate
group by
	MerchantNo;

--4. Get Previous period data
select
	MerchantNo,
	sum(SucceedTransCount) as SucceedCount,
	sum(SucceedTransAmount) as SucceedAmount
into
	#PrevData
from
	Table_EmallTransSum
where
	TransDate >= @PrevStartDate
	and
	TransDate  < @PrevEndDate
group by
	MerchantNo;

--5. Get LastYear period data
select
	MerchantNo,
	sum(SucceedTransCount) as SucceedCount,
	sum(SucceedTransAmount) as SucceedAmount
into
	#LastYearData
from
	Table_EmallTransSum
where
	TransDate >= @LastYearStartDate
	and
	TransDate  < @LastYearEndDate
group by
	MerchantNo;

--6. Get ThisYearRunning period data
select
	MerchantNo,
	sum(SucceedTransCount) as SucceedCount,
	sum(SucceedTransAmount) as SucceedAmount
into
	#ThisYearData
from
	Table_EmallTransSum
where
	TransDate >= @ThisYearRunningStartDate
	and
	TransDate  < @ThisYearRunningEndDate
group by
	MerchantNo;

--7. Get Result
select
	convert(decimal, SUM(ISNULL(Curr.SucceedAmount, 0)))/1000000 SucceedAmount,
	Convert(decimal, SUM(ISNULL(Curr.SucceedCount, 0)))/10000 SucceedCount,
	case when SUM(ISNULL(Curr.SucceedCount, 0)) = 0 
		then null 
		else (convert(decimal, SUM(ISNULL(Curr.SucceedAmount, 0)))/SUM(ISNULL(Curr.SucceedCount,0)))/100
	end AvgAmount,
	case when SUM(ISNULL(Prev.SucceedAmount, 0)) = 0
		then null
		else convert(decimal, SUM(ISNULL(Curr.SucceedAmount, 0)) - SUM(ISNULL(Prev.SucceedAmount, 0)))/SUM(ISNULL(Prev.SucceedAmount,0))
	end SeqIncrementAmountRatio,
	case when SUM(ISNULL(Prev.SucceedCount, 0)) = 0
		then null
		else CONVERT(decimal, SUM(ISNULL(Curr.SucceedCount, 0)) - SUM(ISNULL(Prev.SucceedCount, 0)))/SUM(ISNULL(Prev.SucceedCount,0))
	end SeqIncrementCountRatio,
	case when SUM(ISNULL(LastYear.SucceedAmount, 0)) = 0
		then null
		else CONVERT(decimal, SUM(ISNULL(Curr.SucceedAmount, 0)) - SUM(ISNULL(LastYear.SucceedAmount, 0)))/SUM(ISNULL(LastYear.SucceedAmount,0))
	end YOYIncrementAmountRatio,
	case when SUM(ISNULL(LastYear.SucceedCount, 0)) = 0
		then null
		else CONVERT(decimal, SUM(ISNULL(Curr.SucceedCount, 0)) - SUM(ISNULL(LastYear.SucceedCount, 0)))/SUM(ISNULL(LastYear.SucceedCount,0))
	end YOYIncrementCountRatio,

	convert(decimal, SUM(ISNULL(ThisYearRunning.SucceedAmount, 0)))/1000000 ThisYearRunningSucceedAmount,
	convert(decimal, SUM(ISNULL(ThisYearRunning.SucceedCount, 0)))/10000 ThisYearRunningSucceedCount,
	convert(decimal, SUM(ISNULL(Prev.SucceedAmount, 0)))/1000000 PrevSucceedAmount,
	convert(decimal, SUM(ISNULL(Prev.SucceedCount, 0)))/10000 PrevSucceedCount,
	convert(decimal, SUM(ISNULL(LastYear.SucceedAmount, 0)))/1000000 LastYearSucceedAmount,
	convert(decimal, SUM(ISNULL(LastYear.SucceedCount, 0)))/10000 LastYearSucceedCount
from
	#CurrData Curr
	full outer join
	#PrevData Prev
	on
		Curr.MerchantNo = Prev.MerchantNo
	full outer join
	#LastYearData LastYear
	on
		Coalesce(Curr.MerchantNo, Prev.MerchantNo) = LastYear.MerchantNo
	full outer join
	#ThisYearData ThisYearRunning
	on
		Coalesce(Curr.MerchantNo, Prev.MerchantNo, LastYear.MerchantNo) = ThisYearRunning.MerchantNo;


--8. Clear temp table
drop table #CurrData;
drop table #PrevData;
drop table #LastYearData;
drop table #ThisYearData;

end 