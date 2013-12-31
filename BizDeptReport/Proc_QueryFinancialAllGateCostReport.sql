--[Created] At 20120530 By 王红燕:金融考核报表之银行成本降低额明细表(境外数据已转为人民币数据)
--[Modified] At 20120713 By 王红燕：Add All Bank Cost Calc Procs @HisRefDate Para Value
--[Modified] At 20130419 By 王红燕：Modify Reference Cost to Standard Cost
--[Modified] At 20131231 By 王红燕：Add New Tra Screen Trans and Cost
if OBJECT_ID(N'Proc_QueryFinancialAllGateCostReport', N'P') is not null
begin
	drop procedure Proc_QueryFinancialAllGateCostReport;
end
go

create procedure Proc_QueryFinancialAllGateCostReport
	@StartDate datetime = '2013-01-01',
	@EndDate datetime = '2013-03-31'
as
begin

--1. Check input
if (@StartDate is null or @EndDate is null)
begin
	raiserror(N'Input params cannot be empty in Proc_QueryFinancialAllGateCostReport', 16, 1);
end

--2. Prepare StartDate and EndDate
declare @CurrStartDate datetime;
declare @CurrEndDate datetime;
set @CurrStartDate = @StartDate;
set @CurrEndDate = DATEADD(day,1,@EndDate);

exec xprcFile '
GateNo	GateDesc	GateFlag
0016	无标准	1
0018	无标准	1
0019	无标准	1
0024	无标准	1
0044	两者均无	2
0045	两者均无	2
0058	无标准	1
0086	无标准	1
1019	无标准	1
2008	无标准	1
3124	无标准	1
5003	无标准	1
5005	无标准	1
5009	无标准	1
5011	无标准	1
5013	无标准	1
5015	无标准	1
5021	无标准	1
5022	无标准	1
5023	无标准	1
5026	无标准	1
5031	无标准	1
5032	无标准	1
5131	两者均无	2
5132	两者均无	2
5424	无标准	1
5602	无标准	1
5603	无标准	1
5604	两者均无	2
5606	两者均无	2
5608	无标准	1
5609	无标准	1
5901	无标准	1
5902	无标准	1
7007	无标准	1
7009	无标准	1
7012	两者均无	2
7013	两者均无	2
7015	两者均无	2
7018	两者均无	2
7022	两者均无	2
7023	无标准	1
7024	两者均无	2
7025	两者均无	2
7027	无标准	1
7029	无标准	1
7033	无标准	1
7107	无标准	1
7207	无标准	1
7507	两者均无	2
7517	无标准	1
8601	无标准	1
8604	无标准	1
8607	无标准	1
8610	无标准	1
8614	两者均无	2
9021	两者均无	2
'

select
	*
into
	#SpecialGateNo
from
	xlsContainer;
	
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
	BankSettingID char(10) not null,
	MerchantNo char(20) not null,
	CPDate datetime not null,
	TransCnt bigint not null,
	TransAmt bigint not null,
	CostAmt decimal(15,4) not null
);
insert into 
	#ActualOraCost
exec 
	Proc_CalOraCost @CurrStartDate,@CurrEndDate,NULL;
	
create table #ActualTraCost
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
insert into #ActualTraCost
exec Proc_CalTraCost @CurrStartDate,@CurrEndDate;
	
With ActualNewOraCost as
(
	select
		ChannelNo,
		N'代收付' as GateCategory,
		SUM(SucceedAmt) TransAmt,
		SUM(SucceedCnt) TransCnt,
		SUM(CostAmt) CostAmt
	from
		#ActualTraCost
	group by
		ChannelNo
),
ActualPayCost as
(
	select 
		Pay.GateNo,
		ISNULL(Gate.GateCategory1, N'B2C') as GateCategory,
		Pay.MerchantNo,
		Convert(decimal,SUM(Pay.TransSumAmount)) TransAmt,
		Convert(decimal,SUM(Pay.TransSumCount)) TransCnt,
		Convert(decimal,SUM(Pay.Cost)) CostAmt
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
		BankSettingID as GateNo,
		N'代收付' as GateCategory,
		Convert(decimal,SUM(TransAmt)) TransAmt,
		Convert(decimal,SUM(TransCnt)) TransCnt,
		Convert(decimal,SUM(CostAmt)) CostAmt
	from 
		#ActualOraCost
	group by
		BankSettingID
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
		GateNo,
		N'基金(支付)' as GateCategory,
		SUM(SucceedTransAmount) as TransAmt,
		SUM(SucceedTransCount) as TransCnt,
		0 as CostAmt
	from
		FactDailyTrans
	where
		DailyTransDate >= @CurrStartDate
		and
		DailyTransDate < @CurrEndDate
		and
		GateNo in ('0044','0045')
	group by
		GateNo
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
OtherB2CTrans as
(
	select
		AllTrans.GateNo,
		N'支付B2C' as GateCategory,
		(AllTrans.TransAmt - ISNULL(DomeTrans.TransAmt, 0)) TransAmt,
		(AllTrans.TransCnt - ISNULL(DomeTrans.TransCnt, 0)) TransCnt,
		(AllTrans.CostAmt - ISNULL(DomeTrans.CostAmt, 0)) CostAmt
	from
		(select
			GateNo,
			SUM(TransAmt) TransAmt,
			SUM(TransCnt) TransCnt,
			SUM(CostAmt) CostAmt
		 from
			B2CAllTrans
		 group by
			GateNo
		)AllTrans
		left join
		(select
			GateNo,
			SUM(TransAmt) TransAmt,
			SUM(TransCnt) TransCnt,
			SUM(CostAmt) CostAmt
		 from
			B2CNetBankTrans
		 group by
			GateNo
		)DomeTrans
		on
			AllTrans.GateNo = DomeTrans.GateNo
	where
		(AllTrans.TransAmt - ISNULL(DomeTrans.TransAmt, 0)) <> 0
		or
		(AllTrans.TransCnt - ISNULL(DomeTrans.TransCnt, 0)) <> 0
		or
		(AllTrans.CostAmt - ISNULL(DomeTrans.CostAmt, 0)) <> 0
),
--4.Join All Data
AllTransData as
(
	select * from ActualOraCost
	union all
	select * from ActualNewOraCost
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
	union all
	select * from OtherB2CTrans
),
GateCostData as 
(
	select
		GateNo,
		GateCategory,
		TransAmt,
		TransCnt,
		CostAmt as ActCostAmt,
		case when GateCategory = N'B2B' 
			 then TransCnt * 500
			 when GateCategory = N'代收付' 
			 then TransCnt * 70
			 when GateCategory in (N'B2C网银(境内)',N'基金(支付)' ) 
			 then Convert(decimal,TransAmt) * 0.0025
			 when GateCategory = N'B2C网银(境外)'
			 then Convert(decimal,CostAmt) 
			 Else NULL End as StdCostAmt
	from
		(
			select
				GateNo,
				GateCategory,
				SUM(TransAmt) TransAmt,
				SUM(TransCnt) TransCnt,
				SUM(CostAmt) CostAmt
			from
				AllTransData
			group by
				GateNo,
				GateCategory
		)Result
),
StdCostSum as
(
	select
		Convert(decimal,SUM(ISNULL(StdCostAmt,0)))/100.0 as StdCostAmt
	from
		GateCostData
),
StdCostRatio as
(
	select	distinct
		GateNo
	from
		GateCostData
	where
		GateCategory = N'B2C网银(境内)'
)
select
	GateCost.GateNo,
	GateCost.GateCategory,
	coalesce(Gate.GateDesc,Ora.BankName,Tra.ChannelName) GateName,
	case when GateCost.GateCategory in (N'B2B',N'代收付')
		 then 1 
		 Else 0 End as Flag,
	NoCostGate.GateDesc,
	Convert(decimal,GateCost.TransAmt)/100.0 as TransAmt,
	GateCost.TransCnt,
	case when coalesce(GateCostRule.GateNo,OraCost.BankSettingID,TraCost.ChannelNo) is null
		 then 0 
		 Else Convert(decimal,GateCost.ActCostAmt)/100.0 End as ActCostAmt,
	case when coalesce(GateCostRule.GateNo,OraCost.BankSettingID,TraCost.ChannelNo) is null
		 then N'无实际成本规则' 
	End as ActCostRatio,
	case when NoCostGate.GateNo is not null or coalesce(GateCostRule.GateNo,OraCost.BankSettingID,TraCost.ChannelNo) is null
		 then 0
		 Else Convert(decimal,GateCost.StdCostAmt)/100.0 End as StdCostAmt,
	case when NoCostGate.GateNo is not null or coalesce(GateCostRule.GateNo,OraCost.BankSettingID,TraCost.ChannelNo) is null
		 then 0
		 Else case when GateCost.GateCategory in (N'代收付')
			       then 0.7
				   when GateCost.GateCategory in (N'B2B')
				   then 5.0
				   when StdCostRatio.GateNo is not null
				   then 0.0025
				   Else GateCost.StdCostAmt/GateCost.TransAmt
	End End as StdCostRatio,
	case when NoCostGate.GateNo is not null or coalesce(GateCostRule.GateNo,OraCost.BankSettingID,TraCost.ChannelNo) is null
		 then 0 
		 when GateCost.StdCostAmt is null 
		 then NULL
		 Else Convert(decimal,(ISNULL(GateCost.StdCostAmt,0) - GateCost.ActCostAmt))/100.0
	End as CostReduce,
	(select StdCostAmt from StdCostSum) as StdCostSum
from
	GateCostData GateCost
	left join
	Table_GateRoute Gate
	on
		GateCost.GateNo = Gate.GateNo
	left join
	Table_OraBankSetting Ora
	on
		GateCost.GateNo = Ora.BankSettingID
	left join
	Table_TraChannelConfig Tra
	on
		GateCost.GateNo = Tra.ChannelNo
	left join
	#SpecialGateNo NoCostGate
	on
		GateCost.GateNo = NoCostGate.GateNo
	left join
	StdCostRatio
	on	
		GateCost.GateNo = StdCostRatio.GateNo
	left join
	(select distinct GateNo from Table_GateCostRule) GateCostRule
	on
		GateCost.GateNo = GateCostRule.GateNo
	left join
	(Select distinct BankSettingID from Table_OraBankCostRule)OraCost
	on
		GateCost.GateNo = OraCost.BankSettingID
	left join
	(Select distinct ChannelNo from Table_TraCostRuleByChannel)TraCost
	on
		GateCost.GateNo = TraCost.ChannelNo
order by
	GateCost.GateCategory,
	GateCost.GateNo;
	
--4.Drop table
Drop table #ActualPayCost;
Drop table #ActualOraCost;
Drop table #SpecialGateNo;
Drop table #ActualTraCost;
End