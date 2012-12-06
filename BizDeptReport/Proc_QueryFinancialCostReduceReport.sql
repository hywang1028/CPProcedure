--[Created] At 20120530 By 王红燕:金融考核报表之银行成本降低额明细表(境外数据已转为人民币数据)
--[Modified] At 20120713 By 王红燕：Add All Bank Cost Calc Procs @HisRefDate Para Value
if OBJECT_ID(N'Proc_QueryFinancialCostReduceReport', N'P') is not null
begin
	drop procedure Proc_QueryFinancialCostReduceReport;
end
go

create procedure Proc_QueryFinancialCostReduceReport
	@StartDate datetime = '2012-01-01',
	@EndDate datetime = '2012-05-29'
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
declare @HisRefDate datetime;
set @HisRefDate = DATEADD(DAY, -1, '2012-01-01');

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

create table #ReferPayCost
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
	#ReferPayCost
exec 
	Proc_CalPaymentCost @CurrStartDate,@CurrEndDate,@HisRefDate,'on';

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
	
create table #ReferOraCost
(
	GateNo char(10) not null,
	MerchantNo char(20) not null,
	CPDate datetime not null,
	TransSumCount bigint not null,
	TransSumAmount bigint not null,
	Cost decimal(15,4) not null
);
insert into 
	#ReferOraCost
exec 
	Proc_CalOraCost @CurrStartDate,@CurrEndDate,@HisRefDate;	
	
With ActualPayCost as
(
	select 
		GateNo,
		Convert(decimal,SUM(TransSumAmount))/100 TransAmt,
		Convert(decimal,SUM(Cost))/100 CostAmt
	from 
		#ActualPayCost
	group by
		GateNo
),
ReferPayCost as
(
	select 
		GateNo,
		Convert(decimal,SUM(TransSumAmount))/100 TransAmt,
		Convert(decimal,SUM(Cost))/100 CostAmt
	from 
		#ReferPayCost
	group by
		GateNo
),
PayCostData as
(
	select
		ActualCost.GateNo,
		(select GateDesc from Table_GateRoute where GateNo = ActualCost.GateNo) as GateName,
		ActualCost.TransAmt,
		ReferenceCost.CostAmt/ActualCost.TransAmt as ReferFeeRatio,
		ReferenceCost.CostAmt as ReferCost,
		ActualCost.CostAmt/ActualCost.TransAmt as ActualFeeRatio,
		ActualCost.CostAmt as ActualCost,
		ReferenceCost.CostAmt - ActualCost.CostAmt as CostReduce
	from
		ActualPayCost ActualCost
		inner join
		ReferPayCost ReferenceCost
		on
			ActualCost.GateNo = ReferenceCost.GateNo
			and
			ActualCost.CostAmt <> ReferenceCost.CostAmt
),
ActualOraCost as
(
	select 
		GateNo,
		Convert(decimal,SUM(TransSumAmount))/100 TransAmt,
		Convert(decimal,SUM(Cost))/100 CostAmt
	from 
		#ActualOraCost
	group by
		GateNo
),
ReferOraCost as
(
	select 
		GateNo,
		Convert(decimal,SUM(TransSumAmount))/100 TransAmt,
		Convert(decimal,SUM(Cost))/100 CostAmt
	from 
		#ReferOraCost
	group by
		GateNo
),
OraCostData as
(
	select
		ActualCost.GateNo,
		(select BankName from Table_OraBankSetting where BankSettingID = ActualCost.GateNo) as GateName,
		ActualCost.TransAmt,
		ReferenceCost.CostAmt/ActualCost.TransAmt as ReferFeeRatio,
		ReferenceCost.CostAmt as ReferCost,
		ActualCost.CostAmt/ActualCost.TransAmt as ActualFeeRatio,
		ActualCost.CostAmt as ActualCost,
		ReferenceCost.CostAmt - ActualCost.CostAmt as CostReduce
	from
		ActualOraCost ActualCost
		inner join
		ReferOraCost ReferenceCost
		on
			ActualCost.GateNo = ReferenceCost.GateNo
			and
			ActualCost.CostAmt <> ReferenceCost.CostAmt
)
select * from PayCostData
union all
select * from OraCostData;
	
--4.Drop table
Drop table #ActualPayCost;
Drop table #ActualOraCost;
Drop table #ReferPayCost;
Drop table #ReferOraCost;

End