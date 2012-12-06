--[Created] At 20120904 By 王红燕：行业投入产出分析报表(境外数据已转为人民币数据)
if OBJECT_ID(N'Proc_QueryIndustryIOReport', N'P') is not null
begin
	drop procedure Proc_QueryIndustryIOReport;
end
go

create procedure Proc_QueryIndustryIOReport
	@StartDate datetime = '2012-01-01',
	@EndDate datetime = '2012-02-29'
as
begin

--0. Check input
if (@StartDate is null or @EndDate is null)
begin
	raiserror(N'Input params cannot be empty in Proc_QueryIndustryIOReport', 16, 1);
end

--1 Prepare StartDate and EndDate
declare @CurrStartDate datetime;
declare @CurrEndDate datetime;
set @CurrStartDate = @StartDate;
set @CurrEndDate = DATEADD(day,1,@EndDate);
declare @HisRefDate datetime;
set @HisRefDate = DATEADD(DAY, -1, DATEADD(YEAR, DATEDIFF(YEAR, 0, @CurrStartDate), 0));

--2. Get All Biz Trans Data
--2.1 Get Ora Trans Data (Take Off Branch Office Merchant)
create table #OraRefCost
(
	BankSettingID char(10) not null,
	MerchantNo char(20) not null,
	CPDate datetime not null,
	TransCnt bigint not null,
	TransAmt bigint not null,
	CostAmt decimal(15,4) not null
);
insert into 
	#OraRefCost
exec 
	Proc_CalOraCost @CurrStartDate,@CurrEndDate,@HisRefDate;

create table #OraActCost
(
	BankSettingID char(10) not null,
	MerchantNo char(20) not null,
	CPDate datetime not null,
	TransCnt bigint not null,
	TransAmt bigint not null,
	CostAmt decimal(15,4) not null
);
insert into 
	#OraActCost
exec 
	Proc_CalOraCost @CurrStartDate,@CurrEndDate,NULL;
		
With OraFee as
(
	select
		Ora.MerchantNo,
		SUM(Ora.TransCount) TransCnt,
		SUM(Ora.TransAmount) TransAmt,
		SUM(Ora.FeeAmount) FeeAmt
	from
		Table_OraTransSum Ora		
	where
		Ora.CPDate >= @CurrStartDate
		and
		Ora.CPDate <  @CurrEndDate
	group by
		Ora.MerchantNo
),
OraRefCost as
(
	select
		Ora.MerchantNo,
		SUM(Ora.CostAmt) RefCostAmt
	from
		#OraRefCost Ora
	group by
		Ora.MerchantNo
),
OraActCost as
(
	select
		Ora.MerchantNo,
		SUM(Ora.CostAmt) ActCostAmt
	from
		#OraActCost Ora
	group by
		Ora.MerchantNo
)
select
	OraFee.MerchantNo,	
	OraFee.TransCnt,
	OraFee.TransAmt,
	OraFee.FeeAmt,
	OraRefCost.RefCostAmt,
	OraActCost.ActCostAmt,
	0 as InstuFeeAmt
into
	#OraTransData
from
	OraFee
	inner join
	OraRefCost
	on
		OraFee.MerchantNo = OraRefCost.MerchantNo
	inner join
	OraActCost
	on
		OraFee.MerchantNo = OraActCost.MerchantNo;
		
update
	Ora
set
	Ora.FeeAmt = MerRate.FeeValue * Ora.TransCnt
from
	#OraTransData Ora
	inner join
	Table_OraAdditionalFeeRule MerRate
	on
		Ora.MerchantNo = MerRate.MerchantNo;
		
--2.2 Get Payment Trans Data (Take Off Branch Office Merchant)
create table #PayRefCost
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
	#PayRefCost
exec 
	Proc_CalPaymentCost @CurrStartDate,@CurrEndDate,@HisRefDate,'on';

create table #PayActCost
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
	#PayActCost
exec 
	Proc_CalPaymentCost @CurrStartDate,@CurrEndDate,NULL,'on';
--3. Get Industry Name Info
With IndustryName as
(
	select
		coalesce(Sales.MerchantNo,Finance.MerchantNo) MerchantNo,
		case when Sales.IndustryName = N'' Then NULL else Sales.IndustryName End as SalesInduInfo,
		case when Finance.IndustryName = N'' Then NULL else Finance.IndustryName End as FinanceInduInfo
	from
		Table_MerAttribute Sales
		full outer join
		Table_FinancialDeptConfiguration Finance
		on
			Sales.MerchantNo = Finance.MerchantNo
),
AllMerInfo as
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
--4. Get Sales Dept Trans Data
--4.l Get Left Payment Trans Data
Ref as 
(
	select
		MerchantNo,
		SUM(TransSumCount) TransCnt,
		SUM(TransSumAmount) TransAmt,
		SUM(FeeAmt) FeeAmt,
		SUM(Cost) RefCostAmt,
		SUM(InstuFeeAmt) InstuFeeAmt
	from
		#PayRefCost
	group by
		MerchantNo
),
Act as
(
	select
		MerchantNo,
		SUM(Cost) ActCostAmt
	from
		#PayActCost
	group by
		MerchantNo
),
PayTransData as
(
	select
		Ref.MerchantNo,
		Ref.TransCnt,
		Ref.TransAmt,
		Ref.FeeAmt,
		Ref.RefCostAmt,
		Act.ActCostAmt,
		Ref.InstuFeeAmt
	from
		Ref
		inner join
		Act
		on
			Ref.MerchantNo = Act.MerchantNo
),
--4.8 Get West Union Trans Data
WUTransData as
(
	select
		WU.MerchantNo,
		COUNT(WU.DestTransAmount) TransCnt,
		SUM(WU.DestTransAmount) TransAmt,
		NULL as FeeAmt,		
		NULL as RefCostAmt,
		NULL as ActCostAmt,
		NULL as InstuFeeAmt
	from
		Table_WUTransLog WU	
	where
		WU.CPDate >= @CurrStartDate
		and
		WU.CPDate <  @CurrEndDate
	group by
		WU.MerchantNo
),
PayWuOraTrans as
(
	select * from PayTransData
	union all
	select * from #OraTransData
	union all
	select * from WUTransData
),
IndustryTrans as 
(
	select
		0 as BizID,
		coalesce(IndustryName.SalesInduInfo,IndustryName.FinanceInduInfo) IndustryName,
		ISNULL(IndustryName.SalesInduInfo,N'') SalesInduInfo,
		ISNULL(IndustryName.FinanceInduInfo,N'') FinanceInduInfo,
		coalesce(PayWuOraTrans.MerchantNo,IndustryName.MerchantNo) MerchantNo,
		(select MerchantName from AllMerInfo where MerchantNo = coalesce(PayWuOraTrans.MerchantNo,IndustryName.MerchantNo)) MerchantName,
		ISNULL(PayWuOraTrans.TransCnt,0)/10000.0 TransCnt,
		ISNULL(PayWuOraTrans.TransAmt,0)/10000000000.0 TransAmt,
		ISNULL(PayWuOraTrans.FeeAmt,0)/100.0 FeeAmt,
		ISNULL(PayWuOraTrans.RefCostAmt,0)/100.0 RefCostAmt,
		ISNULL(PayWuOraTrans.ActCostAmt,0)/100.0 ActCostAmt,
		ISNULL(PayWuOraTrans.InstuFeeAmt,0)/100.0 InstuFeeAmt,
		case when ISNULL(IndustryName.SalesInduInfo,N'') <> N'' and ISNULL(IndustryName.FinanceInduInfo,N'') <> N'' then 1 else 0 End as RepeatedFlag
	from
		PayWuOraTrans
		full outer join
		IndustryName
		on
			PayWuOraTrans.MerchantNo = IndustryName.MerchantNo	
),

--5. Get Finance Trans Data
--5.1 Get All Transfer Data
AllTransferData as
(
	select
		TransType,
		MerchantNo,
		SUM(TransAmt)/10000000000.0 TransAmt,
		COUNT(TransAmt)/10000.0 TransCnt,
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
		2 as BizID,
		N'B2C基金' as IndustryName,
		NULL as SalesInduInfo,
		NULL as FinanceInduInfo,
		MerchantNo,
		(select MerchantName from Table_MerInfo where MerchantNo = AllTransferData.MerchantNo) MerchantName,
		SUM(case when TransType = '3020' then -1*TransCnt else TransCnt End) as TransCnt,
		SUM(case when TransType = '3020' then -1*TransAmt else TransAmt End) as TransAmt,
		NULL as FeeAmt,	
		NULL as RefCostAmt,
		NULL as ActCostAmt,
		NULL as InstuFeeAmt,
		0 as RepeatedFlag
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
		3 as BizID,
		N'转账' as IndustryName,
		NULL as SalesInduInfo,
		NULL as FinanceInduInfo,
		MerchantNo,
		(select MerchantName from Table_MerInfo where MerchantNo = AllTransferData.MerchantNo) MerchantName,
		SUM(TransCnt) TransCnt,
		SUM(TransAmt) TransAmt,
		0.3*SUM(ISNULL(FeeAmt,0)) FeeAmt,	
		0 as RefCostAmt,
		0 as ActCostAmt,
		0 as InstuFeeAmt,
		0 as RepeatedFlag
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
		4 as BizID,
		N'信用卡还款' as IndustryName,
		NULL as SalesInduInfo,
		NULL as FinanceInduInfo,
		NULL as MerchantNo,
		NULL as MerchantName,
		ISNULL(SUM(RepaymentCount),0)/10000.0 TransCnt,
		ISNULL(SUM(RepaymentAmount),0)/100000000.0 TransAmt,
		0.2*ISNULL(SUM(RepaymentCount),0) FeeAmt,	
		0 as RefCostAmt,
		0 as ActCostAmt,
		0 as InstuFeeAmt,
		0 as RepeatedFlag
	from
		Table_CreditCardPayment
	where
		RepaymentDate >= @CurrStartDate
		and
		RepaymentDate <  @CurrEndDate
),

--6. Get CP Corp TransData
--6.1 Get 基金（CupSecure） Trans Data
CupSecureFundTrans as
(
	select
		1 as BizID,
		N'基金（支付）' as IndustryName,
		NULL as SalesInduInfo,
		NULL as FinanceInduInfo,
		MerchantNo,
		(select MerchantName from Table_MerInfo where MerchantNo = FactDailyTrans.MerchantNo) MerchantName,
		SUM(SucceedTransCount)/10000.0 TransCnt,
		SUM(SucceedTransAmount)/10000000000.0 TransAmt,
		0 as FeeAmt,	
		0 as RefCostAmt,
		0 as ActCostAmt,
		0 as InstuFeeAmt,
		0 as RepeatedFlag
	from
		FactDailyTrans
	where
		DailyTransDate >= @CurrStartDate
		and
		DailyTransDate <  @CurrEndDate
		and
		GateNo in ('0044','0045')
	group by
		MerchantNo
)
--7. Join All Trans Data
select * from IndustryTrans
union all
select * from CupSecureFundTrans
union all
select * from B2CFundData
union all
select * from TransferData
union all
select * from CreditCardData
order by BizID;
	
--8. Drop Temp table 
Drop table #OraRefCost;
Drop table #OraActCost;
Drop table #OraTransData;
Drop table #PayRefCost;
Drop table #PayActCost;

End