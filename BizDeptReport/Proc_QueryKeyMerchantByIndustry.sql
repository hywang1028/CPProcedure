if OBJECT_ID(N'Proc_QueryKeyMerchantByIndustry', N'P') is not null
begin
	drop procedure Proc_QueryKeyMerchantByIndustry;
end
go

create procedure Proc_QueryKeyMerchantByIndustry
	@StartDate as datetime = '2011-01-01',
	@EndDate as datetime = '2011-02-01',
	@ReportCategory as nvarchar(4) = N'汇总'
as
begin

--1. Check input
if @StartDate is null or @EndDate is null
begin
	raiserror(N'Input params cannot be empty in Proc_QueryKeyMerchantByIndustry', 16, 1);
end;

--2. Get DailyTrans during the period
select
	Trans.MerchantNo,
	ISNULL(Gate.BankName, N'其它') as BankName,
	convert(decimal, SUM(Trans.SucceedTransAmount))/1000000 as SucceedAmount
into
	#PeriodSumAmount
from
	FactDailyTrans Trans
	left join
	DimGate Gate
	on
		Trans.GateNo = Gate.GateNo
where
	Trans.DailyTransDate >= @StartDate
	and
	Trans.DailyTransDate < DATEADD(day,1,@EndDate)
group by
	Trans.MerchantNo,
	ISNULL(Gate.BankName, N'其它');

--3. Get Result
if (@ReportCategory = N'明细')
begin
	select
		Merchant.IndustryName,
		Merchant.MerchantName,
		Merchant.MerchantNo,
		PeriodSumAmount.BankName,
		ISNULL(PeriodSumAmount.SucceedAmount,0) as SucceedAmount
	from
		Table_KeyMerByIndustryForBizDept Merchant
		left join
		#PeriodSumAmount PeriodSumAmount
		on
			Merchant.MerchantNo = PeriodSumAmount.MerchantNo;
end
else if (@ReportCategory = N'汇总')
begin
	select
		Merchant.IndustryName,
		Merchant.MerchantName,
		'0' as MerchantNo,
		PeriodSumAmount.BankName,
		ISNULL(SUM(PeriodSumAmount.SucceedAmount),0) as SucceedAmount
	from
		Table_KeyMerByIndustryForBizDept Merchant
		left join
		#PeriodSumAmount PeriodSumAmount
		on
			Merchant.MerchantNo = PeriodSumAmount.MerchantNo
	group by
		Merchant.IndustryName,
		Merchant.MerchantName,
		PeriodSumAmount.BankName;
end
		
--4. Clear temp table
drop table #PeriodSumAmount;

end