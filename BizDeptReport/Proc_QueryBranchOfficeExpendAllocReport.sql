--[Created] At 20120618 By 王红燕:分公司业务费用配置报表(境外数据已转为人民币数据)
--[Modified] At 20120713 By 王红燕：Add All Bank Cost Calc Procs @HisRefDate Para Value
--[Modified] At 20130422 By 王红燕：Modify Cost Calc Format
if OBJECT_ID(N'Proc_QueryBranchOfficeExpendAllocReport', N'P') is not null
begin
	drop procedure Proc_QueryBranchOfficeExpendAllocReport;
end
go

create procedure Proc_QueryBranchOfficeExpendAllocReport
	@StartDate datetime = '2013-01-01',
	@EndDate datetime = '2013-03-31'
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
	
With OraTransData as
(
	select
		N'代付交易' as BizCategory,
		3 as OrderID,
		BranchMer.InstuName,
		BranchMer.MerchantNo,
		(select MerchantName from Table_OraMerchants where MerchantNo = BranchMer.MerchantNo) MerchantName,
		SUM(Ora.TransAmount)/100.0 TransAmt,
		SUM(Ora.TransCount) TransCnt,
		0.7*SUM(Ora.TransCount) CostAmt,
		SUM(Ora.FeeAmount)/100.0 FeeAmt,
		0 as InstuFeeAmt
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
		SUM(TransAmt) TransAmt,
		SUM(TransCnt) TransCnt,
		5.0*SUM(TransCnt) CostAmt,
		SUM(FeeAmt) FeeAmt,
		SUM(InstuFeeAmt) InstuFeeAmt
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
		SUM(TransAmt) TransAmt,
		SUM(TransCnt) TransCnt,
		0.7*SUM(TransCnt) CostAmt,
		SUM(FeeAmt) FeeAmt,
		SUM(InstuFeeAmt) InstuFeeAmt
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
		InstuName,
		MerchantNo,
		GateNo,
		TransCnt,
		TransAmt,
		FeeAmt,
		InstuFeeAmt,
		CostAmt
	from
		BranchTrans
	where
		GateNo not in (select GateNo from Table_GateCategory where GateCategory1 in ('B2B',N'代扣'))
),
DomesticTrans as
(
	select
		N'B2C网银(境内)' as BizCategory,
		0 as OrderID,
		InstuName,
		MerchantNo,
		(select MerchantName from Table_MerInfo where MerchantNo = B2CTrans.MerchantNo) MerchantName,
		SUM(TransAmt) TransAmt,
		SUM(TransCnt) TransCnt,
		SUM(CostAmt) CostAmt,
		SUM(FeeAmt) FeeAmt,
		SUM(InstuFeeAmt) InstuFeeAmt
	from
		B2CTrans
	where
		GateNo not in (select GateNo from Table_GateCategory where GateCategory1 in ('EPOS','UPOP'))
		and
		GateNo not in ('5901','5902')
		and
		MerchantNo not in (select distinct MerchantNo from Table_MerInfoExt)
	group by
		InstuName,
		MerchantNo
	union all
	select
		N'B2C网银(境内)' as BizCategory,
		0 as OrderID,
		InstuName,
		MerchantNo,
		(select MerchantName from Table_MerInfo where MerchantNo = B2CTrans.MerchantNo) MerchantName,
		SUM(TransAmt) TransAmt,
		SUM(TransCnt) TransCnt,
		SUM(CostAmt) CostAmt,
		SUM(FeeAmt) FeeAmt,
		SUM(InstuFeeAmt) InstuFeeAmt
	from
		B2CTrans
	where
		GateNo in (select GateNo from Table_GateCategory where GateCategory1 in ('EPOS')) 
		and
		MerchantNo in (select MerchantNo from Table_EposTakeoffMerchant)
		and
		MerchantNo not in (select distinct MerchantNo from Table_MerInfoExt)
	group by
		InstuName,
		MerchantNo
),
OtherB2CTrans as
(
	select
		N'B2C交易' as BizCategory,
		0 as OrderID,
		AllTrans.InstuName,
		AllTrans.MerchantNo,
		(select MerchantName from Table_MerInfo where MerchantNo = AllTrans.MerchantNo) MerchantName,
		(AllTrans.TransAmt - ISNULL(DomeTrans.TransAmt, 0)) TransAmt,
		(AllTrans.TransCnt - ISNULL(DomeTrans.TransCnt, 0)) TransCnt,
		(AllTrans.CostAmt - ISNULL(DomeTrans.CostAmt, 0)) CostAmt,
		(AllTrans.FeeAmt - ISNULL(DomeTrans.FeeAmt, 0)) FeeAmt,
		(AllTrans.InstuFeeAmt - ISNULL(DomeTrans.InstuFeeAmt, 0)) InstuFeeAmt
	from
		(select
			InstuName,
			MerchantNo,
			SUM(TransAmt) TransAmt,
			SUM(TransCnt) TransCnt,
			SUM(CostAmt) CostAmt,
			SUM(FeeAmt) FeeAmt,
			SUM(InstuFeeAmt) InstuFeeAmt
		 from
			B2CTrans
		 group by
			InstuName,
			MerchantNo
		)AllTrans
		left join
		(select
			InstuName,
			MerchantNo,
			SUM(TransAmt) TransAmt,
			SUM(TransCnt) TransCnt,
			SUM(CostAmt) CostAmt,
			SUM(FeeAmt) FeeAmt,
			SUM(InstuFeeAmt) InstuFeeAmt
		 from
			DomesticTrans
		 group by
			InstuName,
			MerchantNo
		)DomeTrans
		on
			AllTrans.InstuName = DomeTrans.InstuName
			and
			AllTrans.MerchantNo = DomeTrans.MerchantNo
)
--3.0 Join All Trans Data
select * into #Result from DomesticTrans
union all
select * from OtherB2CTrans
union all
select * from B2BTrans
union all
select * from DeductTrans
union all
select * from OraTransData;

Update 
	#Result
Set
	BizCategory = N'B2C交易',
	CostAmt = TransAmt * 0.0025
where	
	BizCategory = N'B2C网银(境内)';
	
select
	BizCategory,
	OrderID,
	InstuName,
	MerchantNo,
	MerchantName,
	SUM(TransAmt) TransAmt,
	SUM(TransCnt) TransCnt,
	SUM(CostAmt) CostAmt,
	SUM(FeeAmt) FeeAmt,
	SUM(InstuFeeAmt) InstuFeeAmt
from
	#Result
group by
	BizCategory,
	OrderID,
	InstuName,
	MerchantNo,
	MerchantName
order by
	OrderID;

--4.0 Drop Temp table
Drop Table #BranchMer;	
Drop Table #PayProcData;
Drop table #Result;
End