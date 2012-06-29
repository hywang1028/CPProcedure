--[Created] At 20120619 By 王红燕：CP内部业务费用配置报表(境外数据已转为人民币数据)
--[Modified] At 20120627 By 王红燕：Add Finance Ora Trans Data
if OBJECT_ID(N'Proc_QueryCorpInnerExpendAllocReport', N'P') is not null
begin
	drop procedure Proc_QueryCorpInnerExpendAllocReport;
end
go

create procedure Proc_QueryCorpInnerExpendAllocReport
	@StartDate datetime = '2012-01-01',
	@EndDate datetime = '2012-02-29'
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
		Ora.MerchantNo not in (select MerchantNo from #BranchMer)
	group by
		Ora.MerchantNo
),
OraCost as
(
	select
		Ora.MerchantNo,
		SUM(Ora.TransCnt) TransCnt,
		SUM(Ora.TransAmt)/100.0 TransAmt,
		SUM(Ora.CostAmt)/100.0 CostAmt
	from
		#ProcOraCost Ora
	where
		Ora.MerchantNo not in(select MerchantNo from #BranchMer)
	group by
		Ora.MerchantNo
)
select
	OraCost.MerchantNo,
	(select MerchantName from Table_OraMerchants where MerchantNo = OraCost.MerchantNo) MerchantName,
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
	Table_OraOrdinaryMerRate MerRate
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
(204,'CP','基金（自有资金）'),
(205,'CP','支付转代付（自有资金）');

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
		#FinanceBizData BizTrans
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
		0 as CostAmt,
		0 as InstuFeeAmt
	from
		FactDailyTrans
	where
		DailyTransDate >= @StartDate
		and
		DailyTransDate <  @EndDate
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
Drop table #ProcOraCost;
Drop table #OraTransData;
Drop table #PayProcData;
Drop table #PayTransData;
Drop table #FinanceBizData;
Drop table #BizCategory;
Drop table #FinanceOraData;

End