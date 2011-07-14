if OBJECT_ID(N'Proc_QueryFundSummaryReport', N'P') is not null
begin
	drop procedure Proc_QueryFundSummaryReport;
end
go

create procedure Proc_QueryFundSummaryReport
	@StartDate datetime = '2011-05-12',
	@PeriodUnit nchar(3) = N'周',
	@EndDate datetime = '2011-01-30'
as
begin

--1. Check input
if (@StartDate is null or ISNULL(@PeriodUnit, N'') = N'' or (@PeriodUnit = N'自定义' and @EndDate is null))
begin
	raiserror(N'Input params cannot be empty in Proc_QueryCPFundTransReport', 16, 1);
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
	SUM(PurchaseCount) CurrPurchaseCount,
	SUM(PurchaseAmount) CurrPurchaseAmount,
	--case when SUM(PurchaseCount)=0 then null else SUM(PurchaseAmount)/SUM(PurchaseCount) end CurrPurchaseAvg,
	
	SUM(RetractCount) CurrRetractCount,
	SUM(RetractAmount) CurrRetractAmount,
	--case when SUM(RetractCount)=0 then null else SUM(RetractAmount)/SUM(RetractCount) end CurrRetractAvg,
	
	SUM(DividendCount) CurrDividendCount,
	SUM(DividendAmount) CurrDividendAmount,
	--case when SUM(DividendCount)=0 then null else SUM(DividendAmount)/SUM(DividendCount) end CurrDividendAvg,
	
	SUM(RedemptoryCount) CurrRedemptoryCount,
	SUM(RedemptoryAmount) CurrRedemptoryAmount,
	--case when SUM(RedemptoryCount)=0 then null else SUM(RedemptoryAmount)/SUM(RedemptoryCount) end CurrRedemptoryAvg,
	
	SUM(PurchaseCount) - SUM(RetractCount) CurrNetPurchaseCount,
	SUM(PurchaseAmount) - SUM(RetractAmount) CurrNetPurchaseAmount,
	--case when SUM(PurchaseAmount) - SUM(RetractAmount)=0 
	--then null else (SUM(PurchaseCount) - SUM(RetractCount))/(SUM(PurchaseAmount) - SUM(RetractAmount)) end CurrNetPurchaseAvg,
	
	SUM(PurchaseCount) - SUM(RetractCount) + SUM(DividendCount) + SUM(RedemptoryCount) CurrTotalCount,
	SUM(PurchaseAmount) - SUM(RetractAmount) + SUM(DividendAmount) + SUM(RedemptoryAmount) CurrTotalAmount
	--case when SUM(PurchaseCount) - SUM(RetractCount) + SUM(DividendCount) + SUM(RedemptoryCount) = 0
	--then null else (SUM(PurchaseAmount) - SUM(RetractAmount) + SUM(DividendAmount) + SUM(RedemptoryAmount))/(SUM(PurchaseCount) - SUM(RetractCount) + SUM(DividendCount) + SUM(RedemptoryCount)) end CurrTotalAvg
into
	#CurrData
from
	Table_FundTransSum
where
	TransDate >= @CurrStartDate
	and
	TransDate < @CurrEndDate;
	
--4. Get Previous Data
select
	SUM(PurchaseCount) PrevPurchaseCount,
	SUM(PurchaseAmount) PrevPurchaseAmount,
	
	SUM(RetractCount) PrevRetractCount,
	SUM(RetractAmount) PrevRetractAmount,
	
	SUM(DividendCount) PrevDividendCount,
	SUM(DividendAmount) PrevDividendAmount,
	
	SUM(RedemptoryCount) PrevRedemptoryCount,
	SUM(RedemptoryAmount) PrevRedemptoryAmount,
	
	SUM(PurchaseCount) - SUM(RetractCount) PrevNetPurchaseCount,
	SUM(PurchaseAmount) - SUM(RetractAmount) PrevNetPurchaseAmount,
	
	SUM(PurchaseCount) - SUM(RetractCount) + SUM(DividendCount) + SUM(RedemptoryCount) PrevTotalCount,
	SUM(PurchaseAmount) - SUM(RetractAmount) + SUM(DividendAmount) + SUM(RedemptoryAmount) PrevTotalAmount
into
	#PrevData
from
	Table_FundTransSum
where
	TransDate >= @PrevStartDate
	and
	TransDate < @PrevEndDate;

--5. Get LastYear Data
select
	SUM(PurchaseCount) LastYearPurchaseCount,
	SUM(PurchaseAmount) LastYearPurchaseAmount,
	
	SUM(RetractCount) LastYearRetractCount,
	SUM(RetractAmount) LastYearRetractAmount,
	
	SUM(DividendCount) LastYearDividendCount,
	SUM(DividendAmount) LastYearDividendAmount,
	
	SUM(RedemptoryCount) LastYearRedemptoryCount,
	SUM(RedemptoryAmount) LastYearRedemptoryAmount,
	
	SUM(PurchaseCount) - SUM(RetractCount) LastYearNetPurchaseCount,
	SUM(PurchaseAmount) - SUM(RetractAmount) LastYearNetPurchaseAmount,
	
	SUM(PurchaseCount) - SUM(RetractCount) + SUM(DividendCount) + SUM(RedemptoryCount) LastYearTotalCount,
	SUM(PurchaseAmount) - SUM(RetractAmount) + SUM(DividendAmount) + SUM(RedemptoryAmount) LastYearTotalAmount
into
	#LastYearData
from
	Table_FundTransSum
where
	TransDate >= @LastYearStartDate
	and
	TransDate < @LastYearEndDate;
	
--6. Get ThisYearRunning Data
select
	SUM(PurchaseCount) ThisYearRunningPurchaseCount,
	SUM(PurchaseAmount) ThisYearRunningPurchaseAmount,
	
	SUM(RetractCount) ThisYearRunningRetractCount,
	SUM(RetractAmount) ThisYearRunningRetractAmount,
	
	SUM(DividendCount) ThisYearRunningDividendCount,
	SUM(DividendAmount) ThisYearRunningDividendAmount,
	
	SUM(RedemptoryCount) ThisYearRunningRedemptoryCount,
	SUM(RedemptoryAmount) ThisYearRunningRedemptoryAmount,
	
	SUM(PurchaseCount) - SUM(RetractCount) ThisYearRunningNetPurchaseCount,
	SUM(PurchaseAmount) - SUM(RetractAmount) ThisYearRunningNetPurchaseAmount,
	
	SUM(PurchaseCount) - SUM(RetractCount) + SUM(DividendCount) + SUM(RedemptoryCount) ThisYearRunningTotalCount,
	SUM(PurchaseAmount) - SUM(RetractAmount) + SUM(DividendAmount) + SUM(RedemptoryAmount) ThisYearRunningTotalAmount
into
	#ThisYearRunningData
from
	Table_FundTransSum
where
	TransDate >= @ThisYearRunningStartDate
	and
	TransDate < @ThisYearRunningEndDate;
	
--7. Cross Join All Temp Tables
select
	CurrData.*,
	PrevData.*,
	LastYearData.*,
	ThisYearRunningData.*
into
	#AllData
from
	#CurrData CurrData
	cross join
	#PrevData PrevData
	cross join
	#LastYearData LastYearData
	cross join
	#ThisYearRunningData ThisYearRunningData;

--8. Pivot Table
--8.1 Create NumSequence Table
if OBJECT_ID(N'NumSequence', N'U') is null
begin
	select
		ROW_NUMBER() over(order by (select 1)) rowid
	into
		NumSequence
	from
		sys.objects cols1
		cross join
		sys.objects cols2;
end;

--8.2 Expand rows and do pivot
With ExpandRowCount as
(
	select
		rowid
	from
		NumSequence
	where
		rowid < 7
)
select
	ExpandRowCount.rowid,
	case when ExpandRowCount.rowid = 1 then N'申购'
		when ExpandRowCount.rowid = 2 then N'撤单'
		when ExpandRowCount.rowid = 3 then N'分红'
		when ExpandRowCount.rowid = 4 then N'赎回'
		when ExpandRowCount.rowid = 5 then N'净申购'
		when ExpandRowCount.rowid = 6 then N'基金交易量'
	else N'' end as BizType,
	
--Curr Amount
	case when ExpandRowCount.rowid = 1 then AllData.CurrPurchaseAmount
		when ExpandRowCount.rowid = 2 then AllData.CurrRetractAmount
		when ExpandRowCount.rowid = 3 then AllData.CurrDividendAmount
		when ExpandRowCount.rowid = 4 then AllData.CurrRedemptoryAmount
		when ExpandRowCount.rowid = 5 then AllData.CurrNetPurchaseAmount
		when ExpandRowCount.rowid = 6 then AllData.CurrTotalAmount
	else 0 end as CurrAmount,
--Curr Count	
	case when ExpandRowCount.rowid = 1 then AllData.CurrPurchaseCount
		when ExpandRowCount.rowid = 2 then AllData.CurrRetractCount
		when ExpandRowCount.rowid = 3 then AllData.CurrDividendCount
		when ExpandRowCount.rowid = 4 then AllData.CurrRedemptoryCount
		when ExpandRowCount.rowid = 5 then AllData.CurrNetPurchaseCount
		when ExpandRowCount.rowid = 6 then AllData.CurrTotalCount
	else 0 end as CurrCount,
	
--Prev Amount	
	case when ExpandRowCount.rowid = 1 then AllData.PrevPurchaseAmount
		when ExpandRowCount.rowid = 2 then AllData.PrevRetractAmount
		when ExpandRowCount.rowid = 3 then AllData.PrevDividendAmount
		when ExpandRowCount.rowid = 4 then AllData.PrevRedemptoryAmount
		when ExpandRowCount.rowid = 5 then AllData.PrevNetPurchaseAmount
		when ExpandRowCount.rowid = 6 then AllData.PrevTotalAmount
	else 0 end as PrevAmount,
--Prev Count	
	case when ExpandRowCount.rowid = 1 then AllData.PrevPurchaseCount
		when ExpandRowCount.rowid = 2 then AllData.PrevRetractCount
		when ExpandRowCount.rowid = 3 then AllData.PrevDividendCount
		when ExpandRowCount.rowid = 4 then AllData.PrevRedemptoryCount
		when ExpandRowCount.rowid = 5 then AllData.PrevNetPurchaseCount
		when ExpandRowCount.rowid = 6 then AllData.PrevTotalCount
	else 0 end as PrevCount,
	
--Last Year Amount	
	case when ExpandRowCount.rowid = 1 then AllData.LastYearPurchaseAmount
		when ExpandRowCount.rowid = 2 then AllData.LastYearRetractAmount
		when ExpandRowCount.rowid = 3 then AllData.LastYearDividendAmount
		when ExpandRowCount.rowid = 4 then AllData.LastYearRedemptoryAmount
		when ExpandRowCount.rowid = 5 then AllData.LastYearNetPurchaseAmount
		when ExpandRowCount.rowid = 6 then AllData.LastYearTotalAmount
	else 0 end as LastYearAmount,
--Last Year Count	
	case when ExpandRowCount.rowid = 1 then AllData.LastYearPurchaseCount
		when ExpandRowCount.rowid = 2 then AllData.LastYearRetractCount
		when ExpandRowCount.rowid = 3 then AllData.LastYearDividendCount
		when ExpandRowCount.rowid = 4 then AllData.LastYearRedemptoryCount
		when ExpandRowCount.rowid = 5 then AllData.LastYearNetPurchaseCount
		when ExpandRowCount.rowid = 6 then AllData.LastYearTotalCount
	else 0 end as LastYearCount,
	
--This Year Running Amount	
	case when ExpandRowCount.rowid = 1 then AllData.ThisYearRunningPurchaseAmount
		when ExpandRowCount.rowid = 2 then AllData.ThisYearRunningRetractAmount
		when ExpandRowCount.rowid = 3 then AllData.ThisYearRunningDividendAmount
		when ExpandRowCount.rowid = 4 then AllData.ThisYearRunningRedemptoryAmount
		when ExpandRowCount.rowid = 5 then AllData.ThisYearRunningNetPurchaseAmount
		when ExpandRowCount.rowid = 6 then AllData.ThisYearRunningTotalAmount
	else 0 end as ThisYearRunningAmount,
--This Year Running Count	
	case when ExpandRowCount.rowid = 1 then AllData.ThisYearRunningPurchaseCount
		when ExpandRowCount.rowid = 2 then AllData.ThisYearRunningRetractCount
		when ExpandRowCount.rowid = 3 then AllData.ThisYearRunningDividendCount
		when ExpandRowCount.rowid = 4 then AllData.ThisYearRunningRedemptoryCount
		when ExpandRowCount.rowid = 5 then AllData.ThisYearRunningNetPurchaseCount
		when ExpandRowCount.rowid = 6 then AllData.ThisYearRunningTotalCount
	else 0 end as ThisYearRunningCount
into
	#PivotData
from
	#AllData AllData
	cross join
	ExpandRowCount;

select
	rowid,
	BizType,
	convert(decimal, CurrAmount)/1000000 as CurrAmount,
	convert(decimal, CurrCount)/10000 as CurrCount,
	
	case when CurrCount = 0 then null else (convert(decimal, CurrAmount)/100)/CurrCount end as CurrAvg,
	case when PrevAmount = 0 then null else convert(decimal, (CurrAmount - PrevAmount))/PrevAmount end as SeqAmountIncrementRatio,
	case when PrevCount = 0 then null else convert(decimal, (CurrCount - PrevCount))/PrevCount end as SeqCountIncrementRatio,
	case when LastYearAmount = 0 then null else convert(decimal, (CurrAmount - LastYearAmount))/LastYearAmount end as YOYAmountIncrementRatio,
	case when LastYearCount = 0 then null else convert(decimal, (CurrCount - LastYearCount))/LastYearCount end as YOYCountIncrementRatio, 
	
	convert(decimal, ThisYearRunningAmount)/1000000 as ThisYearRunningAmount,
	convert(decimal, ThisYearRunningCount)/10000 as ThisYearRunningCount
from
	#PivotData;

--9. Clear temp table
drop table #CurrData;
drop table #PrevData;
drop table #LastYearData;
drop table #ThisYearRunningData;
drop table #AllData;
drop table #PivotData;

end 