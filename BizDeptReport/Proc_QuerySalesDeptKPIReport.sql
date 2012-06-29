--[Created] At 20120604 By 王红燕:销售考核报表(境外数据已转为人民币数据)
--[Modified] At 20120627 By 王红燕：Add Finance Ora Trans Data
if OBJECT_ID(N'Proc_QuerySalesDeptKPIReport', N'P') is not null
begin
	drop procedure Proc_QuerySalesDeptKPIReport;
end
go

create procedure Proc_QuerySalesDeptKPIReport
	@StartDate datetime = '2012-01-01',
	@EndDate datetime = '2012-02-29'
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
	N'代收付' as TypeName,
	1 as OrderID,
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
		OraCost.MerchantNo = OraFee.MerchantNo;
		
update
	Ora
set
	Ora.FeeAmt = (MerRate.FeeValue * Ora.TransCnt)/100.0
from
	#OraAllData Ora
	inner join
	Table_OraOrdinaryMerRate MerRate
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

--3.3 Prepare West Union Trans Data
With WUTransData as
(
	select
		N'西联汇款' as TypeName,
		4 as OrderID,
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
		CPDate >= @StartDate
		and
		CPDate <  @EndDate
	group by
		MerchantNo
),
--3.4 Prepare Deduction Data
DeductionData as 
(
	select
		N'代收付' as TypeName,
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
		N'支付渠道基金(0044、0045网关交易)' as TypeName,
		6 as OrderID,
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
--3.6 Prepare Convenience Data
ConvenienceData as
(
	select
		N'便民(公共事业缴费)' as TypeName,
		3 as OrderID,
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
		MerchantNo in (select MerchantNo from dbo.Table_InstuMerInfo where InstuNo = '000020100816001')
		and
		GateNo not in ('0044','0045')
		and
		GateNo not in (select GateNo from Table_GateCategory where GateCategory1 = N'代扣')
	group by
		MerchantNo
),
--3.7 Prepare EMall Data
EMallData as
(
	select
		N'商城' as TypeName,
		5 as OrderID,
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
		MerchantNo in ('808080290000007')
		and
		GateNo not in ('0044','0045')
		and
		GateNo not in (select GateNo from Table_GateCategory where GateCategory1 = N'代扣')
	group by
		MerchantNo
),
--3.8 Prepare BizTrip Data
BizTrip as
(
	select
		N'银联商旅平台' as TypeName,
		7 as OrderID,
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
		MerchantNo in ('808080510003188')
		and
		GateNo not in ('0044','0045')
		and
		GateNo not in (select GateNo from Table_GateCategory where GateCategory1 = N'代扣')
	group by
		MerchantNo
),
--3.9 Prepare Left Payment Data
OnlinePayData as
(
	select
		N'一般网上支付' as TypeName,
		0 as OrderID,
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
		MerchantNo not in ('808080510003188','808080290000007')
		and
		MerchantNo not in (select MerchantNo from dbo.Table_InstuMerInfo where InstuNo = '000020100816001')
		and
		GateNo not in ('0044','0045')
		and
		GateNo not in (select GateNo from Table_GateCategory where GateCategory1 = N'代扣')
	group by
		MerchantNo
)
--4.Join All Data
select * from OnlinePayData
union all
select * from #OraAllData
union all
select * from DeductionData
union all
select * from ConvenienceData
union all
select * from WUTransData
union all
select * from EMallData
union all
select * from FundPayData
union all
select * from BizTrip;
	
--5.Drop Temp Table
Drop table #ProcPayCost;
Drop table #PayGateMerData;
Drop table #ProcOraCost;
Drop table #OraAllData;

End