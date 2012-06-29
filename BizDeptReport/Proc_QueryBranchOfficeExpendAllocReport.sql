--[Created] At 20120618 By 王红燕:分公司业务费用配置报表(境外数据已转为人民币数据)
if OBJECT_ID(N'Proc_QueryBranchOfficeExpendAllocReport', N'P') is not null
begin
	drop procedure Proc_QueryBranchOfficeExpendAllocReport;
end
go

create procedure Proc_QueryBranchOfficeExpendAllocReport
	@StartDate datetime = '2012-01-01',
	@EndDate datetime = '2012-02-29'
as
begin

--0. Check input
if (@StartDate is null or @EndDate is null)
begin
	raiserror(N'Input params cannot be empty in Proc_QueryBranchOfficeExpendAllocReport', 16, 1);
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

--2.0 Get All Biz Trans Data
--2.1 Get Branch Mer Payment Trans Data
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

--2.2 Get Branch Mer Ora Trans Data
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
		BranchMer.InstuName,
		BranchMer.MerchantNo,
		SUM(Ora.FeeAmount)/100.0 FeeAmt
	from
		Table_OraTransSum Ora
		inner join
		#BranchMer BranchMer
		on
			Ora.MerchantNo = BranchMer.MerchantNo
		
	where
		Ora.CPDate >= @CurrStartDate
		and
		Ora.CPDate <  @CurrEndDate
	group by
		BranchMer.InstuName,
		BranchMer.MerchantNo
),
OraCost as
(
	select
		BranchMer.InstuName,
		BranchMer.MerchantNo,
		SUM(Ora.TransCnt) TransCnt,
		SUM(Ora.TransAmt)/100.0 TransAmt,
		SUM(Ora.CostAmt)/100.0 CostAmt
	from
		#ProcOraCost Ora
		inner join
		#BranchMer BranchMer
		on
			Ora.MerchantNo = BranchMer.MerchantNo
	group by
		BranchMer.InstuName,
		BranchMer.MerchantNo
),
OraTransData as
(
	select
		N'代付交易' as BizCategory,
		3 as OrderID,
		OraCost.InstuName,
		OraCost.MerchantNo,
		(select MerchantName from Table_OraMerchants where MerchantNo = OraCost.MerchantNo) MerchantName,
		OraCost.TransAmt,
		OraCost.TransCnt,
		OraCost.CostAmt,
		OraFee.FeeAmt,
		0 as InstuFeeAmt
	from
		OraCost
		inner join
		OraFee
		on
			OraCost.InstuName = OraFee.InstuName
			and
			OraCost.MerchantNo = OraFee.MerchantNo
),
BranchTrans as
(
	select
		BranchMer.InstuName,
		Pay.MerchantNo,
		Pay.GateNo,
		SUM(Pay.TransSumCount) TransCnt,
		SUM(Pay.TransSumAmount)/100.0 TransAmt,
		SUM(Pay.FeeAmt)/100.0 FeeAmt,
		SUM(Pay.Cost)/100.0 CostAmt,
		SUM(Pay.InstuFeeAmt)/100.0 InstuFeeAmt
	from
		#PayProcData Pay
		inner join
		#BranchMer BranchMer
		on
			Pay.MerchantNo = BranchMer.MerchantNo
	group by
		BranchMer.InstuName,
		Pay.MerchantNo,
		Pay.GateNo
),
--2.3 Get B2B GateNo Trans Data
B2BTrans as
(
	select
		N'B2B交易' as BizCategory,
		1 as OrderID,
		InstuName,
		MerchantNo,
		(select MerchantName from Table_MerInfo where MerchantNo = BranchTrans.MerchantNo) MerchantName,
		SUM(TransCnt) TransCnt,
		SUM(TransAmt) TransAmt,
		SUM(FeeAmt) FeeAmt,
		SUM(InstuFeeAmt) InstuFeeAmt,
		SUM(CostAmt) CostAmt
	from
		BranchTrans
	where
		GateNo in (select GateNo from Table_GateCategory where GateCategory1 = 'B2B')
	group by
		InstuName,
		MerchantNo
),	
--2.4 Get Deduct GateNo Trans Data
DeductTrans as
(
	select
		N'代扣交易' as BizCategory,
		2 as OrderID,
		InstuName,
		MerchantNo,
		(select MerchantName from Table_MerInfo where MerchantNo = BranchTrans.MerchantNo) MerchantName,
		SUM(TransCnt) TransCnt,
		SUM(TransAmt) TransAmt,
		SUM(FeeAmt) FeeAmt,
		SUM(InstuFeeAmt) InstuFeeAmt,
		SUM(CostAmt) CostAmt
	from
		BranchTrans
	where
		GateNo in (select GateNo from Table_GateCategory where GateCategory1 = N'代扣')
	group by
		InstuName,
		MerchantNo
),	
--2.5 Get Other GateNo (B2C) Trans Data
B2CTrans as
(
	select
		N'B2C交易' as BizCategory,
		0 as OrderID,
		InstuName,
		MerchantNo,
		(select MerchantName from Table_MerInfo where MerchantNo = BranchTrans.MerchantNo) MerchantName,
		SUM(TransCnt) TransCnt,
		SUM(TransAmt) TransAmt,
		SUM(FeeAmt) FeeAmt,
		SUM(InstuFeeAmt) InstuFeeAmt,
		SUM(CostAmt) CostAmt
	from
		BranchTrans
	where
		GateNo not in (select GateNo from Table_GateCategory where GateCategory1 in ('B2B',N'代扣'))
	group by
		InstuName,
		MerchantNo
)
--3.0 Join All Trans Data
select * from B2CTrans
union all
select * from B2BTrans
union all
select * from DeductTrans
union all
select * from OraTransData;

--4.0 Drop Temp table
Drop Table #BranchMer;	
Drop Table #PayProcData;
Drop Table #ProcOraCost;

End