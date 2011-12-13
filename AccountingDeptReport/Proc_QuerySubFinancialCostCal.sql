if OBJECT_ID(N'Proc_QuerySubFinancialCostCal',N'P') is not null
begin
	drop procedure Proc_QuerySubFinancialCostCal;
end
go

create procedure Proc_QuerySubFinancialCostCal
	@StartDate datetime = '2011-07-01',
	@EndDate datetime = '2011-08-01'
as
begin

declare @MaxRef bigint;
declare @MinRef bigint;
set @MaxRef = 100000000000000;
set @MinRef = 0;

--1. Check Input
if(@StartDate is null or @EndDate is null)
begin
	raiserror(N'Input params can`t be empty in Proc_QuerySubFinancialCostCal',16,1);
end


--2 get dailytrans
select
	GateNo,
	MerchantNo,
	FeeEndDate,
	SUM(ISNULL(PurCnt,0)) PurCnt,
	SUM(ISNULL(PurAmt,0))*100 PurAmt,
	SUM(ISNULL(FeeAmt,0))*100 FeeAmt,
	SUM(ISNULL(InstuFeeAmt,0))*100 InstuFeeAmt,
	SUM(ISNULL(BankFeeAmt,0))*100 BankFeeAmt
into
	#FeeResult
from
	Table_FeeCalcResult
where
	FeeEndDate >= @StartDate
	and
	FeeEndDate < @EndDate
group by
	GateNo,
	MerchantNo,
	FeeEndDate;


--3. determin rule type

--3.1 get daily trans with ApplyDate
select
	FeeResult.GateNo,
	FeeResult.MerchantNo,
	FeeResult.FeeEndDate,
	max(GateCostRule.ApplyDate) ApplyDate
into
	#FeeResultWithApplyDate
from
	#FeeResult FeeResult
	left join
	Table_GateCostRule GateCostRule
	on
		FeeResult.GateNo = GateCostRule.GateNo
		and
		FeeResult.FeeEndDate >= GateCostRule.ApplyDate   
group by
	FeeResult.GateNo,
	FeeResult.MerchantNo,
	FeeResult.FeeEndDate;
	
--3.2 add NextApplyDate in #DailyTransWithApplyDate
select
	FeeResultWithApplyDate.GateNo,
	FeeResultWithApplyDate.MerchantNo,
	FeeResultWithApplyDate.FeeEndDate,
	FeeResultWithApplyDate.ApplyDate,
	MIN(GateCostRule.ApplyDate) NextApplyDate
into
	#FeeResultWithAllApplyDate
from
	#FeeResultWithApplyDate FeeResultWithApplyDate
	left join
	Table_GateCostRule GateCostRule
	on
		FeeResultWithApplyDate.GateNo = GateCostRule.GateNo
		and
		FeeResultWithApplyDate.ApplyDate < GateCostRule.ApplyDate
group by
	FeeResultWithApplyDate.GateNo,
	FeeResultWithApplyDate.MerchantNo,
	FeeResultWithApplyDate.FeeEndDate,
	FeeResultWithApplyDate.ApplyDate;

--3.3 get TransWithRuleType
select
	FeeResult.GateNo,
	FeeResult.MerchantNo,
	FeeResult.FeeEndDate,
	FeeResult.PurCnt,
	FeeResult.PurAmt,
	FeeResult.FeeAmt,
	FeeResult.InstuFeeAmt,
	FeeResult.BankFeeAmt,
	isnull(GateCostRule.CostRuleType, '') as CostRuleType,
	isnull(FeeResultWithAllApplyDate.ApplyDate,'1900-01-01') as ApplyDate,
	case when 
		FeeResultWithAllApplyDate.NextApplyDate is null
		or FeeResultWithAllApplyDate.NextApplyDate > @EndDate
	then
		@EndDate
	else
		FeeResultWithAllApplyDate.NextApplyDate
	end as NextApplyDate
into
	#FeeResultWithRuleType
from
	#FeeResultWithAllApplyDate FeeResultWithAllApplyDate
	inner join
	#FeeResult FeeResult
	on
		FeeResultWithAllApplyDate.GateNo = FeeResult.GateNo
		and
		FeeResultWithAllApplyDate.MerchantNo = FeeResult.MerchantNo
		and
		FeeResultWithAllApplyDate.FeeEndDate = FeeResult.FeeEndDate
	left join
	Table_GateCostRule GateCostRule
	on
		FeeResultWithAllApplyDate.GateNo = GateCostRule.GateNo
		and
		FeeResultWithAllApplyDate.ApplyDate = GateCostRule.ApplyDate;
				
				
--3.4 construct #GateMerRule
select
	GateNo,
	MerchantNo,
	CostRuleType,
	ApplyDate,
	NextApplyDate,
	SUM(PurCnt) SucceedTransCount,
	SUM(PurAmt) SucceedTransAmount,
	SUM(ISNULL(FeeAmt,0)) FeeAmt,
	SUM(ISNULL(InstuFeeAmt,0)) InstuFeeAmt,
	SUM(ISNULL(BankFeeAmt,0)) BankFeeAmt,
	CONVERT(decimal(15,4),0) as Cost
into
	#GateMerRule
from
	#FeeResultWithRuleType
group by
	GateNo,
	MerchantNo,
	CostRuleType,
	ApplyDate,
	NextApplyDate;
	
	
--4. calculate cost value

--4.1 calculate By Trans

--4.1.1 Fixed	
update
	GateMerRule
set
	GateMerRule.Cost = GateMerRule.SucceedTransCount * CostRuleByTrans.FeeValue
from
	#GateMerRule GateMerRule
	inner join
	Table_CostRuleByTrans CostRuleByTrans
	on
		GateMerRule.GateNo = CostRuleByTrans.GateNo
		and
		GateMerRule.ApplyDate = CostRuleByTrans.ApplyDate
where
	GateMerRule.CostRuleType = 'ByTrans'
	and
	CostRuleByTrans.FeeType = 'Fixed'
	and
	CostRuleByTrans.RefMaxAmt = @MaxRef
	and  
	CostRuleByTrans.RefMinAmt = @MinRef;


--4.1.2 Percent
update
	GateMerRule
set
	GateMerRule.Cost = GateMerRule.SucceedTransAmount * CostRuleByTrans.FeeValue
from
	#GateMerRule GateMerRule
	inner join
	Table_CostRuleByTrans CostRuleByTrans
	on
		GateMerRule.GateNo = CostRuleByTrans.GateNo
		and
		GateMerRule.ApplyDate = CostRuleByTrans.ApplyDate
where
	GateMerRule.CostRuleType = 'ByTrans'
	and
	CostRuleByTrans.FeeType = 'Percent'
	and
	CostRuleByTrans.RefMaxAmt = @MaxRef
	and  
	CostRuleByTrans.RefMinAmt = @MinRef;
	
 
--4.1.3 DetailGateNo  

--a.Get DetailPayment data
select
	FeeTransLog.GateNo,
	FeeTransLog.MerchantNo,
	FeeTransLog.TransAmt,
	FeeCalcResult.FeeEndDate
into
	#TransDetail
from
	Table_FeeTransLog FeeTransLog
	inner join
	(select distinct 
			FeeBatchNo,
			FeeEndDate 
	from 
			Table_FeeCalcResult 
	where
			FeeEndDate >= @StartDate
			and
			FeeEndDate < @EndDate)FeeCalcResult
	on
		FeeTransLog.FeeBatchNo = FeeCalcResult.FeeBatchNo;	

--b.Cal DetailCost	
select
	TransDetail.GateNo,
	TransDetail.MerchantNo,
	GateMerRule.ApplyDate,
	case when
		CostRuleByTrans.FeeType = 'Fixed'
	then
		CostRuleByTrans.FeeValue
	else
		TransDetail.TransAmt * CostRuleByTrans.FeeValue
	end DetailCost
into
	#TransDetailWithCost
from	
	#TransDetail TransDetail
	inner join
	#GateMerRule GateMerRule
	on
		TransDetail.GateNo = GateMerRule.GateNo
		and
		TransDetail.MerchantNo = GateMerRule.MerchantNo
		and
		TransDetail.FeeEndDate >= GateMerRule.ApplyDate
		and
		TransDetail.FeeEndDate < GateMerRule.NextApplyDate
	inner join
	Table_CostRuleByTrans CostRuleByTrans
	on
		GateMerRule.GateNo = CostRuleByTrans.GateNo
		and
		GateMerRule.ApplyDate = CostRuleByTrans.ApplyDate
where
	GateMerRule.CostRuleType = 'ByTrans'
	and
	(CostRuleByTrans.RefMaxAmt <> @MaxRef
	or
	CostRuleByTrans.RefMinAmt <> @MinRef)
	and
	(TransDetail.TransAmt >= CostRuleByTrans.RefMinAmt
	and
	TransDetail.TransAmt <  CostRuleByTrans.RefMaxAmt);

--c.Get DetailGateNoCost
With TransLogCost as
(
	select
		GateNo,
		MerchantNo,
		ApplyDate,
		SUM(DetailCost) as Cost
	from
		#TransDetailWithCost
	group by
		GateNo,
		MerchantNo,
		ApplyDate
)
	
update 
	GateMerRule
set
	GateMerRule.Cost = TransLogCost.Cost
from
	#GateMerRule GateMerRule
	inner join
	TransLogCost 
	on
		GateMerRule.GateNo = TransLogCost.GateNo
		and
		GateMerRule.MerchantNo = TransLogCost.MerchantNo
		and
		GateMerRule.ApplyDate = TransLogCost.ApplyDate
where
	GateMerRule.CostRuleType = 'ByTrans';
		
	
--4.2 Caculate By Year
--Not consider RefMinAmt, RefMaxAmt

--4.2.1 Get Valid CostRuleByYearFixed
select
	GateNo,
	FeeValue/365 FeePerDay,
	ApplyDate,
	GateGroup
into
	#CostRuleByYearFixed
from
	Table_CostRuleByYear
where
	FeeType = 'Fixed'
	and
	RefMaxAmt = @MaxRef
	and
	RefMinAmt = @MinRef;
	
	
--4.2.2 Get GateGroup=0 CostRuleByYear
select
	GateNo,
	FeePerDay,
	ApplyDate
into
	#ByYearFixedSingleGate
from
	#CostRuleByYearFixed
where
	GateGroup = 0;

With SingleGateSumAmt as
(
	select
		GateNo,
		ApplyDate,
		NextApplyDate,
		SUM(SucceedTransAmount) SucceedTransAmount
	from
		#GateMerRule
	where
		CostRuleType = 'ByYear'
	group by
		GateNo,
		ApplyDate,
		NextApplyDate
),
SingleGateSumCost as 
(
	select
		SingleGateSumAmt.GateNo,
		SingleGateSumAmt.ApplyDate,
		case when 
			SingleGateSumAmt.ApplyDate <= @StartDate
		then
			DATEDIFF(DAY, @StartDate, SingleGateSumAmt.NextApplyDate) * ByYearFixedSingleGate.FeePerDay
		else
			DATEDIFF(DAY, SingleGateSumAmt.ApplyDate, SingleGateSumAmt.NextApplyDate) * ByYearFixedSingleGate.FeePerDay 
		end Cost,
		SingleGateSumAmt.SucceedTransAmount
	from
		#ByYearFixedSingleGate ByYearFixedSingleGate
		inner join
		SingleGateSumAmt
		on
			SingleGateSumAmt.GateNo = ByYearFixedSingleGate.GateNo
			and
			SingleGateSumAmt.ApplyDate = ByYearFixedSingleGate.ApplyDate
)
update
	GateMerRule
set
	GateMerRule.Cost = (case when
				SingleGateSumCost.SucceedTransAmount = 0
			then
				0
			else
				(CONVERT(decimal,GateMerRule.SucceedTransAmount)/SingleGateSumCost.SucceedTransAmount)*SingleGateSumCost.Cost
			end)
from
	#GateMerRule GateMerRule
	inner join
	SingleGateSumCost
	on
		GateMerRule.GateNo = SingleGateSumCost.GateNo
		and
		GateMerRule.ApplyDate = SingleGateSumCost.ApplyDate
where
	GateMerRule.CostRuleType = 'ByYear';
	
	
--4.2.3 Get GateGroup<>0 CostRuleByYear
select
	GateNo,
	FeePerDay,
	ApplyDate,
	GateGroup
into
	#ByYearFixedGroupGate
from
	#CostRuleByYearFixed
where
	GateGroup <> 0;
	
With GroupGateSumAmt as
(
	select
		ByYearFixedGroupGate.GateGroup,
		GateMerRule.ApplyDate,
		GateMerRule.NextApplyDate,
		SUM(GateMerRule.SucceedTransAmount) SucceedTransAmount
	from
		#GateMerRule GateMerRule
		inner join
		#ByYearFixedGroupGate ByYearFixedGroupGate
		on
			GateMerRule.GateNo = ByYearFixedGroupGate.GateNo
			and
			GateMerRule.ApplyDate = ByYearFixedGroupGate.ApplyDate
	where
		GateMerRule.CostRuleType = 'ByYear'
	group by
		ByYearFixedGroupGate.GateGroup,
		GateMerRule.ApplyDate,
		GateMerRule.NextApplyDate
),
GroupGateFee as
(
	select distinct
		GateGroup,
		FeePerDay,
		ApplyDate
	from
		#ByYearFixedGroupGate
),
GroupGateSumCost as 
(
	select
		GroupGateSumAmt.GateGroup,
		GroupGateSumAmt.ApplyDate,
		case when 
			GroupGateSumAmt.ApplyDate <= @StartDate
		then
			DATEDIFF(DAY, @StartDate, GroupGateSumAmt.NextApplyDate) * GroupGateFee.FeePerDay
		else
			DATEDIFF(DAY, GroupGateSumAmt.ApplyDate, GroupGateSumAmt.NextApplyDate) * GroupGateFee.FeePerDay 
		end Cost,
		GroupGateSumAmt.SucceedTransAmount
	from
		GroupGateFee
		inner join
		GroupGateSumAmt
		on
			GroupGateFee.GateGroup = GroupGateSumAmt.GateGroup
			and
			GroupGateFee.ApplyDate = GroupGateSumAmt.ApplyDate
)
update
	GateMerRule
set
	GateMerRule.Cost = (case when
							GroupGateSumCost.SucceedTransAmount = 0
						then
							0
						else
							(CONVERT(decimal,GateMerRule.SucceedTransAmount)/GroupGateSumCost.SucceedTransAmount)*GroupGateSumCost.Cost
						end)
from
	#GateMerRule GateMerRule
	inner join
	#ByYearFixedGroupGate ByYearFixedGroupGate
	on
		GateMerRule.GateNo = ByYearFixedGroupGate.GateNo
		and
		GateMerRule.ApplyDate = ByYearFixedGroupGate.ApplyDate
	inner join
	GroupGateSumCost
	on
		GroupGateSumCost.GateGroup = ByYearFixedGroupGate.GateGroup
		and
		GroupGateSumCost.ApplyDate = ByYearFixedGroupGate.ApplyDate
where
	GateMerRule.CostRuleType = 'ByYear';

	
--4.2.4 Calculate By Split
update 
	GateMerRule
set
	GateMerRule.cost = (
							case when
								ISNULL(GateMerRule.FeeAmt,0) <= ISNULL(GateMerRule.InstuFeeAmt,0)
							then
								0
							else	
								(GateMerRule.FeeAmt - ISNULL(GateMerRule.InstuFeeAmt,0)) * CostRuleByYear.FeeValue
							end
						)
from
	#GateMerRule GateMerRule
	inner join
	Table_CostRuleByYear CostRuleByYear
	on
		GateMerRule.GateNo = CostRuleByYear.GateNo
		and
		GateMerRule.ApplyDate = CostRuleByYear.ApplyDate
where
	CostRuleByYear.FeeType = N'Split'
	and
	CostRuleByYear.RefMaxAmt = @MaxRef
	and
	CostRuleByYear.RefMinAmt = @MinRef;
		
		
--4.3 Calculate by Merchant

--4.3.1 Calculate Cost for like cases
update
	GateMerRule
set
	GateMerRule.Cost = (case when 
							CostRuleByMer.FeeType = 'Percent'
						then
							CostRuleByMer.FeeValue * GateMerRule.SucceedTransAmount
						when
							CostRuleByMer.FeeType = 'Fixed'
						then
							CostRuleByMer.FeeValue * GateMerRule.SucceedTransCount
						else
							0
						end)	
from
	#GateMerRule GateMerRule
	inner join
	Table_CostRuleByMer CostRuleByMer
	on
		GateMerRule.GateNo = CostRuleByMer.GateNo
		and
		GateMerRule.MerchantNo like (RTRIM(CostRuleByMer.MerchantNo)+'%') 
		and
		GateMerRule.ApplyDate = CostRuleByMer.ApplyDate
where
	GateMerRule.CostRuleType = 'ByMer'
	and
	left(CostRuleByMer.MerchantNo,1) <> N'!';
	

--4.3.2 Calculate Cost for not like cases
update
	GateMerRule
set
	GateMerRule.Cost = (case when 
							CostRuleByMer.FeeType = 'Percent'
						then
							CostRuleByMer.FeeValue * GateMerRule.SucceedTransAmount
						when
							CostRuleByMer.FeeType = 'Fixed'
						then
							CostRuleByMer.FeeValue * GateMerRule.SucceedTransCount
						else
							0
						end)	
from
	#GateMerRule GateMerRule
	inner join
	Table_CostRuleByMer CostRuleByMer
	on
		GateMerRule.GateNo = CostRuleByMer.GateNo
		and
		GateMerRule.MerchantNo not like (ltrim(substring(CostRuleByMer.MerchantNo, 2, len(CostRuleByMer.MerchantNo)-1))+'%')
		and
		GateMerRule.ApplyDate = CostRuleByMer.ApplyDate
where
	GateMerRule.CostRuleType = 'ByMer'
	and
	left(CostRuleByMer.MerchantNo,1) = N'!';


--5. Get result
select 
	GateNo,
	MerchantNo,
	SUM(ISNULL(SucceedTransCount,0)) TransSumCount,
	SUM(ISNULL(SucceedTransAmount,0)) TransSumAmount,
	SUM(ISNULL(Cost ,0)) as Cost
from 
	#GateMerRule
group by
	GateNo,
	MerchantNo;	


--6. clear temp table 
drop table #FeeResult;
drop table #FeeResultWithApplyDate;
drop table #FeeResultWithAllApplyDate;
drop table #FeeResultWithRuleType;
drop table #GateMerRule;
drop table #TransDetail;	
drop table #TransDetailWithCost;
drop table #CostRuleByYearFixed;
drop table #ByYearFixedSingleGate;
drop table #ByYearFixedGroupGate;

end