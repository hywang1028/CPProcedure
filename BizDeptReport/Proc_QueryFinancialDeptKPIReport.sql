--[Created] At 20120528 By 王红燕:金融考核报表(境外数据已转为人民币数据)
--[Modified] At 20120627 By 王红燕：Add Finance Ora Trans Data
--[Modified] At 20120713 By 王红燕：Add All Bank Cost Calc Procs @HisRefDate Para Value
--[Modified] At 20130416 By 王红燕：Modify Biz Category and Cost Calc Format
--[Modified] At 20130929 By 王红燕：Add Table_TraScreenSum Trans Data
if OBJECT_ID(N'Proc_QueryFinancialDeptKPIReport', N'P') is not null
begin
	drop procedure Proc_QueryFinancialDeptKPIReport;
end
go

create procedure Proc_QueryFinancialDeptKPIReport
	@StartDate datetime = '2013-07-01',
	@EndDate datetime = '2013-09-30'
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
--declare @HisRefDate datetime;
--set @HisRefDate = DATEADD(DAY, -1, DATEADD(YEAR, DATEDIFF(YEAR, 0, @CurrStartDate), 0));

exec xprcFile '
OrderID	BizCategory
01	基金B2C
02	基金B2B
03	转账业务
04	信用卡还款业务
05	贵金属业务
06	理财平台业务
07	保险代收付
08	支付B2C
09	支付B2B
10	代付业务
11	pos业务
12	结算款代付
'
select
	*
into
	#BizOrder
from
	xlsContainer;
	
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
	Proc_CalPaymentCost @CurrStartDate,@CurrEndDate,NULL,'on';
	
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
	Proc_CalOraCost @CurrStartDate,@CurrEndDate,NULL;
	
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
	Ora.FeeAmt = (MerRate.FeeValue * (10000.0*Ora.TransCnt))/100.0
from
	#OraTransData Ora
	inner join
	Table_OraAdditionalFeeRule MerRate
	on
		Ora.MerchantNo = MerRate.MerchantNo;

--3.0.3 Get Table_TraScreenSum Trans Data
create table #CalTraCost
(	
	MerchantNo char(15),
	ChannelNo char(6),	
	TransType varchar(20),	
	CPDate date,
	TotalCnt int,	
	TotalAmt decimal(15,2),	
	SucceedCnt int,	
	SucceedAmt decimal(15,2),	
	CalFeeCnt int,	
	CalFeeAmt decimal(15,2),	
	CalCostCnt int,	
	CalCostAmt decimal(15,2),	
	FeeAmt decimal(15,2),
	CostAmt decimal(15,2)
)
insert into #CalTraCost
exec Proc_CalTraCost @CurrStartDate,@CurrEndDate;

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
TranswithGateNoData as
(	
	select
		Finance.BizCategory,
		Finance.MerchantNo,
		PaymentData.GateNo,
		Finance.BelongRate*ISNULL(PaymentData.TransAmt,0) TransAmt,
		Finance.BelongRate*ISNULL(PaymentData.TransCnt,0) TransCnt,
		Finance.BelongRate*ISNULL(PaymentData.FeeAmt,0) FeeAmt,
		Finance.BelongRate*ISNULL(PaymentData.CostAmt,0) CostAmt, 
		Finance.BelongRate*ISNULL(PaymentData.InstuFeeAmt,0) InstuFeeAmt
	from
		Table_BelongToFinance Finance
		inner join
		PaymentData
		on
			Finance.MerchantNo = PaymentData.MerchantNo
	where
		Finance.GateNo = 'all'
	union all
	select
		Finance.BizCategory,
		Finance.MerchantNo,
		PaymentData.GateNo,
		Finance.BelongRate*ISNULL(PaymentData.TransAmt,0) TransAmt,
		Finance.BelongRate*ISNULL(PaymentData.TransCnt,0) TransCnt,
		Finance.BelongRate*ISNULL(PaymentData.FeeAmt,0) FeeAmt,
		Finance.BelongRate*ISNULL(PaymentData.CostAmt,0) CostAmt, 
		Finance.BelongRate*ISNULL(PaymentData.InstuFeeAmt,0) InstuFeeAmt
	from
		Table_BelongToFinance Finance
		inner join
		PaymentData 
		on
			Finance.MerchantNo = PaymentData.MerchantNo
			and
			Finance.GateNo = PaymentData.GateNo
	where
		Finance.GateNo <> 'all'
),
DomesticTrans as
(
	select
		BizCategory,
		MerchantNo,
		GateNo,
		SUM(TransAmt) TransAmt,
		SUM(TransCnt) TransCnt,
		SUM(CostAmt) CostAmt,
		SUM(FeeAmt) FeeAmt,
		SUM(InstuFeeAmt) InstuFeeAmt
	from
		TranswithGateNoData
	where
		GateNo not in (select GateNo from Table_GateCategory where GateCategory1 in ('B2B',N'代扣','EPOS','UPOP'))
		and
		GateNo not in ('5901','5902')
		and
		MerchantNo not in (select distinct MerchantNo from Table_MerInfoExt)
	group by
		BizCategory,
		MerchantNo,
		GateNo
	union all
	select
		BizCategory,
		MerchantNo,
		GateNo,
		SUM(TransAmt) TransAmt,
		SUM(TransCnt) TransCnt,
		SUM(CostAmt) CostAmt,
		SUM(FeeAmt) FeeAmt,
		SUM(InstuFeeAmt) InstuFeeAmt
	from
		TranswithGateNoData
	where
		GateNo in (select GateNo from Table_GateCategory where GateCategory1 in ('EPOS')) 
		and
		MerchantNo in (select MerchantNo from Table_EposTakeoffMerchant)
		and
		MerchantNo not in (select distinct MerchantNo from Table_MerInfoExt)
	group by
		BizCategory,
		MerchantNo,
		GateNo
),
OtherPayTrans as
(
	select
		AllTrans.BizCategory,
		AllTrans.MerchantNo,
		AllTrans.GateNo,
		(AllTrans.TransAmt - ISNULL(DomeTrans.TransAmt, 0)) TransAmt,
		(AllTrans.TransCnt - ISNULL(DomeTrans.TransCnt, 0)) TransCnt,
		(AllTrans.CostAmt - ISNULL(DomeTrans.CostAmt, 0)) CostAmt,
		(AllTrans.FeeAmt - ISNULL(DomeTrans.FeeAmt, 0)) FeeAmt,
		(AllTrans.InstuFeeAmt - ISNULL(DomeTrans.InstuFeeAmt, 0)) InstuFeeAmt
	from
		(select
			BizCategory,
			MerchantNo,
			GateNo,
			SUM(TransAmt) TransAmt,
			SUM(TransCnt) TransCnt,
			SUM(CostAmt) CostAmt,
			SUM(FeeAmt) FeeAmt,
			SUM(InstuFeeAmt) InstuFeeAmt
		 from
			TranswithGateNoData
		 group by
			BizCategory,
			MerchantNo,
			GateNo
		)AllTrans
		left join
		(select
			BizCategory,
			MerchantNo,
			GateNo,
			SUM(TransAmt) TransAmt,
			SUM(TransCnt) TransCnt,
			SUM(CostAmt) CostAmt,
			SUM(FeeAmt) FeeAmt,
			SUM(InstuFeeAmt) InstuFeeAmt
		 from
			DomesticTrans
		 group by
			BizCategory,
			MerchantNo,
			GateNo
		)DomeTrans
		on
			AllTrans.BizCategory = DomeTrans.BizCategory
			and
			AllTrans.MerchantNo = DomeTrans.MerchantNo
			and
			AllTrans.GateNo = DomeTrans.GateNo
	where
		(AllTrans.TransAmt - ISNULL(DomeTrans.TransAmt, 0)) <> 0
		or
		(AllTrans.TransCnt - ISNULL(DomeTrans.TransCnt, 0)) <> 0
),
otherTransDetail as
(
	select
		OtherPayTrans.BizCategory,
		OtherPayTrans.MerchantNo,
		case when Gate.GateCategory1 = N'代扣' then N'代收付' 
			 when Gate.GateCategory1 = N'B2B' then N'B2B' 
			 Else N'其他' End as UpdateFlag,
		OtherPayTrans.TransAmt TransAmt,
		OtherPayTrans.TransCnt TransCnt,
		OtherPayTrans.CostAmt as CostAmt,
		OtherPayTrans.FeeAmt FeeAmt,
		OtherPayTrans.InstuFeeAmt InstuFeeAmt
	from
		OtherPayTrans
		left join
		Table_GateCategory Gate
		on
			OtherPayTrans.GateNo = Gate.GateNo
),
otherTransSum as
(
	select
		BizCategory,
		MerchantNo,
		UpdateFlag,
		(select MerchantName from Table_MerInfo where MerchantNo = otherTransDetail.MerchantNo) MerchantName,
		SUM(TransAmt) TransAmt,
		SUM(TransCnt) TransCnt,
		SUM(CostAmt) CostAmt,
		SUM(FeeAmt) FeeAmt,
		SUM(InstuFeeAmt) InstuFeeAmt
	from
		otherTransDetail
	group by
		BizCategory,
		MerchantNo,
		UpdateFlag
),
DomesticSum as
(
	select
		BizCategory,
		MerchantNo,
		'B2C网银(境内)' as UpdateFlag,
		(select MerchantName from Table_MerInfo where MerchantNo = DomesticTrans.MerchantNo) MerchantName,
		SUM(TransAmt) TransAmt,
		SUM(TransCnt) TransCnt,
		SUM(CostAmt) as CostAmt,
		SUM(FeeAmt) FeeAmt,
		SUM(InstuFeeAmt) InstuFeeAmt
	 from
		DomesticTrans
	 group by
		BizCategory,
		MerchantNo
),
FinanceOraTransData as
(
	select
		Finance.BizCategory,
		Finance.MerchantNo,
		'代收付' as UpdateFlag,
		(select MerchantName from Table_OraMerchants where MerchantNo = Finance.MerchantNo) as MerchantName,
		Finance.BelongRate*ISNULL(Ora.TransAmt,0) TransAmt,
		Finance.BelongRate*ISNULL(Ora.TransCnt,0) TransCnt,
		Finance.BelongRate*ISNULL(Ora.CostAmt,0) as CostAmt, 
		Finance.BelongRate*ISNULL(Ora.FeeAmt,0) FeeAmt,
		Finance.BelongRate*ISNULL(Ora.InstuFeeAmt,0) InstuFeeAmt
	from
		Table_BelongToFinance Finance
		inner join
		#OraTransData Ora
		on
			Finance.MerchantNo = Ora.MerchantNo
	where
		Finance.GateNo = 'all'
),
TraScreenSum as
(
	select
		Finance.BizCategory,
		Finance.MerchantNo,
		'代收付' as UpdateFlag,
		(select MerchantName from Table_TraMerchantInfo where MerchantNo = Finance.MerchantNo) as MerchantName,
		Finance.BelongRate*ISNULL(Ora.SucceedAmt,0)/10000000000.0 TransAmt,
		Finance.BelongRate*ISNULL(Ora.SucceedCnt,0)/10000.0 TransCnt,
		Finance.BelongRate*ISNULL(Ora.CostAmt,0)/100.0 as CostAmt, 
		Finance.BelongRate*ISNULL(Ora.FeeAmt,0)/100.0 FeeAmt,
		0 as InstuFeeAmt
	from
		Table_BelongToFinance Finance
		inner join
		#CalTraCost Ora
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
		N'其他' as UpdateFlag,
		NULL as MerchantName,
		SUM(case when TransType = '3020' then -1*TransAmt else TransAmt End) as TransAmt,
		SUM(case when TransType = '3020' then -1*TransCnt else TransCnt End) as TransCnt,
		NULL as CostAmt,
		NULL as FeeAmt,
		NULL as InstuFeeAmt
	from
		AllTransferData
	where
		TransType in ('3010','3020','3030','3040')
),
----3.2 Prepare Transfer Data
TransferData as 
(
	select
		N'转账业务' as BizCategory,
		NULL as MerchantNo,
		N'其他' as UpdateFlag,
		NULL as MerchantName,
		SUM(TransAmt) TransAmt,
		SUM(TransCnt) TransCnt,
		0 as CostAmt,
		0.3*SUM(ISNULL(FeeAmt,0)) FeeAmt,
		0 as InstuFeeAmt
	from
		AllTransferData
	where
		TransType = '2070'
),	
----3.3 Prepare CreditCardPayment Data
CreditCardData as
(
	select
		N'信用卡还款业务' as BizCategory,
		NULL as MerchantNo,
		N'其他' as UpdateFlag,
		NULL as MerchantName,
		ISNULL(SUM(RepaymentAmount),0)/100000000 TransAmt,
		Convert(decimal,ISNULL(SUM(RepaymentCount),0))/10000 TransCnt,
		0 as CostAmt,
		0.2*ISNULL(SUM(RepaymentCount),0) FeeAmt,
		0 as InstuFeeAmt
	from
		Table_CreditCardPayment
	where
		RepaymentDate >= @CurrStartDate
		and
		RepaymentDate <  @CurrEndDate
)

--4.Join All Data
select * into #TempResult from B2CTransData
union all
select * from TransferData
union all
select * from CreditCardData
union all
select * from otherTransSum
union all
select * from DomesticSum
union all
select * from FinanceOraTransData
union all
select * from TraScreenSum;

Update 
	#TempResult
Set
	CostAmt = (100000000.0 * TransAmt) * 0.0025
where	
	UpdateFlag = N'B2C网银(境内)';
	
Update 
	#TempResult
Set
	CostAmt = (10000.0 * TransCnt) * 5.0
where	
	UpdateFlag = N'B2B';
	
Update 
	#TempResult
Set
	CostAmt = (10000.0 * TransCnt) * 0.7
where	
	UpdateFlag = N'代收付';

select
	BizOrder.OrderID,
	BizOrder.BizCategory,
	TempResult.MerchantNo,
	MerInfo.MerchantName,
	SUM(TempResult.TransAmt) TransAmt,
	SUM(TempResult.TransCnt) TransCnt,
	SUM(TempResult.FeeAmt) FeeAmt,
	SUM(TempResult.CostAmt) CostAmt,
	SUM(TempResult.InstuFeeAmt) InstuFeeAmt
from
	#BizOrder BizOrder
	left join
	#TempResult TempResult
	on
		BizOrder.BizCategory = TempResult.BizCategory
	left join
	(
		select
			MerchantNo,
			MIN(MerchantName) MerchantName
		from
			#TempResult
		group by
			MerchantNo
	)MerInfo
	on
		TempResult.MerchantNo = MerInfo.MerchantNo
group by
	BizOrder.OrderID,
	BizOrder.BizCategory,
	TempResult.MerchantNo,
	MerInfo.MerchantName;
	
--5.Drop Temp Table
Drop table #BizOrder;
Drop table #ProcResult;
Drop table #ProcOraCost;
Drop table #OraTransData;
Drop table #CalTraCost;
Drop table #TempResult;

End