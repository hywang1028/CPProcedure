
declare @StartDate date;
declare @EndDate date;

set @StartDate = '2013-01-01';
set @EndDate = '2013-11-01';


--1 FeeCalcResult总数据
create table #PaymentCost
(
	GateNo char(4),
	MerchantNo Char(20),
	FeeEndDate date,
	TransCnt int,
	TransAmt decimal(20,2),
	CostAmt decimal(20,2),
	FeeAmt decimal(20,2),
	InstuFeeAmt decimal(20,2)
);

if not exists(select 1 from #PaymentCost)
begin
	insert into #PaymentCost
	(
		GateNo,
		MerchantNo,
		FeeEndDate,
		TransCnt,
		TransAmt,
		CostAmt,
		FeeAmt,
		InstuFeeAmt
	)
	exec Proc_CalPaymentCost @StartDate,@EndDate,null,'on'
end;

--2 UpopliqFeeLiqResult数据
create table #UpopDirect
(
	GateNo char(4),
	MerchantNo char(20),
	TransDate date,
	CdFlag char(2),
	TransAmt bigint,
	TransCnt int,
	FeeAmt bigint,
	CostAmt decimal(20,2)
);

if not exists(select 1 from #UpopDirect)
begin
	insert into #UpopDirect
	(
		GateNo,
		MerchantNo,
		TransDate,
		CdFlag,
		TransAmt,
		TransCnt,
		FeeAmt,
		CostAmt
	)
	exec Proc_CalUpopCost @StartDate, @EndDate;
end

--3 All Data
With PaymentCost as
(
	select
		case when 
			GateNo in (select GateNo from Table_GateCategory where GateCategory1 = N'B2B')
		then
			N'B2B'
		when
			GateNo in (select GateNo from Table_GateCategory where GateCategory1 = N'UPOP')
		then
			N'UPOP网关'
		else
			N'B2C网银'			
		end as BizCategory,
		MerchantNo,
		FeeEndDate,
		TransCnt,
		TransAmt,
		CostAmt,
		FeeAmt,
		InstuFeeAmt
	from
		#PaymentCost
	where
		GateNo not in ('5901', '5902', '7008')	
)
select
	N'Table_FeeCalcResult' as plat,
	pc.MerchantNo,
	pc.MerchantNo as CpMerNo,
	pc.BizCategory,
	MONTH(pc.FeeEndDate) as Year_month,
	
	SUM(pc.TransCnt) as TransCnt,
	SUM(pc.TransAmt) as TransAmt,
	SUM(pc.CostAmt) as CostAmt,
	SUM(pc.FeeAmt) as FeeAmt,
	SUM(pc.InstuFeeAmt) as InstuFeeAmt
into
	#AllData
from
	PaymentCost pc
group by
	pc.MerchantNo,
	pc.BizCategory,
	MONTH(pc.FeeEndDate)
union all
select
	N'Table_UpopliqFeeLiqResult' as plat,
	ud.MerchantNo,
	isnull((select CpMerNo from Table_CpUpopRelation where UpopMerNo = ud.MerchantNo),ud.MerchantNo) as CpMerNo,
	N'UPOP直连' as BizCategory,
	MONTH(ud.TransDate) as Year_month,
	
	SUM(TransCnt) as TransCnt,
	SUM(TransAmt) as TransAmt,
	SUM(CostAmt) as CostAmt,
	SUM(FeeAmt) as FeeAmt,
	0 as InstuFeeAmt
from
	#UpopDirect ud
group by
	ud.MerchantNo,
	MONTH(ud.TransDate);

select
	ad.MerchantNo,
	case when 
		ad.plat = N'Table_FeeCalcResult'
	then
		(select MerchantName from Table_MerInfo where MerchantNo = ad.MerchantNo)
	else
		(select MerchantName from Table_UpopliqMerInfo where MerchantNo = ad.MerchantNo)
	end as MerchantName,
	Year_month,
	ad.BizCategory,
	coalesce(
		(select IndustryName from Table_FinancialDeptConfiguration where MerchantNo = ad.CpMerNo),
		(select IndustryName from Table_MerAttribute where MerchantNo = ad.CpMerNo),
		N''
	) as IndustryName,
	ad.TransAmt/1000000.0 as TransAmt,
	ad.TransCnt/10000.0 as TransCnt,
	ad.FeeAmt/1000000.0 as FeeAmt,
	ad.CostAmt/1000000.0 as CostAmt,
	ad.InstuFeeAmt/1000000.0 as InstuAmt,
	(ad.FeeAmt - ad.CostAmt - ad.InstuFeeAmt)/1000000.0 as ProfitAmt
from
	#AllData ad


drop table #AllData