--[Created] At 20120528 By 王红燕:金融考核报表(境外数据已转为人民币数据)
if OBJECT_ID(N'Proc_QueryFinancialDeptKPIReport', N'P') is not null
begin
	drop procedure Proc_QueryFinancialDeptKPIReport;
end
go

create procedure Proc_QueryFinancialDeptKPIReport
	@StartDate datetime = '2012-01-01',
	@EndDate datetime = '2012-02-29'
as
begin

--1. Check input
if (@StartDate is null or @EndDate is null)
begin
	raiserror(N'Input params cannot be empty in Proc_QueryFinancialDeptKPIReport', 16, 1);
end

--2. Prepare StartDate and EndDate
declare @CurrStartDate datetime;
declare @CurrEndDate datetime;
set @CurrStartDate = @StartDate;
set @CurrEndDate = DATEADD(day,1,@EndDate);

--3. Prepare Trans Data
--3.1 Prepare Other Biz Data
--3.1.1 Prepare Payment Cost and Income Data
create table #ProcResult
(
	GateNo char(4) not null,
	MerchantNo char(20) not null,
	FeeEndDate datetime not null,
	TransSumCount bigint not null,
	TransSumAmount bigint not null,
	Cost decimal(15,4) not null,
	FeeAmt decimal(15,2) not null,
	InstuFeeAmt decimal(15,2) not null
);
insert into 
	#ProcResult
exec 
	Proc_CalPaymentCost @CurrStartDate,@CurrEndDate,NULL,'on';

With PaymentData as
(
	select 
		MerchantNo,
		GateNo,
		Convert(decimal,SUM(TransSumAmount))/10000000000 TransAmt,
		Convert(decimal,SUM(TransSumCount))/10000 TransCnt,
		Convert(decimal,SUM(Cost))/100 CostAmt,
		Convert(decimal,SUM(FeeAmt))/100 FeeAmt,
		Convert(decimal,SUM(InstuFeeAmt))/100 InstuFeeAmt
	from 
		#ProcResult
	where
		MerchantNo in (select distinct MerchantNo from Table_BelongToFinance)
	group by
		MerchantNo,
		GateNo
),
notwithGateNoData as
(	
	select
		Finance.BizCategory,
		Finance.MerchantNo,
		(select MerchantName from Table_MerInfo where MerchantNo = Finance.MerchantNo) as MerchantName,
		Finance.BelongRate*ISNULL(PaymentData.TransAmt,0) TransAmt,
		Finance.BelongRate*ISNULL(PaymentData.TransCnt,0) TransCnt,
		Finance.BelongRate*ISNULL(PaymentData.FeeAmt,0) FeeAmt,
		Finance.BelongRate*ISNULL(PaymentData.CostAmt,0) CostAmt, 
		Finance.BelongRate*ISNULL(PaymentData.InstuFeeAmt,0) InstuFeeAmt
	from
		Table_BelongToFinance Finance
		left join
		(select
			MerchantNo,
			SUM(TransAmt) TransAmt,
			SUM(TransCnt) TransCnt,
			SUM(FeeAmt) FeeAmt,
			SUM(CostAmt) CostAmt,
			SUM(InstuFeeAmt) InstuFeeAmt
		 from
			PaymentData 
		 group by
			MerchantNo
		)PaymentData
		on
			Finance.MerchantNo = PaymentData.MerchantNo
	where
		Finance.GateNo = 'all'
),
withGateNoData as
(
	select
		Finance.BizCategory,
		Finance.MerchantNo,
		(select MerchantName from Table_MerInfo where MerchantNo = Finance.MerchantNo) as MerchantName,
		SUM(Finance.BelongRate*ISNULL(PaymentData.TransAmt,0)) TransAmt,
		SUM(Finance.BelongRate*ISNULL(PaymentData.TransCnt,0)) TransCnt,
		SUM(Finance.BelongRate*ISNULL(PaymentData.FeeAmt,0)) FeeAmt,
		SUM(Finance.BelongRate*ISNULL(PaymentData.CostAmt,0)) CostAmt, 
		SUM(Finance.BelongRate*ISNULL(PaymentData.InstuFeeAmt,0)) InstuFeeAmt
	from
		Table_BelongToFinance Finance
		left join
		PaymentData 
		on
			Finance.MerchantNo = PaymentData.MerchantNo
			and
			Finance.GateNo = PaymentData.GateNo
	where
		Finance.GateNo <> 'all'	
	group by
		Finance.BizCategory,
		Finance.MerchantNo
),
--3.1 Prepare Fund Data
AllTransferData as
(
	select
		TransType,
		Convert(decimal,ISNULL(SUM(TransAmt),0))/10000000000 TransAmt,
		Convert(decimal,ISNULL(COUNT(TransAmt),0))/10000 TransCnt,
		Convert(decimal,ISNULL(SUM(FeeAmt),0))/100 FeeAmt
	from
		Table_TrfTransLog
	where
		TransDate >= @CurrStartDate
		and
		TransDate <  @CurrEndDate
	group by
		TransType
),
B2CTransData as
(
	select
		N'基金B2C' as BizCategory,
		NULL as MerchantNo,
		NULL as MerchantName,
		SUM(case when TransType = '3020' then -1*TransAmt else TransAmt End) as TransAmt,
		SUM(case when TransType = '3020' then -1*TransCnt else TransCnt End) as TransCnt,
		NULL as FeeAmt,
		NULL as CostAmt,
		NULL as InstuFeeAmt
	from
		AllTransferData
	where
		TransType in ('3010','3020','3030','3040')
),
--3.2 Prepare Transfer Data
TransferData as 
(
	select
		N'转账业务' as BizCategory,
		NULL as MerchantNo,
		NULL as MerchantName,
		SUM(TransAmt) TransAmt,
		SUM(TransCnt) TransCnt,
		0.3*SUM(ISNULL(FeeAmt,0)) FeeAmt,
		0 as CostAmt,
		0 as InstuFeeAmt
	from
		AllTransferData
	where
		TransType = '2070'
),	
--3.3 Prepare CreditCardPayment Data
CreditCardData as
(
	select
		N'信用卡还款业务' as BizCategory,
		NULL as MerchantNo,
		NULL as MerchantName,
		ISNULL(SUM(RepaymentAmount),0)/100000000 TransAmt,
		Convert(decimal,ISNULL(SUM(RepaymentCount),0))/10000 TransCnt,
		0.2*ISNULL(SUM(RepaymentCount),0) FeeAmt,
		0 as CostAmt,
		0 as InstuFeeAmt
	from
		Table_CreditCardPayment
	where
		RepaymentDate >= @CurrStartDate
		and
		RepaymentDate <  @CurrEndDate
)
--4.Join All Data
select * from B2CTransData
union all
select
	N'基金B2B' as BizCategory,
	NULL as MerchantNo,
	NULL as MerchantName,
	NULL as TransAmt,
	NULL as TransCnt,
	NULL as FeeAmt,
	NULL as CostAmt,
	NULL as InstuFeeAmt
union all
select * from TransferData
union all
select * from CreditCardData
union all
select
	N'终端接入' as BizCategory,
	NULL as MerchantNo,
	NULL as MerchantName,
	NULL as TransAmt,
	NULL as TransCnt,
	NULL as FeeAmt,
	NULL as CostAmt,
	NULL as InstuFeeAmt
union all
select * from notwithGateNoData
union all
select * from withGateNoData;
	
--5.Drop Temp Table
Drop table #ProcResult;

End