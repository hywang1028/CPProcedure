--[Created] At 20120619 By 王红燕：CP内部业务费用配置报表(境外数据已转为人民币数据)
--[Modified] At 20120627 By 王红燕：Add Finance Ora Trans Data
--[Modified] At 20120713 By 王红燕：Add All Bank Cost Calc Procs @HisRefDate Para Value
--[Modified] At 20130422 By 王红燕：Modify Cost Calc Format
if OBJECT_ID(N'Proc_QueryCorpInnerExpendAllocReport', N'P') is not null
begin
	drop procedure Proc_QueryCorpInnerExpendAllocReport;
end
go

create procedure Proc_QueryCorpInnerExpendAllocReport
	@StartDate datetime = '2013-01-01',
	@EndDate datetime = '2013-03-31'
as
begin

--0. Check input
if (@StartDate is null or @EndDate is null)
begin
	raiserror(N'Input params cannot be empty in Proc_QueryCorpInnerExpendAllocReport', 16, 1);
end

--0.1 Prepare StartDate and EndDate
declare @CurrStartDate datetime;
declare @CurrEndDate datetime;
set @CurrStartDate = @StartDate;
set @CurrEndDate = DATEADD(day,1,@EndDate);
--declare @HisRefDate datetime;
--set @HisRefDate = DATEADD(DAY, -1, DATEADD(YEAR, DATEDIFF(YEAR, 0, @CurrStartDate), 0));

--1. Get Branch Office Merchant List
select
	Instu.BranchOfficeName InstuName,
	Mer.MerchantNo
into
	#BranchMer
from
	Table_ExpenAllocInstu Instu
	inner join
	Table_ExpenAllocInstuMer Mer
	on
		Instu.InstuNo = Mer.InstuNo;

--2. Get All Biz Trans Data
--2.1 Get Ora Trans Data (Take Off Branch Office Merchant)
--create table #ProcOraCost
--(
--	BankSettingID char(10) not null,
--	MerchantNo char(20) not null,
--	CPDate datetime not null,
--	TransCnt bigint not null,
--	TransAmt bigint not null,
--	CostAmt decimal(15,4) not null
--);
--insert into 
--	#ProcOraCost
--exec 
--	Proc_CalOraCost @CurrStartDate,@CurrEndDate,NULL;

select
	Ora.MerchantNo,
	SUM(Ora.TransAmount)/100.0 TransAmt,
	SUM(Ora.TransCount) TransCnt,
	0.7*SUM(Ora.TransCount) CostAmt,
	SUM(Ora.FeeAmount)/100.0 FeeAmt,
	0 as InstuFeeAmt
into
	#OraTransData
from
	Table_OraTransSum Ora	
where
	Ora.CPDate >= @CurrStartDate
	and
	Ora.CPDate <  @CurrEndDate
	and
	MerchantNo not in(select MerchantNo from #BranchMer)
group by
	Ora.MerchantNo
		
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
		
--2.2 Get Payment Trans Data (Take Off Branch Office Merchant)
create table #PayProcData
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
	#PayProcData
exec 
	Proc_CalPaymentCost @CurrStartDate,@CurrEndDate,NULL,'on';
	
select 
	MerchantNo,
	GateNo,
	SUM(TransSumCount) TransCnt,
	SUM(TransSumAmount)/100.0 TransAmt,
	SUM(FeeAmt)/100.0 FeeAmt,
	SUM(Cost)/100.0 CostAmt,
	SUM(InstuFeeAmt)/100.0 InstuFeeAmt
into
	#PayTransData
from
	#PayProcData
where
	MerchantNo not in(select MerchantNo from #BranchMer)
group by
	MerchantNo,
	GateNo;

--2.3 Get Finance Dept Trans Data
select
	Finance.BizCategory,
	PaymentData.MerchantNo,
	PaymentData.GateNo,
	Finance.BelongRate*ISNULL(PaymentData.TransAmt,0) TransAmt,
	Finance.BelongRate*ISNULL(PaymentData.TransCnt,0) TransCnt,
	Finance.BelongRate*ISNULL(PaymentData.FeeAmt,0) FeeAmt,
	Finance.BelongRate*ISNULL(PaymentData.CostAmt,0) CostAmt, 
	Finance.BelongRate*ISNULL(PaymentData.InstuFeeAmt,0) InstuFeeAmt
into
	#FinanceBizData
from
	Table_BelongToFinance Finance
	inner join
	#PayTransData PaymentData
	on
		Finance.MerchantNo = PaymentData.MerchantNo
where
	Finance.GateNo = 'all'
union all
select
	Finance.BizCategory,
	PaymentData.MerchantNo,
	PaymentData.GateNo,
	Finance.BelongRate*ISNULL(PaymentData.TransAmt,0) TransAmt,
	Finance.BelongRate*ISNULL(PaymentData.TransCnt,0) TransCnt,
	Finance.BelongRate*ISNULL(PaymentData.FeeAmt,0) FeeAmt,
	Finance.BelongRate*ISNULL(PaymentData.CostAmt,0) CostAmt, 
	Finance.BelongRate*ISNULL(PaymentData.InstuFeeAmt,0) InstuFeeAmt
from
	Table_BelongToFinance Finance
	inner join
	#PayTransData PaymentData
	on
		Finance.MerchantNo = PaymentData.MerchantNo
		and
		Finance.GateNo = PaymentData.GateNo
where
	Finance.GateNo <> 'all';

select
	Finance.BizCategory,
	OraTransData.MerchantNo,
	Finance.BelongRate*ISNULL(OraTransData.TransAmt,0) TransAmt,
	Finance.BelongRate*ISNULL(OraTransData.TransCnt,0) TransCnt,
	Finance.BelongRate*ISNULL(OraTransData.FeeAmt,0) FeeAmt,
	Finance.BelongRate*ISNULL(OraTransData.CostAmt,0) CostAmt, 
	Finance.BelongRate*ISNULL(OraTransData.InstuFeeAmt,0) InstuFeeAmt
into
	#FinanceOraData
from
	Table_BelongToFinance Finance
	inner join
	#OraTransData OraTransData
	on
		Finance.MerchantNo = OraTransData.MerchantNo
where
	Finance.GateNo = 'all';
	
--3. Get All Dept Biz List
Create Table #BizCategory 
(
	BizID int not null primary key,
	BizDept nchar(10) not null,
	BizCategory nchar(20) not null
);
insert into #BizCategory Values
(1,'销售部','B2C交易'),
(2,'销售部','B2B交易'),
(3,'销售部','代扣交易'),
(4,'销售部','代付交易'),
(5,'销售部','西联汇款'),
(6,'销售部','易商旅'),
(7,'销售部','御航宝'),
(8,'销售部','信用支付'),
(9,'金融部','个人基金(B2C)'),
(10,'金融部','公司基金(B2B)'),
(11,'金融部','转账业务'),
(12,'金融部','信用卡还款业务'),
(13,'金融部','终端接入'),
(201,'CP','其中：信用支付'),
(202,'CP','铁道部'),
(203,'CP','支付基金'),
(204,'CP','基金(自有资金)'),
(205,'CP','支付转代付(自有资金)');

insert into #BizCategory
select 
	20+ROW_NUMBER() Over(order by Finance.BizCategory),
	N'金融部',
	BizCategory
from
	(select distinct 
		BizCategory	
	from
		Table_BelongToFinance
	)Finance;	
	
--4. Get Sales Dept Trans Data
--4.l Get Left Payment Trans Data
With PayTransData as
(
	select
		Pay.MerchantNo,
		Pay.GateNo,
		(Pay.TransCnt - ISNULL(Finance.TransCnt,0)) TransCnt,
		(Pay.TransAmt - ISNULL(Finance.TransAmt,0)) TransAmt,
		(Pay.FeeAmt - ISNULL(Finance.FeeAmt,0)) FeeAmt,
		(Pay.CostAmt - ISNULL(Finance.CostAmt,0)) CostAmt,
		(Pay.InstuFeeAmt - ISNULL(Finance.InstuFeeAmt,0)) InstuFeeAmt
	from
		#PayTransData Pay
		left join
		#FinanceBizData Finance
		on
			Pay.MerchantNo = Finance.MerchantNo
			and
			Pay.GateNo = Finance.GateNo
	where
		(Pay.TransCnt - ISNULL(Finance.TransCnt,0)) <> 0
		or
		(Pay.TransAmt - ISNULL(Finance.TransAmt,0)) <> 0
		or
		(Pay.FeeAmt - ISNULL(Finance.FeeAmt,0)) <> 0
),
B2BTrans as
(
	select
		N'B2B' as BizCategory,
		MerchantNo,
		GateNo,
		TransAmt,
		TransCnt,
		5.0*TransCnt as CostAmt,
		FeeAmt,
		InstuFeeAmt
	from
		PayTransData
	where
		GateNo in (select GateNo from Table_GateCategory where GateCategory1 = 'B2B')
),	
--2.4 Get Deduct GateNo Trans Data
DeductTrans as
(
	select
		N'代扣' as BizCategory,
		MerchantNo,
		GateNo,
		TransAmt,
		TransCnt,
		0.7*TransCnt as CostAmt,
		FeeAmt,
		InstuFeeAmt
	from
		PayTransData
	where
		GateNo in (select GateNo from Table_GateCategory where GateCategory1 = N'代扣')
),	
--2.5 Get Other GateNo (B2C) Trans Data
B2CTrans as
(
	select
		MerchantNo,
		GateNo,
		TransCnt,
		TransAmt,
		FeeAmt,
		InstuFeeAmt,
		CostAmt
	from
		PayTransData
	where
		GateNo not in (select GateNo from Table_GateCategory where GateCategory1 in ('B2B',N'代扣'))
),
DomesticTrans as
(
	select
		N'B2C网银(境内)' as BizCategory,
		MerchantNo,
		GateNo,
		TransAmt,
		TransCnt,
		CostAmt,
		FeeAmt,
		InstuFeeAmt
	from
		B2CTrans
	where
		GateNo not in (select GateNo from Table_GateCategory where GateCategory1 in ('EPOS','UPOP'))
		and
		GateNo not in ('5901','5902')
		and
		MerchantNo not in (select distinct MerchantNo from Table_MerInfoExt)
	union all
	select
		N'B2C网银(境内)' as BizCategory,
		MerchantNo,
		GateNo,
		TransAmt,
		TransCnt,
		CostAmt,
		FeeAmt,
		InstuFeeAmt
	from
		B2CTrans
	where
		GateNo in (select GateNo from Table_GateCategory where GateCategory1 in ('EPOS')) 
		and
		MerchantNo in (select MerchantNo from Table_EposTakeoffMerchant)
		and
		MerchantNo not in (select distinct MerchantNo from Table_MerInfoExt)
),
OtherB2CTrans as
(
	select
		N'B2C交易' as BizCategory,
		AllTrans.MerchantNo,
		AllTrans.GateNo,
		(AllTrans.TransAmt - ISNULL(DomeTrans.TransAmt, 0)) TransAmt,
		(AllTrans.TransCnt - ISNULL(DomeTrans.TransCnt, 0)) TransCnt,
		(AllTrans.CostAmt - ISNULL(DomeTrans.CostAmt, 0)) CostAmt,
		(AllTrans.FeeAmt - ISNULL(DomeTrans.FeeAmt, 0)) FeeAmt,
		(AllTrans.InstuFeeAmt - ISNULL(DomeTrans.InstuFeeAmt, 0)) InstuFeeAmt
	from
		B2CTrans AllTrans
		left join
		(select
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
			MerchantNo,
			GateNo
		)DomeTrans
		on
			AllTrans.MerchantNo = DomeTrans.MerchantNo
			and
			AllTrans.GateNo = DomeTrans.GateNo
)
select * into #SalesPayTrans from B2BTrans
union all
select * from DeductTrans
union all
select * from DomesticTrans
union all
select * from OtherB2CTrans;

Update 
	#SalesPayTrans
Set
	CostAmt = TransAmt * 0.0025
where	
	BizCategory = N'B2C网银(境内)';

With PayTransData as
(
	select
		MerchantNo,
		GateNo,
		SUM(TransAmt) TransAmt,
		SUM(TransCnt) TransCnt,
		SUM(CostAmt) CostAmt,
		SUM(FeeAmt) FeeAmt,
		SUM(InstuFeeAmt) InstuFeeAmt
	from
		#SalesPayTrans
	group by
		MerchantNo,
		GateNo
),
--4.2 Get '易商旅' Trans Data
BizTripTrans as
(
	select 
		6 as BizID,
		MerchantNo,
		(select MerchantName from Table_MerInfo where MerchantNo = PayTransData.MerchantNo) MerchantName,
		SUM(TransCnt) TransCnt,
		SUM(TransAmt) TransAmt,
		SUM(FeeAmt) FeeAmt,
		SUM(CostAmt) CostAmt,
		SUM(InstuFeeAmt) InstuFeeAmt
	from
		PayTransData
	where
		MerchantNo = '808080510003188'
	group by
		MerchantNo
),

--4.3 Get '御航宝' Trans Data
YuHangBaoTrans as
(
	select 
		7 as BizID,
		MerchantNo,
		(select MerchantName from Table_MerInfo where MerchantNo = PayTransData.MerchantNo) MerchantName,
		SUM(TransCnt) TransCnt,
		SUM(TransAmt) TransAmt,
		SUM(FeeAmt) FeeAmt,
		SUM(CostAmt) CostAmt,
		SUM(InstuFeeAmt) InstuFeeAmt
	from
		PayTransData
	where
		MerchantNo = '808080510004481'
	group by
		MerchantNo
),

--4.4 Get B2B Trans Data
B2BTrans as
(
	select
		2 as BizID,
		MerchantNo,
		(select MerchantName from Table_MerInfo where MerchantNo = PayTransData.MerchantNo) MerchantName,
		SUM(TransCnt) TransCnt,
		SUM(TransAmt) TransAmt,
		SUM(FeeAmt) FeeAmt,
		SUM(CostAmt) CostAmt,
		SUM(InstuFeeAmt) InstuFeeAmt
	from
		PayTransData
	where
		MerchantNo not in ('808080510003188','808080510004481')
		and
		GateNo in (select GateNo from Table_GateCategory where GateCategory1 = 'B2B')
	group by
		MerchantNo
),

--4.5 Get '代扣' Trans Data
DeductTrans as
(
	select
		3 as BizID,
		MerchantNo,
		(select MerchantName from Table_MerInfo where MerchantNo = PayTransData.MerchantNo) MerchantName,
		SUM(TransCnt) TransCnt,
		SUM(TransAmt) TransAmt,
		SUM(FeeAmt) FeeAmt,
		SUM(CostAmt) CostAmt,
		SUM(InstuFeeAmt) InstuFeeAmt
	from
		PayTransData
	where
		MerchantNo not in ('808080510003188','808080510004481')
		and
		GateNo in (select GateNo from Table_GateCategory where GateCategory1 = N'代扣')
	group by
		MerchantNo
),

--4.6 Get '信用支付' Trans Data
SalesCreditTrans as
(
	select
		8 as BizID,
		MerchantNo,
		(select MerchantName from Table_MerInfo where MerchantNo = PayTransData.MerchantNo) MerchantName,
		SUM(TransCnt) TransCnt,
		SUM(TransAmt) TransAmt,
		SUM(FeeAmt) FeeAmt,
		SUM(CostAmt) CostAmt,
		SUM(InstuFeeAmt) InstuFeeAmt
	from
		PayTransData
	where
		MerchantNo not in ('808080510003188','808080510004481')
		and
		GateNo in ('5602','5603')
	group by
		MerchantNo
),

--4.7 Get B2C Trans Data
B2CTrans as
(
	select
		1 as BizID,
		MerchantNo,
		(select MerchantName from Table_MerInfo where MerchantNo = PayTransData.MerchantNo) MerchantName,
		SUM(TransCnt) TransCnt,
		SUM(TransAmt) TransAmt,
		SUM(FeeAmt) FeeAmt,
		SUM(CostAmt) CostAmt,
		SUM(InstuFeeAmt) InstuFeeAmt
	from
		PayTransData
	where
		MerchantNo not in ('808080510003188','808080510004481')
		and
		GateNo not in (select GateNo from Table_GateCategory where GateCategory1 in('B2B',N'代扣'))
		and
		GateNo not in ('5602','5603','5901','5902')
	group by
		MerchantNo
),

--4.8 Get West Union Trans Data
WUTransData as
(
	select
		5 as BizID,
		MerchantNo,
		(select MerchantName from Table_OraMerchants where MerchantNo = Table_WUTransLog.MerchantNo) MerchantName,
		COUNT(DestTransAmount) TransCnt,
		SUM(DestTransAmount)/100.0 TransAmt,
		NULL as FeeAmt,
		NULL as CostAmt,
		NULL as InstuFeeAmt
	from
		Table_WUTransLog
	where
		CPDate >= @CurrStartDate
		and
		CPDate <  @CurrEndDate
	group by
		MerchantNo
),

--4.9 Get 代付 数据
OraTransData as
(
	select		
		4 as BizID,
		Ora.MerchantNo,
		(select MerchantName from Table_OraMerchants where MerchantNo = Ora.MerchantNo) MerchantName,
		(Ora.TransCnt - ISNULL(Finance.TransCnt,0)) TransCnt,
		(Ora.TransAmt - ISNULL(Finance.TransAmt,0)) TransAmt,
		(Ora.FeeAmt - ISNULL(Finance.FeeAmt,0)) FeeAmt,
		(Ora.CostAmt - ISNULL(Finance.CostAmt,0)) CostAmt,
		(Ora.InstuFeeAmt - ISNULL(Finance.InstuFeeAmt,0)) InstuFeeAmt
	from
		#OraTransData Ora
		left join
		#FinanceOraData Finance
		on
			Ora.MerchantNo = Finance.MerchantNo
	where			
		Ora.MerchantNo not in ('606060290000015','606060290000016','606060290000017')
		and
		(
			(Ora.TransCnt - ISNULL(Finance.TransCnt,0)) <> 0
			or
			(Ora.TransAmt - ISNULL(Finance.TransAmt,0)) <> 0
			or
			(Ora.FeeAmt - ISNULL(Finance.FeeAmt,0)) <> 0
		)
),

--5. Get Finance Trans Data
--5.1 Get All Transfer Data
AllTransferData as
(
	select
		TransType,
		MerchantNo,
		SUM(TransAmt)/100.0 TransAmt,
		COUNT(TransAmt) TransCnt,
		SUM(FeeAmt)/100.0 FeeAmt
	from
		Table_TrfTransLog
	where
		TransDate >= @CurrStartDate
		and
		TransDate <  @CurrEndDate
	group by
		TransType,		
		MerchantNo
),

--5.2 Get B2C Fund Trans Data
B2CFundData as
(
	select
		9 as BizID,
		MerchantNo,
		(select MerchantName from Table_MerInfo where MerchantNo = AllTransferData.MerchantNo) MerchantName,
		SUM(case when TransType = '3020' then -1*TransCnt else TransCnt End) as TransCnt,
		SUM(case when TransType = '3020' then -1*TransAmt else TransAmt End) as TransAmt,
		NULL as FeeAmt,
		NULL as CostAmt,
		NULL as InstuFeeAmt
	from
		AllTransferData
	where
		TransType in ('3010','3020','3030','3040')
	group by
		MerchantNo
),

--5.2 Get Transfer Data
TransferData as 
(
	select
		11 as BizID,
		MerchantNo,
		(select MerchantName from Table_MerInfo where MerchantNo = AllTransferData.MerchantNo) MerchantName,
		SUM(TransCnt) TransCnt,
		SUM(TransAmt) TransAmt,
		0.3*SUM(ISNULL(FeeAmt,0)) FeeAmt,
		0 as CostAmt,
		0 as InstuFeeAmt
	from
		AllTransferData
	where
		TransType = '2070'
	group by
		MerchantNo
),	

--5.4 Get CreditCardPayment Data
CreditCardData as
(
	select
		12 as BizID,
		NULL as MerchantNo,
		NULL as MerchantName,
		ISNULL(SUM(RepaymentCount),0) TransCnt,
		ISNULL(SUM(RepaymentAmount),0) TransAmt,
		0.2*ISNULL(SUM(RepaymentCount),0) FeeAmt,
		0 as CostAmt,
		0 as InstuFeeAmt
	from
		Table_CreditCardPayment
	where
		RepaymentDate >= @CurrStartDate
		and
		RepaymentDate <  @CurrEndDate
),

--5.5 Get Finance Trans Data
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
		#FinanceBizData
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
		#FinanceBizData
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
			#FinanceBizData
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
),
OtherTransUpdate as
(
	select
		OtherPayTrans.BizCategory,
		OtherPayTrans.MerchantNo,
		OtherPayTrans.TransAmt TransAmt,
		OtherPayTrans.TransCnt TransCnt,
		case when Gate.GateCategory1 = N'代扣' then 0.7*OtherPayTrans.TransCnt
			 when Gate.GateCategory1 = N'B2B' then 5.0*OtherPayTrans.TransCnt 
			 Else OtherPayTrans.CostAmt End as CostAmt,
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
		SUM(TransAmt) TransAmt,
		SUM(TransCnt) TransCnt,
		SUM(CostAmt) CostAmt,
		SUM(FeeAmt) FeeAmt,
		SUM(InstuFeeAmt) InstuFeeAmt
	from
		OtherTransUpdate
	group by
		BizCategory,
		MerchantNo
),
DomesticSum as
(
	select
		BizCategory,
		MerchantNo,
		SUM(TransAmt) TransAmt,
		SUM(TransCnt) TransCnt,
		0.0025*SUM(TransAmt) as CostAmt,
		SUM(FeeAmt) FeeAmt,
		SUM(InstuFeeAmt) InstuFeeAmt
	 from
		DomesticTrans
	 group by
		BizCategory,
		MerchantNo
),
FinanceTrans as
(
	select * from DomesticSum
	union all 
	select * from otherTransSum
),
FinanceBizData as
(
	select
		BizCategory.BizID,
		BizTrans.MerchantNo,
		(select MerchantName from Table_MerInfo where MerchantNo = BizTrans.MerchantNo) MerchantName,
		SUM(BizTrans.TransCnt) TransCnt,
		SUM(BizTrans.TransAmt) TransAmt,
		SUM(BizTrans.FeeAmt) FeeAmt,
		SUM(BizTrans.CostAmt) CostAmt, 
		SUM(BizTrans.InstuFeeAmt) InstuFeeAmt
	from
		FinanceTrans BizTrans
		inner join
		(select
			*
		 from
			#BizCategory
		 where
			BizDept = N'金融部'
		)BizCategory
		on
			BizTrans.BizCategory = BizCategory.BizCategory
	group by
		BizCategory.BizID,
		BizTrans.MerchantNo
	union all
	select
		BizCategory.BizID,
		Ora.MerchantNo,
		(select MerchantName from Table_OraMerchants where MerchantNo = Ora.MerchantNo) MerchantName,
		SUM(Ora.TransCnt) TransCnt,
		SUM(Ora.TransAmt) TransAmt,
		SUM(Ora.FeeAmt) FeeAmt,
		SUM(Ora.CostAmt) CostAmt, 
		SUM(Ora.InstuFeeAmt) InstuFeeAmt
	from
		#FinanceOraData Ora
		inner join
		(select
			*
		 from
			#BizCategory
		 where
			BizDept = N'金融部'
		)BizCategory
		on
			Ora.BizCategory = BizCategory.BizCategory
	group by
		BizCategory.BizID,
		Ora.MerchantNo
),	

--6. Get CP Corp TransData
--6.1 Get 基金（CupSecure） Trans Data
CupSecureFundTrans as
(
	select
		203 as BizID,
		MerchantNo,
		(select MerchantName from Table_MerInfo where MerchantNo = FactDailyTrans.MerchantNo) MerchantName,
		SUM(SucceedTransCount) TransCnt,
		SUM(SucceedTransAmount)/100.0 TransAmt,
		0 as FeeAmt,
		0.0025*SUM(SucceedTransAmount)/100.0 as CostAmt,
		0 as InstuFeeAmt
	from
		FactDailyTrans
	where
		DailyTransDate >= @CurrStartDate
		and
		DailyTransDate <  @CurrEndDate
		and
		GateNo in ('0044','0045')
		and
		MerchantNo not in (select MerchantNo from #BranchMer)
	group by
		MerchantNo
),

--6.2 Get CP 信用支付 数据
CPCreditTrans as
(
	select
		201 as BizID,
		MerchantNo,
		(select MerchantName from Table_MerInfo where MerchantNo = PayTransData.MerchantNo) MerchantName,
		SUM(TransCnt) TransCnt,
		SUM(TransAmt) TransAmt,
		SUM(FeeAmt) FeeAmt,
		SUM(CostAmt) CostAmt,
		SUM(InstuFeeAmt) InstuFeeAmt
	from
		PayTransData
	where
		MerchantNo not in ('808080510003188','808080510004481')
		and
		GateNo in ('5901','5902')
	group by
		MerchantNo
),

--6.3 Get 支付转代付 数据
PayToOraData as
(
	select		
		205 as BizID,
		Ora.MerchantNo,
		(select MerchantName from Table_OraMerchants where MerchantNo = Ora.MerchantNo) MerchantName,
		(Ora.TransCnt - ISNULL(Finance.TransCnt,0)) TransCnt,
		(Ora.TransAmt - ISNULL(Finance.TransAmt,0)) TransAmt,
		(Ora.FeeAmt - ISNULL(Finance.FeeAmt,0)) FeeAmt,
		(Ora.CostAmt - ISNULL(Finance.CostAmt,0)) CostAmt,
		(Ora.InstuFeeAmt - ISNULL(Finance.InstuFeeAmt,0)) InstuFeeAmt
	from
		#OraTransData Ora
		left join
		#FinanceOraData Finance
		on
			Ora.MerchantNo = Finance.MerchantNo
	where			
		Ora.MerchantNo in ('606060290000015','606060290000016','606060290000017')
)

--7. Join All Trans Data
select * into #Result from B2CTrans
union all
select * from B2BTrans
union all
select * from DeductTrans
union all
select * from OraTransData
union all
select * from WUTransData
union all
select * from BizTripTrans
union all
select * from YuHangBaoTrans
union all
select * from SalesCreditTrans
union all
select * from FinanceBizData
union all
select * from B2CFundData
union all
select * from TransferData
union all
select * from CreditCardData
union all
select * from CPCreditTrans
union all
select * from CupSecureFundTrans
union all
select * from PayToOraData;


--8. Join Biz Dept List
select
	Biz.BizID,
	Biz.BizDept,
	Biz.BizCategory,
	Result.MerchantNo,
	Result.MerchantName,
	Result.TransCnt,
	Result.TransAmt,
	Result.FeeAmt,
	Result.InstuFeeAmt,
	Result.CostAmt,
	Ratio.RefRatio
from
	#BizCategory Biz
	left join
	#Result Result
	on
		Biz.BizID = Result.BizID
	left join
	Table_ExpenAllocRefRatio Ratio
	on
		Biz.BizCategory = Ratio.BizCategory
order by
	Biz.BizID;
	
--9. Drop Temp table 
Drop table #BranchMer;
--Drop table #ProcOraCost;
Drop table #OraTransData;
Drop table #PayProcData;
Drop table #PayTransData;
Drop table #FinanceBizData;
Drop table #BizCategory;
Drop table #FinanceOraData;

End