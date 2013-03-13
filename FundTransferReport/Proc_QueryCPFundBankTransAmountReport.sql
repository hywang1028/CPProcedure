if OBJECT_ID(N'Proc_QueryCPFundBankTransAmountReport', N'P') is not null
begin
	drop procedure Proc_QueryCPFundBankTransAmountReport;
end
go

create procedure Proc_QueryCPFundBankTransAmountReport
	@StartDate datetime = '2011-05-01',
	@PeriodUnit nchar(4) = N'自定义',
	@EndDate datetime = '2011-05-30'
as
begin

--1. Check input
if (@StartDate is null or ISNULL(@PeriodUnit, N'') = N'' or (@PeriodUnit = N'自定义' and @EndDate is null))
begin
	raiserror(N'Input params cannot be empty in Proc_QueryCPFundBankTransAmountReport', 16, 1);
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
With CurrTransWithCardNo as
(
	select
		TransType,
		TransAmt,
		case when
			TransType in ('1010','3010')
		then
			CardID
		else
			CardTwo
		end CardNo
	from
		dbo.Table_TrfTransLog
	where
		TransType in ('1010','3010','3020','3030','3040','3050')
		and
		TransDate >= @CurrStartDate
		and
		TransDate <  @CurrEndDate
),
TransData as
(
	select
		(select BankName from Table_BankID where BankNo = FundCardBin.BankNo) BankName,
		TransWithCardNo.TransType,
		Sum(TransWithCardNo.TransAmt) as TransAmt,
		COUNT(TransWithCardNo.TransAmt) as TransCnt
	from
		CurrTransWithCardNo TransWithCardNo
		left join
		dbo.Table_FundCardBin FundCardBin
		on
			TransWithCardNo.CardNo like (RTrim(FundCardBin.CardBin)+'%')
	group by
		FundCardBin.BankNo,
		TransWithCardNo.TransType
)
select
	ISNULL(BankName,N'未知银行') BankName,
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
	TransData
group by
	BankName;
	
--4. Get Previous Data
With CurrTransWithCardNo as
(
	select
		TransType,
		TransAmt,
		case when
			TransType in ('3010')
		then
			CardID
		else
			CardTwo
		end CardNo
	from
		dbo.Table_TrfTransLog
	where
		TransType in ('3010','3020','3030','3040','3050')
		and
		TransDate >= @PrevStartDate
		and
		TransDate <  @PrevEndDate
),
TransData as
(
	select
		(select BankName from Table_BankID where BankNo = FundCardBin.BankNo) BankName,
		TransWithCardNo.TransType,
		Sum(TransWithCardNo.TransAmt) as TransAmt,
		COUNT(TransWithCardNo.TransAmt) as TransCnt
	from
		CurrTransWithCardNo TransWithCardNo
		left join
		dbo.Table_FundCardBin FundCardBin
		on
			TransWithCardNo.CardNo like (RTrim(FundCardBin.CardBin)+'%')
	group by
		FundCardBin.BankNo,
		TransWithCardNo.TransType
)
select
	ISNULL(BankName,N'未知银行') BankName,
	SUM(case when TransType in ('3010','3020') then case when TransType = '3020' then -1*TransAmt Else TransAmt End End) NetPurchaseAmount,
	SUM(case when TransType = '3020' then -1*TransAmt Else TransAmt End) TotalAmount
into
	#PrevData	
from
	TransData
group by
	BankName;

--5. Get LastYear Data
With CurrTransWithCardNo as
(
	select
		TransType,
		TransAmt,
		case when
			TransType in ('3010')
		then
			CardID
		else
			CardTwo
		end CardNo
	from
		dbo.Table_TrfTransLog
	where
		TransType in ('3010','3020','3030','3040','3050')
		and
		TransDate >= @LastYearStartDate
		and
		TransDate <  @LastYearEndDate
),
TransData as
(
	select
		(select BankName from Table_BankID where BankNo = FundCardBin.BankNo) BankName,
		TransWithCardNo.TransType,
		Sum(TransWithCardNo.TransAmt) as TransAmt,
		COUNT(TransWithCardNo.TransAmt) as TransCnt
	from
		CurrTransWithCardNo TransWithCardNo
		left join
		dbo.Table_FundCardBin FundCardBin
		on
			TransWithCardNo.CardNo like (RTrim(FundCardBin.CardBin)+'%')
	group by
		FundCardBin.BankNo,
		TransWithCardNo.TransType
)
select
	ISNULL(BankName,N'未知银行') BankName,
	SUM(case when TransType in ('3010','3020') then case when TransType = '3020' then -1*TransAmt Else TransAmt End End) NetPurchaseAmount,
	SUM(case when TransType = '3020' then -1*TransAmt Else TransAmt End) TotalAmount
into
	#LastYearData	
from
	TransData
group by
	BankName;
	
--6. Get ThisYearRunning Data
With CurrTransWithCardNo as
(
	select
		TransType,
		TransAmt,
		case when
			TransType in ('3010')
		then
			CardID
		else
			CardTwo
		end CardNo
	from
		dbo.Table_TrfTransLog
	where
		TransType in ('3010','3020','3030','3040','3050')
		and
		TransDate >= @ThisYearRunningStartDate
		and
		TransDate <  @ThisYearRunningEndDate
),
TransData as
(
	select
		(select BankName from Table_BankID where BankNo = FundCardBin.BankNo) BankName,
		TransWithCardNo.TransType,
		Sum(TransWithCardNo.TransAmt) as TransAmt,
		COUNT(TransWithCardNo.TransAmt) as TransCnt
	from
		CurrTransWithCardNo TransWithCardNo
		left join
		dbo.Table_FundCardBin FundCardBin
		on
			TransWithCardNo.CardNo like (RTrim(FundCardBin.CardBin)+'%')
	group by
		FundCardBin.BankNo,
		TransWithCardNo.TransType
)
select
	ISNULL(BankName,N'未知银行') BankName,
	SUM(case when TransType in ('3010','3020') then case when TransType = '3020' then -1*TransAmt Else TransAmt End End) NetPurchaseAmount,
	SUM(case when TransType = '3020' then -1*TransAmt Else TransAmt End) TotalAmount
into
	#ThisYearRunningData	
from
	TransData
group by
	BankName;
	
--7. Get Current period total SucceedAmount 
declare @CurrNetPurchaseAmount bigint;
set @CurrNetPurchaseAmount = (select ISNULL(SUM(NetPurchaseAmount),0) from #CurrData);

declare @CurrTotalAmount bigint;
set @CurrTotalAmount = (select ISNULL(SUM(TotalAmount),0) from #CurrData);

--8. Get Result
select
	coalesce(Curr.BankName,Prev.BankName,LastYear.BankName,ThisYearRunning.BankName,N'未知银行') BankName,
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
		Curr.BankName = Prev.BankName
	full outer join
	#LastYearData LastYear
	on
		coalesce(Curr.BankName,Prev.BankName) = LastYear.BankName
	full outer join
	#ThisYearRunningData ThisYearRunning
	on
		coalesce(Curr.BankName,Prev.BankName,LastYear.BankName) = ThisYearRunning.BankName;
	
--9. Clear temp table
drop table #CurrData;
drop table #PrevData;
drop table #LastYearData;
drop table #ThisYearRunningData;

end 