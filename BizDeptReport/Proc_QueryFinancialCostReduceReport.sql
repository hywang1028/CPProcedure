--[Created] At 20120530 By 王红燕:金融考核报表之银行成本降低额明细表(境外数据已转为人民币数据)
--[Modified] At 20120713 By 王红燕：Add All Bank Cost Calc Procs @HisRefDate Para Value
--[Modified] At 20130419 By 王红燕：Modify Reference Cost to Standard Cost
if OBJECT_ID(N'Proc_QueryFinancialCostReduceReport', N'P') is not null
begin
	drop procedure Proc_QueryFinancialCostReduceReport;
end
go

create procedure Proc_QueryFinancialCostReduceReport
	@StartDate datetime = '2013-01-01',
	@EndDate datetime = '2013-03-31'
as
begin

--1. Check input
if (@StartDate is null or @EndDate is null)
begin
	raiserror(N'Input params cannot be empty in Proc_QueryFinancialCostReduceReport', 16, 1);
end

--2. Prepare StartDate and EndDate
declare @CurrStartDate datetime;
declare @CurrEndDate datetime;
set @CurrStartDate = @StartDate;
set @CurrEndDate = DATEADD(day,1,@EndDate);
--declare @HisRefDate datetime;
--set @HisRefDate = DATEADD(DAY, -1, '2012-01-01');

--3. Prepare Trans Data
create table #ActualPayCost
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
	#ActualPayCost
exec 
	Proc_CalPaymentCost @CurrStartDate,@CurrEndDate,NULL,'on';

create table #ActualOraCost
(
	GateNo char(10) not null,
	MerchantNo char(20) not null,
	CPDate datetime not null,
	TransSumCount bigint not null,
	TransSumAmount bigint not null,
	Cost decimal(15,4) not null
);
insert into 
	#ActualOraCost
exec 
	Proc_CalOraCost @CurrStartDate,@CurrEndDate,NULL;		
	
With ActualPayCost as
(
	select 
		Pay.GateNo,
		ISNULL(Gate.GateCategory1, N'B2C') as GateCategory,
		Pay.MerchantNo,
		Convert(decimal,SUM(Pay.TransSumAmount))/100 TransAmt,
		Convert(decimal,SUM(Pay.TransSumCount)) TransCnt,
		Convert(decimal,SUM(Pay.Cost))/100 CostAmt
	from 
		#ActualPayCost Pay
		Left join
		Table_GateCategory Gate
		on
			Pay.GateNo = Gate.GateNo
	group by
		Pay.GateNo,
		ISNULL(Gate.GateCategory1, N'B2C'),
		Pay.MerchantNo
),
ActualOraCost as
(
	select 
		GateNo,
		N'代收付' as GateCategory,
		Convert(decimal,SUM(TransSumAmount))/100 TransAmt,
		Convert(decimal,SUM(TransSumCount)) TransCnt,
		Convert(decimal,SUM(Cost))/100 CostAmt
	from 
		#ActualOraCost
	group by
		GateNo
),
DeductionData as 
(
	select
		GateNo,
		N'代收付' as GateCategory,
		SUM(TransAmt) TransAmt,
		SUM(TransCnt) TransCnt,
		SUM(CostAmt) CostAmt
	from
		ActualPayCost
	where
		GateCategory = N'代扣'
	group by
		GateNo
),
B2BTransData as
(
	select
		GateNo,
		N'B2B' as GateCategory,
		SUM(TransAmt) TransAmt,
		SUM(TransCnt) TransCnt,
		SUM(CostAmt) CostAmt
	from
		ActualPayCost
	where
		GateCategory = N'B2B'
	group by
		GateNo
),
--3.5 Prepare Fund(Pay) Data
FundPayData as
(
	select
		N'' as GateNo,
		N'基金(支付)' as GateCategory,
		SUM(SucceedTransAmount)/100.0 as TransAmt,
		SUM(SucceedTransCount) as TransCnt,
		0.0025*SUM(SucceedTransAmount)/100.0 as CostAmt
	from
		FactDailyTrans
	where
		DailyTransDate >= @CurrStartDate
		and
		DailyTransDate < @CurrEndDate
		and
		GateNo in ('0044','0045')
),
--3.6 Prepare B2C Trans Data
B2CAllTrans as
(
	select
		GateNo,
		MerchantNo,
		GateCategory,
		TransAmt,
		TransCnt,
		CostAmt
	from
		ActualPayCost
	where
		GateNo not in ('0044','0045')
		and
		GateCategory not in (N'代扣',N'B2B')
),
B2CNetBankTrans as
(
	select
		GateNo,
		MerchantNo,
		N'B2C网银' as GateCategory,
		TransAmt,
		TransCnt,
		CostAmt
	from
		B2CAllTrans
	where
		GateCategory not in ('EPOS','UPOP')
		and
		GateNo not in ('5901','5902')
	union all
	select
		GateNo,
		MerchantNo,
		N'B2C网银' as GateCategory,
		TransAmt,
		TransCnt,
		CostAmt
	from
		B2CAllTrans
	where
		GateCategory in ('EPOS') 
		and
		MerchantNo in (select MerchantNo from Table_EposTakeoffMerchant)
),
DomesticTrans as
(
	select
		GateNo,
		N'B2C网银(境内)' as GateCategory,
		SUM(TransAmt) TransAmt,
		SUM(TransCnt) TransCnt,
		SUM(CostAmt) CostAmt
	from
		B2CNetBankTrans
	where
		MerchantNo not in (select distinct MerchantNo from Table_MerInfoExt)
	group by
		GateNo
),
OutsideTrans as
(
	select
		GateNo,
		N'B2C网银(境外)' as GateCategory,
		SUM(TransAmt) TransAmt,
		SUM(TransCnt) TransCnt,
		SUM(CostAmt) CostAmt
	from
		B2CNetBankTrans
	where
		MerchantNo in (select distinct MerchantNo from Table_MerInfoExt)
	group by
		GateNo
),

--4.Join All Data
Result as
(
	select * from ActualOraCost
	union all
	select * from DeductionData
	union all
	select * from B2BTransData
	union all
	select * from FundPayData
	union all
	select * from DomesticTrans
	union all
	select * from OutsideTrans
)
select
	GateNo,
	GateCategory,
	TransAmt,
	TransCnt,
	CostAmt as ActCostAmt,
	case when GateCategory = N'B2B' 
		 then TransCnt*5.0
		 when GateCategory = N'代收付' 
		 then TransCnt*0.7
		 when GateCategory in (N'B2C网银(境内)',N'基金(支付)' ) 
		 then TransAmt*0.0025
		 Else CostAmt End as StdCostAmt
into
	#AllStdCostData
from
	(
		select
			GateNo,
			GateCategory,
			SUM(TransAmt) TransAmt,
			SUM(TransCnt) TransCnt,
			SUM(CostAmt) CostAmt
		from
			Result
		group by
			GateNo,
			GateCategory
	)Result;

With StdCostSum as
(
	select
		SUM(StdCostAmt) StdCostAmt
	from
		#AllStdCostData
)
select
	StdCost.GateNo,
	coalesce(Gate.GateDesc,Ora.BankName) GateName,
	case when StdCost.GateCategory in (N'B2B',N'代收付')
		 then 1 
		 Else 0 End as Flag,
	StdCost.TransAmt,
	StdCost.TransCnt,
	StdCost.ActCostAmt,
	case when StdCost.GateCategory in (N'B2B',N'代收付')
	     then case when StdCost.TransCnt = 0 
				   then 0
				   Else StdCost.ActCostAmt/StdCost.TransCnt End
		 Else case when StdCost.TransAmt = 0 
				   then 0
				   Else StdCost.ActCostAmt/StdCost.TransAmt End
	End as ActCostRatio,
	StdCost.StdCostAmt,
	case when StdCost.GateCategory in (N'B2B',N'代收付')
	     then case when StdCost.TransCnt = 0 
				   then 0
				   Else StdCost.StdCostAmt/StdCost.TransCnt End
		 Else case when StdCost.TransAmt = 0 
				   then 0
				   Else StdCost.StdCostAmt/StdCost.TransAmt End
	End as StdCostRatio,
	(StdCost.StdCostAmt - StdCost.ActCostAmt) as CostReduce,
	(select StdCostAmt from StdCostSum) as StdCostSum
from
	#AllStdCostData StdCost
	left join
	Table_GateRoute Gate
	on
		StdCost.GateNo = Gate.GateNo
	left join
	Table_OraBankSetting Ora
	on
		StdCost.GateNo = Ora.BankSettingID
where
	StdCost.GateCategory <> N'基金(支付)' 
	and 
	(StdCost.StdCostAmt - StdCost.ActCostAmt) <> 0
order by
	StdCost.GateNo;
	
--4.Drop table
Drop table #ActualPayCost;
Drop table #ActualOraCost;
Drop table #AllStdCostData;

End