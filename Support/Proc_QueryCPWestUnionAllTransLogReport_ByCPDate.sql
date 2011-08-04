if OBJECT_ID(N'Proc_QueryCPWestUnionAllTransLogReport_ByCPDate', N'P') is not null
begin
	drop procedure Proc_QueryCPWestUnionAllTransLogReport_ByCPDate;
end
go


Create Procedure Proc_QueryCPWestUnionAllTransLogReport_ByCPDate
    @StartDate datetime = '2011-06-01',
    @PeriodUnit nChar(3) = N'�Զ���',
    @EndDate datetime = '2011-06-30'
as
begin


--1. Check Input
if (@StartDate is null or ISNULL(@PeriodUnit,N'') = N'' or (@PeriodUnit = N'�Զ���' and @EndDate is null))
begin 
      raiserror(N'Input params cannot be empty in Proc_QueryCPWestUnionAllTransLogReport_ByCPDate',16,1);
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

if(@PeriodUnit = N'��')
begin
      set @CurrStartDate = @StartDate;
      set @CurrEndDate = DATEADD(week,1,@StartDate);
      set @PrevStartDate = DATEADD(week,-1,@CurrStartDate);
      set @PrevEndDate = @CurrStartDate;
      set @LastYearStartDate = DATEADD(year,-1,@CurrStartDate);
      set @LastYearEndDate = DATEADD(year,-1,@CurrEndDate);
end
else if(@PeriodUnit = N'��')
begin
    set @CurrStartDate = @StartDate;
    set @CurrEndDate = DATEADD(MONTH, 1, @StartDate);
    set @PrevStartDate = DATEADD(MONTH, -1, @CurrStartDate);
    set @PrevEndDate = @CurrStartDate;
    set @LastYearStartDate = DATEADD(year, -1, @CurrStartDate); 
    set @LastYearEndDate = DATEADD(year, -1, @CurrEndDate);
end
else if(@PeriodUnit = N'����')
begin
    set @CurrStartDate = @StartDate;
    set @CurrEndDate = DATEADD(QUARTER, 1, @StartDate);
    set @PrevStartDate = DATEADD(QUARTER, -1, @CurrStartDate);
    set @PrevEndDate = @CurrStartDate;
    set @LastYearStartDate = DATEADD(year, -1, @CurrStartDate); 
    set @LastYearEndDate = DATEADD(year, -1, @CurrEndDate);
end
else if(@PeriodUnit = N'����')
begin
    set @CurrStartDate = @StartDate;
    set @CurrEndDate = DATEADD(QUARTER, 2, @StartDate);
    set @PrevStartDate = DATEADD(QUARTER, -2, @CurrStartDate);
    set @PrevEndDate = @CurrStartDate;
    set @LastYearStartDate = DATEADD(year, -1, @CurrStartDate); 
    set @LastYearEndDate = DATEADD(year, -1, @CurrEndDate);
end
else if(@PeriodUnit = N'��')
begin
    set @CurrStartDate = @StartDate;
    set @CurrEndDate = DATEADD(YEAR, 1, @StartDate);
    set @PrevStartDate = DATEADD(YEAR, -1, @CurrStartDate);
    set @PrevEndDate = @CurrStartDate;
    set @LastYearStartDate = DATEADD(year, -1, @CurrStartDate); 
    set @LastYearEndDate = DATEADD(year, -1, @CurrEndDate);
end     
else if(@PeriodUnit = N'�Զ���')
begin
     set @CurrStartDate = @StartDate;
     set @CurrEndDate = DATEADD(day,1,@EndDate);
     set @PrevStartDate = DATEADD(day,-1*DATEDIFF(day,@CurrStartDate,@CurrEndDate),@CurrStartDate);
     set @PrevEndDate = @CurrStartDate;
     set @LastYearStartDate = DATEADD(year,-1,@CurrStartDate);
     set @LastYearEndDate = DATEADD(year,-1,@CurrEndDate);
end

set @ThisYearRunningStartDate = CONVERT(char(4),YEAR(@CurrStartDate)) + '-01-01';
set @ThisYearRunningEndDate = @CurrEndDate;     


--3. Get Current Data
select
	SUM(ISNULL(DestTransAmount,0)) as TransSumAmount,
	COUNT(DestTransAmount) as TransSumCount
into
	#CurrData	
from
	Table_WUTransLog
where
	CPDate >= @CurrStartDate
	and
	CPDate < @CurrEndDate;
	

--4. Get Previous Data
select
	SUM(ISNULL(DestTransAmount,0)) as TransSumAmount,
	COUNT(DestTransAmount) as TransSumCount
into
	#PrevData
from
	Table_WUTransLog
where
	CPDate >= @PrevStartDate
	and
	CPDate < @PrevEndDate;	
	
--5. Get LastYearData
select
	SUM(ISNULL(DestTransAmount,0)) as TransSumAmount,
	COUNT(DestTransAmount) as TransSumCount
into
	#LastYearData
from
	Table_WUTransLog
where
	CPDate >= @LastYearStartDate
	and
	CPDate < @LastYearEndDate;		


--6. GetThisYearRunningData
select
	SUM(ISNULL(DestTransAmount,0)) as TransSumAmount,
	COUNT(DestTransAmount) as TransSumCount
into
	#ThisYearRunningData
from
	Table_WUTransLog
where
	CPDate >= @ThisYearRunningStartDate
	and
	CPDate < @ThisYearRunningEndDate;	
	
--7. Get Result
select
	CONVERT(decimal,ISNULL(Curr.TransSumAmount,0))/1000000 as TransSumAmount,
	CONVERT(decimal,Curr.TransSumCount)/10000 as TransSumCount,
	case when ISNULL(Prev.TransSumAmount,0) = 0
		then null
		else (CONVERT(decimal,ISNULL(Curr.TransSumAmount,0) - Prev.TransSumAmount))/Prev.TransSumAmount
	end SeqGrowthAmountRatio,
	case when ISNULL(Prev.TransSumCount,0) = 0
		then null
		else (CONVERT(decimal,ISNULL(Curr.TransSumCount,0) - Prev.TransSumCount))/Prev.TransSumCount
	end SeqGrowthCountRatio,
	case when ISNULL(LastYear.TransSumAmount,0) = 0
		then null
		else (CONVERT(decimal,ISNULL(Curr.TransSumAmount,0) - LastYear.TransSumAmount))/LastYear.TransSumAmount
	end YearOnYearGrowthAmountRatio,	
	case when ISNULL(LastYear.TransSumCount,0) = 0
		then null
		else (CONVERT(decimal,ISNULL(Curr.TransSumCount,0) - LastYear.TransSumCount))/LastYear.TransSumCount
	end YearOnYearGrowthCountRatio,	
	CONVERT(decimal,ISNULL(ThisYearRunning.TransSumAmount,0))/1000000 as ThisYearTotalAmount,
	CONVERT(decimal,ThisYearRunning.TransSumCount)/10000 as ThisYearTotalCount
from
    #CurrData Curr, 
    #PrevData Prev,
    #LastYearData LastYear,
    #ThisYearRunningData ThisYearRunning; 
    
--8. Clear Temp Table
drop table #CurrData;
drop table #PrevData;
drop table #LastYearData;
drop table #ThisYearRunningData;

end    