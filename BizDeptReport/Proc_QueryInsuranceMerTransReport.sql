if OBJECT_ID(N'Proc_QueryInsuranceMerTransReport', N'P') is not null
begin
	drop procedure Proc_QueryInsuranceMerTransReport;
end
go

create procedure Proc_QueryInsuranceMerTransReport
	@StartDate datetime = '2012-04-01',
	@EndDate datetime = '2012-04-30'
as
begin

--0. Check input
if (@StartDate is null or @EndDate is null)
begin
	raiserror(N'Input params cannot be empty in Proc_QueryInsuranceMerTransReport', 16, 1);
end

--1. Prepare date period
declare @CurrStartDate datetime;
declare @CurrEndDate datetime;
set @CurrStartDate = @StartDate;
set @CurrEndDate = DATEADD(DAY,1,@EndDate);

--2. Prepare payment and ora cost/fee/trans data
--2.1 Prepare payment data
create table #ProcPayCost
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
	#ProcPayCost
exec 
	Proc_CalPaymentCost @CurrStartDate,@CurrEndDate,NULL,NULL;

--2.2 Prepare ora data	
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
		MerchantNo,
		SUM(FeeAmount) FeeAmt
	from
		Table_OraTransSum
	where
		CPDate >= @CurrStartDate
		and
		CPDate <  @CurrEndDate
	group by
		MerchantNo
),
OraCost as
(
	select
		MerchantNo,
		SUM(TransCnt) TransCnt,
		SUM(TransAmt) TransAmt,
		SUM(CostAmt) CostAmt
	from
		#ProcOraCost
	group by
		MerchantNo
)
select
	OraCost.MerchantNo,
	OraCost.TransAmt,
	OraCost.TransCnt,
	OraCost.CostAmt,
	OraFee.FeeAmt,
	0 as InstuFeeAmt
into
	#OraAllData
from
	OraCost
	inner join
	OraFee
	on
		OraCost.MerchantNo = OraFee.MerchantNo;
		
update
	Ora
set
	Ora.FeeAmt = MerRate.FeeValue * Ora.TransCnt
from
	#OraAllData Ora
	inner join
	Table_OraAdditionalFeeRule MerRate
	on
		Ora.MerchantNo = MerRate.MerchantNo;
		
--3. Prepare Insurance Industry Merchant List
With AllMer as 
(
	select
		coalesce(PayMer.MerchantNo,OraMer.MerchantNo) MerchantNo,
		coalesce(PayMer.MerchantName,OraMer.MerchantName) MerchantName
	from
		Table_MerInfo PayMer
		full outer join
		Table_OraMerchants OraMer
		on
			PayMer.MerchantNo = OraMer.MerchantNo
),
InsuranceMer as 
(
	select
		MerchantNo
	from
		Table_MerInfo
	where
		MerchantName like N'%险%'
		or
		MerchantName like N'%保险%'
		or
		MerchantName like N'%人寿%'
	union
	select
		MerchantNo
	from
		Table_OraMerchants
	where
		MerchantName like N'%险%'
		or
		MerchantName like N'%保险%'
		or
		MerchantName like N'%人寿%'
	union
	select
		MerchantNo
	from
		Table_MerAttribute
	where
		IndustryName like N'%保险%'
	union
	select
		MerchantNo
	from
		Table_FinancialDeptConfiguration
	where
		IndustryName like N'%保险%' 
),
MerList as
(
	select
		InsuranceMer.MerchantNo,
		AllMer.MerchantName
	from
		InsuranceMer
		left join
		AllMer
		on
			InsuranceMer.MerchantNo = AllMer.MerchantNo
),

--4. Prepare All Biz Trans Data
PaymentTransData as
(
	select
		MerchantNo,
		GateNo,
		SUM(TransSumCount) TransCnt,
		SUM(TransSumAmount) TransAmt,
		SUM(Cost) CostAmt,
		SUM(FeeAmt) FeeAmt,
		SUM(InstuFeeAmt) InstuFeeAmt
	from
		#ProcPayCost
	group by
		MerchantNo,
		GateNo
),
--4.1 Prepare Deduction Trans Data 
DeductData as
(
	select
		Trans.MerchantNo,
		N'代收付' as TypeName,
		SUM(TransCnt) TransCnt,
		SUM(TransAmt) TransAmt,
		SUM(CostAmt) CostAmt,
		SUM(FeeAmt) FeeAmt,
		SUM(InstuFeeAmt) InstuFeeAmt
	from
		PaymentTransData Trans
		inner join
		MerList
		on
			Trans.MerchantNo = MerList.MerchantNo 
	where
		Trans.GateNo in (select GateNo from Table_GateCategory where GateCategory1 = N'代扣')
	group by
		Trans.MerchantNo
),

--4.2 Prepare Payment Trans Data
PayTransData as
(
	select
		Trans.MerchantNo,
		N'网上支付' as TypeName,
		SUM(TransCnt) TransCnt,
		SUM(TransAmt) TransAmt,
		SUM(CostAmt) CostAmt,
		SUM(FeeAmt) FeeAmt,
		SUM(InstuFeeAmt) InstuFeeAmt
	from
		PaymentTransData Trans
		inner join
		MerList
		on
			Trans.MerchantNo = MerList.MerchantNo 
	where
		Trans.GateNo not in (select GateNo from Table_GateCategory where GateCategory1 = N'代扣')
	group by
		Trans.MerchantNo
),

--4.3 Prepare Ora Trans Data
OraTransData as
(
	select
		Trans.MerchantNo,
		N'代收付' as TypeName,
		SUM(TransCnt) TransCnt,
		SUM(TransAmt) TransAmt,
		SUM(CostAmt) CostAmt,
		SUM(FeeAmt) FeeAmt,
		SUM(InstuFeeAmt) InstuFeeAmt
	from
		#OraAllData Trans
		inner join
		MerList
		on
			Trans.MerchantNo = MerList.MerchantNo 
	group by
		Trans.MerchantNo
),

--4.4 Join Trans Data
AllMerTrans as
(
	select * from PayTransData
	union all
	select * from DeductData
	union all
	select * from OraTransData
)
select
	AllMerTrans.MerchantNo,
	Mer.MerchantName,
	AllMerTrans.TypeName,
	SUM(AllMerTrans.TransAmt)/100.0 TransAmt,
	SUM(AllMerTrans.TransCnt) TransCnt,
	SUM(AllMerTrans.CostAmt)/100.0 CostAmt,
	SUM(AllMerTrans.FeeAmt)/100.0 FeeAmt,
	SUM(AllMerTrans.InstuFeeAmt)/100.0 InstuFeeAmt
from
	AllMerTrans
	inner join
	MerList Mer
	on
		AllMerTrans.MerchantNo = Mer.MerchantNo
group by 
	AllMerTrans.MerchantNo,
	Mer.MerchantName,
	AllMerTrans.TypeName
order by
	AllMerTrans.TypeName;

--5. Drop table 
Drop table #ProcPayCost;
Drop table #ProcOraCost;
Drop table #OraAllData;

End