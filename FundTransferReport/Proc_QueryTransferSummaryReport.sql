if OBJECT_ID(N'Proc_QueryTransferSummaryReport', N'P') is not null
begin
	drop procedure Proc_QueryTransferSummaryReport;
end
go

create procedure Proc_QueryTransferSummaryReport
	@StartDate datetime = '2011-05-01',
	@PeriodUnit nchar(3) = N'月',
	@EndDate datetime = '2011-05-31'
as
begin

--1. Check input
if (@StartDate is null or ISNULL(@PeriodUnit, N'') = N'' or (@PeriodUnit = N'自定义' and @EndDate is null))
begin
	raiserror(N'Input params cannot be empty in Proc_QueryTransferSummaryReport', 16, 1);
end

--2. Prepare StartDate and EndDate
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

set @ThisYearRunningStartDate = CONVERT(char(4), YEAR(@CurrStartDate)) + '-01-01';
set @ThisYearRunningEndDate = @CurrEndDate;

--3. Get Current Data
select 
	case when InstuType = '00' then N'ChinaPay'
		 when InstuType = '01' then N'网银'
	end as ItemName,
	SUM(TransAmt) as TransAmount,
	COUNT(TransAmt) as TransCount
into
	#CurrData
from 
	dbo.Table_TrfTransLog
where
	TransType = '2070'
	and
	InstuType in ('00','01')
	and
	TransDate >= @CurrStartDate
	and
	TransDate < @CurrEndDate
group by
	InstuType;
	
--4. Get Previous Data
select 
	case when InstuType = '00' then N'ChinaPay'
		 when InstuType = '01' then N'网银'
	end as ItemName,
	SUM(TransAmt) as TransAmount,
	COUNT(TransAmt) as TransCount
into
	#PrevData
from 
	dbo.Table_TrfTransLog
where
	TransType = '2070'
	and
	InstuType in ('00','01')
	and
	TransDate >= @PrevStartDate
	and
	TransDate < @PrevEndDate
group by
	InstuType;
	
--5. Get Last Year Data
select 
	case when InstuType = '00' then N'ChinaPay'
		 when InstuType = '01' then N'网银'
	end as ItemName,
	SUM(TransAmt) as TransAmount,
	COUNT(TransAmt) as TransCount
into
	#LastYearData
from 
	dbo.Table_TrfTransLog
where
	TransType = '2070'
	and
	InstuType in ('00','01')
	and
	TransDate >= @LastYearStartDate
	and
	TransDate < @LastYearEndDate
group by
	InstuType;
	
--6.Get This Year Running Data
select 
	case when InstuType = '00' then N'ChinaPay'
		 when InstuType = '01' then N'网银'
	end as ItemName,
	SUM(TransAmt) as TransAmount,
	COUNT(TransAmt) as TransCount
into
	#ThisYearRunningData
from 
	dbo.Table_TrfTransLog
where
	TransType = '2070'
	and
	InstuType in ('00','01')
	and
	TransDate >= @ThisYearRunningStartDate
	and
	TransDate < @ThisYearRunningEndDate
group by
	InstuType;
	
--7. Get Current period total SucceedAmount
declare @CurrTotalSucceedAmount bigint;
set @CurrTotalSucceedAmount = (select ISNULL(SUM(TransAmount),0) from #CurrData);

--8.Get Result
select
	Coalesce(Curr.ItemName,Prev.ItemName,LastYear.ItemName,ThisYear.ItemName) as ItemName,
	CONVERT(decimal, ISNULL(Curr.TransAmount,0))/1000000 as TransAmount,
	CONVERT(decimal, ISNULL(Curr.TransCount,0))/10000 as TransCount,
	CONVERT(decimal, ISNULL(Prev.TransAmount,0))/1000000 as PrevTransAmount,
	CONVERT(decimal, ISNULL(Prev.TransCount,0))/10000 as PrevTransCount,
	CONVERT(decimal, ISNULL(LastYear.TransAmount,0))/1000000 as LastYearAmount,
	CONVERT(decimal, ISNULL(LastYear.TransCount,0))/10000 as LastYearCount,
	CONVERT(decimal, ISNULL(ThisYear.TransAmount,0))/1000000 as ThisYearAmount,
	CONVERT(decimal, ISNULL(ThisYear.TransCount,0))/10000 as ThisYearCount,
	case when ISNULL(@CurrTotalSucceedAmount, 0) = 0
		then null
		else CONVERT(decimal, ISNULL(Curr.TransAmount, 0))/@CurrTotalSucceedAmount
	end DutyRatio
from
	#CurrData Curr
	full outer join
	#PrevData Prev
	on
		Curr.ItemName = Prev.ItemName
	full outer join
	#LastYearData LastYear
	on
		Coalesce(Curr.ItemName,Prev.ItemName) = LastYear.ItemName
	full outer join
	#ThisYearRunningData ThisYear
	on
		Coalesce(Curr.ItemName,Prev.ItemName,LastYear.ItemName) = ThisYear.ItemName;	
End