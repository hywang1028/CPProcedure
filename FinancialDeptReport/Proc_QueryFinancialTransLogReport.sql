if OBJECT_ID(N'Proc_QueryFinancialTransLogReport', N'P') is not null
begin
	drop procedure Proc_QueryFinancialTransLogReport;
end
go

create procedure Proc_QueryFinancialTransLogReport
	@StartDate datetime = '2011-05-12',
	@EndDate datetime = '2011-05-30'
as
begin

--1. Check input
if (@StartDate is null or @EndDate is null)
begin
	raiserror(N'Input params cannot be empty in Proc_QueryFinancialTransLogReport', 16, 1);
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

set @CurrStartDate = @StartDate;
set @CurrEndDate = DateAdd(day,1,@EndDate);
set @PrevStartDate = DATEADD(DAY, -1*datediff(day,@CurrStartDate,@CurrEndDate), @CurrStartDate);
set @PrevEndDate = @CurrStartDate;
set @LastYearStartDate = DATEADD(year, -1, @CurrStartDate); 
set @LastYearEndDate = DATEADD(year, -1, @CurrEndDate);

set @ThisYearRunningStartDate = CONVERT(char(4), YEAR(@CurrStartDate)) + '-01-01';
set @ThisYearRunningEndDate = @CurrEndDate;

----3.Get the Current Data
--3.1 Get Fund Trans With Card No
select
	TransDate,
	MerchantNo,
	TransType,
	TransAmt,
	FeeAmt,
	FundType,
	case when
		TransType in ('1010','3010')
	then
		CardID
	else
		CardTwo
	end CardNo
into
	#CurrTransWithCardNo
from
	dbo.Table_TrfTransLog
where
	TransType in ('1010','3010','3020','3030','3040','3050')
	and
	TransDate >= @CurrStartDate
	and
	TransDate < @CurrEndDate;

--3.2 Prepare BankNo and BranchNo
select
	TransWithCardNo.MerchantNo,
	FundCardBin.BankNo,
	SUBSTRING(TransWithCardNo.CardNo, LEN(FundCardBin.CardBin)+1, 2) as BranchNo,
	TransWithCardNo.TransType,
	TransWithCardNo.FundType,
	Convert(Decimal,Sum(TransWithCardNo.TransAmt))/100 as TransAmount,
	COUNT(TransWithCardNo.TransAmt) as TransCount
into
	#CurrTransWithBankNo
from
	#CurrTransWithCardNo TransWithCardNo
	left join
	dbo.Table_FundCardBin FundCardBin
	on
		TransWithCardNo.CardNo like (RTrim(FundCardBin.CardBin)+'%')
group by
	TransWithCardNo.MerchantNo,
	FundCardBin.BankNo,
	SUBSTRING(TransWithCardNo.CardNo, LEN(FundCardBin.CardBin)+1, 2),
	TransWithCardNo.FundType,
	TransWithCardNo.TransType;

--3.3 synthesize TransType and FundType to ColName
select 
	RT.MerchantNo,
	RT.BankNo,
	RT.BranchNo,	
--开户
	case when
		RT.TransType = '1010'
	then
		N'开户认证'
--申购		
	when
		RT.TransType = '3010' and RT.FundType = '0'
	then
		N'申购股票型'
	when
		RT.TransType = '3010' and RT.FundType = '1'
	then
		N'申购货币型'
	when
		RT.TransType = '3010' and RT.FundType = '2'
	then
		N'申购债券型'		
	when
		RT.TransType = '3010' and RT.FundType not in ('0','1','2')
	then
		N'申购股票型'
--撤单		
	when
		RT.TransType = '3020'
	then
		N'撤单'
--赎回
	when
		RT.TransType = '3030' and RT.FundType = '0'
	then
		N'赎回股票型'
	when
		RT.TransType = '3030' and RT.FundType = '1'
	then
		N'赎回货币型'
	when
		RT.TransType = '3030' and RT.FundType = '2'
	then
		N'赎回债券型'		
	when
		RT.TransType = '3030' and RT.FundType not in ('0','1','2')
	then
		N'赎回股票型'
--分红	
	when
		RT.TransType = '3040'
	then
		N'分红'
--定投
	when
		RT.TransType = '3050'
	then
		N'定投'			
	end ColName,
	RT.TransAmount,
	RT.TransCount
into
	#CurrResultTable2
from
	#CurrTransWithBankNo RT;
	
--3.4 Pivot Table (Row to Column)
select
	RT.MerchantNo,
	RT.BankNo,
	RT.BranchNo,
	SUM(case when
		ColName = N'开户认证'
	then
		TransCount
	else
		0
	end) as RegisterCount,
	
	SUM(case when
		ColName = N'申购货币型'
	then
		TransCount
	else
		0
	end) as PurchaseCurrencyCount,
	SUM(case when
		ColName = N'申购货币型'
	then
		TransAmount
	else
		0
	end) as PurchaseCurrencyAmount,
	
	SUM(case when
		ColName = N'申购股票型'
	then
		TransCount
	else
		0
	end) as PurchaseStockCount,
	SUM(case when
		ColName = N'申购股票型'
	then
		TransAmount
	else
		0
	end) as PurchaseStockAmount,
	
	SUM(case when
		ColName = N'申购债券型'
	then
		TransCount
	else
		0
	end) as PurchaseBondCount,
	SUM(case when
		ColName = N'申购债券型'
	then
		TransAmount
	else
		0
	end) as PurchaseBondAmount,
	
	SUM(case when
		ColName = N'申购其他型'
	then
		TransCount
	else
		0
	end) as PurchaseOtherCount,
	SUM(case when
		ColName = N'申购其他型'
	then
		TransAmount
	else
		0
	end) as PurchaseOtherAmount,
	
	SUM(case when
		ColName = N'撤单'
	then
		TransCount
	else
		0
	end) as RetractCount,
	SUM(case when
		ColName = N'撤单'
	then
		TransAmount
	else
		0
	end) as RetractAmount,
	
	SUM(case when
		ColName = N'赎回货币型'
	then
		TransCount
	else
		0
	end) as RedemptoryCurrencyCount,
	SUM(case when
		ColName = N'赎回货币型'
	then
		TransAmount
	else
		0
	end) as RedemptoryCurrencyAmount,
	
	SUM(case when
		ColName = N'赎回股票型'
	then
		TransCount
	else
		0
	end) as RedemptoryStockCount,
	SUM(case when
		ColName = N'赎回股票型'
	then
		TransAmount
	else
		0
	end) as RedemptoryStockAmount,
	
	SUM(case when
		ColName = N'赎回债券型'
	then
		TransCount
	else
		0
	end) as RedemptoryBondCount,
	SUM(case when
		ColName = N'赎回债券型'
	then
		TransAmount
	else
		0
	end) as RedemptoryBondAmount,
	
	SUM(case when
		ColName = N'赎回其他型'
	then
		TransCount
	else
		0
	end) as RedemptoryOtherCount,
	SUM(case when
		ColName = N'赎回其他型'
	then
		TransAmount
	else
		0
	end) as RedemptoryOtherAmount,
	
	SUM(case when
		ColName = N'分红'
	then
		TransCount
	else
		0
	end) as DividendCount,
	SUM(case when
		ColName = N'分红'
	then
		TransAmount
	else
		0
	end) as DividendAmount,	
	
	SUM(case when
		ColName = N'定投'
	then
		TransCount
	else
		0
	end) as ScheduleCount,
	SUM(case when
		ColName = N'定投'
	then
		TransAmount
	else
		0
	end) as ScheduleAmount
into
	#CurrResultTable3
from
	#CurrResultTable2 RT
group by
	MerchantNo,
	BankNo,
	BranchNo;
	
--3.5 Get Current Total Amount
declare @PurchaseAmount decimal(12,2);
set @PurchaseAmount = (select SUM(PurchaseCurrencyAmount)+SUM(PurchaseStockAmount)+SUM(PurchaseBondAmount)+SUM(PurchaseOtherAmount) from #CurrResultTable3);

declare @TotalAmount decimal(12,2);
set @TotalAmount = @PurchaseAmount + (select SUM(RedemptoryCurrencyAmount)+SUM(RedemptoryStockAmount)+SUM(RedemptoryBondAmount)+
										SUM(RedemptoryOtherAmount)+ SUM(RetractAmount)+SUM(DividendAmount) from #CurrResultTable3);
										
----4.Get the Previous Data
--4.1 Get Fund Trans With Card No
select
	TransDate,
	MerchantNo,
	TransType,
	TransAmt,
	FeeAmt,
	FundType,
	case when
		TransType in ('1010','3010')
	then
		CardID
	else
		CardTwo
	end CardNo
into
	#PrevTransWithCardNo
from
	dbo.Table_TrfTransLog
where
	TransType in ('1010','3010','3020','3030','3040','3050')
	and
	TransDate >= @PrevStartDate
	and
	TransDate < @PrevEndDate;

--4.2 Prepare BankNo and BranchNo
select
	TransWithCardNo.MerchantNo,
	FundCardBin.BankNo,
	SUBSTRING(TransWithCardNo.CardNo, LEN(FundCardBin.CardBin)+1, 2) as BranchNo,
	TransWithCardNo.TransType,
	TransWithCardNo.FundType,
	Convert(Decimal,Sum(TransWithCardNo.TransAmt))/100 as TransAmount,
	COUNT(TransWithCardNo.TransAmt) as TransCount
into
	#PrevTransWithBankNo
from
	#PrevTransWithCardNo TransWithCardNo
	left join
	dbo.Table_FundCardBin FundCardBin
	on
		TransWithCardNo.CardNo like (RTrim(FundCardBin.CardBin)+'%')
group by
	TransWithCardNo.MerchantNo,
	FundCardBin.BankNo,
	SUBSTRING(TransWithCardNo.CardNo, LEN(FundCardBin.CardBin)+1, 2),
	TransWithCardNo.FundType,
	TransWithCardNo.TransType;

--4.3 Pivot Table (Row to Column)
select
	RT.MerchantNo,
	RT.BankNo,
	RT.BranchNo,
	SUM(case when
		TransType = '3010'
	then
		TransAmount
	else
		0
	end) as PurchaseAmount,
	SUM(case when
		TransType in ('3010','3020','3030','3040')
	then
		TransAmount
	else
		0
	end) as TotalAmount
into
	#PrevResultTable2
from
	#PrevTransWithBankNo RT
group by
	MerchantNo,
	BankNo,
	BranchNo;

----5.Get the Last Year Data
--5.1 Get Fund Trans With Card No
select
	TransDate,
	MerchantNo,
	TransType,
	TransAmt,
	FeeAmt,
	FundType,
	case when
		TransType in ('1010','3010')
	then
		CardID
	else
		CardTwo
	end CardNo
into
	#LastYearTransWithCardNo
from
	dbo.Table_TrfTransLog
where
	TransType in ('1010','3010','3020','3030','3040','3050')
	and
	TransDate >= @LastYearStartDate
	and
	TransDate < @LastYearEndDate;

--5.2 Prepare BankNo and BranchNo
select
	TransWithCardNo.MerchantNo,
	FundCardBin.BankNo,
	SUBSTRING(TransWithCardNo.CardNo, LEN(FundCardBin.CardBin)+1, 2) as BranchNo,
	TransWithCardNo.TransType,
	TransWithCardNo.FundType,
	Convert(Decimal,Sum(TransWithCardNo.TransAmt))/100 as TransAmount,
	COUNT(TransWithCardNo.TransAmt) as TransCount
into
	#LastYearTransWithBankNo
from
	#LastYearTransWithCardNo TransWithCardNo
	left join
	dbo.Table_FundCardBin FundCardBin
	on
		TransWithCardNo.CardNo like (RTrim(FundCardBin.CardBin)+'%')
group by
	TransWithCardNo.MerchantNo,
	FundCardBin.BankNo,
	SUBSTRING(TransWithCardNo.CardNo, LEN(FundCardBin.CardBin)+1, 2),
	TransWithCardNo.FundType,
	TransWithCardNo.TransType;

--5.3 Pivot Table (Row to Column)
select
	RT.MerchantNo,
	RT.BankNo,
	RT.BranchNo,
	
	SUM(case when
		TransType = '3010'
	then
		TransAmount
	else
		0
	end) as PurchaseAmount,
	SUM(case when
		TransType in ('3010','3020','3030','3040')
	then
		TransAmount
	else
		0
	end) as TotalAmount
into
	#LastYearResultTable2
from
	#LastYearTransWithBankNo RT
group by
	MerchantNo,
	BankNo,
	BranchNo;

--6. Join All
select
	coalesce(C.MerchantNo,P.MerchantNo,L.MerchantNo) MerchantNo,
	coalesce(C.BankNo,P.BankNo,L.BankNo) BankNo,
	coalesce(C.BranchNo,P.BranchNo,L.BranchNo) BranchNo,
	isnull(C.RegisterCount,0) RegisterCount,
	isnull(C.PurchaseCurrencyCount,0) PurchaseCurrencyCount,
	isnull(C.PurchaseCurrencyAmount,0) PurchaseCurrencyAmount,
	isnull(C.PurchaseStockCount,0) PurchaseStockCount,
	isnull(C.PurchaseStockAmount,0) PurchaseStockAmount,
	isnull(C.PurchaseBondCount,0) PurchaseBondCount,
	isnull(C.PurchaseBondAmount,0) PurchaseBondAmount,
	isnull(C.RedemptoryCurrencyCount,0) RedemptoryCurrencyCount,
	isnull(C.RedemptoryCurrencyAmount,0) RedemptoryCurrencyAmount,
	isnull(C.RedemptoryStockCount,0) RedemptoryStockCount,
	isnull(C.RedemptoryStockAmount,0) RedemptoryStockAmount,
	isnull(C.RedemptoryBondCount,0) RedemptoryBondCount,
	isnull(C.RedemptoryBondAmount,0) RedemptoryBondAmount,
	isnull(C.RetractCount,0) RetractCount,
	isnull(C.RetractAmount,0) RetractAmount,
	isnull(C.DividendCount,0) DividendCount,
	isnull(C.DividendAmount,0) DividendAmount,
	isnull(C.ScheduleCount,0) ScheduleCount,
	isnull(C.ScheduleAmount,0) ScheduleAmount,
	ISNULL(P.PurchaseAmount,0) PrevPurchaseAmount,
	ISNULL(P.TotalAmount,0) PrevTotalAmount,
	ISNULL(L.PurchaseAmount,0) LastYearPurchaseAmount,
	ISNULL(L.TotalAmount,0) LastYearTotalAmount
into
	#ResultTable
from
	#CurrResultTable3 C
	full outer join
	#PrevResultTable2 P
	on
		C.MerchantNo = P.MerchantNo
		and
		C.BankNo = P.BankNo
		and
		C.BranchNo = P.BranchNo
	full outer join
	#LastYearResultTable2 L
	on
		coalesce(C.MerchantNo,P.MerchantNo) = L.MerchantNo
		and
		coalesce(C.BankNo,P.BankNo) = L.BankNo
		and
		coalesce(C.BranchNo,P.BranchNo) = L.BranchNo;

--7. Get Final Result
select
	(isnull(Result.BankNo,N'')+isnull(BankID.BankName,N'其他银行')) BankName,
	ISNULL(FundBankBranch.BankBranchName, N'其他分行') BankBranchName,
	(RTrim(Result.MerchantNo)+isnull(MerInfo.MerchantName,N'其他基金公司')) MerchantName,
	Result.*,
	(Result.PurchaseCurrencyCount+Result.PurchaseStockCount+Result.PurchaseBondCount) as PurchaseCount,
	(Result.PurchaseCurrencyAmount+Result.PurchaseStockAmount+Result.PurchaseBondAmount) as PurchaseAmount,
	(Result.RedemptoryCurrencyCount+Result.RedemptoryStockCount+Result.RedemptoryBondCount) as RedemptoryCount,
	(Result.RedemptoryCurrencyAmount+Result.RedemptoryStockAmount+Result.RedemptoryBondAmount) as RedemptoryAmount,
	(Result.PurchaseCurrencyCount+Result.PurchaseStockCount+Result.PurchaseBondCount+Result.RedemptoryCurrencyCount+Result.RedemptoryStockCount+Result.RedemptoryBondCount+Result.RetractCount+Result.DividendCount) as TotalCount,
	(Result.PurchaseCurrencyAmount+Result.PurchaseStockAmount+Result.PurchaseBondAmount+Result.RedemptoryCurrencyAmount+Result.RedemptoryStockAmount+Result.RedemptoryBondAmount+Result.RetractAmount+Result.DividendAmount) as TotalAmount,
	
	case when ISNULL(@PurchaseAmount,0) = 0
		then null
		else (Result.PurchaseCurrencyAmount+Result.PurchaseStockAmount+Result.PurchaseBondAmount)/@PurchaseAmount
		end PurchaseDutyRatio,
		
	case when ISNULL(@TotalAmount,0) = 0
		then null
		else (Result.PurchaseCurrencyAmount+Result.PurchaseStockAmount+Result.PurchaseBondAmount+Result.RedemptoryCurrencyAmount+Result.RedemptoryStockAmount+Result.RedemptoryBondAmount+Result.RetractAmount+Result.DividendAmount)/@TotalAmount
		end TotalDutyRatio
from
	#ResultTable Result
	left join
	Table_BankID BankID
	on
		Result.BankNo = BankID.BankNo
	left join
	Table_FundBankBranch FundBankBranch
	on
		Result.BankNo = FundBankBranch.BankNo
		and
		Result.BranchNo = FundBankBranch.BankBranchNo
	left join
	Table_MerInfo MerInfo
	on
		Result.MerchantNo = MerInfo.MerchantNo;
		
--8. Drop Table		
drop table #CurrTransWithCardNo;
drop table #CurrTransWithBankNo;
drop table #CurrResultTable2;
drop table #CurrResultTable3;
drop table #PrevTransWithCardNo;
drop table #PrevTransWithBankNo;
drop table #PrevResultTable2;
drop table #LastYearTransWithCardNo;
drop table #LastYearTransWithBankNo;
drop table #LastYearResultTable2;
drop table #ResultTable;

end