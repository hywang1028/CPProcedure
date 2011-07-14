if OBJECT_ID(N'Proc_QueryCPFundMerchantTransCountReport', N'P') is not null
begin
	drop procedure Proc_QueryCPFundMerchantTransCountReport;
end
go

create procedure Proc_QueryCPFundMerchantTransCountReport
	@StartDate datetime = '2011-05-01',
	@PeriodUnit nchar(3) = N'自定义',
	@EndDate datetime = '2011-05-30'
as
begin

--1. Check input
if (@StartDate is null or ISNULL(@PeriodUnit, N'') = N'' or (@PeriodUnit = N'自定义' and @EndDate is null))
begin
	raiserror(N'Input params cannot be empty in Proc_QueryCPFundMerchantTransCountReport', 16, 1);
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
	MerchantNo,
	SUM(isnull(RegisterCount,0)) as RegisterCount,
	SUM(isnull(PurchaseCount,0)) as PurchaseCount,
	SUM(isnull(RetractCount,0)) as RetractCount,
	SUM(isnull(DividendCount,0)) as DividendCount,
	SUM(isnull(RedemptoryCount,0)) as RedemptoryCount,
	SUM(isnull(PurchaseCount,0)-isnull(RetractCount,0)) as NetPurchaseCount,
	SUM(isnull(PurchaseCount,0)-isnull(RetractCount,0)+isnull(DividendCount,0)+isnull(RedemptoryCount,0)) as TotalCount
into
	#CurrData
from
	Table_FundTransSum
where
	TransDate >= @CurrStartDate
	and
	TransDate < @CurrEndDate
group by
	MerchantNo;
	
--4. Get Previous Data
select
	MerchantNo,
	SUM(isnull(PurchaseCount,0)-isnull(RetractCount,0)) as NetPurchaseCount,
	SUM(isnull(PurchaseCount,0)-isnull(RetractCount,0)+isnull(DividendCount,0)+isnull(RedemptoryCount,0)) as TotalCount
into
	#PrevData
from
	Table_FundTransSum
where
	TransDate >= @PrevStartDate
	and
	TransDate < @PrevEndDate
group by
	MerchantNo;

--5. Get LastYear Data
select
	MerchantNo,
	SUM(isnull(PurchaseCount,0)-isnull(RetractCount,0)) as NetPurchaseCount,
	SUM(isnull(PurchaseCount,0)-isnull(RetractCount,0)+isnull(DividendCount,0)+isnull(RedemptoryCount,0)) as TotalCount
into
	#LastYearData
from
	Table_FundTransSum
where
	TransDate >= @LastYearStartDate
	and
	TransDate < @LastYearEndDate
group by
	MerchantNo;
	
--6. Get ThisYearRunning Data
select
	MerchantNo,
	SUM(isnull(PurchaseCount,0)-isnull(RetractCount,0)) as NetPurchaseCount,
	SUM(isnull(PurchaseCount,0)-isnull(RetractCount,0)+isnull(DividendCount,0)+isnull(RedemptoryCount,0)) as TotalCount
into
	#ThisYearRunningData
from
	Table_FundTransSum
where
	TransDate >= @ThisYearRunningStartDate
	and
	TransDate < @ThisYearRunningEndDate
group by
	MerchantNo;

--7. Get Result
select
	BizFundMerchant.MerchantName,
	Curr.RegisterCount,
	CONVERT(decimal,Curr.PurchaseCount)/10000 PurchaseCount,
	CONVERT(decimal,Curr.RetractCount)/10000 RetractCount,
	CONVERT(decimal,Curr.DividendCount)/10000 DividendCount,
	CONVERT(decimal,Curr.RedemptoryCount)/10000 RedemptoryCount,
	CONVERT(decimal,Curr.NetPurchaseCount)/10000 NetPurchaseCount,
	CONVERT(decimal,Curr.TotalCount)/10000 TotalCount,
	case when ISNULL(Prev.NetPurchaseCount, 0) = 0
		then null
		else CONVERT(decimal, ISNULL(Curr.NetPurchaseCount, 0) - ISNULL(Prev.NetPurchaseCount, 0))/Prev.NetPurchaseCount
	end SeqNetPurchaseIncrementRatio,
	case when ISNULL(Prev.TotalCount, 0) = 0
		then null
		else CONVERT(decimal, ISNULL(Curr.TotalCount, 0) - ISNULL(Prev.TotalCount, 0))/Prev.TotalCount
	end SeqTotalCountIncrementRatio,
	case when ISNULL(LastYear.NetPurchaseCount, 0) = 0
		then null
		else CONVERT(decimal, ISNULL(Curr.NetPurchaseCount, 0) - ISNULL(LastYear.NetPurchaseCount, 0))/LastYear.NetPurchaseCount
	end YOYNetPurchaseIncrementRatio,
	case when ISNULL(LastYear.TotalCount, 0) = 0
		then null
		else CONVERT(decimal, ISNULL(Curr.TotalCount, 0) - ISNULL(LastYear.TotalCount, 0))/LastYear.TotalCount
	end YOYTotalCountIncrementRatio,
	convert(decimal, ISNULL(ThisYearRunning.NetPurchaseCount, 0))/10000 ThisYearNetPurchaseCount,
	convert(decimal, ISNULL(ThisYearRunning.TotalCount, 0))/10000 ThisYearTotalCount,
	Convert(decimal,ISNULL(Prev.NetPurchaseCount, 0))/1000000 PrevNetPurchaseCount,
	Convert(decimal,ISNULL(Prev.TotalCount, 0))/10000 PrevTotalCount,
	Convert(decimal,ISNULL(LastYear.NetPurchaseCount, 0))/1000000 LastYearNetPurchaseCount,
	Convert(decimal,ISNULL(LastYear.TotalCount, 0))/10000 LastYearTotalCount
from
	Table_BizFundMerchant BizFundMerchant
	left join
	#CurrData Curr
	on
		BizFundMerchant.MerchantNo = Curr.MerchantNo
	left join
	#PrevData Prev
	on
		BizFundMerchant.MerchantNo = Prev.MerchantNo
	left join
	#LastYearData LastYear
	on
		BizFundMerchant.MerchantNo = LastYear.MerchantNo
	left join
	#ThisYearRunningData ThisYearRunning
	on
		BizFundMerchant.MerchantNo = ThisYearRunning.MerchantNo;
	
--8. Clear temp table
drop table #CurrData;
drop table #PrevData;
drop table #LastYearData;
drop table #ThisYearRunningData;

end 