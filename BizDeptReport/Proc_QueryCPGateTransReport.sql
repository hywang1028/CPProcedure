if OBJECT_ID(N'Proc_QueryCPGateTransReport', N'P') is not null
begin
	drop procedure Proc_QueryCPGateTransReport;
end
go

create procedure Proc_QueryCPGateTransReport
	@StartDate datetime = '2011-01-01',
	@PeriodUnit nchar(2) = N'周',
	@ReportCategory nchar(4) = N'明细'
as
begin

--1. Check input
if (@StartDate is null or ISNULL(@PeriodUnit, N'') = N'')
begin
	raiserror(N'Input params cannot be empty in Proc_QueryCPGateTransReport', 16, 1);
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

set @ThisYearRunningStartDate = CONVERT(char(4), YEAR(@CurrStartDate)) + '-01-01';
set @ThisYearRunningEndDate = @CurrEndDate;

--3. Get Current Data
select
	GateNo,
	SUM(SucceedTransCount) as CurrSucceedCount,
	SUM(SucceedTransAmount) as CurrSucceedAmount
into
	#CurrData
from
	FactDailyTrans
where
	DailyTransDate >= @CurrStartDate
	and
	DailyTransDate < @CurrEndDate
group by
	GateNo;
	
--4. Get Previous Data
select
	GateNo,
	SUM(SucceedTransCount) as PrevSucceedCount,
	SUM(SucceedTransAmount) as PrevSucceedAmount
into
	#PrevData
from
	FactDailyTrans
where
	DailyTransDate >= @PrevStartDate
	and
	DailyTransDate < @PrevEndDate
group by
	GateNo;

--5. Get LastYear Data
select
	GateNo,
	SUM(SucceedTransCount) as LastYearSucceedCount,
	SUM(SucceedTransAmount) as LastYearSucceedAmount
into
	#LastYearData
from
	FactDailyTrans
where
	DailyTransDate >= @LastYearStartDate
	and
	DailyTransDate < @LastYearEndDate
group by
	GateNo;
	
--6. Get ThisYearRunning Data
select
	GateNo,
	SUM(SucceedTransCount) as ThisYearRunningCount,
	SUM(SucceedTransAmount) as ThisYearRunningAmount
into
	#ThisYearRunningData
from
	FactDailyTrans
where
	DailyTransDate >= @ThisYearRunningStartDate
	and
	DailyTransDate < @ThisYearRunningEndDate
group by
	GateNo;
	
--7. Get Current period total SucceedAmount
declare @CurrTotalSucceedAmount bigint;
set @CurrTotalSucceedAmount = (select ISNULL(SUM(CurrSucceedAmount),0) from #CurrData);

--8. Get Result
if @ReportCategory = N'明细'
begin
	select
		DimGate.BankName,
		DimGate.GateNo,
		CONVERT(decimal, ISNULL(Curr.CurrSucceedAmount, 0))/1000000 SucceedAmount,
		CONVERT(decimal, ISNULL(Curr.CurrSucceedCount, 0))/10000 SucceedCount,
		case when ISNULL(Curr.CurrSucceedCount, 0) = 0
			then null
			else (CONVERT(decimal, ISNULL(Curr.CurrSucceedAmount, 0))/100)/Curr.CurrSucceedCount
		end AvgAmount,
		case when ISNULL(Prev.PrevSucceedAmount, 0) = 0
			then null
			else CONVERT(decimal, ISNULL(Curr.CurrSucceedAmount, 0) - ISNULL(Prev.PrevSucceedAmount, 0))/Prev.PrevSucceedAmount
		end SeqAmountIncrementRatio,
		case when ISNULL(Prev.PrevSucceedCount, 0) = 0
			then null
			else CONVERT(decimal, ISNULL(Curr.CurrSucceedCount, 0) - ISNULL(Prev.PrevSucceedCount, 0))/Prev.PrevSucceedCount
		end SeqCountIncrementRatio,
		case when ISNULL(LastYear.LastYearSucceedAmount, 0) = 0
			then null
			else CONVERT(decimal, ISNULL(Curr.CurrSucceedAmount, 0) - ISNULL(LastYear.LastYearSucceedAmount, 0))/LastYear.LastYearSucceedAmount
		end YOYAmountIncrementRatio,
		case when ISNULL(LastYear.LastYearSucceedCount, 0) = 0
			then null
			else CONVERT(decimal, ISNULL(Curr.CurrSucceedCount, 0) - ISNULL(LastYear.LastYearSucceedCount, 0))/LastYear.LastYearSucceedCount
		end YOYCountIncrementRatio,
		case when ISNULL(@CurrTotalSucceedAmount, 0) = 0
			then null
			else CONVERT(decimal, ISNULL(Curr.CurrSucceedAmount, 0))/@CurrTotalSucceedAmount
		end DutyRatio,
		convert(decimal, ISNULL(ThisYearRunning.ThisYearRunningAmount, 0))/1000000 ThisYearRunningAmount,
		convert(decimal, ISNULL(ThisYearRunning.ThisYearRunningCount, 0))/10000 ThisYearRnnningCount,
		Convert(decimal,ISNULL(Prev.PrevSucceedAmount, 0))/1000000 PrevSucceedAmount,
		Convert(decimal,ISNULL(Prev.PrevSucceedCount, 0))/10000 PrevSucceedCount,
		Convert(decimal,ISNULL(LastYear.LastYearSucceedAmount, 0))/1000000 LastYearSucceedAmount,
		Convert(decimal,ISNULL(LastYear.LastYearSucceedCount, 0))/10000 LastYearSucceedCount
	from
		DimGate
		left join
		#CurrData Curr
		on
			DimGate.GateNo = Curr.GateNo
		left join
		#PrevData Prev
		on
			DimGate.GateNo = Prev.GateNo
		left join
		#LastYearData LastYear
		on
			DimGate.GateNo = LastYear.GateNo
		left join
		#ThisYearRunningData ThisYearRunning
		on
			DimGate.GateNo = ThisYearRunning.GateNo
	where
		len(DimGate.GateNo) = 4 
		or
		Curr.CurrSucceedAmount > 0
		or
		Curr.CurrSucceedCount > 0;
end
else if @ReportCategory = N'汇总'
begin
	select
		DimGate.BankName,
		'0' as GateNo,
		CONVERT(decimal, SUM(ISNULL(Curr.CurrSucceedAmount, 0)))/1000000 SucceedAmount,
		CONVERT(decimal, SUM(ISNULL(Curr.CurrSucceedCount, 0)))/10000 SucceedCount,
		case when SUM(ISNULL(Curr.CurrSucceedCount, 0)) = 0
			then null
			else (CONVERT(decimal, SUM(ISNULL(Curr.CurrSucceedAmount, 0)))/100)/SUM(ISNULL(Curr.CurrSucceedCount,0))
		end AvgAmount,
		case when SUM(ISNULL(Prev.PrevSucceedAmount, 0)) = 0
			then null
			else CONVERT(decimal, SUM(ISNULL(Curr.CurrSucceedAmount, 0)) - SUM(ISNULL(Prev.PrevSucceedAmount, 0)))/SUM(ISNULL(Prev.PrevSucceedAmount,0))
		end SeqAmountIncrementRatio,
		case when SUM(ISNULL(Prev.PrevSucceedCount, 0)) = 0
			then null
			else CONVERT(decimal, SUM(ISNULL(Curr.CurrSucceedCount, 0)) - SUM(ISNULL(Prev.PrevSucceedCount, 0)))/SUM(ISNULL(Prev.PrevSucceedCount,0))
		end SeqCountIncrementRatio,
		case when SUM(ISNULL(LastYear.LastYearSucceedAmount, 0)) = 0
			then null
			else CONVERT(decimal, SUM(ISNULL(Curr.CurrSucceedAmount, 0)) - SUM(ISNULL(LastYear.LastYearSucceedAmount, 0)))/SUM(ISNULL(LastYear.LastYearSucceedAmount,0))
		end YOYAmountIncrementRatio,
		case when SUM(ISNULL(LastYear.LastYearSucceedCount, 0)) = 0
			then null
			else CONVERT(decimal, SUM(ISNULL(Curr.CurrSucceedCount, 0)) - SUM(ISNULL(LastYear.LastYearSucceedCount, 0)))/SUM(ISNULL(LastYear.LastYearSucceedCount,0))
		end YOYCountIncrementRatio,
		case when ISNULL(@CurrTotalSucceedAmount, 0) = 0
			then null
			else CONVERT(decimal, SUM(ISNULL(Curr.CurrSucceedAmount, 0)))/@CurrTotalSucceedAmount
		end DutyRatio,
		convert(decimal, SUM(ISNULL(ThisYearRunning.ThisYearRunningAmount, 0)))/1000000 ThisYearRunningAmount,
		convert(decimal, SUM(ISNULL(ThisYearRunning.ThisYearRunningCount, 0)))/10000 ThisYearRnnningCount,
		Convert(decimal,SUM(ISNULL(Prev.PrevSucceedAmount, 0)))/1000000 PrevSucceedAmount,
		Convert(decimal,SUM(ISNULL(Prev.PrevSucceedCount, 0)))/10000 PrevSucceedCount,
		Convert(decimal,SUM(ISNULL(LastYear.LastYearSucceedAmount, 0)))/1000000 LastYearSucceedAmount,
		Convert(decimal,SUM(ISNULL(LastYear.LastYearSucceedCount, 0)))/10000 LastYearSucceedCount
	from
		DimGate
		left join
		#CurrData Curr
		on
			DimGate.GateNo = Curr.GateNo
		left join
		#PrevData Prev
		on
			DimGate.GateNo = Prev.GateNo
		left join
		#LastYearData LastYear
		on
			DimGate.GateNo = LastYear.GateNo
		left join
		#ThisYearRunningData ThisYearRunning
		on
			DimGate.GateNo = ThisYearRunning.GateNo
	where
		len(DimGate.GateNo) = 4 
		or
		Curr.CurrSucceedAmount > 0
		or
		Curr.CurrSucceedCount > 0
	group by
		DimGate.BankName;
end
--9. Clear temp table
drop table #CurrData;
drop table #PrevData;
drop table #LastYearData;
drop table #ThisYearRunningData;

end 