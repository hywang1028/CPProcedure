if OBJECT_ID(N'Proc_QueryCPFundMerchantTransAmountReport', N'P') is not null
begin
	drop procedure Proc_QueryCPFundMerchantTransAmountReport;
end
go

create procedure Proc_QueryCPFundMerchantTransAmountReport
	@StartDate datetime = '2011-05-15',
	@PeriodUnit nchar(3) = N'自定义',
	@EndDate datetime = '2011-05-16'
as
begin

--1. Check input
if (@StartDate is null or ISNULL(@PeriodUnit, N'') = N'' or (@PeriodUnit = N'自定义' and @EndDate is null))
begin
	raiserror(N'Input params cannot be empty in Proc_QueryCPFundMerchantTransAmountReport', 16, 1);
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
With CurrFundTrans as
(
	select
		MerchantNo,
		TransType,
		COUNT(TransAmt) TransCnt,
		SUM(TransAmt) TransAmt
	from
		Table_TrfTransLog
	where
		TransDate >= @CurrStartDate
		and
		TransDate <  @CurrEndDate
		and
		TransType in ('1010','3010','3020','3030','3040','3050')
	group by
		MerchantNo,
		TransType
)
select
	MerchantNo,
	SUM(case when TransType = '1010' then TransCnt End) RegisterCount,	
	SUM(case when TransType = '3010' then TransAmt End) PurchaseAmount,	
	SUM(case when TransType = '3020' then TransAmt End) RetractAmount,		
	SUM(case when TransType = '3030' then TransAmt End) RedemptoryAmount,	
	SUM(case when TransType = '3040' then TransAmt End) DividendAmount,	
	SUM(case when TransType = '3050' then TransAmt End) RegularAmount,	
	SUM(case when TransType in ('3010','3020') then case when TransType = '3020' then -1*TransAmt Else TransAmt End End) NetPurchaseAmount,
	SUM(case when TransType = '3020' then -1*TransAmt Else TransAmt End) TotalAmount
into
	#CurrData	
from
	CurrFundTrans
group by
	MerchantNo;
	
--4. Get Previous Data
select
	MerchantNo,
	SUM(case when TransType in ('3010','3020') then case when TransType = '3020' then -1*TransAmt Else TransAmt End End) NetPurchaseAmount,
	SUM(case when TransType = '3020' then -1*TransAmt Else TransAmt End) TotalAmount
into
	#PrevData	
from
	Table_TrfTransLog
where
	TransDate >= @PrevStartDate
	and
	TransDate <  @PrevEndDate
	and
	TransType in ('3010','3020','3030','3040','3050')
group by
	MerchantNo;

--5. Get LastYear Data
select
	MerchantNo,
	SUM(case when TransType in ('3010','3020') then case when TransType = '3020' then -1*TransAmt Else TransAmt End End) NetPurchaseAmount,
	SUM(case when TransType = '3020' then -1*TransAmt Else TransAmt End) TotalAmount
into
	#LastYearData	
from
	Table_TrfTransLog
where
	TransDate >= @LastYearStartDate
	and
	TransDate <  @LastYearEndDate
	and
	TransType in ('3010','3020','3030','3040','3050')
group by
	MerchantNo;
	
--6. Get ThisYearRunning Data
select
	MerchantNo,
	SUM(case when TransType in ('3010','3020') then case when TransType = '3020' then -1*TransAmt Else TransAmt End End) NetPurchaseAmount,
	SUM(case when TransType = '3020' then -1*TransAmt Else TransAmt End) TotalAmount
into
	#ThisYearRunningData	
from
	Table_TrfTransLog
where
	TransDate >= @ThisYearRunningStartDate
	and
	TransDate <  @ThisYearRunningEndDate
	and
	TransType in ('3010','3020','3030','3040','3050')
group by
	MerchantNo;
	
--7. Get Current period total SucceedAmount 
declare @CurrNetPurchaseAmount bigint;
set @CurrNetPurchaseAmount = (select ISNULL(SUM(NetPurchaseAmount),0) from #CurrData);

declare @CurrTotalAmount bigint;
set @CurrTotalAmount = (select ISNULL(SUM(TotalAmount),0) from #CurrData);

--8. Get Result
select
	(select MerchantName from Table_MerInfo where MerchantNo = coalesce(Curr.MerchantNo,Prev.MerchantNo,LastYear.MerchantNo,ThisYearRunning.MerchantNo)) MerchantName,
	Curr.RegisterCount,
	CONVERT(decimal,Curr.PurchaseAmount)/1000000 PurchaseAmount,
	CONVERT(decimal,Curr.RetractAmount)/1000000 RetractAmount,
	CONVERT(decimal,Curr.RedemptoryAmount)/1000000 RedemptoryAmount,
	CONVERT(decimal,Curr.DividendAmount)/1000000 DividendAmount,
	CONVERT(decimal,Curr.RegularAmount)/1000000 RegularAmount,
	CONVERT(decimal,Curr.NetPurchaseAmount)/1000000 NetPurchaseAmount,
	CONVERT(decimal,Curr.TotalAmount)/1000000 TotalAmount,
	case when ISNULL(@CurrNetPurchaseAmount, 0) = 0
		then null
		else CONVERT(decimal, ISNULL(Curr.NetPurchaseAmount, 0))/@CurrNetPurchaseAmount
	end NetPurchaseDutyRatio,
	case when ISNULL(@CurrTotalAmount, 0) = 0
		then null
		else CONVERT(decimal, ISNULL(Curr.TotalAmount, 0))/@CurrTotalAmount
	end TotalAmountDutyRatio,
	case when ISNULL(Prev.NetPurchaseAmount, 0) = 0
		then null
		else CONVERT(decimal, ISNULL(Curr.NetPurchaseAmount, 0) - ISNULL(Prev.NetPurchaseAmount, 0))/Prev.NetPurchaseAmount
	end SeqNetPurchaseIncrementRatio,
	case when ISNULL(Prev.TotalAmount, 0) = 0
		then null
		else CONVERT(decimal, ISNULL(Curr.TotalAmount, 0) - ISNULL(Prev.TotalAmount, 0))/Prev.TotalAmount
	end SeqTotalCountIncrementRatio,
	case when ISNULL(LastYear.NetPurchaseAmount, 0) = 0
		then null
		else CONVERT(decimal, ISNULL(Curr.NetPurchaseAmount, 0) - ISNULL(LastYear.NetPurchaseAmount, 0))/LastYear.NetPurchaseAmount
	end YOYNetPurchaseIncrementRatio,
	case when ISNULL(LastYear.TotalAmount, 0) = 0
		then null
		else CONVERT(decimal, ISNULL(Curr.TotalAmount, 0) - ISNULL(LastYear.TotalAmount, 0))/LastYear.TotalAmount
	end YOYTotalCountIncrementRatio,
	convert(decimal, ISNULL(ThisYearRunning.NetPurchaseAmount, 0))/1000000 ThisYearNetPurchaseAmount,
	convert(decimal, ISNULL(ThisYearRunning.TotalAmount, 0))/1000000 ThisYearTotalAmount,
	Convert(decimal, ISNULL(Prev.NetPurchaseAmount, 0))/1000000 PrevNetPurchaseAmount,
	Convert(decimal, ISNULL(Prev.TotalAmount, 0))/1000000 PrevTotalAmount,
	Convert(decimal, ISNULL(LastYear.NetPurchaseAmount, 0))/1000000 LastYearNetPurchaseAmount,
	Convert(decimal, ISNULL(LastYear.TotalAmount, 0))/1000000 LastYearTotalAmount
from
	#CurrData Curr
	full outer join
	#PrevData Prev
	on
		Curr.MerchantNo = Prev.MerchantNo
	full outer join
	#LastYearData LastYear
	on
		coalesce(Curr.MerchantNo,Prev.MerchantNo) = LastYear.MerchantNo
	full outer join
	#ThisYearRunningData ThisYearRunning
	on
		coalesce(Curr.MerchantNo,Prev.MerchantNo,LastYear.MerchantNo) = ThisYearRunning.MerchantNo;
	
--9. Clear temp table
drop table #CurrData;
drop table #PrevData;
drop table #LastYearData;
drop table #ThisYearRunningData;

end 