--[Created] At 20120528 By 王红燕:金融考核报表(境外数据已转为人民币数据)
--[Modified] At 20120627 By 王红燕：Add Finance Ora Trans Data
--[Modified] At 20120713 By 王红燕：Add All Bank Cost Calc Procs @HisRefDate Para Value
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
declare @HisRefDate datetime;
set @HisRefDate = DATEADD(DAY, -1, DATEADD(YEAR, DATEDIFF(YEAR, 0, @CurrStartDate), 0));

--3. Prepare Trans Data
--3.0 Prepare Other Biz Data
--3.0.1 Prepare Payment Cost and Income Data
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
	Proc_CalPaymentCost @CurrStartDate,@CurrEndDate,@HisRefDate,'on';
	
--3.0.2 Get Ora Trans Data
create table #ProcOraCost
(
	BankSettingID char(10) not null,
	MerchantNo char(20) not null,
	CPDate datetime not null,
	TransCnt bigint not null,
	TransAmt bigint not null,
	CostAmt decimal(15,4) not null
);
insert into 
	#ProcOraCost
exec 
	Proc_CalOraCost @CurrStartDate,@CurrEndDate,@HisRefDate;
	
With OraFee as
(
	select
		Ora.MerchantNo,
		SUM(Ora.FeeAmount)/100.0 FeeAmt
	from
		Table_OraTransSum Ora		
	where
		Ora.CPDate >= @CurrStartDate
		and
		Ora.CPDate <  @CurrEndDate
		and
		Ora.MerchantNo in (select distinct MerchantNo from Table_BelongToFinance)
	group by
		Ora.MerchantNo
),
OraCost as
(
	select
		Ora.MerchantNo,
		SUM(Ora.TransCnt)/10000.0 TransCnt,
		SUM(Ora.TransAmt)/10000000000.0 TransAmt,
		SUM(Ora.CostAmt)/100.0 CostAmt
	from
		#ProcOraCost Ora
	where
		Ora.MerchantNo in(select distinct MerchantNo from Table_BelongToFinance)
	group by
		Ora.MerchantNo
)
select
	OraCost.MerchantNo,
	OraCost.TransCnt,
	OraCost.TransAmt,
	OraFee.FeeAmt,
	OraCost.CostAmt,
	0 as InstuFeeAmt
into
	#OraTransData
from
	OraCost
	inner join
	OraFee
	on
		OraCost.MerchantNo = OraFee.MerchantNo;
		
update
	Ora
set
	Ora.FeeAmt = (MerRate.FeeValue * Ora.TransCnt)/100.0
from
	#OraTransData Ora
	inner join
	Table_OraAdditionalFeeRule MerRate
	on
		Ora.MerchantNo = MerRate.MerchantNo;

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
FinanceOraTransData as
(
	select
		Finance.BizCategory,
		Finance.MerchantNo,
		(select MerchantName from Table_OraMerchants where MerchantNo = Finance.MerchantNo) as MerchantName,
		Finance.BelongRate*ISNULL(Ora.TransAmt,0) TransAmt,
		Finance.BelongRate*ISNULL(Ora.TransCnt,0) TransCnt,
		Finance.BelongRate*ISNULL(Ora.FeeAmt,0) FeeAmt,
		Finance.BelongRate*ISNULL(Ora.CostAmt,0) CostAmt, 
		Finance.BelongRate*ISNULL(Ora.InstuFeeAmt,0) InstuFeeAmt
	from
		Table_BelongToFinance Finance
		left join
		#OraTransData Ora
		on
			Finance.MerchantNo = Ora.MerchantNo
	where
		Finance.GateNo = 'all'
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
select * from withGateNoData
union all
select * from FinanceOraTransData;
	
--5.Drop Temp Table
Drop table #ProcResult;
Drop table #ProcOraCost;
Drop table #OraTransData;
End