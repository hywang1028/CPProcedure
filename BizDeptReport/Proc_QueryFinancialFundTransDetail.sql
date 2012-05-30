if OBJECT_ID(N'Proc_QueryFinancialFundTransDetail', N'P') is not null
begin
	drop procedure Proc_QueryFinancialFundTransDetail;
end
go

create procedure Proc_QueryFinancialFundTransDetail
	@StartDate datetime = '2012-01-01',
	@EndDate datetime = '2012-02-29'
as
begin

--1. Check input
if (@StartDate is null or @EndDate is null)
begin
	raiserror(N'Input params cannot be empty in Proc_QueryFinancialFundTransDetail', 16, 1);
end

--2. Prepare StartDate and EndDate
declare @CurrStartDate datetime;
declare @CurrEndDate datetime;
set @CurrStartDate = @StartDate;
set @CurrEndDate = DATEADD(day,1,@EndDate);
--set @CurrStartDate = '2012-01-01';
--set @CurrEndDate = '2012-03-01';
--3. Prepare Fund Data
With AllTransferData as
(
	select
		MerchantNo,
		TransType,
		Convert(decimal,ISNULL(SUM(TransAmt),0))/100 TransAmt,
		ISNULL(COUNT(TransAmt),0) TransCnt
	from
		Table_TrfTransLog
	where
		TransDate >= @CurrStartDate
		and
		TransDate <  @CurrEndDate
		and
		TransType in ('3010','3020','3030','3040','3050')
	group by
		MerchantNo,
		TransType
)
select
	AllTransferData.MerchantNo,
	Mer.MerchantName,
	ISNULL(SUM(case when TransType = '3010' then ISNULL(TransAmt,0) End),0) as PurchaseAmt,
	ISNULL(SUM(case when TransType = '3020' then ISNULL(TransAmt,0) End),0) as RevokeAmt,
	ISNULL(SUM(case when TransType = '3030' then ISNULL(TransAmt,0) End),0) as RedeemAmt,
	ISNULL(SUM(case when TransType = '3040' then ISNULL(TransAmt,0) End),0) as DividendAmt,
	ISNULL(SUM(case when TransType = '3050' then ISNULL(TransAmt,0) End),0) as InvestmentAmt
from
	AllTransferData
	left join
	Table_MerInfo Mer
	on
		AllTransferData.MerchantNo = Mer.MerchantNo
group by
	AllTransferData.MerchantNo,
	Mer.MerchantName;
	
End