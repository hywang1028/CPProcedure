--[Created] At 20120604 By 王红燕:销售考核报表(境外数据已转为人民币数据)
--[Modified] At 20120627 By 王红燕：Add Finance Ora Trans Data
--[Modified] At 20120713 By 王红燕：Add All Bank Cost Calc Procs @HisRefDate Para Value
--[Modified] At 20130416 By 王红燕：Modify Biz Category and Cost Calc Format
--[Modified] At 20130929 By 王红燕：Add Table_TraScreenSum Trans Data
if OBJECT_ID(N'Proc_QuerySalesDeptKPIReport', N'P') is not null
begin
	drop procedure Proc_QuerySalesDeptKPIReport;
end
go

create procedure Proc_QuerySalesDeptKPIReport
	@StartDate datetime = '2013-07-01',
	@EndDate datetime = '2013-09-30'
as
begin

--1. Check input
if (@StartDate is null or @EndDate is null)
begin
	raiserror(N'Input params cannot be empty in Proc_QuerySalesDeptKPIReport', 16, 1);
end

--2. Prepare StartDate and EndDate
declare @CurrStartDate datetime;
declare @CurrEndDate datetime;
set @CurrStartDate = @StartDate;
set @CurrEndDate = DATEADD(day,1,@EndDate);
--declare @HisRefDate datetime;
--set @HisRefDate = DATEADD(DAY, -1, DATEADD(YEAR, DATEDIFF(YEAR, 0, @CurrStartDate), 0));
--set @CurrStartDate = '2012-01-01';
--set @CurrEndDate = '2012-03-01';
--3. Prepare Trans Data
--3.1 Prepare Payment Data
--3.1.1 Get All Payment Trans Data
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
	Proc_CalPaymentCost @CurrStartDate,@CurrEndDate,NULL,'on';

select 
	MerchantNo,
	GateNo,
	Convert(decimal,SUM(TransSumAmount))/10000000000 TransAmt,
	Convert(decimal,SUM(TransSumCount))/10000 TransCnt,
	Convert(decimal,SUM(Cost))/1000000 CostAmt,
	Convert(decimal,SUM(FeeAmt))/1000000 FeeAmt,
	Convert(decimal,SUM(InstuFeeAmt))/1000000 InstuFeeAmt
into
	#PayGateMerData
from 
	#ProcPayCost
group by
	MerchantNo,
	GateNo;

--3.1.2 Take Off Finance Dept Trans Data 		
update
	Pay
set
	Pay.TransAmt = (1-Finance.BelongRate)*Pay.TransAmt,
	Pay.TransCnt = (1-Finance.BelongRate)*Pay.TransCnt,
	Pay.CostAmt = (1-Finance.BelongRate)*Pay.CostAmt,
	Pay.FeeAmt = (1-Finance.BelongRate)*Pay.FeeAmt,
	Pay.InstuFeeAmt = (1-Finance.BelongRate)*Pay.InstuFeeAmt
from
	#PayGateMerData Pay
	inner join
	(
		select
			MerchantNo,
			GateNo,
			BelongRate
		from
			Table_BelongToFinance
		where
			GateNo <> 'all'
	)Finance
	on
		Pay.MerchantNo = Finance.MerchantNo
		and
		Pay.GateNo = Finance.GateNo;

update
	Pay
set
	Pay.TransAmt = (1-Finance.BelongRate)*Pay.TransAmt,
	Pay.TransCnt = (1-Finance.BelongRate)*Pay.TransCnt,
	Pay.CostAmt = (1-Finance.BelongRate)*Pay.CostAmt,
	Pay.FeeAmt = (1-Finance.BelongRate)*Pay.FeeAmt,
	Pay.InstuFeeAmt = (1-Finance.BelongRate)*Pay.InstuFeeAmt
from
	#PayGateMerData Pay
	inner join
	(
		select
			MerchantNo,
			BelongRate
		from
			Table_BelongToFinance
		where
			GateNo = 'all'
	)Finance
	on
		Pay.MerchantNo = Finance.MerchantNo;

--3.2 Prepare Ora Trans Data
--3.2.1 Prepare Old Ora Trans Data
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
		Convert(decimal,SUM(FeeAmount))/1000000 FeeAmt
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
		SUM(TransCnt)/10000.0 TransCnt,
		SUM(TransAmt)/10000000000.0 TransAmt,
		SUM(CostAmt)/1000000.0 CostAmt
	from
		#ProcOraCost
	group by
		MerchantNo
)
select
	N'代收付业务' as TypeName,
	2 as OrderID,
	OraCost.MerchantNo,
	(select MerchantName from Table_OraMerchants where MerchantNo = OraCost.MerchantNo) MerchantName,
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
		OraCost.MerchantNo = OraFee.MerchantNo
where
	OraCost.MerchantNo <> '606060290000015';
		
update
	Ora
set
	Ora.FeeAmt = (MerRate.FeeValue * Ora.TransCnt)/100.0
from
	#OraAllData Ora
	inner join
	Table_OraAdditionalFeeRule MerRate
	on
		Ora.MerchantNo = MerRate.MerchantNo;

update
	Ora
set
	Ora.TransAmt = (1-Finance.BelongRate)*Ora.TransAmt,
	Ora.TransCnt = (1-Finance.BelongRate)*Ora.TransCnt,
	Ora.CostAmt = (1-Finance.BelongRate)*Ora.CostAmt,
	Ora.FeeAmt = (1-Finance.BelongRate)*Ora.FeeAmt,
	Ora.InstuFeeAmt = (1-Finance.BelongRate)*Ora.InstuFeeAmt
from
	#OraAllData Ora
	inner join
	(
		select
			MerchantNo,
			BelongRate
		from
			Table_BelongToFinance
		where
			GateNo = 'all'
	)Finance
	on
		Ora.MerchantNo = Finance.MerchantNo;

--3.2.2 Prepare New Ora Trans Data
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

select
	N'代收付业务' as TypeName,
	2 as OrderID,
	TraCost.MerchantNo,
	(select MerchantName from Table_TraMerchantInfo where MerchantNo = TraCost.MerchantNo) MerchantName,
	SUM(TraCost.SucceedAmt)/10000000000.0  TransAmt,
	SUM(TraCost.SucceedCnt)/10000.0 TransCnt,
	SUM(TraCost.CostAmt)/1000000.0 CostAmt,
	SUM(TraCost.FeeAmt)/1000000.0 FeeAmt,
	0 as InstuFeeAmt
into
	#TraTransData
from
	#CalTraCost TraCost
group by
	MerchantNo;

update
	Tra
set
	Tra.TransAmt = (1-Finance.BelongRate)*Tra.TransAmt,
	Tra.TransCnt = (1-Finance.BelongRate)*Tra.TransCnt,
	Tra.CostAmt = (1-Finance.BelongRate)*Tra.CostAmt,
	Tra.FeeAmt = (1-Finance.BelongRate)*Tra.FeeAmt,
	Tra.InstuFeeAmt = (1-Finance.BelongRate)*Tra.InstuFeeAmt
from
	#TraTransData Tra
	inner join
	(
		select
			MerchantNo,
			BelongRate
		from
			Table_BelongToFinance
		where
			GateNo = 'all'
	)Finance
	on
		Tra.MerchantNo = Finance.MerchantNo;

--3.3 Prepare West Union Trans Data
With WUTransData as
(
	select
		N'西联汇款' as TypeName,
		3 as OrderID,
		MerchantNo,
		(select MerchantName from Table_OraMerchants where MerchantNo = Table_WUTransLog.MerchantNo) MerchantName,
		SUM(DestTransAmount)/10000000000.0 TransAmt,
		COUNT(DestTransAmount)/10000.0 TransCnt,
		NULL as CostAmt,
		NULL as FeeAmt,
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
--3.4 Prepare Deduction Data
DeductionData as 
(
	select
		N'代收付业务' as TypeName,
		2 as OrderID,
		MerchantNo,
		(select MerchantName from Table_MerInfo where MerchantNo = #PayGateMerData.MerchantNo) MerchantName,
		SUM(TransAmt) TransAmt,
		SUM(TransCnt) TransCnt,
		SUM(CostAmt) CostAmt,
		SUM(FeeAmt) FeeAmt,
		SUM(InstuFeeAmt) InstuFeeAmt
	from
		#PayGateMerData
	where
		GateNo in (select GateNo from Table_GateCategory where GateCategory1 = N'代扣')
	group by
		MerchantNo
),	
--3.5 Prepare Fund(Pay) Data
FundPayData as
(
	select
		N'B2C网银(境内)' as TypeName,
		0 as OrderID,
		MerchantNo,
		(select MerchantName from Table_MerInfo where MerchantNo = FactDailyTrans.MerchantNo) MerchantName,
		SUM(SucceedTransAmount)/10000000000.0 as TransAmt,
		SUM(SucceedTransCount)/10000.0 as TransCnt,
		NULL as CostAmt,
		NULL as FeeAmt,
		NULL as InstuFeeAmt
	from
		FactDailyTrans
	where
		DailyTransDate >= @CurrStartDate
		and
		DailyTransDate < @CurrEndDate
		and
		GateNo in ('0044','0045')
	group by
		MerchantNo
),
--3.6 Prepare B2C Trans Data
B2CAllTrans as
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
		#PayGateMerData
	where
		GateNo not in ('0044','0045')
		and
		GateNo not in (select GateNo from Table_GateCategory where GateCategory1 in (N'代扣',N'B2B'))
	group by
		MerchantNo,
		GateNo
),
DomesticTrans as
(
	select
		N'B2C网银(境内)' as TypeName,
		0 as OrderID,
		MerchantNo,
		(select MerchantName from Table_MerInfo where MerchantNo = B2CAllTrans.MerchantNo) MerchantName,
		SUM(TransAmt) TransAmt,
		SUM(TransCnt) TransCnt,
		SUM(CostAmt) CostAmt,
		SUM(FeeAmt) FeeAmt,
		SUM(InstuFeeAmt) InstuFeeAmt
	from
		B2CAllTrans
	where
		GateNo not in (select GateNo from Table_GateCategory where GateCategory1 in ('EPOS','UPOP'))
		and
		GateNo not in ('5901','5902')
		and
		MerchantNo not in (select distinct MerchantNo from Table_MerInfoExt)
	group by
		MerchantNo
	union all
	select
		N'B2C网银(境内)' as TypeName,
		0 as OrderID,
		MerchantNo,
		(select MerchantName from Table_MerInfo where MerchantNo = B2CAllTrans.MerchantNo) MerchantName,
		SUM(TransAmt) TransAmt,
		SUM(TransCnt) TransCnt,
		SUM(CostAmt) CostAmt,
		SUM(FeeAmt) FeeAmt,
		SUM(InstuFeeAmt) InstuFeeAmt
	from
		B2CAllTrans
	where
		GateNo in (select GateNo from Table_GateCategory where GateCategory1 in ('EPOS')) 
		and
		MerchantNo in (select MerchantNo from Table_EposTakeoffMerchant)
		and
		MerchantNo not in (select distinct MerchantNo from Table_MerInfoExt)
	group by
		MerchantNo
),
B2CTrans as
(
	select
		N'支付B2C' as TypeName,
		0 as OrderID,
		AllTrans.MerchantNo,
		(select MerchantName from Table_MerInfo where MerchantNo = AllTrans.MerchantNo) MerchantName,
		(AllTrans.TransAmt - ISNULL(DomeTrans.TransAmt, 0)) TransAmt,
		(AllTrans.TransCnt - ISNULL(DomeTrans.TransCnt, 0)) TransCnt,
		(AllTrans.CostAmt - ISNULL(DomeTrans.CostAmt, 0)) CostAmt,
		(AllTrans.FeeAmt - ISNULL(DomeTrans.FeeAmt, 0)) FeeAmt,
		(AllTrans.InstuFeeAmt - ISNULL(DomeTrans.InstuFeeAmt, 0)) InstuFeeAmt
	from
		(select
			MerchantNo,
			SUM(TransAmt) TransAmt,
			SUM(TransCnt) TransCnt,
			SUM(CostAmt) CostAmt,
			SUM(FeeAmt) FeeAmt,
			SUM(InstuFeeAmt) InstuFeeAmt
		 from
			B2CAllTrans
		 group by
			MerchantNo
		)AllTrans
		left join
		(select
			MerchantNo,
			SUM(TransAmt) TransAmt,
			SUM(TransCnt) TransCnt,
			SUM(CostAmt) CostAmt,
			SUM(FeeAmt) FeeAmt,
			SUM(InstuFeeAmt) InstuFeeAmt
		 from
			DomesticTrans
		 group by
			MerchantNo
		)DomeTrans
		on
			AllTrans.MerchantNo = DomeTrans.MerchantNo
),
--3.7 Prepare B2B Trans Data
B2BTrans as
(
	select
		N'支付B2B' as TypeName,
		1 as OrderID,
		MerchantNo,
		(select MerchantName from Table_MerInfo where MerchantNo = #PayGateMerData.MerchantNo) MerchantName,
		SUM(TransAmt) TransAmt,
		SUM(TransCnt) TransCnt,
		SUM(CostAmt) CostAmt,
		SUM(FeeAmt) FeeAmt,
		SUM(InstuFeeAmt) InstuFeeAmt
	from
		#PayGateMerData
	where
		GateNo in (select GateNo from Table_GateCategory where GateCategory1 = N'B2B')
	group by
		MerchantNo
)
--4.Join All Data
select * into #Result from B2CTrans
union all
select * from #OraAllData
union all
select * from #TraTransData
union all
select * from DeductionData
union all
select * from B2BTrans
union all
select * from WUTransData
union all
select * from FundPayData
union all
select * from DomesticTrans;

Update 
	#Result
Set
	TypeName = N'支付B2C',
	CostAmt = (10000.0 * TransAmt) * 0.0025
where	
	TypeName = N'B2C网银(境内)';
	
Update 
	#Result
Set
	CostAmt = TransCnt * 5.0
where	
	TypeName = N'支付B2B';
	
Update 
	#Result
Set
	CostAmt = TransCnt * 0.7
where	
	TypeName in (N'代收付业务');

select
	R.TypeName,
	R.OrderID,
	R.MerchantNo,
	B.MerchantName,
	SUM(R.TransAmt) TransAmt,
	SUM(R.TransCnt) TransCnt,
	SUM(R.CostAmt) CostAmt,
	SUM(R.FeeAmt) FeeAmt,
	SUM(R.InstuFeeAmt) InstuFeeAmt
from
	#Result R
	inner join
	(
		select
			MerchantNo,
			MIN(MerchantName) MerchantName
		from
			#Result
		group by
			MerchantNo
	)B
	on
		R.MerchantNo = B.MerchantNo
where
	10000.0*R.TransCnt <> 0
group by
	R.TypeName,
	R.OrderID,
	R.MerchantNo,
	B.MerchantName
order by
	R.OrderID;
	
--5.Drop Temp Table
Drop table #ProcPayCost;
Drop table #PayGateMerData;
Drop table #ProcOraCost;
Drop table #OraAllData;
Drop table #CalTraCost;
Drop table #TraTransData;
Drop table #Result;

End