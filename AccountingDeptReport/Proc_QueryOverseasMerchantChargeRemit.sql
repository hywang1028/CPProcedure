--[Created] At 20120515 By 丁俊昊：境外商户手续费汇总表
--Input:@StartDate,@Currency,@EndDate;
--Output:CuryCode,MerchantNo,MerchantName,TransAmt,TransAmtForeign,FeeAmt,FeeAmtForeign,SettlementAmt,SettlementAmtForeign
if OBJECT_ID(N'Proc_QueryOverseasMerchantChargeRemit',N'P') is not null
begin
	drop Procedure Proc_QueryOverseasMerchantChargeRemit
end
go


Create Procedure Proc_QueryOverseasMerchantChargeRemit
	@StartDate datetime = '2012-05-01',
	@Currency nchar(4) = N'全部',
	@EndDate datetime = '2012-05-31'
as
begin


--1.check input
if(@StartDate is null or ISNULL(@Currency,N'') = N'' or (@Currency = N'全部' and @EndDate is null))
begin
	raiserror(N'Input params cannot be empty in Proc_QueryOverseasMerchantChargeRemit',16,1)
end


--2.Prepare
declare @CurrEndDate datetime;
set @CurrEndDate = DATEADD(DAY,1,@EndDate)

--3.查询
if (@Currency = N'全部')
select
	BuyCuryLog.CuryCode,
	BuyCuryLog.MerchantNo,
	MerInfo.MerchantName,
	SUM(BuyCuryLog.TransAmt)/100.0 TransAmt,
	SUM(BuyCuryLog.TransAmtForeign)/100.0 TransAmtForeign,
	SUM(BuyCuryLog.FeeAmt)/100.0 FeeAmt,
	SUM(BuyCuryLog.FeeAmtForeign)/100.0 FeeAmtForeign,
	SUM(BuyCuryLog.TransAmt)/100.0 - SUM(BuyCuryLog.FeeAmt)/100.0 SettlementAmt,
	SUM(BuyCuryLog.TransAmtForeign)/100.0 - SUM(BuyCuryLog.FeeAmtForeign)/100.0 SettlementAmtForeign
from
	Table_BuyCuryLog BuyCuryLog
	left join
	Table_MerInfo MerInfo
	on
		BuyCuryLog.MerchantNo = MerInfo.MerchantNo
where
	BuyCuryLog.BuyDate >= @StartDate
	and
	BuyCuryLog.BuyDate < @CurrEndDate
group by
	BuyCuryLog.CuryCode,
	MerInfo.MerchantName,
	BuyCuryLog.MerchantNo
else
select 
	BuyCuryLog.CuryCode,
	BuyCuryLog.MerchantNo,
	MerInfo.MerchantName,
	SUM(BuyCuryLog.TransAmt)/100.0 TransAmt,
	SUM(BuyCuryLog.TransAmtForeign)/100.0 TransAmtForeign,
	SUM(BuyCuryLog.FeeAmt)/100.0 FeeAmt,
	SUM(BuyCuryLog.FeeAmtForeign)/100.0 FeeAmtForeign,
	SUM(BuyCuryLog.TransAmt)/100.0 - SUM(BuyCuryLog.FeeAmt)/100.0 SettlementAmt,
	SUM(BuyCuryLog.TransAmtForeign)/100.0 - SUM(BuyCuryLog.FeeAmtForeign)/100.0 SettlementAmtForeign
from
	Table_BuyCuryLog BuyCuryLog
	left join
	Table_MerInfo MerInfo
	on
		BuyCuryLog.MerchantNo = MerInfo.MerchantNo
where
	BuyCuryLog.CuryCode = @Currency
	and
	BuyCuryLog.BuyDate >= @StartDate
	and
	BuyCuryLog.BuyDate < @CurrEndDate
group by
	BuyCuryLog.CuryCode,
	MerInfo.MerchantName,
	BuyCuryLog.MerchantNo
end