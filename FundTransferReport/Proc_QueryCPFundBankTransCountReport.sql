if OBJECT_ID(N'Proc_QueryCPFundBankTransCountReport', N'P') is not null
begin
	drop procedure Proc_QueryCPFundBankTransCountReport;
end
go

create procedure Proc_QueryCPFundBankTransCountReport
	@StartDate datetime = '2011-05-01',
	@PeriodUnit nchar(3) = N'自定义',
	@EndDate datetime = '2011-05-30'
as
begin

--1. Check input
if (@StartDate is null or ISNULL(@PeriodUnit, N'') = N'' or (@PeriodUnit = N'自定义' and @EndDate is null))
begin
	raiserror(N'Input params cannot be empty in Proc_QueryCPFundBankTransCountReport', 16, 1);
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
	SUM(case when TransType = '3010' then TransCnt End) PurchaseCount,	
	SUM(case when TransType = '3020' then TransCnt End) RetractCount,		
	SUM(case when TransType = '3030' then TransCnt End) RedemptoryCount,	
	SUM(case when TransType = '3040' then TransCnt End) DividendCount,	
	SUM(case when TransType = '3050' then TransCnt End) RegularCount,	
	SUM(case when TransType in ('3010','3020') then case when TransType = '3020' then -1*TransCnt Else TransCnt End End) NetPurchaseCount,
	SUM(case when TransType = '3020' then -1*TransCnt Else TransCnt End) TotalCount
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
	SUM(case when TransType in ('3010','3020') then case when TransType = '3020' then -1*TransCnt Else TransCnt End End) NetPurchaseCount,
	SUM(case when TransType = '3020' then -1*TransCnt Else TransCnt End) TotalCount
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
	SUM(case when TransType in ('3010','3020') then case when TransType = '3020' then -1*TransCnt Else TransCnt End End) NetPurchaseCount,
	SUM(case when TransType = '3020' then -1*TransCnt Else TransCnt End) TotalCount
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
	SUM(case when TransType in ('3010','3020') then case when TransType = '3020' then -1*TransCnt Else TransCnt End End) NetPurchaseCount,
	SUM(case when TransType = '3020' then -1*TransCnt Else TransCnt End) TotalCount
into
	#ThisYearRunningData	
from
	TransData
group by
	BankName;

--7. Get Result
select
	coalesce(Curr.BankName,Prev.BankName,LastYear.BankName,ThisYearRunning.BankName,N'未知银行') BankName,
	Curr.RegisterCount,
	CONVERT(decimal,Curr.PurchaseCount)/10000 PurchaseCount,
	CONVERT(decimal,Curr.RetractCount)/10000 RetractCount,
	CONVERT(decimal,Curr.RedemptoryCount)/10000 RedemptoryCount,
	CONVERT(decimal,Curr.DividendCount)/10000 DividendCount,
	CONVERT(decimal,Curr.RegularCount)/10000 RegularCount,
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
	
--8. Clear temp table
drop table #CurrData;
drop table #PrevData;
drop table #LastYearData;
drop table #ThisYearRunningData;

end 